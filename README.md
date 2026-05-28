# nix-darwin configuration

Personal macOS configuration managed by [nix-darwin](https://github.com/LnL7/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager), targeting **nixpkgs 25.11** (`aarch64-darwin`). Based on [nix-darwin-kickstarter](https://github.com/ryan4yin/nix-darwin-kickstarter/tree/main/minimal).

## Layout

```
.
├── flake.nix              # Inputs, outputs, host definitions
├── flake.lock             # Pinned input revisions (generated)
├── modules/               # System (nix-darwin) modules
│   ├── nix-core.nix       # Nix daemon: flakes, GC, store optimisation
│   ├── system.nix         # macOS defaults (dock, finder, trackpad, fonts, TouchID sudo)
│   ├── apps.nix           # System packages + Homebrew (brews / casks / mas)
│   └── host-users.nix     # Hostname & user account
└── home/                  # Home Manager (user-level) modules
    ├── default.nix        # Entry point, imports the rest
    ├── core.nix           # CLI tools (ripgrep, fzf, eza, bat, yazi, zoxide, …)
    ├── shell.nix          # zsh + direnv + aliases
    ├── git.nix            # git + delta + aliases
    └── starship.nix       # prompt
```

## Setting up a new Mac

1. **Install Xcode Command Line Tools** (needed for git, compilers):
   ```sh
   xcode-select --install
   ```

2. **Install Nix** — upstream Nix via the Determinate Systems installer (flakes enabled, clean uninstall):
   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
     | sh -s -- install --determinate=false
   ```
   Open a new shell so `nix` is on `PATH`.

3. **Install Homebrew** (required for casks / mas / a handful of CLI tools):
   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

4. **Clone this repo**:
   ```sh
   mkdir -p ~/.config && cd ~/.config
   git clone https://github.com/jpgehrig/nix-darwin.git
   cd nix-darwin
   ```

5. **Adjust identity** in `flake.nix` (`username`, `useremail`, `hostname`) if you're not me.

6. **Move aside installer-managed shell files** so nix-darwin can take them over (otherwise activation aborts with "Unexpected files in /etc"):
   ```sh
   sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin 2>/dev/null || true
   sudo mv /etc/zshrc  /etc/zshrc.before-nix-darwin  2>/dev/null || true
   ```

7. **Bootstrap nix-darwin** — activation must run as root since 25.05. On the very first run, flakes aren't enabled in root's nix config yet, so pass them inline:
   ```sh
   sudo -H nix --extra-experimental-features 'nix-command flakes' \
     run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake .#jps-mbp
   ```

   After the first activation, `modules/nix-core.nix` enables `nix-command` and `flakes` daemon-wide, so subsequent rebuilds simplify to:
   ```sh
   sudo darwin-rebuild switch --flake ~/.config/nix-darwin
   ```
   (or just `rebuild` — aliased in `home/shell.nix`).

8. **Sign in to the Mac App Store** before the first rebuild if `masApps` is non-empty (otherwise `mas` install will fail).

## Updating inputs

```sh
nix flake update                 # bump all inputs
nix flake update nixpkgs         # bump a single input
darwin-rebuild switch --flake .  # apply
```

## Rolling back

```sh
darwin-rebuild --list-generations
darwin-rebuild switch --rollback
```

## Useful commands

| Command | What it does |
|---|---|
| `rebuild` | `sudo darwin-rebuild switch --flake ~/.config/nix-darwin` |
| `nix flake check` | Evaluate the flake without building |
| `nix fmt` | Format `.nix` files with alejandra |
| `nix-collect-garbage -d` | Delete old generations now (weekly GC also runs automatically) |

## Notes

- Targets `aarch64-darwin` (Apple Silicon). Change `system` in `flake.nix` for Intel Macs.
- Home Manager is wired in as a `darwin` module (`useGlobalPkgs = true`), so packages share the system `nixpkgs` and config.
- Conflicting files written by Home Manager are backed up with the `.hm-backup` suffix.
- TouchID for `sudo` is enabled via `security.pam.services.sudo_local.touchIdAuth`.
- Homebrew uses `cleanup = "zap"`: any brew / cask / mas app **not** declared in `modules/apps.nix` will be uninstalled on the next `rebuild`. Add it to the lists before installing manually.
- Git config is managed by Home Manager and written to `~/.config/git/config`. Any pre-existing `~/.gitconfig` is removed on activation (see `home/git.nix`).
- Anything under `~/work/` automatically picks up `~/work/.gitconfig` via a conditional include — keep work identity / signing keys there.
