# Machine

Declarative macOS setup for my machines.

## Fresh Machine

Run the bootstrap script from a fresh macOS install:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcuswestin/machine/main/up.sh)"
```

## Daily Command Surface

```sh
just apply           # apply system/app/env/dotfile layers
just chezmoi-apply   # apply chezmoi from this repo
just git-auth        # authenticate GitHub CLI for GitHub HTTPS pushes
just verify          # validate the flake
just fmt             # format with dprint
just prune-diff      # show undeclared apps/extensions and dotfile drift
just prune           # prune undeclared apps/extensions and apply dotfiles
just import-current  # capture current machine state into inventory for review
```

## Ownership

- `nix-darwin`: system configuration, macOS defaults, Nix packages.
- `nix-homebrew`/Homebrew: GUI apps and Brew-specific packages.
- `home-manager`: PATH/env/session variables only.
- `chezmoi`: actual dotfiles and app config files.

The default flow applies system/app/env layers and the repo-owned chezmoi
dotfiles automatically. `just prune-diff` includes chezmoi drift alongside other
undeclared state.
