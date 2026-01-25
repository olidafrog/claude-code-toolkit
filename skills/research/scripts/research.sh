#!/bin/bash
# Research task spawner (v2) - Creates structured research tasks with MECE decomposition
#
# Implements meta-research best practices:
# - MECE decomposition
# - Hypothesis-driven option
# - Source quality tracking
# - Confidence indicators
# - "So What" enforcement
# - Model + thinking selection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
RESEARCH_TYPE="general"
RESEARCH_MODE="exploratory"
HYPOTHESIS=""
TASK=""
OUTPUT_DIR="$HOME/clawd/reports"
NOTION_DB=""
TIMEOUT=600
LABEL=""
MODEL="sonnet"
THINKING=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] <task-description>

Spawn a research sub-agent with structured task brief implementing meta-research best practices.

OPTIONS:
  -t, --type TYPE          Research type: compare, feasibility, cost-benefit, market, technical, general
                           (default: general)
  -m, --mode MODE          Research mode: exploratory, hypothesis (default: exploratory)
  -H, --hypothesis TEXT    Hypothesis to test (implies --mode hypothesis)
  -M, --model MODEL        Model: sonnet, opus (default: sonnet)
  -T, --thinking THINKING  Thinking mode: standard, extended (default: based on complexity)
  -o, --output DIR         Output directory for reports (default: ~/clawd/reports)
  -n, --notion DB_ID       Notion database ID for upload (optional)
  -s, --timeout SECONDS    Task timeout in seconds (default: 600)
  -l, --label LABEL        Session label (auto-generated if not provided)
  -h, --help               Show this help

RESEARCH TYPES:
  compare       Compare options (X vs Y)
  feasibility   Evaluate if something is viable
  cost-benefit  Analyze if something is worth it
  market        Understand the landscape
  technical     Deep technical investigation
  general       General research

EXAMPLES:
  # Simple comparison (exploratory, Sonnet)
  $(basename "$0") -t compare "Compare Tailwind vs styled-components"
  
  # Hypothesis-driven feasibility (Sonnet + extended thinking)
  $(basename "$0") -t feasibility -H "Bun is faster than Node for our use case" "Evaluate Bun migration"
  
  # Deep technical research (Opus + extended thinking)
  $(basename "$0") -t technical -M opus -T extended "Event sourcing architecture patterns"
  
  # Market research with Notion upload
  $(basename "$0") -t market -n DATABASE_ID "LLM routing solutions landscape"

CONFIGURATIONS:
  Simple fact-finding:     -M sonnet              (standard thinking)
  Standard research:       -M sonnet -T extended  (recommended default)
  Complex analysis:        -M opus -T extended    (deeper reasoning)

EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--type)
      RESEARCH_TYPE="$2"
      shift 2
      ;;
    -m|--mode)
      RESEARCH_MODE="$2"
      shift 2
      ;;
    -H|--hypothesis)
      HYPOTHESIS="$2"
      RESEARCH_MODE="hypothesis"
      shift 2
      ;;
    -M|--model)
      MODEL="$2"
      shift 2
      ;;
    -T|--thinking)
      THINKING="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -n|--notion)
      NOTION_DB="$2"
      shift 2
      ;;
    -s|--timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    -l|--label)
      LABEL="$2"
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
      TASK="$1"
      shift
      ;;
  esac
done

if [[ -z "$TASK" ]]; then
  echo "Error: Task description required" >&2
  usage
fi

# Generate label if not provided
if [[ -z "$LABEL" ]]; then
  LABEL="research-$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | cut -c1-40)"
fi

# Auto-select thinking mode if not specified
if [[ -z "$THINKING" ]]; then
  case "$RESEARCH_TYPE" in
    technical)
      THINKING="extended"
      ;;
    compare|feasibility)
      if [[ "$RESEARCH_MODE" == "hypothesis" ]]; then
        THINKING="extended"
      else
        THINKING="standard"
      fi
      ;;
    *)
      THINKING="standard"
      ;;
  esac
fi

# Adjust timeout for complex research
if [[ "$MODEL" == "opus" || "$THINKING" == "extended" ]]; then
  if [[ "$TIMEOUT" -lt 900 ]]; then
    TIMEOUT=900
  fi
fi
if [[ "$MODEL" == "opus" && "$THINKING" == "extended" ]]; then
  if [[ "$TIMEOUT" -lt 1200 ]]; then
    TIMEOUT=1200
  fi
fi

# Load template
TEMPLATE_FILE="$SKILL_DIR/references/task-templates.md"
if [[ ! -f "$TEMPLATE_FILE" ]]; then
  echo "Error: Template file not found: $TEMPLATE_FILE" >&2
  exit 1
