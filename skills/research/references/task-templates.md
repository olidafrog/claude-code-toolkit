# Research Task Templates (v2)

Enhanced templates implementing meta-research best practices: MECE decomposition, source quality tracking, confidence indicators, "So What" enforcement, and iterative refinement.

---

## Template Structure

Every template includes:
1. **Type definition** – What this research is for
2. **Mode selection** – When to use exploratory vs hypothesis-driven
3. **Model guidance** – When Sonnet vs Opus + thinking selection (RETAINED)
4. **MECE framework** – Standard decomposition pattern
5. **Source strategy** – What sources to consult and quality thresholds
6. **Quality requirements** – Confidence, methodology, validation
7. **Deliverable structure** – Progressive disclosure format

---

## Model & Thinking Mode Selection (RETAINED)

### Model Selection

| Scenario | Model | Rationale |
|----------|-------|-----------|
| Straightforward information gathering | **Sonnet** | Efficient, cost-effective |
| Clear parameters, well-defined questions | **Sonnet** | Good results, fast |
| Complex analysis, many sources | **Opus** | Deeper reasoning |
| Nuanced synthesis, conflicting info | **Opus** | Sophisticated interpretation |

**Default to Sonnet** unless research clearly requires Opus-level reasoning.

### Extended Thinking Selection

| Scenario | Thinking | Rationale |
|----------|----------|-----------|
| Fact-finding, simple summarization | **Standard** | Speed, efficiency |
| Complex reasoning, contradictions | **Extended** | Better analysis |
| Multi-step problems, synthesis | **Extended** | Structured decomposition |

**Sweet Spot:** Sonnet + Extended = capable research at reasonable cost

---

## compare

### Type Definition
**Research Type:** Comparative Analysis

**Objective:** Compare two or more options across multiple dimensions to support decision-making.

### Mode Selection
- **Exploratory:** Use when exploring unfamiliar options
- **Hypothesis-Driven:** Use when user leans toward one option ("I think X is better because...")

### Model Guidance
| Scenario | Config |
|----------|--------|
| Simple feature/price comparison | Sonnet (standard) |
| Multiple dimensions, trade-offs | Sonnet + Extended |
| Complex, many conflicting sources | Opus + Extended |

### MECE Framework

Standard decomposition for comparisons:

```
Main Question: "Compare X vs Y for use case Z"
├── 1. Core Capabilities
│   ├── What can X do?
│   └── What can Y do?
├── 2. Key Differentiators  
│   ├── Where does X excel?
│   └── Where does Y excel?
├── 3. Limitations & Trade-offs
│   ├── X's weaknesses
│   └── Y's weaknesses
├── 4. Context Fit
│   ├── When to choose X
│   └── When to choose Y
└── 5. External Validation
    ├── What do users say?
    └── What do experts recommend?
```

### Source Strategy
| Sub-Question | Sources | Quality Threshold |
|--------------|---------|-------------------|
| Capabilities | Official docs | 🟢 High |
| Differentiators | Docs + expert reviews | 🟢 High |
| Limitations | Community (Reddit, HN) | 🟡 Medium (triangulate) |
| Context fit | Case studies, comparisons | 🟡 Medium |
| Validation | Community consensus | 🟡 Medium |

### Deliverable Structure

```markdown
# [X] vs [Y]: Comparative Analysis

## TL;DR
[1-2 sentence recommendation]

## Executive Summary
[2-3 paragraphs: key differences, recommendation, conditions]

## Quick Comparison

| Dimension | [X] | [Y] |
|-----------|-----|-----|
| [Dim 1] | ... | ... |
| [Dim 2] | ... | ... |

## Detailed Analysis

### Core Capabilities
[Analysis with sources]

### Key Differentiators  
[What makes each unique]

### Limitations & Trade-offs
[Honest assessment of weaknesses]

### Context Fit
[When to choose which]

## So What: Recommendation

### Bottom Line
[Clear recommendation with conditions]

### Decision Framework
- Choose [X] if: [conditions]
- Choose [Y] if: [conditions]

### Confidence Assessment
- Overall confidence: [🟢/🟡/🔴]
- Key uncertainty: [What we're less sure about]

## Methodology
[Sources consulted, search strategy, limitations]

## Sources
[Full citations with URLs]
```

---

## feasibility

### Type Definition
**Research Type:** Feasibility Study

**Objective:** Evaluate whether a proposed solution is technically viable, practically implementable, and worth pursuing.

### Mode Selection
- **Exploratory:** When assessing unknown territory
- **Hypothesis-Driven:** When testing "Can we do X?" or "Is X possible?"

