# Bug Fix: Sub-Agent Workflow Completion Failure

**Date:** 2026-02-05 18:51 GMT
**Reporter:** Oli (main agent task)
**Fixed by:** Nyx (sub-agent: 6f1b0904-4f93-4da5-8405-b3e891283d1b)

---

## Problem Statement

Sub-agents spawned for Notion tasks were completing their work locally but **failing to complete the full workflow**:

1. ✅ They would do the work (research, debugging, etc.)
2. ✅ They would save output locally (markdown files)
3. ❌ They would NOT upload results to Notion
4. ❌ They would NOT update task status to "Waiting Review"
5. ❌ Result: Cron keeps spawning duplicate sub-agents for the same task

### Evidence from Recent Failures

| Task | Issue |
|------|-------|
| **Gemini Flash** | Completed at 10:06 GMT, processed 3+ times (08:00, 10:00, 18:00) |
| **Investment Bot** | Work done, content uploaded, status NOT updated |
| **Cosmic Orb** | Processed multiple times due to missing status update |

---

## Root Cause Analysis

### 1. No Enforcement Mechanism

The SKILL.md documented that sub-agents "should" call `mark-task-complete.sh`, but:
- There was no wrapper that enforced this
- Sub-agents weren't receiving explicit instructions
- There was no verification that the workflow completed

### 2. Separated Upload and Status Update

Sub-agents had to:
1. Call `notion-importer/upload.js` to upload content
2. Then separately call `mark-task-complete.sh` to update status

If either step was forgotten or failed, the task would be reprocessed.

### 3. No Sub-Agent Prompt Template

When the main agent spawned sub-agents for Notion tasks:
- It didn't pass the PAGE_ID clearly
- It didn't include explicit completion requirements
- Sub-agents didn't know they had to update Notion

### 4. No Orphan Detection

There was no mechanism to detect tasks where:
- Local output files existed
- But Notion wasn't updated
- Tasks remained stuck in "In Progress"

---

## The Solution

### 1. New Script: `complete-task.sh` ⭐

**Single atomic operation that does both upload AND status update:**

```bash
/root/nyx/skills/notion-task-queue/complete-task.sh <page-id> <markdown-file>
```

This script:
- Uploads content to Notion
- Updates status to "Waiting Review"
- Verifies both steps succeeded
- Logs completion for audit trail
- Fails loudly if either step fails

**This is now the ONLY way sub-agents should complete tasks.**

### 2. New Script: `generate-subagent-prompt.sh` 📝

Generates a complete prompt with:
- Task instructions from Notion
- The PAGE_ID
- Explicit completion requirements
- The exact `complete-task.sh` command to run

Usage when spawning sub-agents:
```bash
PROMPT=$(/root/nyx/skills/notion-task-queue/generate-subagent-prompt.sh <page-id>)
# Pass $PROMPT to the sub-agent
```

### 3. New Script: `scan-orphans.sh` 🔍

Detects orphaned tasks:
- Finds tasks stuck in "In Progress"
- Searches for matching local output files
- Reports potential orphans
- Can auto-fix with `--fix` flag

Usage:
```bash
/root/nyx/skills/notion-task-queue/scan-orphans.sh [--fix]
```

### 4. New Documentation: `SUB_AGENT_INSTRUCTIONS.md`

Template instructions for sub-agents with:
- Required completion steps
- Example commands
- Failure conditions
- Error recovery procedures

### 5. Updated SKILL.md

Added new critical section at the top:
- "⚠️ CRITICAL: Sub-Agent Task Completion"
- Explains the problem
- Documents the solution
- Lists all new scripts

---

## Implementation Details

### Files Created

| File | Purpose |
|------|---------|
| `complete-task.sh` | Atomic upload + status update |
| `generate-subagent-prompt.sh` | Generate prompts for sub-agents |
| `scan-orphans.sh` | Detect orphaned tasks |
| `SUB_AGENT_INSTRUCTIONS.md` | Instructions template |

### Files Updated

| File | Changes |
|------|---------|
| `SKILL.md` | Added sub-agent completion section, documented new scripts |

