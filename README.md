# Machine

Declarative macOS setup for my machines.

## Fresh Machine

Run the bootstrap script from a fresh macOS install:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcuswestin/machine/feat/declarative/up.sh)"
```

## Daily Command Surface

```sh
just up              # apply system/app/env/dotfile layers
just dotfiles-diff   # review chezmoi changes
just dotfiles-apply  # apply chezmoi changes directly
just doctor          # show tool and repo state
just check           # validate the flake
just import-current  # capture current machine state into inventory for review
```

## Ownership

- `nix-darwin`: system configuration, macOS defaults, Nix packages.
- `nix-homebrew`/Homebrew: GUI apps and Brew-specific packages.
- `home-manager`: PATH/env/session variables only.
- `chezmoi`: actual dotfiles and app config files.

The default flow applies the conservative dotfile set automatically. Use
`just dotfiles-diff` first when you want to preview changes manually.
