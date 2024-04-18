{config, ...}: {
  flake.templates = {
    devenv = {
      path = ./devenv;
      description = "Basic example using devenv";
    };
    flake-parts = {
      path = ./flake-parts;
      description = "Basic example using flake-parts";
    };
    basic = {
      path = ./basic;
      description = "Basic example";
    };
    default = config.flake.templates.basic;
  };
}
