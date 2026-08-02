# Zen Browser is installed as a Homebrew cask (see modules/apps.nix), so its
# profile is not nix-managed and programs.zen-browser is deliberately unused --
# that module would fight the cask's profile layout.
#
# What this module *does* provide is `zen-restore-spaces`, a manual command that
# replays config/zen/spaces.json onto a profile. It is not an activation hook:
# it mutates live app state and requires Zen to be closed.
{pkgs, ...}: let
  # The session store is Mozilla LZ4, which needs python's lz4 bindings.
  pythonEnv = pkgs.python313.withPackages (ps: [ps.lz4]);

  zen-restore-spaces = pkgs.writeShellApplication {
    name = "zen-restore-spaces";
    runtimeInputs = [pythonEnv];
    text = ''
      exec python3 ${./../scripts/zen-restore-spaces.py} \
        --config "''${ZEN_SPACES_CONFIG:-${./../config/zen/spaces.json}}" "$@"
    '';
  };
in {
  home.packages = [zen-restore-spaces];
}
