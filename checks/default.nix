{
  config,
  inputs,
  lib,
  self,
  ...
}: {
  perSystem = {pkgs, ...} @ perSystem: let
    callFlake = src:
      lib.fix (flake:
        (import src).outputs (inputs
          // {
            self = flake // {inherit inputs;};
            agenix-shell = config.flake;
          }));

    templateCheck = {
      flakeSrc,
      templateSrc,
      ...
    } @ args:
      pkgs.callPackage ./template-check.nix (builtins.removeAttrs args ["flakeSrc" "templateSrc"]
        // {
          src = templateSrc;
          flake = callFlake flakeSrc;
        });
  in {
    checks = {
      flake-parts-template = templateCheck {
        flakeSrc = "${config.flake.templates.flake-parts.path}/flake.nix";
        templateSrc = ../templates/flake-parts;
      };

      basic-template = templateCheck {
        flakeSrc = "${config.flake.templates.basic.path}/flake.nix";
        templateSrc = ../templates/basic;
      };

      formatting = pkgs.runCommand "check-formatting" {} ''
        ${lib.getExe perSystem.config.formatter} --check ${self.outPath} > $out
      '';
    };
  };
}
