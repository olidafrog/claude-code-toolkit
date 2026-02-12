#!/bin/bash
# Upload markdown research reports to Notion with proper formatting and TOC
# Uses notion-importer skill for full markdown support with table of contents

set -euo pipefail

NOTION_IMPORTER="/root/clawd/skills/notion-importer/upload.js"
DATABASE_ID=""
MARKDOWN_FILE=""
TITLE=""
PROPERTIES=""
NO_TOC=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <markdown-file>

Upload markdown research report to Notion database with table of contents.

This script uses the notion-importer skill which:
- Converts markdown to Notion blocks with full formatting support
- Automatically adds table of contents for documents with 3+ headings
- Supports tables, code blocks, lists, and inline formatting

OPTIONS:
  -d, --database ID     Notion database ID (defaults to Nyx database)
  -t, --title TITLE     Page title (defaults to filename or first # heading)
  -p, --properties JSON Custom properties as JSON
  --no-toc              Disable table of contents
  -h, --help            Show this help

EXAMPLES:
  # Upload with auto-detected title and TOC
  $(basename "$0") -d 86e5cd15bff042cd9db8444d23a1e9a8 report.md
  
  # Upload with custom title and properties
  $(basename "$0") -d 86e5cd15bff042cd9db8444d23a1e9a8 \\
    -t "Research Report" \\
    -p '{"Type":{"select":{"name":"Research"}},"Status":{"select":{"name":"Done"}}}' \\
    report.md
  
  # Upload without table of contents
  $(basename "$0") -d 86e5cd15bff042cd9db8444d23a1e9a8 --no-toc report.md

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
    -p|--properties)
      PROPERTIES="$2"
      shift 2
      ;;
    --no-toc)
      NO_TOC="--no-toc"
      shift
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
if [[ -z "$MARKDOWN_FILE" ]]; then
  echo "Error: Markdown file required" >&2
  exit 1
fi

if [[ ! -f "$MARKDOWN_FILE" ]]; then
  echo "Error: File not found: $MARKDOWN_FILE" >&2
  exit 1
fi

if [[ ! -f "$NOTION_IMPORTER" ]]; then
  echo "Error: notion-importer not found at $NOTION_IMPORTER" >&2
  exit 1
fi

# Build command
CMD="node $NOTION_IMPORTER \"$MARKDOWN_FILE\""

if [[ -n "$DATABASE_ID" ]]; then
  CMD="$CMD --database \"$DATABASE_ID\""
fi

if [[ -n "$TITLE" ]]; then
  CMD="$CMD --title \"$TITLE\""
fi

if [[ -n "$PROPERTIES" ]]; then
  CMD="$CMD --properties '$PROPERTIES'"
fi

if [[ -n "$NO_TOC" ]]; then
  CMD="$CMD $NO_TOC"
fi

# Execute upload
echo "Uploading to Notion with table of contents..."
eval "$CMD"
