{
  lib,
  inputs,
  ...
}: {
  imports =
    lib.optional (inputs.treefmt-nix ? flakeModule) inputs.treefmt-nix.flakeModule
    ++ lib.optional (inputs.git-hooks-nix ? flakeModule) inputs.git-hooks-nix.flakeModule;

  perSystem = {config, ...}:
    lib.optionalAttrs (inputs.treefmt-nix ? flakeModule && inputs.git-hooks-nix ? flakeModule) {
      treefmt.config = {
        projectRootFile = ".git/config";
        flakeFormatter = true;
        flakeCheck = true;
        programs = {
          alejandra.enable = true;
        };
        settings.global.excludes = [
          "*.yaml"
          ".envrc"
          "*.md"
          "**/id_rsa"
          "*.age"
          "LICENSE"
        ];
      };

      pre-commit = {
        check.enable = false;
        settings.hooks = {
          treefmt = {
            enable = true;
            package = config.treefmt.build.wrapper;
          };
        };
      };
    };
}
