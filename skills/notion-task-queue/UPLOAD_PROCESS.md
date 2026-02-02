# Notion Upload Process for Task Queue

## Use the Notion Importer Skill

The `notion-importer` skill handles all Notion uploads with proper batching, rate limiting, and formatting.

**Location:** `/root/clawd/skills/notion-importer/`

## Workflow

### 1. Save Report Locally

After completing research or work, save the full report:

```bash
# For research tasks
/tmp/{task_name}_research.md

# For other tasks
/tmp/{task_name}_report.md
```

### 2. Upload to Task Page

```bash
# Replace existing page content with results
node /root/clawd/skills/notion-importer/upload.js \
  /tmp/{task_name}_report.md \
  --page <page_id> \
  --replace

# Or append to existing content
node /root/clawd/skills/notion-importer/upload.js \
  /tmp/{task_name}_report.md \
  --page <page_id>
```

### 3. Update Task Status

After uploading, update the task status via Notion API:

```bash
NOTION_KEY=$(cat ~/.config/notion/api_key)
PAGE_ID="<notion-page-id>"

curl -s -X PATCH "https://api.notion.com/v1/pages/${PAGE_ID}" \
    -H "Authorization: Bearer ${NOTION_KEY}" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"properties": {"Status": {"select": {"name": "Waiting Review"}}}}'
```

## Example Complete Workflow

```bash
# 1. Task produces report
TASK_NAME="axidraw_research"
REPORT="/tmp/${TASK_NAME}_report.md"
PAGE_ID="2f6e334e-6d5f-8060-91f4-ed979d32e712"
NOTION_KEY=$(cat ~/.config/notion/api_key)

# 2. Upload full report to task page
node /root/clawd/skills/notion-importer/upload.js "$REPORT" --page "$PAGE_ID" --replace

# 3. Update status to Waiting Review
curl -s -X PATCH "https://api.notion.com/v1/pages/${PAGE_ID}" \
    -H "Authorization: Bearer ${NOTION_KEY}" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{"properties": {"Status": {"select": {"name": "Waiting Review"}}}}'

echo "✅ Task completed and uploaded"
echo "URL: https://www.notion.so/${PAGE_ID//-/}"
```

## Why This Matters

- **Summaries lose detail** - Oli needs full context, not executive summaries
- **Research reports are valuable** - They're reference material, not just status updates
- **Notion is the source of truth** - The database should contain complete information
- **Rate limiting** - The skill handles batching automatically

## Skill Features

The notion-importer skill handles:
- Automatic batching for large documents (>100 blocks)
- Rate limiting to prevent API throttling
- All markdown formatting (tables, code blocks, links, etc.)
- Upload verification

## Full Documentation

See `/root/clawd/skills/notion-importer/SKILL.md` for complete documentation.
