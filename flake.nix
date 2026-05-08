{
  description = "Declarative macOS machine setup";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    # Kept pinned in flake.lock for now; dotfiles are managed by chezmoi.
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nix-darwin,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      # Personal defaults for this repo. Change these values to adapt the
      # machine declaration for another user, hostname, or architecture.
      user = "ro";
      system = "aarch64-darwin";
      host = "machine";
    in
    {
      darwinConfigurations.${host} = nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = { inherit inputs user host; };
        modules = [
          ./hosts/machine.nix
          home-manager.darwinModules.home-manager
          nix-homebrew.darwinModules.nix-homebrew
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-rfc-style;
    };
}
