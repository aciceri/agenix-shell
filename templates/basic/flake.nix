{
  description = "Basic example";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    agenix-shell.url = "github:aciceri/agenix-shell";
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin"];

      imports = [
        inputs.agenix-shell.flakeModules.default
      ];

      agenix = {
        secrets = {
          foo.file = ./secrets/foo.age;
        };
      };

      perSystem = {
        pkgs,
        config,
        lib,
        ...
      }: {
        devShells.default = pkgs.mkShell {
          shellHook = ''
            source ${lib.getExe config.agenix.installationScript}
          '';
        };
      };
    };
}
