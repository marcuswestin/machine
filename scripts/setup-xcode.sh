#!/usr/bin/env bash
set -euo pipefail

# Provisions macOS developer tools that nix-darwin cannot manage directly:
#   1) Installs the Command Line Tools via softwareupdate (no-op once the CLT
#      package receipt is present).
#   2) Installs Xcode.app from the Mac App Store via `mas get` (Xcode's App
#      Store ID is 497799835).
#   3) Points xcode-select at Xcode.app, accepts the license, and finishes
#      Xcode's first-launch component install.
#   4) Downloads an iOS Simulator runtime so Simulator actually has a device to
#      boot (Expo's `expo run:ios` and CocoaPods builds need this).
#
# Mac App Store sign-in is required for `mas get` to succeed. If App Store auth
# is missing, this fails loudly after nix-darwin has already converged the rest
# of the machine; sign in via App Store.app and rerun `just apply`.

if ! pkgutil --pkg-info=com.apple.pkg.CLTools_Executables >/dev/null 2>&1; then
  # Apple-documented sentinel that makes softwareupdate offer CLT for fresh
  # installs. Only created when CLT is actually missing — otherwise softwareupdate
  # will re-offer (and reinstall) CLT on every run.
  sentinel="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "$sentinel"
  trap 'sudo rm -f "$sentinel"' EXIT

  clt_label="$(softwareupdate --list 2>/dev/null \
    | awk -F'Label: ' '/\*.*Command Line Tools/ { print $2 }' \
    | sed 's/[[:space:]]*$//' \
    | sort -V \
    | tail -n 1)"

  if [ -n "$clt_label" ]; then
    sudo softwareupdate --install "$clt_label" --verbose
  fi

  trap - EXIT
  sudo rm -f "$sentinel"
fi

if ! mas list | awk '{ print $1 }' | grep -qx '497799835'; then
  mas get 497799835
fi

# Switch the active developer dir to Xcode.app. This is what `xcodebuild`,
# Expo, CocoaPods, and Simulator look at; CLT-only is not sufficient for iOS
# builds (Expo errors with "Xcode must be fully installed before you can
# continue"). `xcode-select -s` accepts either the .app bundle or its
# Contents/Developer subdir, but `xcode-select -p` always reports the latter,
# so the comparison must use the resolved form.
if [ "$(xcode-select -p 2>/dev/null || true)" != "/Applications/Xcode.app/Contents/Developer" ]; then
  sudo xcode-select -s /Applications/Xcode.app
fi

# Idempotent: -checkFirstLaunchStatus exits 0 once the per-Xcode-version
# component install has run, so subsequent applies skip the multi-minute
# -runFirstLaunch step.
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
fi

# Without an iOS simulator runtime, Simulator opens with no devices and Expo's
# iOS builds fail at simctl boot. `xcodebuild -downloadPlatform iOS` is the
# headless equivalent of Xcode → Settings → Platforms → install iOS. Idempotent:
# `simctl list runtimes` already reports an iOS runtime once one is installed,
# so subsequent applies skip the multi-GB download.
if ! xcrun simctl list runtimes 2>/dev/null | grep -q '^iOS '; then
  sudo xcodebuild -downloadPlatform iOS
fi
