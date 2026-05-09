{
  pkgs,
  user,
  ...
}:

{
  imports = [
    ../modules/apps.nix
    ../modules/defaults.nix
    ../modules/home-manager.nix
    ../modules/homebrew.nix
    ../modules/startup.nix
  ];

  # Determinate Nix manages the daemon itself; nix-darwin must not.
  nix.enable = false;

  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.${user}.home = "/Users/${user}";

  environment.systemPackages = with pkgs; [
    bun
    chezmoi
    cocoapods
    git
    jq
    just
    mas
    parallel
    ripgrep
  ];

  system.primaryUser = user;
  system.stateVersion = 6;
}
