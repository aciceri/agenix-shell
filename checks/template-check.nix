{
  pkgs,
  flake,
  src,
  ...
}: let
  inherit (pkgs) system;

  check-secret = pkgs.writeText "check-secret" ''
    check_diff() {
      local left="''${1?internal error}"
      shift

      local right="''${1?internal error}"
      shift

      ${pkgs.diffutils}/bin/diff -U3 "$left" "$right" 1>&2 || {
        local -i rc="$?"
        printf 1>&2 -- 'ERROR: %s\n' "''${*:-unexpected differences found in inputs}"
        return "$rc"
      }
    }

    cp -r ${src}/* .

    git -c init.defaultBranch=main init .

    ${flake.devShells.${system}.default.shellHook}

    # XXX no newline!  Otherwise `diff_check` will fail spuriously.
    printf > ./expected -- '%s' 'I believe that Club-Mate is overrated'
    printf > ./actual -- '%s' "$foo"

    rc=0
    check_diff ./expected ./actual "the \$foo variable did not contain the expected text" || rc="$?"
    check_diff ./expected "$foo_PATH" "the file indicated by \$foo_PATH did not contain the expected text" || rc="$?"
    exit "$rc"
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
