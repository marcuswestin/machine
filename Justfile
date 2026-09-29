set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

export PATH := "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:" + env_var_or_default("PATH", "")

REPO := justfile_directory()
HOST := env_var_or_default("MACHINE_HOST", "machine")
NIX_CMD := "nix --extra-experimental-features 'nix-command flakes'"

# List public workflows.
help:
    @just --list --unsorted

# Apply repo declarations to this Mac; full restarts apps, dotfiles limits the scope.
[group('Configure')]
apply-to-machine mode="normal":
    #!/usr/bin/env bash
    set -euo pipefail
    printf 'Starting apply-to-machine (%s). Checking the selected workflow...\n' {{ quote(mode) }}
    case {{ quote(mode) }} in
      normal) MACHINE_APPLY_MODE=basic just _apply-to-machine ;;
      full) bash "{{ REPO }}/scripts/settings-apply.sh" ;;
      dotfiles) MACHINE_APPLY_MODE=basic just _chezmoi-apply ;;
      *) printf 'usage: just apply-to-machine [normal|full|dotfiles]\n' >&2; exit 64 ;;
    esac

# Review portable machine settings and import selected values into the repo.
[group('Configure')]
import-from-machine scope="all":
    @bash "{{ REPO }}/scripts/save-machine-settings.sh" {{ quote(scope) }}

# Compare declared state with this Mac; snapshot compares an earlier local capture.
[group('Inspect')]
diff scope="all" inventory="tracked":
    #!/usr/bin/env bash
    set -euo pipefail
    case {{ quote(scope) }} in
      all) "{{ REPO }}/scripts/diff-tracked.sh" ;;
      settings) just _settings-check ;;
      prune) just _prune-removals-diff ;;
      snapshot) just _snapshot-diff {{ quote(inventory) }} ;;
      *) printf 'usage: just diff [all|settings|prune|snapshot [tracked|global]]\n' >&2; exit 64 ;;
    esac

# Validate repo source, current machine health, or both (read-only).
[group('Inspect')]
[positional-arguments]
check scope="all" *args:
    #!/usr/bin/env bash
    set -euo pipefail
    scope="$1"
    shift
    case "$scope" in
      repo)
        if (( $# != 0 )); then
          printf 'usage: just check [all|repo|machine [--json]]\n' >&2
          exit 64
        fi
        just _verify
        ;;
      machine) just _doctor "$@" ;;
      all)
        if (( $# != 0 )); then
          printf 'usage: just check [all|repo|machine [--json]]\n' >&2
          exit 64
        fi
        repo_status=0
        machine_status=0
        just _verify || repo_status=$?
        just _doctor || machine_status=$?
        if (( (repo_status != 0 && repo_status != 2) || (machine_status != 0 && machine_status != 2) )); then exit 1; fi
        if (( repo_status != 0 || machine_status != 0 )); then exit 2; fi
        ;;
      *) printf 'usage: just check [all|repo|machine [--json]]\n' >&2; exit 64 ;;
    esac

# Find unmanaged candidates, or capture an ignored local inventory snapshot.
[group('Inspect')]
discover scope="global" inventory="tracked":
    #!/usr/bin/env bash
    set -euo pipefail
    case {{ quote(scope) }} in
      global) "{{ REPO }}/scripts/discover-global.sh" ;;
      apps) bun "{{ REPO }}/scripts/app-settings-candidates.ts" ;;
      snapshot) "{{ REPO }}/scripts/import-inventory.sh" {{ quote(inventory) }} ;;
      *) printf 'usage: just discover [global|apps|snapshot [tracked|global]]\n' >&2; exit 64 ;;
    esac

# Update pinned taps and installed packages, or upgrade declared casks only.
[group('Maintain')]
[positional-arguments]
update scope="all" *casks:
    #!/usr/bin/env bash
    set -euo pipefail
    scope="$1"
    shift
    case "$scope" in
      all)
        if (( $# != 0 )); then
          printf 'usage: just update [all|casks [cask...]]\n' >&2
          exit 64
        fi
        just _update-all
        ;;
      casks) just _upgrade "$@" ;;
      *) printf 'usage: just update [all|casks [cask...]]\n' >&2; exit 64 ;;
    esac

