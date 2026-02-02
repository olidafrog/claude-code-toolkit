# Changelog - Notion Task Queue

## 2026-02-02 - Critical Bug Fix: Block-Level Comments Being Ignored

### Problem Identified

Block-level (inline) comments were being ignored during task processing, leading to incomplete task execution.

**Example:** When processing "Improvements to Cosmic orb repo", only the top-level comment was actioned. Block-level comments containing important context and details were not read or actioned.

### Root Cause Analysis

The `get-unprocessed-comments.sh` script was working correctly - it WAS returning both page-level and block-level comments. The bug was in the **processing workflow guidance** in SKILL.md.

The issue: SKILL.md told the agent to "iterate through and action EVERY discussion_id" but didn't emphasize that you must **READ ALL COMMENTS TOGETHER FIRST** to understand the complete conversation before taking any action.

**What was happening:**
1. Agent gets comments (page + block level)
2. Agent reads comment 1 → Acts → Replies
3. Agent might miss context from block-level comments
4. Incomplete action taken

**What should happen:**
1. Agent gets comments (page + block level)
2. Agent READS ALL comments together to understand full context
3. Agent decides on action based on COMPLETE picture
4. Agent executes holistic action
5. Agent replies to EACH comment individually

### Solution

Updated SKILL.md with:

1. **New critical section:** "⚠️ CRITICAL: READ ALL COMMENTS FIRST (BEFORE ANY ACTION)"
   - Explains that comments form a conversation
   - Must read the ENTIRE conversation before responding

2. **Updated Processing Pattern:** Changed from sequential process-as-you-go to READ-THEN-ACT pattern:
   - READ PHASE: Read ALL comments completely first
   - ACT PHASE: Decide and act based on complete picture
   - REPLY PHASE: Reply to each comment individually

3. **Added concrete examples:** Showing correct vs incorrect approach

4. **Updated Key Principles:** Added principle #2 emphasizing reading all comments before acting

5. **Updated Anti-Patterns:** Added explicit warning against processing comments one-by-one without reading all first

### Files Changed

| File | Changes |
|------|---------|
| `SKILL.md` | Added READ-THEN-ACT pattern, updated key principles, added anti-pattern |
| `CHANGELOG.md` | This entry |

### Verification

The `get-unprocessed-comments.sh` script was verified to be working correctly:
- ✅ Fetches page-level comments
- ✅ Fetches block-level comments from all child blocks
- ✅ Handles pagination (100+ blocks)
- ✅ Skips non-commentable block types for efficiency

---

## 2026-02-02 - Critical Bug Fixes: Comment Processing & Status Updates

### Problems Identified

Four critical bugs reported from production usage:

1. **Status not updated:** Tasks were actioned but left in 'To do' status instead of moving to 'Waiting Review'

2. **Content overwrite bug:** A 'To do' task with existing comments had its content overwritten. Tasks with comments should be treated as feedback mode, not fresh tasks.

3. **Re-actioning completed work:** Tasks in 'Waiting Review' with no new comments were re-processed. These should be skipped entirely.

4. **Duplicate comment processing:** Comments that were already actioned (had ✅ or ❓ replies) were processed again due to JSON parsing issues.

### Root Causes

1. **No status update script existed** - Workflow relied on manual updates
2. **SKILL.md wasn't explicit enough** - Didn't clearly state that 'To do' tasks with comments = feedback mode
3. **Missing skip logic documentation** - No clear guidance to skip 'Waiting Review' tasks with empty comments
4. **JSON escaping bug** - Comment text wasn't properly escaped, causing parsing issues with special characters

### Solutions

#### 1. Created `update-task-status.sh`

New script to update task status in Notion. Must be called after completing any work.

```bash
./update-task-status.sh <page-id> "Waiting Review"
```

Valid statuses: Backlog, To do, In Progress, Waiting Review, Done

#### 2. Added Mandatory Decision Flow to SKILL.md

New explicit decision tree that MUST be followed for every task:

```
1. Run get-unprocessed-comments.sh FIRST (for ALL tasks)
2. If comments exist → Process comments only (don't overwrite content)
3. If no comments + "Waiting Review" → SKIP TASK
4. If no comments + "To do" → Process as fresh task
5. ALWAYS update status to "Waiting Review" after work
```

#### 3. Fixed JSON Escaping in `get-unprocessed-comments.sh`

**Before:** Comment text was embedded directly in JSON string (broke on quotes/newlines)
```bash
UNPROCESSED+=("{\"text\":\"$COMMENT_TEXT\"...}")  # BROKEN
```

**After:** Uses `jq` to properly escape JSON
```bash
NEW_ITEM=$(jq -n --arg txt "$COMMENT_TEXT" '{text: $txt}')  # CORRECT
```

Also fixed: Now extracts ALL rich_text elements, not just the first one.

#### 4. Updated Key Principles Summary

Added explicit anti-patterns:
- ❌ DON'T process 'to do' without checking comments first
- ❌ DON'T re-process 'Waiting Review' with no new comments
- ❌ DON'T forget to update status after work
- ✅ DO follow the Decision Flow for every task

### Files Changed

| File | Changes |
|------|---------|
| `update-task-status.sh` | **NEW** - Status update automation |
| `get-unprocessed-comments.sh` | Fixed JSON escaping, extract all rich_text |
| `SKILL.md` | Added Decision Flow section, updated Scripts, updated Key Principles |
| `CHANGELOG.md` | This entry |

