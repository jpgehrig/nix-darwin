{...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    # superseded by atuin (Ctrl-R) in core.nix
    historySubstringSearch.enable = false;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    initContent = ''
      # Homebrew (Apple Silicon). `brew shellenv` prepends /opt/homebrew/bin,
      # which would shadow Nix-provided binaries of the same name. Capture the
      # Nix-managed PATH first and restore its precedence afterwards, so Nix
      # stays authoritative and Homebrew only supplies what Nix does not.
      if [ -x /opt/homebrew/bin/brew ]; then
        __nix_path="$PATH"
        eval "$(/opt/homebrew/bin/brew shellenv)"
        export PATH="$__nix_path:$PATH"
        unset __nix_path
      fi

      export PATH="$PATH:$HOME/bin:$HOME/.local/bin:$HOME/go/bin"

      # Point at the 1Password SSH agent (see home/git.nix). `ssh` itself gets
      # this from IdentityAgent in ~/.ssh/config, but git's SSH commit signing
      # shells out to ssh-keygen, which ignores ssh_config and reads only
      # SSH_AUTH_SOCK. Without this, auth works while commits fail with
      # "Couldn't find key in agent?". macOS presets this to its own launchd
      # agent, so it must be overridden here rather than merely defaulted.
      export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

      # Drop duplicate PATH entries, keeping the first (Nix) occurrence.
      typeset -U path PATH

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
    rebuild = "sudo darwin-rebuild switch --flake ~/.config/nix-darwin";
    urldecode = "python3 -c 'import sys, urllib.parse as ul; print(ul.unquote_plus(sys.stdin.read()))'";
    urlencode = "python3 -c 'import sys, urllib.parse as ul; print(ul.quote_plus(sys.stdin.read()))'";
  };
}
