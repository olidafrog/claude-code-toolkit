# Notion Upload Guide for Research Reports

## Use the Notion Importer Skill

The `notion-importer` skill handles all Notion uploads with proper batching, rate limiting, and formatting.

**Location:** `/root/clawd/skills/notion-importer/`

## Quick Reference

```bash
# Upload research report to Nyx database (default)
node /root/clawd/skills/notion-importer/upload.js /tmp/research_report.md \
  --title "Research: Topic Name" \
  --properties '{"Type":{"select":{"name":"Research"}},"Status":{"select":{"name":"Done"}},"Tags":{"multi_select":[{"name":"research"}]}}'

# Upload to existing task page (replace content)
node /root/clawd/skills/notion-importer/upload.js /tmp/report.md \
  --page <page_id> \
  --replace

# Append to existing page
node /root/clawd/skills/notion-importer/upload.js /tmp/notes.md \
  --page <page_id>
```

## Features

The notion-importer skill handles:
- **Batching:** Automatic batching for >100 blocks
- **Rate limiting:** Built-in delays to prevent API throttling
- **All markdown formatting:**
  - Headings (h1-h3)
  - Bold, italic, code, strikethrough
  - Links (auto-converted to clickable)
  - Bullet and numbered lists
  - Checkboxes
  - Code blocks with syntax highlighting
  - Tables (converted to Notion simple tables)
  - Blockquotes (converted to callouts)
- **Verification:** Confirms upload succeeded

## Default Database

All uploads go to the **Nyx database** by default:
- Database ID: `5df03450-e009-47eb-9440-1bca190f835c`

Override with `--database <id>` for other destinations.

## Task Brief Template

When spawning research agents that upload to Notion:

```markdown
**Notion Upload:**
After completing research:
1. Save report to `/tmp/research_{topic}.md`
2. Upload using the notion-importer skill:

```bash
node /root/clawd/skills/notion-importer/upload.js /tmp/research_{topic}.md \
  --title "Research: {topic}" \
  --properties '{"Type":{"select":{"name":"Research"}},"Status":{"select":{"name":"Done"}}}'
```⁠

3. Report the Notion URL in your response
```

## Critical Rules

1. **Always use `2022-06-28` API version** (handled by the skill)
2. **Upload FULL reports** - not just summaries
3. **Verify success** - check the block count in output
4. **Use --replace carefully** - it deletes existing content

## Full Documentation

See `/root/clawd/skills/notion-importer/SKILL.md` for complete documentation.
