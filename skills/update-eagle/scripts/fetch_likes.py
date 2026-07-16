#!/usr/bin/env python3
"""
fetch_likes.py — pull Oli's X (Twitter) Likes via the `bird` CLI and print them
in the exact shape eagle_import.py's `import` subcommand expects.

This is the PRIMARY path for /update-eagle: bird talks to X's internal GraphQL
API with the logged-in session cookies (no browser, no scraping). If bird is
unavailable or breaks (X rotates its GraphQL query IDs), the skill falls back to
the Claude-in-Chrome DOM scrape documented in SKILL.md.

What it does
------------
1. Ensures bird has credentials. bird's macOS cookie auto-detect is unreliable
   (its 3s Keychain timeout loses to a ~4s Keychain read on this machine), so we
   extract `auth_token` + `ct0` from Chrome ourselves and pass them as env vars —
   the method bird's own docs call "recommended for agents". If AUTH_TOKEN and CT0
   are already in the environment, we use those and skip Chrome entirely.
2. Runs `bird likes -n <limit> --json`.
3. Maps bird's tweet objects to the eagle_import shape:
     {statusUrl, statusId, author, text, photos:[{index,mediaId,format}], hasVideo, hasGif}

Output: a JSON array on stdout. Redirect it to a file and hand that to
`eagle_import.py import`, which re-dedups against the live library authoritatively.

Requires: `bird` on PATH, and (for Chrome extraction) the `cryptography` package
plus Keychain access to "Chrome Safe Storage" (granted once, may re-prompt after a
Chrome update). Stdlib otherwise.
"""

import argparse
import json
import os
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile

CHROME_DIR = os.path.expanduser("~/Library/Application Support/Google/Chrome")
CHROME_PROFILES = ["Default", "Profile 1", "Profile 2", "Profile 3"]

_MEDIA_RE = re.compile(r"/media/([A-Za-z0-9_\-]+)")
_TCO_RE = re.compile(r"\s*https?://t\.co/\w+\s*$")


# ---------------------------------------------------------------------------
# Chrome cookie extraction (macOS)
# ---------------------------------------------------------------------------

def _extract_chrome_cookies():
    """
    Return (auth_token, ct0) for x.com decrypted from Chrome's cookie DB, trying
    each profile until one has both cookies. Raises RuntimeError with a clear
    message if crypto libs, Keychain, or the cookies aren't available.
    """
    try:
        from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
        from cryptography.hazmat.primitives import hashes
    except ImportError:
        raise RuntimeError(
            "python 'cryptography' package is required to read Chrome cookies "
            "(pip3 install cryptography), or set AUTH_TOKEN and CT0 env vars yourself."
        )

    try:
        pw = subprocess.check_output(
            ["security", "find-generic-password", "-w", "-a", "Chrome", "-s", "Chrome Safe Storage"],
            timeout=30,
        ).strip()
    except Exception as e:
        raise RuntimeError(f"Could not read Chrome's Keychain password: {e}")

    kdf = PBKDF2HMAC(algorithm=hashes.SHA1(), length=16, salt=b"saltysalt", iterations=1003)
    key = kdf.derive(pw)

    def decrypt(val):
        if not val or val[:3] not in (b"v10", b"v11"):
            return None
        cipher = Cipher(algorithms.AES(key), modes.CBC(b" " * 16))
        dec = cipher.decryptor()
        out = dec.update(val[3:]) + dec.finalize()
        out = out[: -out[-1]]  # strip PKCS7 padding
        try:
            return out.decode("utf-8")
        except UnicodeDecodeError:
            return out[32:].decode("utf-8", "replace")  # newer Chrome prefixes a 32-byte domain hash

    for prof in CHROME_PROFILES:
        db = os.path.join(CHROME_DIR, prof, "Cookies")
        if not os.path.exists(db):
            continue
        tmp = tempfile.mktemp(suffix=".db")
        shutil.copy(db, tmp)  # Chrome holds a lock; work on a copy
        try:
            con = sqlite3.connect(tmp)
            rows = con.execute(
                "SELECT name, encrypted_value FROM cookies "
                "WHERE host_key LIKE '%x.com' AND name IN ('auth_token','ct0')"
            ).fetchall()
            con.close()
        except Exception:
            rows = []
        finally:
            os.remove(tmp)
        got = {}
        for name, ev in rows:
            v = decrypt(ev)
            if v:
                got[name] = v
        if got.get("auth_token") and got.get("ct0"):
            return got["auth_token"], got["ct0"]

    raise RuntimeError(
        "No x.com auth_token/ct0 found in any Chrome profile. Log into x.com in "
        "Chrome, or set AUTH_TOKEN and CT0 env vars manually."
    )


