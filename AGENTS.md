# Agent Instructions

This repo is a personal declarative macOS machine setup. Treat it as an
operational repo: small changes, concrete validation, and no broad rewrites
unless asked.

## Primary Workflow

- Fresh-machine entrypoint: `up.sh`.
- Daily command surface: `just`.
- Steady-state apply command: `just apply`.
- Public commands are the recipes shown by `just --list`; implementation
  recipes are prefixed with `_` and should stay private.
- `up.sh` should remain minimal: install/load base Nix, ensure enough tooling to
  clone/update this repo, then hand off to `scripts/up-local.sh`.
- `scripts/up-local.sh` should invoke the declarative apply path with minimal
  bootstrap, not inspect and repair unexpected local state.

## Ownership Boundaries

- `nix-darwin`: system configuration, macOS defaults, Nix packages.
- `nix-homebrew` / Homebrew: GUI apps and Brew-specific packages.
- Home Manager: minimal PATH/env/session integration only.
- `chezmoi`: actual dotfiles under `home/`; editable configs live in `home/.dotfiles/`
  (hidden so chezmoi does not copy them) and are symlinked into `$HOME` via `symlink_*`
  templates.
- `inventory/`: review snapshots and deferred/imported machine state; do not
  blindly promote inventory entries into active config.

Prefer first-class nix-darwin options over custom activation scripts. Use custom
activation only when the option does not exist or macOS requires a special path.

## Editing Rules

- Use `apply_patch` for file edits.
- Keep active config conservative and deterministic for fresh machines.
- Do not import current-machine state into active config unless explicitly asked.
- Do not add secrets, auth files, histories, caches, telemetry, SQLite DBs,
  workspace storage, model caches, or session state.
- Keep branch/default install references pointed at `main` unless the user is
  explicitly testing another branch.
- Preserve the `MACHINE_*` environment overrides in scripts where present.
- Do not add safety checks, fallback branches, or workaround paths for
  unexpected machine state. This repo is declarative: if state is unexpected,
  fix the owning nix-darwin, Homebrew, Home Manager, or chezmoi declaration so
  every managed machine converges to the same expected state.
- Comment non-obvious settings where they are declared. For numeric or encoded
  values such as macOS defaults IDs, modifier bitmasks, key codes, separator
  characters, and state-version pins, look up what the value means and record
  that meaning in an adjacent comment.

## Validation

Run the smallest useful validation for the change. Common checks:

```sh
bash -n up.sh
bash -n scripts/up-local.sh
bash -n scripts/with-sudo-keepalive.sh
just --list
just --dry-run apply
nix flake check --extra-experimental-features 'nix-command flakes' --show-trace
```

For macOS defaults changes, also inspect the relevant nix-darwin option when
possible:

```sh
nix eval --extra-experimental-features 'nix-command flakes' \
  .#darwinConfigurations.machine.config.system.defaults
```

## Git

- Don't stage or commit changes unless asked to do so.
- Before committing, check `git status --short`.
- Commit only the files relevant to the completed fix.
- Push the current branch after a successful commit.
- If the worktree contains unrelated user changes, leave them alone, unless relevant to your change.

## Fresh-Machine Safety

- `just apply` may install apps, apply macOS defaults, apply chezmoi dotfiles, and
  install editor extensions.
- `just prune-diff` should show removals before `just prune-apply` executes
  them.
- Prune commands should stay conservative: only remove undeclared Homebrew
  leaves/casks and undeclared editor extensions.
- Keep sudo usage explicit. The sudo keepalive wrapper should prompt up front
  and only preserve the timestamp for commands that still invoke `sudo`
  themselves.
