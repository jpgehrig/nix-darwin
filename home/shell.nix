{...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    historySubstringSearch.enable = true;
    initContent = ''
      # Homebrew
      eval "$(/opt/homebrew/bin/brew shellenv)"

      # Additional paths
      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"

      # Fix Delete key
      bindkey "^[[3~" delete-char
      bindkey "\e[3~" delete-char
    '';
  };

  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  home.shellAliases = {
    k = "kubectl";

    # nix-darwin rebuild
    rebuild = "darwin-rebuild switch --flake ~/.config/nix-darwin";

    urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
    urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
  };
}
