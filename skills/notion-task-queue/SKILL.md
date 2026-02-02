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

## Status Definitions

| Status | Meaning |
|--------|---------|
| **Backlog** | Items assigned but not yet prioritized for active work |
| **To do** | Ready to be worked on, in priority order |
| **In Progress** | Currently being actively worked on |
| **Waiting Review** | Work completed, awaiting Oli's feedback via comments |
| **Done** | Approved and complete (typically Oli moves items here) |

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

### Rules for Cron Runs

1. **Scan ALL tasks first** - Get the full list of tasks with unprocessed comments before acting
2. **Process comments before new work** - Comment responses are usually quick
3. **Time-box complex work** - If a comment requires significant work (>5 min estimated):
   - Reply with ❓ asking for confirmation, OR
   - Spawn a sub-agent for the complex work, OR
   - Reply with ✅ noting the work is queued
4. **Never skip tasks** - Process all tasks with comments, even if just acknowledging

### Example Cron Flow
```
1. Scan all 6 tasks for comments → Found 3 tasks with comments
2. Task A: 1 simple comment → ✅ Reply immediately
3. Task B: 1 complex comment requiring code changes → ❓ "Shall I proceed with this?" OR spawn sub-agent
4. Task C: 2 comments → ✅ Reply to both
5. All comment-tasks processed → Now handle new work if time permits
```

### What NOT to Do
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

4. **Empty comments + "To do" = Fresh Task** - Execute the task according to its Type.

5. **ALWAYS update status** - When work is done, update status to "Waiting Review":
   ```bash
   /root/clawd/skills/notion-task-queue/update-task-status.sh <page-id> "Waiting Review"
   ```

---

## Item Review Process

This is the core workflow for processing each task:

### 1. Check for Un-actioned Comments

**CRITICAL: Use the `get-unprocessed-comments.sh` script for every task** to get ALL unprocessed comments:

```bash
/root/clawd/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
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
/root/clawd/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
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
/root/clawd/output/{Type}/
```

Examples:
- `/root/clawd/output/Research/` - Research reports
- `/root/clawd/output/Task/` - Task outputs
- `/root/clawd/output/Documentation/` - Documentation files
- `/root/clawd/output/Note/` - Note outputs
- `/root/clawd/output/Idea/` - Idea outputs

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

## Scripts

### `check-queue.sh`

Queries Notion for pending tasks and outputs summary.

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
bash /root/clawd/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
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
bash /root/clawd/skills/notion-task-queue/list-unprocessed-discussions.sh <page-id>
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
bash /root/clawd/skills/notion-task-queue/mark-comment-processed.sh <discussion-id> "✅ Brief summary of action taken"
```

### `update-task-status.sh`

Updates a task's status in Notion. **MUST be called after completing any work.**

**Usage:**
```bash
bash /root/clawd/skills/notion-task-queue/update-task-status.sh <page-id> "Waiting Review"
```

**Valid statuses:** Backlog, To do, In Progress, Waiting Review, Done

**When to use:**
- After processing a fresh "To do" task → Set to "Waiting Review"
- After processing comments on any task → Set to "Waiting Review"
- Starting complex work → Set to "In Progress" (optional, for visibility)

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
bash /root/clawd/skills/notion-task-queue/check-queue.sh
```

### Get Un-actioned Comments
```bash
bash /root/clawd/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
```

### Reply to a Comment
```bash
bash /root/clawd/skills/notion-task-queue/mark-comment-processed.sh <discussion-id> "✅ Summary"
```

### Update Task Status
```bash
bash /root/clawd/skills/notion-task-queue/update-task-status.sh <page-id> "Waiting Review"
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

1. **CHECK COMMENTS FIRST on EVERY task** - Run `get-unprocessed-comments.sh` BEFORE any action, regardless of status
2. **⭐ READ ALL COMMENTS BEFORE ACTING** - Comments form a conversation. Read the ENTIRE conversation (page + block level) BEFORE taking ANY action. Never process comments one-by-one in isolation.
3. **"To do" with comments = Feedback mode** - Don't overwrite content; process comments only
4. **"Waiting Review" with no comments = SKIP** - Task is complete, awaiting Oli's review
5. **ALL comments MUST be processed** - Loop through EVERY discussion_id; never skip or miss any
6. **Reply individually** - Each comment gets its own response (don't bundle)
7. **Track threads separately** - Each discussion_id is an independent conversation
8. **VERIFY before proceeding** - Run `get-unprocessed-comments.sh` AFTER processing; only continue when it returns `[]`
9. **ALWAYS update status** - Use `update-task-status.sh` after completing work → "Waiting Review"
10. **Use markers** - ✅ for complete, ❓ for questions
11. **Let Oli close** - Default to staying in Waiting Review
12. **Segment content** - Use horizontal lines + timestamps between updates
13. **Save locally AND to Notion** - Local files are backup, Notion is primary

### Critical Anti-Patterns to Avoid
❌ **DO NOT:** Process a "to do" task without checking for comments first
❌ **DO NOT:** Re-process a "Waiting Review" task that has no new comments
❌ **DO NOT:** See 2+ discussions → Action only 1 → Move to next task
❌ **DO NOT:** Forget to update task status after completing work
❌ **DO NOT:** Process comments one-by-one without reading ALL of them first (leads to missing context from block-level comments)

✅ **DO:** Check comments → READ ALL comments together → Understand full context → Act → Reply to each → Update status → Verify → Move on

---

## Notes

- The Notion API cannot create database views - set those up manually in the UI
- Resolved comments become invisible to the API (accepted behavior)
- Type values should be read from database, not hardcoded
- Always test changes with manual runs before relying on cron
