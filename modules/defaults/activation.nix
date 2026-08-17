{ lib, user, ... }:

let
  userArg = lib.escapeShellArg user;
  # AppleSymbolicHotKeys parameters are [character code, hardware key code, modifier mask].
  # 32/49 is Space. 1048576 is Command; 1572864 is Command+Option.
  # Use XML plist fragments, not old-style ASCII ({ enabled = 0; ... }): `defaults write
  # -dict-add` parses bare 0 / 49 as <string>, not <false/> / <integer>, and HIToolbox
  # ignores wrongly-typed entries--silently leaving Cmd-Space bound to Spotlight.
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
  # Thaw stores General -> Thaw icon as JSON-encoded UserDefaults Data (key IceIcon).
  # Imported value is ControlItemImageSet(name: Dot, hidden: catalog DotFill, visible: catalog DotStroke).
  thawDotIconDataHex = lib.concatStrings [
    "7b2268696464656e223a7b22636174616c6f67223a7b225f30223a22446f7446696c6c227d7d2c"
    "226e616d65223a22446f74222c2276697369626c65223a7b22636174616c6f67223a7b225f30223a22446f745374726f6b65227d7d7d"
  ];
  # Thaw stores Display -> Use Thaw Bar as JSON-encoded UserDefaults Data keyed by display UUID.
  # Imported display 37D8832A-2D66-02CA-B9F7-8F30A301B230 uses the Thaw Bar with location 1
  # (mouse pointer) and alwaysShowHiddenItems=false.
  thawDisplayIceBarConfigurationsDataHex = lib.concatStrings [
    "7b2233374438383332412d324436362d303243412d423946372d384633304133303142323330223a"
    "7b226963654261724c6f636174696f6e223a312c22616c7761797353686f7748696464656e4974656d73223a66616c73652c"
    "22757365496365426172223a747275657d7d"
  ];
in

{
  system.activationScripts.postActivation.text = ''
    # Disable macOS Spotlight keyboard shortcuts (Raycast uses Cmd-Space / Cmd-Opt-Space).
    # Writing the plist is necessary but not sufficient: HIToolbox keeps its own in-memory
    # binding table that survives reboots, so without the activateSettings call below the
    # plist says enabled=0 while Cmd-Space still opens Spotlight. See
    # https://github.com/nix-darwin/nix-darwin/issues/518 and
    # https://zameermanji.com/blog/2021/6/8/applying-com-apple-symbolichotkeys-changes-instantaneously/.
    # Settings.app must be closed during activation--if it is open it can rewrite the plist
    # from its own cached state and undo these writes.
    ${disableSpotlightSymbolicHotkeys}
    # Hide the Spotlight magnifying-glass menu bar extra: MenuItemHidden -int 1 (0 = show, 1 = hide).
    # Apple changes menu bar plumbing occasionally--verify after OS upgrades.
    ${asUser "/usr/bin/defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1"}
    # Thaw -> General -> Thaw icon: Dot. The app stores this setting as Data,
    # so nix-darwin's CustomUserPreferences cannot express it directly.
    ${asUser "/usr/bin/defaults write com.stonerl.Thaw IceIcon -data ${thawDotIconDataHex}"}
    # Thaw -> Display -> Use Thaw Bar: enabled for the imported display, located at the mouse pointer.
    ${asUser "/usr/bin/defaults write com.stonerl.Thaw DisplayIceBarConfigurations -data ${thawDisplayIceBarConfigurationsDataHex}"}
    # Force cfprefsd to refresh its in-memory snapshot of the file we just wrote; without
    # this read, activateSettings can pick up the stale cached values (Apple SE #405937).
    ${asUser "/usr/bin/defaults read com.apple.symbolichotkeys >/dev/null"}
    # Re-bind symbolic hotkeys into HIToolbox so the disabled state takes effect immediately
    # and persists across reboots. activateSettings is a private SystemAdministration helper
    # whose -u flag re-reads user preferences and applies them to the live session.
    ${asUser "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u"}
  '';
}
