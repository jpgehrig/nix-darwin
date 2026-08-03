# nix-darwin configuration

Personal macOS configuration managed by [nix-darwin](https://github.com/LnL7/nix-darwin) and [home-manager](https://github.com/nix-community/home-manager), targeting **nixpkgs 25.11** (`aarch64-darwin`). Based on [nix-darwin-kickstarter](https://github.com/ryan4yin/nix-darwin-kickstarter/tree/main/minimal).

## Layout

```
.
├── flake.nix              # Inputs + one mkHost entry per machine
├── flake.lock             # Pinned input revisions (generated)
├── modules/               # System (nix-darwin) modules
│   ├── nix-core.nix       # nix.enable = false (Determinate) + GC / optimise jobs
│   ├── system.nix         # macOS defaults (dock, finder, trackpad, fonts, TouchID sudo)
│   ├── apps.nix           # System packages + Homebrew (brews / casks / mas)
│   └── host-users.nix     # Hostname & user account
├── home/                  # Home Manager (user-level) modules
│   ├── default.nix        # Entry point, imports the rest
│   ├── core.nix           # CLI tools (ripgrep, fzf, eza, bat, yazi, zoxide, atuin, …)
│   ├── shell.nix          # zsh + direnv + aliases
│   ├── git.nix            # git + delta + SSH auth & commit signing (1Password)
│   ├── starship.nix       # prompt
│   └── zen.nix            # zen-backup-spaces / zen-restore-spaces wrappers
├── config/
│   └── zen/spaces.json    # Zen Spaces, containers & pinned tabs (source of truth)
└── scripts/
    └── zen-restore-spaces.py  # Captures (--capture) and replays spaces.json
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

5. **Add your host** to `darwinConfigurations` in `flake.nix`, and adjust
   `username` / `useremail` / `useremailWork` if you're not me.

   Each host name does double duty: it names the flake output you activate in
   step 7 (`.#<hostname>`) *and* becomes the machine's ComputerName /
   LocalHostName / NetBIOSName via `modules/host-users.nix`. A Mac whose name
   matches no entry fails with
   `flake output attribute 'darwinConfigurations.<name>' does not exist`.

   ```nix
   darwinConfigurations = {
     jps-macbook = mkHost "jps-macbook";
     jps-old-macbook = mkHost "jps-old-macbook";
   };
   ```

   Because the output name and the machine name agree, `darwin-rebuild` with no
   explicit `.#target` resolves to whichever host it runs on — so `rebuild` works
   unqualified on every machine.

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

12. **Restore Zen Spaces.** Launch Zen once so it creates a profile, quit it
    completely, then run `zen-restore-spaces --dry-run` and, if the diff looks
    right, `zen-restore-spaces`. See [Zen Browser Spaces](#zen-browser-spaces).

## Zen Browser Spaces

Zen is installed as a **Homebrew cask**, so its profile is not nix-managed. The
`programs.zen-browser` Home Manager module is deliberately unused — it would
fight the cask's profile layout.

Instead, `config/zen/spaces.json` holds the Spaces, containers and pinned tabs as
a hand-editable, diffable file, and `zen-restore-spaces` replays it onto a
profile. Edit that file directly; it is the source of truth.

### Restoring onto a new Mac

```sh
# 1. Launch Zen once so it creates a profile, then QUIT IT COMPLETELY
# 2. Preview — writes nothing
zen-restore-spaces --dry-run
# 3. Apply
zen-restore-spaces
```

The command refuses to run while Zen is open (`pgrep -x zen`): Zen holds the
session store in memory and would overwrite it on exit, silently discarding the
restore.

The script runs under `uv` (the brew from `modules/apps.nix`, resolved from PATH)
and declares its own `lz4` dependency inline (PEP 723). The first run fetches
that wheel and caches it in `~/.cache/uv`, so it needs network access once;
afterwards it is offline. On a fresh Mac this means `brew bundle` must have run —
if uv is missing the command says so and exits non-zero.

### Capturing changes back

After changing Spaces, containers or pins in Zen, pull them back into the repo:

```sh
cd ~/.config/nix-darwin
zen-backup-spaces --dry-run   # show what changed
zen-backup-spaces             # rewrite config/zen/spaces.json
git diff config/zen/spaces.json
```

This only reads the profile, so it needs no backup — git is the undo. It does
not require Zen to be closed either, but it warns if Zen is running, since
changes made in that session may not have been flushed to disk yet.

Run it from the repo root: it writes to `./config/zen/spaces.json` by default,
and refuses (non-zero, with a message) if pointed at the read-only store copy.

### Removing Spaces the config doesn't describe

Restore is **additive** by default: a Space the profile has but `spaces.json`
doesn't mention is left alone, because it may hold tabs this tool doesn't
manage. To end up with exactly the Spaces in the config:

```sh
zen-restore-spaces --prune --dry-run   # lists each Space that would go, with tab counts
zen-restore-spaces --prune
```

`--replace` is an alias for `--prune`.

Deleting a Space also deletes its tabs — leaving them would orphan them against
a Space uuid that no longer exists. Only *pinned* tabs are captured in
`spaces.json`, so unpinned ones cannot be restored. If a pruned Space holds any,
the command refuses:

```
error: --prune would delete 3 unpinned tab(s) in 1 Space(s).
```

Pass `--force` to discard them anyway. Pruning a Space does **not** delete its
container or its cookies; those live outside the session store.

### What is and isn't managed

Managed: Space names, icons and gradient themes; the five custom containers
(created if missing); pinned tabs and Essentials per Space.

Not managed, by design:

- **Open tabs and history.** Tab entries, scroll offsets, form data and
  `*_base64` security principals are session state and stay out of the repo.
- **Favicons.** Cache, not config — Zen refetches them per site. A pin may show
  a globe until you visit it once.
- **Firefox's built-in containers** (`personal` / `work` / `banking` /
  `shopping`). Nothing binds to them, but Zen recreates them on any fresh
  profile, so they still appear in the container list.
- **Bookmarks.** Not captured (the profile had none beyond Mozilla's defaults).

### Editing

Container bindings are by **name**, not by `userContextId` — those integers are
profile-local, and binding by integer would silently attach a Space to the wrong
container on a fresh profile. Missing containers are created automatically,
allocating ids from `lastUserContextId`.

Container `icon` must be one of: `briefcase cart chill circle dollar fence
fingerprint food fruit gift pet tree vacation`. Colors: `blue turquoise green
yellow orange red pink purple`.

After editing, **rebuild** — the wrapper reads `spaces.json` from the Nix store.
To iterate without rebuilding, point it at the working copy:

```sh
zen-restore-spaces --config ./config/zen/spaces.json --dry-run
```

Both `containers.json` and `zen-sessions.jsonlz4` are backed up to timestamped
files before any write, and both are rolled back together if anything fails.

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

**`Error: Refusing to load cask <tap>/<cask> from untrusted tap <tap>`.** The
cask's tap isn't declared in `homebrew.taps`. Referencing it inline as
`"owner/tap/cask"` is not enough — newer Homebrew requires the tap itself to be
listed so it is tapped first. Add it to `taps` in `modules/apps.nix`.

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
| `zen-backup-spaces` | Capture live Zen Spaces back into `config/zen/spaces.json` |
| `zen-restore-spaces --dry-run` | Preview restoring Zen Spaces from `config/zen/spaces.json` (Zen must be closed) |

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
