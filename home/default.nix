{username, ...}: {
  imports = [
    ./core.nix
    ./code-repos.nix
    ./shell.nix
    ./git.nix
    ./starship.nix
    ./vscode.nix
    ./zen.nix
  ];

  home = {
    inherit username;
    homeDirectory = "/Users/${username}";
    stateVersion = "25.11";
  };

  programs.home-manager.enable = true;
}
