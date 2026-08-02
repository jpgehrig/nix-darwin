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
  # uv comes from PATH -- the `uv` brew in modules/apps.nix. That makes this
  # wrapper depend on `brew bundle` having run, so fail with an explicit
  # message rather than a bare "uv: command not found".
  #
  # Do not go back to running a bare `python3` here: an earlier version put a
  # python env on PATH and did exactly that, which silently picked up whatever
  # interpreter came first -- Homebrew python, a pyenv shim, an active venv --
  # and failed with "No module named 'lz4'" on a machine whose PATH differed.
  zen-restore-spaces = pkgs.writeShellApplication {
    name = "zen-restore-spaces";
    text = ''
      if ! command -v uv >/dev/null; then
        echo "error: uv not found on PATH." >&2
        echo "       It is declared as a brew in modules/apps.nix -- run" >&2
        echo "       'darwin-rebuild switch' (or 'brew install uv') first." >&2
        exit 1
      fi
      exec uv run --script ${./../scripts/zen-restore-spaces.py} \
        --config "''${ZEN_SPACES_CONFIG:-${./../config/zen/spaces.json}}" "$@"
    '';
  };
in {
  home.packages = [zen-restore-spaces];
}
