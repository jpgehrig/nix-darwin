#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lz4"]
# ///
"""Restore Zen Spaces, containers and pinned tabs from config/zen/spaces.json.

Zen is installed via Homebrew cask, so its profile is not managed by nix. This
script is a *manual* command: it mutates live app state and requires Zen to be
closed. It is deliberately not wired into home.activation.

The session file is Mozilla LZ4: 8-byte b"mozLz40\\0" magic, 4-byte LE
uncompressed size, then a raw LZ4 block. `lz4 -d` cannot read it.
"""

from __future__ import annotations

import argparse
import difflib
import json
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import lz4.block

MAGIC = b"mozLz40\0"
PROFILES = Path.home() / "Library/Application Support/zen/Profiles"


class Failed(Exception):
    """Anything that should abort the restore and roll back."""


# --------------------------------------------------------------------------
# profile discovery / codec


def find_profile(explicit: str | None = None) -> Path:
    if explicit:
        p = Path(explicit).expanduser()
        if not (p / "zen-sessions.jsonlz4").exists():
            raise Failed(f"no zen-sessions.jsonlz4 under {p}")
        return p
    if not PROFILES.is_dir():
        raise Failed(f"no Zen profile directory at {PROFILES}")
    # Random prefix on the directory name, so resolve dynamically. Several
    # profiles can exist; the live one is the one whose places.sqlite was
    # touched most recently.
    cands = [d for d in PROFILES.iterdir() if (d / "zen-sessions.jsonlz4").exists()]
    if not cands:
        raise Failed(f"no profile with a session file under {PROFILES}")
    if len(cands) > 1:
        cands.sort(
            key=lambda d: (d / "places.sqlite").stat().st_mtime
            if (d / "places.sqlite").exists()
            else 0,
            reverse=True,
        )
    return cands[0]


def decode(path: Path) -> dict:
    raw = path.read_bytes()
    if raw[:8] != MAGIC:
        raise Failed(f"{path.name}: bad magic {raw[:8]!r}, expected {MAGIC!r}")
    size = struct.unpack("<I", raw[8:12])[0]
    try:
        body = lz4.block.decompress(raw[12:], uncompressed_size=size)
    except Exception as exc:  # noqa: BLE001 - surface the codec error verbatim
        raise Failed(f"{path.name}: LZ4 decompress failed: {exc}") from exc
    return json.loads(body)


def encode(obj: dict) -> bytes:
    body = json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode()
    return MAGIC + struct.pack("<I", len(body)) + lz4.block.compress(
        body, mode="default", store_size=False
    )


def zen_running() -> bool:
    # Escape hatch for testing against a throwaway copy of a profile while the
    # real Zen is open. Never set this when pointing at a live profile.
    if os.environ.get("ZEN_RESTORE_SKIP_PGREP") == "1":
        return False
    return subprocess.run(["pgrep", "-x", "zen"], capture_output=True).returncode == 0


# --------------------------------------------------------------------------
# merge


def container_map(profile: Path) -> dict[str, int]:
    """Map portable container key -> this profile's numeric userContextId.

    Bindings are stored by l10nId (built-ins) or name (custom) because the
    numeric ids are profile-local: a fresh profile can renumber them, and
    binding by integer would silently attach a Space to the wrong container.
    """
    cf = profile / "containers.json"
    if not cf.exists():
        raise Failed(f"missing {cf}")
    out = {}
    for ident in json.loads(cf.read_text()).get("identities", []):
        if not ident.get("public"):
            continue
        key = ident.get("l10nId") or ident.get("name")
        if key:
            out[key] = ident["userContextId"]
    return out


def plan_containers(profile: Path, cfg: dict) -> tuple[dict, list[dict]]:
    """Work out which custom containers are missing and allocate ids for them.

    Returns the new containers.json content and the list of identities that
    would be added. Only custom containers are declared in spaces.json --
    Firefox recreates its own built-ins (user-context-personal/work/banking/
    shopping) on any fresh profile, so they neither need nor benefit from being
    managed here. They will still show up in Zen's container list.

    New ids come from lastUserContextId, which is the profile's allocator: it
    must be bumped in lockstep or Zen later hands out a colliding id and two
    containers end up sharing a cookie jar.
    """
    cf = profile / "containers.json"
    data = json.loads(cf.read_text())
    existing = container_map(profile)
    next_id = data.get("lastUserContextId", 0)

    added = []
    for want in cfg.get("containers", []):
        key = want["key"]
        if key in existing:
            continue  # idempotent: bind to the existing one, don't duplicate
        next_id += 1
        ident = {
            "userContextId": next_id,
            "public": True,
            "icon": want["icon"],
            "color": want["color"],
            "name": key,
            "accessKey": "",
        }
        data["identities"].append(ident)
        added.append(ident)

    data["lastUserContextId"] = next_id
    return data, added


