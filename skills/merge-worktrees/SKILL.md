---
name: merge-worktrees
description: >-
  Use when one or more finished git worktrees need to be consolidated into the
  main branch and cleaned up — e.g. after working on several branches in parallel
  and wanting to merge them all back. Triggered by /merge-worktrees, optionally
  naming specific worktrees or branches to limit the set.
allowed-tools: Bash(git:*) AskUserQuestion
---

# Merge Worktrees

## Overview

Consolidate finished git worktrees into the base branch with a clean linear history,
then remove the merged worktrees and their local branches. Rebase + fast-forward,
one worktree at a time, stopping on any conflict. Uncommitted work in a worktree is
committed first so nothing is lost.

**Core principle:** the base branch (`main`) can only be moved from the primary repo
root, so rebase each branch in its own worktree, then fast-forward `main` from primary.

## When to use

- After reviewing several parallel worktrees and wanting to merge them all into `main`.
- Triggered by `/merge-worktrees` (all eligible worktrees) or
  `/merge-worktrees <name> <name>` (only the named worktrees/branches).

Do NOT use to push, to touch remote branches, or to merge unreviewed work — it stops
on conflicts and leaves remotes alone by design.

## Workflow

### 0. Locate the repo and primary root
Run from anywhere inside the target repo.
```bash
PRIMARY_ROOT="$(cd "$(git rev-parse --git-common-dir)/.." && pwd -P)"
```

### 1. Determine the base branch
```bash
if   git show-ref --verify --quiet refs/heads/main;   then BASE=main
elif git show-ref --verify --quiet refs/heads/master; then BASE=master
fi
```
If neither exists, ask which branch to merge into.

### 2. Enumerate candidate worktrees
Parse `git worktree list --porcelain`. Candidates = every worktree EXCEPT:
- the primary root, and the worktree currently on `$BASE`
- bare or detached-HEAD worktrees (report as skipped — no branch to merge)

If args were given, keep only worktrees whose path basename or branch name matches.

### 3. Pre-flight + single confirmation (the only planned checkpoint)
For each candidate, count its commits and check for uncommitted changes:
```bash
git -C "$WT" rev-list --count "$BASE"..HEAD   # commits ahead of BASE
git -C "$WT" status --short                    # non-empty → has uncommitted work
```
If a worktree has uncommitted work, inspect it and draft a concise commit message:
```bash
git -C "$WT" status --short
git -C "$WT" diff            # unstaged
git -C "$WT" diff --staged   # already staged
```
Confirm `$PRIMARY_ROOT` is on `$BASE` (if it's on another branch but clean, `git -C
"$PRIMARY_ROOT" checkout "$BASE"`; if dirty, stop and report).

Show ONE summary via AskUserQuestion and wait for approval:
- worktrees to merge, in order, with commit counts
- for any worktree with uncommitted work: the **proposed commit message** that will be
  committed first (`git add -A`) — the user can adjust it here
- exactly what will be deleted (each worktree folder + local branch)
- any skipped worktrees (detached/bare) and why

### 4. Execute per worktree, in order (after approval)
```bash
# 4a. Commit any uncommitted work first, in its own worktree (skip if already clean)
git -C "$WT" add -A
git -C "$WT" commit -m "<approved message>"   # add -A respects .gitignore

# 4b. Rebase the branch onto the latest BASE, in its own worktree
git -C "$WT" rebase "$BASE"
#     On conflict: STOP. Report the conflicted files and tell the user to resolve in
#     $WT then re-run /merge-worktrees, or abort: git -C "$WT" rebase --abort
#     NEVER auto-resolve. Already-merged worktrees rebase to a no-op — that's fine.

# 4c. Fast-forward BASE from the primary root
git -C "$PRIMARY_ROOT" merge --ff-only "$BRANCH"

# 4d. Clean up — always from the primary root, never inside the worktree
git -C "$PRIMARY_ROOT" worktree remove "$WT"   # refuses if dirty (safety net)
git -C "$PRIMARY_ROOT" branch -d "$BRANCH"      # -d refuses if unmerged (safety net)
git -C "$PRIMARY_ROOT" worktree prune
```
Then move to the next worktree — its 4b rebase targets the now-advanced `$BASE`.

### 5. Final summary
Report branches merged (with counts), any work that was auto-committed, worktrees
removed, branches deleted, anything skipped, and the new tip:
`git -C "$PRIMARY_ROOT" log --oneline -1`.
Remind: nothing was pushed — run `git push` when ready.

## Safety rules
- Never treat the primary root or the `$BASE` worktree as a candidate.
- Commit uncommitted work before rebasing — never discard it.
- Stop on the first conflict; hand it to the user; never auto-resolve.
- Only `-d` / `worktree remove` (no `-D`, no `--force`) — let git refuse to destroy
  unmerged or dirty work.
- No `git push`; never delete remote branches.

## Resuming after a stop
A conflict stops the run with the already-merged worktrees done and gone. Just re-run
`/merge-worktrees` to continue with the remaining ones.

## Common mistakes
- Trying to fast-forward `$BASE` from inside a feature worktree → git refuses. Always
  ff-merge from `$PRIMARY_ROOT`.
- Deleting a branch before removing its worktree → fails (branch is checked out).
  Order is: remove worktree, then delete branch.
- Committing a detached-HEAD worktree → there's no branch to merge; report and skip it
  instead of committing.
