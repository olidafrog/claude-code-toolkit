#!/bin/bash
# Orchestrate phased research - determines which phase to run next
#
# This script checks the current phase status and outputs:
# - Which phase to run (1, 2, or 3)
# - The prompt for that phase
# - Metadata for spawning the sub-agent
#
# Usage: ./orchestrate-phased-research.sh <page-id>
#
# Output (JSON to stderr, prompt to stdout):
# stderr: {"phase": 1, "task_id": "...", "timeout_seconds": 600, ...}
# stdout: The prompt text for the sub-agent

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <page-id>" >&2
  exit 1
fi

PAGE_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
NOTION_KEY=$(cat ~/.config/notion/api_key)

# Use page ID as task ID (consistent identifier)
TASK_ID="$PAGE_ID"

# Fetch task details from Notion
TASK_DATA=$(curl -s --max-time 15 "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28")

TASK_NAME=$(echo "$TASK_DATA" | jq -r '.properties.Name.title[0].text.content // "Untitled"')
TASK_TYPE=$(echo "$TASK_DATA" | jq -r '.properties.Type.select.name // "Research"')
MODEL_OVERRIDE=$(echo "$TASK_DATA" | jq -r '.properties.Model.select.name // ""')
THINKING_ENABLED=$(echo "$TASK_DATA" | jq -r '.properties.Thinking.checkbox // true')

# Fetch task description
TASK_DESCRIPTION=$(curl -s --max-time 15 "https://api.notion.com/v1/blocks/$PAGE_ID/children?page_size=50" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" | \
  jq -r '.results[] | 
    if .type == "paragraph" then .paragraph.rich_text[].plain_text
    elif .type == "bulleted_list_item" then "• " + .bulleted_list_item.rich_text[].plain_text
    elif .type == "heading_1" then "# " + .heading_1.rich_text[].plain_text
    elif .type == "heading_2" then "## " + .heading_2.rich_text[].plain_text
    elif .type == "heading_3" then "### " + .heading_3.rich_text[].plain_text
    else empty
    end' 2>/dev/null | head -100 || echo "[Task description]")

# Check current phase
PHASE_STATUS=$("$SCRIPT_DIR/check-phase.sh" "$TASK_ID")
CURRENT_PHASE=$(echo "$PHASE_STATUS" | jq -r '.current_phase')
NEXT_PHASE=$(echo "$PHASE_STATUS" | jq -r '.next_phase')

# Determine model (default Opus for research)
if [ -n "$MODEL_OVERRIDE" ] && [ "$MODEL_OVERRIDE" != "null" ]; then
  MODEL="$MODEL_OVERRIDE"
else
  MODEL="opus"
fi

# All phases get 10 minutes (shorter because work is divided)
TIMEOUT_SECONDS=600

# Output metadata to stderr
echo "{\"page_id\":\"${PAGE_ID}\",\"task_id\":\"${TASK_ID}\",\"task_name\":\"${TASK_NAME}\",\"phase\":${NEXT_PHASE},\"total_phases\":3,\"model\":\"${MODEL}\",\"thinking\":${THINKING_ENABLED},\"timeout_seconds\":${TIMEOUT_SECONDS}}" >&2

# Generate appropriate phase prompt
case "$NEXT_PHASE" in
  1)
    "$SCRIPT_DIR/phase1-gather.sh" "$TASK_ID" "$TASK_NAME" "$TASK_DESCRIPTION"
    ;;
  2)
    "$SCRIPT_DIR/phase2-synthesize.sh" "$TASK_ID"
    ;;
  3)
    "$SCRIPT_DIR/phase3-upload.sh" "$TASK_ID" "$PAGE_ID"
    ;;
  "complete")
    echo "# Task Already Complete"
    echo ""
    echo "All 3 phases have been completed for this task."
    echo "Task ID: ${TASK_ID}"
    echo ""
    echo "Nothing to do - task should already be in 'Waiting Review' status."
    ;;
  *)
    echo "ERROR: Unknown phase: $NEXT_PHASE" >&2
    exit 1
    ;;
esac
