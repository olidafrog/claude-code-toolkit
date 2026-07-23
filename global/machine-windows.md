# Machine-specific setup — Windows

Per-machine tooling notes for the browser-verification workflow in `CLAUDE.md`. This file is
imported into the global config via `@~/.claude/machine.md`, which the sync script symlinks to
this file on Windows.

Recorded 2026-07-23 on this machine (Windows 11 Pro, build 26200). Node is a **system install
(no nvm on Windows)**, so global npm binaries sit under one fixed prefix rather than a per-version
path like the Mac.

## Playwright browser tooling

The tooling on this machine is **installed and working**. Do **not** conclude "no browser is
available" — a missing PATH is **not** "no browser."

- **Browsers** live in `%USERPROFILE%\AppData\Local\ms-playwright`
  (`C:\Users\oliin\AppData\Local\ms-playwright`) — Chromium build **1208** plus its headless
  shell, `ffmpeg`, and `winldd` are present. Check this path before deciding a browser is missing;
  only if truly absent: `npx playwright install chromium`.
- **`playwright-cli`** is installed **globally** — `@playwright/cli` **v0.1.17**, shim on PATH at
  `C:\Users\oliin\AppData\Roaming\npm\playwright-cli.ps1`. Verified working **headless**
  (`open` → `snapshot` → `close` round-trips cleanly). **Headless is the default**; pass `--headed`
  to `open` for a visible window. To reinstall/update:
  ```powershell
  npm install -g @playwright/cli@latest
  ```
  npm's global prefix here is `%USERPROFILE%\AppData\Roaming\npm`
  (`C:\Users\oliin\AppData\Roaming\npm`), which is on PATH, so the shim resolves automatically.
- **Node**: v24.12.0 at `C:\Program Files\nodejs` (npm 10.8.2). Only one active Node, so no
  per-version PATH juggling.

### PATH recovery

If `playwright-cli` does **not** resolve after installing (`Get-Command playwright-cli`):

- Confirm `%USERPROFILE%\AppData\Roaming\npm` is on PATH (it holds the global `.cmd` shims), or
- Re-install on the active Node: `npm install -g @playwright/cli@latest`.

> A one-off libuv `UV_HANDLE_CLOSING` assertion (`async.c` line 76, exit 9) can print on the
> **first** invocation right after install. It clears on subsequent runs and is harmless.

## Shell for `.sh` scripts (statusline, examples)

The `bash` on PATH is **WSL** (`C:\Windows\system32\bash.exe`), whose `~` is the Linux home — it
will **not** find `~/.claude/...` Windows files. **Git Bash** is the shell that shares the Windows
home:

- Git Bash: `C:\Program Files\Git\bin\bash.exe` (or `sh.exe` at `C:\Program Files\Git\bin\sh.exe`).
- Git's `cmd\` is on PATH (so `git` works), but its `bin\` / `usr\bin\` are **not**, so a bare
  `sh` does not resolve.

The statusline in `settings.json` is `bash ~/.claude/statusline-command.sh`. If it renders blank,
point it at Git Bash explicitly, e.g.
`"C:\\Program Files\\Git\\bin\\bash.exe" ~/.claude/statusline-command.sh`, or leave the statusline
unset on this machine.

**`statusline-command.sh` requires `jq`** to parse the JSON Claude Code pipes in. Git Bash does
**not** bundle `jq`, so without it the line collapses to just the folder icon, git branch, and a
bare model emoji (model name, context bar, tokens, session %, and cost all disappear). Installed
here via `winget install jqlang.jq` (**jq 1.8.2**, shim at
`%LOCALAPPDATA%\Microsoft\WinGet\Links\jq.exe`, on PATH). After installing, **restart Claude Code**
so its process picks up the new PATH — a running session keeps the stale PATH and still shows the
broken line until restarted.

## Symlink sync (setup gotcha)

`~/.claude` is populated by `scripts\sync.ps1`, which symlinks the repo's skills / agents /
commands into it. Two Windows specifics:

- **Developer Mode must be on** (Settings → System → For developers) so links create without an
  admin prompt. Currently **enabled** on this machine.
- Windows PowerShell 5.1's `New-Item -ItemType SymbolicLink` ignores Developer Mode and still
  demands admin, so `sync.ps1` creates links via `cmd mklink` (which honors Developer Mode).
  There is no `pwsh` / PowerShell 7 here — only Windows PowerShell 5.1.
