#!/bin/bash
# Get unprocessed comments on a Notion page (includes inline comments on child blocks)
# Usage: ./get-unprocessed-comments.sh <page-id>
#
# Comprehensive mode: Checks page-level AND all block-level comments
# Optimized for completeness, not speed (async task queue context)
#
# Performance optimizations:
# - Parallel comment fetching: 3 blocks at a time (~3 req/sec, respects Notion rate limit)
# - Skip non-commentable block types (divider, column_list, etc.)

if [ -z "$1" ]; then
  echo "Usage: $0 <page-id>"
  exit 1
fi

PAGE_ID="$1"

NOTION_KEY=$(cat ~/.config/notion/api_key)
NYX_USER_ID="6f1f6737-c929-412b-b5cc-cea3343a1d9b"
NOTION_VERSION="2022-06-28"
REQUEST_DELAY=0.35  # 350ms delay between requests (~3 req/sec, well under Notion's rate limit)
PARALLEL_JOBS=3     # Fetch comments for 3 blocks simultaneously

# Block types that don't support inline comments - skip API calls for these
NON_COMMENTABLE_TYPES="divider table_of_contents breadcrumb column_list column child_page child_database unsupported"

# Temporary file for collecting all comments
TEMP_COMMENTS=$(mktemp)
TEMP_DIR=$(mktemp -d)

# Function to check if a block type supports comments
is_commentable() {
  local BLOCK_TYPE="$1"
  for skip_type in $NON_COMMENTABLE_TYPES; do
    if [ "$BLOCK_TYPE" = "$skip_type" ]; then
      return 1  # Not commentable
    fi
  done
  return 0  # Commentable
}

# Function to get comments for a block (writes to temp file for parallel use)
get_comments_for_block() {
  local BLOCK_ID="$1"
  local OUTPUT_FILE="$2"
  local RESP
  RESP=$(curl -s --max-time 30 "https://api.notion.com/v1/comments?block_id=${BLOCK_ID}" \
    -H "Authorization: Bearer ${NOTION_KEY}" \
    -H "Notion-Version: ${NOTION_VERSION}")
  
  # Check for API errors
  if echo "$RESP" | jq -e '.object == "error"' >/dev/null 2>&1; then
    return
  fi
  
  echo "$RESP" | jq -c '.results[]' 2>/dev/null >> "$OUTPUT_FILE"
}

# Function to fetch comments for a single block (used in parallel execution)
# This is called via xargs with: BLOCK_ID BLOCK_TYPE OUTPUT_FILE
fetch_block_comments() {
  local BLOCK_ID="$1"
  local BLOCK_TYPE="$2"
  local OUTPUT_FILE="$3"
  
  # Skip non-commentable block types
  for skip_type in $NON_COMMENTABLE_TYPES; do
    if [ "$BLOCK_TYPE" = "$skip_type" ]; then
      return 0
    fi
  done
  
  local RESP
  RESP=$(curl -s --max-time 30 "https://api.notion.com/v1/comments?block_id=${BLOCK_ID}" \
    -H "Authorization: Bearer ${NOTION_KEY}" \
    -H "Notion-Version: ${NOTION_VERSION}")
  
  # Check for API errors
  if echo "$RESP" | jq -e '.object == "error"' >/dev/null 2>&1; then
    return
  fi
  
  echo "$RESP" | jq -c '.results[]' 2>/dev/null >> "$OUTPUT_FILE"
}
export -f fetch_block_comments
export NOTION_KEY NOTION_VERSION NON_COMMENTABLE_TYPES

# Function to process comments and check for unprocessed
process_comments() {
  local COMMENTS_FILE="$1"
  
  if [ ! -s "$COMMENTS_FILE" ]; then
    echo "[]"
    return
  fi
  
  COMMENTS_JSON=$(cat "$COMMENTS_FILE" | jq -s '.')
  DISCUSSION_IDS=$(echo "$COMMENTS_JSON" | jq -r '.[].discussion_id' | sort -u | grep -v '^$' | grep -v '^null$')
  
  UNPROCESSED_JSON="[]"
  for DISCUSSION_ID in $DISCUSSION_IDS; do
    LATEST_COMMENT=$(echo "$COMMENTS_JSON" | jq ".[] | select(.discussion_id == \"$DISCUSSION_ID\")" | jq -s 'sort_by(.created_time) | last')
    LATEST_AUTHOR=$(echo "$LATEST_COMMENT" | jq -r '.created_by.id // "Unknown"')
    
    if [ "$LATEST_AUTHOR" != "$NYX_USER_ID" ] && [ "$LATEST_AUTHOR" != "Unknown" ]; then
      # Extract all rich_text content (not just first element) and properly escape for JSON
      COMMENT_TEXT=$(echo "$LATEST_COMMENT" | jq -r '[.rich_text[].plain_text] | join("")' 2>/dev/null || echo "(empty)")
      AUTHOR_ID=$(echo "$LATEST_COMMENT" | jq -r '.created_by.id // "Unknown"')
      CREATED_TIME=$(echo "$LATEST_COMMENT" | jq -r '.created_time // ""')
      
      # Build JSON object properly using jq to ensure correct escaping
      NEW_ITEM=$(jq -n \
        --arg did "$DISCUSSION_ID" \
        --arg txt "$COMMENT_TEXT" \
        --arg aid "$AUTHOR_ID" \
        --arg ct "$CREATED_TIME" \
        '{discussion_id: $did, text: $txt, author_id: $aid, created: $ct}')
      
      # Append to array
      UNPROCESSED_JSON=$(echo "$UNPROCESSED_JSON" | jq --argjson item "$NEW_ITEM" '. + [$item]')
    fi
  done
  
  echo "$UNPROCESSED_JSON"
}

