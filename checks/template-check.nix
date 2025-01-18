{
  bash,
  bubblewrap,
  busybox,
  diffutils,
  git,
  gnugrep,
  lib,
  runCommand,
  system,
  util-linux,
  writeText,
  flake,
  src,
  ...
}: let
  inherit system;

  check-secret = writeText "check-secret" ''
    check() {
      local msg="''${1?internal error}"
      shift

      "$@" 1>&2 || {
        local -i rc="$?"
        printf 1>&2 -- 'ERROR: %s\n' "$msg"
        return "$rc"
      }
    }

    check_diff() {
      local left="''${1?internal error}"
      shift

      local right="''${1?internal error}"
      shift

      check "''${*:-unexpected differences found in inputs}" ${diffutils}/bin/diff -U3 "$left" "$right"
    }

    # Declared variables and functions, minus certain Bash-managed special
    # variables.
    clean_set() {
      set | ${lib.getExe gnugrep} -v -e '^_=' -e '^BASH_[A-Z_]\+=' "$@"
    }

    cp -r ${src}/* .

    git -c init.defaultBranch=main init .

    clean_set > ./set_pre

    ${flake.devShells.${system}.default.shellHook}

    clean_set -e '^foo=' -e '^foo_PATH=' > set_post

    # XXX no newline!  Otherwise `diff_check` will fail spuriously.
    printf > ./expected -- '%s' 'I believe that Club-Mate is overrated'
    printf > ./actual -- '%s' "$foo"

    rc=0
    check '$foo is undefined or empty' test -n "''${foo:-}" || rc="$?"
    check '$foo_PATH is undefined or empty' test -n "''${foo_PATH:-}" || rc="$?"
    check_diff ./expected ./actual "the \$foo variable did not contain the expected text" || rc="$?"
    check_diff ./expected "$foo_PATH" "the file indicated by \$foo_PATH did not contain the expected text" || rc="$?"
    check_diff ./set_pre ./set_post "the shell environment changed in an unexpected manner while running the shell hook" || rc="$?"
    exit "$rc"
  '';

  home = runCommand "create-home" {} ''
    mkdir -p $out/.ssh
    cp ${./id_rsa} $out/.ssh/id_rsa
  '';
in
  runCommand "check-flake-parts-template" {}
  /*
  Bubblewrap command explanation
    --dir /run \  # secrets are saved in /run
    --dev /dev \  # /dev/null is needed by xargs (used by the sourced script)
    --ro-bind /nix/store /nix/store \  # read the store
  */
  ''
    ${bubblewrap}/bin/bwrap \
      --dir /run \
      --dev /dev \
      --bind /build /build \
      --chdir /build \
      --setenv PATH "${git}/bin:${busybox}/bin:${util-linux}/bin" \
      --setenv HOME "${home}" \
      --ro-bind /nix/store /nix/store \
        ${bash}/bin/bash ${check-secret} > $out
  ''
