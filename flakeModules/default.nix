{config, ...}: {
  flake.flakeModules = {
    agenix-shell = ./agenix-shell.nix;
    default = config.flake.flakeModules.agenix-shell;
  };
}
