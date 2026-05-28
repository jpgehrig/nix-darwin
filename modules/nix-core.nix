{lib, ...}: {
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
    # Drop legacy channels; everything lives in the flake
    auto-optimise-store = lib.mkDefault false;
  };

  nixpkgs.config.allowUnfree = true;

  # Weekly GC, delete generations older than 7 days
  nix.gc = {
    automatic = lib.mkDefault true;
    interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 0;
    };
    options = lib.mkDefault "--delete-older-than 7d";
  };

  # Periodic store optimisation (replaces nix.settings.auto-optimise-store)
  nix.optimise.automatic = true;
}
