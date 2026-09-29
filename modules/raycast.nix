{ ... }:
let
  settings = builtins.fromJSON (builtins.readFile ../config/raycast/settings.json);
in
{
  # Homebrew installs Raycast (modules/apps.nix). Declarative preferences live in
  # config/raycast/settings.json (plain JSON). Native export/import is paused
  # for the Spotlight trial; `just _raycast-import-force` is an explicit private
  # override. The declared hotkey still maps to NSUserDefaults:
  system.defaults.CustomUserPreferences."com.raycast.macos" = {
    # Let Homebrew own Raycast updates (brew upgrade) instead of the in-app updater.
    updaterEnabled = false;
    # Register the exported shortcut before first launch, even if the interactive
    # .rayconfig import has not completed. Control-49 means Control + Space
    # (macOS virtual key code 49); keep settings.json as the source of truth.
    raycastGlobalHotkey =
      settings.builtin_package_raycastPreferences.preferencesGeneral.raycastGlobalHotkey;
    # Raycast 1.104.x's first-launch wizard flag (verified against 1.104.29).
    # This skips the tour; it does not grant macOS permissions or sign in.
    onboardingCompleted = true;
    # Hide the getting-started task list, matching raycast_onboarding in the export.
    onboarding_showTasksProgress = false;
  };
}
