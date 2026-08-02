{pkgs, ...}: {
  home.packages = with pkgs; [
    # archives
    zip
    xz
    unzip
    p7zip

    # utils
    ripgrep # recursively searches directories for a regex pattern
    fd # fast, user-friendly `find` replacement; backs fzf's file walk
    sd # intuitive `sed` replacement for simple find-and-replace
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processer https://github.com/mikefarah/yq
    # fzf is configured via programs.fzf below

    # system monitoring
    btop # resource monitor, a better top/htop
    dust # `du` replacement showing what is eating disk
    duf # `df` replacement with a readable table
    procs # `ps` replacement
    hyperfine # command-line benchmarking tool

    # dev tooling (moved off Homebrew)
    pdm # Python package manager
    opentofu # open-source Terraform fork; replaces the broken tfenv setup
    python313 # default interpreter; project envs come from direnv/pdm

    # nix helpers
    comma # run any package without installing it: `, cowsay hi`

    aria2 # A lightweight multi-protocol & multi-source command-line download utility
    socat # replacement of openbsd-netcat
    nmap # A utility for network discovery and security auditing

    # misc
    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    caddy
    gnupg

    # productivity
    glow # markdown previewer in terminal
  ];

  programs = {
    # modern vim
    neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
    };

    # A modern replacement for ‘ls’
    # useful in bash/zsh prompt, not in nushell.
    eza = {
      enable = true;
      git = true;
      icons = "auto";
      enableZshIntegration = true;
    };

    # terminal file manager
    yazi = {
      enable = true;
      enableZshIntegration = true;
      settings.manager = {
        show_hidden = true;
        sort_dir_first = true;
      };
    };

    bat.enable = true;
    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    # fuzzy finder; use fd so it honours .gitignore and skips .git
    fzf = {
      enable = true;
      enableZshIntegration = true;
      defaultCommand = "fd --type f --hidden --exclude .git";
      fileWidgetCommand = "fd --type f --hidden --exclude .git";
      changeDirWidgetCommand = "fd --type d --hidden --exclude .git";
    };

    # SQLite-backed shell history with fuzzy search, synced across sessions.
    # Replaces zsh's historySubstringSearch (disabled in shell.nix).
    atuin = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        # keep the up-arrow bound to plain history; Ctrl-R opens atuin
        filter_mode_shell_up_key_binding = "session";
        style = "compact";
      };
    };
  };
}
