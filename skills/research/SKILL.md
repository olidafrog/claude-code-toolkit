---
name: research
description: Evidence-based research workflow applying meta-research best practices. Implements MECE decomposition, hypothesis-driven investigation, iterative refinement, source quality tracking, confidence indicators, and "So What" enforcement. Use for any research task—comparative analysis, feasibility studies, technical investigation, or general research. Spawns sub-agents with structured task briefs and optional Notion upload.
---

# Research Skill (v2)

Evidence-based research workflow applying meta-research best practices for effective, actionable research.

## Core Principles

This skill implements 10 best practices from consulting and academic research:

1. **Explicit Planning** – Visible research plan before execution
2. **MECE Decomposition** – Mutually Exclusive, Collectively Exhaustive sub-questions
3. **Hypothesis-Driven Option** – Focused investigation when appropriate
4. **"So What" Enforcement** – Actionable insights, not just comprehensiveness
5. **Iterative Refinement** – Self-evaluation and gap-filling loops
6. **Source Quality Tracking** – Evaluate and weight citation quality
7. **Confidence Indicators** – Show certainty levels in findings
8. **Methodology Transparency** – Document approach for reproducibility
9. **Progressive Disclosure** – Structure for scanning vs deep reading
10. **Human Checkpoints** – Natural intervention points

## When to Use

Use this skill when:
- User requests research or investigation on any topic
- Need to compare options (tools, approaches, solutions)
- Evaluating feasibility of an idea or implementation
- Analyzing costs vs benefits
- Understanding a market or technology landscape
- Deep technical investigation needed
- Any "can you research..." or "look into..." query

## Quick Reference

```bash
# Simple research (Sonnet, exploratory)
sessions_spawn with structured task brief for "Research topic"

# Focused research with hypothesis
sessions_spawn with hypothesis-driven task brief for "Test whether X is true"

# Deep analysis (Opus + extended thinking)
sessions_spawn with model:"opus", thinking:"extended" for complex synthesis
```

## Workflow Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│  PHASE 1: SCOPE & CONFIGURE                                         │
│  → Research type, mode (exploratory/hypothesis), model selection    │
│  → Human checkpoint: "Does this research approach look right?"      │
├─────────────────────────────────────────────────────────────────────┤
│  PHASE 2: PLAN                                                      │
│  → MECE decomposition into sub-questions                            │
│  → Source strategy per sub-question                                 │
│  → Human checkpoint: "Approve this research plan?" (optional)       │
├─────────────────────────────────────────────────────────────────────┤
│  PHASE 3: EXECUTE                                                   │
│  → Research each sub-question                                       │
│  → Track source quality, note contradictions                        │
│  → Iterative refinement if gaps remain                              │
├─────────────────────────────────────────────────────────────────────┤
│  PHASE 4: SYNTHESIZE                                                │
│  → Apply "So What" framework                                        │
│  → Add confidence indicators                                        │
│  → Document methodology                                             │
├─────────────────────────────────────────────────────────────────────┤
│  PHASE 5: DELIVER                                                   │
│  → Progressive disclosure structure                                 │
│  → Quality validation                                               │
│  → Optional Notion upload                                           │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Scope & Configure

### Step 1.1: Determine Research Type

Six research templates available (see `references/task-templates.md`):

| Type | Use When | Example |
|------|----------|---------|
| `compare` | Evaluating multiple options | "Compare Linear vs Jira" |
| `feasibility` | Checking if something is viable | "Can we implement X?" |
| `cost-benefit` | Analyzing ROI/worth | "Is switching to Y worth it?" |
| `market` | Understanding landscape | "What solutions exist for Z?" |
| `technical` | Deep technical dive | "How does X work?" |
| `general` | General investigation | "Research topic X" |

### Step 1.2: Select Research Mode

**NEW:** Choose between two modes:

| Mode | Description | Best For |
|------|-------------|----------|
| **Exploratory** | Comprehensive, broad investigation | Unknown territory, landscape mapping |
| **Hypothesis-Driven** | Focused testing of specific claim | Decisions, validation, efficiency |

**Default:** Exploratory. Use hypothesis-driven when user has a specific belief to test.

**Hypothesis-Driven Format:**
```
Hypothesis: [Statement to test]
Test by examining: [What evidence would support/refute]
Decision criteria: [How to interpret results]
```

### Step 1.3: Select Model & Thinking Mode (RETAINED)

Determine model (Sonnet vs Opus) AND thinking mode based on complexity:

#### Model Selection

| Scenario | Model | Rationale |
|----------|-------|-----------|
| Straightforward information gathering | **Sonnet** | Efficient, cost-effective |
| Clear parameters, well-defined questions | **Sonnet** | Good results, fast |
| Complex analysis, many sources | **Opus** | Deeper reasoning |
| Nuanced synthesis, conflicting info | **Opus** | Sophisticated interpretation |
| Accuracy matters more than speed | **Opus** | Thoroughness |

