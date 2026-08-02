{...}: {
  programs.starship = {
    enable = true;

    enableBashIntegration = true;
    enableZshIntegration = true;

    settings = {
      # Do not stall the prompt on slow git status in large repos.
      command_timeout = 1000;

      character = {
        success_symbol = "[›](bold green)";
        error_symbol = "[›](bold red)";
      };
      aws = {
        symbol = "🅰 ";
      };
      gcloud = {
        # do not show the account/project's info
        # to avoid the leak of sensitive information when sharing the terminal
        format = "on [$symbol$active(\($region\))]($style) ";
        symbol = "🅶 ️";
      };

      # Show which cluster is targeted — `k` is aliased to kubectl, and acting
      # on the wrong cluster is the expensive mistake. Context only: the
      # namespace is omitted to limit what a shared screen reveals.
      kubernetes = {
        disabled = false;
        format = "on [⎈ $context]($style) ";
        style = "bold purple";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_status = {
        ahead = "⇡$count";
        behind = "⇣$count";
        diverged = "⇕⇡$ahead_count⇣$behind_count";
        conflicted = "=$count";
        untracked = "?$count";
        modified = "!$count";
        staged = "+$count";
        stashed = "$$count";
      };
    };
  };
}
