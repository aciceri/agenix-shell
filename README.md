# agenix-shell

Leveraging [age](https://github.com/FiloSottile/age) and [agenix](https://github.com/ryantm/agenix),
this project allows you to inject variables containing secrets into your flakes' `devShells`.

This simplifies the onboarding process for new developers by enabling secure secret sharing 
(with access control) and making projects more self-contained by eliminating the need for external tools.

## Usage

Basic knowledge of how [agenix](https://github.com/ryantm/agenix) works is required. 
It relies on the same setup as `agenix`:
- A `secrets` directory containing all the encrypted secrets.
- A `secrets.nix` file that lists the secrets and specifies which keys can decrypt each one.

Example of `secrets/secrets.nix`:
```nix
{
  "foo.age".publicKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDpVA+jisOuuNDeCJ67M11qUP8YY29cipajWzTFAobi"
  ];
}
```

While this is the format expected by `agenix`, you are not strictly bound to it, `agenix-shell` only requires you to specify the paths for the `.age` files, similar to `agenix` modules, following the `secrets/secrets.nix` structure is only useful if you want to use the `agenix` CLI.

`agenix-shell` injects two environment variables for each secret:
- One containing the cleartext secret itself.
- Another containing the path to the secret (automatically appending `_PATH` to the variable name).

For example:
- `foo`: Contains the secret.
- `foo_PATH`: Contains the path to the secret.

### Basic Usage

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

Check the [basic example](./templates/basic/) for a working setup. You'll need to delete the encrypted secret and encrypt your own using your key. Alternatively, you can use the [provided key](./checks/id_rsa) (**not for production use**).

Initialize with:
```bash
nix flake init -t github:aciceri/agenix-shell#basic
```

Internally, this approach uses `flake-parts` for argument evaluation. Refer to the [flake.parts documentation](https://flake.parts/options/agenix-shell) for a full list of options.

---

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

  perSystem = {pkgs, config, lib, ...}: {
    devShells.default = pkgs.mkShell {
      shellHook = ''
        source ${lib.getExe config.agenix-shell.installationScript}
      '';
    };
  };
}
```

Check the [flake-parts template](./templates/flake-parts) for a working example. Initialize with:
```bash
nix flake init -t github:aciceri/agenix-shell#flake-parts
```

---

### With `devenv`

Find a working template [here](./templates/devenv/).

Initialize with:
```bash
nix flake init -t github:aciceri/agenix-shell#devenv
```

---

## How It Works

The functionality is straightforward:
1. `agenix-shell` exports a configurable script, which is sourced in the `devShell` (e.g. via a `shellHook`).
2. The script:
   - Decrypts secrets using the user's SSH keys (default: `$HOME/.ssh/id_rsa` or `$HOME/.ssh/id_ed25519`).
   - Stores decrypted secrets in a secure location:
     - **Linux**: `$XDG_RUNTIME_DIR/agenix-shell/<hash>` (commonly mounted on `tmpfs`).
     - **Darwin**: `~/.agenix-shell/<hash>` (mounted on `hfs`, similar to `tmpfs`).
   - Declares two variables per secret:
     - One containing the secret itself.
     - Another containing the path to the secret.

Everything is highly customizable via options. Refer to [flake.parts](https://flake.parts/options/agenix-shell) for a complete list and defaults.

The script is hygienic:
- Intermediate variables are unset.
- A custom `PATH` is used to isolate dependencies (on Linux).
