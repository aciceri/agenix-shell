{config, ...}: {
  flake.templates = {
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
