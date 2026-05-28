{username, ...}: {
  imports = [
    ./core.nix
    ./shell.nix
    ./git.nix
    ./starship.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/Users/${username}";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}