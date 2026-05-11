{
  pkgs,
  user,
  ...
}:

{
  imports = [
    ../modules/apps.nix
    ../modules/defaults.nix
    ../modules/raycast.nix
    ../modules/home-manager.nix
    ../modules/homebrew.nix
    ../modules/startup.nix
  ];

  # Determinate Nix manages the daemon itself; nix-darwin must not.
  nix.enable = false;

  security.pam.services.sudo_local.touchIdAuth = true;

  nixpkgs.hostPlatform = "aarch64-darwin";

  users.users.${user}.home = "/Users/${user}";

  environment.systemPackages = with pkgs; [
    bun
    chezmoi
    cocoapods
    devenv
    dprint
    direnv
    gh
    git
    jq
    just
    mas
    parallel
    ripgrep
    taplo
  ];

  system.primaryUser = user;
  # nix-darwin migration compatibility version. This is not the macOS version;
  # only bump it intentionally when accepting nix-darwin state migrations.
  system.stateVersion = 6;
}
