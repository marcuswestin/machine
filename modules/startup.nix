{
  config,
  lib,
  user,
  ...
}:

let
  displayLayoutScript = "/Users/${user}/code/machine/scripts/display-layout.sh";
  startupApps = [
    {
      name = "Handy";
      appPath = "/Applications/Handy.app";
      executable = "/Applications/Handy.app/Contents/MacOS/handy";
      args = [ "--start-hidden" ];
    }
    {
      name = "AeroSpace";
      appPath = "/Applications/AeroSpace.app";
      executable = "/Applications/AeroSpace.app/Contents/MacOS/AeroSpace";
      args = [ ];
    }
    {
      name = "Raycast";
      appPath = "/Applications/Raycast.app";
      executable = "/Applications/Raycast.app/Contents/MacOS/Raycast";
      args = [ ];
    }
    {
      name = "CodexBar";
      appPath = "/Applications/CodexBar.app";
      executable = "/Applications/CodexBar.app/Contents/MacOS/CodexBar";
      args = [ ];
    }
    {
      name = "Docker";
      appPath = "/Applications/Docker.app";
      executable = "/Applications/Docker.app/Contents/MacOS/com.docker.backend";
      args = [ ];
    }
  ];

  launchAgentFor =
    app:
    lib.nameValuePair "open-${lib.toLower app.name}" {
      script = ''
        process_name="$(/usr/bin/basename ${lib.escapeShellArg app.executable})"
        if /usr/bin/pgrep -x "$process_name" >/dev/null 2>&1; then
          exit 0
        fi

        if /usr/bin/pgrep -f ${lib.escapeShellArg app.executable} >/dev/null 2>&1; then
          exit 0
        fi

        if [ -e ${lib.escapeShellArg app.appPath} ]; then
          /usr/bin/open -gj ${lib.escapeShellArg app.appPath} && exit 0
        fi

        if [ -x ${lib.escapeShellArg app.executable} ]; then
          exec ${lib.escapeShellArg app.executable} ${lib.escapeShellArgs app.args}
        fi

        exit 0
      '';
      serviceConfig = {
        RunAtLoad = true;
      };
    };

  displayLayoutAgent = {
    script = ''
      display_layout_script=${lib.escapeShellArg displayLayoutScript}
      if [ ! -x "$display_layout_script" ]; then
        exit 0
      fi

      # Captured layouts contain an exec displayplacer command. The initial
      # placeholder stays a no-op so login is clean before a layout is captured.
      if ! /usr/bin/grep -Eq '^[[:space:]]*exec[[:space:]]+displayplacer[[:space:]]+' "$display_layout_script"; then
        exit 0
      fi

      export PATH="/opt/homebrew/bin:/usr/local/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
      "$display_layout_script" || true
    '';
    serviceConfig = {
      RunAtLoad = true;
    };
  };
in

{
  options.machine.startupApps = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption { type = lib.types.str; };
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
    launchd.user.agents = lib.listToAttrs (map launchAgentFor config.machine.startupApps) // {
      display-layout = displayLayoutAgent;
    };
  };
}
