{ lib, user, ... }:

let
  userArg = lib.escapeShellArg user;
in

{
  # Homebrew installs Raycast (modules/apps.nix). Declarative preferences live in
  # config/raycast/settings.json (plain JSON). `just apply` and `just import-inventory global` run
  # scripts/raycast-settings-sync.sh: if settings.json changed since the last run
  # (SHA-256 in ~/.local/state/machine/), it gzips to settings.rayconfig and opens it.
  # Use `just _raycast-import-force` to rebuild/open regardless of stamp. Clear Raycast's
  # export passphrase when exporting from the app if you want an unencrypted backup. A few keys
  # still map to NSUserDefaults:
  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Let Homebrew own Raycast updates (brew upgrade) instead of the in-app updater.
    launchctl asuser "$(id -u -- ${userArg})" sudo --user=${userArg} -- /usr/bin/defaults write com.raycast.macos updaterEnabled -bool false
  '';
}
