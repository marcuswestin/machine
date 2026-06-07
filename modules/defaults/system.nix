{ ... }:

let
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
      ApplePressAndHoldEnabled = true; # Enable the press-and-hold accent popup.
      "com.apple.swipescrolldirection" = true; # Natural scrolling.
      # macOS stores keyboard repeat timings in 15 ms units; this is a 150 ms
      # initial delay followed by a 30 ms repeat interval.
      InitialKeyRepeat = 10;
      KeyRepeat = 2;
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

    # Control Center -> Menu Bar Only / Battery: show numeric percentage next to the icon.
    # nix-darwin exposes only a boolean; System Settings may still offer Always / When Low /
    # Never on newer macOS--adjust there if you want "when low" only.
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
        # cmd+ctrl+enter to toggle current window to take up the full screen (without native fullscreen)
        # - @ for Command, ^ for Control, and \r for Return/Enter.
        NSUserKeyEquivalents = {
          Zoom = "^@\r";
        };
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

      # Human Interface Toolbox - Globe/FN key action (Settings -> Keyboard -> Press Globe key to).
      # 0 = Do Nothing; 1 = Change Input Source; 2 = Show Emoji & Symbols; 3 = Start Dictation (press Globe twice).
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
}
