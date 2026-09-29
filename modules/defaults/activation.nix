{ lib, user, ... }:

let
  userArg = lib.escapeShellArg user;
  # AppleSymbolicHotKeys parameters are [character code, hardware key code, modifier mask].
  # 32/49 is Space. 262144 is Control; 1048576 is Command;
  # 1572864 is Command+Option.
  # Use XML plist fragments, not old-style ASCII ({ enabled = 0; ... }): `defaults write
  # -dict-add` parses bare 0 / 49 as <string>, not <false/> / <integer>, and HIToolbox
  # ignores wrongly-typed entries--silently leaving a shortcut unchanged.
  configuredSymbolicHotkeys = {
    # Previous input source (Control-Space), reserved for Raycast.
    "60" = ''
      <dict>
        <key>enabled</key><false/>
        <key>value</key>
        <dict>
          <key>parameters</key>
          <array>
            <integer>32</integer>
            <integer>49</integer>
            <integer>262144</integer>
          </array>
          <key>type</key><string>standard</string>
        </dict>
      </dict>
    '';
    # Spotlight search (Cmd-Space).
    "64" = ''
      <dict>
        <key>enabled</key><true/>
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
  configureSymbolicHotkeys = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      id: plist:
      asUser "/usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add ${id} ${lib.escapeShellArg plist}"
    ) configuredSymbolicHotkeys
  );
in

{
  system.activationScripts.postActivation.text = ''
    # Reserve Control-Space for Raycast and restore Cmd-Space for Spotlight search.
    # Writing the plist is necessary but not sufficient: HIToolbox keeps its own in-memory
    # binding table that survives reboots, so without the activateSettings call below
    # the plist and live keyboard bindings can disagree. See
    # https://github.com/nix-darwin/nix-darwin/issues/518 and
    # https://zameermanji.com/blog/2021/6/8/applying-com-apple-symbolichotkeys-changes-instantaneously/.
    # Settings.app must be closed during activation--if it is open it can rewrite the plist
    # from its own cached state and undo these writes.
    ${configureSymbolicHotkeys}
    # Keep the Spotlight magnifying-glass menu bar extra hidden; Cmd-Space still opens it.
    # MenuItemHidden -int 1 means hide (0 = show).
    # Apple changes menu bar plumbing occasionally--verify after OS upgrades.
    ${asUser "/usr/bin/defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1"}
    # Force cfprefsd to refresh its in-memory snapshot of the file we just wrote; without
    # this read, activateSettings can pick up the stale cached values (Apple SE #405937).
    ${asUser "/usr/bin/defaults read com.apple.symbolichotkeys >/dev/null"}
    # Re-bind symbolic hotkeys into HIToolbox so the new shortcuts take effect immediately
    # and persist across reboots. activateSettings is a private SystemAdministration helper
    # whose -u flag re-reads user preferences and applies them to the live session.
    ${asUser "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u"}
  '';
}
