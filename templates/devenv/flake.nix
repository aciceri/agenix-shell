{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    devenv.url = "github:cachix/devenv";
    agenix-shell.url = "github:aciceri/agenix-shell";
  };

  outputs = inputs: let
    system = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;
    installationScript = inputs.agenix-shell.packages.${system}.installationScript.override {
      agenixShellConfig.secrets = {
        foo.file = ./secrets/foo.age;
      };
    };
  in {
    devShell.x86_64-linux = inputs.devenv.lib.mkShell {
      inherit inputs pkgs;
      modules = [
        ({
          pkgs,
          config,
          ...
        }: {
          enterShell = ''
            source ${lib.getExe installationScript}
          '';
        })
      ];
    };
  };
}
