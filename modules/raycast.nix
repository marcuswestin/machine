{ lib, user, ... }:

let
  userArg = lib.escapeShellArg user;
in

{
  # Homebrew installs Raycast (modules/apps.nix). Declarative preferences live in
  # config/raycast/settings.json (plain JSON). `just apply` runs
  # scripts/raycast-settings-sync.sh after switch: if settings.json changed since the
  # last run (SHA-256 in ~/.local/state/machine/), it gzips to settings.rayconfig and
  # opens it. Use `just raycast-import` to force that step. Clear Raycast's export
  # passphrase when exporting from the app if you want an unencrypted backup. A few keys
  # still map to NSUserDefaults:
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Let Homebrew own Raycast updates (brew upgrade) instead of the in-app updater.
    launchctl asuser "$(id -u -- ${userArg})" sudo --user=${userArg} -- /usr/bin/defaults write com.raycast.macos updaterEnabled -bool false
  '';
}
