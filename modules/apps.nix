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
    git
    neovim
    awscli2
  ];

  environment.variables.EDITOR = "nvim";

  # To make this work, homebrew need to be installed manually, see https://brew.sh
  #
  # The apps installed by homebrew are not managed by nix, and not reproducible!
  # But on macOS, homebrew has a much larger selection of apps than nixpkgs, especially for GUI apps!
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      cleanup = "zap";
    };

    taps = [
      "homebrew/services"
    ];

    # `brew install`
    brews = [
      "mas"
      "tfenv"
      "gh"
    ];

    # `brew install --cask`
    casks = [
      "arc"
      "1password"
      "docker"
      "drawio"
      "figma"
      "github"
      "fujitsu-scansnap-home"
      "microsoft-office"
      "microsoft-teams"
      "notion"
      "raycast"
      "sketchup"
      "slack"
      "visual-studio-code"
      "warp"
    ];

    # Apps from AppStore
    masApps = {
      "dropover" = 1355679052;
      "hidden bar" = 1452453066;
      "nordvpn" = 905953485;
      "poolsuite fm" = 1514817810;
      "postico" = 1031280567;
      "spark mail" = 6445813049;
      "ticktick" = 966085870;
      "whatsapp" = 310633997;
      "windows app" = 1295203466;
    };
  };
}