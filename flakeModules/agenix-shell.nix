{
  config,
  lib,
  flake-parts-lib,
  ...
}: let
  inherit (lib) mkOption mkPackageOption types;
  inherit (flake-parts-lib) mkPerSystemOption;

  cfg = config.agenix-shell;

  secretType = types.submodule ({
    config,
    ...
  }: {
    options = {
      name = mkOption {
        default = config._module.args.name;
	description = "Name of the file used in {option}`agenix-shell.secretsPath`.";
        internal = true;
      };

      file = mkOption {
        type = types.path;
        description = "Age file the secret is loaded from.";
      };

      path = mkOption {
        type = types.str; # TODO or path?
        default = "${cfg.secretsPath}/${config.name}";
	description = "Path where the decrypted secret is installed.";
      };

      mode = mkOption {
        type = types.str;
        default = "0400";
        description = "Permissions mode of the decrypted secret in a format understood by chmod.";
      };
    };
  });
in {
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

    secretsPath = mkOption {
      type = types.str; # TODO or path?
      default = ''/run/user/$(id -u)/agenix-shell/$(git rev-parse --show-toplevel | xargs basename)'';
      description = "Where the secrets are created.";
    };

    identityPaths = mkOption {
      type = types.listOf types.str; # TODO or path?
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
      package = mkPackageOption pkgs "age" {
	default = "rage";
      };

      _installSecrets = mkOption {
        type = types.str;
        internal = true;
        default =
          ''
            # shellcheck disable=SC2086
            rm -rf "${cfg.secretsPath}"
          ''
          + lib.concatStrings (lib.mapAttrsToList (_: config.agenix-shell._installSecret) cfg.secrets);
      };

      _installSecret = mkOption {
        type = types.functionTo types.str;
        internal = true;
        default = secret: ''
          IDENTITIES=()
          # shellcheck disable=2043
          for identity in ${builtins.toString cfg.identityPaths}; do
            test -r "$identity" || continue
            IDENTITIES+=(-i)
            IDENTITIES+=("$identity")
          done

          test "''${#IDENTITIES[@]}" -eq 0 && echo "[agenix] WARNING: no readable identities found!"

          mkdir -p "${cfg.secretsPath}"
          # shellcheck disable=SC2193
          [ "${secret.path}" != "${cfg.secretsPath}/${secret.name}" ] && mkdir -p "$(dirname "${secret.path}")"
          (
            umask u=r,g=,o=
            test -f "${secret.file}" || echo '[agenix] WARNING: encrypted file ${secret.file} does not exist!'
            test -d "$(dirname "${secret.path}")" || echo "[agenix] WARNING: $(dirname "$TMP_FILE") does not exist!"
            LANG=${config.i18n.defaultLocale or "C"} ${lib.getExe config.agenix-shell.package} --decrypt "''${IDENTITIES[@]}" -o "${secret.path}" "${secret.file}"
          )

          chmod ${secret.mode} "${secret.path}"

          AGENIX_${secret.name}_PATH="${secret.path}"
          AGENIX_${secret.name}=$(cat "$AGENIX_${secret.name}_PATH")
          export AGENIX_${secret.name}_PATH
          export AGENIX_${secret.name}

          function cleanup_secrets() {
            rm -rf "${cfg.secretsPath}"
          }

          trap cleanup_secrets EXIT
        '';
      };

      installationScript = mkOption {
        type = types.package;
        default = pkgs.writeShellApplication {
          name = "install-agenix-shell";
          runtimeInputs = [];
          text = config.agenix-shell._installSecrets;
        };
	description = "Script that exports secrets as variables, it's meant to be used as hook in `devShell`s.";
      };
    };
  });
}