**Default: Sonnet** – Opus is for edge cases requiring complex reasoning.

#### Extended Thinking Selection

| Scenario | Thinking | Rationale |
|----------|----------|-----------|
| Fact-finding, information retrieval | **Standard** | Speed |
| Simple summarization | **Standard** | Efficiency |
| Complex reasoning chains | **Extended** | Better analysis |
| Identifying contradictions | **Extended** | Catches errors |
| Multi-step problems | **Extended** | Structured decomposition |

**Sweet Spot:** Sonnet + Extended Thinking = capable research at reasonable cost

#### Configuration Matrix

| Research Complexity | Recommended Config |
|--------------------|--------------------|
| Simple fact-finding | Sonnet (standard) |
| Standard research | Sonnet + Extended |
| Complex analysis | Opus + Extended |
| Maximum capability | Opus + Extended (slowest) |

#### When Uncertain – Ask User

```
This research could benefit from different configurations:
• Sonnet: Faster, cheaper, handles most research well
• Sonnet + Extended: Better reasoning, cost-effective (recommended)
• Opus + Extended: Deepest analysis (slower, more expensive)

Which would you prefer?
```

### Step 1.4: Human Checkpoint (Implicit)

Before spawning, briefly confirm the approach:

```
I'll research [topic] using [type] research in [mode] mode.
[If non-default model/thinking]: Using [config] for deeper analysis.

Sound good, or would you like a different approach?
```

For routine research, skip explicit confirmation and proceed.

---

## Phase 2: Plan

### Step 2.1: MECE Decomposition

Break the research question into Mutually Exclusive, Collectively Exhaustive sub-questions.

**MECE Criteria:**
- **Mutually Exclusive:** Sub-questions don't overlap
- **Collectively Exhaustive:** Together they cover the entire question

**Example MECE Decomposition:**
```
Main Question: "Should we migrate from Postgres to MongoDB?"

Sub-Questions (MECE):
1. What are our current pain points with Postgres? (Current state)
2. How well does MongoDB address these pain points? (Solution fit)
3. What new challenges would MongoDB introduce? (Trade-offs)
4. What is the migration effort and cost? (Implementation)
5. What do similar companies do? (External validation)
```

See `references/planning-frameworks.md` for decomposition patterns.

### Step 2.2: Source Strategy

For each sub-question, identify:
- **Source types:** Official docs, academic papers, community forums, etc.
- **Quality threshold:** What source quality is needed?
- **Minimum sources:** How many sources per claim?

**Source Priority Hierarchy:**
1. Peer-reviewed / official documentation
2. Industry reports / expert analysis
3. Community experiences (Reddit, HN, Discord)
4. General web (requires triangulation)

### Step 2.3: Create Research Plan

Generate a visible research plan:

```markdown
## Research Plan

**Main Question:** [User's question]
**Type:** [Research type] | **Mode:** [Exploratory/Hypothesis-driven]
**Model:** [Sonnet/Opus] | **Thinking:** [Standard/Extended]

### Sub-Questions (MECE)
1. [Sub-Q1] → Sources: [types] | Min: [N sources]
2. [Sub-Q2] → Sources: [types] | Min: [N sources]
3. [Sub-Q3] → Sources: [types] | Min: [N sources]

### Hypothesis (if hypothesis-driven)
**Claim:** [Statement being tested]
**Evidence for:** [What would support it]
**Evidence against:** [What would refute it]

### Scope
- Depth: [Surface/Standard/Deep]
- Timeframe: [If relevant]
- Geographic focus: [If relevant]
```

### Step 2.4: Human Checkpoint (Optional)

For complex or high-stakes research, ask:

```
Here's my research plan:
[Show plan]

Should I proceed, or adjust the approach?
```

For routine research, include plan in task brief without pause.

---

## Phase 3: Execute

### Step 3.1: Research Each Sub-Question

Execute research following the plan. For each sub-question:
1. Search relevant sources
2. Evaluate source quality (see `references/quality-standards.md`)
3. Extract relevant findings
4. Note contradictions and gaps

### Step 3.2: Track Source Quality

Rate each source:

| Rating | Criteria | Weight |
|--------|----------|--------|
| 🟢 **High** | Official docs, peer-reviewed, authoritative | 3x |
| 🟡 **Medium** | Industry publications, expert blogs | 2x |
| 🔴 **Low** | General web, unverified, potential bias | 1x |

**Triangulation Rule:** Low-quality sources require 2+ independent confirmations.

### Step 3.3: Iterative Refinement Loop

After initial research pass:

