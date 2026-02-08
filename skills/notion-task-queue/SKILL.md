---
name: notion-task-queue
description: Automated task queue processor for Nyx's Notion database. Checks for assigned tasks and processes them based on type with comprehensive feedback loop via comments.
---

# notion-task-queue

Automated workflow to check and process tasks assigned to Nyx in the Notion database.

## Overview

This skill runs on a schedule to:
1. Query tasks assigned to Nyx with Status = To do, In Progress, or Waiting Review (**excludes Backlog** - not ready for action)
2. **Prioritize tasks with un-actioned comments first** (feedback loop takes precedence)
3. Sort remaining tasks by Priority (High → Medium → Low), then Created date
4. Process tasks based on Type (Research/Task/Documentation/Note/Idea)
5. Upload findings/results to task page using Notion blocks
6. **Reply to each comment individually** with ✅ or ❓ markers
7. Move Status appropriately (usually to "Waiting Review")

**Key Feature:** Iterative feedback loop via Notion comments. Each comment is a separate conversation tracked to completion.

---

## ⚠️ CRITICAL: Sub-Agent Task Completion

**THIS IS THE MOST IMPORTANT SECTION FOR SUB-AGENTS**

When a sub-agent is spawned to work on a Notion task, IT MUST COMPLETE THE FULL WORKFLOW:

### The Problem (Why This Exists)

Sub-agents were completing work locally but NOT:
1. Uploading results to Notion
2. Updating task status to "Waiting Review"

This caused the same task to be processed multiple times by the cron.

### The Solution: Use `complete-task.sh`

**EVERY sub-agent MUST call this script when finishing a task:**

```bash
/root/nyx/skills/notion-task-queue/complete-task.sh <page-id> <output-file>
```

This single script:
- ✅ Uploads content to the Notion page
- ✅ Updates status to "Waiting Review"
- ✅ Verifies both steps succeeded
- ✅ Logs the completion

### Sub-Agent Workflow

```
1. Receive task with PAGE_ID
2. Do the work (research, coding, etc.)
3. Save output to /root/nyx/output/{Type}/{name}_{date}.md
4. ⭐ RUN: complete-task.sh <PAGE_ID> <output-file>
5. Report success ONLY after complete-task.sh succeeds
```

### Failure Conditions

A sub-agent HAS FAILED if:
- ❌ It finishes without running `complete-task.sh`
- ❌ It reports success but `complete-task.sh` showed errors
- ❌ The task remains in "In Progress" status

### Related Scripts

| Script | Purpose |
|--------|---------|
| `complete-task.sh` | **USE THIS** - Uploads AND updates status |
| `generate-subagent-prompt.sh` | Generates prompt with completion instructions |
| `scan-orphans.sh` | Detects tasks with local output but missing Notion update |

### For Main Agent: Spawning Sub-Agents

When spawning a sub-agent for a Notion task, use `generate-subagent-prompt.sh`:

```bash
PROMPT=$(/root/nyx/skills/notion-task-queue/generate-subagent-prompt.sh <page-id>)
# Pass $PROMPT to the sub-agent
```

This generates a prompt that includes:
- Task instructions
- The PAGE_ID
- Explicit completion requirements
- The exact `complete-task.sh` command to run

---

## Database Details

- **Database ID**: `5df03450-e009-47eb-9440-1bca190f835c`
- **Data Source ID**: `4d050324-79c8-4543-8a42-dac961761b93`
- **URL**: https://www.notion.so/oliingram/5df03450e00947eb94401bca190f835c

## Properties Used

- **Name** (title): Task name
- **Status** (select): Backlog → To do → In Progress → Waiting Review → Done
- **Type** (select): Task, Research, Documentation, Note, Idea (read dynamically from database)
- **Assignee** (select): Oli, Nyx, Both
- **Priority** (select): High, Medium, Low
- **Model** (select): Sonnet, Opus, Haiku (optional - overrides defaults)
- **Thinking** (checkbox): On/Off toggle (optional - controls extended thinking mode)
- **Tags** (multi-select): Various tags for categorization
- **Project** (relation): Links related tasks to a parent project
- **Due Date** (date): Optional deadline
- **Created** (created_time): Auto-populated
- **Updated** (last_edited_time): Auto-tracked

## Status Definitions & Transitions

| Status | Meaning | When to Use |
|--------|---------|-------------|
| **Backlog** | Items assigned but not yet prioritized for active work | User/agent sets when task created but not ready |
| **To do** | Ready to be worked on, in priority order | User moves here when ready to action |
| **In Progress** | Currently being actively worked on | **AUTO: Agent moves here when work starts** |
| **Waiting Review** | Work completed, awaiting Oli's feedback via comments | **AUTO: Agent moves here when work completes** |
| **Done** | Approved and complete | User moves here after reviewing/approving |

### Status Transition Flow

```
To do  →  [Work starts]  →  In Progress  →  [Work completes]  →  Waiting Review
  ↑                                                                      ↓
  └────────────────────  [Feedback via comment]  ──────────────────────┘
                         [Agent processes feedback]
                         [Moves back to In Progress]
                         [Completes, moves to Waiting Review]
```

**Key Rules:**
1. **When starting ANY work** (sub-agent spawn, research, etc.) → Move to "In Progress"
2. **When work completes** → Move to "Waiting Review"
3. **With feedback comments** → Move to "In Progress", process, then back to "Waiting Review"
4. **"In Progress" without comments** → SKIP (already being worked on elsewhere)
5. **"Waiting Review" without comments** → SKIP (awaiting user feedback)

