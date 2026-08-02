{pkgs, ...}: {
  # System-wide packages (reproducible, rollback-able).
  # Prefer Home Manager for user packages; keep this list minimal.
  environment.systemPackages = with pkgs; [
    awscli2
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

    brews = [
      "arduino-cli"
      "googleworkspace-cli"
      "imagemagick"
      "mas"
      # gh/node/pnpm stay on Homebrew deliberately: nixpkgs 25.11 lags behind
      # (gh 2.83 vs 2.96, node 24 vs 26, pnpm 10 vs 11). Revisit on the next
      # nixpkgs release. Everything else here is either macOS-only or not packaged.
      "gh"
      "node"
      "pnpm"
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
