{
  config,
  lib,
  user,
  ...
}:

let
  # Repo-local script; applied at login only if it already contains a real displayplacer line.
  displayLayoutScript = "/Users/${user}/code/machine/scripts/display-layout.sh";
  # Each entry drives a user LaunchAgent: try the .app bundle first, fall back to the bundle binary + args.
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
      name = "Docker Desktop";
      bundleIdentifier = "com.docker.docker";
      appPath = "/Applications/Docker.app";
      executable = "/Applications/Docker.app/Contents/MacOS/com.docker.backend";
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

  # nix-darwin builds plist paths from the agent key; spaces (e.g. "Docker Desktop") break activate(8)'s shell.
  agentKeyFragment = app: lib.replaceStrings [ " " ] [ "-" ] (lib.toLower app.name);
  toPlist = lib.generators.toPlist { escape = true; };

  # Nix interpolates paths/args through lib.escapeShellArg(s) so spaces and metacharacters stay one shell word each.
  appLaunchCommand =
    app:
    ''
        /bin/wait4path /nix/store

        process_name="$(/usr/bin/basename ${lib.escapeShellArg app.executable})"
        # -x: exact process name match (cheap guard when the binary basename is unique).
        if /usr/bin/pgrep -x "$process_name" >/dev/null 2>&1; then
          exit 0
        fi

        # -f: full command line match on the executable path (catches renamed helpers sharing a basename).
        if /usr/bin/pgrep -f ${lib.escapeShellArg app.executable} >/dev/null 2>&1; then
          exit 0
        fi

        # Prefer Launch Services: -g do not foreground, -j start hidden (when the app supports it).
        if /usr/bin/open -gj ${lib.escapeShellArg app.appPath}; then
          exit 0
        fi

        # Last resort: run the bundle’s Mach-O directly with the declared argv (same words open would use).
        exec ${lib.escapeShellArg app.executable} ${lib.escapeShellArgs app.args}
    '';

  launchAgentFileFor =
    app:
    let
      label = "org.nixos.open-${agentKeyFragment app}";
    in
    lib.nameValuePair "${label}.plist" {
      text = toPlist {
        Label = label;
        Program = "/bin/sh";
        ProgramArguments = [
          app.name
          "-c"
          (appLaunchCommand app)
        ];
        # AssociatedBundleIdentifiers is Apple’s legacy LaunchAgent hint for
        # System Settings → Login Items & Extensions app names/icons.
        AssociatedBundleIdentifiers = [ app.bundleIdentifier ];
        RunAtLoad = true;
      };
    };

  displayLayoutAgentFile = {
    text = toPlist {
      Label = "org.nixos.display-layout";
      Program = "/bin/sh";
      ProgramArguments = [
        "Display Layout"
        "-c"
        ''
      /bin/wait4path /nix/store

      display_layout_script=${lib.escapeShellArg displayLayoutScript}
      if [ ! -x "$display_layout_script" ]; then
        exit 0
      fi

      # Captured layouts contain an exec displayplacer command. The initial
      # placeholder stays a no-op so login is clean before a layout is captured.
      if ! /usr/bin/grep -Eq '^[[:space:]]*exec[[:space:]]+displayplacer[[:space:]]+' "$display_layout_script"; then
        exit 0
      fi

      # displayplacer is Homebrew-managed here; nix paths cover darwin-rebuild and default profiles.
      export PATH="/opt/homebrew/bin:/usr/local/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:$PATH"
      "$display_layout_script" || true
        ''
      ];
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
    environment.userLaunchAgents = lib.listToAttrs (map launchAgentFileFor config.machine.startupApps) // {
      "org.nixos.display-layout.plist" = displayLayoutAgentFile;
    };
  };
}