### Model Guidance
| Scenario | Config |
|----------|--------|
| Straightforward viability check | Sonnet (standard) |
| Multi-step dependencies | Sonnet + Extended |
| Complex interdependencies | Opus + Extended |

### MECE Framework

```
Main Question: "Is [approach X] feasible for [context Y]?"
├── 1. Technical Viability
│   ├── Is it technically possible?
│   └── What are technical prerequisites?
├── 2. Practical Implementation
│   ├── What resources are required?
│   └── What is the implementation path?
├── 3. Risks & Challenges
│   ├── What could go wrong?
│   └── How do we mitigate risks?
├── 4. Alternatives
│   ├── What other approaches exist?
│   └── Why is this approach preferred?
└── 5. Decision Factors
    ├── What conditions make this feasible?
    └── What conditions make it infeasible?
```

### Source Strategy
| Sub-Question | Sources | Quality Threshold |
|--------------|---------|-------------------|
| Technical viability | Official docs, technical specs | 🟢 High |
| Implementation | Tutorials, case studies, GitHub | 🟡 Medium |
| Risks | Community experiences, post-mortems | 🟡 Medium |
| Alternatives | Market research, expert opinions | 🟡 Medium |
| Decision factors | Synthesis of above | N/A |

### Deliverable Structure

```markdown
# Feasibility Study: [Approach X]

## TL;DR
[Feasible/Not feasible/Conditionally feasible + key condition]

## Executive Summary
[2-3 paragraphs: viability assessment, key factors, recommendation]

## Feasibility Assessment

### Technical Viability 🟢/🟡/🔴
[Is it technically possible?]

### Resource Requirements
| Resource | Requirement | Availability |
|----------|-------------|--------------|
| Time | ... | ... |
| Skills | ... | ... |
| Cost | ... | ... |

### Implementation Path
1. [Step 1]
2. [Step 2]
3. [Step 3]

### Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| ... | ... | ... | ... |

### Alternatives Considered
[Other approaches and why this one]

## So What: Go/No-Go Assessment

### Verdict
[Clear recommendation: Proceed / Don't proceed / Proceed with conditions]

### Key Conditions
- Feasible if: [conditions]
- Not feasible if: [conditions]

### Confidence Assessment
- Overall confidence: [🟢/🟡/🔴]
- Key uncertainty: [What would change the assessment]

## Next Steps (If Feasible)
1. [Immediate action]
2. [Subsequent action]

## Methodology
[Sources consulted, search strategy, limitations]

## Sources
[Full citations with URLs]
```

---

## cost-benefit

### Type Definition
**Research Type:** Cost-Benefit Analysis

**Objective:** Quantify costs and benefits to determine if a decision is worthwhile.

### Mode Selection
- **Exploratory:** When unknown costs/benefits
- **Hypothesis-Driven:** When testing "Is X worth it?"

### Model Guidance
| Scenario | Config |
|----------|--------|
| Quantitative comparison (clear metrics) | Sonnet (standard) |
| Mix of qualitative factors | Sonnet + Extended |
| Complex multi-factor analysis | Opus + Extended |

### MECE Framework

```
Main Question: "Is [decision X] worth it?"
├── 1. Costs (Direct)
│   ├── Upfront costs
│   └── Ongoing costs
├── 2. Costs (Indirect)
│   ├── Hidden costs
│   └── Opportunity costs
├── 3. Benefits (Direct)
│   ├── Immediate benefits
│   └── Long-term benefits
├── 4. Benefits (Indirect)
│   ├── Strategic benefits
│   └── Intangible benefits
└── 5. Net Assessment
    ├── ROI calculation
    └── Break-even analysis
```

### Deliverable Structure

```markdown
# Cost-Benefit Analysis: [Decision X]

## TL;DR
[Worth it / Not worth it + ROI summary]

## Executive Summary
[2-3 paragraphs: costs, benefits, net assessment]

## Cost Breakdown

### Direct Costs
| Cost | Amount | Frequency | Confidence |
|------|--------|-----------|------------|
| ... | ... | ... | 🟢/🟡/🔴 |

### Indirect Costs
[Hidden costs, opportunity costs]

### Total Cost Estimate
- Best case: $X
- Expected: $Y  
- Worst case: $Z

## Benefit Analysis

### Quantifiable Benefits
| Benefit | Value | Timeframe | Confidence |
|---------|-------|-----------|------------|
| ... | ... | ... | 🟢/🟡/🔴 |

### Non-Quantifiable Benefits
[Strategic, intangible benefits with importance rating]

## Net Assessment

### ROI Calculation
[Show the math]

### Break-Even Point
[When does this pay off?]

### Sensitivity Analysis
| Scenario | Outcome |
|----------|---------|
| Best case | ... |
| Expected | ... |
| Worst case | ... |

## So What: Recommendation

### Verdict
[Worth it / Not worth it / Conditional]

### Decision Framework
- Worth it if: [conditions]
- Not worth it if: [conditions]

## Methodology & Sources
```

