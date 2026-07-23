# Machine-specific setup — Windows

Per-machine tooling notes for the browser-verification workflow in `CLAUDE.md`. This file is
imported into the global config via `@~/.claude/machine.md`, which the sync script symlinks to
this file on Windows.

Recorded 2026-07-23 on this machine (Windows 11 Pro, build 26200). Node is a **system install
(no nvm on Windows)**, so global npm binaries sit under one fixed prefix rather than a per-version
path like the Mac.

## Playwright browser tooling

The **browsers are installed**; the **`playwright-cli` wrapper is not yet installed** on this
machine. Do **not** conclude "no browser is available" — a missing `playwright-cli` is not a
missing browser.

- **Browsers** live in `%USERPROFILE%\AppData\Local\ms-playwright`
  (`C:\Users\oliin\AppData\Local\ms-playwright`) — Chromium build **1208** plus its headless
  shell, `ffmpeg`, and `winldd` are present. Check this path before deciding a browser is missing;
  only if truly absent: `npx playwright install chromium`.
- **`playwright-cli`** is **not currently installed** (`@playwright/cli` is absent from the global
  modules, and `playwright-cli` does not resolve on PATH). Install it with:
  ```powershell
  npm install -g @playwright/cli@latest
  ```
  npm's global prefix here is `%USERPROFILE%\AppData\Roaming\npm`
  (`C:\Users\oliin\AppData\Roaming\npm`), which is already on PATH, so the `playwright-cli` shim
  lands on PATH automatically after install.
- **Node**: v24.12.0 at `C:\Program Files\nodejs` (npm 10.8.2). Only one active Node, so no
  per-version PATH juggling.

### PATH recovery

If `playwright-cli` does **not** resolve after installing (`Get-Command playwright-cli`):

- Confirm `%USERPROFILE%\AppData\Roaming\npm` is on PATH (it holds the global `.cmd` shims), or
- Re-install on the active Node: `npm install -g @playwright/cli@latest`.

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

## Symlink sync (setup gotcha)

`~/.claude` is populated by `scripts\sync.ps1`, which symlinks the repo's skills / agents /
commands into it. Two Windows specifics:

- **Developer Mode must be on** (Settings → System → For developers) so links create without an
  admin prompt. Currently **enabled** on this machine.
- Windows PowerShell 5.1's `New-Item -ItemType SymbolicLink` ignores Developer Mode and still
  demands admin, so `sync.ps1` creates links via `cmd mklink` (which honors Developer Mode).
  There is no `pwsh` / PowerShell 7 here — only Windows PowerShell 5.1.
