{ user, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.${user} = {
      home = {
        username = user;
        homeDirectory = "/Users/${user}";
        # Home Manager migration compatibility version. This is not the
        # installed package version; only bump it intentionally.
        stateVersion = "25.05";

        sessionPath = [
          "$HOME/.local/bin"
          "$HOME/.cargo/bin"
        ];

        sessionVariables = {
          EDITOR = "cursor -w";
          VISUAL = "cursor -w";
          HOMEBREW_NO_ENV_HINTS = "1";
        };
      };

      programs.home-manager.enable = true;
      manual.manpages.enable = false;
    };
  };
}