# Review undeclared package/extension removals and confirm before pruning.
[group('Maintain')]
prune mode="prompt":
    #!/usr/bin/env bash
    set -euo pipefail
    candidates="$(just _prune-removals-diff)"
    if [[ -z "$candidates" ]]; then
      printf 'No prune candidates found.\n'
      exit 0
    fi
    printf '%s\n' "$candidates"
    case {{ quote(mode) }} in
      prompt)
        if [[ ! -t 0 ]]; then
          printf 'No interactive terminal; nothing was removed. Run just prune in a terminal to confirm.\n'
          exit 0
        fi
        printf 'Remove these packages and extensions? Homebrew may quit affected apps. [y/N] '
        IFS= read -r answer || answer=""
        case "$answer" in
          y|Y|yes|YES|Yes) ;;
          *) printf 'Prune cancelled; nothing was removed.\n'; exit 0 ;;
        esac
        ;;
      plan)
        printf 'Preview only; nothing was removed.\n'
        exit 0
        ;;
      apply) ;;
      *) printf 'usage: just prune [prompt|plan|apply]\n' >&2; exit 64 ;;
    esac
    printf 'Removing the listed undeclared packages and editor extensions...\n'
    just _prune-homebrew-apply
    just _prune-editor-extensions-apply

# Format repo files with dprint.
[group('Develop')]
fmt:
    dprint fmt .

# Hidden compatibility names; new workflows use the grouped public recipes.
[private]
apply: apply-to-machine
[private]
apply-full:
    @just apply-to-machine full
[private]
apply-settings: apply-full
[private]
settings-apply: apply-full
[private]
chezmoi-apply: _chezmoi-apply
[private]
save-machine-settings scope="all":
    @just import-from-machine {{ quote(scope) }}
[private]
diff-tracked: diff
[private]
prune-diff: _prune-removals-diff
[private]
doctor *args:
    @just _doctor {{ args }}
[private]
verify: _verify
[private]
upgrade *casks:
    @just _upgrade {{ casks }}
[private]
discover-global:
    @just discover global
[private]
discover-app-settings:
    @just discover apps
[private]
import-inventory scope="global":
    @just discover snapshot {{ quote(scope) }}
[private]
export-thaw source="":
    @bash "{{ REPO }}/scripts/export-thaw.sh" {{ quote(source) }}
[private]
settings-check: _settings-check
[private]
merge-in-settings *args:
    @bun "{{ REPO }}/scripts/repo-settings-import.ts" "{{ REPO }}" {{ args }}
[private]
git-auth: _git-auth

# Private implementation recipes.
_apply-to-machine: _check-macos
    @echo "Checking Codex configuration for conflicts before making changes..."
    @bun "{{ REPO }}/scripts/codex-config-sync.ts" preflight
    @echo "Preparing sudo access for the machine apply..."
    @scripts/with-sudo-keepalive.sh just _apply

_chezmoi-apply:
    @echo "Checking the declared Handy model..."
    @bash "{{ REPO }}/scripts/setup-handy.sh" "{{ REPO }}"
    @echo "Applying managed dotfiles with chezmoi..."
    chezmoi apply --force --no-tty --source "{{ REPO }}/home"
    @echo "Applying or checking managed app settings that depend on dotfiles..."
    @if [[ "${MACHINE_SKIP_DOCKER:-0}" == 1 ]]; then \
      echo "Docker settings skipped for this apply (MACHINE_SKIP_DOCKER=1)."; \
    elif [[ "${MACHINE_APPLY_MODE:-basic}" == full ]]; then \
      bun "{{ REPO }}/scripts/repo-settings-import.ts" "{{ REPO }}" --push-docker-live; \
    else \
      echo "Docker live settings deferred to just apply-to-machine full."; \
    fi
    @"{{ REPO }}/scripts/aerospace-reload-config.sh"

_settings-check:
    @/usr/bin/python3 "{{ REPO }}/scripts/check-app-defaults.py" "{{ HOST }}"
    @bun "{{ REPO }}/scripts/app-preferences.ts" check
    @bun "{{ REPO }}/scripts/repo-settings-import.ts" "{{ REPO }}" --diff
    @bash "{{ REPO }}/scripts/codexbar-settings-sync.sh" check
    @"{{ REPO }}/scripts/check-codex-config.sh" "{{ REPO }}"
    @bash "{{ REPO }}/scripts/thaw-profile-sync.sh" check
    @bash "{{ REPO }}/scripts/raycast-settings-sync.sh" "{{ REPO }}" check

_prune-removals-diff:
    @just _prune-homebrew-diff
    @just _prune-editor-extensions-diff

_doctor *args:
    @bun "{{ REPO }}/scripts/doctor.ts" {{ args }}

_verify:
    dprint check .
    @"{{ REPO }}/scripts/check-vscode-family-symlinks.sh" "{{ REPO }}"
    {{ NIX_CMD }} flake check --show-trace

[positional-arguments]
_upgrade *casks: _check-macos
    @bash scripts/upgrade-homebrew-casks.sh "{{ HOST }}" "$@"

