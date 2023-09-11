{
  flakePartsArgs,
  pkgs,
  ...
}: let
  inherit (flakePartsArgs) config inputs;
  inherit (pkgs) system;

  flake = (import "${config.flake.templates.basic.path}/flake.nix").outputs {
    self = flake // {inherit inputs;};
    agenix-shell = config.flake;
    inherit (inputs) flake-parts nixpkgs;
  };

  check-secret = pkgs.writeText "check-secret" ''
    cp -r ${../templates/basic}/* .
    git init .
    ${flake.devShells.${system}.default.shellHook}
    [[ $AGENIX_foo == "I believe that Club-Mate is overrated" ]] || exit 1
  '';
  
  home = pkgs.runCommand "create-home" {} ''
    mkdir -p $out/.ssh
    cp ${./id_rsa} $out/.ssh/id_rsa
  '';
in
  pkgs.runCommand "check-basic-template" {}
  /*
  Bubblewrap command explanation
    --dir /run \  # secrets are saved in /run
    --dev /dev \  # /dev/null is needed by xargs (used by the sourced script)
    --ro-bind /nix/store /nix/store \  # store paths must
  */
  ''
    ${pkgs.bubblewrap}/bin/bwrap \
      --dir /run \
      --dev /dev \
      --bind /build /build \
      --chdir /build \
      --setenv PATH "${pkgs.git}/bin:${pkgs.busybox}/bin" \
      --setenv HOME "${home}" \
      --ro-bind /nix/store /nix/store \
        ${pkgs.bash}/bin/bash ${check-secret} > $out
  ''
