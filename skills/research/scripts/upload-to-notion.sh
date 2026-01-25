#!/bin/bash
# Upload markdown research reports to Notion with proper formatting

set -euo pipefail

NOTION_KEY="${NOTION_KEY:-$(cat ~/.config/notion/api_key 2>/dev/null || echo '')}"
NOTION_VERSION="2022-06-28"  # Use stable version, NOT 2025-09-03 (has silent failures)
DATABASE_ID=""
MARKDOWN_FILE=""
TITLE=""
TYPE="Notes"
STATUS="Done"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <markdown-file>

Upload markdown research report to Notion database.

OPTIONS:
  -d, --database ID     Notion database ID (required)
  -t, --title TITLE     Page title (defaults to filename or first # heading)
  -T, --type TYPE       Page type property (default: Notes)
  -s, --status STATUS   Page status property (default: Done)
  -k, --key KEY         Notion API key (defaults to ~/.config/notion/api_key)
  -h, --help            Show this help

ENVIRONMENT:
  NOTION_KEY            Notion API key (alternative to --key)

EXAMPLES:
  # Upload with auto-detected title
  $(basename "$0") -d 86e5cd15bff042cd9db8444d23a1e9a8 report.md
  
  # Upload with custom title
  $(basename "$0") -d 86e5cd15bff042cd9db8444d23a1e9a8 -t "Research Report" report.md

EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--database)
      DATABASE_ID="$2"
      shift 2
      ;;
    -t|--title)
      TITLE="$2"
      shift 2
      ;;
    -T|--type)
      TYPE="$2"
      shift 2
      ;;
    -s|--status)
      STATUS="$2"
      shift 2
      ;;
    -k|--key)
      NOTION_KEY="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage
      ;;
    *)
      MARKDOWN_FILE="$1"
      shift
      ;;
  esac
done

# Validate inputs
if [[ -z "$DATABASE_ID" ]]; then
  echo "Error: Database ID required (--database)" >&2
  exit 1
fi

if [[ -z "$MARKDOWN_FILE" ]]; then
  echo "Error: Markdown file required" >&2
  exit 1
fi

if [[ ! -f "$MARKDOWN_FILE" ]]; then
  echo "Error: File not found: $MARKDOWN_FILE" >&2
  exit 1
fi

if [[ -z "$NOTION_KEY" ]]; then
  echo "Error: Notion API key required (set NOTION_KEY or use --key)" >&2
  exit 1
fi

# Remove dashes from database ID
DATABASE_ID_CLEAN=$(echo "$DATABASE_ID" | tr -d '-')

# Extract title if not provided
if [[ -z "$TITLE" ]]; then
  # Try to extract from first # heading
  TITLE=$(grep -m 1 '^# ' "$MARKDOWN_FILE" | sed 's/^# //' || basename "$MARKDOWN_FILE" .md)
fi

echo "Uploading to Notion..."
echo "  Database: ${DATABASE_ID}"
echo "  Title: ${TITLE}"
echo "  File: ${MARKDOWN_FILE}"

# Create page with title only first (Notion API has strict payload size limits)
PAGE_ID=$(curl -s -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: $NOTION_VERSION" \
  -H "Content-Type: application/json" \
  -d "{
    \"parent\": {\"database_id\": \"$DATABASE_ID_CLEAN\"},
    \"properties\": {
      \"Name\": {\"title\": [{\"text\": {\"content\": \"$TITLE\"}}]},
      \"Type\": {\"select\": {\"name\": \"$TYPE\"}},
      \"Status\": {\"status\": {\"name\": \"$STATUS\"}}
    }
  }" | jq -r '.id // empty')

if [[ -z "$PAGE_ID" ]]; then
  echo "Error: Failed to create Notion page" >&2
  exit 1
fi

echo "✅ Page created: $PAGE_ID"
echo "   URL: https://www.notion.so/${PAGE_ID}"
echo ""
echo "Note: Full markdown upload requires pandoc or manual content addition"
echo "      Consider using sessions_spawn with Notion upload task instead"
