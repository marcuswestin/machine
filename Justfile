set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

repo := justfile_directory()
host := env_var_or_default("MACHINE_HOST", "machine")
repos_file := env_var_or_default("MACHINE_REPOS_FILE", repo + "/repos.tsv")
code_dir := env_var_or_default("MACHINE_CODE_DIR", env_var("HOME") + "/code")
nix_flags := "--extra-experimental-features 'nix-command flakes'"
export PATH := "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:" + env_var_or_default("PATH", "")

default:
    @just --list

# Apply system/app/env/dotfile layers and install editor extensions.
up:
    @scripts/with-sudo-keepalive.sh just _up

_up:
    @just _darwin-switch
    @just _post-darwin
    @printf '\nMachine setup complete.\n'
    @just _prune-check

# Machine Setup
###############

# Post-switch tasks run after nix-darwin has installed tools/apps.
_post-darwin:
    @just git-auth
    @just dotfiles-apply
    @just _install-editor-extensions
    @just repos-sync
    @just _launch-startup-apps

# Authenticate GitHub CLI and configure GitHub HTTPS pushes.
git-auth:
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

_prune-check:
    @output="$(just prune-diff 2>&1)" || true; \
      if printf '%s\n' "$output" | grep -Eq 'Would uninstall|Undeclared .* extensions|^diff --git'; then \
        printf '\nPrune candidates found:\n%s\n\nRun this to prune them:\n  just prune-apply\n' "$output"; \
      else \
        printf '\nNo prune candidates found.\n'; \
      fi


# Save Machine State
####################

# Capture current machine state into reviewable inventory files.
import-current:
    just _apps-dump
    just _defaults-capture
    just _import-editor-extensions
    just _import-home-files-review
    git status --short

# Show missing declared repos or origin remote mismatches.
repos-diff:
    @scripts/repos.sh diff "{{repos_file}}" "{{code_dir}}"

# Clone missing declared repos into ~/code without pulling or changing existing repos.
repos-sync:
    @scripts/repos.sh sync "{{repos_file}}" "{{code_dir}}"

# Show undeclared Homebrew formulae/casks, editor extensions, and dotfile drift.
prune-diff:
    @just _prune-homebrew-diff
    @just _prune-editor-extensions-diff
    @just _prune-dotfiles-diff

# Remove undeclared Homebrew formulae/casks and editor extensions, then apply dotfiles.
prune-apply:
    @just _prune-homebrew-apply
    @just _prune-editor-extensions-apply
    @just dotfiles-apply

_prune-homebrew-diff:
    @scripts/prune-homebrew.sh diff "{{host}}"

_prune-homebrew-apply:
    @scripts/prune-homebrew.sh apply "{{host}}"

_prune-editor-extensions-diff:
    @scripts/editor-extensions.sh prune-diff

_prune-editor-extensions-apply:
    @scripts/editor-extensions.sh prune-apply

_prune-dotfiles-diff:
    @chezmoi diff --source "{{repo}}/home" || true

_darwin-switch host=host:
    sudo -H env "PATH=$PATH" nix {{nix_flags}} run nix-darwin/master#darwin-rebuild -- switch --flake ".#{{host}}"

dotfiles-apply:
    chezmoi apply --force --no-tty --source "{{repo}}/home"

dotfiles-diff:
    @chezmoi diff --source "{{repo}}/home" || true

_install-editor-extensions:
    @scripts/editor-extensions.sh install

_launch-startup-apps:
    #!/usr/bin/env bash
    set -euo pipefail

    # Join startup app args with ASCII Unit Separator (0x1f, octal 037) so
    # spaces inside individual args survive TSV parsing.
    nix {{nix_flags}} eval --json .#darwinConfigurations.{{host}}.config.machine.startupApps \
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

# Validate the Nix flake without applying it.
check:
    nix {{nix_flags}} flake check

_update:
    nix {{nix_flags}} flake update

# Export current Homebrew state for review.
_apps-dump file="inventory/Brewfile":
    mkdir -p "$(dirname "{{file}}")"
    brew bundle dump --force --file "{{file}}"

_apps-apply file="inventory/Brewfile":
    brew bundle --file "{{file}}"

# Export current Mac App Store inventory for review.
_mas-dump file="inventory/mas.json":
    mkdir -p "$(dirname "{{file}}")"
    mas list --json > "{{file}}"

# Export selected macOS preferences for review, not blind re-application.
_defaults-capture dir="inventory/defaults":
    mkdir -p "{{dir}}"
    for domain in \
      NSGlobalDomain \
      com.apple.dock \
      com.apple.finder \
      com.apple.AppleMultitouchTrackpad \
      com.apple.driver.AppleBluetoothMultitouch.trackpad \
      com.apple.symbolichotkeys \
      com.apple.universalaccess; do \
      defaults export "$domain" "{{dir}}/$domain.plist" 2>/dev/null || true; \
    done

_import-editor-extensions dir="inventory/editor-extensions":
    @code_cli="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"; \
      cursor_cli="/Applications/Cursor.app/Contents/Resources/app/bin/cursor"; \
      mkdir -p "{{dir}}"; \
      [ -x "$code_cli" ] && "$code_cli" --list-extensions > "{{dir}}/code.txt" || true; \
      [ -x "$cursor_cli" ] && "$cursor_cli" --list-extensions > "{{dir}}/cursor.txt" || true

_import-home-files-review dir="inventory/home":
    mkdir -p "{{dir}}"
    [ ! -f "$HOME/.zshrc" ] || cp "$HOME/.zshrc" "{{dir}}/zshrc"
    [ ! -f "$HOME/.zprofile" ] || cp "$HOME/.zprofile" "{{dir}}/zprofile"
    [ ! -f "$HOME/.zshenv" ] || cp "$HOME/.zshenv" "{{dir}}/zshenv"
    [ ! -f "$HOME/.gitconfig" ] || cp "$HOME/.gitconfig" "{{dir}}/gitconfig"
    [ ! -f "$HOME/.gitignore" ] || cp "$HOME/.gitignore" "{{dir}}/gitignore"
    [ ! -f "$HOME/.config/vscode-family/settings.json" ] || cp "$HOME/.config/vscode-family/settings.json" "{{dir}}/vscode-family-settings.json"
    [ ! -f "$HOME/.config/vscode-family/keybindings.json" ] || cp "$HOME/.config/vscode-family/keybindings.json" "{{dir}}/vscode-family-keybindings.json"
    [ ! -f "$HOME/Library/Application Support/com.mitchellh.ghostty/config" ] || cp "$HOME/Library/Application Support/com.mitchellh.ghostty/config" "{{dir}}/ghostty-config"
