{pkgs, ...}: {
  # System-wide packages (reproducible, rollback-able).
  # Prefer Home Manager for user packages; keep this list minimal.
  environment.systemPackages = with pkgs; [
    awscli2
    git
    python312
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
      "gh"
      "googleworkspace-cli"
      "imagemagick"
      "mas"
      "node"
      "pdm"
      "pnpm"
      "tf-summarize"
      "tfenv"
      "typst"
    ];

    casks = [
      "nikitabobko/tap/aerospace"
      "1password"
      "1password-cli"
      "balenaetcher"
      "claude"
      "claude-code"
      "docker-desktop"
      "drawio"
      "figma"
      "fujitsu-scansnap-home"
      "github"
      "gcloud-cli"
      "google-drive"
      "libreoffice"
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
      "hidden bar" = 1452453066;
      "nordvpn" = 905953485;
      "whatsapp" = 310633997;
      "windows app" = 1295203466;
    };
  };
}
