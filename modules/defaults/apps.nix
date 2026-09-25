{ ... }:

{
  system.defaults.CustomUserPreferences = {
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

    "com.stonerl.Thaw" = {
      # Imported from the live Thaw 1.2.0 domain, excluding source defaults, window frames,
      # Sparkle keys, migration flags, null hotkeys, menu-bar item caches, visibility caches,
      # and the large default menu-bar appearance blob. Key names still use the Ice prefix.
      # Data-backed icon and per-display Thaw Bar settings are written in activation.nix.
      # Thaw 3 owns profile layout and divider positions; do not reassert old positions on apply.
      ItemSpacingOffset = -10.0; # Menu bar item spacing/padding offset in points.
    };

    "eu.exelban.Stats" = {
      # Imported from /Users/ro/Desktop/Stats.plist. Keep the exported app/module settings,
      # but omit transient open-panel, window, toolbar, updater, version, and keychain state.
      # Stats widget ids used here: battery, line_chart, mini, and network_chart.
      CombinedModules = false;
      setupProcess = true; # Setup assistant completed; skips first-run onboarding.

      # Battery module. *_position values are Stats widget-picker order indices.
      Battery_barChart_position = 1;
      Battery_battery_additional = "innerPercentage"; # Show percentage inside the battery icon.
      Battery_battery_position = 0;
      Battery_batteryDetails_position = 3;
      Battery_label_position = 4;
      Battery_mini_position = 2;
      Battery_widget = "battery";

      # CPU module. updateInterval is seconds; line_chart_historyCount is retained chart samples.
      CPU_barChart_position = 3;
      CPU_label_position = 2;
      CPU_lineChart_position = 0;
      CPU_line_chart_color = "blue"; # Stats built-in blue chart color token.
      CPU_line_chart_historyCount = 30;
      CPU_mini_position = 1;
      CPU_pieChart_position = 4;
      CPU_tachometer_position = 5;
      CPU_updateInterval = 3;
      CPU_widget = "line_chart";

      # Disk module. *_position values are Stats widget-picker order indices.
      Disk_barChart_position = 2;
      Disk_label_position = 3;
      Disk_memory_position = 4;
      Disk_mini_position = 0;
      Disk_networkChart_position = 6;
      Disk_pieChart_position = 1;
      Disk_speed_position = 5;
      Disk_text_position = 7;
      Disk_widget = "mini";

      # GPU module. updateInterval is seconds; line_chart_historyCount is retained chart samples.
      GPU_barChart_position = 3;
      GPU_label_position = 2;
      GPU_lineChart_position = 0;
      GPU_line_chart_color = "secondBlue"; # Stats built-in secondary blue chart color token.
      GPU_line_chart_historyCount = 30;
      GPU_mini_position = 1;
      GPU_state = true;
      GPU_tachometer_position = 4;
      GPU_updateInterval = 3;
      GPU_widget = "line_chart";

      # Network module. *_position values are Stats widget-picker order indices.
      Network_label_position = 2;
      Network_networkChart_position = 0;
      Network_network_chart_box = true; # Draw the network chart box.
      Network_network_chart_frame = false; # Do not draw the network chart frame.
      Network_speed_position = 1;
      Network_state_position = 3;
      Network_text_position = 4;
      Network_widget = "network_chart";

      # RAM module. updateInterval is seconds; line_chart_historyCount is retained chart samples.
      RAM_barChart_position = 3;
      RAM_label_position = 2;
      RAM_lineChart_position = 0;
      RAM_line_chart_color = "teal"; # Stats built-in teal chart color token.
      RAM_line_chart_historyCount = 30;
      RAM_memory_position = 5;
      RAM_mini_position = 1;
      RAM_pieChart_position = 4;
      RAM_state_position = 8;
      RAM_tachometer_position = 6;
      RAM_text_position = 7;
      RAM_updateInterval = 3;
      RAM_widget = "line_chart";

      # macOS status-item autosave positions for the individual Stats menu bar modules.
      "NSStatusItem Preferred Position Battery" = 612.0;
      "NSStatusItem Preferred Position CPU" = 480.0;
      "NSStatusItem Preferred Position Disk" = 912.0;
      "NSStatusItem Preferred Position GPU" = 568.0;
      "NSStatusItem Preferred Position Network" = 963.0;
      "NSStatusItem Preferred Position RAM" = 524.0;
    };

    "com.openai.chat" = {
      # ChatGPT -> Settings -> App -> Show in Menu Bar: Always.
      # The app stores this Swift enum as a JSON string rather than a plist dictionary.
      desktopMenuBarBehavior = ''{"always":{}}'';
      # ChatGPT -> Settings -> Chat bar -> Keyboard shortcut: Option-Command-Space.
      # Carbon key code 49 is Space; modifier mask 2304 is Option (2048) + Command (256).
      KeyboardShortcuts_toggleLauncher = ''{"carbonModifiers":2304,"carbonKeyCode":49}'';
    };

    "com.google.Chrome" = {
      # Chrome policy: disable Chrome -> Warn Before Quitting so Cmd-Q quits normally.
      WarnBeforeQuittingEnabled = false;
    };

    "com.googlecode.iterm2" = {
      # iTerm2 -> Settings -> General -> Closing -> Confirm Quit iTerm2.
      PromptOnQuit = false;
    };
  };
}
