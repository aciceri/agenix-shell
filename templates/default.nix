{config, ...}: {
  flake.templates = {
    flake-parts = {
      path = ./flake-parts;
      description = "Basic example using flake-parts";
    };
    default = config.flake.templates.flake-parts;
  };
}
