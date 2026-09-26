set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

export PATH := "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:" + env_var_or_default("PATH", "")

REPO := justfile_directory()
HOST := env_var_or_default("MACHINE_HOST", "machine")
NIX_CMD := "nix --extra-experimental-features 'nix-command flakes'"

# List all recipes
help:
    @just --list

# Read-only machine health summary; --json emits structured results (no repairs).
doctor *args:
    @bun "{{ REPO }}/scripts/doctor.ts" {{ args }}

# Update system/app/env/dotfile layers and install editor extensions.
apply: _check-macos
    @scripts/with-sudo-keepalive.sh just _apply

# Apply dotfile changes with chezmoi
chezmoi-apply:
    @bash "{{ REPO }}/scripts/setup-handy.sh" "{{ REPO }}"
    chezmoi apply --force --no-tty --source "{{ REPO }}/home"
    @bun "{{ REPO }}/scripts/repo-settings-import.ts" "{{ REPO }}" --push-docker-live
    @"{{ REPO }}/scripts/aerospace-reload-config.sh"

# Capture machine state into inventory-tracked/ or inventory-global/ (see AGENTS.md).
import-inventory scope="global":
    @"{{ REPO }}/scripts/import-inventory.sh" "{{ scope }}"

# Guide a Thaw profile export and save its JSON in the repo (optional file path).
export-thaw source="":
    @bash "{{ REPO }}/scripts/export-thaw.sh" {{ quote(source) }}

# Run tracked inventory import, then report drift for currently managed surfaces.
diff-tracked:
    @"{{ REPO }}/scripts/diff-tracked.sh"

# Discover unmanaged global machine surfaces that may be worth tracking.
discover-global:
    @"{{ REPO }}/scripts/discover-global.sh"

# Discover persisted app settings candidates for declared Homebrew casks.
discover-app-settings:
    bun "{{ REPO }}/scripts/app-settings-candidates.ts"

# Merge live app JSON/JSONC into chezmoi-backed repo files (report by default; see scripts/repo-settings-import.ts).
merge-in-settings *args:
    bun "{{ REPO }}/scripts/repo-settings-import.ts" "{{ REPO }}" {{ args }}

# Authenticate GitHub CLI and configure GitHub HTTPS pushes.
git-auth:
    @just _git-auth

# Homebrew, editor extensions, and chezmoi only (used by `_prune-check` and `diff-tracked`).
prune-diff:
    @just _prune-homebrew-diff
    @just _prune-editor-extensions-diff
    @just _prune-dotfiles-diff

# Remove undeclared Homebrew formulae/casks and editor extensions, then apply dotfiles.
prune:
    @just _prune-homebrew-apply
    @just _prune-editor-extensions-apply
    @just chezmoi-apply

# Upgrade outdated declared Homebrew casks. Name a self-updating cask to upgrade it deliberately.
upgrade *casks: _check-macos
    @bash scripts/upgrade-homebrew-casks.sh "{{ HOST }}" {{ casks }}

# Bump Homebrew and tap pins, apply, then upgrade declared formulae and casks.
update: _check-macos
    {{ NIX_CMD }} flake update nix-homebrew homebrew-cask homebrew-anomalyco-tap homebrew-nikitabobko-tap homebrew-steipete-tap
    @just apply
    @scripts/update-homebrew-apps.sh "{{ HOST }}"
    @just upgrade
    @just _unquarantine-cask-apps

# Format repo files with dprint. Uses `./dprint.json` at repo root (extends chezmoi-config).
fmt:
    dprint fmt .

# Validate the Nix flake without applying it.
verify:
    dprint check .
    @"{{ REPO }}/scripts/check-vscode-family-symlinks.sh" "{{ REPO }}"
    {{ NIX_CMD }} flake check --show-trace

# Private recipes
#################

# Check the same macOS baseline as the single-file bootstrap, without applying.
_check-macos:
    @bash "{{ REPO }}/up.sh" --check-os

# Report enabled Login Items / background tasks outside startupApps + known prefixes.
_audit-login-items:
    @"{{ REPO }}/scripts/audit-login-items.sh" "{{ REPO }}"

# If config/raycast/settings.json changed, gzip + open for Raycast import (see scripts/raycast-settings-sync.sh).
_raycast-settings-sync:
    @"{{ REPO }}/scripts/raycast-settings-sync.sh" "{{ REPO }}"

# Guide native Thaw import/apply when its saved profile changes; use force to repeat.
_thaw-profile-sync mode="apply":
    @bash "{{ REPO }}/scripts/thaw-profile-sync.sh" {{ quote(mode) }}

# Diff captured files under inventory-tracked/ or inventory-global/ vs current machine.
_snapshot-diff scope="global":
    @"{{ REPO }}/scripts/snapshot-diff.sh" "{{ scope }}"

# Write readable plist sidecars (default: inventory-global/defaults when no args).
_plist-sidecars *paths:
    @"{{ REPO }}/scripts/plist-sidecars.sh" {{ paths }}

# Force Raycast .rayconfig rebuild + open (ignores change stamp). Normal path: `import-inventory global` or `_after-switch`.
_raycast-import-force:
    @"{{ REPO }}/scripts/raycast-settings-sync.sh" "{{ REPO }}" force

# Apply
#####

