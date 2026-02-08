#!/bin/bash
# Scan ALL pending tasks and identify which ones have unprocessed comments
# This script MUST be run at the start of every cron run to prioritize comment tasks
#
# Output: JSON with properly categorized tasks:
#   - tasks_with_comments: PRIORITY 1 - Process feedback loop first
#   - fresh_tasks: PRIORITY 2 - "To do" tasks ready for new work
#   - skip_tasks: DO NOT PROCESS - "In Progress"/"Waiting Review" without new comments
#
# Usage: ./scan-all-for-comments.sh
#
# Design principle: Comments = feedback loop, must be processed BEFORE any new work
# CRITICAL: Only "To do" tasks without comments should be processed as new work!

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"
NOTION_KEY=$(cat ~/.config/notion/api_key)
DATA_SOURCE_ID="4d050324-79c8-4543-8a42-dac961761b93"

log_start "Full task scan"

# Step 1: Get all pending tasks (To do, In Progress, Waiting Review) assigned to Nyx
TASKS=$(curl -s --max-time 30 -X POST "https://api.notion.com/v1/data_sources/${DATA_SOURCE_ID}/query" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Notion-Version: 2025-09-03" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "and": [
        {
          "property": "Assignee",
          "select": { "equals": "Nyx" }
        },
        {
          "or": [
            { "property": "Status", "select": { "equals": "To do" } },
            { "property": "Status", "select": { "equals": "In Progress" } },
            { "property": "Status", "select": { "equals": "Waiting Review" } }
          ]
        }
      ]
    },
    "sorts": [
      { "property": "Priority", "direction": "ascending" },
      { "property": "Created", "direction": "ascending" }
    ]
  }')

# Check for API errors
if echo "$TASKS" | jq -e '.object == "error"' >/dev/null 2>&1; then
  log_api_error "data_sources query" "$TASKS"
  echo "API_ERROR"
  exit 1
fi

TASK_COUNT=$(echo "$TASKS" | jq -r '.results | length')

if [ "$TASK_COUNT" -eq 0 ]; then
  log_info "Queue empty - no tasks to scan"
  echo "QUEUE_EMPTY"
  exit 0
fi

log_info "Found ${TASK_COUNT} tasks to scan"

echo "Scanning $TASK_COUNT tasks for unprocessed comments..." >&2

# Step 2: For each task, check for unprocessed comments and categorize properly
TASKS_WITH_COMMENTS="[]"
FRESH_TASKS="[]"         # "To do" tasks without comments - ready for new work
SKIP_TASKS="[]"          # "In Progress"/"Waiting Review" without comments - DO NOT PROCESS

# Extract task list
TASK_IDS=$(echo "$TASKS" | jq -r '.results[].id')

for TASK_ID in $TASK_IDS; do
  # Get task name for display
  TASK_NAME=$(echo "$TASKS" | jq -r ".results[] | select(.id == \"$TASK_ID\") | .properties.Name.title[0].text.content // \"Untitled\"")
  TASK_STATUS=$(echo "$TASKS" | jq -r ".results[] | select(.id == \"$TASK_ID\") | .properties.Status.select.name")
  TASK_PRIORITY=$(echo "$TASKS" | jq -r ".results[] | select(.id == \"$TASK_ID\") | .properties.Priority.select.name // \"Low\"")
  TASK_TYPE=$(echo "$TASKS" | jq -r ".results[] | select(.id == \"$TASK_ID\") | .properties.Type.select.name // \"Task\"")
  TASK_PHASED=$(echo "$TASKS" | jq -r ".results[] | select(.id == \"$TASK_ID\") | .properties[\"Phased Research\"].checkbox // false")
  
  echo "  Checking: $TASK_NAME..." >&2
  
  # TRIAGE PHASE: Fast page-level comment check only
  # This is for quick categorization - full scan happens before processing
  COMMENTS=$(timeout 15 "${SCRIPT_DIR}/quick-page-comments.sh" "$TASK_ID" 2>/dev/null)
  TIMEOUT_EXIT=$?
  
  if [ "$TIMEOUT_EXIT" -eq 124 ]; then
    log_timeout "Comment check timed out for task: ${TASK_NAME} (${TASK_ID})"
    echo "    ⚠️ Comment check timed out" >&2
    COMMENTS="[]"
  elif [ -z "$COMMENTS" ]; then
    log_warn "Empty response from comment check for task: ${TASK_NAME} (${TASK_ID})"
    COMMENTS="[]"
  fi
  
  # Validate JSON response
  if ! echo "$COMMENTS" | jq -e 'type == "array"' >/dev/null 2>&1; then
    log_error "Invalid JSON from comment check for task: ${TASK_NAME} (${TASK_ID}) - Response: ${COMMENTS:0:200}"
    echo "    ⚠️ Comment check failed, assuming no comments" >&2
    COMMENTS="[]"
  fi
  
  COMMENT_COUNT=$(echo "$COMMENTS" | jq 'length')
  
  # Check if any comment indicates inline comments exist (e.g., "read the rest of the page")
  # This is Oli's convention to signal that inline comments need attention
  NEEDS_FULL_SCAN=false
  if [ "$COMMENT_COUNT" -gt 0 ]; then
    # Check for keywords that indicate inline comments exist
    INLINE_SIGNAL=$(echo "$COMMENTS" | jq -r '.[].text | ascii_downcase' | grep -iE "(read the rest|inline comment|page.level|block comment|see below|check the page)" || true)
    if [ -n "$INLINE_SIGNAL" ]; then
      NEEDS_FULL_SCAN=true
      echo "    → Top-level comment signals inline comments exist - will do full scan before processing" >&2
    fi
  fi
  
  # Build task object
  TASK_OBJ=$(jq -n \
    --arg id "$TASK_ID" \
    --arg name "$TASK_NAME" \
    --arg status "$TASK_STATUS" \
    --arg priority "$TASK_PRIORITY" \
    --arg type "$TASK_TYPE" \
    --argjson phased_research "$TASK_PHASED" \
    --argjson needs_full_scan "$NEEDS_FULL_SCAN" \
    --argjson comments "$COMMENTS" \
    --argjson comment_count "$COMMENT_COUNT" \
    '{
      id: $id,
      name: $name,
      status: $status,
      priority: $priority,
      type: $type,
      phased_research: $phased_research,
      needs_full_scan: $needs_full_scan,
      comment_count: $comment_count,
      comments: $comments,
      triage_note: (if $needs_full_scan then "Top-level comment indicates inline comments - run full scan before processing" else "Page-level comments only (quick triage)" end)
    }')
  
  if [ "$COMMENT_COUNT" -gt 0 ]; then
    # Has unprocessed comments - PROCESS (feedback loop)
    echo "    → Found $COMMENT_COUNT unprocessed comment(s) ⚠️" >&2
    TASKS_WITH_COMMENTS=$(echo "$TASKS_WITH_COMMENTS" | jq --argjson task "$TASK_OBJ" '. + [$task]')
  elif [ "$TASK_STATUS" = "To do" ]; then
    # No comments AND "To do" status - PROCESS as fresh task
    echo "    → Fresh task ready for work ✨" >&2
    FRESH_TASKS=$(echo "$FRESH_TASKS" | jq --argjson task "$TASK_OBJ" '. + [$task]')
  else
    # No comments AND ("In Progress" or "Waiting Review") - SKIP
    echo "    → Skipping ($TASK_STATUS, no new comments) ⏭️" >&2
    SKIP_TASKS=$(echo "$SKIP_TASKS" | jq --argjson task "$TASK_OBJ" '. + [$task]')
  fi