fi

# Extract template for research type
TEMPLATE=$(awk -v type="$RESEARCH_TYPE" '
  $0 == "## " type {found=1; next}
  found && /^## [a-z]/ {exit}
  found && /^---/ {next}
  found {print}
' "$TEMPLATE_FILE" | head -100 || true)

if [[ -z "$TEMPLATE" ]]; then
  echo "Warning: No template found for type '$RESEARCH_TYPE', using general" >&2
  RESEARCH_TYPE="general"
fi

# Build the task brief
TASK_BRIEF=$(cat <<EOF
# Research Task Brief

## Configuration
- **Type:** ${RESEARCH_TYPE}
- **Mode:** ${RESEARCH_MODE}
- **Model:** ${MODEL}
- **Thinking:** ${THINKING}

## Research Question
${TASK}

EOF
)

# Add hypothesis section if hypothesis-driven
if [[ "$RESEARCH_MODE" == "hypothesis" && -n "$HYPOTHESIS" ]]; then
  TASK_BRIEF+=$(cat <<EOF
## Hypothesis to Test
**Claim:** ${HYPOTHESIS}

**Evidence for:** Look for data, benchmarks, case studies supporting this claim
**Evidence against:** Actively seek contradicting evidence, counterexamples
**Verdict criteria:** Supported / Partially supported / Refuted / Inconclusive

EOF
)
fi

# Add instructions
TASK_BRIEF+=$(cat <<EOF
## Instructions

### Phase 1: Planning
1. Decompose the research question into MECE sub-questions (mutually exclusive, collectively exhaustive)
2. Identify source strategy for each sub-question
3. Create visible research plan

### Phase 2: Execution
1. Research each sub-question
2. Track source quality (🟢 High, 🟡 Medium, 🔴 Low)
3. Note contradictions and gaps
4. Iterate if quality threshold not met (max 3 iterations)

### Phase 3: Synthesis
1. Apply "So What" framework - drive to actionable insights
2. Add confidence indicators on key findings
3. Document methodology
4. Structure for progressive disclosure

## Deliverable Structure

\`\`\`markdown
# [Title]

## TL;DR
[1-2 sentence answer]

## Executive Summary
[2-3 paragraphs]

## Key Findings
[Bullet points with confidence indicators]

## Detailed Analysis
[Full sections per MECE decomposition]

## So What: Implications
### What This Means
[Synthesis into insight]

### Recommended Actions
[Specific, actionable recommendations]

### Decision Framework
[Conditional guidance]

## Methodology
[How research was conducted]

## Sources
[Full citations with URLs]
\`\`\`

## Quality Standards
- All claims cited with URLs
- Minimum 2 sources per key claim
- Confidence indicators (🟢/🟡/🔴) on findings
- "So What" section must be actionable
- Methodology documented
- Limitations acknowledged

## Output
- Save report to: ${OUTPUT_DIR}/
- Filename format: ${RESEARCH_TYPE}-$(echo "$TASK" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | cut -c1-50).md
EOF
)

# Add Notion upload instruction if database provided
if [[ -n "$NOTION_DB" ]]; then
  TASK_BRIEF+=$(cat <<EOF

## Notion Upload
After completing research, upload report to Notion database: ${NOTION_DB}
- Use proper formatting (headings, code blocks, tables, callouts)
- Set Type: Notes
- Set Status: Done
- Return Notion URL when complete
EOF
)
fi

# Build spawn JSON
SPAWN_JSON="{"
SPAWN_JSON+="\"task\": $(echo "$TASK_BRIEF" | jq -Rs .),"
SPAWN_JSON+="\"label\": \"${LABEL}\","
SPAWN_JSON+="\"model\": \"${MODEL}\","
if [[ "$THINKING" == "extended" ]]; then
  SPAWN_JSON+="\"thinking\": \"extended\","
fi
SPAWN_JSON+="\"runTimeoutSeconds\": ${TIMEOUT}"
SPAWN_JSON+="}"

# Output
cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RESEARCH TASK (v2)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Type:       ${RESEARCH_TYPE}
Mode:       ${RESEARCH_MODE}
Model:      ${MODEL}
Thinking:   ${THINKING}
Timeout:    ${TIMEOUT}s
Output:     ${OUTPUT_DIR}
$([ -n "$NOTION_DB" ] && echo "Notion:     ${NOTION_DB}" || echo "Notion:     Not configured")
Label:      ${LABEL}
$([ -n "$HYPOTHESIS" ] && echo -e "\nHypothesis: ${HYPOTHESIS}")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
TASK BRIEF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${TASK_BRIEF}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SPAWN JSON
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${SPAWN_JSON}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
