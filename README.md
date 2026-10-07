# Machine

Declarative macOS setup for my machines.

## Set up a new machine

Run as the declared macOS user (`ro`), without `sudo`; the script asks for sudo
when needed:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcuswestin/machine/main/up.sh)"
```

Rerun the same command after an interrupted install, or run
`bash scripts/up-local.sh` from an existing checkout.

## Daily use

```sh
just help                      # List public workflows
just diff                      # Compare declared state with this Mac (read-only)
just apply-to-machine          # Apply the repo to this Mac; asks before restarting apps
just partial-apply-to-machine  # Apply without quitting or restarting apps
just import-from-machine       # Review settings changed in app UIs and promote them into the repo
just update                    # Update pinned taps and installed packages
just prune                     # Review and remove undeclared packages and extensions
just check                     # Validate the repo and this Mac's health (read-only)
```

See [configuration commands](docs/configuration-workflow.md) for details.
