# Machine

Declarative macOS setup for my machines.

The target is **macOS 27**, declared once as `TARGET_MACOS_MAJOR` in `up.sh`.
The installer, `scripts/up-local.sh`, and `just apply`, `just update`, and
`just upgrade` reject a different major version before making setup changes
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
# Or: MACHINE_ALLOW_UNSUPPORTED_MACOS=1 just apply
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

Thaw has verified install baselines for several macOS generations: 1.x
for macOS 14/15, 2.x for macOS 26, and 3.x for macOS 27. Discontinued Atlas is no
longer installed. Unrelated packages and untrusted legacy taps remain visible
through the existing prune review; setup does not grant them trust or delete
their application data. Upstream cask deprecation notices and Zoom's optional
post-install quit warning do not require local cleanup.

## Machine health

Run `just doctor` for a read-only operational health summary, or
`just doctor --json` for structured output. It checks Nix activation and required
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
`review-machine-repo` skill for that, `just diff-tracked` for tracked drift and
inventory capture, and `just verify` for repository validation. An active Nix
generation is not proof it matches the current Git tree; running apps are not
proof of functionality; import confirmation is not proof of live app settings.

## Ownership

- `nix-darwin`: system configuration, macOS defaults, Nix packages.
- `nix-homebrew`/Homebrew: GUI apps and Brew-specific packages.
- `home-manager`: PATH/env/session variables only.
- `chezmoi`: actual dotfiles and app config files.
- AeroSpace: window management and workspace navigation only.
- Karabiner-Elements: keyboard semantics, physical key behavior, and key
  remapping only. The managed `Machine` profile maps Caps Lock to Escape when
  tapped alone and Control while held with another key. Escape is sent on release
  (Karabiner's default tap timeout is one second). nix-darwin clears its older
  Caps-to-Control mapping so Karabiner receives the original key. Enable
  Karabiner's requested macOS permissions on each Mac; test both a tap and a
  Control shortcut after `just apply`. No Mac restart is needed for the rule.

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
dotfiles automatically. After the system switch, the existing cask quarantine
cleanup runs first, before settings reloads, Raycast import, editor commands,
or startup app launches. The login LaunchAgent defers to the apply process while
it is running, so loading the agent during the switch cannot launch apps early.
Dotfiles and app settings are applied before Xcode downloads, GitHub sign-in,
and Raycast import, so an interruption in those steps leaves the settings in
place. `chezmoi-apply` stops Handy first and downloads its configured transcription
model before applying settings. The existing Parakeet TDT 0.6B v3 Q8 model is
pinned by revision and SHA-256 in `config/handy/models.json`; verified existing
files in Handy's model folder or its Hugging Face cache are reused. Downloads
stay outside Git. `just diff-tracked` reports missing or mismatched model files.
Handy's managed shortcut is hold Right Command; the full apply launches Handy
afterward, or reopen it manually after running only `just chezmoi-apply`.

Raycast's first-launch tour and Stats' setup wizard are disabled by declared
preferences before startup. This does not grant macOS privacy permissions or
sign into app accounts. Raycast's separate settings import may still ask for
confirmation. If a setup window was already open during an apply, close or
restart the app to load its declared preferences.
`just prune-diff` includes chezmoi drift alongside other undeclared state.