## Queue Priority Order

When processing the queue, tasks are ordered as follows:

1. **Tasks with un-actioned comments** (any comment without a ✅ or ❓ reply from Nyx)
   - Sorted by: Priority (High → Medium → Low) → Created date
   
2. **Tasks without comments** (or all comments already actioned)
   - Sorted by: Priority (High → Medium → Low) → Created date

This ensures the feedback loop is always prioritized over new work.

---

## Queue Processing Discipline

**CRITICAL: Don't let complex tasks block the queue.**

### Problem to Avoid
A cron run that gets stuck on one complex task (e.g., fixing a bug, building a feature) and never processes comments on other tasks. This breaks the feedback loop.

---

### ⚠️ MANDATORY FIRST STEP: Run the Comment Scanner (TRIAGE)

**EVERY cron run MUST start by running the comment scanner:**

```bash
/root/nyx/skills/notion-task-queue/scan-all-for-comments.sh
```

**This script performs TRIAGE (Phase 1):**
1. Queries ALL pending tasks (To do, In Progress, Waiting Review)
2. Does QUICK page-level comment check (fast, ~1 second per task)
3. Returns a prioritized list with `tasks_with_comments` FIRST
4. Flags tasks that need full scan before processing

**⚠️ IMPORTANT: This is TRIAGE only!**
- The scanner checks PAGE-LEVEL comments for quick categorization
- It does NOT check inline/block-level comments during triage
- BEFORE processing any task, you MUST run the FULL comment scan (see below)

---

### ⚠️ CRITICAL: Full Scan BEFORE Processing (Phase 2)

**After triage identifies tasks needing work, you MUST run a FULL comment scan on EACH task BEFORE taking ANY action:**

```bash
/root/nyx/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
```

**Why this matters:**
- Oli's convention: If inline comments exist, he leaves a top-level comment like "Read the rest of the page before actioning"
- The triage scan only sees page-level comments
- Inline comments on specific sections may contain critical feedback
- **You MUST read ALL comments (page-level AND inline) BEFORE doing any work**

**The Two-Phase Workflow:**

```
PHASE 1: TRIAGE (Fast)
┌─────────────────────────────────────────────────────────────────────┐
│ scan-all-for-comments.sh                                            │
│                                                                      │
│ • Quick page-level comment check (~1 sec/task)                      │
│ • Categorizes tasks: with_comments / fresh / skip                   │
│ • Detects "read the rest" signals in top-level comments             │
│ • OUTPUT: List of tasks needing work                                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
PHASE 2: FULL SCAN (Before Processing Each Task)
┌─────────────────────────────────────────────────────────────────────┐
│ get-unprocessed-comments.sh <page-id>                               │
│                                                                      │
│ • Scans page-level AND all inline block comments                    │
│ • Takes 30-60 seconds per task (acceptable - we're about to work)   │
│ • Returns COMPLETE picture of all feedback                          │
│ • OUTPUT: All unprocessed comments (page + inline)                  │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
PHASE 3: PROCESS (Only After Reading ALL Comments)
┌─────────────────────────────────────────────────────────────────────┐
│ • READ all returned comments carefully                              │
│ • UNDERSTAND the full context (page + inline)                       │
│ • THEN take action based on complete picture                        │
│ • Reply to each comment with ✅ or ❓                                │
└─────────────────────────────────────────────────────────────────────┘
```

**Convention: Top-Level Comment Signals**

Oli may leave a top-level comment containing phrases like:
- "Read the rest of the page before actioning"
- "See inline comments below"
- "Check the page-level comments"

When detected, the triage phase sets `needs_full_scan: true` on that task.

**⚠️ CRITICAL RULE:**
```
NEVER spawn a sub-agent or take action on a task without first running:
get-unprocessed-comments.sh <page-id>

And reading ALL returned comments!
```

---

**Output structure:**
```json
{
  "tasks_with_comments": [...],    // PRIORITY 1: Process feedback loop FIRST
  "fresh_tasks": [...],            // PRIORITY 2: "To do" tasks ready for new work
  "skip_tasks": [...],             // DO NOT PROCESS - awaiting Oli's feedback
  "summary": { "with_comments": 2, "fresh_tasks": 2, "skip_tasks": 2, "total": 6 },
  "instructions": "PROCESS: tasks_with_comments (PRIORITY 1), then fresh_tasks (PRIORITY 2). DO NOT process skip_tasks!"
}
```

**⚠️ CRITICAL: Only process `tasks_with_comments` and `fresh_tasks`!**
- `skip_tasks` contains "In Progress" and "Waiting Review" tasks WITHOUT new comments
- These are awaiting Oli's feedback - DO NOT re-process them!
- The script pre-categorizes tasks so you don't need to filter by status

**DO NOT skip this step.** The check-queue.sh script does NOT check for comments - it only lists tasks by priority. The scanner is the ONLY reliable way to identify tasks with unprocessed comments.

---

### Rules for Cron Runs

1. **Run scan-all-for-comments.sh FIRST** - Get the full list of tasks with unprocessed comments before acting
2. **Process ALL comment-tasks before ANY new work** - Comment responses are usually quick
3. **Time-box complex work** - If a comment requires significant work (>5 min estimated):
   - Reply with ❓ asking for confirmation, OR
   - Spawn a sub-agent for the complex work, OR
   - Reply with ✅ noting the work is queued
