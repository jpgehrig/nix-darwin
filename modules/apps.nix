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
    ];

    # `brew install --cask`
    casks = [
      "arc"
      "1password"
      "docker"
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
      "postico" = 1031280567;
      "ticktick" = 966085870;
    };
  };
}