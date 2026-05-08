{ lib, user, ... }:

let
  userArg = lib.escapeShellArg user;
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
      InitialKeyRepeat = 10; # Fastest.
      KeyRepeat = 1; # Fastest.
    };

    dock = {
      autohide = true;
      expose-group-apps = false;
      launchanim = false;
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

      "com.apple.AppleMultitouchTrackpad" = {
        Clicking = true;
        DragLock = false;
        Dragging = false;
        TrackpadRightClick = true;
        TrackpadScroll = true;
        TrackpadThreeFingerDrag = true;
      };

      "com.apple.driver.AppleBluetoothMultitouch.trackpad" = {
        Clicking = true;
        DragLock = false;
        Dragging = false;
        TrackpadRightClick = true;
        TrackpadScroll = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };

  system.activationScripts.postActivation.text = ''
    # Refresh the per-user defaults cache so keyboard repeat changes are visible
    # promptly after `darwin-rebuild switch`.
    /usr/bin/killall -qu ${userArg} cfprefsd || true
  '';
}
