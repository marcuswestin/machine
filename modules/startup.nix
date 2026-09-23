{
  config,
  lib,
  pkgs,
  user,
  ...
}:

let
  # Repo-local script; applied at login only if it already contains a real displayplacer line.
  displayLayoutScript = "/Users/${user}/code/machine/scripts/display-layout.sh";
  # One user LaunchAgent starts these apps and applies the display layout.
  startupApps = [
    {
      name = "Handy";
      bundleIdentifier = "com.pais.handy";
      appPath = "/Applications/Handy.app";
      executable = "/Applications/Handy.app/Contents/MacOS/handy";
      args = [ "--start-hidden" ];
    }
    {
      name = "AeroSpace";
      bundleIdentifier = "bobko.aerospace";
      appPath = "/Applications/AeroSpace.app";
      executable = "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace";
      args = [ ];
    }
    {
      name = "Raycast";
      bundleIdentifier = "com.raycast.macos";
      appPath = "/Applications/Raycast.app";
      executable = "/Applications/Raycast.app/Contents/MacOS/Raycast";
      args = [ ];
    }
    {
      name = "CodexBar";
      bundleIdentifier = "com.steipete.codexbar";
      appPath = "/Applications/CodexBar.app";
      executable = "/Applications/CodexBar.app/Contents/MacOS/CodexBar";
      args = [ ];
    }
    {
      name = "Thaw";
      bundleIdentifier = "com.stonerl.Thaw";
      appPath = "/Applications/Thaw.app";
      executable = "/Applications/Thaw.app/Contents/MacOS/Thaw";
      args = [ ];
    }
    {
      name = "Stats";
      bundleIdentifier = "eu.exelban.Stats";
      appPath = "/Applications/Stats.app";
      executable = "/Applications/Stats.app/Contents/MacOS/Stats";
      args = [ ];
    }
  ];

  agentKeyFragment = app: lib.replaceStrings [ " " ] [ "-" ] (lib.toLower app.name);
  toPlist = lib.generators.toPlist { escape = true; };
  loginProgram = "/usr/local/libexec/machine-login-startup";

  # Each subshell exits independently, so an already-running app cannot skip
  # the remaining apps or display layout. Paths and args remain shell-quoted.
  appLaunchCommand =
    app:
    ''
      (
        process_name="$(/usr/bin/basename ${lib.escapeShellArg app.executable})"
        if /usr/bin/pgrep -x "$process_name" >/dev/null 2>&1 \
          || /usr/bin/pgrep -f ${lib.escapeShellArg app.executable} >/dev/null 2>&1; then
          exit 0
        fi

        if /usr/bin/open -gj ${lib.escapeShellArg app.appPath}; then
          exit 0
        fi

        # Launch Services failed; start the declared binary without blocking the next app.
        nohup ${lib.escapeShellArg app.executable} ${lib.escapeShellArgs app.args} >/dev/null 2>&1 &
      )
    '';

  loginScript = pkgs.writeText "machine-login-startup" ''
    #!/bin/sh
    set -eu
    /bin/wait4path /nix/store
    ${lib.concatMapStringsSep "\n" appLaunchCommand config.machine.startupApps}

    # The captured layout is a no-op until it contains a displayplacer command.
      display_layout_script=${lib.escapeShellArg displayLayoutScript}
    if [ -x "$display_layout_script" ] \
      && /usr/bin/grep -Eq '^[[:space:]]*exec[[:space:]]+displayplacer[[:space:]]+' "$display_layout_script"; then
      PATH="/opt/homebrew/bin:/usr/local/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
      export PATH
      "$display_layout_script" || true
    fi
  '';

  loginAgentFile = {
    text = toPlist {
      Label = "org.nixos.machine-login-startup";
      Program = loginProgram;
      ProgramArguments = [ loginProgram ];
      RunAtLoad = true;
    };
  };

  legacyAgentFiles = (map (app: "org.nixos.open-${agentKeyFragment app}.plist") startupApps) ++ [
    "org.nixos.display-layout.plist"
  ];
in

{
  options.machine.startupApps = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
          bundleIdentifier = lib.mkOption { type = lib.types.str; };
          appPath = lib.mkOption { type = lib.types.str; };
          executable = lib.mkOption { type = lib.types.str; };
          args = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };
        };
      }
    );
    default = [ ];
    description = "Applications to launch after setup and at user login.";
  };

  config = {
    machine.startupApps = startupApps;
    environment.userLaunchAgents = {
      "org.nixos.machine-login-startup.plist" = loginAgentFile;
    };

    # A fixed, root-owned path keeps the Background App Activity identity stable
    # even when the Nix store derivation changes on a later apply.
    system.activationScripts.preActivation.text = lib.mkAfter ''
      mkdir -p /usr/local/libexec
      if ! cmp -s ${loginScript} ${loginProgram}; then
        install -o root -g wheel -m 0555 ${loginScript} ${loginProgram}
      fi
    '';

    # /run/current-system is missing when boot activation was disallowed, so
    # nix-darwin cannot discover these retired agents through its usual diff.
    system.activationScripts.userLaunchd.text = lib.mkAfter ''
      for name in ${lib.escapeShellArgs legacyAgentFiles}; do
        legacy="/Users/${user}/Library/LaunchAgents/$name"
        if [ -e "$legacy" ]; then
          launchctl asuser "$(id -u -- ${user})" sudo --user=${user} -- launchctl unload "$legacy" || true
          rm -f "$legacy"
        fi
      done
    '';
  };
}
