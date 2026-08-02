{pkgs, ...}: {
  # System-wide packages (reproducible, rollback-able).
  # Prefer Home Manager for user packages; keep this list minimal.
  environment.systemPackages = with pkgs; [
    git
  ];

  environment.variables.EDITOR = "nvim";

  # Homebrew must be installed manually first: https://brew.sh
  # GUI apps, App Store apps, and a few CLI tools not in nixpkgs.
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "none";
    };

    taps = [];

    # Homebrew-first for fast-moving standalone binaries: nixpkgs follows the
    # 25.11 release branch and only lands new upstream versions at the next
    # release, so tools that ship often sit months behind here.
    #
    # The exception is anything with a Home Manager module (fzf, atuin, zoxide,
    # eza, bat, delta, yazi, neovim, git). Those stay in Nix even when slightly
    # behind — HM generates their config and shell integration, and trading
    # declarative config for a minor version bump is a bad deal.
    brews = [
      "arduino-cli"
      "awscli" # 2.36 vs nixpkgs 2.31
      "gh" # 2.97 vs nixpkgs 2.83
      "googleworkspace-cli"
      "imagemagick"
      "mas"
      "node" # 26 vs nixpkgs 24
      "opentofu" # 1.12 vs nixpkgs 1.10; replaces the broken tfenv setup
      "pdm" # 2.28 vs nixpkgs 2.26
      "pnpm" # 11 vs nixpkgs 10
      "tf-summarize"
      "typst"
    ];

    casks = [
      "nikitabobko/tap/aerospace"
      "1password"
      "1password-cli"
      "balenaetcher"
      "claude"
      "docker-desktop"
      "drawio"
      "figma"
      # Nerd Font: required for eza --icons and Starship glyph presets.
      # Set it as your terminal font after the first rebuild.
      "font-jetbrains-mono-nerd-font"
      "fujitsu-scansnap-home"
      "github"
      "gcloud-cli"
      "google-drive"
      "onlyoffice"
      # greedy: also upgrade this self-updating cask on rebuild (`brew upgrade --greedy`).
      {
        name = "microsoft-teams";
        greedy = true;
      }
      "notion"
      "plaud"
      "prosys-opc-ua-browser"
      "raycast"
      "slack"
      "sketchup"
      "vlc"
      "warp"
      "xmind"
      "zed"
      "zen"
    ];

    masApps = {
      "dropover" = 1355679052;
      "nordvpn" = 905953485;
      "whatsapp" = 310633997;
      "windows app" = 1295203466;
    };
  };
}
