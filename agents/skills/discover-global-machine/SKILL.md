---
name: discover-global-machine
description: Runs `just discover-global` in the machine repo to find unmanaged global machine surfaces that may be worth tracking later. Use when the user asks for discovery, entire-machine review, candidate app/defaults/config surfaces, or things not currently managed by the repo.
disable-model-invocation: true
---

# discover-global-machine

## What to run

From the machine repo root:

```sh
just discover-global
```

## What it does

Implemented by `scripts/discover-global.sh`. This is a review-only scan for unmanaged candidates, not a convergence check and not a prune/apply workflow. It writes full reports under `inventory-global/discovery/` and prints a short preview.

It reports:

- `/Applications` and `~/Applications` candidates not obviously owned by Homebrew Caskroom, Nix, or Apple.
- Defaults domains not in the tracked defaults capture list.
- Preference plist candidates under `~/Library/Preferences` and `/Library/Preferences`.
- LaunchAgents and LaunchDaemons candidates.
- Fonts outside system font directories.
- System extensions.
- Unmanaged shell snippets such as `~/.zprofile` and `~/.zshenv`.

## After it runs

- Summarize candidates by section.
- Point to `inventory-global/discovery/` for full lists when the preview is truncated.
- Do **not** promote discovered state into active config unless the user explicitly asks next.
- Do **not** run `just apply`, `just prune`, or `merge-in-settings` writes.
- For currently tracked drift, use the `diff-tracked-machine` skill instead.

## Related

| Purpose                                 | Command                  |
| --------------------------------------- | ------------------------ |
| Currently tracked drift                 | `just diff-tracked`      |
| Discovery of unmanaged candidates       | `just discover-global`   |
| Snapshot capture vs live only (private) | `just _snapshot-diff`    |
| Git worktree                            | `git status`, `git diff` |
