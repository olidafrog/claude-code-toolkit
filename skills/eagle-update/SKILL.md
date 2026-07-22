---
name: eagle-update
description: Use when Oli wants to pull his latest X (Twitter) likes into his Eagle library — capturing new liked images and videos since the last import so he can review and file them. Triggers on "/eagle-update", "update eagle", "grab my twitter likes", "sync my X likes into eagle".
---

# eagle-update

Capture the **delta** of Oli's X (Twitter) likes into his Eagle library: read his Likes,
skip anything already in the library (dedup by source URL, resolution-agnostic), and import
new images/videos at full resolution into the library root.

Media saved: images + videos/GIFs. Each item stores the tweet URL as its Eagle source and
`@author — <tweet text>` as name/annotation. No folder, no tags (imports land in the root).

Two helper scripts do the deterministic work — call them, don't reimplement them:

```
FETCH="$HOME/.claude/skills/eagle-update/scripts/fetch_likes.py"    # X → tweets JSON (bird)
IMPORT="$HOME/.claude/skills/eagle-update/scripts/eagle_import.py"   # tweets JSON → Eagle
```

**Primary path = the `bird` CLI** (below): it reads Likes straight from X's GraphQL API using
the logged-in session cookies — no browser, no scraping, one API call. **Fallback = the
Claude-in-Chrome DOM scrape** (see "Fallback" at the end), used only when bird is unavailable
or breaks (X rotates its GraphQL query IDs).

## Step 1 — Preflight (stop early if either fails)

1. **Eagle running?** `python3 "$IMPORT" check` → must print `"ok": true`. If not, tell Oli
   to open the Eagle desktop app (the API only runs while Eagle is open) and stop.
2. **bird installed?** `bird --version`. If "command not found", install it from the bundled
   tarball: `npm install -g "$HOME/GitHub/claude-code-toolkit/skills/bird-skill/bird-0.8.0.tgz"`.
   If install fails, skip to the **Fallback** path.

`fetch_likes.py` reads Oli's `auth_token`/`ct0` from Chrome automatically (he's logged into
x.com in Chrome — Profile 1). The first run of a session may pop a macOS Keychain prompt for
"Chrome Safe Storage" — that's expected; approve it. Don't pass or log the cookies.

## Step 2 — Fetch the likes

```
python3 "$FETCH" --limit 50 > /tmp/eagle_tweets.json
```

`--limit` caps how many recent likes to pull in one call (default 50). This is one GraphQL
request; no scrolling, no per-round dedup. The output already matches the import shape
(`statusUrl`, `statusId`, `author`, `text`, `photos:[{index,mediaId,format,url}]`, `hasVideo`,
`hasGif`). It prints `fetched N likes` to stderr.

If it prints an `{"error": ...}` to stderr instead (e.g. `bird failed`, rate-limited, or
cookies missing/expired), read the message: a 429 means wait a few minutes; a credentials
error means Oli needs to re-log into x.com in Chrome. If bird itself is broken, use the
**Fallback** path.

## Step 3 — Import

```
python3 "$IMPORT" import /tmp/eagle_tweets.json
```

The importer re-dedups against the **live library** authoritatively (by source URL at photo
granularity, resolution-agnostic), so it's safe to hand it likes that are already saved —
they're skipped, not duplicated. It downloads videos/GIFs via yt-dlp (short clips only; see
Notes) and imports images at full resolution (`name=orig`). Prints a JSON summary:
`imported` / `skipped_existing` / `skipped_long_video` / `failed`.

## Step 4 — Report

Relay the summary to Oli: how many imported, how many skipped as already present, and any
`failed` entries (protected tweets, age-gated video yt-dlp couldn't fetch) with their tweet
URLs so he can grab those by hand. Remind him the new items are in the Eagle library root,
ready to review and file into his folders.

## Notes

- **Idempotent:** dedup is by source URL at photo granularity and resolution-agnostic (a prior
  `name=large` save and a new `name=orig` of the same image are the same asset). Re-running is
  safe — already-saved likes are skipped.
- **Going deeper:** raise `--limit` (e.g. `--limit 100`) to pull further back through the Likes
  timeline. Each run is one API call; the importer skips whatever's already in the library.
- **Rate limits:** X's GraphQL API is aggressively rate-limited. One `fetch_likes` call per run
  is fine; don't loop it tightly. A 429 means back off a few minutes.
- **Eagle indexing is asynchronous** — a just-imported item takes a few seconds to appear in
  `item/list`. Don't run the skill twice within the same minute (the second run won't see the
  first run's items yet and would re-import them). Across normal runs (minutes/days apart) dedup
  is reliable; within a single run the importer dedups in memory.
- **Long videos skipped:** clips over 10 min / 150 MB are treated as not-inspiration and left
  for manual grabbing (listed under `skipped_long_video`).
- **Cookie expiry:** `auth_token` eventually expires (weeks/months). If `fetch_likes` reports a
  credentials error, Oli just needs to open x.com in Chrome again to refresh the session.
- **Don't hardcode secrets** — the importer self-discovers the Eagle API token; `fetch_likes`
  self-extracts the X cookies. Never log either.

---

## Fallback — Claude-in-Chrome scrape

Use this ONLY if bird can't run (not installed and won't install, or X changed its GraphQL
query IDs so `bird likes` errors even with valid cookies). It scrapes the rendered Likes page
in the logged-in Chrome. It produces the **same** `/tmp/eagle_tweets.json` shape, so Step 3
(import) and Step 4 (report) above are unchanged — only the fetch differs.

