# Machine-specific setup — Mac

Per-machine tooling notes for the browser-verification workflow in `CLAUDE.md`. This file is
imported into the global config via `@~/.claude/machine.md`, which the sync script symlinks to
this file on Mac.

## Playwright browser tooling

The tooling on this machine is installed and working. Do **not** conclude "no browser is
available" — a missing PATH is **not** "no browser."

- **Browsers** live in `~/Library/Caches/ms-playwright` (Playwright 1.58.2). Check this path
  before deciding a browser is missing; only if truly absent: `npx playwright install chromium`.
- **`playwright-cli`** is installed **globally under the active nvm node `v24.18.0`** (so plain
  `which playwright-cli` resolves), with a backstop copy still under `v22.17.1`.

### PATH recovery

If `which playwright-cli` does **not** resolve, the active nvm node just isn't on PATH:

- Use the backstop directly: `~/.nvm/versions/node/v22.17.1/bin/playwright-cli`, or
- `nvm use 22`, or
- Re-install on the active node: `npm install -g @playwright/cli@latest`.

If nvm's active node is ever switched, re-run `npm install -g @playwright/cli@latest` under the
new active node to put `playwright-cli` back on PATH.
