# Zen Browser is installed as a Homebrew cask (see modules/apps.nix), so its
# profile is not nix-managed and programs.zen-browser is deliberately unused --
# that module would fight the cask's profile layout.
#
# What this module *does* provide is `zen-restore-spaces`, a manual command that
# replays config/zen/spaces.json onto a profile. It is not an activation hook:
# it mutates live app state and requires Zen to be closed.
{pkgs, ...}: let
  # The session store is Mozilla LZ4, so the script needs python's lz4
  # bindings. It declares them itself via PEP 723 inline metadata and `uv run`
  # resolves them at first run, caching under ~/.cache/uv.
  #
  # uv is called by absolute store path on purpose. An earlier version put a
  # python env on PATH and ran bare `python3`, which silently picked up
  # whatever interpreter came first -- Homebrew python, a pyenv shim, an active
  # venv -- and failed with "No module named 'lz4'" on a machine whose PATH
  # differed. Same reason uv comes from nixpkgs rather than the Homebrew uv:
  # that one is not declared anywhere, so it does not exist on a fresh Mac.
  zen-restore-spaces = pkgs.writeShellApplication {
    name = "zen-restore-spaces";
    text = ''
      exec ${pkgs.uv}/bin/uv run --script ${./../scripts/zen-restore-spaces.py} \
        --config "''${ZEN_SPACES_CONFIG:-${./../config/zen/spaces.json}}" "$@"
    '';
  };
in {
  home.packages = [zen-restore-spaces];
}
