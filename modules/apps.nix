{ pkgs, ...}: {

  ##########################################################################
  #
  #  Install all apps and packages here.
  #
  #  NOTE: Your can find all available options in:
  #    https://daiderd.com/nix-darwin/manual/index.html
  #
  #
  ##########################################################################

  # Install packages from nix's official package repository.
  #
  # The packages installed here are available to all users, and are reproducible across machines, and are rollbackable.
  # But on macOS, it's less stable than homebrew.
  #
  # Related Discussion: https://discourse.nixos.org/t/darwin-again/29331
  environment.systemPackages = with pkgs; [
    awscli2
    git
    python312
    # neovim is managed via home-manager in home/core.nix
  ];

  environment.variables.EDITOR = "nvim";

  # To make this work, homebrew need to be installed manually, see https://brew.sh
  #
  # The apps installed by homebrew are not managed by nix, and not reproducible!
  # But on macOS, homebrew has a much larger selection of apps than nixpkgs, especially for GUI apps!
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    # homebrew/services tap is deprecated - services are now built-in
    taps = [
    ];

    # `brew install`
    brews = [
      "aws-sam-cli"
      "mas"
      "pdm"
      "k6"
      "tfenv"
      "tf-summarize"
      "gh"
    ];

    # `brew install --cask`
    casks = [
      "1password"
      "arc"
      "clockify"
      "docker-desktop"
      "drawio"
      "figma"
      "github"
      "google-drive"
      "fujitsu-scansnap-home"
      "microsoft-office"
      "microsoft-teams"
      "notion"
      "raycast"
      "sketchup"
      "slack"
      "vlc"
      "warp"
      "xmind"
    ];

    # Apps from AppStore
    masApps = {
      "dropover" = 1355679052;
      "hidden bar" = 1452453066;
      "nordvpn" = 905953485;
      "postico" = 1031280567;
      "ticktick" = 966085870;
      "whatsapp" = 310633997;
      "windows app" = 1295203466;
    };
  };
}