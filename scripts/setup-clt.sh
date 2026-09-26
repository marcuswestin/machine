#!/usr/bin/env bash
set -euo pipefail

# Pre-Homebrew bootstrap: Apple's developer tools are needed by source builds.
# Use normal Software Update for existing installs; the install-on-demand marker
# is only for missing tools, otherwise Apple may offer the same release again.
sentinel="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
clt_installed=false
if pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
  clt_installed=true
else
  sudo touch "$sentinel"
  trap 'sudo rm -f "$sentinel"' EXIT
fi

clt_label="$(softwareupdate --list \
  | awk -F'Label: ' '/\*.*Command Line Tools/ { print $2 }' \
  | sed 's/[[:space:]]*$//' \
  | sort -V \
  | tail -n 1)"

if [ -z "$clt_label" ]; then
  if [ "$clt_installed" = true ]; then
    printf 'Command Line Tools are up to date.\n'
    exit 0
  fi
  printf 'Command Line Tools are missing, but softwareupdate offered no installer.\n' >&2
  exit 1
fi

sudo softwareupdate --install "$clt_label" --verbose
pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null
