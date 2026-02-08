#!/bin/bash
# Generate Phase 3 prompt: Upload and Finalize
#
# This phase focuses ONLY on:
# - Reading Phase 2 report
# - Uploading to Notion
# - Saving to local archive
# - Updating task status
# - Cleaning up checkpoint files
#
# Usage: ./phase3-upload.sh <task-id> <page-id>

set -e

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <task-id> <page-id>" >&2
  exit 1
fi

TASK_ID="$1"
PAGE_ID="$2"
PHASE_DIR="/tmp/nyx-research-phases/${TASK_ID}"
PHASE2_FILE="${PHASE_DIR}/phase2.md"
METADATA_FILE="${PHASE_DIR}/metadata.json"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify Phase 2 report exists
if [ ! -f "$PHASE2_FILE" ]; then
  echo "ERROR: Phase 2 report not found: $PHASE2_FILE" >&2
  echo "Phase 2 must complete before Phase 3 can start." >&2
  exit 1
fi

# Read task name from metadata
TASK_NAME=$(jq -r '.task_name // "Research Task"' "$METADATA_FILE" 2>/dev/null || echo "Research Task")

# Sanitize task name for filename
SANITIZED_NAME=$(echo "$TASK_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//')
DATE=$(date +%Y-%m-%d)
ARCHIVE_FILE="/root/nyx/output/Research/${SANITIZED_NAME}_${DATE}.md"

# Generate the prompt
cat << PROMPT_END
# PHASE 3: Upload and Finalize

**Task:** ${TASK_NAME}
**Task ID:** \`${TASK_ID}\`
**Page ID:** \`${PAGE_ID}\`
**Phase:** 3 of 3 (Upload)

---

## Your Mission

You are executing **Phase 3** (final phase) of a phased research task. Your job is to **upload the completed report to Notion** and **finalize the task**.

---

## Phase 2 Report Location

**Report file:** \`${PHASE2_FILE}\`

**⚠️ CRITICAL: Verify the report exists:**
\`\`\`bash
ls -la ${PHASE2_FILE}
head -50 ${PHASE2_FILE}
\`\`\`

---

## Phase 3 Objectives

1. **Read the Phase 2 Report**
   - Load \`${PHASE2_FILE}\`
   - Verify it's complete and well-formatted

2. **Save to Local Archive**
   \`\`\`bash
   mkdir -p /root/nyx/output/Research/
   cp "${PHASE2_FILE}" "${ARCHIVE_FILE}"
   \`\`\`

3. **Upload to Notion**
   Use the complete-task.sh script which handles:
   - Uploading content to Notion
   - Updating status to "Waiting Review"
   
   \`\`\`bash
   ${SKILL_DIR}/complete-task.sh "${PAGE_ID}" "${PHASE2_FILE}"
   \`\`\`

4. **Clean Up Checkpoint Files**
   After successful upload, remove the phase directory:
   \`\`\`bash
   rm -rf "${PHASE_DIR}"
   \`\`\`

---

## ⚠️ CRITICAL: Execution Steps

**Run these commands IN ORDER:**

\`\`\`bash
# Step 1: Verify report exists
if [ -f "${PHASE2_FILE}" ]; then echo "✅ Report found"; else echo "❌ Report missing"; exit 1; fi

# Step 2: Save to local archive
mkdir -p /root/nyx/output/Research/
cp "${PHASE2_FILE}" "${ARCHIVE_FILE}"
echo "✅ Archived to: ${ARCHIVE_FILE}"

# Step 3: Upload to Notion and update status
${SKILL_DIR}/complete-task.sh "${PAGE_ID}" "${PHASE2_FILE}"

# Step 4: Clean up phase files (only after successful upload)
rm -rf "${PHASE_DIR}"
echo "✅ Cleaned up phase directory"
\`\`\`

---

## Success Criteria

✅ Phase 3 is complete when:
1. Report is archived locally
2. Content is uploaded to Notion page
3. Task status is "Waiting Review"
4. Phase directory is cleaned up
5. complete-task.sh reports success

❌ Phase 3 is NOT complete if:
- Upload to Notion failed
- Status is not "Waiting Review"
- complete-task.sh showed errors

---

## After Completion

Report back with:
\`\`\`
✅ PHASED RESEARCH COMPLETE (All 3 Phases)
- Task: ${TASK_NAME}
- Notion page: https://notion.so/${PAGE_ID//-/}
- Local archive: ${ARCHIVE_FILE}
- Status: Waiting Review
- Checkpoints cleaned up
\`\`\`

**Notify the user:**
Include a summary of the research findings (2-3 key points) and the Notion URL.
PROMPT_END
