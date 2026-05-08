set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

repo := justfile_directory()
host := env_var_or_default("MACHINE_HOST", "machine")
nix_flags := "--extra-experimental-features 'nix-command flakes'"
export PATH := "/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/opt/homebrew/bin:/usr/local/bin:" + env_var_or_default("PATH", "")

default:
    @just --list

# Apply system/app/env/dotfile layers and install editor extensions.
up:
    #!/usr/bin/env bash
    set -euo pipefail

    sudo -v
    while true; do
      sudo -n -v 2>/dev/null || exit
      sleep 30
    done &
    sudo_keepalive_pid="$!"
    trap 'kill "$sudo_keepalive_pid" 2>/dev/null || true; sudo -k' EXIT

    just doctor
    just _darwin-switch
    just _post-darwin
    just _prune-check
    printf '\nMachine setup complete.\n'

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

# Post-switch tasks run after nix-darwin has installed tools/apps.
_post-darwin:
    @just dotfiles-apply
    @just _install-editor-extensions

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
    #!/usr/bin/env bash
    set -euo pipefail

    brewfile="$(mktemp)"
    desired_casks="$(mktemp)"
    desired_formulae="$(mktemp)"
    trap 'rm -f "$brewfile" "$desired_casks" "$desired_formulae"' EXIT

    nix {{nix_flags}} eval --raw .#darwinConfigurations.{{host}}.config.homebrew.brewfile > "$brewfile"

    awk -F'"' '/^cask "/ { print $2 }' "$brewfile" | sort -fu > "$desired_casks"
    extra_casks="$(comm -23 <(brew list --cask --full-name | sort -fu) "$desired_casks")"

    if [ -n "$extra_casks" ]; then
      printf 'Would uninstall casks:\n%s\n' "$extra_casks"
    fi

    awk -F'"' '/^brew "/ { print $2 }' "$brewfile" | sort -fu > "$desired_formulae"
    installed="$(
      brew leaves --installed-on-request 2>/dev/null || brew leaves
    )"
    extra_formulae="$(comm -23 <(printf '%s\n' "$installed" | sort -fu) "$desired_formulae")"

    if [ -n "$extra_formulae" ]; then
      printf 'Would uninstall formulae leaves:\n%s\n' "$extra_formulae"
    fi

_prune-homebrew-apply:
    #!/usr/bin/env bash
    set -euo pipefail

    brewfile="$(mktemp)"
    desired_casks="$(mktemp)"
    desired_formulae="$(mktemp)"
    trap 'rm -f "$brewfile" "$desired_casks" "$desired_formulae"' EXIT

    nix {{nix_flags}} eval --raw .#darwinConfigurations.{{host}}.config.homebrew.brewfile > "$brewfile"

    awk -F'"' '/^cask "/ { print $2 }' "$brewfile" | sort -fu > "$desired_casks"
    extra_casks="$(comm -23 <(brew list --cask --full-name | sort -fu) "$desired_casks")"

    if [ -n "$extra_casks" ]; then
      while IFS= read -r cask; do
        HOMEBREW_NO_AUTOREMOVE=1 brew uninstall --cask --force "$cask"
      done <<< "$extra_casks"
    fi

    awk -F'"' '/^brew "/ { print $2 }' "$brewfile" | sort -fu > "$desired_formulae"
    installed="$(
      brew leaves --installed-on-request 2>/dev/null || brew leaves
    )"
    extra_formulae="$(comm -23 <(printf '%s\n' "$installed" | sort -fu) "$desired_formulae")"

    if [ -n "$extra_formulae" ]; then
      while IFS= read -r formula; do
        HOMEBREW_NO_AUTOREMOVE=1 brew uninstall --force "$formula"
      done <<< "$extra_formulae"
    fi

_prune-editor-extensions-diff:
    #!/usr/bin/env bash
    set -euo pipefail

    diff_extensions() {
      local name="$1"
      local cli="$2"
      local desired_file="$3"

      if [ ! -x "$cli" ]; then
        echo "Skipping $name extension prune diff; CLI not found at $cli"
        return
      fi

      extra="$(
        comm -23 \
          <("$cli" --list-extensions | sort -fu) \
          <(grep -Ev '^\s*(#|$)' "$desired_file" | sort -fu)
      )"

      if [ -z "$extra" ]; then
        echo "$name extensions match declaration"
      else
        printf 'Undeclared %s extensions:\n%s\n' "$name" "$extra"
      fi
    }

    diff_extensions "VS Code" "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "home/dot_config/vscode-family/extensions.code.txt"
    diff_extensions "Cursor" "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "home/dot_config/vscode-family/extensions.cursor.txt"

_prune-editor-extensions-apply:
    #!/usr/bin/env bash
    set -euo pipefail

    prune_extensions() {
      local name="$1"
      local cli="$2"
      local desired_file="$3"

      if [ ! -x "$cli" ]; then
        echo "Skipping $name extension prune; CLI not found at $cli"
        return
      fi

      extra="$(
        comm -23 \
          <("$cli" --list-extensions | sort -fu) \
          <(grep -Ev '^\s*(#|$)' "$desired_file" | sort -fu)
      )"

      if [ -z "$extra" ]; then
        echo "$name extensions match declaration"
        return
      fi

      while IFS= read -r extension; do
        "$cli" --uninstall-extension "$extension"
      done <<< "$extra"
    }

    prune_extensions "VS Code" "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "home/dot_config/vscode-family/extensions.code.txt"
    prune_extensions "Cursor" "/Applications/Cursor.app/Contents/Resources/app/bin/cursor" "home/dot_config/vscode-family/extensions.cursor.txt"

_prune-dotfiles-diff:
    @chezmoi diff --source "{{repo}}/home" || true

_darwin-switch host=host:
    @test -f flake.nix || { echo 'No flake.nix yet. Add the nix-darwin flake first.' >&2; exit 1; }
    sudo -H env "PATH=$PATH" nix {{nix_flags}} run nix-darwin/master#darwin-rebuild -- switch --flake ".#{{host}}"

dotfiles-apply:
    chezmoi apply --force --no-tty --source "{{repo}}/home"

dotfiles-diff:
    @chezmoi diff --source "{{repo}}/home" || true

_install-editor-extensions:
    #!/usr/bin/env bash
    set -euo pipefail

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

      while IFS= read -r extension; do
        "$cli" --install-extension "$extension"
      done <<< "$missing"
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