```
QUALITY CHECK:
□ All sub-questions addressed?
□ At least 2 sources per key claim?
□ Major contradictions resolved or explained?
□ Critical gaps identified?

If any NO → Conduct targeted follow-up → Re-check
Max iterations: 3
```

### Step 3.4: Document Contradictions

When sources disagree:
```
**Contradiction Noted:**
- Source A claims: [X]
- Source B claims: [Y]
- Resolution: [Explanation, or "Unresolved - noted in findings"]
```

---

## Phase 4: Synthesize

### Step 4.1: Apply "So What" Framework

Every finding must answer "So what?":

| Level | Question | Example |
|-------|----------|---------|
| **Observation** | What does the data show? | "MongoDB lacks ACID by default" |
| **Analysis** | Why does this matter? | "Our financial transactions require ACID" |
| **So What** | What should we do? | "MongoDB is unsuitable without workarounds" |

**Mandatory "So What" Section:**
```markdown
## So What: Key Implications

### What This Means
[Synthesis of findings into meaningful insight]

### Recommended Actions
1. [Specific, actionable recommendation]
2. [Specific, actionable recommendation]

### Decision Framework
- If [condition A], then [recommendation A]
- If [condition B], then [recommendation B]
```

### Step 4.2: Add Confidence Indicators

Mark confidence on key findings:

| Indicator | Meaning | Criteria |
|-----------|---------|----------|
| 🟢 **High confidence** | Strong evidence | 3+ high-quality sources, consistent |
| 🟡 **Medium confidence** | Moderate evidence | 1-2 sources, or some inconsistency |
| 🔴 **Low confidence** | Weak evidence | Single source, unverified, speculation |

**Usage:**
```
"MongoDB handles 100K+ reads/sec easily" 🟢 (benchmarks from official docs + 3 production case studies)
"Migration typically takes 2-4 weeks" 🟡 (2 blog posts, varies by complexity)
"Version 8.0 will add feature X" 🔴 (single unofficial source)
```

### Step 4.3: Document Methodology

Include methodology section:

```markdown
## Methodology

**Search Strategy:**
- Sources consulted: [list types]
- Search terms: [key terms]
- Date range: [if relevant]

**Quality Assessment:**
- Total sources found: [N]
- Sources included: [N]
- Exclusion reasons: [brief]

**Limitations:**
- [Known limitation 1]
- [Known limitation 2]
```

---

## Phase 5: Deliver

### Step 5.1: Progressive Disclosure Structure

Structure output for different consumption levels:

```markdown
# [Report Title]

## TL;DR (1-2 sentences)
[One-line answer for busy readers]

## Executive Summary (2-3 paragraphs)
[High-level findings and recommendation]

## Key Findings (Scannable)
- Finding 1 🟢
- Finding 2 🟡
- Finding 3 🟢

## Detailed Analysis
[Full sections with evidence]

## Methodology
[How research was conducted]

## Sources
[Full citation list]
```

### Step 5.2: Quality Validation Checklist

Before finalizing:

```
RESEARCH QUALITY CHECKLIST:
□ Research question answered directly
□ All sub-questions addressed
□ All claims have sources
□ "So What" section is actionable
□ Confidence levels indicated
□ Methodology documented
□ Contradictions addressed
□ Limitations acknowledged
□ Next steps defined
```

### Step 5.3: Notion Upload (Optional)

If database ID provided:
- **Use notion-importer skill** – `/root/clawd/skills/notion-importer/upload.js`
  - Automatic table of contents for documents with 3+ headings
  - Full markdown support (tables, code blocks, formatting)
  - Batching and rate limiting handled automatically
- **API Version:** Uses `2022-06-28` (stable, NOT 2025+ versions)
- **Default Properties:** Set Type: Research, Status: Done (customizable)
- Upload command:
  ```bash
  node /root/clawd/skills/notion-importer/upload.js report.md \
    --database <db-id> \
    --title "Research Report Title" \
    --properties '{"Type":{"select":{"name":"Research"}},"Status":{"select":{"name":"Done"}}}'
  ```
- Returns Notion URL with block count confirmation
- **Table of Contents:** Auto-enabled for research reports (disable with `--no-toc` if needed)

## Task Brief Template

Use this template when spawning research sub-agents:

