{ config, lib, ... }:

let
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
  ];

  launchAgentFor =
    app:
    lib.nameValuePair "open-${lib.toLower app.name}" {
      script = ''
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
    launchd.user.agents = lib.listToAttrs (map launchAgentFor config.machine.startupApps);
  };
}
