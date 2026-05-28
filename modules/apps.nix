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
      cleanup = "zap";
    };

    taps = [];

    brews = [
      "arduino-cli"
      "aws-vault"
      "gh"
      "mas"
      "node"
      "pdm"
      "pnpm"
      "tf-summarize"
      "tfenv"
      "typst"
    ];

    casks = [
      "1password"
      "arc"
      "balenaetcher"
      "claude"
      "docker-desktop"
      "drawio"
      "figma"
      "fujitsu-scansnap-home"
      "github"
      "google-drive"
      "microsoft-teams"
      "notion"
      "prosys-opc-ua-browser"
      "raycast"
      "slack"
      "vlc"
      "vscodium"
      "warp"
      "xmind"
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
