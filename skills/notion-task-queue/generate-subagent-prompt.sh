#!/bin/bash
# Generate a complete sub-agent prompt for a Notion task
#
# This script creates a comprehensive prompt that includes:
# - The task instructions from Notion
# - The mandatory completion requirements
# - The page ID and task details
#
# Usage: ./generate-subagent-prompt.sh <page-id>
#
# Output: A complete prompt ready to pass to a sub-agent

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <page-id>" >&2
  exit 1
fi

PAGE_ID="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NOTION_KEY=$(cat ~/.config/notion/api_key)

# Fetch task details from Notion
TASK_DATA=$(curl -s --max-time 15 "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28")

TASK_NAME=$(echo "$TASK_DATA" | jq -r '.properties.Name.title[0].text.content // "Untitled"')
TASK_TYPE=$(echo "$TASK_DATA" | jq -r '.properties.Type.select.name // "Task"')
TASK_PRIORITY=$(echo "$TASK_DATA" | jq -r '.properties.Priority.select.name // "Medium"')
MODEL_OVERRIDE=$(echo "$TASK_DATA" | jq -r '.properties.Model.select.name // ""')
THINKING_ENABLED=$(echo "$TASK_DATA" | jq -r '.properties.Thinking.checkbox // true')
PHASED_RESEARCH=$(echo "$TASK_DATA" | jq -r '.properties["Phased Research"].checkbox // false')

# Check if phased research is enabled for this task
if [ "$PHASED_RESEARCH" = "true" ] && [ "$TASK_TYPE" = "Research" ]; then
  # Redirect to phased research orchestrator
  exec "${SCRIPT_DIR}/phases/orchestrate-phased-research.sh" "$PAGE_ID"
fi

# Determine timeout based on task type
# Research tasks get 20 minutes (1200s), others get 10 minutes (600s)
if [ "$TASK_TYPE" = "Research" ]; then
  TIMEOUT_SECONDS=1200
  TIMEOUT_HUMAN="20 minutes"
else
  TIMEOUT_SECONDS=600
  TIMEOUT_HUMAN="10 minutes"
fi

# Fetch page content (task description)
PAGE_CONTENT=$(curl -s --max-time 15 "https://api.notion.com/v1/blocks/$PAGE_ID/children?page_size=100" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" | \
  jq -r '.results[] | 
    if .type == "paragraph" then .paragraph.rich_text[].plain_text
    elif .type == "bulleted_list_item" then "• " + .bulleted_list_item.rich_text[].plain_text
    elif .type == "numbered_list_item" then "- " + .numbered_list_item.rich_text[].plain_text
    elif .type == "heading_1" then "# " + .heading_1.rich_text[].plain_text
    elif .type == "heading_2" then "## " + .heading_2.rich_text[].plain_text
    elif .type == "heading_3" then "### " + .heading_3.rich_text[].plain_text
    else empty
    end' 2>/dev/null || echo "[Unable to fetch page content]")

# Sanitize task name for filename
SANITIZED_NAME=$(echo "$TASK_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
DATE=$(date +%Y-%m-%d)
OUTPUT_FILE="/root/nyx/output/${TASK_TYPE}/${SANITIZED_NAME}_${DATE}.md"

# Output metadata for the main agent (JSON on stderr, prompt on stdout)
echo "{\"page_id\":\"${PAGE_ID}\",\"name\":\"${TASK_NAME}\",\"type\":\"${TASK_TYPE}\",\"priority\":\"${TASK_PRIORITY}\",\"model\":\"${MODEL_OVERRIDE}\",\"thinking\":${THINKING_ENABLED},\"timeout_seconds\":${TIMEOUT_SECONDS}}" >&2

# Generate the complete prompt
cat << PROMPT_END
# Notion Task: ${TASK_NAME}

**Task Type:** ${TASK_TYPE}
**Priority:** ${TASK_PRIORITY}
**Timeout:** ${TIMEOUT_HUMAN} (${TIMEOUT_SECONDS} seconds)
**Page ID:** \`${PAGE_ID}\`

---

## Task Instructions

${PAGE_CONTENT}

---

## ⚠️ MANDATORY COMPLETION REQUIREMENTS

**YOUR TASK IS NOT COMPLETE UNTIL YOU DO ALL OF THE FOLLOWING:**

### Step 1: Complete the Work
Execute the task as described above.

### Step 2: Save Output
Save your work to:
\`\`\`
${OUTPUT_FILE}
\`\`\`

### Step 3: ⭐ UPLOAD AND UPDATE STATUS (CRITICAL)

**Run this command after saving your output:**
\`\`\`bash
/root/nyx/skills/notion-task-queue/complete-task.sh "${PAGE_ID}" "${OUTPUT_FILE}"
\`\`\`

This script will:
- Upload your content to the Notion page
- Update status to "Waiting Review"
- Verify both steps succeeded

### Step 4: Report Success

Only report success AFTER \`complete-task.sh\` runs successfully:
\`\`\`
✅ Task completed:
- Page: ${TASK_NAME}
- Content uploaded to Notion
- Status: Waiting Review
- Output: ${OUTPUT_FILE}
\`\`\`

---

## ❌ FAILURE CONDITIONS

Your task is FAILED if:
- You finish without running \`complete-task.sh\`
- The status is not "Waiting Review" when done
- You report success but \`complete-task.sh\` showed errors

---

**Remember: The task is NOT done until \`complete-task.sh\` succeeds!**
PROMPT_END