### F1 — Browser + existing-ids

1. `mcp__claude-in-chrome__list_connected_browsers`. Empty list → ask Oli to connect the Chrome
   extension and stop. Select the local browser.
2. Build the "already have it" set so scrolling knows when it's caught up:
   ```
   python3 "$IMPORT" existing-ids > /tmp/eagle_existing.json
   ```
   Load `ids` (keys like `photo:<statusId>:<n>`, `media:<twimgId>`, `status:<statusId>`) into a Set.

### F2 — Open his Likes

Likes are private, so the logged-in session is required. Detect his handle — don't ask:

1. `navigate` to `https://x.com/home`.
2. Read the handle via `javascript_tool`, then navigate to the Likes tab:
   ```js
   document.querySelector('a[data-testid="AppTabBar_Profile_Link"]')?.getAttribute('href')
   ```
3. `navigate` to `https://x.com/<handle>/likes`.

### F3 — Scrape the delta (scroll + extract loop)

**Critical:** the automated tab is backgrounded, so X throttles it. `window.scrollBy` in JS does
NOT render or paginate the feed. You MUST scroll with the **`computer` tool** — that renders
tweets and loads their media. Extract with `javascript_tool` between scrolls.

One round = one scroll + one extract:

1. `computer` `scroll` down at coordinate `[640, 400]`, `scroll_amount: 10` (max allowed).
2. Wait ~1.5s, then run this extractor via `javascript_tool`. It returns tweet objects with
   **safe tokens only** (mediaId/format/index) — the browser blocks returning full media URLs,
   and the importer rebuilds them. **If it returns `[]` on a page with visible tweets, X changed
   its markup — adapt the `data-testid` selectors and retry.**

```js
const out = [];
for (const art of document.querySelectorAll('article[data-testid="tweet"]')) {
  const link = [...art.querySelectorAll('a[href*="/status/"]')].find(a => a.querySelector('time'));
  const m = link && link.getAttribute('href').match(/^\/([^/]+)\/status\/(\d+)/);
  if (!m) continue;
  const [author, statusId] = [m[1], m[2]];
  const photos = [], seen = new Set();
  for (const img of art.querySelectorAll('img[src*="pbs.twimg.com/media/"]')) {
    const src = img.getAttribute('src');
    const mediaId = src.match(/media\/([A-Za-z0-9_\-]+)/)?.[1];
    if (!mediaId || seen.has(mediaId)) continue;                 // dedupe within tweet
    // keep only MAIN-tweet photos: their /photo/ anchor points to THIS status
    // (this drops images belonging to a quoted tweet nested in the same article)
    const hm = img.closest('a[href*="/photo/"]')?.getAttribute('href')
                  ?.match(/\/([^/]+)\/status\/(\d+)\/photo\/(\d+)/);
    if (!hm || hm[2] !== statusId) continue;
    seen.add(mediaId);
    photos.push({ mediaId, format: src.match(/format=([a-z0-9]+)/i)?.[1] || 'jpg', index: +hm[3] });
  }
  const hasVideo = !!art.querySelector('[data-testid="videoPlayer"], [data-testid="videoComponent"], video');
  out.push({ statusUrl:`https://x.com/${author}/status/${statusId}`, statusId, author,
             text: art.querySelector('[data-testid="tweetText"]')?.innerText || '',
             photos, hasVideo, hasGif:false });
}
JSON.stringify(out)
```

**Accumulate** across rounds into `collected`, deduped by `statusId`. Maintain
`consecutiveSeen = 0`. For each **newly seen** tweet (statusId not seen this run):

- Media keys: for each photo `photo:<statusId>:<index>` and `media:<mediaId>`; for video
  `status:<statusId>`.
- If **all** the tweet's keys are already in the existing-ids Set → already in Eagle →
  `consecutiveSeen++`.
- Otherwise → add to `collected`, reset `consecutiveSeen = 0`.

**Stop** when any holds:
- `collected.length >= 50` (hard cap), OR
- `consecutiveSeen >= 5` (caught up to the last import), OR
- two consecutive scrolls surface no new statusIds (end of timeline).

Note: this account's likes are video-heavy, so many rounds yield only videos — that's normal.

Write `collected` to `/tmp/eagle_tweets.json`, then continue at **Step 3 — Import** above.
