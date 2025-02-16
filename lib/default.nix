{withSystem, ...}: {
  flake.lib.installationScript = system: agenixShellConfig: withSystem system ({config, ...}: config.packages.installationScript.override {inherit agenixShellConfig;});
}
