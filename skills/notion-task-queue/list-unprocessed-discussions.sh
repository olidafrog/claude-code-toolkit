#!/bin/bash
# List all unprocessed discussion threads for a Notion page in human-readable format
# Usage: ./list-unprocessed-discussions.sh <page-id>

if [ -z "$1" ]; then
  echo "Usage: $0 <page-id>"
  exit 1
fi

PAGE_ID="$1"

# Get unprocessed comments as JSON
UNPROCESSED=$(/root/clawd/skills/notion-task-queue/get-unprocessed-comments.sh "$PAGE_ID")

# Count them (handle empty/null safely)
COUNT=$(echo "$UNPROCESSED" | jq -r 'if . == null then 0 else length end')

if [ "$COUNT" -eq 0 ]; then
  echo "✅ No unprocessed comments - all discussions have been actioned"
  exit 0
fi

echo "⚠️  Found $COUNT unprocessed discussion(s):"
echo ""

# List each one with details and explicit numbering
echo "$UNPROCESSED" | jq -r --argjson total "$COUNT" 'to_entries[] | 
  "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n" +
  "📌 DISCUSSION \(.key + 1) of \($total)\n" +
  "Discussion ID: \(.value.discussion_id)\n" +
  "Created: \(.value.created)\n" +
  "Author ID: \(.value.author_id)\n" +
  "Comment Text:\n\(.value.text)\n"'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  MANDATORY: Process ALL $COUNT discussion(s)"
echo "⚡ After processing, verify with: get-unprocessed-comments.sh $PAGE_ID"
echo "✅ Only proceed when verification returns []"