---

## market

### Type Definition
**Research Type:** Market Research

**Objective:** Understand the landscape of solutions, trends, and best practices in a domain.

### Mode Selection
- **Exploratory:** Default for market research (landscape mapping)
- **Hypothesis-Driven:** When testing "Is X the market leader because Y?"

### Model Guidance
| Scenario | Config |
|----------|--------|
| Landscape overview | Sonnet (standard) |
| Trend analysis, pattern identification | Sonnet + Extended |
| Deep competitive analysis | Opus + Extended |

### MECE Framework

```
Main Question: "What is the landscape for [domain X]?"
├── 1. Market Structure
│   ├── What categories exist?
│   └── How is the market segmented?
├── 2. Key Players
│   ├── Who are the leaders?
│   └── Who are the challengers?
├── 3. Trends & Dynamics
│   ├── What's changing?
│   └── Where is it heading?
├── 4. User Needs
│   ├── What problems are being solved?
│   └── What gaps remain?
└── 5. Recommendations
    ├── Top options by use case
    └── Emerging opportunities
```

### Deliverable Structure

```markdown
# Market Research: [Domain]

## TL;DR
[Key insight about the market]

## Executive Summary
[2-3 paragraphs: landscape overview, trends, recommendations]

## Market Overview

### Market Structure
[Categories, segments, size if available]

### Landscape Map
| Category | Leaders | Challengers | Niche |
|----------|---------|-------------|-------|
| ... | ... | ... | ... |

## Key Players

### Leaders
[Who and why they lead]

### Rising Challengers
[Who's disrupting and how]

## Trends & Dynamics

### Current Trends 🟢
[What's happening now]

### Emerging Trends 🟡
[What's likely coming]

### User Pain Points
[Unmet needs and gaps]

## So What: Recommendations

### Top Options by Use Case
| Use Case | Recommendation | Why |
|----------|----------------|-----|
| ... | ... | ... |

### Opportunities
[Gaps in the market, emerging areas]

## Methodology & Sources
```

---

## technical

### Type Definition
**Research Type:** Technical Investigation

**Objective:** Deep dive into technical details, implementation patterns, and best practices.

### Mode Selection
- **Exploratory:** When learning new technology
- **Hypothesis-Driven:** When testing "X works by doing Y"

### Model Guidance
| Scenario | Config |
|----------|--------|
| Standard investigation | Sonnet + Extended |
| Complex systems, edge cases | Opus + Extended |

**Note:** Technical research usually benefits from extended thinking to catch errors in reasoning.

### MECE Framework

```
Main Question: "How does [technology X] work / How to implement [pattern Y]?"
├── 1. Core Concepts
│   ├── What is it?
│   └── How does it work?
├── 2. Architecture & Design
│   ├── Key components
│   └── How they interact
├── 3. Implementation Patterns
│   ├── Common approaches
│   └── Best practices
├── 4. Pitfalls & Solutions
│   ├── Common mistakes
│   └── How to avoid/fix them
├── 5. Production Considerations
│   ├── Performance characteristics
│   └── Scaling patterns
└── 6. Learning Path
    ├── Where to start
    └── Resources
```

### Deliverable Structure

```markdown
# Technical Deep Dive: [Technology/Pattern]

## TL;DR
[Core insight]

## Executive Summary
[2-3 paragraphs: what it is, key patterns, recommendations]

## Core Concepts

### What It Is
[Explanation with diagrams if helpful]

### How It Works
[Technical explanation]

## Architecture & Design
[Components, interactions, diagrams]

## Implementation Patterns

### Pattern 1: [Name]
```code
[Example code]
```
[When to use, trade-offs]

### Pattern 2: [Name]
[...]

## Pitfalls & Solutions

| Pitfall | Impact | Solution |
|---------|--------|----------|
| ... | ... | ... |

## Production Considerations

### Performance
[Characteristics, benchmarks if available]

### Scaling
[Patterns, limits]

## So What: Recommendations

### Getting Started
[Recommended approach]

### Key Decisions
[What you'll need to decide]

## Resources
[Ranked list of learning resources]

## Methodology & Sources
```

