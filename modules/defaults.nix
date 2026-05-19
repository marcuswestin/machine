{ lib, user, ... }:

let
  userArg = lib.escapeShellArg user;
  trackpadPreferences = {
    ActuateDetents = 1; # Force Touch haptic detents enabled.
    Clicking = true;
    DragLock = false;
    Dragging = false;
    FirstClickThreshold = 1; # Trackpad click pressure: medium.
    ForceSuppressed = false;
    SecondClickThreshold = 1; # Force click pressure: medium.
    TrackpadCornerSecondaryClick = 0; # Secondary click corner disabled; two-finger right click is used.
    TrackpadFiveFingerPinchGesture = 2; # Launchpad five-finger pinch.
    TrackpadFourFingerHorizSwipeGesture = 2; # Four-finger horizontal swipe switches Spaces.
    TrackpadFourFingerPinchGesture = 2; # Show Desktop with four-finger spread.
    TrackpadFourFingerVertSwipeGesture = 2; # Mission Control/App Expose four-finger vertical gestures.
    TrackpadHandResting = true;
    TrackpadHorizScroll = 1; # Horizontal scrolling enabled.
    TrackpadMomentumScroll = true;
    TrackpadPinch = 1; # Pinch to zoom enabled.
    TrackpadRightClick = true;
    TrackpadRotate = 1; # Rotate gesture enabled.
    TrackpadScroll = true;
    TrackpadThreeFingerDrag = true;
    TrackpadThreeFingerHorizSwipeGesture = 2; # Three-finger horizontal swipe switches Spaces.
    TrackpadThreeFingerTapGesture = 0; # Look up/data detectors three-finger tap disabled.
    TrackpadThreeFingerVertSwipeGesture = 2; # Three-finger vertical swipe for Mission Control/App Expose.
    TrackpadTwoFingerDoubleTapGesture = 1; # Smart zoom enabled.
    TrackpadTwoFingerFromRightEdgeSwipeGesture = 3; # Notification Center edge swipe enabled.
    USBMouseStopsTrackpad = 0; # Keep trackpad active when a mouse is connected.
  };
  # AppleSymbolicHotKeys parameters are [character code, hardware key code, modifier mask].
  # 32/49 is Space. 1048576 is Command; 1572864 is Command+Option.
  disabledSpotlightSymbolicHotkeys = {
    "64" = "{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }"; # Spotlight search (Cmd-Space).
    "65" = "{ enabled = 0; value = { parameters = (32, 49, 1572864); type = standard; }; }"; # Finder search window (Cmd-Option-Space).
    "164" = "{ enabled = 0; }"; # Show apps inside the Spotlight window UI.
  };
  disableSpotlightSymbolicHotkeys = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      id: plist:
      ''
        launchctl asuser "$(id -u -- ${userArg})" sudo --user=${userArg} -- /usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${id} '${plist}'
      ''
    ) disabledSpotlightSymbolicHotkeys
  );
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
      KeyRepeat = 15;
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
      # Four-letter Finder view-style constant: icon view (vs clmv, Nlsv, flwv).
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
        # BCP 47 language tags; first is primary UI language, second is fallback order.
        AppleLanguages = [
          "en-US"
          "sv-SE"
        ];
        # Underscore form is what NSGlobalDomain expects for the primary locale bundle.
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

      "app.monitorcontrol.MonitorControl" = {
        disableAltBrightnessKeys = false;
        enableBrightnessSync = true;
        enableSliderPercent = true;
        keyboardBrightness = 0; # Keyboard brightness keys affect the built-in keyboard only.
        keyboardVolume = 0; # Volume keys use the normal system target.
        menuItemStyle = 0; # MonitorControl's default menu bar style.
        multiKeyboardBrightness = 1; # Brightness keys control all relevant displays.
        multiKeyboardVolume = 1; # Volume keys control all relevant displays.
        separateCombinedScale = false;
        showTickMarks = true;
        useFineScaleBrightness = true;
        useFineScaleVolume = false;
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
    # Disable macOS Spotlight keyboard shortcuts (Raycast uses Cmd-Space / Cmd-Opt-Space).
    ${disableSpotlightSymbolicHotkeys}
    # Hide the Spotlight magnifying-glass menu bar extra: MenuItemHidden -int 1 (0 = show, 1 = hide).
    # Apple changes menu bar plumbing occasionally—verify after OS upgrades.
    launchctl asuser "$(id -u -- ${userArg})" sudo --user=${userArg} -- /usr/bin/defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1
  '';
}
