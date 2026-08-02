{...}: {
  # Nix itself is managed by Determinate (determinate-nixd), not nix-darwin.
  # Without this, activation aborts with "Determinate detected".
  #
  # Flakes need no opt-in here: Determinate enables nix-command and flakes
  # by default. On an upstream-Nix host, ~/.config/nix/nix.conf covers it.
  nix.enable = false;

  nixpkgs.config.allowUnfree = true;

  # `nix.enable = false` also disables `nix.gc` and `nix.optimise`, which used
  # to install these as launchd jobs. Recreate them directly so the store still
  # gets collected and deduplicated. Works the same on Determinate and upstream.
  launchd.daemons = {
    nix-gc = {
      command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 7d";
      serviceConfig = {
        RunAtLoad = false;
        StartCalendarInterval = [
          {
            Weekday = 0;
            Hour = 3;
            Minute = 0;
          }
        ];
        StandardOutPath = "/var/log/nix-gc.log";
        StandardErrorPath = "/var/log/nix-gc.log";
      };
    };

    nix-optimise = {
      command = "/nix/var/nix/profiles/default/bin/nix-store --optimise";
      serviceConfig = {
        RunAtLoad = false;
        StartCalendarInterval = [
          {
            Weekday = 0;
            Hour = 4;
            Minute = 0;
          }
        ];
        StandardOutPath = "/var/log/nix-optimise.log";
        StandardErrorPath = "/var/log/nix-optimise.log";
      };
    };
  };
}
