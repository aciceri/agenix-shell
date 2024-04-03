{
  flakePartsArgs,
  pkgs,
  ...
}: let
  inherit (flakePartsArgs) config inputs;
  inherit (pkgs) system;

  flake = (import "${config.flake.templates.flake-parts.path}/flake.nix").outputs {
    self = flake // {inherit inputs;};
    agenix-shell = config.flake;
    inherit (inputs) flake-parts nixpkgs;
  };

  check-secret = pkgs.writeText "check-secret" ''
    cp -r ${../templates/flake-parts}/* .
    git init .
    ${flake.devShells.${system}.default.shellHook}
    [[ $foo == "I believe that Club-Mate is overrated" ]] || exit 1
  '';

  home = pkgs.runCommand "create-home" {} ''
    mkdir -p $out/.ssh
    cp ${./id_rsa} $out/.ssh/id_rsa
  '';
in
  pkgs.runCommand "check-flake-parts-template" {}
  /*
  Bubblewrap command explanation
    --dir /run \  # secrets are saved in /run
    --dev /dev \  # /dev/null is needed by xargs (used by the sourced script)
    --ro-bind /nix/store /nix/store \  # read the store
  */
  ''
    ${pkgs.bubblewrap}/bin/bwrap \
      --dir /run \
      --dev /dev \
      --bind /build /build \
      --chdir /build \
      --setenv PATH "${pkgs.git}/bin:${pkgs.busybox}/bin:${pkgs.util-linux}/bin" \
      --setenv HOME "${home}" \
      --ro-bind /nix/store /nix/store \
        ${pkgs.bash}/bin/bash ${check-secret} > $out
  ''
