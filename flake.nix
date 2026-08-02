{
  description = "Nix for macOS configuration";

  nixConfig = {
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-25.11-darwin";

    nix-darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    nix-darwin,
    home-manager,
    ...
  }: let
    username = "jpgehrig";
    useremail = "jp.gehrig@gmail.com";
    # Used for repos under ~/work/ via a conditional git include.
    useremailWork = "jp.gehrig@56k.cloud";
    system = "aarch64-darwin";

    # One entry per machine. `hostname` names the flake output *and* sets the
    # machine's ComputerName / LocalHostName, so `darwin-rebuild` with no
    # explicit `.#target` resolves to the host it is running on.
    mkHost = hostname: let
      specialArgs = inputs // {inherit username useremail useremailWork hostname;};
    in
      nix-darwin.lib.darwinSystem {
        inherit system specialArgs;
        modules = [
          ./modules/nix-core.nix
          ./modules/system.nix
          ./modules/apps.nix
          ./modules/host-users.nix

          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "hm-backup";
              extraSpecialArgs = specialArgs;
              users.${username} = import ./home;
            };
          }
        ];
      };
  in {
    darwinConfigurations = {
      jps-macbook = mkHost "jps-macbook";
      jps-old-macbook = mkHost "jps-old-macbook";
    };

    formatter.${system} = nixpkgs.legacyPackages.${system}.alejandra;
  };
}