done

# Step 3: Output summary
COMMENT_TASK_COUNT=$(echo "$TASKS_WITH_COMMENTS" | jq 'length')
FRESH_TASK_COUNT=$(echo "$FRESH_TASKS" | jq 'length')
SKIP_TASK_COUNT=$(echo "$SKIP_TASKS" | jq 'length')

log_complete "Scan finished: ${COMMENT_TASK_COUNT} with comments, ${FRESH_TASK_COUNT} fresh, ${SKIP_TASK_COUNT} skipped"

echo "" >&2
echo "=== SCAN COMPLETE ===" >&2
echo "Tasks with unprocessed comments: $COMMENT_TASK_COUNT" >&2
echo "Fresh 'To do' tasks: $FRESH_TASK_COUNT" >&2
echo "Skipped (no new comments): $SKIP_TASK_COUNT" >&2

if [ "$COMMENT_TASK_COUNT" -gt 0 ]; then
  echo "" >&2
  echo "⚠️  PRIORITY 1: Process these tasks FIRST (feedback loop):" >&2
  echo "$TASKS_WITH_COMMENTS" | jq -r '.[] | "  • \(.name) [\(.status)] - \(.comment_count) comment(s)"' >&2
fi

if [ "$FRESH_TASK_COUNT" -gt 0 ]; then
  echo "" >&2
  echo "✨ PRIORITY 2: Fresh tasks ready for work:" >&2
  echo "$FRESH_TASKS" | jq -r '.[] | "  • \(.name) [To do] - Priority: \(.priority)"' >&2
fi

if [ "$SKIP_TASK_COUNT" -gt 0 ]; then
  echo "" >&2
  echo "⏭️  SKIPPED (awaiting Oli's feedback/review - DO NOT PROCESS):" >&2
  echo "$SKIP_TASKS" | jq -r '.[] | "  • \(.name) [\(.status)] - no new comments"' >&2
fi

# Output the full result as JSON for programmatic use
# CRITICAL: Only process tasks_with_comments and fresh_tasks!
# skip_tasks is informational only - DO NOT process these!
jq -n \
  --argjson with_comments "$TASKS_WITH_COMMENTS" \
  --argjson fresh_tasks "$FRESH_TASKS" \
  --argjson skip_tasks "$SKIP_TASKS" \
  '{
    tasks_with_comments: $with_comments,
    fresh_tasks: $fresh_tasks,
    skip_tasks: $skip_tasks,
    summary: {
      with_comments: ($with_comments | length),
      fresh_tasks: ($fresh_tasks | length),
      skip_tasks: ($skip_tasks | length),
      total: (($with_comments | length) + ($fresh_tasks | length) + ($skip_tasks | length))
    },
    instructions: "PROCESS: tasks_with_comments (PRIORITY 1), then fresh_tasks (PRIORITY 2). DO NOT process skip_tasks!"
  }'
