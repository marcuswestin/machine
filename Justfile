set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

repo := justfile_directory()
host := env_var_or_default("MACHINE_HOST", "machine")
nix_flags := "--extra-experimental-features 'nix-command flakes'"

default:
    @just --list

# Apply system/app/env layers, dotfiles, and editor extensions.
up: _sudo-refresh doctor _darwin-switch _post-darwin
    @printf '\nMachine setup complete.\n'

# Show the base tool state for this machine.
doctor:
    @printf 'repo: %s\n' "{{repo}}"
    @printf 'host: %s\n' "{{host}}"
    @for cmd in nix git just brew chezmoi mas darwin-rebuild; do \
      if command -v "$cmd" >/dev/null 2>&1; then \
        printf 'ok   %s -> %s\n' "$cmd" "$(command -v "$cmd")"; \
      else \
        printf 'miss %s\n' "$cmd"; \
      fi; \
    done
    @test -f flake.nix || printf 'miss flake.nix\n'

# Machine Setup
###############

# Ask for sudo up front, before the longer machine setup starts.
_sudo-refresh:
    sudo -v

# Post-switch tasks can run at the same time once nix-darwin has installed tools/apps.
_post-darwin:
    printf '%s\n' dotfiles-apply _install-editor-extensions | parallel --will-cite -j 2 just {}

# Save Machine State
####################

# Capture current machine state into reviewable inventory files.
import-current:
    just _apps-dump
    just _defaults-capture
    just _import-editor-extensions
    just _import-home-files-review
    git status --short

_darwin-switch host=host:
    @test -f flake.nix || { echo 'No flake.nix yet. Add the nix-darwin flake first.' >&2; exit 1; }
    sudo -H env "PATH=$PATH" nix {{nix_flags}} run nix-darwin/master#darwin-rebuild -- switch --flake ".#{{host}}"

dotfiles-apply:
    chezmoi apply --source "{{repo}}/home"

dotfiles-diff:
    chezmoi diff --source "{{repo}}/home" || true

_install-editor-extensions:
    #!/usr/bin/env bash
    set -euo pipefail

    jobs="${EDITOR_EXTENSION_JOBS:-4}"

    install_extensions() {
      local name="$1"
      local cli="$2"
      local desired_file="$3"

      if [ ! -x "$cli" ]; then
        echo "Skipping $name extensions; CLI not found at $cli"
        return
      fi

      missing="$(
        comm -23 \
          <(grep -Ev '^\s*(#|$)' "$desired_file" | sort -fu) \
          <("$cli" --list-extensions | sort -fu)
      )"

      if [ -z "$missing" ]; then
        echo "$name extensions already installed"
        return
      fi

      printf '%s\n' "$missing" | parallel --will-cite -j "$jobs" "$cli" --install-extension {}
    }

    install_extensions "VS Code" "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "home/dot_config/vscode-family/extensions.code.txt" &
    code_pid="$!"

    install_extensions "Cursor" "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "home/dot_config/vscode-family/extensions.cursor.txt" &
    cursor_pid="$!"

    wait "$code_pid"
    wait "$cursor_pid"

# Validate the Nix flake without applying it.
check:
    @test -f flake.nix || { echo 'No flake.nix yet.' >&2; exit 1; }
    nix {{nix_flags}} flake check

_update:
    @test -f flake.nix || { echo 'No flake.nix yet.' >&2; exit 1; }
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
