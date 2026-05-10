# Additional Current-Machine Review Surfaces

Reviewed on 2026-05-10. `just import-current` already captures Homebrew state,
selected macOS defaults, editor extensions, and a small set of home files. The
items below are additional surfaces worth considering, not active config.

## Strong Candidates

- [x] AeroSpace config: promoted through chezmoi as `home/dot_aerospace.toml`.
- [ ] Display layout: `displayplacer` is installed and repo capture/replay
  commands exist, but no replayable display arrangement has been captured yet.
- [ ] iTerm2 profile: iTerm2 preferences exist in
  `~/Library/Preferences/com.googlecode.iterm2.plist`. Review only durable
  profile/theme/hotkey settings; avoid saved state, sockets, chat databases, and
  other runtime files under `~/Library/Application Support/iTerm2`.
- [ ] Codex/agent setup: `~/.codex` contains potentially useful portable config
  such as `AGENTS.md`, `config.toml`, and `rules/default.rules`, but also auth,
  logs, SQLite state, sessions, caches, and memories. Handle this as a separate
  curated agent-setup review rather than a blind import.

## Probably Keep Manual Or App-Owned

- Raycast: preferences and Application Support contents are mostly app state,
  SQLite databases, IDs, analytics/update metadata, and remote model/extension
  caches. Prefer Raycast's own export/import path or specific stable defaults if
  a concrete setting matters.
- GitHub CLI: `~/.config/gh/config.yml` and `hosts.yml` exist, but auth is
  already handled by `just git-auth`; do not import host credentials.
- Launch agents and login items: current user launch agents are the Nix-owned
  startup app agents, and System Events reported no separate login items. Keep
  startup ownership in `modules/startup.nix`.
- SSH/GPG: no `~/.ssh` directory or obvious GPG agent config was present. Do
  not import keys or trust databases if they appear later; only consider
  non-secret client config.

## Existing Review Queues To Finish First

- `inventory/apps-review.md`: decide which deferred apps/packages are still
  wanted.
- `inventory/defaults-review.md`: decode and promote only stable defaults with
  comments.
- `inventory/dotfiles-review.md`: review imported home-file snapshots and
  promote only intentional, non-secret dotfiles.
