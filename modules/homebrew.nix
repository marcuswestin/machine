{
  inputs,
  pkgs,
  user,
  ...
}:

{
  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    enableRosetta = false;
    taps = {
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
      "machine/homebrew-handy" = pkgs.runCommandLocal "homebrew-handy" { } ''
        mkdir -p "$out"
        cp -R ${../homebrew/handy}/. "$out"
      '';
      "nikitabobko/tap" = inputs.homebrew-nikitabobko-tap;
      "steipete/tap" = inputs.homebrew-steipete-tap;
    };
    user = user;
  };

  homebrew = {
    enable = true;
    caskArgs.no_quarantine = true;

    # Keep Homebrew's tap/API metadata fresh enough for cask installs.
    # This does not upgrade installed packages; `onActivation.upgrade` controls
    # that separately below.
    global.autoUpdate = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "none";
      extraEnv = {
        HOMEBREW_NO_ANALYTICS = "1";
        HOMEBREW_NO_ENV_HINTS = "1";
        # Homebrew 5.1.7 can crash while converting cask API JSON
        # dependencies (`undefined method 'to_sym' for nil`) during
        # `brew fetch`. Use tapped cask definitions during activation.
        HOMEBREW_NO_INSTALL_FROM_API = "1";
      };
      extraFlags = [
        "--jobs"
        "auto"
      ];
      upgrade = false;
    };
  };
}
