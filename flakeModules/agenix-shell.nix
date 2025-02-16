{
  config,
  lib,
  flake-parts-lib,
	inputs,
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

      path = mkOption {
        type = types.str;
        default = "${cfg.secretsPath}/${config.name}";
        description = "Path where the decrypted secret is installed.";
        defaultText = lib.literalExpression ''"''${config.agenix-shell.secretsPath}/<name>"'';
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
    inputs.flake-root.flakeModule
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

    flakeName = mkOption {
      type = types.str;
      default = "git rev-parse --show-toplevel | xargs basename";
      description = "Command returning the name of the flake, used as part of the secrets path.";
    };

    secretsPath = mkOption {
      type = types.str;
			default = ".agenix";
      description = "Name of directory relative to flake root where secrets are stored.";
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
  }: {
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
          (formatDuplicates duplicateFiles ''
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
					  SECRETS_PATH="$(${lib.getExe config.flake-root.package})/${cfg.secretsPath}"
						OLD_DEV=$(hdiutil info | grep $SECRETS_PATH -B 2 | grep '/dev/disk' | awk '{print $1}')
						umount "$SECRETS_PATH"
            # fail silently, expected to fail on first run because previous device won't exist yet
						hdiutil detach "$OLD_DEV" &> /dev/null
						rm -rf "$SECRETS_PATH"

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

					  if ! diskutil info "$SECRETS_PATH" &> /dev/null; then
							num_sectors=1048576
							NEW_DEV=$(hdiutil attach -nomount ram://"$num_sectors" | sed 's/[[:space:]]*$//')
							newfs_hfs -v "agenix" "$NEW_DEV"
							mkdir "$SECRETS_PATH"
							mount -t hfs -o nobrowse,nodev,nosuid,-m=0751 "$NEW_DEV" "$SECRETS_PATH"
						fi
          ''
          + lib.concatStrings (lib.mapAttrsToList config.agenix-shell._installSecret cfg.secrets)
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
          __agenix_shell_secret_path=${secret.path}

          printf 1>&2 -- '[agenix] decrypting secret %q from %q to %q...\n' ${lib.escapeShellArgs [name secret.file]} "$__agenix_shell_secret_path"

          # shellcheck disable=SC2193
          if [ "$__agenix_shell_secret_path" != "$SECRETS_PATH/${secret.name}" ]; then
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
              runtimeInputs = with pkgs; [ toybox gawk ];
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
