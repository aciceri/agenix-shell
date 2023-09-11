flakePartsArgs @ {self, ...}: {
  perSystem = {
    pkgs,
    config,
    lib,
    ...
  }: {
    checks = {
      basic-template = pkgs.callPackage ./basic-template.nix {
        inherit flakePartsArgs;
      };

      formatting = pkgs.runCommand "check-formatting" {} ''
        ${lib.getExe config.formatter} --check ${self.outPath} > $out
      '';
    };
  };
}
