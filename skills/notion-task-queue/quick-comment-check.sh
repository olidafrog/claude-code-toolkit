#!/bin/bash

NOTION_KEY=$(cat ~/.config/notion/api_key)
PAGE_ID="$1"

echo "Checking page-level comments for: $PAGE_ID"

# Get comments
COMMENTS=$(curl -s "https://api.notion.com/v1/comments?block_id=${PAGE_ID}" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Notion-Version: 2022-06-28")

# Check if there are any results
COUNT=$(echo "$COMMENTS" | jq '.results | length')
echo "Found $COUNT page-level comments"

# Show unprocessed (where latest message is NOT from Nyx)
echo "$COMMENTS" | jq -r '.results[] | 
  select(.discussion_id != null) | 
  {
    discussion_id: .discussion_id,
    text: .rich_text[0].text.content,
    author: (.created_by.id // .created_by.object),
    created: .created_time
  }'
