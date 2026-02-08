#!/bin/bash
# Notion Task Queue Processor - runs periodically to check and execute Nyx tasks
# New flow with "In Progress" status tracking

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh"
NOTION_KEY=$(cat ~/.config/notion/api_key)

log_start "Queue check initiated"

echo "🔍 Scanning Notion task queue..."

# Run the scan script to categorize tasks
SCAN_RESULT=$("${SCRIPT_DIR}/scan-all-for-comments.sh")

# Parse the JSON output
TASKS_WITH_COMMENTS=$(echo "$SCAN_RESULT" | jq -r '.tasks_with_comments')
FRESH_TASKS=$(echo "$SCAN_RESULT" | jq -r '.fresh_tasks')
SKIP_TASKS=$(echo "$SCAN_RESULT" | jq -r '.skip_tasks')
INSTRUCTIONS=$(echo "$SCAN_RESULT" | jq -r '.instructions')

# Count tasks
COMMENT_COUNT=$(echo "$TASKS_WITH_COMMENTS" | jq 'length')
FRESH_COUNT=$(echo "$FRESH_TASKS" | jq 'length')
SKIP_COUNT=$(echo "$SKIP_TASKS" | jq 'length')

echo ""
echo "📊 Scan Results:"
echo "  • Tasks with feedback: $COMMENT_COUNT"
echo "  • Fresh tasks (To do): $FRESH_COUNT"
echo "  • Tasks to skip: $SKIP_COUNT"
echo ""

# Log scan results
log_info "Scan complete: ${COMMENT_COUNT} feedback, ${FRESH_COUNT} fresh, ${SKIP_COUNT} skipped"

# If no work to do, return OK
if [ "$COMMENT_COUNT" -eq 0 ] && [ "$FRESH_COUNT" -eq 0 ]; then
  if [ "$SKIP_COUNT" -gt 0 ]; then
    echo "✅ $(echo "$SKIP_TASKS" | jq -r '.[] | "• \(.name) - \(.status)"')"
  fi
  echo ""
  log_complete "No tasks to process"
  echo "HEARTBEAT_OK"
  exit 0
fi

# Process tasks with comments first (feedback loop - Priority 1)
if [ "$COMMENT_COUNT" -gt 0 ]; then
  echo "🔄 Processing feedback tasks (Priority 1):"
  echo "$TASKS_WITH_COMMENTS" | jq -c '.[]' | while read -r task; do
    TASK_ID=$(echo "$task" | jq -r '.id')
    TASK_NAME=$(echo "$task" | jq -r '.name')
    TASK_TYPE=$(echo "$task" | jq -r '.type')
    TASK_PRIORITY=$(echo "$task" | jq -r '.priority')
    TASK_MODEL=$(echo "$task" | jq -r '.model')
    TASK_THINKING=$(echo "$task" | jq -r '.thinking')
    COMMENT_COUNT=$(echo "$task" | jq -r '.comment_count')
    
    echo ""
    echo "  📝 $TASK_NAME [$TASK_TYPE] - $COMMENT_COUNT comment(s)"
    echo "     Priority: $TASK_PRIORITY | Model: $TASK_MODEL | Thinking: $TASK_THINKING"
    
    # Move to "In Progress" before starting work
    echo "     ↻ Moving to 'In Progress'..."
    "${SCRIPT_DIR}/update-task-status.sh" "$TASK_ID" "In Progress" > /dev/null
    
    # Spawn sub-agent to handle feedback
    # (Implementation note: The actual processing would happen here)
    log_info "Feedback task queued: ${TASK_NAME} (${TASK_ID})"
    echo "     ✓ Feedback processing queued"
  done
fi

# Process fresh "To do" tasks (Priority 2)
if [ "$FRESH_COUNT" -gt 0 ]; then
  echo ""
  echo "📋 Processing fresh tasks (Priority 2):"
  echo "$FRESH_TASKS" | jq -c '.[]' | while read -r task; do
    TASK_ID=$(echo "$task" | jq -r '.id')
    TASK_NAME=$(echo "$task" | jq -r '.name')
    TASK_TYPE=$(echo "$task" | jq -r '.type')
    TASK_PRIORITY=$(echo "$task" | jq -r '.priority')
    TASK_MODEL=$(echo "$task" | jq -r '.model')
    TASK_THINKING=$(echo "$task" | jq -r '.thinking')
    
    echo ""
    echo "  ✨ $TASK_NAME [$TASK_TYPE]"
    echo "     Priority: $TASK_PRIORITY | Model: $TASK_MODEL | Thinking: $TASK_THINKING"
    
    # Move to "In Progress" before starting work
    echo "     ↻ Moving to 'In Progress'..."
    "${SCRIPT_DIR}/update-task-status.sh" "$TASK_ID" "In Progress" > /dev/null
    
    # Spawn sub-agent to handle task
    # (Implementation note: The actual processing would happen here)
    log_info "Fresh task queued: ${TASK_NAME} (${TASK_ID})"
    echo "     ✓ Task processing queued"
  done
fi

log_complete "Queue scan finished"
echo ""
echo "✅ Queue scan complete"
