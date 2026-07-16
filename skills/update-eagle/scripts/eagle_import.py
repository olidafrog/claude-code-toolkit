#!/usr/bin/env python3
"""
eagle_import.py — Eagle-side logic for the /update-eagle skill.

The skill scrapes X (Twitter) Likes with Claude-in-Chrome, then hands the
collected tweets to this script, which does the deterministic Eagle work:
dedup against the whole library (by source URL, resolution-agnostic) and import
new media via the local Eagle API.

Subcommands
-----------
  check
      Verify Eagle is running. Prints version + the self-discovered API token.
      Exit 0 if reachable, 1 if not.

  existing-ids
      Page through the ENTIRE library and print JSON:
        {"count": N, "ids": ["photo:123:1", "media:GXXXX", "status:456", ...]}
      These are resolution-agnostic identifiers for every asset whose source is
      a twitter/x link. The skill uses this set to decide when it has "caught up"
      to previously-imported likes while scrolling.

  import <tweets.json>
      Import new liked tweets. Re-dedups against the live library (authoritative).
        - photos  -> POST /api/item/addFromURL at full resolution (name=orig)
        - video/gif -> yt-dlp downloads the real file, then POST /api/item/addFromPath
      Prints a JSON summary: imported / skipped_existing / failed.

Stdlib only. yt-dlp is invoked as a subprocess for video/GIF.

tweets.json shape (produced by the skill from the page scrape):
  [
    {
      "statusUrl": "https://x.com/<author>/status/<id>",
      "statusId":  "<id>",
      "author":    "<handle without @>",
      "text":      "<full tweet text>",
      "photos":    [ {"index": 1, "mediaId": "<ID>", "format": "jpg"} ],
      "hasVideo":  false,
      "hasGif":    false
    }
  ]
"""

import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "http://localhost:41595"
PAGE_LIMIT = 500          # items per item/list page
MAX_PAGES = 400           # safety backstop for existing-ids paging (~200k items)
NAME_MAX = 60             # chars of tweet text used in the Eagle item name

# Eagle's addFromPath is ASYNCHRONOUS — it returns "success" immediately and copies
# the file into its library a moment later. So downloaded videos must OUTLIVE the
# import call; we keep them in a persistent cache and sweep old ones next run rather
# than deleting them straight away (a self-deleting temp dir loses the race).
CACHE_DIR = os.path.expanduser("~/.claude/skills/update-eagle/.cache")
CACHE_TTL = 2 * 60 * 60   # seconds; sweep cached downloads older than this

# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

_TOKEN = None  # cached across calls within one process


def _request(method, path, params=None, body=None, timeout=30):
    """Call the Eagle API. Returns parsed JSON dict. Raises on transport error."""
    params = dict(params or {})
    token = get_token()
    if token:
        params["token"] = token
    qs = "&".join(f"{k}={urllib.parse.quote(str(v))}" for k, v in params.items())
    url = f"{BASE}{path}" + (f"?{qs}" if qs else "")
    data = json.dumps(body).encode() if body is not None else None
    headers = {"Content-Type": "application/json"} if data else {}
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode())


def get_token():
    """Self-discover the install's API token from application/info (cached)."""
    global _TOKEN
    if _TOKEN is not None:
        return _TOKEN
    try:
        url = f"{BASE}/api/application/info"
        with urllib.request.urlopen(url, timeout=8) as resp:
            info = json.loads(resp.read().decode())
        _TOKEN = (
            info.get("data", {})
            .get("preferences", {})
            .get("developer", {})
            .get("apiToken", "")
        ) or ""
    except Exception:
        _TOKEN = ""
    return _TOKEN


# ---------------------------------------------------------------------------
# Source-URL dedup identity (resolution-agnostic)
# ---------------------------------------------------------------------------

_TWIMG_RE = re.compile(r"pbs\.twimg\.com/media/([A-Za-z0-9_\-]+)")
_STATUS_RE = re.compile(r"(?:twitter\.com|x\.com)/[^/]+/status/(\d+)(?:/photo/(\d+))?", re.I)


def media_keys(url):
    """
    Return the set of resolution-agnostic dedup keys a source URL implies.
    A twitter photo page yields photo:<status>:<n>; a raw twimg URL yields
    media:<id>; a bare status yields status:<id>. Non-twitter URLs yield set().
    """
    keys = set()
    if not url:
        return keys
    url = urllib.parse.unquote(url)  # some old saves wrap the real URL, percent-encoded
    m = _TWIMG_RE.search(url)
    if m:
        keys.add(f"media:{m.group(1)}")
    m = _STATUS_RE.search(url)
    if m:
        sid, photo = m.group(1), m.group(2)
        keys.add(f"photo:{sid}:{photo}" if photo else f"status:{sid}")
    return keys


