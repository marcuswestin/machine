{ config, lib, ... }:

let
  startupApps = [
    "Handy"
    "AeroSpace"
    "Raycast"
  ];

  launchAgentFor =
    app:
    lib.nameValuePair "open-${lib.toLower app}" {
      command = "/usr/bin/open -gj -a ${lib.escapeShellArg app}";
      serviceConfig = {
        RunAtLoad = true;
      };
    };
in

{
  options.machine.startupApps = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Applications to launch after setup and at user login.";
  };

  config = {
    machine.startupApps = startupApps;
    launchd.user.agents = lib.listToAttrs (map launchAgentFor config.machine.startupApps);
  };
}
