{ inputs, user, ... }:

{
  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    enableRosetta = true;
    taps = {
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
    user = user;
  };

  homebrew = {
    enable = true;

    # Keep Homebrew's tap/API metadata fresh enough for cask installs.
    # This does not upgrade installed packages; `onActivation.upgrade` controls
    # that separately below.
    global.autoUpdate = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "none";
      extraEnv = {
        # Homebrew 5.1.7 can crash while converting cask API JSON
        # dependencies (`undefined method 'to_sym' for nil`). Use tapped cask
        # definitions during nix-darwin activation instead of the API loader.
        HOMEBREW_NO_INSTALL_FROM_API = "1";
      };
      upgrade = false;
    };
  };
}
