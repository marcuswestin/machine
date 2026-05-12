# Machine

Declarative macOS setup for my machines.

Setup a new machine:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcuswestin/machine/main/up.sh)"
```

## Ownership

- `nix-darwin`: system configuration, macOS defaults, Nix packages.
- `nix-homebrew`/Homebrew: GUI apps and Brew-specific packages.
- `home-manager`: PATH/env/session variables only.
- `chezmoi`: actual dotfiles and app config files.

The default flow applies system/app/env layers and the repo-owned chezmoi
dotfiles automatically. `just prune-diff` includes chezmoi drift alongside other
undeclared state.
