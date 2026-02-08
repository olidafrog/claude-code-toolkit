#!/bin/bash
# Scan for orphaned tasks: Local output exists but Notion wasn't updated
#
# This script identifies tasks that:
# 1. Have local output files in /root/nyx/output/
# 2. Are still in "In Progress" status (should be "Waiting Review")
# 3. Were modified in the last 7 days
#
# Usage: ./scan-orphans.sh [--fix]
#
# Options:
#   --fix    Attempt to complete orphaned tasks by uploading to Notion

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTION_KEY=$(cat ~/.config/notion/api_key)
DATA_SOURCE_ID="4d050324-79c8-4543-8a42-dac961761b93"
OUTPUT_DIR="/root/nyx/output"

FIX_MODE=false
if [ "$1" = "--fix" ]; then
  FIX_MODE=true
fi

echo "🔍 Scanning for orphaned tasks..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Get all tasks currently "In Progress" assigned to Nyx
IN_PROGRESS_TASKS=$(curl -s --max-time 30 -X POST "https://api.notion.com/v1/data_sources/${DATA_SOURCE_ID}/query" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Notion-Version: 2025-09-03" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "and": [
        { "property": "Assignee", "select": { "equals": "Nyx" } },
        { "property": "Status", "select": { "equals": "In Progress" } }
      ]
    }
  }' | jq -c '.results[]' 2>/dev/null || echo "")

if [ -z "$IN_PROGRESS_TASKS" ]; then
  echo "✅ No tasks in 'In Progress' status"
  exit 0
fi

ORPHAN_COUNT=0
FIXED_COUNT=0

echo "$IN_PROGRESS_TASKS" | while read -r task; do
  TASK_ID=$(echo "$task" | jq -r '.id')
  TASK_NAME=$(echo "$task" | jq -r '.properties.Name.title[0].text.content // "Untitled"')
  TASK_TYPE=$(echo "$task" | jq -r '.properties.Type.select.name // "Task"')
  LAST_EDITED=$(echo "$task" | jq -r '.last_edited_time')
  
  # Generate expected filename pattern
  SANITIZED_NAME=$(echo "$TASK_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g')
  
  echo ""
  echo "📋 Checking: $TASK_NAME ($TASK_TYPE)"
  echo "   Page ID: $TASK_ID"
  echo "   Last edited: $LAST_EDITED"
  
  # Search for matching output files
  MATCHING_FILES=$(find "$OUTPUT_DIR" -name "*${SANITIZED_NAME}*" -type f -mtime -7 2>/dev/null || echo "")
  
  if [ -n "$MATCHING_FILES" ]; then
    ORPHAN_COUNT=$((ORPHAN_COUNT + 1))
    echo "   ⚠️  POTENTIAL ORPHAN: Found local output files!"
    echo "$MATCHING_FILES" | while read -r file; do
      echo "      → $file"
    done
    
    if [ "$FIX_MODE" = true ]; then
      # Try to fix by completing the task
      NEWEST_FILE=$(echo "$MATCHING_FILES" | head -1)
      echo "   🔧 Attempting to complete task with: $NEWEST_FILE"
      
      if "${SCRIPT_DIR}/complete-task.sh" "$TASK_ID" "$NEWEST_FILE"; then
        FIXED_COUNT=$((FIXED_COUNT + 1))
        echo "   ✅ Task completed successfully"
      else
        echo "   ❌ Failed to complete task"
      fi
    else
      echo "   💡 Run with --fix to attempt completion"
    fi
  else
    echo "   ✅ No orphaned output files found"
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Orphan Scan Summary"
echo "   Potential orphans: $ORPHAN_COUNT"
if [ "$FIX_MODE" = true ]; then
  echo "   Fixed: $FIXED_COUNT"
fi
echo ""

if [ "$ORPHAN_COUNT" -gt 0 ] && [ "$FIX_MODE" = false ]; then
  echo "💡 Run with --fix to attempt to complete orphaned tasks:"
  echo "   $0 --fix"
fi
