{
  inputs,
  config,
  ...
}: {
  perSystem = {pkgs, ...}: {
    packages.installationScript = pkgs.callPackage ./installationScript.nix {
      mkFlake = inputs.flake-parts.lib.mkFlake {inherit inputs;};
      agenix-shell-module = config.flake.flakeModules.agenix-shell;
    };
  };
}
