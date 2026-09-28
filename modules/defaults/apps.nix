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

    "com.steipete.codexbar" = {
      # CodexBar 0.60.3: one provider icon with usage percentage, selected by
      # highest usage. Provider credentials stay in its writable private config.
      mergeIcons = true;
      menuBarDisplayMode = "percent"; # Numeric usage percentage rather than a reset countdown.
      menuBarShowsBrandIconWithPercent = true;
      menuBarShowsHighestUsage = true;
      selectedMenuProvider = "codex"; # Initial/fallback provider; highest usage can select another.
      usageBarsShowUsed = true;
      resetTimesShowAbsolute = true;
      multiAccountMenuLayout = "stacked"; # Show account cards together in the dropdown.
      costSummaryDisplayStyle = "both"; # Show both the inline cost summary and cost submenu.
    };

    "eu.exelban.Stats" = {
      # Imported from /Users/ro/Desktop/Stats.plist. Keep the exported app/module settings,
      # but omit transient open-panel, window, toolbar, updater, version, and keychain state.
      # Stats widget ids used here: battery, line_chart, mini, and network_chart.
      # Keep the metrics in one status item so macOS/Thaw cannot reorder them.
      CombinedModules = true;
      CombinedModules_popup = false; # Clicking a metric opens that module's own popup.
      # Stats sorts combinedPosition (the *_position keys below) ascending,
      # placing modules from left to right. These are ranks, not screen offsets.
      GPU_position = 0;
      Network_position = 1;
      Disk_position = 2;
      Sensors_position = 3;
      RAM_position = 4;
      CPU_position = 5;
      Battery_position = 6;
      pause = false; # Keep the selected menu bar modules running.
      # Explicit module switches override choices already saved on another Mac.
      # Stats still omits modules unsupported by that Mac's hardware.
      Battery_state = true;
      Bluetooth_state = false;
      CPU_state = true;
      Clock_state = false;
      Disk_state = true;
      Network_state = true;
      RAM_state = true;
      Remote_state = false;
      Sensors_state = true;
      # Stats 3.0.17 checks for this key's existence before showing its setup
      # assistant (Stats/helpers.swift). Module choices below replace that wizard.
      setupProcess = true;

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
      CPU_line_chart_box = true;
      CPU_line_chart_frame = false;
      CPU_line_chart_label = true;
      CPU_line_chart_value = true;
      CPU_line_chart_valueColor = false; # Keep the numeric value independent of the chart color.
      CPU_line_chart_scale = "none"; # Stats' unscaled utilization chart (fixed full-scale range).
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
      SSD_mini_color = "monochrome"; # The Disk mini widget uses the title SSD in its preference keys.

      # GPU module. updateInterval is seconds; line_chart_historyCount is retained chart samples.
      GPU_barChart_position = 3;
      GPU_label_position = 2;
      GPU_lineChart_position = 0;
      GPU_line_chart_color = "secondBlue"; # Stats built-in secondary blue chart color token.
      GPU_line_chart_historyCount = 30;
      GPU_line_chart_label = true;
      GPU_line_chart_value = true;
      GPU_line_chart_scale = "none"; # Stats' unscaled utilization chart (fixed full-scale range).
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
      RAM_line_chart_label = true;
      RAM_line_chart_value = true;
      RAM_memory_position = 5;
      RAM_mini_position = 1;
      RAM_pieChart_position = 4;
      RAM_state_position = 8;
      RAM_tachometer_position = 6;
      RAM_text_position = 7;
      RAM_updateInterval = 3;
      RAM_widget = "line_chart";

      # Sensors' compact numeric widget; Stats calls its display title "Sensor".
      Sensors_widget = "mini";
      Sensor_mini_label = true;
      Sensors_barChart_position = 3;
      Sensors_label_position = 2;
      Sensors_mini_position = 0;
      Sensors_stack_position = 1;

      # The combined item's position among other apps belongs to Thaw. Old
      # per-module NSStatusItem screen offsets do not control its internal order.
    };

    "com.openai.chat" = {
      # Legacy ChatGPT domain. The current app bundle is com.openai.codex;
      # the helper's current shortcut keys are declared below.
      # Legacy ChatGPT -> Settings -> App -> Show in Menu Bar: Always.
      # The app stores this Swift enum as a JSON string rather than a plist dictionary.
      desktopMenuBarBehavior = ''{"always":{}}'';
      # Legacy ChatGPT -> Settings -> Chat bar -> Keyboard shortcut: Option-Command-Space.
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
      # The stable GUID of our chezmoi DynamicProfiles/machine.json profile.
      "Default Bookmark Guid" = "1e7270ff-59ad-4b07-b2b0-87089cb2748d";
      ApplePressAndHoldEnabled = false; # Holding a key repeats instead of showing accented characters.
      UseLionStyleFullscreen = false; # iTerm's traditional fullscreen rather than a separate macOS Space.
      HapticFeedbackForEsc = false;
      SoundForEsc = false;
      VisualIndicatorForEsc = false;
    };

    "ChatGPTHelper" = {
      # Current ChatGPT launcher helper owns these shortcuts independently of
      # the legacy com.openai.chat app. Carbon 49 = Space; 2304 = Option + Command.
      KeyboardShortcuts_toggleLauncher = ''{"carbonKeyCode":49,"carbonModifiers":2304}'';
      # 6400 = Control (4096) + Option (2048) + Command (256).
      KeyboardShortcuts_toggleAttachedLauncher = ''{"carbonKeyCode":49,"carbonModifiers":6400}'';
    };
  };
}