```markdown
# Research Task Brief

## Research Configuration
- **Type:** [compare/feasibility/cost-benefit/market/technical/general]
- **Mode:** [Exploratory/Hypothesis-driven]
- **Main Question:** [User's question]

## Research Plan

### Sub-Questions (MECE)
1. [Sub-Q1] → Sources: [types]
2. [Sub-Q2] → Sources: [types]
3. [Sub-Q3] → Sources: [types]

### Hypothesis (if applicable)
[Statement being tested with evidence criteria]

## Execution Requirements

### Source Quality Standards
- Minimum 2 sources per key claim
- Triangulate low-quality sources
- Track quality ratings (🟢/🟡/🔴)

### Iterative Refinement
- After initial pass, check for gaps
- Conduct follow-up research if needed
- Max 3 iterations

## Deliverable Requirements

### Structure (Progressive Disclosure)
1. TL;DR (1-2 sentences)
2. Executive Summary (2-3 paragraphs)
3. Key Findings (with confidence indicators)
4. Detailed Analysis
5. So What: Implications & Recommendations
6. Methodology
7. Sources

### Quality Standards
- All claims sourced with URLs
- Confidence indicators on key findings
- "So What" section with actionable recommendations
- Methodology documented
- Limitations acknowledged

## Output
- Save report to: [output directory]
- Filename: [suggested filename]
[If Notion]: Upload to database: [DB_ID]
```

---

## Spawn Configuration

### Basic Spawn

```json
{
  "task": "<structured task brief>",
  "label": "research-<topic>",
  "model": "sonnet",
  "runTimeoutSeconds": 600
}
```

### With Extended Thinking

```json
{
  "task": "<structured task brief>",
  "label": "research-<topic>",
  "model": "sonnet",
  "thinking": "extended",
  "runTimeoutSeconds": 900
}
```

### Deep Analysis (Opus)

```json
{
  "task": "<structured task brief>",
  "label": "research-<topic>",
  "model": "opus",
  "thinking": "extended",
  "runTimeoutSeconds": 1200
}
```

---

## Examples

### Example 1: Simple Comparative (Sonnet, Standard)

**User:** "Compare Tailwind vs styled-components"

**Action:**
1. Type: `compare`
2. Mode: Exploratory
3. Config: Sonnet, standard (straightforward feature comparison)
4. MECE: Features, Performance, DX, Ecosystem, Use cases
5. Spawn with structured brief

**Confirmation:**
```
Researching Tailwind vs styled-components. I'll compare features, 
performance, developer experience, and ecosystem, then recommend 
which fits which use cases. Report in ~5 minutes.
```

### Example 2: Hypothesis-Driven (Sonnet + Extended)

**User:** "I think we should switch to Bun because it's faster"

**Action:**
1. Type: `feasibility` (or `cost-benefit`)
2. Mode: Hypothesis-driven ("Bun provides meaningful speed improvements for our use case")
3. Config: Sonnet + extended (testing a claim requires careful analysis)
4. MECE: Current perf, Bun benchmarks, Migration effort, Compatibility, Real-world cases
5. Spawn with hypothesis framework

**Confirmation:**
```
I'll test the hypothesis that Bun provides meaningful speed improvements 
for your use case. Using extended thinking to carefully evaluate the 
evidence. Will report whether the hypothesis is supported, refuted, 
or needs refinement.
```

### Example 3: Complex Technical (Opus + Extended)

**User:** "Research the architectural trade-offs of event sourcing for our transaction system"

**Action:**
1. Type: `technical`
2. Mode: Exploratory (complex domain)
3. Config: Opus + extended (nuanced trade-offs, many sources, synthesis required)
4. MECE: Core concepts, Benefits, Challenges, Implementation patterns, Our constraints, Alternatives
5. Spawn with deep analysis brief

**Confirmation:**
```
This is a complex architectural question. Using Opus with extended 
thinking for maximum depth. I'll analyze event sourcing trade-offs 
specifically for transaction systems, including implementation patterns 
and alternatives. Expect a thorough report in ~15 minutes.
```

### Example 4: Ask When Uncertain

**User:** "Research whether we should adopt Kubernetes"

**Action:**
1. Type: `feasibility`
2. Config uncertain: Could be simple overview or complex analysis

**Response:**
```
This K8s research could go different directions:

• **Quick overview** (Sonnet): Pros/cons, when it makes sense, 5 min
• **Thorough analysis** (Sonnet + Extended): Detailed for your context, 10 min  
• **Deep investigation** (Opus + Extended): Full architectural analysis, 15 min

What level of depth do you need?
```

---

## References

- **Task Templates:** `references/task-templates.md` – Complete templates for all research types
- **Planning Frameworks:** `references/planning-frameworks.md` – MECE patterns, hypothesis frameworks
- **Quality Standards:** `references/quality-standards.md` – Source evaluation, confidence, methodology
- **Notion Upload Guide:** `references/notion-upload-guide.md` – Batching, verification, error handling for large uploads

## Notes

- Default timeout: 600s; increase for extended thinking (900s) or Opus (1200s)
- Reports saved to `~/clawd/reports/` by default
- Sub-agents can spawn additional sub-agents for MECE sub-questions if needed
- Hypothesis-driven mode is more efficient when testing specific claims
- Always drive to "So What" – actionable insights over comprehensiveness