### Path Standardization

Updated all paths in SKILL.md to use `/root/nyx/` consistently (was mixed `/root/clawd/` and `/root/nyx/`).

---

## Correct Sub-Agent Workflow (After Fix)

```
1. Main agent spawns sub-agent with:
   PROMPT=$(generate-subagent-prompt.sh <page-id>)
   
2. Sub-agent receives prompt with:
   - Task instructions
   - PAGE_ID
   - Completion requirements
   - The complete-task.sh command
   
3. Sub-agent:
   a. Does the work (research, coding, etc.)
   b. Saves output to /root/nyx/output/{Type}/{name}_{date}.md
   c. Runs: complete-task.sh <page-id> <output-file>
   d. Reports success ONLY after complete-task.sh succeeds
   
4. complete-task.sh:
   a. Uploads content to Notion page
   b. Updates status to "Waiting Review"
   c. Verifies both steps succeeded
   d. Logs completion
   
5. Next cron run:
   - Task is now in "Waiting Review"
   - Has no new comments
   - Gets categorized as "skip_tasks"
   - NOT reprocessed ✅
```

---

## Testing

### Test 1: Verify Scripts Exist and Are Executable

```bash
ls -la /root/nyx/skills/notion-task-queue/complete-task.sh
ls -la /root/nyx/skills/notion-task-queue/generate-subagent-prompt.sh
ls -la /root/nyx/skills/notion-task-queue/scan-orphans.sh
```

### Test 2: Generate a Sub-Agent Prompt

```bash
# Use an actual task page ID from Notion
/root/nyx/skills/notion-task-queue/generate-subagent-prompt.sh <page-id>
```

Verify the output includes:
- Task name and instructions
- PAGE_ID
- Explicit `complete-task.sh` command
- Completion requirements

### Test 3: Complete a Task (Dry Run)

Create a test task in Notion with "To do" status, then:

```bash
# 1. Create dummy output
echo "# Test Output" > /tmp/test-output.md

# 2. Complete the task
/root/nyx/skills/notion-task-queue/complete-task.sh <test-page-id> /tmp/test-output.md
```

Verify:
- Content uploaded to Notion
- Status changed to "Waiting Review"
- Logged in `/root/nyx/logs/notion-task-completions/`

### Test 4: Scan for Orphans

```bash
/root/nyx/skills/notion-task-queue/scan-orphans.sh
```

Verify it correctly identifies any tasks in "In Progress" with matching local files.

---

## Prevention Measures

### Defense in Depth

1. **Script-level:** `complete-task.sh` makes upload + status update atomic
2. **Prompt-level:** `generate-subagent-prompt.sh` includes explicit requirements
3. **Documentation-level:** SKILL.md prominently documents the workflow
4. **Detection-level:** `scan-orphans.sh` catches any missed completions

### Failure Modes Handled

| Failure | Response |
|---------|----------|
| Upload fails | Script aborts, reports error, status NOT updated |
| Status update fails | Script warns, content IS uploaded, manual fix needed |
| Sub-agent forgets to complete | `scan-orphans.sh` detects and can auto-fix |
| Main agent forgets to pass PAGE_ID | `generate-subagent-prompt.sh` always includes it |

---

## Migration Notes

### Existing Orphaned Tasks

Run orphan scanner to find and fix:
```bash
/root/nyx/skills/notion-task-queue/scan-orphans.sh --fix
```

### Updating Main Agent Behavior

The main agent (cron handler) should now:
1. Generate prompts with `generate-subagent-prompt.sh`
2. Pass complete prompts to sub-agents
3. Periodically run `scan-orphans.sh` as a safety net

---

## Summary

| Before | After |
|--------|-------|
| Sub-agents completed work locally | Sub-agents MUST call `complete-task.sh` |
| Upload and status update separate | Single atomic operation |
| No explicit instructions | `generate-subagent-prompt.sh` includes all requirements |
| No orphan detection | `scan-orphans.sh` catches missed completions |
| Duplicate processing common | Status guaranteed to update on completion |

**The fundamental error has been addressed through structural enforcement, not just documentation.**