4. **Never skip tasks** - Process all tasks with comments, even if just acknowledging

### Example Cron Flow with Status Transitions
```
1. Run scan-all-for-comments.sh → Output:
   - tasks_with_comments: 2 (feedback loop - PRIORITY 1)
   - fresh_tasks: 2 ("To do" ready for work - PRIORITY 2)
   - skip_tasks: 2 ("In Progress"/"Waiting Review" - DO NOT PROCESS!)
   
2. Process ALL tasks_with_comments FIRST (PRIORITY 1):
   
   Task A (Waiting Review → has comment):
     • Move to "In Progress"
     • Read comment: "Can you add more detail about X?"
     • Process feedback, update content
     • Reply with ✅ "Added detailed section on X"
     • Move to "Waiting Review"
   
   Task B (Waiting Review → has complex comment):
     • Move to "In Progress"
     • Read comment: "Please rebuild this with feature Y"
     • Spawn sub-agent with Opus
     • Sub-agent completes work and moves to "Waiting Review"
     • Reply with ✅ "Feature Y implemented, see updated page"
   
3. Process fresh_tasks NEXT (PRIORITY 2):
   
   Task C (To do → Research task):
     • Move to "In Progress"
     • Execute research (spawn sub-agent with Opus)
     • Sub-agent uploads findings to Notion
     • Sub-agent calls mark-task-complete.sh → "Waiting Review"
   
   Task D (To do → Documentation task):
     • Move to "In Progress"
     • Create documentation
     • Upload to Notion
     • Call mark-task-complete.sh → "Waiting Review"
   
4. DO NOT touch skip_tasks:
   - These are "In Progress" (being worked on) or "Waiting Review" (awaiting feedback)
   - Processing them would cause duplicates!
```

### What NOT to Do
❌ Skip running scan-all-for-comments.sh and just process tasks in priority order
❌ Start fixing a complex issue and forget about other tasks
❌ Let one task consume the entire cron session
❌ Skip tasks because you're "in the middle of something"

---

## Item Types

Item types are defined by the **Type** field in the Notion record. Types should be read dynamically from the database rather than hardcoded.

### Task
- Use default model settings unless specified otherwise in Notion
- Execute the task instructions following the Item Review Process
- Output a summary of the task details
- Default model: Sonnet

### Research
- Use the research skill
- Default to Opus model with thinking enabled
- Override if Model/Thinking fields are set differently on Notion
- Upload full research report to Notion using notion-importer skill
- Default model: Opus

### Documentation
- Create guides or document processes/tooling
- Will often be used as reference material
- Upload to Notion using proper block formatting
- Default model: Sonnet

### Note
- Typically for reference/documentation
- Process only if explicitly assigned to Nyx with actionable content
- Otherwise, may be informational only

### Idea
- Typically for capturing thoughts/concepts
- Process only if explicitly assigned to Nyx with actionable content
- Otherwise, may be informational only

---

## ⚠️ MANDATORY: Task Decision Flow (CHECK FIRST)

**BEFORE doing ANYTHING with a task, follow this decision tree:**

```
┌────────────────────────────────────────────────────────────────────────┐
│ STEP 1: Run get-unprocessed-comments.sh <page-id>                     │
│         This applies to ALL tasks (To do, In Progress, Waiting Review) │
└─────────────────────────────┬──────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │ Does the result contain       │
              │ any comments (not empty [])?  │
              └───────┬───────────────┬───────┘
                      │               │
                  YES │               │ NO (empty [])
                      ▼               ▼
        ┌─────────────────────┐   ┌─────────────────────────┐
        │ PROCESS COMMENTS    │   │ What is the task status?│
        │ (regardless of      │   └────┬──────────┬─────────┘
        │  task status)       │        │          │
        │                     │   To do│    Waiting Review
        │ • DO NOT overwrite  │        │    or In Progress
        │   existing content  │        ▼          ▼
        │ • Reply to each     │   ┌─────────┐ ┌─────────────┐
        │   comment with ✅/❓ │   │PROCESS  │ │SKIP TASK    │
        │ • Update status to  │   │NEW TASK │ │(all comments│
        │   "Waiting Review"  │   │• Execute│ │ actioned,   │
        │   after processing  │   │  per    │ │ awaiting    │
        └─────────────────────┘   │  Type   │ │ Oli review) │
                                  │• Add    │ └─────────────┘
                                  │  content│
                                  │• Update │
                                  │  status │
                                  │  to     │
                                  │ "Waiting│
                                  │  Review"│
                                  └─────────┘
```

### Key Rules:

1. **ALWAYS check comments FIRST** - Even for "To do" tasks. A "To do" task with comments is a feedback loop, not a fresh task.

2. **Comments = Feedback Mode** - If there are unprocessed comments (any status), process ONLY the comments. Do NOT execute the task or add new content.

3. **Empty comments + "Waiting Review" = SKIP** - The task is complete, awaiting Oli's review. Don't touch it.

4. **Empty comments + "In Progress" = SKIP** - Work is already in progress (likely by a sub-agent or previous cron run). Don't re-start it! Only process if Oli adds new comments with feedback.

5. **Empty comments + "To do" = Fresh Task** - Execute the task according to its Type.

6. **ALWAYS update status** - When work is done, update status to "Waiting Review":
   ```bash
   /root/nyx/skills/notion-task-queue/update-task-status.sh <page-id> "Waiting Review"
   ```

---

## Item Review Process

This is the core workflow for processing each task:

