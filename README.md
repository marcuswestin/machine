# Machine

Declarative macOS setup for my machines.

## Fresh Machine

Run the bootstrap script from a fresh macOS install:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcuswestin/machine/main/up.sh)"
```

## Daily Command Surface

```sh
just up              # apply system/app/env/dotfile layers
just dotfiles-diff   # review chezmoi changes
just dotfiles-apply  # apply chezmoi changes directly
just git-auth        # authenticate GitHub CLI for GitHub HTTPS pushes
just check           # validate the flake
just prune-diff      # show undeclared apps/extensions and dotfile drift
just prune-apply     # prune undeclared apps/extensions and apply dotfiles
just import-current  # capture current machine state into inventory for review
```

## Ownership

- `nix-darwin`: system configuration, macOS defaults, Nix packages.
- `nix-homebrew`/Homebrew: GUI apps and Brew-specific packages.
- `home-manager`: PATH/env/session variables only.
- `chezmoi`: actual dotfiles and app config files.

The default flow applies system/app/env layers and the repo-owned chezmoi
dotfiles automatically. Use `just dotfiles-diff` first when you want to preview
dotfile changes manually.
