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
  # Use XML plist fragments, not old-style ASCII ({ enabled = 0; ... }): `defaults write
  # -dict-add` parses bare 0 / 49 as <string>, not <false/> / <integer>, and HIToolbox
  # ignores wrongly-typed entries—silently leaving Cmd-Space bound to Spotlight.
  disabledSpotlightSymbolicHotkeys = {
    # Spotlight search (Cmd-Space).
    "64" = ''
      <dict>
        <key>enabled</key><false/>
        <key>value</key>
        <dict>
          <key>parameters</key>
          <array>
            <integer>32</integer>
            <integer>49</integer>
            <integer>1048576</integer>
          </array>
          <key>type</key><string>standard</string>
        </dict>
      </dict>
    '';
    # Finder search window (Cmd-Option-Space).
    "65" = ''
      <dict>
        <key>enabled</key><false/>
        <key>value</key>
        <dict>
          <key>parameters</key>
          <array>
            <integer>32</integer>
            <integer>49</integer>
            <integer>1572864</integer>
          </array>
          <key>type</key><string>standard</string>
        </dict>
      </dict>
    '';
    # Show apps inside the Spotlight window UI.
    "164" = ''
      <dict>
        <key>enabled</key><false/>
      </dict>
    '';
  };
  asUser = cmd: ''launchctl asuser "$(id -u -- ${userArg})" sudo --user=${userArg} -- ${cmd}'';
  disableSpotlightSymbolicHotkeys = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      id: plist:
      asUser "/usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${id} ${lib.escapeShellArg plist}"
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

      "bobko.aerospace" = {
        displayStyle = "i3Ordered"; # AeroSpace menu bar style: i3-style ordered workspace pills.
      };

      "com.openai.chat" = {
        # ChatGPT → Settings → App → Show in Menu Bar: Always.
        # The app stores this Swift enum as a JSON string rather than a plist dictionary.
        desktopMenuBarBehavior = ''{"always":{}}'';
        # ChatGPT → Settings → Chat bar → Keyboard shortcut: Option-Command-Space.
        # Carbon key code 49 is Space; modifier mask 2304 is Option (2048) + Command (256).
        KeyboardShortcuts_toggleLauncher = ''{"carbonModifiers":2304,"carbonKeyCode":49}'';
      };

      "com.google.Chrome" = {
        # Chrome policy: disable Chrome → Warn Before Quitting so Cmd-Q quits normally.
        WarnBeforeQuittingEnabled = false;
      };

      "com.googlecode.iterm2" = {
        # iTerm2 → Settings → General → Closing → Confirm Quit iTerm2.
        PromptOnQuit = false;
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
    # Writing the plist is necessary but not sufficient: HIToolbox keeps its own in-memory
    # binding table that survives reboots, so without the activateSettings call below the
    # plist says enabled=0 while Cmd-Space still opens Spotlight. See
    # https://github.com/nix-darwin/nix-darwin/issues/518 and
    # https://zameermanji.com/blog/2021/6/8/applying-com-apple-symbolichotkeys-changes-instantaneously/.
    # Settings.app must be closed during activation—if it is open it can rewrite the plist
    # from its own cached state and undo these writes.
    ${disableSpotlightSymbolicHotkeys}
    # Hide the Spotlight magnifying-glass menu bar extra: MenuItemHidden -int 1 (0 = show, 1 = hide).
    # Apple changes menu bar plumbing occasionally—verify after OS upgrades.
    ${asUser "/usr/bin/defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1"}
    # Force cfprefsd to refresh its in-memory snapshot of the file we just wrote; without
    # this read, activateSettings can pick up the stale cached values (Apple SE #405937).
    ${asUser "/usr/bin/defaults read com.apple.symbolichotkeys >/dev/null"}
    # Re-bind symbolic hotkeys into HIToolbox so the disabled state takes effect immediately
    # and persists across reboots. activateSettings is a private SystemAdministration helper
    # whose -u flag re-reads user preferences and applies them to the live session.
    ${asUser "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u"}
  '';
}
