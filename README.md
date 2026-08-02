# nix-darwin configuration

Personal macOS configuration managed by [nix-darwin](https://github.com/LnL7/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager), targeting **nixpkgs 25.11** (`aarch64-darwin`). Based on [nix-darwin-kickstarter](https://github.com/ryan4yin/nix-darwin-kickstarter/tree/main/minimal).

## Layout

```
.
├── flake.nix              # Inputs, outputs, host definitions
├── flake.lock             # Pinned input revisions (generated)
├── modules/               # System (nix-darwin) modules
│   ├── nix-core.nix       # nix.enable = false (Determinate) + GC / optimise jobs
│   ├── system.nix         # macOS defaults (dock, finder, trackpad, fonts, TouchID sudo)
│   ├── apps.nix           # System packages + Homebrew (brews / casks / mas)
│   └── host-users.nix     # Hostname & user account
└── home/                  # Home Manager (user-level) modules
    ├── default.nix        # Entry point, imports the rest
    ├── core.nix           # CLI tools (ripgrep, fzf, eza, bat, yazi, zoxide, atuin, …)
    ├── shell.nix          # zsh + direnv + aliases
    ├── git.nix            # git + delta + SSH auth & commit signing (1Password)
    ├── starship.nix       # prompt
    └── vscode.nix         # VSCodium
```

## Setting up a new Mac

1. **Install Xcode Command Line Tools** (needed for git, compilers):
   ```sh
   xcode-select --install
   ```

2. **Install Nix** — Determinate Nix (flakes enabled, clean uninstall):
   ```sh
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
     | sh -s -- install
   ```
   Open a new shell so `nix` is on `PATH`.

3. **Install Homebrew** (required for casks / mas / a handful of CLI tools):
   ```sh
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

4. **Clone this repo** (public, so HTTPS needs no auth at this point):
   ```sh
   mkdir -p ~/.config && cd ~/.config
   git clone https://github.com/jpgehrig/nix-darwin.git
   cd nix-darwin
   ```

   > Clone **before** activating. Afterwards `home/git.nix` rewrites
   > `https://github.com/` → `git@github.com:`, so this same command would
   > require SSH that isn't set up until step 9.

5. **Set the hostname and identity** in `flake.nix` — `username`, `useremail`, `useremailWork`, and `hostname`.

   `hostname` does double duty: it names the flake output you activate in step 7
   (`.#<hostname>`) *and* becomes the machine's ComputerName / LocalHostName /
   NetBIOSName via `modules/host-users.nix`. Set it **before** bootstrapping —
   e.g. `jps-macbook` for a new MacBook:

   ```nix
   hostname = "jps-macbook";
   ```

   The config defines a single host, so a fresh Mac whose name doesn't match
   fails with `flake output attribute 'darwinConfigurations.<name>' does not exist`.
   Editing this value first avoids activating under the wrong name and having to
   rename afterwards.

   If you're using a different SSH key, also update `sshPublicKey` in `home/git.nix` — commits are signed with it and activation will configure signing regardless of whether the key exists yet. Generate one per machine so a lost Mac can be revoked on its own.

6. **Move aside installer-managed shell files** so nix-darwin can take them over (otherwise activation aborts with "Unexpected files in /etc"):
   ```sh
   sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin 2>/dev/null || true
   sudo mv /etc/zshrc  /etc/zshrc.before-nix-darwin  2>/dev/null || true
   ```

   > **This removes `nix` from new shells.** The installer put its PATH hook in
   > `/etc/zshrc`, and you just moved that file. Existing shells keep working;
   > new ones report `nix: command not found` until step 7 finishes and
   > nix-darwin writes its own `/etc/zshrc`. Don't restore the backup — instead
   > source the profile in whichever shell runs step 7:
   > ```sh
   > . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
   > ```

7. **Bootstrap nix-darwin** — activation must run as root since 25.05. On the very first run, flakes aren't enabled in root's nix config yet, so pass them inline. Substitute the `hostname` you set in step 5:
   ```sh
   sudo -H nix --extra-experimental-features 'nix-command flakes' \
     run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake .#<hostname>
   ```

   The explicit `.#<hostname>` is needed only on this first run, while the
   machine still has its factory name. Activation renames it to match, so later
   rebuilds resolve automatically.

   After the first activation, `modules/nix-core.nix` enables `nix-command` and `flakes` daemon-wide, so subsequent rebuilds simplify to:
   ```sh
   sudo darwin-rebuild switch --flake ~/.config/nix-darwin
   ```
   (or just `rebuild` — aliased in `home/shell.nix`).

8. **Sign in to the Mac App Store** before the first rebuild — `masApps` is non-empty (Dropover, NordVPN, WhatsApp, Windows App), and `mas` install fails otherwise.

9. **Set up GitHub SSH auth.** Activation configures SSH auth *and* commit signing through the 1Password agent, but none of it works until you do these three things. **Until then `git commit` fails** with `Couldn't find key in agent?` — see [GitHub authentication](#github-authentication) for why, and for the escape hatch if you need git working before finishing this.

   a. **Enable the agent**: 1Password app → Settings → Developer → Set Up SSH Agent. This creates the socket `~/.ssh/config` already points at.

   b. **Register the key on GitHub, in both roles.** GitHub tracks authentication and signing keys separately; the same key must be added twice. Needs `gh` and `op` (both installed by step 7) with 1Password unlocked and `gh auth login` done. The token also needs scopes it won't have by default:
   ```sh
   gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key
   KEY="$(op item get "GitHub JP's MBP" --fields 'public key')"
   gh ssh-key add --type authentication --title "1Password - $(hostname -s)" <(echo "$KEY")
   gh ssh-key add --type signing        --title "1Password - $(hostname -s)" <(echo "$KEY")
   ```

   > One key per machine. On a new Mac, generate its own rather than reusing
   > this one, so a lost machine can be revoked on its own:
   > ```sh
   > op item create --category "SSH Key" --title "GitHub <host>" \
   >   --vault Personal --ssh-generate-key ed25519
   > ```
   > Then put its public half in `sshPublicKey` (`home/git.nix`) and rebuild.

   c. **Trust GitHub's host key** — a fresh Mac has no `~/.ssh/known_hosts`, and SSH fails closed with `Host key verification failed`:
   ```sh
   mkdir -p ~/.ssh && ssh-keyscan github.com >> ~/.ssh/known_hosts
   ```

   Verify:
   ```sh
   ssh -T git@github.com          # "Hi jpgehrig! You've successfully authenticated"
   git -C ~/.config/nix-darwin log --show-signature -1
   ```

10. **Set your terminal font** to *JetBrainsMono Nerd Font* (installed by the `font-jetbrains-mono-nerd-font` cask). Without it, `eza --icons` and any Nerd Font glyphs in the Starship prompt render as tofu.

11. **Open a new shell** to pick up zsh, Starship, atuin and direnv.

## Troubleshooting

**`nix: command not found` in new terminals, but sourcing the profile works.**
Step 6 moved `/etc/zshrc`, which held the installer's PATH hook, and nix-darwin
has not written its replacement yet. Don't restore the backup — source the
profile and finish the bootstrap:

```sh
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
sudo -H nix --extra-experimental-features 'nix-command flakes' \
  run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake .#<hostname>
```

New shells work permanently once activation succeeds. If `/nix` itself is
missing, the install never completed — re-run step 2.

**`flake output attribute 'darwinConfigurations.<name>' does not exist`.**
The machine's hostname doesn't match the single host in `flake.nix`. Either fix
`hostname` there (step 5) or pass the right one explicitly with `--flake .#<hostname>`.

**`error: unexpected value 'false' for '--determinate'`.** The installer flag is
valueless as of v3.21.9; drop `=false` — see step 2.

**`error: Determinate detected, aborting activation`.** `nix.enable = false` is
missing from `modules/nix-core.nix`. nix-darwin and `determinate-nixd` both want
to own `/etc/nix/nix.conf` and the daemon, so nix-darwin refuses unless told to
stand back. This repo already sets it — pull the latest config.

## GitHub authentication

Git talks to GitHub over SSH, with the key held in 1Password:

- The private key never lands on disk. `programs.ssh` points `IdentityAgent` at
  the 1Password agent socket, so every use prompts for Touch ID.
- The same key signs commits and tags (`gpg.format = ssh`). `allowed_signers`
  covers both the personal and work identities, so `git log --show-signature`
  verifies locally; GitHub verifies against the key registered on your account.
- `url."git@github.com:".insteadOf = "https://github.com/"` means HTTPS remotes
  are transparently upgraded — no need to edit remotes on existing clones.

**If git breaks before the agent is up** (fresh machine, 1Password locked, key
not yet registered), bypass the rewrite with an empty global config:

```sh
GIT_CONFIG_GLOBAL=/dev/null git push https://github.com/jpgehrig/nix-darwin.git <branch>
```

`git -c url."git@github.com:".insteadOf= …` does **not** work: git merges
`insteadOf` values rather than replacing them, so the rewrite still applies.

To commit without signing while the agent is unavailable:

```sh
git -c commit.gpgsign=false commit -m "…"
```

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
- Nix itself is managed by **Determinate** (`determinate-nixd`), so `modules/nix-core.nix` sets `nix.enable = false` and the `nix.*` options are unavailable. Daemon settings live in `/etc/nix/nix.custom.conf`; weekly GC (Sun 03:00) and store optimisation (Sun 04:00) are installed as plain `launchd.daemons` instead, logging to `/var/log/nix-gc.log` and `/var/log/nix-optimise.log`.
- Home Manager is wired in as a `darwin` module (`useGlobalPkgs = true`), so packages share the system `nixpkgs` and config.
- Conflicting files written by Home Manager are backed up with the `.hm-backup` suffix.
- TouchID for `sudo` is enabled via `security.pam.services.sudo_local.touchIdAuth`.
- Homebrew uses `cleanup = "none"`: removing a brew / cask from `modules/apps.nix` stops managing it but does **not** uninstall it. Run `brew uninstall <name>` to actually remove it.
- Git config is managed by Home Manager and written to `~/.config/git/config`. Any pre-existing `~/.gitconfig` is removed on activation (see `home/git.nix`).
- Anything under `~/work/` commits with the work identity (`useremailWork` in `flake.nix`) via a conditional include generated into the Nix store.

## Nix or Homebrew?

Default to **Homebrew for fast-moving standalone binaries**. `nixpkgs` follows the
`25.11` release branch, so new upstream versions only land at the next release —
tools that ship often (`gh`, `node`, `pnpm`, `awscli`, `opentofu`, `pdm`) can sit
months behind. Each is annotated with its version gap in `modules/apps.nix`.

The exception: **anything with a Home Manager module stays in Nix**, even when
slightly behind. `fzf`, `atuin`, `zoxide`, `eza`, `bat`, `delta`, `yazi`,
`neovim` and `git` have HM modules that generate their config files *and* wire
up shell integration. Homebrew would give you the binary and leave you
hand-writing both. A minor version lag is worth less than declarative config.

Everything else — stable CLI utilities at or near parity (`ripgrep`, `fd`, `jq`,
`btop`, `dust`, `hyperfine`, …) — stays in Nix, where it is reproducible and
rolls back with the generation.

Re-check the gaps after `nix flake update` or a nixpkgs release bump:

```bash
nix eval --raw .#darwinConfigurations.<hostname>.pkgs.<pkg>.version
brew info --json=v2 --formula <pkg> | jq -r '.formulae[0].versions.stable'
```
