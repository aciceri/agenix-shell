# This approach is a bit hacky but gives free type checking
# by re-uusing the flake-parts module system.
{
  mkFlake,
  agenix-shell-module,
  agenixShellConfig ? {secrets = {};},
  stdenv,
}: let
  flake = mkFlake {
    systems = [stdenv.system];
    imports = [agenix-shell-module];
    agenix-shell = agenixShellConfig;
    debug = true;
  };
  flakePerSystem = flake.debug.perSystem stdenv.system;
in
  flakePerSystem.agenix-shell.installationScript
