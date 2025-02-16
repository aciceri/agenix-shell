{
  perSystem = {
    config,
    pkgs,
    ...
  }: {
    devShells.default = pkgs.mkShell {
      packages = [];
      shellHook = ''
        ${config.pre-commit.installationScript}
      '';
    };
  };
}
