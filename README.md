# Claude Code Toolkit

My personal Claude Code setup — skills, agents, slash commands, global `CLAUDE.md`, and status
line — kept in one git repo and **symlinked into `~/.claude/`** on each machine so everything
stays in sync across my Mac and my Windows machine.

**This repo is the single source of truth.** The live files Claude Code loads from `~/.claude/`
are symlinks pointing back into this clone. Editing a skill (by hand or through Claude) changes
the file in this repo directly, so `git` sees every change and `push`/`pull` moves it between
machines.

---

## How the sync works (read this first)

Each machine clones this repo into its GitHub folder, then runs a **sync script** that creates
symlinks in `~/.claude/`:

```
~/.claude/skills/find-logo   ->   <repo>/skills/find-logo
~/.claude/agents/*.md        ->   <repo>/agents/*.md
~/.claude/commands/*.md      ->   <repo>/commands/*.md
~/.claude/CLAUDE.md          ->   <repo>/global/CLAUDE.md
~/.claude/machine.md         ->   <repo>/global/machine-mac.md   (or machine-windows.md)
~/.claude/statusline-command.sh -> <repo>/global/statusline-command.sh
```

A **symlink** is a filesystem alias — Claude Code reads and writes through it as if the file were
really in `~/.claude/`, but the bytes live in this repo. Nothing inside the repo is a symlink
(the links only point *into* it), so GitHub and the Windows checkout behave like a normal repo.

### Why `CLAUDE.md` lives in `global/`, not the repo root

If a `CLAUDE.md` sat at the repo root, Claude Code would load it as *this project's* instructions
every time you worked in this repo. Keeping it in `global/` and symlinking it to `~/.claude/CLAUDE.md`
avoids that — it only ever applies as the user-wide global config.

### Per-machine config split

`global/CLAUDE.md` is shared verbatim across machines. The parts that differ per machine (Playwright
browser paths, node versions, PATH-recovery steps) live in **`global/machine-mac.md`** and
**`global/machine-windows.md`**. `CLAUDE.md` ends with `@~/.claude/machine.md`, and the sync script
points that symlink at the right file for the current machine. Both machine files are tracked, so
each machine can see (and edit) the other's notes.

---

## Day-to-day sync

Run the sync script whenever you sit down at a machine or after making changes:

```sh
# Mac / Linux
scripts/sync.sh                    # pull + (re)link + report untracked local items + show status
scripts/sync.sh --push "message"   # ...then commit everything and push

# Windows (PowerShell)
powershell -File scripts\sync.ps1
powershell -File scripts\sync.ps1 -Push "message"
```

The script is **idempotent** — safe to run repeatedly. It:

1. `git pull --rebase --autostash` (warns and continues if offline).
2. (Re)creates any missing/incorrect symlinks. If it would overwrite a **real** file, it moves
   that file to `~/.claude/backups/toolkit-migration-<timestamp>/` first — it never deletes.
3. Reports anything real in `~/.claude/{skills,agents,commands}` that isn't in the repo — i.e. a
   skill you created locally that should be moved into the repo. (Known vendor skills are ignored.)
4. Shows `git status`; with `--push` it commits and pushes.

**Typical flow:** edit a skill → `scripts/sync.sh --push "improve find-logo"` on machine A →
`scripts/sync.sh` (pulls) on machine B. Conflicts from editing both machines are ordinary git
conflicts, resolved here in the repo.

**Adopting a new local skill:** create it in `~/.claude/skills/foo`, then `mv ~/.claude/skills/foo
<repo>/skills/foo` and re-run the sync script to link it back.

---

## First-time setup on a new machine

### Mac / Linux

```sh
git clone https://github.com/olidafrog/claude-code-toolkit ~/GitHub/claude-code-toolkit
cd ~/GitHub/claude-code-toolkit
scripts/sync.sh          # backs up existing ~/.claude copies, replaces them with symlinks
```

If the status line isn't showing, confirm `~/.claude/settings.json` contains:

```json
"statusLine": { "type": "command", "command": "sh /Users/<you>/.claude/statusline-command.sh" }
```

### Windows (native, PowerShell)

1. **Enable Developer Mode** — Settings → System → For developers. This lets PowerShell create
   symlinks without an admin prompt. One toggle, no restart.
2. Clone and link:
   ```powershell
   git clone https://github.com/olidafrog/claude-code-toolkit "$env:USERPROFILE\GitHub\claude-code-toolkit"
   cd "$env:USERPROFILE\GitHub\claude-code-toolkit"
   powershell -File scripts\sync.ps1
   ```
3. Fill in **`global/machine-windows.md`** with this machine's tooling (Claude can do it), then
   `scripts\sync.ps1 -Push "windows machine notes"`.

Line endings are normalized by `.gitattributes` (LF for `.sh`/`.py`/`.md`, CRLF for `.ps1`) so the
Windows checkout doesn't mangle shell scripts.

---

## Repo layout

```
skills/          # AgentSkills            -> ~/.claude/skills/<name>
agents/          # custom subagents       -> ~/.claude/agents/<name>.md
commands/        # slash commands         -> ~/.claude/commands/<name>.md
global/
  CLAUDE.md              # shared global instructions  -> ~/.claude/CLAUDE.md
  machine-mac.md         # Mac tooling notes           -> ~/.claude/machine.md (on Mac)
  machine-windows.md     # Windows tooling notes       -> ~/.claude/machine.md (on Windows)
  statusline-command.sh  # status line script          -> ~/.claude/statusline-command.sh
scripts/
  sync.sh          # Mac/Linux pull + link + push helper
  sync.ps1         # Windows equivalent
.gitattributes     # LF/CRLF normalization
```

### Skills — mine

| Skill | Purpose |
|---|---|
| `bird-skill` | X (Twitter) integration |
| `find-logo` | Fetch brand logos as transparent SVG/PNG |
| `google-workspace` | Google Workspace via gog CLI |
| `merge-worktrees` | Consolidate finished git worktrees into main |
| `motion-physics` | Gesture-driven UI motion (drag, snap points, velocity) |
| `notion-importer` | Import content into Notion |
| `notion-task-queue` | Notion-backed task queue with trajectory injection |
| `prototype` | Playground setup for comparing versions of an idea |
| `research` | Evidence-based research workflow (MECE, source quality, confidence) |
| `r3f-shaders` | Three.js / R3F scenes, shaders, post-processing + starter templates |
| `shader-techniques` | Shader technique reference |
| `spec-writer` | In-depth project specification interviewer |
| `update-eagle` | Sync X likes into Eagle library |
| `webgpu-threejs-tsl` | WebGPU Three.js + TSL guide |

### Skills — third-party (mirrored)

| Skill | Source |
|---|---|
| `humanizer` | [blader/humanizer](https://github.com/blader/humanizer) — remove signs of AI writing |

Vendor skills installed on my machines but deliberately **not** tracked here (re-downloadable from
their sources): the eight official GSAP skills, `framer` + `framer-code-components`, and
`playwright-cli`. The sync script knows to leave these alone.

### Agents

| Agent | Purpose |
|---|---|
| `backend-iot-builder` | Backend services, APIs, smart-home / IoT glue code |
| `docs-maintainer` | Keeps project docs in sync with code changes |
| `frontend-react-builder` | React / Next.js UI implementation |
| `fullstack-code-reviewer` | TS/JS full-stack code review |
| `technical-project-manager` | Turns plans/specs into execution roadmaps |

### Commands

| Command | Purpose |
|---|---|
| `/ask-question` | Structured clarifying questions before taking action |

---

## License

MIT