---

## general

### Type Definition
**Research Type:** General Research

**Objective:** Comprehensive investigation of a topic to build understanding and provide insights.

### Mode Selection
- **Exploratory:** Default for general research
- **Hypothesis-Driven:** When testing a specific belief

### Model Guidance
| Scenario | Config |
|----------|--------|
| Basic information gathering | Sonnet (standard) |
| Synthesis required | Sonnet + Extended |
| Highly complex, nuanced | Opus + Extended |

### MECE Framework

Adapt to the topic. Generic structure:

```
Main Question: "What should I know about [topic X]?"
├── 1. Background & Context
│   ├── What is it?
│   └── Why does it matter?
├── 2. Current State
│   ├── What's happening now?
│   └── Key facts and figures
├── 3. Key Perspectives
│   ├── Different approaches/views
│   └── Points of agreement/disagreement
├── 4. Trade-offs & Considerations
│   ├── Pros and cons
│   └── Nuances to understand
└── 5. Implications
    ├── What does this mean for [context]?
    └── What actions to consider
```

### Deliverable Structure

```markdown
# Research: [Topic]

## TL;DR
[Key insight]

## Executive Summary
[2-3 paragraphs]

## Background & Context
[What it is, why it matters]

## Current State
[Key facts, recent developments]

## Key Perspectives
[Different viewpoints, areas of agreement/disagreement]

## Trade-offs & Considerations
[Nuances, pros/cons]

## So What: Implications

### What This Means
[Synthesis into meaningful insight]

### Recommended Actions
1. [Action with rationale]
2. [Action with rationale]

### Open Questions
[What remains unclear]

## Methodology & Sources
```

---

## Notion Upload Requirements

When uploading research reports to Notion:

1. **Use correct API version** (CRITICAL)
   - ALWAYS use `Notion-Version: 2022-06-28`
   - NEVER use `2025-09-03` or any 2025+ versions (silent failures)
   - This applies to ALL Notion API calls (create, update, query)

2. **Batch large uploads** (critical for reports >100 blocks)
   - Create page with properties first
   - Split content into batches of 100 blocks
   - Upload each batch with verification
   - Add 0.4s delay between batches
   
3. **Verify upload success**
   - Check block count after each batch
   - Verify final total matches expected
   - Return confirmation with block count

4. **Handle failures gracefully**
   - If batch fails, return partial upload warning
   - Include URL, blocks uploaded, and error message

See `references/notion-upload-guide.md` for complete details.

---


## Universal Requirements (All Templates)

### Quality Standards

Every research report must include:

1. **TL;DR** – One-line answer for quick consumption
2. **Executive Summary** – 2-3 paragraphs with key findings
3. **Confidence Indicators** – 🟢/🟡/🔴 on key findings
4. **"So What" Section** – Actionable implications, not just observations
5. **Methodology** – How research was conducted
6. **Sources** – All claims cited with URLs

### Confidence Indicators

| Indicator | Meaning | Criteria |
|-----------|---------|----------|
| 🟢 High | Strong evidence | 3+ quality sources, consistent |
| 🟡 Medium | Moderate evidence | 1-2 sources, some inconsistency |
| 🔴 Low | Weak evidence | Single source, unverified |

### Source Citation Format

```
[Claim] (Source: [Title], [Date], [URL])
```

### Iterative Refinement Checklist

After initial research:
```
□ All MECE sub-questions addressed?
□ At least 2 sources per key claim?
□ Contradictions resolved or explained?
□ "So What" is actionable?
□ Confidence levels indicated?

If any NO → Conduct targeted follow-up
```

---

## Hypothesis-Driven Template Addendum

When using hypothesis-driven mode, add this section:

```markdown
## Hypothesis Assessment

### Original Hypothesis
[Statement being tested]

### Evidence For
- [Evidence 1] (Source, 🟢/🟡/🔴)
- [Evidence 2] (Source, 🟢/🟡/🔴)

### Evidence Against  
- [Evidence 1] (Source, 🟢/🟡/🔴)
- [Evidence 2] (Source, 🟢/🟡/🔴)

### Verdict
- [ ] **Supported** – Evidence strongly supports the hypothesis
- [ ] **Partially Supported** – Some support, with caveats
- [ ] **Refuted** – Evidence contradicts the hypothesis
- [ ] **Inconclusive** – Insufficient evidence either way

### Refined Hypothesis (if applicable)
[Updated hypothesis based on evidence]
```