def merge(session: dict, cfg: dict, cmap: dict[str, int]) -> dict:
    """Apply spaces.json onto a decoded session, returning a new session."""
    out = json.loads(json.dumps(session))  # deep copy
    by_uuid = {s["uuid"]: s for s in out.get("spaces", [])}
    # uuids are minted per profile, so a fresh Mac's Spaces never carry the
    # captured ones. Matching on uuid alone left Zen's own default Space
    # orphaned next to five newly-created ones, with pins bound to Spaces the
    # sidebar showed under different names. Match by name first and adopt the
    # existing uuid; fall back to uuid so a rename in spaces.json still lands
    # on the right Space.
    by_name = {s.get("name"): s for s in out.get("spaces", []) if s.get("name")}
    # A Space this run has already claimed cannot be reused by another.
    claimed: set[int] = set()
    uuid_remap: dict[str, str] = {}

    # Spaces the profile already has that carry no pinned tabs. A fresh profile
    # ships exactly one of these ("Space"), and it is neither uuid- nor
    # name-matchable once spaces.json renames it -- so without this it would be
    # left orphaned beside the restored Spaces. Only empty Spaces are eligible:
    # adopting one that holds pins would silently swallow the user's tabs.
    pinned_spaces = {
        t.get("zenWorkspace")
        for t in out.get("tabs", [])
        if t.get("pinned") or t.get("zenEssential")
    }
    spare = [s for s in out.get("spaces", []) if s.get("uuid") not in pinned_spaces]

    for want in cfg.get("spaces", []):
        space = by_name.get(want["name"]) or by_uuid.get(want["uuid"])
        if space is not None and id(space) in claimed:
            space = None
        if space is None:
            # Adopt an unused Space before minting a new one.
            space = next((s for s in spare if id(s) not in claimed), None)
        if space is None:
            space = {"uuid": want["uuid"]}
            out.setdefault("spaces", []).append(space)
            by_uuid[want["uuid"]] = space
        claimed.add(id(space))
        # Pins reference the *profile's* uuid, not the captured one.
        uuid_remap[want["uuid"]] = space["uuid"]
        space["name"] = want["name"]
        space["icon"] = want["icon"]
        space["theme"] = want["theme"]

        key = want.get("container")
        if key is None:
            space["containerTabId"] = 0  # 0 == unbound, not container id 0
        elif key in cmap:
            space["containerTabId"] = cmap[key]
        else:
            raise Failed(
                f"space {want['name']!r} wants container {key!r}, which does not "
                f"exist in this profile (have: {sorted(cmap) or 'none'})"
            )

    # Rebuild pinned/essential tabs from config; keep non-pinned tabs untouched.
    wanted_uuids = set(uuid_remap.values())
    kept = [
        t
        for t in out.get("tabs", [])
        if not (
            (t.get("pinned") or t.get("zenEssential"))
            and t.get("zenWorkspace") in wanted_uuids
        )
    ]
    for want in cfg.get("spaces", []):
        for i, pin in enumerate(want.get("pins", [])):
            kept.append(
                {
                    "entries": [{"url": pin["url"], "title": pin.get("label")}],
                    "index": 1,
                    "pinned": True,
                    "hidden": False,
                    "zenEssential": bool(pin.get("essential")),
                    "zenWorkspace": uuid_remap[want["uuid"]],
                    "zenPinnedIcon": pin.get("icon"),
                    "zenHasStaticIcon": pin.get("icon") is not None,
                    "zenStaticLabel": pin.get("label"),
                    "_zenPinnedInitialState": {
                        "entry": {"url": pin["url"], "title": pin.get("label")}
                    },
                }
            )
    out["tabs"] = kept
    return out


def managed_view(session: dict, cmap: dict[str, int]) -> dict:
    """Project a session down to just the fields spaces.json manages.

    Diffing whole sessions is meaningless: the session store is mostly tab
    history, scroll offsets and form state that this tool deliberately does not
    manage. The scoped view is what "faithful capture" can actually mean here.
    """
    inv = {v: k for k, v in cmap.items()}
    pins: dict[str, list] = {}
    for t in session.get("tabs", []):
        if not (t.get("pinned") or t.get("zenEssential")):
            continue
        ent = (t.get("entries") or [{}])[-1]
        init = (t.get("_zenPinnedInitialState") or {}).get("entry") or {}
        url = init.get("url") or ent.get("url")
        if not url:
            continue
        pins.setdefault(t.get("zenWorkspace"), []).append(
            {
                "essential": bool(t.get("zenEssential")),
                "icon": t.get("zenPinnedIcon"),
                "label": t.get("zenStaticLabel") or init.get("title") or ent.get("title"),
                "url": url,
            }
        )
    spaces = []
    for s in session.get("spaces", []):
        p = sorted(pins.get(s["uuid"], []), key=lambda x: (not x["essential"], x["url"]))
        spaces.append(
            {
                "container": inv.get(s.get("containerTabId"))
                if s.get("containerTabId")
                else None,
                "icon": s.get("icon"),
                "name": s.get("name"),
                "pins": p,
                "theme": s.get("theme"),
                # uuid is deliberately absent: it is minted per profile, so
                # including it would show every fresh-profile restore as a diff
                # even when every managed field already matches.
            }
        )
    spaces.sort(key=lambda s: s["name"])
    return {"spaces": spaces}


