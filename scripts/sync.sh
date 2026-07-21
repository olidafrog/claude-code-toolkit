#!/usr/bin/env bash
#
# sync.sh — keep this machine's ~/.claude/ in sync with the claude-code-toolkit repo.
#
# What it does (idempotent, safe to run any time):
#   1. git pull --rebase --autostash   (best-effort; warns and continues if offline/conflicted)
#   2. Symlink every tracked skill / agent / command / global file into ~/.claude/,
#      backing up any real file it would replace (never deletes).
#   3. Report anything real in ~/.claude/{skills,agents,commands} that ISN'T in the repo.
#   4. Show git status. With `--push "message"` it also commits & pushes.
#
# Usage:
#   scripts/sync.sh                    # pull + link + report + status
#   scripts/sync.sh --push "message"   # ...then commit all changes and push
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
MACHINE_SRC="machine-mac.md"            # this machine imports the Mac tooling notes
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$CLAUDE_HOME/backups/toolkit-migration-$STAMP"

# Known vendor skills that live in ~/.claude but are deliberately NOT tracked in the repo.
VENDOR_SKILLS="gsap-core gsap-frameworks gsap-performance gsap-plugins gsap-react gsap-scrolltrigger gsap-timeline gsap-utils framer framer-code-components playwright-cli"

PUSH_MSG=""
if [ "${1:-}" = "--push" ]; then PUSH_MSG="${2:-sync: update toolkit}"; fi

say()  { printf '%s\n' "$*"; }
info() { printf '  %s\n' "$*"; }

# link SRC DST — ensure DST is a symlink pointing at SRC. Back up a real DST first.
link() {
  local src="$1" dst="$2" rel
  if [ ! -e "$src" ]; then info "skip (source missing): $src"; return; fi
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$src" ]; then return; fi   # already correct
    rm "$dst"; ln -s "$src" "$dst"; info "relinked  ${dst#$CLAUDE_HOME/}"
    return
  fi
  if [ -e "$dst" ]; then
    rel="${dst#$CLAUDE_HOME/}"
    mkdir -p "$BACKUP/$(dirname "$rel")"
    mv "$dst" "$BACKUP/$rel"; info "backed up ${rel} -> backups/$(basename "$BACKUP")/$rel"
  fi
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"; info "linked    ${dst#$CLAUDE_HOME/}"
}

# ---------------------------------------------------------------- 1. pull
say "==> Pulling latest from origin"
if ! git -C "$REPO" pull --rebase --autostash; then
  say "  ⚠️  git pull failed (offline or conflict) — continuing with local state"
fi

# ---------------------------------------------------------------- 2. link
say "==> Linking repo -> $CLAUDE_HOME"
mkdir -p "$CLAUDE_HOME/skills" "$CLAUDE_HOME/agents" "$CLAUDE_HOME/commands"

for d in "$REPO"/skills/*/;      do link "${d%/}" "$CLAUDE_HOME/skills/$(basename "$d")"; done
for f in "$REPO"/agents/*.md;    do [ -e "$f" ] && link "$f" "$CLAUDE_HOME/agents/$(basename "$f")"; done
for f in "$REPO"/commands/*.md;  do [ -e "$f" ] && link "$f" "$CLAUDE_HOME/commands/$(basename "$f")"; done

link "$REPO/global/CLAUDE.md"             "$CLAUDE_HOME/CLAUDE.md"
link "$REPO/global/$MACHINE_SRC"          "$CLAUDE_HOME/machine.md"
link "$REPO/global/statusline-command.sh" "$CLAUDE_HOME/statusline-command.sh"

# ---------------------------------------------------------------- 3. adoption report
say "==> Local items in ~/.claude not tracked in the repo"
found_untracked=0
for kind in skills agents commands; do
  for path in "$CLAUDE_HOME/$kind"/*; do
    [ -e "$path" ] || continue
    [ -L "$path" ] && continue                       # symlinks are ours
    name="$(basename "$path")"
    if [ "$kind" = "skills" ]; then
      case " $VENDOR_SKILLS " in *" $name "*) continue ;; esac   # known vendor skill — ignore
    fi
    info "$kind/$name  (real, not in repo — move into repo/$kind/ then re-run to link)"
    found_untracked=1
  done
done
[ "$found_untracked" = 0 ] && info "(none — everything is linked)"

# ---------------------------------------------------------------- 4. status / push
say "==> Repo status"
git -C "$REPO" status --short || true

if [ -n "$PUSH_MSG" ]; then
  if [ -n "$(git -C "$REPO" status --porcelain)" ]; then
    say "==> Committing & pushing"
    git -C "$REPO" add -A
    git -C "$REPO" commit -m "$PUSH_MSG"
    git -C "$REPO" push
  else
    say "  nothing to commit"
  fi
else
  say "  (run with --push \"message\" to commit & push these changes)"
fi

say "Done."
