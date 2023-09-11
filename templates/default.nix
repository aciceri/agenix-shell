{config, ...}: {
  flake.templates = {
    basic = {
      path = ./basic;
      description = "Basic example";
    };
    default = config.flake.templates.basic;
  };
}
