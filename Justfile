set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

export PATH := "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:" + env_var_or_default("PATH", "")

REPO := justfile_directory()
HOST := env_var_or_default("MACHINE_HOST", "machine")
NIX_CMD := "nix --extra-experimental-features 'nix-command flakes'"

default:
    @just --list

# Update system/app/env/dotfile layers and install editor extensions.
apply:
    @scripts/with-sudo-keepalive.sh just _apply

# Apply dotfile changes with chezmoi
chezmoi-apply:
    chezmoi apply --force --no-tty --source "{{ REPO }}/home"

# Capture current machine state into reviewable inventory files.
import-current:
    just _apps-dump
    just _mas-dump
    just _defaults-capture
    just _import-editor-extensions
    just _import-home-files-review
    -just display-layout-capture inventory/display-layout.sh
    git status --short

# Authenticate GitHub CLI and configure GitHub HTTPS pushes.
git-auth:
    @just _git-auth

# Capture the current display arrangement as the checked-in replay script.
display-layout-capture file="scripts/display-layout.sh":
    @just _display-layout-capture "{{ file }}"

# Show undeclared Homebrew formulae/casks, editor extensions, and dotfile drift.
prune-diff:
    @just _prune-homebrew-diff
    @just _prune-editor-extensions-diff
    @just _prune-dotfiles-diff

# Remove undeclared Homebrew formulae/casks and editor extensions, then apply dotfiles.
prune:
    @just _prune-homebrew-apply
    @just _prune-editor-extensions-apply
    @just chezmoi-apply

# Format repo files with dprint. Uses `./dprint.json` at repo root (extends chezmoi-config).
fmt:
    dprint fmt .

# Validate the Nix flake without applying it.
verify:
    dprint check .
    {{ NIX_CMD }} flake check --show-trace

# Build settings.rayconfig from settings.json and open it (always; ignores change stamp).
raycast-import:
    @{{ REPO }}/scripts/raycast-settings-sync.sh "{{ REPO }}" force

# Private recipes
#################

# If config/raycast/settings.json changed, gzip + open for Raycast import (see scripts/raycast-settings-sync.sh).
_raycast-settings-sync:
    @"{{ REPO }}/scripts/raycast-settings-sync.sh" "{{ REPO }}"

# Apply
#####

_apply:
    @just _system-switch
    @just _after-switch
    @printf '\nMachine setup complete.\n'
    @just _prune-check

# System switch
###############

# `darwin-rebuild switch` for this flake (nix-darwin system generation).
_system-switch host=HOST:
    sudo -H env "PATH=$PATH" {{ NIX_CMD }} run "{{ REPO }}#darwin-rebuild" -- switch --flake "{{ REPO }}#{{ host }}"

# After switch
##############

# After `darwin-rebuild switch`: auth, chezmoi, editor extensions, startup apps.
_after-switch:
    @just git-auth
    @just chezmoi-apply
    @printf '\nInstalling editor extensions (may take a while)...\n'
    @just _install-editor-extensions
    @just _launch-startup-apps
    @just _raycast-settings-sync

_git-auth:
    #!/usr/bin/env bash
    set -euo pipefail
    if gh auth status --hostname github.com >/dev/null 2>&1; then
      echo "GitHub auth already configured"
    elif [ -t 0 ] && [ -t 1 ]; then
      gh auth login --hostname github.com --git-protocol https --web
    else
      echo "Skipping GitHub auth; run 'just git-auth' from an interactive terminal"
      exit 0
    fi
    gh auth setup-git --hostname github.com

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

          if [ -e "$app_path" ] && /usr/bin/open -gj "$app_path"; then
            continue
          fi

          if [ -x "$executable" ]; then
            # ASCII Unit Separator (0x1f, octal 037), matching the jq join above.
            IFS=$'\037' read -r -a args <<< "$args_joined"
            nohup "$executable" "${args[@]}" >/dev/null 2>&1 &
            continue
          fi

          printf 'Could not launch startup app: %s\n' "$name" >&2
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

    cat > "{{ file }}" <<EOF
    #!/usr/bin/env bash
    set -euo pipefail

    # Captured from the current macOS display arrangement with displayplacer.
    exec $command
    EOF
    chmod +x "{{ file }}"
    printf 'Captured display layout in %s\n' "{{ file }}"

