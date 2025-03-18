# agenix-shell

Leveraging [age](https://github.com/FiloSottile/age) and [agenix](https://github.com/ryantm/agenix) this project gives you the ability to inject variables containing secrets into your flakes' `devShells`.

This simplify a lot the onboarding phase for new developers allowing them to share secrets (it's possible to set who can access which secrets) and make projects more self-contained eliminating the need of external tools.


## Usage

Minimal knowledge of how [agenix](https://github.com/ryantm/agenix) operates is required, indeed it relies on having the same setup as `agenix` i.e. a `secrets` directory containing all the encrypted secrets and a `secrets.nix` file that lists them and specifies which keys can be used to decrypt each secret.

Example of `secrets/secrets.nix` file:

```nix
{
  "foo.age".publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDpVA+jisOuuNDeCJ67M11qUP8YY29cipajWzTFAobi"
  ];
}
```

Notice how while this is the format expected by `agenix` script you are not required to use the same since `agenix-shell` will require you to set the paths for the `.age` files (exactly as the `agenix` modules do).

`agenix-shell` will inject two environment variables for each secret, one containing the cleartext secret itself and the other one containing the path to the secret. Assuming the example above you will get:

- `foo` containing the secret
- `foo_PATH` containing the path to the secret (`agenix-shell` automatically appends `_PATH`)


### Basic usage
```nix
{
  devShells.${system}.default = let
    installationScript = inputs.agenix-shell.lib.installationScript system {
      secrets = {
        foo.file = ./secrets/foo.age;
      };
    };
  in pkgs.mkShell {
    shellHook = ''
      source ${lib.getExe installationScript}
    '';
  };
}
```
Check the [basic example](./templates/basic/) for a working example (you will need to delete the encrypted secret and encrypt your own with your key). Otherwise you could copy the [used key](./checks/id_rsa) (**do not use that key in production obviously**).

```bash
nix flake init -t github:aciceri/agenix-shell#basic
```

Notice that internally this approach uses `flake-parts` for evaluating the passed arguments, so you can browse the automatically generated documentation on [flake.parts](https://flake.parts/options/agenix-shell) for understanding all the attributes you can pass to `agenix-shell.lib.installationScript system`.


### With `flake-parts`
```nix
{
  imports = [
    inputs.agenix-shell.flakeModules.default
  ];

  agenix-shell = {
    secrets = {
      foo.file = ./secrets/foo.age;
    };
  };

  perSystem = {pkgs, config, lib, ... }: {
    devShells.default = pkgs.mkShell {
      shellHook = ''
        source ${lib.getExe config.agenix-shell.installationScript}
      '';
    };
  };
}
```

Check the [flake-parts template](./templates/flake-parts) for a working example (you will need to delete the encrypted secret and encrypt your own with your key). Otherwise you could copy the [used key](./checks/id_rsa) (**do not use that key in production obviously**).

```
nix flake init -t github:aciceri/agenix-shell#flake-parts 
```

### With `devenv`

[Here](./templates/devenv/) a working template.

```bash
nix flake init -t github:aciceri/agenix-shell#devenv
```

## How it works

The functioning is quite simple, `agenix-shell` exports a configurable script that will be sourced somewhere in the `devShell` (like in an `hook`). This script will:

- decrypt the configured secrets using user's keys (by default it expects them in `$HOME/.ssh/id_rsa` or `$HOME/.ssh/id_ed25519`)
- put the decrypted secrets somewhere
  - on Linux they will end in `$XDG_RUNTIME_DIR/agenix-shell/<hash>` (which means in `/run/user/$UID` that is accessible only by the shell's user and it's mounted on `tmpfs`)
  - on Darwin a `~/.agenix-shell` directory will be created and then `~/.agenix-shell/<hash>` is mounted on `hfs` (similar to `tmpfs`), secrets will end there.
- declare two variables for each secret, one containing the secret itself and the other one containing the path to the secret

That's it! Everything is as customizable as possible using the appropriate options. Check [flake.parts](https://flake.parts/options/agenix-shell) for a complete list (and to know defaults).

Notice that the script is hygenic, meaning that all the intermediary variables are unset, leaving only the ones containing the secrets. In the same way it also uses a different `PATH` is used, meaning that all the binaries used by the script are declared (only on Linux).