_apply:
    #!/usr/bin/env bash
    set -euo pipefail
    # The login LaunchAgent is loaded during the system switch. Defer it until
    # this apply has cleared quarantine and installed settings; apps are opened
    # explicitly at the end of _after-switch. The PID lets login ignore a stale
    # marker left by an interrupted/killed apply.
    startup_marker="$HOME/.local/state/machine/apply-in-progress"
    mkdir -p "$(dirname "$startup_marker")"
    printf '%s\n' "$$" > "$startup_marker"
    trap 'rm -f "$startup_marker"' EXIT
    bash "{{ REPO }}/scripts/setup-clt.sh"
    just _system-switch
    just _after-switch
    echo "Machine setup complete."
    just _prune-check

# System switch
###############

# `darwin-rebuild switch` for this flake (nix-darwin system generation).
_system-switch host=HOST:
    sudo -H env "PATH=$PATH" {{ NIX_CMD }} run "{{ REPO }}#darwin-rebuild" -- switch --flake "{{ REPO }}#{{ host }}"

# After switch
##############

# Clear quarantine before settings reloads or app launches; apply settings before Xcode.
_after-switch:
    @just _unquarantine-cask-apps
    @just chezmoi-apply
    @just _attention-required
    @just _ensure-code-repos
    @echo "Installing editor extensions (may take a while)..."
    @just _install-editor-extensions
    @echo "Opening startup apps..."
    @just _launch-startup-apps
    @"{{ REPO }}/scripts/aerospace-reload-config.sh"

_attention-required:
    @echo "Checking attention-required setup: Xcode/App Store, GitHub authentication, Raycast, and Thaw profiles."
    @just _setup-xcode
    @just git-auth
    @just _raycast-settings-sync
    @just _thaw-profile-sync

_git-auth:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
      "{{ REPO }}/scripts/attention.sh" \
        "GitHub authentication needs attention" \
        "GitHub CLI is not authenticated; a browser login will open and Terminal will wait."
      gh auth login --hostname github.com --git-protocol https --web
    fi

_setup-xcode:
    @scripts/setup-xcode.sh

_ensure-code-repos:
    @scripts/ensure-code-repos.sh

_unquarantine-cask-apps:
    @scripts/unquarantine-cask-apps.sh "{{ REPO }}" "{{ HOST }}"

_install-editor-extensions:
    @scripts/editor-extensions.sh install

_launch-startup-apps:
    #!/usr/bin/env bash
    set -euo pipefail

    # Join startup app args with ASCII Unit Separator (0x1f, octal 037) so
    # spaces inside individual args survive TSV parsing.
    {{ NIX_CMD }} eval --json .#darwinConfigurations.{{ HOST }}.config.machine.startupApps \
      | jq -r '.[] | [.name, .appPath, .executable, (.args | join("\u001f"))] | @tsv' \
      | while IFS=$'\t' read -r name app_path executable args_joined; do
          [ -n "$name" ] || continue

          process_name="$(basename "$executable")"
          if pgrep -x "$process_name" >/dev/null 2>&1 \
            || pgrep -f "$executable" >/dev/null 2>&1; then
            printf '%s already running\n' "$name"
            continue
          fi

          if /usr/bin/open -gj "$app_path"; then
            continue
          fi

          # ASCII Unit Separator (0x1f, octal 037), matching the jq join above.
          IFS=$'\037' read -r -a args <<< "$args_joined"
          nohup "$executable" "${args[@]}" >/dev/null 2>&1 &
          continue
        done

# Prune
#######

_prune-check:
    @set +e; \
      output="$(just prune-diff 2>&1)"; \
      status="$?"; \
      set -e; \
      if [ "$status" -ne 0 ]; then \
        printf '\nPrune check failed:\n%s\n' "$output" >&2; \
      elif printf '%s\n' "$output" | grep -Eq 'Would uninstall|Undeclared .* extensions|^diff --git'; then \
        printf '\nPrune candidates found:\n%s\n\nRun this to prune them:\n  just prune\n' "$output"; \
      else \
        printf '\nNo prune candidates found.\n'; \
      fi

_prune-homebrew-diff:
    @scripts/prune-homebrew.sh diff "{{ HOST }}"

_prune-homebrew-apply:
    @scripts/prune-homebrew.sh apply "{{ HOST }}"

_prune-editor-extensions-diff:
    @scripts/editor-extensions.sh prune-diff

_prune-editor-extensions-apply:
    @scripts/editor-extensions.sh prune-apply

_prune-dotfiles-diff:
    @chezmoi diff --source "{{ REPO }}/home" || true

# Display layout
##############

_display-layout-apply:
    @scripts/display-layout.sh

_display-layout-capture file="scripts/display-layout.sh":
    #!/usr/bin/env bash
    set -euo pipefail

    command="$(displayplacer list | awk '/^displayplacer( |$)/ { print; exit }')"
    if [ -z "$command" ] || [ "$command" = "displayplacer" ]; then
      printf 'No replayable display layout found. Connect and arrange the displays, then rerun this recipe.\n' >&2
      exit 1
    fi

    # Avoid a leading-indented heredoc here; those spaces break the shebang line.
    printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' '' '# Captured from the current macOS display arrangement with displayplacer.' "exec $command" > "{{ file }}"
    chmod +x "{{ file }}"
    printf 'Captured display layout in %s\n' "{{ file }}"

# Flake
#######

_update:
    {{ NIX_CMD }} flake update
