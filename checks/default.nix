flakePartsArgs @ {self, ...}: {
  perSystem = {
    pkgs,
    config,
    lib,
    ...
  }: {
    checks = {
      flake-parts-template = pkgs.callPackage ./flake-parts-template.nix {
        inherit flakePartsArgs;
      };

      basic-template = pkgs.callPackage ./basic-template.nix {
        inherit flakePartsArgs;
      };

      formatting = pkgs.runCommand "check-formatting" {} ''
        ${lib.getExe config.formatter} --check ${self.outPath} > $out
      '';
    };
  };
}
