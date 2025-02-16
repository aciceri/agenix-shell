# This approach is a bit hacky but gives free type checking
# by re-using the flake-parts module system.
{
  mkFlake,
  agenix-shell-module,
  agenixShellConfig ? {secrets = {};},
  stdenv,
}: let
  flake = mkFlake ({withSystem, ...}: {
    systems = [stdenv.system];
    imports = [agenix-shell-module];
    agenix-shell = agenixShellConfig;
    flake.installationScript = withSystem stdenv.system ({config, ...}: config.agenix-shell.installationScript);
  });
in
  flake.installationScript
