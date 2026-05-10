{ lib, user, ... }:

let
  userArg = lib.escapeShellArg user;
  trackpadPreferences = {
    Clicking = true;
    DragLock = false;
    Dragging = false;
    TrackpadRightClick = true;
    TrackpadScroll = true;
    TrackpadThreeFingerDrag = true;
  };
  spotlightHotkeys = [
    {
      id = 64;
      modifiers = 1048576;
    }
    {
      id = 65;
      modifiers = 1572864;
    }
  ];
  disableSpotlightHotkey =
    hotkey:
    ''
      launchctl asuser "$(id -u -- ${userArg})" sudo --user=${userArg} -- /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${toString hotkey.id} '{ enabled = 0; value = { parameters = (32, 49, ${toString hotkey.modifiers}); type = standard; }; }'
    '';
in

{
  system.keyboard = {
    # Use nix-darwin's official hidutil-backed key mapping support.
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      AppleKeyboardUIMode = 2; # Full keyboard access.
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false; # Enable key repeat instead of accent popup.
      "com.apple.swipescrolldirection" = true; # Natural scrolling.
      InitialKeyRepeat = 10; # Fastest.
      KeyRepeat = 1; # Fastest.
    };

    dock = {
      autohide = true;
      expose-group-apps = false;
      launchanim = false;
      magnification = false;
      minimize-to-application = false;
      mru-spaces = false;
      orientation = "left";
      show-recents = false;
      tilesize = 64;
      wvous-bl-corner = 10; # Lock Screen.
      wvous-tl-corner = 4; # Desktop.
      wvous-tr-corner = 12; # Notification Center.
      wvous-br-corner = 14; # Quick Note.
    };

    finder = {
      FXPreferredViewStyle = "icnv";
      ShowExternalHardDrivesOnDesktop = false;
      ShowHardDrivesOnDesktop = false;
      ShowRemovableMediaOnDesktop = true;
      ShowStatusBar = false;
      ShowPathbar = false;
    };

    trackpad = {
      Clicking = true;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = true;
    };

    CustomUserPreferences = {
      NSGlobalDomain = {
        AppleLanguages = [
          "en-US"
          "sv-SE"
        ];
        AppleLocale = "en_US";
        AppleSpacesSwitchOnActivate = false;
        NSAutomaticCapitalizationEnabled = true;
        NSAutomaticPeriodSubstitutionEnabled = true;
        NSQuitAlwaysKeepsWindows = true;
        NSWindowShouldDragOnGesture = true;
        "com.apple.sound.beep.feedback" = 0;
        "com.apple.sound.beep.flash" = 0;
        "com.apple.trackpad.forceClick" = true;
        "com.apple.trackpad.scaling" = 3.0;
        "com.apple.trackpad.scrolling" = true;
      };

      "com.apple.AppleMultitouchTrackpad" = trackpadPreferences;
      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = trackpadPreferences;
    };

    WindowManager = {
      AutoHide = false;
      EnableStandardClickToShowDesktop = false;
      EnableTiledWindowMargins = true;
      EnableTilingByEdgeDrag = false;
      EnableTopTilingByEdgeDrag = false;
      GloballyEnabled = false;
      HideDesktop = false;
      StageManagerHideWidgets = false;
      StandardHideWidgets = false;
    };
  };

  system.activationScripts.postActivation.text = ''
    # Disable Spotlight's default keyboard shortcuts so Raycast can own
    # Command-Space. Merge only these symbolic hotkey IDs to avoid replacing
    # the whole AppleSymbolicHotKeys dictionary.
    ${lib.concatMapStringsSep "\n" disableSpotlightHotkey spotlightHotkeys}
  '';
}