def build_photo_url(photo):
    """
    Build a full-resolution pbs.twimg.com URL for a scraped photo. The scraper
    returns only safe tokens (mediaId, format) because the browser blocks
    returning full URLs with query strings, so reconstruct the URL here.
    """
    mid = photo.get("mediaId")
    if mid:
        fmt = photo.get("format") or "jpg"
        return f"https://pbs.twimg.com/media/{mid}?format={fmt}&name=orig"
    # fallback: a full url was supplied — rewrite its size param to orig
    url = photo.get("url") or ""
    m = _TWIMG_RE.search(url)
    if not m:
        return url
    fm = re.search(r"[?&]format=([a-z0-9]+)", url, re.I)
    fmt = fm.group(1) if fm else ("png" if ".png" in url.lower() else "jpg")
    return f"https://pbs.twimg.com/media/{m.group(1)}?format={fmt}&name=orig"


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_check():
    try:
        info = _request("GET", "/api/application/info", timeout=8)
    except Exception as e:
        print(json.dumps({"ok": False, "error": f"Eagle API not reachable: {e}"}))
        return 1
    data = info.get("data", {})
    print(json.dumps({
        "ok": True,
        "version": data.get("version"),
        "platform": data.get("platform"),
        "hasToken": bool(get_token()),
    }))
    return 0


def _iter_library():
    """
    Yield every item in the library, paging until exhausted.

    Eagle's `offset` is PAGE-based, not item-count based: with limit=500,
    offset=1 returns the *second* page of 500 (verified empirically). So the
    page index is passed to `offset` directly.
    """
    for page in range(MAX_PAGES):
        res = _request(
            "GET", "/api/item/list",
            params={"limit": PAGE_LIMIT, "offset": page, "orderBy": "-CREATEDATE"},
            timeout=45,
        )
        items = res.get("data", []) or []
        for it in items:
            yield it
        if len(items) < PAGE_LIMIT:
            return


def cmd_existing_ids():
    ids = set()
    for it in _iter_library():
        for k in media_keys(it.get("url")):
            ids.add(k)
    print(json.dumps({"count": len(ids), "ids": sorted(ids)}))
    return 0


def _clean_name(author, text, status_id):
    snippet = re.sub(r"\s+", " ", (text or "")).strip()
    if snippet:
        if len(snippet) > NAME_MAX:
            snippet = snippet[:NAME_MAX].rstrip() + "…"
        return f"@{author} — {snippet}"
    return f"@{author} tweet {status_id}"


def _add_from_url(url, name, website, annotation, mtime):
    body = {
        "url": url, "name": name, "website": website,
        "annotation": annotation, "modificationTime": mtime,
    }
    res = _request("POST", "/api/item/addFromURL", body=body, timeout=60)
    if res.get("status") != "success":
        raise RuntimeError(f"addFromURL failed: {res}")


def _add_from_path(path, name, website, annotation):
    body = {"path": path, "name": name, "website": website, "annotation": annotation}
    res = _request("POST", "/api/item/addFromPath", body=body, timeout=120)
    if res.get("status") != "success":
        raise RuntimeError(f"addFromPath failed: {res}")


def _sweep_cache():
    """Delete cached downloads left over from previous runs (older than CACHE_TTL)."""
    if not os.path.isdir(CACHE_DIR):
        return
    now = time.time()
    for f in os.listdir(CACHE_DIR):
        p = os.path.join(CACHE_DIR, f)
        try:
            if now - os.path.getmtime(p) > CACHE_TTL:
                os.remove(p)
        except OSError:
            pass


# Skip long videos: liked media is design inspiration (short clips/GIFs), not 45-minute
# talks. Videos longer than this (or larger than the size cap) are left for manual grabbing.
MAX_VIDEO_SECONDS = 600      # 10 minutes
MAX_VIDEO_FILESIZE = "150M"


