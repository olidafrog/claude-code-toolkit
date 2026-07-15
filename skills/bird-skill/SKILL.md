---
name: bird
description: "X/Twitter CLI for reading, searching, posting, and engagement via cookie-based GraphQL auth (no Developer account or paid API credits required)."
version: 1.0.0
author: steipete + OpenClaw + Hermes Agent
license: MIT
platforms: [linux, macos, windows]
prerequisites:
  commands: [bird]
metadata:
  hermes:
    tags: [twitter, x, social-media, bird, cookie-auth]
    homepage: https://github.com/jawond/bird
---

# bird — X/Twitter via Cookie-Based GraphQL CLI

`bird` is a Node.js CLI (`@steipete/bird`) that talks to X/Twitter's internal GraphQL API using browser cookies — **no Developer account, no OAuth, no paid API credits**. It supports reading tweets, threads, searching, posting, replying, bookmarks, likes, mentions, user timelines, news/trending, lists, followers/following, and more.

Use this skill for:
- reading tweets, threads, and user timelines
- searching tweets
- checking mentions and home timeline
- posting tweets and replies (confirm with user first!)
- browsing bookmarks and likes
- checking news/trending topics
- looking up followers/following
- list timelines

This skill replaces the older `xurl` (paid X API) and `xitter` (x-cli) skills for Hermes. Cookie-based auth is zero-cost and zero-friction — no Developer portal, no OAuth dance.

---

## Installation

bird is already available via npm:

```bash
npm install -g @steipete/bird
# or
pnpm add -g @steipete/bird
```

Verify:

```bash
bird --version
bird whoami
```

---

## Authentication

bird authenticates using X session cookies (`auth_token` + `ct0`), NOT API keys.

### Method 1: Environment Variables (recommended for agents)

```bash
export AUTH_TOKEN="your_auth_token_here"
export CT0="your_ct0_here"
```

These are sourced before Hermes starts (add to `~/.hermes/.env`).

### Method 2: Config File

`~/.config/bird/config.json5`:

```json5
{
  authToken: "your_auth_token_here",
  ct0: "your_ct0_here",
  timeoutMs: 20000,
  quoteDepth: 1
}
```

### Extracting Cookies from Browser

#### On macOS (auto-detection works)
bird can automatically extract cookies from Safari, Chrome, or Firefox:
```bash
bird --firefox-profile default-release whoami
```

#### On Linux/WSL2 (manual required)
bird's browser cookie auto-detection does NOT work on Linux due to file access restrictions. You MUST manually provide credentials:

**Option 1: Environment Variables (recommended)**
```bash
export AUTH_TOKEN="your_auth_token_here"
export CT0="your_ct0_here"
# Add to ~/.hermes/.env for persistence
```

**Option 2: Config File**
```json5
// ~/.config/bird/config.json5
{
  authToken: "your_auth_token_here",
  ct0: "your_ct0_here",
  timeoutMs: 20000,
  quoteDepth: 1
}
```

#### Extracting cookies from any browser (Chrome/Chromium/Firefox/Arc/etc.)
1. Log into x.com in your browser
2. Open DevTools (F12) → Application → Cookies → https://x.com
3. Copy the values for:
   - `auth_token`
   - `ct0`
4. Use one of the methods above to provide them to bird

> **WSL2 + Windows browser note:** If using a Windows browser (Chrome, Firefox, Arc, etc.) from WSL2, you cannot directly access the locked cookie database. You must:
> 1. Extract cookies manually via DevTools as described above, OR
> 2. For Arc browser specifically: cookies are stored in `/mnt/c/Users/<username>/AppData/Local/Packages/TheBrowserCompany.Arc_*/LocalCache/Local/Arc/User Data/Default/Network/Cookies` but are typically locked; manual extraction via DevTools is recommended

### Verify Auth

```bash
# Show logged-in account
bird whoami

# Show credential sources
bird check
```

---

## Quick Reference

|| Action | Command |
||--------|---------|
|| Who am I | `bird whoami` |
|| Read a tweet | `bird read URL_OR_ID` (--json for structured output) |
|| Thread | `bird thread URL_OR_ID` |
|| Replies | `bird replies URL_OR_ID` |
|| Search | `bird search "query" -n 10` |
|| Mentions | `bird mentions -n 10` |
|| Home timeline | `bird home -n 20` |
|| User tweets | `bird user-tweets @handle -n 20` |
|| Post tweet | `bird tweet "text"` |
|| Reply | `bird reply ID_OR_URL "text"` |
|| Bookmarks | `bird bookmarks -n 10` |
|| Likes | `bird likes -n 10` |
|| News/Trending | `bird news -n 10` |
|| Following | `bird following -n 20` |
|| Followers | `bird followers -n 20` |
|| List timeline | `bird list-timeline LIST_ID -n 20` |
|| Check auth | `bird check` |

---

## Command Details

### Reading

