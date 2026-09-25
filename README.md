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
- AeroSpace: window management and workspace navigation only.
- Karabiner-Elements: keyboard semantics, physical key behavior, and key
  remapping only. The checked-in `karabiner.json` is the managed profile
  scaffold; remaps are added there as they are decided.

`just apply` installs missing Homebrew packages but does not upgrade or
downgrade apps that are already present, including those that self-update.
The Homebrew tap commits in `flake.lock` supply install versions for ordinary
casks. Local casks under `homebrew/local/` pin a verified release and checksum
for fresh installs. An app that updates itself may run a newer version than its
Homebrew receipt or local cask; that difference is reported during review, not
automatically copied into a pin. Advance a local pin after checking the upstream
release, download, and compatibility with this Mac.

`just upgrade` upgrades outdated declared casks that Homebrew manages. It leaves
self-updating apps to their own updaters; name one explicitly to upgrade it
through Homebrew. `just update` bumps the Homebrew tap pins in `flake.lock`,
applies, then upgrades declared formulae and Homebrew-managed casks. The upgrade
script keeps declared tap-qualified names and skips targets older than their
installed Homebrew receipts.

The default flow applies system/app/env layers and the repo-owned chezmoi
dotfiles automatically. `just prune-diff` includes chezmoi drift alongside other
undeclared state.