# Inventory
###########

# Export current Homebrew state for review.
_apps-dump file="inventory/Brewfile":
    mkdir -p "$(dirname "{{ file }}")"
    brew bundle dump --force --file "{{ file }}"

_apps-apply file="inventory/Brewfile":
    brew bundle --file "{{ file }}"

# Export current Mac App Store inventory for review.
_mas-dump file="inventory/mas.json":
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "$(dirname "{{ file }}")"
    if command -v mas >/dev/null 2>&1; then
      mas list --json > "{{ file }}"
    fi

# Export selected macOS preferences for review, not blind re-application.
_defaults-capture dir="inventory/defaults":
    mkdir -p "{{ dir }}"
    for domain in \
      NSGlobalDomain \
      com.apple.dock \
      com.apple.finder \
      com.apple.AppleMultitouchTrackpad \
      com.apple.driver.AppleBluetoothMultitouch.trackpad \
      com.apple.symbolichotkeys \
      com.apple.universalaccess; do \
      defaults export "$domain" "{{ dir }}/$domain.plist" 2>/dev/null || true; \
    done

_import-editor-extensions dir="inventory/editor-extensions":
    @code_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; \
      cursor_cli="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"; \
      mkdir -p "{{ dir }}"; \
      [ -x "$code_cli" ] && "$code_cli" --list-extensions > "{{ dir }}/code.txt" || true; \
      [ -x "$cursor_cli" ] && "$cursor_cli" --list-extensions > "{{ dir }}/cursor.txt" || true

_import-home-files-review dir="inventory/home":
    mkdir -p "{{ dir }}"
    [ ! -f "$HOME/.zshrc" ] || cp "$HOME/.zshrc" "{{ dir }}/zshrc"
    [ ! -f "$HOME/.zprofile" ] || cp "$HOME/.zprofile" "{{ dir }}/zprofile"
    [ ! -f "$HOME/.zshenv" ] || cp "$HOME/.zshenv" "{{ dir }}/zshenv"
    [ ! -f "$HOME/.gitconfig" ] || cp "$HOME/.gitconfig" "{{ dir }}/gitconfig"
    [ ! -f "$HOME/.gitignore" ] || cp "$HOME/.gitignore" "{{ dir }}/gitignore"
    [ ! -f "$HOME/.aerospace.toml" ] || cp "$HOME/.aerospace.toml" "{{ dir }}/aerospace.toml"
    [ ! -f "$HOME/.config/vscode-family/settings.json" ] || cp "$HOME/.config/vscode-family/settings.json" "{{ dir }}/vscode-family-settings.json"
    [ ! -f "$HOME/.config/vscode-family/keybindings.json" ] || cp "$HOME/.config/vscode-family/keybindings.json" "{{ dir }}/vscode-family-keybindings.json"
    [ ! -f "$HOME/.config/vscode-family/extensions.txt" ] || cp "$HOME/.config/vscode-family/extensions.txt" "{{ dir }}/vscode-family-extensions.txt"
    [ ! -f "$HOME/.config/dprint/dprint.json" ] || cp "$HOME/.config/dprint/dprint.json" "{{ dir }}/dprint.json"
    [ ! -f "$HOME/.cursor/cli-config.json" ] || cp "$HOME/.cursor/cli-config.json" "{{ dir }}/cursor-cli-config.json"
    [ ! -f "$HOME/Library/Application Support/Cursor/User/settings.json" ] || cp "$HOME/Library/Application Support/Cursor/User/settings.json" "{{ dir }}/cursor-User-settings.json"
    [ ! -f "$HOME/Library/Application Support/com.pais.handy/settings_store.json" ] || cp "$HOME/Library/Application Support/com.pais.handy/settings_store.json" "{{ dir }}/handy-settings_store.json"
    [ ! -f "$HOME/Library/Group Containers/group.com.docker/settings-store.json" ] || cp "$HOME/Library/Group Containers/group.com.docker/settings-store.json" "{{ dir }}/docker-settings-store.json"

# Flake
#######

_update:
    {{ NIX_CMD }} flake update