```bash
# Single tweet (URL or ID)
bird read https://x.com/user/status/1234567890
bird 1234567890 --json

# Full conversation thread
bird thread https://x.com/user/status/1234567890
bird thread 1234567890 --all --max-pages 3 --json

# Replies to a tweet
bird replies 1234567890
bird replies 1234567890 --max-pages 3 --json
```

### Search & Discovery

```bash
# Search tweets
bird search "AI agents" -n 10
bird search "from:nousresearch" -n 5
bird search "query" --all --max-pages 3 --json

# Mentions of your account
bird mentions -n 10
bird mentions --user @handle -n 10 --json

# Home timeline
bird home -n 20
bird home --following -n 20        # Following timeline (not For You)
bird home --json

# User profile timeline
bird user-tweets @handle -n 20
bird user-tweets @handle -n 50 --json

# News and trending
bird news -n 10                    # all tabs
bird news --ai-only -n 20          # AI-curated only
bird news --sports -n 10
bird news --json -n 5
```

### Posting (always confirm with user first!)

```bash
bird tweet "Hello from bird!"
bird reply 1234567890 "Great post!"
bird reply https://x.com/user/status/1234567890 "Agreed!"
```

### Bookmarks & Likes

```bash
bird bookmarks -n 10
bird bookmarks --all --json
bird bookmarks --folder-id FOLDER_ID -n 10
bird bookmarks --include-parent --json

bird likes -n 10
```

### Social Graph

```bash
bird following -n 20
bird following --user @handle -n 10

bird followers -n 20
bird followers --user @handle -n 10
```

### Lists

```bash
bird list-timeline 1234567890 -n 20
bird list-timeline https://x.com/i/lists/1234567890 --all --json
```

---

## JSON Output

Add `--json` for structured, machine-readable output:

```bash
bird read 1234567890 --json
bird search "query" -n 5 --json
bird mentions -n 10 --json
```

JSON output includes tweet text, author info, metrics, media links, etc.

---

## Engine / Transport

bird supports two engines:

- **`graphql` (default):** Uses Twitter/X GraphQL with cookies. No API key needed.
- **`sweetistics`:** Uses Sweetistics API key. No cookies needed, but requires paid third-party key.
- **`auto`:** Sweetistics if API key present, otherwise GraphQL.

```bash
bird --engine graphql whoami
bird --engine sweetistics tweet "hi" --media img.png
```

---

## Agent Workflow

1. Verify bird is installed: `bird --version`
2. Verify auth: `bird whoami` — should show the logged-in account
3. Start with a cheap read command to confirm reachability
4. For write operations (tweet, reply), ALWAYS confirm intent with the user first
5. Use `--json` when extracting fields for later steps
6. To archive media from likes (e.g., to Eagle), fetch likes with `--json`, extract media URLs, and POST them to the target service’s API (see examples in references/)
7. When uploading to external services (e.g., Eagle), first verify the service is reachable (e.g., `curl -s http://<host>:<port>/api/info?token=…`).
8. See `references/twitter_to_eagle.md` for a complete workflow script to sync Twitter likes to Eagle library.

---

## ⚠️ Important Warnings

1. **Rate limits:** X's internal GraphQL endpoints are aggressively rate-limited. Frequent reads/writes will cause **429 errors**. Space out requests and use `--delay` flags where available.
2. **Undocumented API:** bird uses X's undocumented web GraphQL API. Endpoints and query IDs can change without notice — expect occasional breakage.
3. **Posting confirmation:** Always confirm with the user before posting or replying. bird has real posting capability — be careful.
4. **Cookie expiry:** `auth_token` cookies expire eventually. If bird stops working, extract fresh cookies from your browser.

---

## Troubleshooting

|| Symptom | Likely Cause | Fix |
||---------|-------------|-----|
|| `Missing auth_token` | Cookies not sourced | Export `AUTH_TOKEN` + `CT0` or set config.json5 |
|| 429 Too Many Requests | Rate limited | Wait, reduce frequency, use --delay |
|| `bird: command not found` | Not installed | `npm install -g @steipete/bird` |
|| Posting fails silently | Query ID rotated | Run `bird query-ids --fresh` |
|| Cookie warning on Linux | No browser cookie DB found or permission denied | Use env vars or config file — browser auto-detect is macOS-only. On Linux/WSL2, manually extract auth_token and ct0 cookies via browser DevTools. |
|| `EACCES: permission denied` when accessing cookie file | Locked cookie database on WSL2 (especially with Arc browser) | Use manual credential extraction via browser DevTools (Application → Cookies → x.com) rather than trying to access the cookie file directly |
|| `EACCES: permission denied` when accessing cookie file | Locked cookie database on WSL2 (especially with Arc browser) | Use manual credential extraction via browser DevTools (Application → Cookies → x.com) rather than trying to access the cookie file directly |

---

## Attribution

- CLI: https://github.com/jawond/bird (Peter Steinberger, MIT license)
- npm: `@steipete/bird`
- Homebrew: `steipete/tap/bird`
- OpenClaw skill: `@sakaen736jih/bird-xn`