def render(obj) -> list[str]:
    return json.dumps(obj, indent=2, ensure_ascii=False).splitlines()


# --------------------------------------------------------------------------


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", default=None, help="path to spaces.json")
    ap.add_argument("--profile", default=None, help="override profile directory")
    ap.add_argument(
        "--dry-run",
        action="store_true",
        help="print a diff of what would change; write nothing",
    )
    args = ap.parse_args()

    cfg_path = (
        Path(args.config)
        if args.config
        else Path(__file__).resolve().parent.parent / "config/zen/spaces.json"
    )
    if not cfg_path.exists():
        print(f"error: no config at {cfg_path}", file=sys.stderr)
        return 1

    try:
        profile = find_profile(args.profile)
    except Failed as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    # Refuse to touch live state while the app owns it. Checked even for
    # --dry-run so the diff reflects a quiescent file.
    if zen_running():
        print(
            "error: Zen is running. Quit Zen completely and re-run.\n"
            "       (this rewrites the session store; Zen would overwrite it on exit)",
            file=sys.stderr,
        )
        return 1

    cfg = json.loads(cfg_path.read_text())
    sess_path = profile / "zen-sessions.jsonlz4"

    try:
        session = decode(sess_path)
        # Custom containers must exist before the merge can resolve bindings to
        # numeric ids, so plan them first and fold them into the map.
        cdata, added = plan_containers(profile, cfg)
        cmap = container_map(profile)
        cmap.update({i["name"]: i["userContextId"] for i in added})
        merged = merge(session, cfg, cmap)
    except Failed as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    before, after = managed_view(session, cmap), managed_view(merged, cmap)
    diff = list(
        difflib.unified_diff(
            render(before), render(after), "current", "after-restore", lineterm=""
        )
    )

    print(f"profile: {profile}")
    print(f"config:  {cfg_path}")
    for ident in added:
        print(
            f"+ container {ident['name']!r} "
            f"(id {ident['userContextId']}, {ident['color']}/{ident['icon']})"
        )
    if not diff and not added:
        print("no changes: profile already matches spaces.json")
        if args.dry_run:
            return 0
    else:
        for line in diff:
            print(line)

    if args.dry_run:
        print(f"\n--dry-run: nothing written ({len(diff)} diff lines)")
        return 0

    # Back up before touching anything; restore on any failure. Both files are
    # backed up because creating containers and rebinding Spaces to them is one
    # logical change: a half-applied restore would leave Spaces pointing at
    # container ids that do not exist.
    stamp = time.strftime("%Y%m%d-%H%M%S")
    cont_path = profile / "containers.json"
    backups = {}
    for target in (sess_path, cont_path):
        bak = target.with_name(f"{target.name}.bak-{stamp}")
        shutil.copy2(target, bak)
        backups[target] = bak
        print(f"\nbackup: {bak}")

    written = []
    tmp = None
    try:
        blob = encode(merged)
        if decode_bytes(blob) != merged:
            raise Failed("re-decode of encoded session did not round-trip")
        for target, payload in (
            (cont_path, json.dumps(cdata, indent=2).encode()),
            (sess_path, blob),
        ):
            # Atomic swap: write beside the target, fsync, then rename.
            fd, tmp = tempfile.mkstemp(dir=str(profile), prefix=".zen-restore-")
            with os.fdopen(fd, "wb") as fh:
                fh.write(payload)
                fh.flush()
                os.fsync(fh.fileno())
            os.replace(tmp, target)
            tmp = None
            written.append(target)
            print(f"wrote {target} ({len(payload)} bytes)")
    except Exception as exc:  # noqa: BLE001 - roll back on *any* failure
        if tmp and os.path.exists(tmp):
            os.unlink(tmp)
        for target, bak in backups.items():
            shutil.copy2(bak, target)
        print(f"error: {exc}\nrolled back {len(backups)} file(s)", file=sys.stderr)
        return 1

    print("done. Start Zen to pick up the restored Spaces.")
    return 0


def decode_bytes(blob: bytes) -> dict:
    size = struct.unpack("<I", blob[8:12])[0]
    return json.loads(lz4.block.decompress(blob[12:], uncompressed_size=size))


if __name__ == "__main__":
    sys.exit(main())
