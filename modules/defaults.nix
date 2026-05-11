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
  # AppleSymbolicHotKeys stores shortcuts as opaque numeric plist values:
  # id 64 is Spotlight search, id 65 is the Finder search window.
  # Shortcut parameters are (character, keyCode, modifierMask). For Space,
  # character is 32 and keyCode is 49. Modifier masks are Cocoa values:
  # Command is 1048576, Option is 524288, and Command-Option is 1572864.
  spotlightSpaceKey = {
    character = 32;
    keyCode = 49;
  };
  spotlightHotkeys = [
    {
      # Command-Space, disabled so Raycast can own that shortcut.
      id = 64;
      modifiers = 1048576;
    }
    {
      # Command-Option-Space, the paired Finder search shortcut.
      id = 65;
      modifiers = 1572864;
    }
  ];
  disableSpotlightHotkey =
    hotkey:
    ''
      launchctl asuser "$(id -u -- ${userArg})" sudo --user=${userArg} -- /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${toString hotkey.id} '{ enabled = 0; value = { parameters = (${toString spotlightSpaceKey.character}, ${toString spotlightSpaceKey.keyCode}, ${toString hotkey.modifiers}); type = standard; }; }'
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
      # 2 means Full Keyboard Access for all controls, not only text boxes/lists.
      AppleKeyboardUIMode = 2;
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false; # Enable key repeat instead of accent popup.
      "com.apple.swipescrolldirection" = true; # Natural scrolling.
      # macOS stores keyboard repeat timings in 15 ms units; this is a 150 ms
      # initial delay followed by a 15 ms repeat interval.
      InitialKeyRepeat = 10;
      KeyRepeat = 1;
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
      tilesize = 64; # Dock icon size in pixels.
      # wvous values are Dock hot-corner action IDs.
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

    # Control Center → Menu Bar Only / Battery: show numeric percentage next to the icon.
    # nix-darwin exposes only a boolean; System Settings may still offer Always / When Low /
    # Never on newer macOS—adjust there if you want “when low” only.
    controlcenter = {
      BatteryShowPercentage = true;
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
        "com.apple.sound.beep.feedback" = 0; # Disable volume-change feedback sounds.
        "com.apple.sound.beep.flash" = 0; # Do not flash the screen for alert sounds.
        "com.apple.trackpad.forceClick" = true;
        "com.apple.trackpad.scaling" = 3.0; # Trackpad tracking speed.
        "com.apple.trackpad.scrolling" = true;
      };

      "com.apple.AppleMultitouchTrackpad" = trackpadPreferences;
      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = trackpadPreferences;

      # Human Interface Toolbox — Globe/FN key action (Settings → Keyboard → Press 🌐 key to).
      # 0 = Do Nothing; 1 = Change Input Source; 2 = Show Emoji & Symbols; 3 = Start Dictation (press 🌐 twice).
      # Single-press emoji steals Fn from apps (e.g. Handy transcribe bound to fn).
      "com.apple.HIToolbox" = {
        AppleFnUsageType = 0;
      };
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
