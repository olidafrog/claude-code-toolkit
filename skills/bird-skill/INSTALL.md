# Bird — X/Twitter CLI: Install Guide

## What's included

| File | Description |
|------|-------------|
| `bird-0.8.0.tgz` | npm package tarball (v0.8.0) — the tool itself |
| `SKILL.md` | Hermes Agent skill definition with full command reference |

> **Why the tarball?** The GitHub repo (github.com/jawond/bird) and npm package (@steipete/bird) have been taken down. The tarball is a snapshot of the last published version so you can still install it.

---

## Installation

### Prerequisites

- **Node.js** ≥ 18 (check with `node --version`)

### Option A: Install from local tarball (recommended)

```bash
# Install globally from the bundled tarball
npm install -g ./bird-0.8.0.tgz
```

### Option B: Install from npm (if it comes back)

```bash
npm install -g @steipete/bird
```

### Verify it works

```bash
bird --version
# → 0.8.0

bird --help
```

---

## Authentication

Bird uses your existing X/Twitter session cookies — no API keys needed.

### Extract cookies from your browser

1. Log into **x.com** in your browser (Chrome, Firefox, Arc, etc.)
2. Press **F12** → **Application** tab → **Cookies** → **https://x.com**
3. Copy the values for:
   - **`auth_token`** (a long hex string)
   - **`ct0`** (a shorter hex string)

### Configure Bird

**Method 1 — Environment variables** (recommended for Hermes):

```bash
# On Linux/macOS
export AUTH_TOKEN="your_auth_token_here"
export CT0="your_ct0_here"

# On Windows (PowerShell)
$env:AUTH_TOKEN="your_auth_token_here"
$env:CT0="your_ct0_here"

# On Windows (Git Bash / MSYS)
export AUTH_TOKEN="your_auth_token_here"
export CT0="your_ct0_here"
```

For Hermes Agent, add these to `~/.hermes/.env` so they persist across sessions.

**Method 2 — Config file:**

Create `~/.config/bird/config.json5`:

```json5
{
  authToken: "your_auth_token_here",
  ct0: "your_ct0_here",
  timeoutMs: 20000,
  quoteDepth: 1
}
```

### Verify auth works

```bash
bird whoami
# Should show your @handle

bird check
# Shows where credentials were found
```

> **⚠️ macOS users only:** bird can auto-detect cookies from Safari, Chrome, or Firefox:
> ```bash
> bird --firefox-profile default-release whoami
> ```
> On Linux and Windows you must provide credentials manually via env vars or config file.

---

## Quick Reference

| Action | Command |
|--------|---------|
| Who am I | `bird whoami` |
| Read tweet | `bird read ID --json` |
| Thread | `bird thread ID --all --json` |
| Search | `bird search "query" -n 10` |
| Home timeline | `bird home -n 20` |
| User tweets | `bird user-tweets @handle -n 20` |
| Post tweet | `bird tweet "text"` |
| Reply | `bird reply ID "text"` |
| Bookmarks | `bird bookmarks -n 10` |
| Likes | `bird likes -n 10` |
| News | `bird news -n 10` |
| Following | `bird following -n 20` |
| Followers | `bird followers -n 20` |

> **Full reference** with detailed examples, JSON output, and troubleshooting — see `SKILL.md`.

---

## Hermes Agent setup

To use bird inside Hermes Agent:

1. Copy `SKILL.md` to your Hermes skills directory:
   ```
   ~/AppData/Local/hermes/skills/social-media/bird/SKILL.md   (Windows)
   ~/.local/share/hermes/skills/social-media/bird/SKILL.md     (Linux)
   ~/Library/Application Support/hermes/skills/social-media/bird/SKILL.md  (macOS)
   ```

2. Set `AUTH_TOKEN` and `CT0` in `~/.hermes/.env`

3. Hermes will automatically load the skill and use bird for X/Twitter operations

---

## Warnings

- **Rate limits**: X's internal GraphQL API is aggressively rate-limited — space out requests
- **Undocumented API**: Endpoints and query IDs can change without notice
- **Cookie expiry**: `auth_token` cookies expire eventually — extract fresh ones if bird stops working
- **Posting**: Always confirm with the user before posting or replying

---

## Attribution

- **Original project**: [github.com/jawond/bird](https://github.com/jawond/bird) (Peter Steinberger, MIT license)
- **npm**: `@steipete/bird` v0.8.0
- **Hermes skill**: adapted from OpenClaw skill `@sakaen736jih/bird-xn`