_update-all: _check-macos
    {{ NIX_CMD }} flake update nix-homebrew homebrew-cask homebrew-anomalyco-tap homebrew-nikitabobko-tap homebrew-steipete-tap
    @just apply-to-machine
    @scripts/update-homebrew-apps.sh "{{ HOST }}"
    @just _upgrade
    @just _unquarantine-cask-apps

# Private recipes
#################

# Check the same macOS baseline as the single-file bootstrap, without applying.
_check-macos:
    @bash "{{ REPO }}/up.sh" --check-os

# Report enabled Login Items / background tasks outside startupApps + known prefixes.
_audit-login-items:
    @"{{ REPO }}/scripts/audit-login-items.sh" "{{ REPO }}"

# Report that native Raycast sync is paused during the Spotlight trial.
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

# Explicit private override for a deliberate Raycast native import during the pause.
_raycast-import-force:
    @"{{ REPO }}/scripts/raycast-settings-sync.sh" "{{ REPO }}" force

# Apply
#####

_apply:
    #!/usr/bin/env bash
    set -euo pipefail
    printf 'Checking Codex configuration for conflicts...\n'
    bun "{{ REPO }}/scripts/codex-config-sync.ts" preflight
    printf 'Checking which app settings will need a restart (this can take several seconds)...\n'
    pending="$(bun "{{ REPO }}/scripts/restart-plan.ts")"
    # The login LaunchAgent is loaded during the system switch. Defer it until
    # this apply has cleared quarantine and installed settings; apps are opened
    # explicitly at the end of _after-switch. The PID lets login ignore a stale
    # marker left by an interrupted/killed apply.
    startup_marker="$HOME/.local/state/machine/apply-in-progress"
    mkdir -p "$(dirname "$startup_marker")"
    printf '%s\n' "$$" > "$startup_marker"
    trap 'rm -f "$startup_marker"' EXIT
    printf 'Checking Apple Command Line Tools and available updates (this can take a while)...\n'
    bash "{{ REPO }}/scripts/setup-clt.sh"
    printf 'Applying the Nix system generation, macOS defaults, and Homebrew declarations...\n'
    printf 'Evaluation, downloads, and installation can take several minutes. Follow any sudo or macOS prompts.\n'
    just _system-switch
    printf 'System switch complete. Applying user files and app settings...\n'
    just _after-switch
    echo "Machine setup complete."
    if [[ "${MACHINE_APPLY_MODE:-basic}" != full && -n "$pending" ]]; then
      printf 'App settings still need apply-to-machine full or a restart:\n%s\n' "$pending"
      printf 'Run just apply-to-machine full from Terminal.app when ready.\n'
    fi
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
    @echo "Clearing quarantine on declared apps..."
    @just _unquarantine-cask-apps
    @echo "Applying Codex and CodexBar settings..."
    @bun "{{ REPO }}/scripts/codex-config-sync.ts" apply
    @bash "{{ REPO }}/scripts/codexbar-settings-sync.sh" apply
    @echo "Applying or checking declared app preferences..."
    @if [[ "${MACHINE_APPLY_MODE:-basic}" == full ]]; then \
      bun "{{ REPO }}/scripts/app-preferences.ts" apply; \
    else \
      bun "{{ REPO }}/scripts/app-preferences.ts" check; \
    fi
    @just _chezmoi-apply
    @echo "Checking setup steps that may need native prompts..."
    @just _attention-required
    @echo "Ensuring declared code repositories are present..."
    @just _ensure-code-repos
    @echo "Installing editor extensions (may take a while)..."
    @just _install-editor-extensions
    @echo "Opening startup apps..."
    @just _launch-startup-apps
    @echo "Reloading AeroSpace configuration..."
    @"{{ REPO }}/scripts/aerospace-reload-config.sh"

_attention-required:
    @echo "Checking attention-required setup: Xcode/App Store, GitHub authentication, and Thaw profiles."
    @just _setup-xcode
    @just _git-auth
    @if [[ "${MACHINE_APPLY_MODE:-basic}" == full ]]; then \
      just _raycast-settings-sync; just _thaw-profile-sync; \
    else \
      just _thaw-profile-sync check; bash "{{ REPO }}/scripts/raycast-settings-sync.sh" "{{ REPO }}" check; \
    fi
    @echo "Weather menu item: confirm System Settings > Menu Bar > Weather during the final visual check."

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
      output="$(just _prune-removals-diff 2>&1)"; \
      status="$?"; \
      set -e; \
      if [ "$status" -ne 0 ]; then \
        printf '\nPrune check failed:\n%s\n' "$output" >&2; \
      elif [ -n "$output" ]; then \
        printf '\nPrune candidates found:\n%s\n\nRun just prune to review and confirm removal.\n' "$output"; \
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

_restart-plan:
    @bun "{{ REPO }}/scripts/restart-plan.ts"

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
