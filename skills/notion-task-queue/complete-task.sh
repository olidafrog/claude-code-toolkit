#!/bin/bash
# MANDATORY: Use this script to complete ANY Notion task with output
#
# This script ensures the FULL workflow is completed:
# 1. Upload content to the Notion page
# 2. Update task status to "Waiting Review"
# 3. Verify both steps succeeded
#
# Usage: ./complete-task.sh <page-id> <markdown-file> [--replace]
#
# Example:
#   ./complete-task.sh abc123 /tmp/research-report.md
#   ./complete-task.sh abc123 /tmp/findings.md --replace
#
# IMPORTANT: This is the ONLY way to properly complete a task!
# DO NOT manually call upload.js and update-task-status.sh separately.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTION_IMPORTER_DIR="${SCRIPT_DIR}/../notion-importer"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "❌ Error: Missing required arguments"
  echo ""
  echo "Usage: $0 <page-id> <markdown-file> [--replace]"
  echo ""
  echo "Arguments:"
  echo "  <page-id>       The Notion task page ID"
  echo "  <markdown-file> Path to the markdown file with task output"
  echo "  --replace       (Optional) Replace existing page content"
  echo ""
  echo "Example:"
  echo "  $0 2f6e334e-6d5f-8060-91f4-ed979d32e712 /tmp/research.md"
  exit 1
fi

PAGE_ID="$1"
MARKDOWN_FILE="$2"
REPLACE_FLAG=""

# Check for --replace flag
if [ "$3" = "--replace" ]; then
  REPLACE_FLAG="--replace"
fi

# Validate markdown file exists
if [ ! -f "$MARKDOWN_FILE" ]; then
  echo "❌ Error: Markdown file not found: $MARKDOWN_FILE"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📤 COMPLETING NOTION TASK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Page ID: $PAGE_ID"
echo "Content: $MARKDOWN_FILE"
echo ""

# Step 1: Upload content to Notion
echo "📝 Step 1/3: Uploading content to Notion..."
UPLOAD_RESULT=$(node "${NOTION_IMPORTER_DIR}/upload.js" "$MARKDOWN_FILE" --page "$PAGE_ID" $REPLACE_FLAG 2>&1) || {
  echo "❌ UPLOAD FAILED!"
  echo "$UPLOAD_RESULT"
  echo ""
  echo "⚠️  Task NOT complete - status NOT updated"
  echo "⚠️  Please fix the upload issue and retry"
  exit 1
}

echo "✅ Content uploaded successfully"
echo "$UPLOAD_RESULT" | grep -E "(blocks|URL)" || true
echo ""

# Step 2: Update task status to "Waiting Review"
echo "📋 Step 2/3: Updating task status to 'Waiting Review'..."
STATUS_RESULT=$("${SCRIPT_DIR}/update-task-status.sh" "$PAGE_ID" "Waiting Review" 2>&1) || {
  echo "⚠️  WARNING: Status update failed!"
  echo "$STATUS_RESULT"
  echo ""
  echo "⚠️  Content WAS uploaded, but status is NOT updated"
  echo "⚠️  Please manually run:"
  echo "    ${SCRIPT_DIR}/update-task-status.sh $PAGE_ID \"Waiting Review\""
  exit 1
}

echo "✅ Status updated to 'Waiting Review'"
echo ""

# Step 3: Verify completion
echo "🔍 Step 3/3: Verifying task completion..."
NOTION_KEY=$(cat ~/.config/notion/api_key)
VERIFY=$(curl -s --max-time 10 "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" | jq -r '.properties.Status.select.name // "Unknown"')

if [ "$VERIFY" = "Waiting Review" ]; then
  echo "✅ Verified: Task is now in 'Waiting Review' status"
else
  echo "⚠️  Warning: Status verification returned '$VERIFY' (expected 'Waiting Review')"
  echo "⚠️  Please verify manually in Notion"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ TASK COMPLETED SUCCESSFULLY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "• Content uploaded to Notion"
echo "• Status set to 'Waiting Review'"
echo "• Ready for Oli's review"
echo ""

# Log completion for audit trail
LOG_DIR="/root/nyx/logs/notion-task-completions"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y-%m-%d).log"
echo "[$(date -Iseconds)] COMPLETED: Page=$PAGE_ID File=$MARKDOWN_FILE" >> "$LOG_FILE"