### Testing

```bash
# Test status update
./update-task-status.sh <page-id> "In Progress"

# Test JSON escaping (comment with quotes/newlines)
./get-unprocessed-comments.sh <page-id>

# Full workflow test
# 1. Create task with comment containing special chars
# 2. Run get-unprocessed-comments.sh
# 3. Verify JSON is valid
# 4. Process and mark comment
# 5. Run update-task-status.sh
# 6. Verify status changed
```

---

## 2026-02-01 - Performance Optimizations

### Problem Identified

Pages with 100+ blocks took 1-2 minutes to scan due to serial API requests with 350ms delays between each.

### Solution

Two optimizations that reduce scan time by ~3× while maintaining reliability:

#### 1. Parallel Block Comment Fetching

**Before:** Serial requests - one block at a time, wait 350ms, next block
**After:** Batch parallel requests - 3 blocks simultaneously, wait, next batch

Implementation:
- Uses bash background jobs with `wait` for controlled concurrency
- Processes 3 blocks in parallel (`PARALLEL_JOBS=3`)
- After each batch completes, waits 350ms before next batch
- Respects Notion's ~3 req/sec rate limit
- Thread-safe file writes using `flock`

#### 2. Skip Non-Commentable Block Types

These block types don't support inline comments - API calls skipped entirely:
- `divider`
- `table_of_contents`
- `breadcrumb`
- `column_list`
- `column`
- `child_page`
- `child_database`
- `unsupported`

Block type is extracted from `/blocks/{id}/children` response (already fetched).

### Performance Impact

**Before:** ~35 seconds per 100 blocks (serial, 350ms × 100)
**After:** ~12 seconds per 100 blocks (parallel batches of 3, minus skipped blocks)

Actual improvement depends on block composition - pages with many dividers/columns benefit more.

### Changes Made

#### `get-unprocessed-comments.sh`
- Added `PARALLEL_JOBS=3` configuration variable
- Added `NON_COMMENTABLE_TYPES` list and `is_commentable()` function
- Rewrote block processing loop to use background jobs with batch waiting
- Extract block type alongside block ID from children response
- Thread-safe writes to temp file using `flock`
- Updated header documentation

---

## 2026-02-01 - API Error Handling Fix

### Problem Identified

Cron job failure: `jq: error (at <stdin>:0): Cannot index array with string "has_more"`

**Root Cause:** The script assumed all Notion API responses would be valid list objects. When the API returned an error (rate limit, auth issue, malformed response), the script tried to parse `.has_more` on a non-list object.

### Solution

Added defensive error handling:

1. ✅ Check for `"object": "error"` in API responses before parsing
2. ✅ Validate response has `.results` field before accessing it
3. ✅ Log error messages to stderr for debugging
4. ✅ Gracefully exit loops on API errors instead of crashing
5. ✅ Added fallback default for `.has_more` (`// "false"`)

### Changes Made

#### `get-unprocessed-comments.sh`
- `get_comments_for_block()`: Skip silently on API errors
- Block pagination loop: Validate response before parsing, break on errors

---

## 2026-02-01 - Comprehensive-Only Comment Scanning

### Problem Identified

The `get-unprocessed-comments.sh` script had two modes (`--quick` and standard), which created an impossible decision:
- **Quick mode**: Only checked page-level comments (fast, ~1 second)
- **Standard mode**: Checked page + blocks (comprehensive, ~1-2 minutes)

**The Dilemma:** You can't know which mode to use without already knowing where the comments are located. This created a risk of missing comments.

**The Bug:** Even in standard mode, the script would exit early if ANY page-level comments were found, skipping all block-level comment checks.

### Solution

**Removed the `--quick` flag entirely** and made the script comprehensive-only:

1. ✅ **Always scans everything**: Page-level AND all child block comments
2. ✅ **No early exits**: Fixed the bug where page-level comments would skip block scanning
3. ✅ **Optimized for reliability**: Completeness > speed (async context)
4. ✅ **Simplified usage**: Single mode, no decision paralysis

### Changes Made

#### `get-unprocessed-comments.sh`
- Removed `--quick` flag and associated logic
- Removed early exit when page-level comments found
- Updated header documentation to reflect comprehensive-only mode
- Simplified usage: `./get-unprocessed-comments.sh <page-id>`

#### `SKILL.md`
- Removed all references to `--quick` mode
- Updated usage examples to single mode
- Simplified performance documentation
- Emphasized comprehensive scanning rationale

### Performance

**Time per task:** ~1-2 minutes for pages with 100+ blocks
- 350ms delay between requests (~3 req/sec)
- Rate-limit friendly (well under Notion's limits)
- Acceptable in async cron context (runs every few hours)

**Token usage:** Minimal
- Script output is compact JSON
- Real token cost is in task processor, not scanner

### Key Principle

**Async workflows optimize for completeness, not speed.**

When you can't predict where data is until you check, and time isn't a constraint, always choose comprehensive scanning over "smart" optimizations that might miss data.

### Testing

Before deploying to cron, verify:
```bash
# Test on a task with known comments
bash get-unprocessed-comments.sh <page-id>

# Should return JSON array of all unprocessed comments (page + blocks)
```

### Migration

**No action required** - existing cron jobs will automatically use the updated script. The `--quick` flag is simply ignored if passed (no breaking changes).