# Step 1: Get page-level comments
get_comments_for_block "$PAGE_ID" "$TEMP_COMMENTS"

# Step 2: Scan all child blocks with parallel comment fetching
# Strategy: Collect blocks in batches, fetch comments for 3 blocks in parallel
# This respects Notion's ~3 req/sec rate limit while being ~3× faster than serial
CURSOR=""
BLOCK_COUNT=0
SKIPPED_COUNT=0

while true; do
  if [ -z "$CURSOR" ]; then
    RESPONSE=$(curl -s --max-time 30 "https://api.notion.com/v1/blocks/${PAGE_ID}/children?page_size=100" \
      -H "Authorization: Bearer ${NOTION_KEY}" \
      -H "Notion-Version: ${NOTION_VERSION}")
  else
    RESPONSE=$(curl -s --max-time 30 "https://api.notion.com/v1/blocks/${PAGE_ID}/children?page_size=100&start_cursor=${CURSOR}" \
      -H "Authorization: Bearer ${NOTION_KEY}" \
      -H "Notion-Version: ${NOTION_VERSION}")
  fi
  
  sleep "$REQUEST_DELAY"  # Rate limit friendly delay
  
  # Check for API errors before parsing
  if echo "$RESPONSE" | jq -e '.object == "error"' >/dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.message // "Unknown API error"')
    echo "Error fetching blocks: $ERROR_MSG" >&2
    break
  fi
  
  # Validate response structure
  if ! echo "$RESPONSE" | jq -e '.results' >/dev/null 2>&1; then
    echo "Invalid API response (no results field)" >&2
    break
  fi
  
  # Extract block IDs and types together
  BLOCKS=$(echo "$RESPONSE" | jq -r '.results[] | "\(.id) \(.type)"')
  HAS_MORE=$(echo "$RESPONSE" | jq -r '.has_more // "false"')
  CURSOR=$(echo "$RESPONSE" | jq -r '.next_cursor // empty')
  
  # Parallel comment fetching: Process blocks in batches of PARALLEL_JOBS
  # Using background jobs with wait to control concurrency
  BATCH_COUNT=0
  while IFS= read -r BLOCK_LINE; do
    [ -z "$BLOCK_LINE" ] && continue
    
    BLOCK_ID=$(echo "$BLOCK_LINE" | awk '{print $1}')
    BLOCK_TYPE=$(echo "$BLOCK_LINE" | awk '{print $2}')
    
    # Skip non-commentable block types
    if ! is_commentable "$BLOCK_TYPE"; then
      SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
      continue
    fi
    
    BLOCK_COUNT=$((BLOCK_COUNT + 1))
    
    # Launch background job to fetch comments for this block
    (
      RESP=$(curl -s --max-time 30 "https://api.notion.com/v1/comments?block_id=${BLOCK_ID}" \
        -H "Authorization: Bearer ${NOTION_KEY}" \
        -H "Notion-Version: ${NOTION_VERSION}")
      
      # Check for API errors
      if echo "$RESP" | jq -e '.object == "error"' >/dev/null 2>&1; then
        exit 0
      fi
      
      # Write results to temp file (use flock for thread-safe writes)
      echo "$RESP" | jq -c '.results[]' 2>/dev/null | flock "$TEMP_COMMENTS" -c "cat >> $TEMP_COMMENTS"
    ) &
    
    BATCH_COUNT=$((BATCH_COUNT + 1))
    
    # Wait for batch to complete before starting next batch
    # This maintains ~3 req/sec rate limit
    if [ "$BATCH_COUNT" -ge "$PARALLEL_JOBS" ]; then
      wait
      sleep "$REQUEST_DELAY"
      BATCH_COUNT=0
    fi
  done <<< "$BLOCKS"
  
  # Wait for any remaining jobs in this page of results
  wait
  
  # Stop if no more pages
  if [ "$HAS_MORE" != "true" ]; then
    break
  fi
done

# Step 3: Process all collected comments (including blocks)
RESULT=$(process_comments "$TEMP_COMMENTS")
rm -f "$TEMP_COMMENTS"
rm -rf "$TEMP_DIR"
echo "$RESULT"
