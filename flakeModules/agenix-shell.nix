{localInputs}: {
  config,
  lib,
  flake-parts-lib,
  ...
}: let
  inherit (lib) mkOption mkPackageOption types;
  inherit (flake-parts-lib) mkPerSystemOption;

  cfg = config.agenix-shell;

  duplicateAttrValues = let
    incrAttr = name: value: attrs: let
      valueStr = builtins.unsafeDiscardStringContext (toString value);
    in
      attrs // {${valueStr} = (attrs.${valueStr} or []) ++ [name];};
    incrAttrs = name: values: attrs: lib.pipe attrs (map (incrAttr name) values);
    getAttrValues = attrs: map (lib.flip lib.getAttr attrs);
  in
    values:
      lib.flip lib.pipe [
        (lib.foldlAttrs (acc: name: item: incrAttrs name (getAttrValues item values) acc) {})
        (lib.mapAttrs (_: lib.unique))
        (lib.filterAttrs (_: names: lib.length names > 1))
      ];

  duplicateShellVars = duplicateAttrValues ["name" "namePath"] cfg.secrets;
  duplicateFiles = duplicateAttrValues ["file"] cfg.secrets;

  shellVarHeadRanges = "_A-Za-z";
  shellVarTailRanges = "${shellVarHeadRanges}0-9";
  shellVarType = let
    base = types.strMatching "^[${shellVarHeadRanges}][${shellVarTailRanges}]+$";
  in
    base
    // {
      name = "shellVar";
      description = "valid shell variable name (${base.description})";
    };

  toShellVar = let
    replacement = "__";
    convertInvalid = c:
      if ((builtins.match "^[${shellVarTailRanges}]+$" c) != null)
      then c
      else replacement;
  in
    name: let
      prefix = lib.optionalString (builtins.match "^[${shellVarHeadRanges}].*" name == null) replacement;
    in "${prefix}${lib.stringAsChars convertInvalid name}";

  secretType = types.submodule ({config, ...}: {
    options = {
      name = mkOption {
        type = shellVarType;
        default = toShellVar config._module.args.name;
        description = "Name of the variable containing the secret.";
        defaultText = lib.literalExpression "<name>";
      };

      namePath = mkOption {
        type = shellVarType;
        default = "${config.name}_PATH";
        description = "Name of the variable containing the path to the secret.";
        defaultText = lib.literalExpression "<name>_PATH";
      };

      file = mkOption {
        type = types.path;
        description = "Age file the secret is loaded from.";
      };

      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "Permissions mode of the decrypted secret in a format understood by chmod.";
      };
    };
  });
