#!/bin/bash
# Quick page-level comment check (FAST - no block scanning)
# Usage: ./quick-page-comments.sh <page-id>
#
# This only checks PAGE-LEVEL comments, not inline block comments.
# Use for quick triage; use get-unprocessed-comments.sh for full scan if needed.

if [ -z "$1" ]; then
  echo "Usage: $0 <page-id>"
  exit 1
fi

PAGE_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/logging.sh" 2>/dev/null || true  # Optional logging (may run standalone)
NOTION_KEY=$(cat ~/.config/notion/api_key)
NYX_USER_ID="6f1f6737-c929-412b-b5cc-cea3343a1d9b"

# Fetch page-level comments only (fast, single API call)
COMMENTS=$(curl -s --max-time 10 "https://api.notion.com/v1/comments?block_id=${PAGE_ID}" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Notion-Version: 2022-06-28")

# Check for API errors
if echo "$COMMENTS" | jq -e '.object == "error"' >/dev/null 2>&1; then
  type log_api_error &>/dev/null && log_api_error "comments (page ${PAGE_ID})" "$COMMENTS"
  echo "[]"
  exit 0
fi

# Check if there are any comments
COMMENT_COUNT=$(echo "$COMMENTS" | jq '.results | length')
if [ "$COMMENT_COUNT" -eq 0 ]; then
  echo "[]"
  exit 0
fi

# Process all comments in a single jq call to avoid line-by-line parsing issues
# Group by discussion_id, get the latest comment in each discussion,
# filter for those NOT from Nyx (unprocessed feedback)
echo "$COMMENTS" | jq --arg nyx_id "$NYX_USER_ID" '
  .results
  | group_by(.discussion_id)
  | map(sort_by(.created_time) | last)
  | map(select(.created_by.id != $nyx_id))
  | map({
      discussion_id: .discussion_id,
      text: ([.rich_text[].plain_text] | join("")),
      author_id: .created_by.id,
      created: .created_time
    })
'