def _download_video(status_id, status_url):
    """
    Download a tweet's video/GIF with yt-dlp into the persistent cache and return
    the file path. The file is intentionally NOT deleted here — Eagle copies it
    asynchronously after addFromPath returns (see CACHE_DIR note above).

    Returns None if the video was skipped by the duration/size filter (too long to be
    inspiration). Raises RuntimeError on a genuine download failure.
    """
    os.makedirs(CACHE_DIR, exist_ok=True)
    out_tmpl = os.path.join(CACHE_DIR, f"{status_id}.%(ext)s")
    common = [
        "--no-playlist",
        "--match-filter", f"duration<?{MAX_VIDEO_SECONDS}",  # <? also passes unknown-duration
        "--max-filesize", MAX_VIDEO_FILESIZE,
        "-o", out_tmpl,
    ]
    attempts = [
        ["yt-dlp", "--cookies-from-browser", "chrome"] + common + [status_url],
        ["yt-dlp"] + common + [status_url],  # fallback without cookies
    ]
    last_err = ""
    for cmd in attempts:
        try:
            out = subprocess.run(cmd, check=True, capture_output=True, text=True, timeout=300)
        except Exception as e:
            last_err = getattr(e, "stderr", "") or str(e)
            continue
        files = [os.path.join(CACHE_DIR, f) for f in os.listdir(CACHE_DIR)
                 if f.startswith(f"{status_id}.") and not f.endswith((".part", ".ytdl"))]
        if files:
            return max(files, key=os.path.getsize)  # largest = the video
        # exit 0 but no file → filtered out by duration/size (yt-dlp says "does not pass filter")
        blob = (out.stdout or "") + (out.stderr or "")
        if "does not pass filter" in blob or "filesize" in blob.lower():
            return None
    raise RuntimeError(f"yt-dlp failed: {last_err.strip()[:300]}")


def cmd_import(tweets_path):
    with open(tweets_path) as f:
        tweets = json.load(f)

    _sweep_cache()  # clear stale downloads from previous runs

    # Authoritative dedup: rebuild the existing-IDs set from the live library.
    existing = set()
    for it in _iter_library():
        existing |= media_keys(it.get("url"))

    now = int(time.time() * 1000)
    imported, skipped, failed, skipped_long = 0, 0, [], []

    for tw in tweets:
        author = (tw.get("author") or "unknown").lstrip("@")
        status_id = str(tw.get("statusId") or "")
        status_url = tw.get("statusUrl") or f"https://x.com/{author}/status/{status_id}"
        text = tw.get("text") or ""
        annotation = (text + ("\n\n" if text else "") + f"Liked from: {status_url}").strip()

        # --- photos ---
        for ph in tw.get("photos", []) or []:
            idx = ph.get("index") or 1
            mid = ph.get("mediaId")
            cand = {f"photo:{status_id}:{idx}"}
            if mid:
                cand.add(f"media:{mid}")
            if cand & existing:
                skipped += 1
                continue
            url = build_photo_url(ph)
            website = f"https://x.com/{author}/status/{status_id}/photo/{idx}"
            name = _clean_name(author, text, status_id)
            try:
                _add_from_url(url, name, website, annotation, now)
                imported += 1
                existing |= cand
            except Exception as e:
                failed.append({"tweet": status_url, "photo": idx, "error": str(e)[:200]})

        # --- video / gif ---
        if tw.get("hasVideo") or tw.get("hasGif"):
            key = f"status:{status_id}"
            if key in existing:
                skipped += 1
            else:
                name = _clean_name(author, text, status_id)
                try:
                    path = _download_video(status_id, status_url)
                    if path is None:
                        skipped_long.append(status_url)   # too long to be inspiration
                    else:
                        _add_from_path(path, name, status_url, annotation)
                        imported += 1
                        existing.add(key)
                except Exception as e:
                    failed.append({"tweet": status_url, "video": True, "error": str(e)[:200]})

    print(json.dumps({
        "imported": imported,
        "skipped_existing": skipped,
        "skipped_long_video": skipped_long,
        "failed": failed,
    }, indent=2))
    return 0  # partial failures/skips don't fail the run


# ---------------------------------------------------------------------------

def main(argv):
    if len(argv) < 2:
        print("usage: eagle_import.py {check|existing-ids|import <tweets.json>}", file=sys.stderr)
        return 2
    cmd = argv[1]
    if cmd == "check":
        return cmd_check()
    if cmd == "existing-ids":
        return cmd_existing_ids()
    if cmd == "import":
        if len(argv) < 3:
            print("import requires a tweets.json path", file=sys.stderr)
            return 2
        return cmd_import(argv[2])
    print(f"unknown command: {cmd}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