### 1. Check for Un-actioned Comments

**CRITICAL: Use the `get-unprocessed-comments.sh` script for every task** to get ALL unprocessed comments:

```bash
/root/nyx/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
```

This returns a JSON array of ALL un-actioned comment discussions (both page-level and inline comments on blocks).

**Comprehensive Mode:** The script always scans both page-level AND all block-level comments to ensure nothing is missed. Optimized for completeness, not speed (async context).

A comment is **un-actioned** if Nyx has not replied to it with:
- ✅ (actioned and complete)
- ❓ (follow-up question)

**If there are un-actioned comments:**

#### ⚠️ CRITICAL: READ ALL COMMENTS FIRST (BEFORE ANY ACTION)

**Comments form a CONVERSATION.** You MUST read the ENTIRE conversation before responding, not just the first message.

**The Bug to Avoid:** Processing comments one-by-one as you encounter them, without reading the full context. This leads to:
- Missing important context from later comments
- Taking incomplete action based on partial information
- Misunderstanding the user's actual intent

#### ⚠️ MANDATORY: PROCESS EVERY DISCUSSION (NO EXCEPTIONS)

**LOOP REQUIREMENT:** You MUST iterate through and action EVERY `discussion_id` in the JSON array before proceeding. Do NOT process just one and move on.

**Processing Pattern (READ-THEN-ACT):**
```
1. Run get-unprocessed-comments.sh → Get JSON array
2. Count discussions: N = array.length
3. ⭐ READ PHASE (do this FIRST, before ANY action):
   a. Read ALL N comments/discussions completely
   b. Note which are page-level vs block-level (inline)
   c. Understand the FULL conversation/context
   d. Identify what action is actually being requested
4. ⭐ ACT PHASE (only after reading ALL comments):
   a. Decide on action based on the COMPLETE picture
   b. Execute the holistic action (don't do partial work)
5. ⭐ REPLY PHASE (after action is complete):
   FOR EACH discussion:
   a. Call mark-comment-processed.sh <discussion_id> "✅ Response"
   b. Response should acknowledge what was addressed
   c. Confirm: "Processed discussion X of N"
6. After ALL N processed → Run verification
```

**Example - CORRECT approach:**
```
Comments returned:
  - Page comment: "Create GitHub issues for the features"
  - Block comment on "Feature A": "This is high priority"
  - Block comment on "Feature B": "Include error handling"

⭐ READ ALL FIRST:
  - User wants GitHub issues created
  - Feature A should be high priority
  - Feature B needs error handling included

⭐ ACT based on FULL context:
  - Create issues with correct priorities
  - Include error handling in Feature B issue

⭐ REPLY to each:
  - ✅ Page comment: "Created 4 GitHub issues as requested"
  - ✅ Block comment A: "Marked as high priority in the issue"
  - ✅ Block comment B: "Added error handling requirements"
```

**Example - WRONG approach (the bug):**
```
❌ Read comment 1 → Act → Reply
❌ Read comment 2 → Act → Reply
❌ Missed context from comment 3!
```

