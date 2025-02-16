{
  description = "Basic example";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    agenix-shell.url = "github:aciceri/agenix-shell";
  };

  outputs = inputs: let
    system = "x86_64-linux";
    pkgs = inputs.nixpkgs.legacyPackages.${system};
    lib = pkgs.lib;
    installationScript = inputs.agenix-shell.lib.installationScript system {
      secrets = {
        foo.file = ./secrets/foo.age;
      };
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      shellHook = ''
        source ${lib.getExe installationScript}
      '';
    };
  };
}
