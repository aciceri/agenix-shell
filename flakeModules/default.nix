{
  config,
  inputs,
  flake-parts-lib,
  ...
}: {
  flake.flakeModules = {
    agenix-shell = flake-parts-lib.importApply ./agenix-shell.nix {localInputs = inputs;};
    default = config.flake.flakeModules.agenix-shell;
  };
}
