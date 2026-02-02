#!/bin/bash
#
# Notion Importer Shell Wrapper
#
# Usage:
#   ./upload.sh <file.md> [options]
#
# Examples:
#   ./upload.sh report.md
#   ./upload.sh report.md --title "My Report"
#   ./upload.sh report.md --page 2f1e334e6d5f812d912dd7a0ffce7d24 --replace
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -eq 0 ]; then
    echo "Notion Importer"
    echo ""
    echo "Usage: upload.sh <file.md> [options]"
    echo ""
    echo "Options:"
    echo "  --database <id>     Target database (default: Nyx)"
    echo "  --page <id>         Upload to existing page"
    echo "  --replace           Replace page content"
    echo "  --title <text>      Page title"
    echo "  --properties <json> Database properties"
    echo ""
    echo "Examples:"
    echo "  ./upload.sh report.md"
    echo "  ./upload.sh report.md --title \"Research: Topic\""
    echo "  ./upload.sh notes.md --page abc123 --replace"
    exit 1
fi

exec node "$SCRIPT_DIR/upload.js" "$@"
