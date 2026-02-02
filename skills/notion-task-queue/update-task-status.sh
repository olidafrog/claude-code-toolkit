#!/bin/bash
# Update a Notion task's status
# Usage: ./update-task-status.sh <page-id> <status>
# Valid statuses: Backlog, To do, In Progress, Waiting Review, Done

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <page-id> <status>"
  echo "Valid statuses: Backlog, To do, In Progress, Waiting Review, Done"
  exit 1
fi

PAGE_ID="$1"
STATUS="$2"
NOTION_KEY=$(cat ~/.config/notion/api_key)

# Validate status
case "$STATUS" in
  "Backlog"|"To do"|"In Progress"|"Waiting Review"|"Done")
    ;;
  *)
    echo "Invalid status: $STATUS"
    echo "Valid statuses: Backlog, To do, In Progress, Waiting Review, Done"
    exit 1
    ;;
esac

# Update the page status
RESPONSE=$(curl -s -X PATCH "https://api.notion.com/v1/pages/${PAGE_ID}" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: 2022-06-28" \
  --data "{
    \"properties\": {
      \"Status\": {
        \"select\": {
          \"name\": \"${STATUS}\"
        }
      }
    }
  }")

# Check for errors
if echo "$RESPONSE" | jq -e '.object == "error"' >/dev/null 2>&1; then
  ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // "Unknown error"')
  echo "Error updating status: $ERROR_MSG"
  exit 1
fi

NEW_STATUS=$(echo "$RESPONSE" | jq -r '.properties.Status.select.name // "Unknown"')
echo "Status updated to: $NEW_STATUS"
