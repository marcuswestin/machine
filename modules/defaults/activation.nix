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
  # Ice stores General -> Ice icon as JSON-encoded UserDefaults Data.
  # Imported value is ControlItemImageSet(name: Chevron, hidden: symbol chevron.left, visible: symbol chevron.right).
  iceChevronIconDataHex = lib.concatStrings [
    "7b2276697369626c65223a7b2273796d626f6c223a7b225f30223a2263686576726f6e2e7269676874227d7d2c"
    "226e616d65223a2243686576726f6e222c2268696464656e223a7b2273796d626f6c223a7b225f30223a2263686576726f6e2e6c656674227d7d7d"
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
    # Ice -> General -> Ice icon: Chevron. The app stores this setting as Data,
    # so nix-darwin's CustomUserPreferences cannot express it directly.
    ${asUser "/usr/bin/defaults write com.jordanbaird.Ice IceIcon -data ${iceChevronIconDataHex}"}
    # Force cfprefsd to refresh its in-memory snapshot of the file we just wrote; without
    # this read, activateSettings can pick up the stale cached values (Apple SE #405937).
    ${asUser "/usr/bin/defaults read com.apple.symbolichotkeys >/dev/null"}
    # Re-bind symbolic hotkeys into HIToolbox so the disabled state takes effect immediately
    # and persists across reboots. activateSettings is a private SystemAdministration helper
    # whose -u flag re-reads user preferences and applies them to the live session.
    ${asUser "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u"}
  '';
}
