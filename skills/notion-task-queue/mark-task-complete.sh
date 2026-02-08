#!/bin/bash
# Mark a Notion task as complete and move to "Waiting Review"
# Usage: ./mark-task-complete.sh <page-id> [completion-message]

if [ -z "$1" ]; then
  echo "Usage: $0 <page-id> [completion-message]"
  exit 1
fi

PAGE_ID="$1"
COMPLETION_MSG="${2:-Task completed successfully}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "✅ Marking task as complete..."

# Move to "Waiting Review" status
"${SCRIPT_DIR}/update-task-status.sh" "$PAGE_ID" "Waiting Review"

# Optionally add a completion comment (if needed)
# (Could be extended to add a timestamped comment)

echo "✓ Task moved to 'Waiting Review'"
echo "  Message: $COMPLETION_MSG"
