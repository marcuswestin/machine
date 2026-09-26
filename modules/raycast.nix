{ ... }:
let
  settings = builtins.fromJSON (builtins.readFile ../config/raycast/settings.json);
in
{
  # Homebrew installs Raycast (modules/apps.nix). Declarative preferences live in
  # config/raycast/settings.json (plain JSON). `just apply` and `just import-inventory global` run
  # scripts/raycast-settings-sync.sh: if settings.json changed since the last run
  # (SHA-256 in ~/.local/state/machine/), it gzips to settings.rayconfig and opens it.
  # Use `just _raycast-import-force` to rebuild/open regardless of stamp. Clear Raycast's
  # export passphrase when exporting from the app if you want an unencrypted backup. A few keys
  # still map to NSUserDefaults:
  system.defaults.CustomUserPreferences."com.raycast.macos" = {
    # Let Homebrew own Raycast updates (brew upgrade) instead of the in-app updater.
    updaterEnabled = false;
    # Register the exported shortcut before first launch, even if the interactive
    # .rayconfig import has not completed. Command-49 means Command + Space
    # (macOS virtual key code 49); keep the export as the single source of truth.
    raycastGlobalHotkey =
      settings.builtin_package_raycastPreferences.preferencesGeneral.raycastGlobalHotkey;
    # Raycast 1.104.x's first-launch wizard flag (verified against 1.104.29).
    # This skips the tour; it does not grant macOS permissions or sign in.
    onboardingCompleted = true;
    # Hide the getting-started task list, matching raycast_onboarding in the export.
    onboarding_showTasksProgress = false;
  };
}
