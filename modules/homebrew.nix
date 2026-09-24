{
  inputs,
  lib,
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
      "machine/homebrew-local" = pkgs.runCommandLocal "homebrew-local" { } ''
        mkdir -p "$out"
        cp -R ${../homebrew/local}/. "$out"
      '';
      "anomalyco/tap" = inputs.homebrew-anomalyco-tap;
      "mobile-dev-inc/tap" = inputs.homebrew-mobile-dev-inc-tap;
      "nikitabobko/tap" = inputs.homebrew-nikitabobko-tap;
      "steipete/tap" = inputs.homebrew-steipete-tap;
    };
    user = user;
  };

  homebrew = {
    enable = true;

    # Homebrew requires explicit trust for non-official tap code. nix-darwin
    # does not yet expose Brewfile trust options, so declare narrow item trust
    # through its supported verbatim Brewfile escape hatch.
    extraConfig = ''
      tap "anomalyco/tap", trusted: { formula: "opencode" }
      tap "mobile-dev-inc/tap", trusted: { formula: "maestro" }
      tap "nikitabobko/tap", trusted: { cask: "aerospace" }
      tap "steipete/tap", trusted: { cask: "codexbar" }
    '';

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

  # nix-homebrew sets HOMEBREW_REPOSITORY to a marker under Library/, so brew's
  # own shell completions never land at $HOMEBREW_PREFIX/completions where the
  # share/zsh/site-functions/_brew symlink points. Relink from the brew package
  # after each activation so zsh compinit does not hit a dangling symlink.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    brew_lib="$(readlink /opt/homebrew/Library/Homebrew 2>/dev/null || true)"
    if [ -n "$brew_lib" ]; then
      brew_completions="$(cd "$(dirname "$brew_lib")/../completions" && pwd)"
      if [ -d "$brew_completions" ]; then
        echo "linking Homebrew shell completions from $brew_completions"
        mkdir -p /opt/homebrew/completions
        for shell in bash fish zsh; do
          if [ -d "$brew_completions/$shell" ]; then
            ln -sfn "$brew_completions/$shell" "/opt/homebrew/completions/$shell"
          fi
        done
      fi
    fi
  '';
}
