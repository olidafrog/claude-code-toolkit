#!/bin/bash
# Generate Phase 1 prompt: Research Gathering
#
# This phase focuses ONLY on:
# - Understanding the task
# - Planning research approach
# - Executing web searches
# - Collecting raw findings
#
# Output: Checkpoint file with raw research data
#
# Usage: ./phase1-gather.sh <task-id> <task-name> <task-description>

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <task-id> <task-name> [task-description]" >&2
  exit 1
fi

TASK_ID="$1"
TASK_NAME="$2"
TASK_DESCRIPTION="${3:-}"
PHASE_DIR="/tmp/nyx-research-phases/${TASK_ID}"
CHECKPOINT_FILE="${PHASE_DIR}/phase1.json"
METADATA_FILE="${PHASE_DIR}/metadata.json"

# Ensure phase directory exists
mkdir -p "$PHASE_DIR"

# Create metadata file
cat > "$METADATA_FILE" << EOF
{
  "task_id": "${TASK_ID}",
  "task_name": "${TASK_NAME}",
  "started_at": "$(date -Iseconds)",
  "type": "phased_research"
}
EOF

# Generate the prompt
cat << PROMPT_END
# PHASE 1: Research Gathering

**Task:** ${TASK_NAME}
**Task ID:** \`${TASK_ID}\`
**Phase:** 1 of 3 (Gather)

---

## Your Mission

You are executing **Phase 1** of a phased research task. Your ONLY job is to **gather raw research data**. Do NOT synthesize, do NOT write a report, do NOT upload to Notion.

## Task Context

${TASK_DESCRIPTION:-[Read the task from Notion to understand what needs to be researched]}

---

## Phase 1 Objectives

1. **Understand the Research Question**
   - What specifically needs to be researched?
   - What are the key aspects to investigate?

2. **Plan Your Search Strategy**
   - What queries will you use?
   - What sources are most relevant?

3. **Execute Web Searches**
   - Run 5-10 targeted searches
   - Focus on authoritative sources
   - Capture key facts, not opinions

4. **Collect Raw Findings**
   - Extract relevant quotes and data points
   - Note source URLs
   - Rate relevance (high/medium/low)

---

## ⚠️ CRITICAL: Output Requirements

When you have gathered sufficient research, you MUST save your findings to this exact file:

\`\`\`
${CHECKPOINT_FILE}
\`\`\`

**The file MUST be valid JSON with this structure:**

\`\`\`json
{
  "task_id": "${TASK_ID}",
  "task_name": "${TASK_NAME}",
  "phase": 1,
  "status": "complete",
  "completed_at": "ISO-8601 timestamp",
  "research_question": "Clear statement of what was researched",
  "search_queries": [
    "query 1",
    "query 2"
  ],
  "findings": [
    {
      "source": "URL or source name",
      "title": "Article/page title",
      "relevance": "high|medium|low",
      "key_points": [
        "Key fact or insight 1",
        "Key fact or insight 2"
      ],
      "quotes": [
        "Direct quote if relevant"
      ]
    }
  ],
  "themes_identified": [
    "Theme 1",
    "Theme 2"
  ],
  "gaps_to_address": [
    "Any areas needing more research in Phase 2"
  ]
}
\`\`\`

---

## Success Criteria

✅ Phase 1 is complete when:
1. You have gathered 5+ high-quality sources
2. Key themes are identified
3. The checkpoint JSON is saved and valid
4. Status is set to "complete"

❌ Phase 1 is NOT complete if:
- No checkpoint file exists
- JSON is malformed
- Status is not "complete"
- Fewer than 3 sources gathered

---

## What NOT to Do

❌ Do NOT write a full report (that's Phase 2)
❌ Do NOT upload to Notion (that's Phase 3)
❌ Do NOT update the task status in Notion
❌ Do NOT synthesize findings into conclusions yet

---

## After Completion

Report back with:
\`\`\`
✅ PHASE 1 COMPLETE
- Task: ${TASK_NAME}
- Sources gathered: [number]
- Themes identified: [list]
- Checkpoint saved: ${CHECKPOINT_FILE}
- Ready for Phase 2
\`\`\`
PROMPT_END