in {
  imports = [
    localInputs.flake-root.flakeModule
  ];

  options.agenix-shell = {
    secrets = mkOption {
      type = types.attrsOf secretType;
      description = "Attrset of secrets.";
      example = lib.literalExpression ''
        {
          foo.file = "secrets/foo.age";
          bar = {
            file = "secrets/bar.age";
            mode = "0440";
          };
        }
      '';
    };

    identityPaths = mkOption {
      type = types.listOf types.str;
      default = [
        "$HOME/.ssh/id_ed25519"
        "$HOME/.ssh/id_rsa"
      ];
      description = ''
        Path to SSH keys to be used as identities in age decryption.
      '';
    };
  };

  options.perSystem = mkPerSystemOption ({
    config,
    pkgs,
    ...
  }: let
    inherit (pkgs.stdenv) isDarwin;

    prepareSecretsPath =
      ''
        __agenix_shell_flake_hash="$(${lib.getExe config.flake-root.package} | openssl dgst -md5 -r | cut -d ' ' -f1)"
      ''
      + (
        if isDarwin
        then ''
          __agenix_shell_secrets_path="$HOME/.agenix-shell/$__agenix_shell_flake_hash"
          __agenix_shell_old_dev=$(hdiutil info | grep $__agenix_shell_secrets_path -B 2 | grep '/dev/disk' | awk '{print $1}')
          umount "$__agenix_shell_secrets_path" &> /dev/null
          # fail silently, expected to fail on first run because previous device won't exist yet
          hdiutil detach "$__agenix_shell_old_dev" &> /dev/null
        ''
        else ''
          __agenix_shell_secrets_path="$XDG_RUNTIME_DIR/agenix-shell/$__agenix_shell_flake_hash";
        ''
      )
      + ''
        rm -rf "$__agenix_shell_secrets_path"
      '';

    createSecretsPath =
      if isDarwin
      then ''
        if ! diskutil info "$__agenix_shell_secrets_path" &> /dev/null; then
          num_sectors=1048576
          __agenix_shell_new_dev=$(hdiutil attach -nomount ram://"$num_sectors" | sed 's/[[:space:]]*$//')
          newfs_hfs -v "agenix" "$__agenix_shell_new_dev" &> /dev/null
          mkdir -p "$__agenix_shell_secrets_path"
          mount -t hfs -o nobrowse,nodev,nosuid,-m=0751 "$__agenix_shell_new_dev" "$__agenix_shell_secrets_path"
        fi
      ''
      else ''
        mkdir -p "$__agenix_shell_secrets_path"
      '';
  in {
    options.agenix-shell = {
      agePackage = mkPackageOption pkgs "age" {
        default = "rage";
      };

      _installSecrets = mkOption {
        type = types.str;
        internal = true;
        readOnly = true;
        default = let
          formatDuplicates = duplicates: pre: post:
            lib.optionalString (duplicates != {}) ''
              printf 1>&2 '[agenix] %s\n' ${lib.escapeShellArg pre}
              ${lib.concatMapStringsSep "\n" (name: ''
                printf 1>&2 -- ' - %s (used by: %s)\n' ${lib.escapeShellArgs [name (lib.concatStringsSep ", " (duplicates.${name}))]}
              '') (builtins.attrNames duplicates)}
              printf 1>&2 '[agenix] %s\n' ${lib.escapeShellArg post}
            '';
        in
          (lib.optionalString (!isDarwin) ''
            # Saving the old PATH set by the shell
            export __agenix_shell_original_path=$PATH
            # Set a new PATH in order to make this script "pure"
            export PATH=${lib.makeBinPath (with pkgs; [coreutils openssl])}
          '')
          + (formatDuplicates duplicateFiles ''
              the following output file paths are used more than once in `agenix-shell.secrets`:
            ''
            ''
              only the last secret using a given output file path will be written to that location.
            '')
          + (formatDuplicates duplicateShellVars ''
              the following variable names are used more than once in `agenix-shell.secrets`:
            ''
            ''
              these variables will be set to the values associated with the last secret to use them.
            '')
          + ''
            ${prepareSecretsPath}

            __agenix_shell_identities=()
            # shellcheck disable=2043,2066
            for __agenix_shell_identity in ${builtins.toString cfg.identityPaths}; do
              if ! test -r "$__agenix_shell_identity"; then
                continue
              fi

              __agenix_shell_identities+=(-i "$__agenix_shell_identity")
            done

            if test "''${#__agenix_shell_identities[@]}" -eq 0; then
              echo 1>&2 "[agenix] WARNING: no readable identities found!"
            fi

            ${createSecretsPath}
          ''
          + lib.concatStrings (lib.mapAttrsToList config.agenix-shell._installSecret cfg.secrets)
          + (lib.optionalString (!isDarwin) ''
            # Restore the original PATH
            export PATH=$__agenix_shell_original_path
          '')
          + ''
            # Clean up after ourselves
            # shellcheck disable=SC2154
            unset "''${!__agenix_shell_@}" || :
          '';
      };

      _installSecret = mkOption {
        type = types.functionTo (types.functionTo types.str);
        internal = true;
        readOnly = true;
        default = name: secret: ''
          __agenix_shell_secret_path="$__agenix_shell_secrets_path/${secret.name}"

          printf 1>&2 -- '[agenix] decrypting secret %q from %q to %q...\n' ${lib.escapeShellArgs [name secret.file]} "$__agenix_shell_secret_path"

          # shellcheck disable=SC2193
          if [ "$__agenix_shell_secret_path" != "$__agenix_shell_secrets_path/${secret.name}" ]; then
            mkdir -p "$(dirname "$__agenix_shell_secret_path")"
          fi

          (
            umask u=r,g=,o=

            if ! test -f "${secret.file}"; then
              echo 1>&2 '[agenix] WARNING: encrypted file ${secret.file} does not exist!'
            fi

            if ! test -d "$(dirname "$__agenix_shell_secret_path")"; then
              echo 1>&2 "[agenix] WARNING: $(dirname "$__agenix_shell_secret_path") does not exist!"
            fi

            LANG=${config.i18n.defaultLocale or "C"} ${lib.getExe config.agenix-shell.agePackage} --decrypt "''${__agenix_shell_identities[@]}" -o "$__agenix_shell_secret_path" "${secret.file}"
          )

          chmod ${secret.mode} "$__agenix_shell_secret_path"

          ${secret.name}=$(cat "$__agenix_shell_secret_path")
          ${secret.namePath}="$__agenix_shell_secret_path"
          export ${secret.name}
          export ${secret.namePath}
        '';
      };

      installationScript = mkOption {
        type = types.package;
        default = let
          optsSupported = let
            fargs = builtins.functionArgs pkgs.writeShellApplication;
          in
            fargs ? "bashOptions" && fargs ? "extraShellCheckFlags";

          writer =
            if optsSupported
            then pkgs.writeShellApplication
            else attrs: pkgs.writeShellScriptBin attrs.name attrs.text;
        in
          writer ({
              name = "install-agenix-shell";
              text = config.agenix-shell._installSecrets;
            }
            // lib.optionalAttrs optsSupported {
              # Only bail for outright errors; allow style violations.
              extraShellCheckFlags = ["-S" "error"];

              # This script is meant to be sourced in an interactive shell; do not
              # touch the user's shell options.
              bashOptions = [];
            });
        description = "Script that exports secrets as variables, it's meant to be used as hook in `devShell`s.";
        defaultText = lib.literalMD "An automatically generated package";
      };
    };
  });
}
