# Dotfiles To Review

The active chezmoi source now keeps only safe-core files. These imported files or
settings were removed from active management and can be reintroduced after
review.

## Removed From Active Chezmoi Source

| Item | Rationale |
| --- | --- |
| Cursor prompt-submit hook | logged prompt payloads to a temp file |
| Empty Cursor config and MCP files | no useful desired state |
| Empty Claude settings | no useful desired state |
| Continue config | contained dummy API keys and local model endpoints |
| Zed settings | app is not in the active app set |
| `.zprofile` local utility PATH | references a local repo that is not installed by this machine config |
| `.zshenv` Cargo sourcing | Home Manager owns session path now |
| project-specific zsh aliases | useful locally, but too brittle for safe-core fresh setup |
| LM Studio, Antigravity, Maestro, RVM PATH edits | apps/runtimes are not active safe-core installs |

## Review Import Location

`just import-current` writes snapshots to `inventory/home/`. Review those files
manually and promote only intentional changes into `home/`.