**Rules:**
- Process each comment **individually** using its `discussion_id`
- Reply to **each comment separately** (don't bundle responses)
- Keep replies **focused and relevant** to that specific comment
- Chunk information logically; avoid long, sectioned responses

#### ⚠️ VERIFICATION STEP (BLOCKING - MUST PASS)

**After processing ALL comments, IMMEDIATELY run:**
```bash
/root/nyx/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
```

**Gate conditions:**
- If result is `[]` (empty array) → ✅ PASS - may proceed to next task
- If result contains ANY discussions → ❌ FAIL - DO NOT PROCEED
  - You missed comments! Go back and process the remaining discussions
  - Repeat until verification returns `[]`

**This verification is NOT optional. A task is NOT complete until `get-unprocessed-comments.sh` returns `[]`.**

#### Example: Processing Multiple Discussions

```
# Initial check reveals 2 unprocessed discussions:
$ get-unprocessed-comments.sh abc123
[
  {"discussion_id":"2f9e...aea0","text":"Add cost comparison","author_id":"xxx","created":"..."},
  {"discussion_id":"335e...abfd","text":"Include timeline section","author_id":"xxx","created":"..."}
]

# ❌ WRONG: Process just the first one and continue
# ✅ CORRECT: Process BOTH before continuing

# Process discussion 1 of 2:
$ mark-comment-processed.sh "2f9e...aea0" "✅ Added cost comparison table"
# → Confirmed: Processed 1 of 2

# Process discussion 2 of 2:
$ mark-comment-processed.sh "335e...abfd" "✅ Added timeline section with milestones"
# → Confirmed: Processed 2 of 2

# VERIFICATION (mandatory):
$ get-unprocessed-comments.sh abc123
[]
# → Empty array = PASS, may proceed
```

---

### 2. If No Un-actioned Comments

Review the item details (page content):
- Read the task description
- Execute based on Type (see Item Types above)
- Add content to the page following Content Structure rules

### 3. Reply Markers

When replying to comments:

| Marker | Meaning | When to Use |
|--------|---------|-------------|
| **✅** | Actioned and complete | Comment has been fully addressed |
| **❓** | Follow-up question | Need clarification before proceeding |

**Example replies:**
- `✅ Added the cost comparison section as requested`
- `✅ Updated the API documentation with error codes`
- `❓ Should I include deprecated methods in the documentation?`

### 4. Comment Thread Tracking

- Each comment thread is **separate** - track each to completion
- If Nyx was the last to respond, no further action needed
- Oli will either:
  - Resolve the comment (invisible to API afterward)
  - Reply with more feedback (triggers new action)
  - Mark task as Done

### 5. Status Transitions

| From | To | When |
|------|-----|------|
| Backlog | To do | (Manual by Oli) |
| To do | In Progress | Starting work on a task |
| In Progress | Waiting Review | Work completed, awaiting feedback |
| Waiting Review | Done | **Default: Oli moves this manually** |
| Waiting Review | Done | Only if all comments have ✅ AND Oli indicated completion |

**Important:** Default behavior is to stay in "Waiting Review" and skip on future runs if all comments are actioned. Let Oli review and close tasks.

---

## Content Structure

### Adding Content to Task Pages

When adding work output to a Notion page:

1. **Add a horizontal line (`---`) above the user's original task description**
2. **Add your content above that line** (user's query stays at the bottom)
3. **Include a timestamp** at the start of your update

For subsequent updates after actioning feedback:
1. Add another horizontal line between content sections
2. Include timestamp for the new update
3. This creates chronological segmentation of work

**Example structure:**
```
[Your latest update - timestamp]
---
[Previous update - timestamp]
---
[User's original task description]
```

### Timestamps

Use ISO format or human-readable format:
- `2026-01-30 23:30 UTC`
- `Updated: 30 Jan 2026, 11:30pm`

---

## File Organization

### Local Output Directory

All task outputs are stored in:
```
/root/nyx/output/{Type}/
```

Examples:
- `/root/nyx/output/Research/` - Research reports
- `/root/nyx/output/Task/` - Task outputs
- `/root/nyx/output/Documentation/` - Documentation files
- `/root/nyx/output/Note/` - Note outputs
- `/root/nyx/output/Idea/` - Idea outputs

### Directory Automation

When processing a task:
1. Read Type values from the database (one API call, acceptable cost)
2. Create directories for any new types that don't exist
3. This ensures future types are automatically supported

### Filename Convention

Use timestamps for versioning:
```
{task_name}_{YYYY-MM-DD_HHmm}.md
```

Example: `axidraw_cli_research_2026-01-30_2330.md`

### Upload to Notion

All key outputs **must also be uploaded to Notion** using the notion-importer skill:
- Notion is the primary interface for organizing and accessing information
- Local files are backup/indexable repository
- Use Notion blocks for proper formatting

---

## Model Selection

When processing tasks via sub-agents:

### If Model Field is Set
Use the specified model (Sonnet/Opus/Haiku)

### If Model Field is Empty (Smart Defaults)
| Type | Default Model | Rationale |
|------|---------------|-----------|
| Research | Opus | Best reasoning for complex analysis |
| Task | Sonnet | Balanced capability |
| Documentation | Sonnet | Clear writing |
| Note/Idea | Sonnet | General purpose |

### Thinking Mode

| Thinking Field | Behavior |
|----------------|----------|
| Checked (true) | Extended thinking enabled |
| Unchecked (false) | No extended thinking (faster) |
| Empty/null | Default to On |

---

## Timeout Configuration

Sub-agents have timeouts to prevent runaway costs and resource exhaustion. Timeouts vary by task type:

| Type | Timeout | Rationale |
|------|---------|-----------|
| **Research** | **1200 seconds (20 min)** | Research involves multiple web searches, reading documentation, synthesis, and uploading large reports to Notion |
| **Research (Phased)** | **600 seconds (10 min) × 3 phases** | Complex research broken into phases with checkpoints |
| Task | 600 seconds (10 min) | Standard tasks are usually shorter |
| Documentation | 600 seconds (10 min) | Documentation is focused writing |
| Note/Idea | 600 seconds (10 min) | Quick processing |

### Why Research Gets More Time

Research tasks typically involve:
1. Multiple web searches (5-15 seconds each)
2. Reading and processing documentation
3. Synthesis and analysis (Opus model, slower but thorough)
4. Writing comprehensive reports
5. Uploading to Notion via batched API calls (2-3 minutes for large reports)

10 minutes is often insufficient for this workflow, causing incomplete work.

### When Spawning Sub-Agents

```javascript
// Example: Spawning a sub-agent with type-based timeout
const timeout = (taskType === "Research") ? 1200 : 600;

sessions_spawn({
  task: "...",
  model: "opus",  // or as specified
  thinking: "low",
  runTimeoutSeconds: timeout
});
```

**Always check the Type field and set `runTimeoutSeconds` accordingly.**

---

## Phased Research (Advanced)

For complex research tasks that might exceed even 20 minutes, use the **Phased Research** approach.

### Enabling Phased Research

Add a checkbox property called **"Phased Research"** to your Notion database. When checked, the task will use the 3-phase approach instead of a single sub-agent.

### How Phased Research Works

```
┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 1: Gather (10 min timeout)                                    │
│                                                                      │
│ • Understand the research question                                  │
│ • Plan search strategy                                              │
│ • Execute 5-10 web searches                                         │
│ • Collect raw findings                                              │
│                                                                      │
│ OUTPUT: /tmp/nyx-research-phases/{task-id}/phase1.json              │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 2: Synthesize (10 min timeout)                                │
│                                                                      │
│ • Read Phase 1 checkpoint                                           │
│ • Analyze and synthesize findings                                   │
│ • Write comprehensive report                                        │
│                                                                      │
│ OUTPUT: /tmp/nyx-research-phases/{task-id}/phase2.md                │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│ PHASE 3: Upload (10 min timeout)                                    │
│                                                                      │
│ • Read Phase 2 report                                               │
│ • Upload to Notion (batched, handles rate limits)                   │
│ • Save to local archive                                             │
│ • Update status to "Waiting Review"                                 │
│ • Clean up checkpoint files                                         │
│                                                                      │
│ OUTPUT: Task complete, status updated                               │
└─────────────────────────────────────────────────────────────────────┘
```

### Benefits of Phased Research

| Benefit | Description |
|---------|-------------|
| **Crash Recovery** | If Phase 2 fails, Phase 1 data is preserved. Restart from Phase 2. |
| **Progress Visibility** | Status shows exactly where work is |
| **Within Timeouts** | Each phase fits comfortably in 10 minutes |
| **Debuggable** | Checkpoint files can be inspected |
| **Parallelizable** | Can run Phase 1 of Task B while Phase 3 of Task A uploads |

### Checkpoint Files

```
/tmp/nyx-research-phases/
└── {task-id}/
    ├── metadata.json      # Task name, started time
    ├── phase1.json        # Raw research findings
    └── phase2.md          # Complete report (markdown)
```

### Scripts

| Script | Purpose |
|--------|---------|
| `phases/check-phase.sh` | Check current phase status |
| `phases/phase1-gather.sh` | Generate Phase 1 prompt |
| `phases/phase2-synthesize.sh` | Generate Phase 2 prompt |
| `phases/phase3-upload.sh` | Generate Phase 3 prompt |
| `phases/orchestrate-phased-research.sh` | Main orchestrator - determines and generates next phase |

### Using Phased Research

**When processing a Research task with "Phased Research" checked:**

```bash
# Get the next phase prompt and metadata
RESULT=$(/root/nyx/skills/notion-task-queue/phases/orchestrate-phased-research.sh <page-id> 2>&1)

# Extract metadata (JSON on first line of stderr)
METADATA=$(echo "$RESULT" | head -1)
PHASE=$(echo "$METADATA" | jq -r '.phase')
TIMEOUT=$(echo "$METADATA" | jq -r '.timeout_seconds')

# Extract prompt (rest of output)
PROMPT=$(echo "$RESULT" | tail -n +2)

# Spawn sub-agent for this phase
sessions_spawn({
  task: "$PROMPT",
  label: "research-{task-id}-phase{$PHASE}",
  model: "opus",
  thinking: "low",
  runTimeoutSeconds: $TIMEOUT
})
```

### Decision Flow

```
Is "Phased Research" checkbox checked?
    │
    ├─→ YES: Use orchestrate-phased-research.sh
    │        • Detects current phase from checkpoints
    │        • Generates prompt for next phase
    │        • Each phase gets 10 min timeout
    │        • Cron continues phases across runs
    │
    └─→ NO: Use standard single-agent approach
             • generate-subagent-prompt.sh
             • 20 min timeout for Research
             • Single sub-agent does all work
```

### Crash Recovery

If a phase fails or times out:
1. Next cron run detects incomplete phase via checkpoint files
2. Resumes from that phase (doesn't restart from beginning)
3. Phase 1 failure: Restart Phase 1 (no checkpoint yet)
4. Phase 2 failure: Re-read Phase 1 checkpoint, retry Phase 2
5. Phase 3 failure: Re-read Phase 2 report, retry upload

---

## Scripts

### `scan-all-for-comments.sh` ⚠️ MANDATORY FIRST STEP

**Run this FIRST at the start of every cron run.** Scans ALL pending tasks to identify which ones have unprocessed comments.

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/scan-all-for-comments.sh
```

**Output:** JSON object with two arrays:
- `tasks_with_comments` - Process these FIRST (feedback loop priority)
- `tasks_without_comments` - Process these AFTER all comments are done

**Example output:**
```json
{
  "tasks_with_comments": [
    {"id": "abc123", "name": "Task A", "comment_count": 2, "comments": [...]}
  ],
  "tasks_without_comments": [
    {"id": "def456", "name": "Task B", "comment_count": 0, "comments": []}
  ],
  "summary": {"with_comments": 1, "without_comments": 1, "total": 2}
}
```

**Why this exists:**
- `check-queue.sh` only lists tasks by priority - it does NOT check for comments
- Without this scanner, tasks with unprocessed comments can be missed if the cron gets blocked on a complex task
- This script ensures the feedback loop is NEVER broken

**Time:** 1-5 minutes depending on task count (scans each task comprehensively)

### `check-queue.sh`

Queries Notion for pending tasks and outputs summary. **Does NOT check for comments** - use `scan-all-for-comments.sh` for that.

**Behavior:**
1. Queries tasks assigned to Nyx with Status = Backlog, To do, In Progress, or Waiting Review
2. Sorts by Priority, then Created date
3. Returns `HEARTBEAT_OK` if queue is empty
4. Otherwise, outputs task list

### `get-unprocessed-comments.sh`

Gets comments that haven't been replied to by Nyx.

**Supports:**
- Page-level comments (attached to page ID)
- Inline comments (attached to child blocks within the page)

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
```

**Returns:** JSON array of un-actioned comments (discussions where latest comment is not from Nyx)

**Behavior:**
- **Comprehensive mode (only mode):** Always checks BOTH page-level AND all child block comments
- Rate-limit friendly: 350ms delay between requests (~3 req/sec, well under Notion's limit)
- Time: ~1-2 minutes for pages with 100+ blocks (acceptable in async task queue context)
- Optimized for completeness, not speed - ensures zero missed comments

**Why comprehensive-only:**
- Cannot predict whether comments are page-level or block-level without checking
- Missing comments breaks the feedback loop
- Async execution means time is not a constraint
- Reliability > speed for this workflow

### `list-unprocessed-discussions.sh`

Human-readable wrapper around `get-unprocessed-comments.sh` that displays unprocessed discussions in a clear format.

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/list-unprocessed-discussions.sh <page-id>
```

**Output:**
```
⚠️  Found 2 unprocessed discussion(s):

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Discussion ID: abc123...
Created: 2026-01-31T14:34:00.000Z
Author ID: 3f916319...
Comment Text:
Can you create a new task for this?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚡ Action required: Reply to ALL 2 discussion(s) before completing this task
```

**When to use:** Before and after processing a task to ensure no comments are missed.

### `mark-comment-processed.sh`

Replies to a comment to mark it as actioned.

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/mark-comment-processed.sh <discussion-id> "✅ Brief summary of action taken"
```

### `update-task-status.sh` 

Updates a task's status in Notion.

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/update-task-status.sh <page-id> "<status>"
```

**Valid statuses:** Backlog, To do, In Progress, Waiting Review, Done

**Status Transition Rules:**
- **When starting work** → Move to "In Progress"
- **When completing work** → Move to "Waiting Review" (or use mark-task-complete.sh)
- **With new feedback** → Move to "In Progress", process, then back to "Waiting Review"

### `mark-task-complete.sh` ✅ NEW

Convenience script that marks a task as complete by moving it to "Waiting Review" status.

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/mark-task-complete.sh <page-id> ["Completion message"]
```

**When to use:** After finishing work on a task (research, development, documentation, etc.)

**What it does:**
1. Moves task status to "Waiting Review"
2. Optionally logs completion message

**Example:**
```bash
bash /root/nyx/skills/notion-task-queue/mark-task-complete.sh abc123 "Research complete, 3 key findings uploaded"
```

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/update-task-status.sh <page-id> "Waiting Review"
```

**Valid statuses:** Backlog, To do, In Progress, Waiting Review, Done

**When to use:**
- After processing a fresh "To do" task → Set to "Waiting Review"
- After processing comments on any task → Set to "Waiting Review"
- Starting complex work → Set to "In Progress" (optional, for visibility)

### `complete-task.sh` ⭐ MANDATORY FOR SUB-AGENTS

**THE script that sub-agents MUST use to finish tasks.** Uploads content AND updates status in one atomic operation.

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/complete-task.sh <page-id> <markdown-file> [--replace]
```

**What it does:**
1. Uploads markdown content to the Notion page
2. Updates task status to "Waiting Review"
3. Verifies both steps succeeded
4. Logs the completion for audit trail

**Example:**
```bash
bash /root/nyx/skills/notion-task-queue/complete-task.sh \
  "2f6e334e-6d5f-8060-91f4-ed979d32e712" \
  "/root/nyx/output/Research/gemini-flash_2026-02-05.md"
```

**Why this exists:** Sub-agents were completing work but NOT uploading to Notion or updating status, causing duplicate processing.

### `generate-subagent-prompt.sh` 📝 NEW

Generates a complete prompt for spawning a sub-agent with all necessary context and completion requirements.

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/generate-subagent-prompt.sh <page-id>
```

**What it does:**
1. Fetches task details from Notion (name, type, priority, content)
2. Generates explicit completion requirements
3. Includes the exact `complete-task.sh` command to run
4. Outputs a ready-to-use prompt for the sub-agent

**When to use:** Before spawning a sub-agent for a Notion task.

### `scan-orphans.sh` 🔍 NEW

Detects tasks with local output files but stuck in "In Progress" status (orphaned tasks).

**Usage:**
```bash
bash /root/nyx/skills/notion-task-queue/scan-orphans.sh [--fix]
```

**What it does:**
1. Finds all tasks in "In Progress" status
2. Searches `/root/nyx/output/` for matching output files
3. Reports potential orphans (work done locally but not completed in Notion)
4. With `--fix`: Attempts to complete orphaned tasks by uploading to Notion

**When to use:**
- After a cron run to verify no tasks were left incomplete
- To recover from sub-agent failures
- As a periodic cleanup mechanism

---

## Comment Handling (API Details)

### Reading Comments

```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
PAGE_ID="<page-id>"

# Get all comments on the page
curl -s "https://api.notion.com/v1/comments?block_id=${PAGE_ID}" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Notion-Version: 2022-06-28"
```

### Replying to Comments

```bash
curl -s -X POST "https://api.notion.com/v1/comments" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: 2022-06-28" \
  --data '{
    "discussion_id": "<discussion-id>",
    "rich_text": [{
      "type": "text",
      "text": { "content": "✅ Your reply here" }
    }]
  }'
```

### API Limitations

- **Resolved comments are invisible** to the API - once Oli resolves a comment, it cannot be retrieved
- **Cannot create new inline discussions** via API - can only reply to existing threads
- Replying to existing comment threads is sufficient for the workflow

---

## Workflow Diagram

```
┌─────────────┐
│   Backlog   │  Items assigned but not prioritized
└──────┬──────┘
       │ (Oli prioritizes)
       ▼
┌─────────────┐
│   To do     │  Ready for Nyx to work on
└──────┬──────┘
       │ (Nyx picks up)
       ▼
┌─────────────┐
│ In Progress │  Actively being worked on
└──────┬──────┘
       │ (Work complete)
       ▼
┌─────────────────────┐
│  Waiting Review     │◀─────────────────────┐
└──────┬──────────────┘                      │
       │                                      │
       │ Oli adds comments                    │
       ▼                                      │
┌─────────────────────┐                      │
│ Process Comments    │  (Each individually)  │
│ Reply with ✅ or ❓ │──────────────────────┘
└──────┬──────────────┘     (More feedback)
       │
       │ Oli satisfied / moves manually
       ▼
┌─────────────┐
│    Done     │
└─────────────┘
```

---

## Cron Schedule

**Runs 5 times daily:**
- **07:00** - Morning check
- **12:00** - Midday check
- **16:00** - Afternoon check
- **19:00** - Evening check
- **22:00** - Late evening check

Cron expression: `0 7,12,16,19,22 * * *`

---

## Manual Usage

### Check the Queue
```bash
bash /root/nyx/skills/notion-task-queue/check-queue.sh
```

### Get Un-actioned Comments
```bash
bash /root/nyx/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
```

### Reply to a Comment
```bash
bash /root/nyx/skills/notion-task-queue/mark-comment-processed.sh <discussion-id> "✅ Summary"
```

### Update Task Status
```bash
bash /root/nyx/skills/notion-task-queue/update-task-status.sh <page-id> "Waiting Review"
```

---

## Configuration

### Change Timing
```bash
clawdbot cron list  # find job ID
clawdbot cron update <job-id> --schedule "0 10,19 * * *"
```

### Change Query Filters
Edit `check-queue.sh`:
- Lines for Assignee and Status filters
- Sort order (Priority, Created)

---

## Key Principles Summary

1. **⭐ RUN COMMENT SCANNER FIRST** - Every cron run MUST start with `scan-all-for-comments.sh` to identify ALL tasks with unprocessed comments BEFORE any processing
2. **PROCESS ALL COMMENT-TASKS BEFORE NEW WORK** - The feedback loop is sacred. Process every task in `tasks_with_comments` before touching any fresh "To do" tasks
3. **CHECK COMMENTS FIRST on EVERY task** - Run `get-unprocessed-comments.sh` BEFORE any action, regardless of status
4. **⭐ READ ALL COMMENTS BEFORE ACTING** - Comments form a conversation. Read the ENTIRE conversation (page + block level) BEFORE taking ANY action. Never process comments one-by-one in isolation.
5. **"To do" with comments = Feedback mode** - Don't overwrite content; process comments only
6. **"Waiting Review" with no comments = SKIP** - Task is complete, awaiting Oli's review
7. **ALL comments MUST be processed** - Loop through EVERY discussion_id; never skip or miss any
8. **Reply individually** - Each comment gets its own response (don't bundle)
9. **Track threads separately** - Each discussion_id is an independent conversation
10. **VERIFY before proceeding** - Run `get-unprocessed-comments.sh` AFTER processing; only continue when it returns `[]`
11. **ALWAYS update status** - Use `update-task-status.sh` after completing work → "Waiting Review"
12. **Use markers** - ✅ for complete, ❓ for questions
13. **Let Oli close** - Default to staying in Waiting Review
14. **Segment content** - Use horizontal lines + timestamps between updates
15. **Save locally AND to Notion** - Local files are backup, Notion is primary

### Critical Status Transition Rules
✅ **DO:** Move task to "In Progress" BEFORE starting any work (research, coding, writing, etc.)
✅ **DO:** Move task to "Waiting Review" AFTER completing work (use mark-task-complete.sh)
✅ **DO:** Move feedback tasks from "Waiting Review" → "In Progress" → back to "Waiting Review"
✅ **DO:** Let sub-agents call mark-task-complete.sh when their work is done

### Critical Anti-Patterns to Avoid
❌ **DO NOT:** Skip running `scan-all-for-comments.sh` at the start of a cron run
❌ **DO NOT:** Process tasks in priority order without checking for comments first across ALL tasks
❌ **DO NOT:** Let a complex task block the queue - spawn sub-agents or reply with ❓
❌ **DO NOT:** Process a "to do" task without checking for comments first
❌ **DO NOT:** Re-process a "Waiting Review" task that has no new comments
❌ **DO NOT:** Re-process an "In Progress" task that has no new comments (it's already being worked on!)
❌ **DO NOT:** Forget to update status after completing work - always move to "Waiting Review"
❌ **DO NOT:** Leave tasks stuck in "In Progress" - they MUST move to "Waiting Review" when done
❌ **DO NOT:** Process anything from `skip_tasks` - only process `tasks_with_comments` and `fresh_tasks`!
❌ **DO NOT:** See 2+ discussions → Action only 1 → Move to next task
❌ **DO NOT:** Forget to update task status after completing work
❌ **DO NOT:** Process comments one-by-one without reading ALL of them first (leads to missing context from block-level comments)

✅ **DO:** Run scanner → Process `tasks_with_comments` (PRIORITY 1) → Process `fresh_tasks` (PRIORITY 2) → SKIP `skip_tasks` entirely → READ ALL comments together → Understand full context → Act → Reply to each → Update status → Verify → Move on

---

## Notes

- The Notion API cannot create database views - set those up manually in the UI
- Resolved comments become invisible to the API (accepted behavior)
- Type values should be read from database, not hardcoded
- Always test changes with manual runs before relying on cron
