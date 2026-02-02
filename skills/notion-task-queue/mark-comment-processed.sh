#!/bin/bash
# Mark a Notion comment as processed by replying to it
# Usage: ./mark-comment-processed.sh <discussion-id> "<message>"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <discussion-id> \"<message>\""
  exit 1
fi

DISCUSSION_ID="$1"
MESSAGE="$2"
NOTION_KEY=$(cat ~/.config/notion/api_key)

# Post reply to the discussion
curl -s -X POST "https://api.notion.com/v1/comments" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: 2022-06-28" \
  --data "{
    \"discussion_id\": \"${DISCUSSION_ID}\",
    \"rich_text\": [
      {
        \"type\": \"text\",
        \"text\": {
          \"content\": \"${MESSAGE}\"
        }
      }
    ]
  }" | jq -r '.id // "Error posting comment"'