def _bird_env():
    """Env dict for the bird subprocess, with credentials guaranteed present."""
    env = dict(os.environ)
    if env.get("AUTH_TOKEN") and env.get("CT0"):
        return env  # caller already supplied cookies
    auth, ct0 = _extract_chrome_cookies()
    env["AUTH_TOKEN"] = auth
    env["CT0"] = ct0
    return env


# ---------------------------------------------------------------------------
# bird -> eagle_import mapping
# ---------------------------------------------------------------------------

def _photo_from_media(m, index):
    """Map a bird photo-media object to eagle_import's {index,mediaId,format}."""
    url = m.get("url") or ""
    mid = None
    mm = _MEDIA_RE.search(url)
    if mm:
        mid = mm.group(1)
    fmt = "jpg"
    fq = re.search(r"[?&]format=([a-z0-9]+)", url, re.I)
    if fq:
        fmt = fq.group(1).lower()
    else:
        ext = re.search(r"\.([a-z0-9]+)(?:[:?]|$)", url.split("/media/")[-1], re.I)
        if ext:
            fmt = ext.group(1).lower()
    return {"index": index, "mediaId": mid, "format": fmt, "url": url}


def _map_tweet(t):
    author = (t.get("author") or {}).get("username") or "unknown"
    status_id = str(t.get("id") or "")
    text = _TCO_RE.sub("", t.get("text") or "").strip()
    media = t.get("media") or []
    photos, i = [], 0
    has_video = has_gif = False
    for m in media:
        mtype = m.get("type")
        if mtype == "photo":
            i += 1
            photos.append(_photo_from_media(m, i))
        elif mtype == "video":
            has_video = True
        elif mtype == "animated_gif":
            has_gif = True
    return {
        "statusUrl": f"https://x.com/{author}/status/{status_id}",
        "statusId": status_id,
        "author": author,
        "text": text,
        "photos": photos,
        "hasVideo": has_video,
        "hasGif": has_gif,
    }


def _run_bird(limit, env):
    cmd = ["bird", "likes", "-n", str(limit), "--json"]
    try:
        out = subprocess.run(cmd, env=env, capture_output=True, text=True, timeout=120)
    except FileNotFoundError:
        raise RuntimeError("`bird` is not installed. See skills/bird-skill/INSTALL.md.")
    except subprocess.TimeoutExpired:
        raise RuntimeError("bird timed out fetching likes (X may be rate-limiting — try again shortly).")
    if out.returncode != 0:
        raise RuntimeError(f"bird failed (exit {out.returncode}): {(out.stderr or out.stdout).strip()[:400]}")
    try:
        data = json.loads(out.stdout)
    except json.JSONDecodeError:
        raise RuntimeError(f"bird returned non-JSON output: {out.stdout[:300]}")
    return data if isinstance(data, list) else data.get("tweets") or data.get("data") or []


def main(argv):
    ap = argparse.ArgumentParser(description="Fetch X likes via bird in eagle_import shape.")
    ap.add_argument("--limit", type=int, default=50, help="max likes to fetch (default 50)")
    args = ap.parse_args(argv[1:])

    try:
        env = _bird_env()
        tweets = _run_bird(args.limit, env)
    except RuntimeError as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        return 1

    mapped = [_map_tweet(t) for t in tweets if t.get("id")]
    print(json.dumps(mapped))
    print(f"fetched {len(mapped)} likes", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
