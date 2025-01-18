{
  flakePartsArgs,
  pkgs,
  ...
}: let
  inherit (flakePartsArgs) config inputs;

  flake = (import "${config.flake.templates.flake-parts.path}/flake.nix").outputs {
    self = flake // {inherit inputs;};
    agenix-shell = config.flake;
    inherit (inputs) flake-parts nixpkgs;
  };
in
  pkgs.callPackage ./template-check.nix {
    inherit flake;
    src = ../templates/flake-parts;
  }
