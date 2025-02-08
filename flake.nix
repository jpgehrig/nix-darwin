{
  description = "Example nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:LnL7/nix-darwin/master";
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    mac-app-util.url = "github:hraban/mac-app-util";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs@{ self, nixpkgs, nix-darwin, nix-homebrew, mac-app-util }:
  let
    configuration = { pkgs, ... }: {

      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [
        pkgs.neovim
      ];

      # Homebrew packages
      homebrew = {
        enable = true;
        brews = [
          "mas"
        ];
        casks = [
          "arc"
          "1password"
          "docker"
          "figma"
          "fujitsu-scansnap-home"
          "microsoft-office"
          "microsoft-teams"
          "notion"
          "raycast"
          "sketchup"
          "slack"
          "ticktick"
          "visual-studio-code"
          "warp"
        ];
        masApps = {
          "postico" = 1031280567;
        };
        onActivation.cleanup = "zap";
      };

      # Necessary for using flakes on this system.
      nix.settings.experimental-features = "nix-command flakes";

      # Enable alternative shell support in nix-darwin.
      # programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      # The platform the configuration will be used on.
      nixpkgs.hostPlatform = "aarch64-darwin";

      # Touch ID instead of password
      security.pam.enableSudoTouchIdAuth = true;
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#jps-mbp
    darwinConfigurations."jps-mbp" = nix-darwin.lib.darwinSystem {
      modules = [
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            # Install Homebrew under the default prefix
            enable = true;
            # Apple Silicon Only: Also install Homebrew under the default Intel prefix for Rosetta 2
            enableRosetta = true;
            # User owning the Homebrew prefix
            user = "jpgehrig";
          };
        }
        mac-app-util.darwinModules.default
      ];
    };
  };
}
