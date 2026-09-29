# Machine

Declarative macOS setup for my machines.

The target is **macOS 27**, declared once as `TARGET_MACOS_MAJOR` in `up.sh`.
The installer, `scripts/up-local.sh`, `just apply-to-machine`, and `just update`
reject a different major version before making setup changes
or prompting for sudo. Minor and patch releases within that major are allowed.
When adopting another macOS major, update that declaration after validating
the setup on it. `system.stateVersion` is a separate nix-darwin migration pin.

Check the current machine without applying anything:

```sh
bash up.sh --check-os
```

To deliberately test another macOS major, override only for that invocation:

```sh
MACHINE_ALLOW_UNSUPPORTED_MACOS=1 bash scripts/up-local.sh
# Or: MACHINE_ALLOW_UNSUPPORTED_MACOS=1 just apply-to-machine
```

The same environment override works with the fresh-machine installer below.
It bypasses this repo's version check; individual packages still enforce their
own macOS requirements.

Setup a new machine:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/marcuswestin/machine/main/up.sh)"
```

Run this as the declared macOS user (`ro`), without prefixing it with `sudo`;
the script requests sudo where needed. Rerun the same command after an
interrupted install, or run `bash scripts/up-local.sh` from an existing checkout.
Command Line Tools are installed before Homebrew packages. Homebrew directory
ownership and trust for declared third-party packages (including local casks)
are applied on every system switch, so no manual `brew trust` step is needed.
Xcode/App Store and GitHub sign-in may still require interaction.

The apply path also updates Command Line Tools through Software Update, replaces
the old Claude Code cask with the declared latest channel, and removes the
standalone CodexBar formula before installing the app that includes its CLI.
These replacements preserve application settings and credentials. After package
installation it relinks unlinked, non-keg-only dependencies, registers JDK 17
with macOS, and ensures the Ollama service required by Continue is started.
It also corrects ownership of Homebrew's zsh completion files (including linked
targets outside the Nix store), so migrated files do not trigger `compinit`
security prompts. The old Codex CLI 0.130.0 is upgraded to the pinned cask because
macOS rejects that release's signature; other versions retain the normal
no-upgrade behavior. This does not disable Gatekeeper or XProtect.
The `chatgpt` cask installs the current ChatGPT/Codex desktop app on fresh Macs;
the separate terminal Codex CLI comes from the `codex` cask. Homebrew's old
`codex-app` cask is deprecated and expects a separate `Codex.app`.

Thaw has verified install baselines for several macOS generations: 1.x
for macOS 14/15, 2.x for macOS 26, and 3.x for macOS 27. Discontinued Atlas is no
longer installed. Unrelated packages and untrusted legacy taps remain visible
through the existing prune review; setup does not grant them trust or delete
their application data. Upstream cask deprecation notices and Zoom's optional
post-install quit warning do not require local cleanup.

## Machine health

Run `just check machine` for a read-only operational health summary, or
`just check machine --json` for structured output. It checks Nix activation and required
background permissions, declared startup apps and package paths, keyboard
mapping, managed editor/Handy/Karabiner configs, Handy's model checksum, AeroSpace,
Codex drift, Thaw's last confirmation, and Time Machine destination configuration.

Results distinguish `OK`, `WARN` (attention needed), `FAIL` (detected problem),
and `UNKNOWN` (not verified, including access failures). Exit codes are 0 for all
OK, 1 if any check fails, and 2 for warnings/unverified checks without a failure.
Checks continue after individual failures. `MACHINE_HOST` selects the Nix host;
Nix evaluates cached locked inputs offline and does not update the lock file.
The command does not apply, upgrade, restart apps, prompt for sudo, grant
permissions, mount backups, or write inventory snapshots. Tools may use their
normal read/evaluation caches. It reports suggested actions without executing them.

This is not a security advisory scan or full installed-version audit. Use the
`review-machine-repo` skill for that, `just diff` for read-only tracked drift,
`just discover snapshot tracked` for an optional local snapshot, and `just check repo`
for repository validation. An active Nix
generation is not proof it matches the current Git tree; running apps are not
proof of functionality; import confirmation is not proof of live app settings.

## Ownership

- `nix-darwin`: system configuration, macOS defaults, Nix packages.
- `nix-homebrew`/Homebrew: GUI apps and Brew-specific packages.
- `home-manager`: PATH/env/session variables only.
- `chezmoi`: actual dotfiles and app config files.
- Global Codex and Claude instructions share
  `home/.dotfiles/agents/global-instructions.md`. Chezmoi renders it into
  `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md`; edit the shared source and run
  `just apply-to-machine dotfiles` to distribute changes. These are regular files because
  Claude Cowork skips global instruction symlinks outside its working directory.
  New sessions load the rule to keep automation windows in the background when
  supported. These instructions do not change either tool's writable local state.
- AeroSpace: window management and workspace navigation only.
- Karabiner-Elements: keyboard semantics, physical key behavior, and key
  remapping only. The managed `Machine` profile maps Caps Lock to Escape when
  tapped alone and Control while held with another key. Escape is sent on release
  (the declared tap timeout is 500 ms). nix-darwin clears its older
  Caps-to-Control mapping so Karabiner receives the original key. Enable
  Karabiner's requested macOS permissions on each Mac; test both a tap and a
  Control shortcut after `just apply-to-machine`. Chezmoi renders a regular
  `~/.config/karabiner/karabiner.json` from the tracked source because Karabiner
  does not reload changes when that file is a symlink. No Mac restart is needed
  for the rule.

`just apply-to-machine` installs missing Homebrew packages but does not upgrade or
downgrade apps that are already present, including those that self-update.
The Homebrew tap commits in `flake.lock` supply install versions for ordinary
casks. Local casks under `homebrew/local/` pin a verified release and checksum
for fresh installs. An app that updates itself may run a newer version than its
Homebrew receipt or local cask; that difference is reported during review, not
automatically copied into a pin. Advance a local pin after checking the upstream
release, download, and compatibility with this Mac.

`just update casks` upgrades outdated declared casks that Homebrew manages. It leaves
self-updating apps to their own updaters; name one explicitly to upgrade it
through Homebrew. `just update` bumps the Homebrew tap pins in `flake.lock`,
applies, then upgrades declared formulae and Homebrew-managed casks. The upgrade
script keeps declared tap-qualified names and skips targets older than their
installed Homebrew receipts.

The default flow applies system/app/env layers and the repo-owned chezmoi
dotfiles automatically. After the system switch, the existing cask quarantine
cleanup runs first, before settings reloads, Raycast import, editor commands,
or startup app launches. The login LaunchAgent defers to the apply process while
it is running, so loading the agent during the switch cannot launch apps early.
Dotfiles and app settings are applied before Xcode downloads, GitHub sign-in,
and Raycast import, so an interruption in those steps leaves the settings in
place. The dotfiles apply provisions Handy's configured transcription
model before applying settings. The existing Parakeet TDT 0.6B v3 Q8 model is
pinned by revision and SHA-256 in `config/handy/models.json`; verified existing
files in Handy's model folder or its Hugging Face cache are reused. Downloads
stay outside Git. `just diff` reports missing or mismatched model files.
Handy's managed shortcut is hold Right Command; the full apply launches Handy
afterward, or reopen it manually after running only `just apply-to-machine dotfiles`.

Raycast's first-launch tour and Stats' setup wizard are disabled by declared
preferences before startup. This does not grant macOS privacy permissions or
sign into app accounts. Raycast's separate settings import may still ask for
confirmation. If a setup window was already open during an apply, close or
restart the app to load its declared preferences.

Stats' module selection and menu bar widgets are declared in
`modules/defaults/apps.nix`: Battery, CPU, Disk, GPU, Network, RAM, and Sensors.
Chart labels, numeric values, and the selected display styles are tracked too.
Stats combines these widgets into one menu bar item, ordered left to right:
**GPU → Network → Disk → Sensors → RAM → CPU → Battery**. Clicking a metric still
opens its own popup. Stats owns this internal order; Thaw owns the position of
the whole group. Hardware-unavailable modules are omitted without reordering
the others. After switching from separate items, place the single group in Thaw
if necessary; a previously exported profile can still contain obsolete individual
Stats entries. Use `just import-from-machine thaw` after adjusting the overall layout.
On another Mac, quit Stats before `just apply-to-machine`, then reopen Stats; no Mac restart
is needed. Stats can omit modules that the hardware does not support. If its
items are still absent, check System Settings → Menu Bar → Stats and Thaw's
visibility settings. `just diff` compares the declared preferences with
saved Stats preferences; run `bash scripts/check-stats-config.sh` for that check
alone. Remote pairing, updater state, and window state remain local.

CodexBar's menu appearance is declared in `modules/defaults/apps.nix`. Its enabled
providers are declared in `config/codexbar/providers.json` and applied through
CodexBar's public CLI, preserving local account credentials. Quit CodexBar before
applying preference changes and reopen it afterward. The highest-usage provider
selection can show a different provider icon on each Mac because usage and
authenticated accounts differ.

Thaw's saved profile pins Handy, ChatGPT/Codex, and Cursor to the hidden section
by bundle ID. New items use the visible section's default placement, avoiding a
workspace-dependent AeroSpace anchor. Import and apply the updated native profile
when prompted; adjust display associations on another Mac. Profiles position
existing items; they do not enable Weather or other macOS controls. Sound visibility
is declared through nix-darwin. macOS has no declared Weather menu control in this
repo: `just apply-to-machine full` asks you to confirm System Settings > Menu Bar > Weather
and its visible menu bar item. The former UI script could not reliably read that
control even with iTerm's permissions enabled, so apply no longer runs it.
Weather's first location determines the displayed city; location permissions
and list order stay local.
Raycast imports now record completion only after you confirm the native import;
older stamps that recorded merely opening the export are not accepted as proof.

`just diff settings` reports saved custom app-defaults drift, CodexBar provider
toggles, managed JSON/file drift, and Codex overrides and Thaw/Raycast confirmations.
It prints a manual Weather check instead of claiming to read that UI state. It does not write settings and
prints preference key names, not private values. A successful command means the
report ran; it does not mean every app is configured. It excludes first-class
macOS defaults, other live UI layout, permissions, and untracked settings. See the
[configuration coverage review](docs/reviews/2026-09-26-configuration-sync.md)
for remaining gaps and verification steps. `just discover apps` inventories
candidate paths and preference keys locally; it does not import those settings.

Additional portable settings are managed for Claude Desktop (a narrow recursive
JSON merge), Antigravity IDE (chezmoi), iTerm2 (visual Dynamic Profile and default
profile GUID), and the current ChatGPT launcher helper (custom defaults).
Claude's account/session/permission fields remain writable and local; quit Claude
before applying differing preferences. iTerm's Machine profile now explicitly
contains the colors/fonts from this Mac instead of inheriting its entire appearance.
Chrome's iCloud Passwords extension is declared for review; the guided full apply
asks you to install it from its Chrome Web Store page. Browser accounts and bookmarks
remain owned by browser sync. Docker settings access failures now fail the apply
step instead of reporting success with skipped settings.
`just diff` reports a declared browser extension missing on the Mac in words;
the raw `-`/`+` diff is no longer used for that section. The repo still keeps
iCloud Passwords. `just import-from-machine browser` reviews browser extensions one
at a time, and refuses to interpret an unreadable browser profile as empty.

Use the [single-pass verification checklist](docs/reviews/2026-09-27-settings-acceptance.md)
after applying on each Mac. These declarations do not replace app credentials,
privacy permission prompts, or per-display Thaw associations.

Use `just diff` for a read-only comparison. `just apply-to-machine` installs and applies
declarations without intentionally quitting desktop apps; it prints apps with
pending restart work. `just apply-to-machine full` is the guided pass: it lists affected
running apps, waits for Enter, then quits only those apps, applies settings,
reopens them in the background, and walks through native imports and visual
verification. Docker containers may be interrupted when Docker needs restarting.
Ctrl-C/EOF leaves a native import confirmation pending. Neither command reboots
the Mac. `just import-from-machine` reviews portable values changed in the UI
and selectively promotes them into the repo. See
[configuration commands](docs/configuration-workflow.md) for scope and limits.

Codex's `config/codex/config.toml` is a per-user key allowlist. Apply merges
missing declared keys into writable `~/.codex/config.toml`, leaving project
trust, app state, and unlisted keys alone. If a declared key changed in the UI,
apply stops before the system switch and asks for review through
`just import-from-machine`. The repo file is never silently overwritten.

`just prune plan` previews undeclared package and extension removals; chezmoi
drift appears in `just diff` and is never a prune candidate.
