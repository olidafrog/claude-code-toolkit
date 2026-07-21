# Machine-specific setup — Windows

Per-machine tooling notes for the browser-verification workflow in `CLAUDE.md`. This file is
imported into the global config via `@~/.claude/machine.md`, which the sync script symlinks to
this file on Windows.

> **Stub — fill in on the Windows machine.** Run Claude Code there and have it record the actual
> tooling state, mirroring the headings in `machine-mac.md`.

## Playwright browser tooling

- **Browsers** live in: _TODO_ (on Windows, typically `%USERPROFILE%\AppData\Local\ms-playwright`).
- **`playwright-cli`** installed via: _TODO_ (e.g. `npm install -g @playwright/cli@latest`).

### PATH recovery

_TODO — how to get `playwright-cli` back on PATH on this machine._

## Notes

- The statusline script (`statusline-command.sh`) is a POSIX shell script; on Windows it needs
  `sh` (Git Bash / WSL) on PATH to run, or leave the statusline unconfigured here.
