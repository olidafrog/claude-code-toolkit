#!/bin/bash
# Check current phase status for a research task
# Returns: 0 (not started), 1 (phase 1 complete), 2 (phase 2 complete), 3 (complete)
#
# Usage: ./check-phase.sh <task-id>
# Output: JSON with phase status and checkpoint paths

set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <task-id>" >&2
  exit 1
fi

TASK_ID="$1"
PHASE_DIR="/tmp/nyx-research-phases/${TASK_ID}"

# Check what checkpoints exist
PHASE1_FILE="${PHASE_DIR}/phase1.json"
PHASE2_FILE="${PHASE_DIR}/phase2.md"
METADATA_FILE="${PHASE_DIR}/metadata.json"

CURRENT_PHASE=0
PHASE1_EXISTS=false
PHASE2_EXISTS=false

if [ -f "$PHASE1_FILE" ]; then
  # Verify phase 1 is complete (has status: complete)
  if jq -e '.status == "complete"' "$PHASE1_FILE" >/dev/null 2>&1; then
    PHASE1_EXISTS=true
    CURRENT_PHASE=1
  fi
fi

if [ -f "$PHASE2_FILE" ] && [ -s "$PHASE2_FILE" ]; then
  # Phase 2 output exists and is not empty
  PHASE2_EXISTS=true
  CURRENT_PHASE=2
fi

# Check if task is already complete (status = Waiting Review with no incomplete phases)
# This would be phase 3 complete

jq -n \
  --arg task_id "$TASK_ID" \
  --arg phase_dir "$PHASE_DIR" \
  --argjson current_phase "$CURRENT_PHASE" \
  --argjson phase1_exists "$PHASE1_EXISTS" \
  --argjson phase2_exists "$PHASE2_EXISTS" \
  --arg phase1_file "$PHASE1_FILE" \
  --arg phase2_file "$PHASE2_FILE" \
  --arg metadata_file "$METADATA_FILE" \
  '{
    task_id: $task_id,
    current_phase: $current_phase,
    next_phase: (if $current_phase == 0 then 1 elif $current_phase == 1 then 2 elif $current_phase == 2 then 3 else "complete" end),
    checkpoints: {
      phase1_exists: $phase1_exists,
      phase2_exists: $phase2_exists,
      phase1_file: $phase1_file,
      phase2_file: $phase2_file,
      metadata_file: $metadata_file
    },
    phase_dir: $phase_dir
  }'
