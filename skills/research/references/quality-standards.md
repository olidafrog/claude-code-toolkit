# Quality Standards

Reference for source evaluation, confidence indicators, methodology documentation, and research quality validation.

---

## Source Quality Evaluation

### Source Quality Hierarchy

| Tier | Source Type | Weight | Example |
|------|-------------|--------|---------|
| **1** | Official documentation | 3x | Docs, specs, official blogs |
| **1** | Peer-reviewed research | 3x | Academic papers, journals |
| **2** | Industry reports | 2x | Gartner, analyst reports |
| **2** | Expert analysis | 2x | Recognized experts, deep-dive articles |
| **3** | Community consensus | 1.5x | Reddit, HN with multiple agreeing voices |
| **3** | Case studies | 1.5x | Published experiences with results |
| **4** | General web | 1x | Blog posts, tutorials (requires triangulation) |
| **5** | Unverified | 0.5x | Single sources, rumors, speculation |

### Source Evaluation Checklist

For each source, assess:

```
□ AUTHORITY
  - Is the author/org credible on this topic?
  - What are their credentials/track record?

□ ACCURACY
  - Can claims be verified independently?
  - Are there citations/evidence?

□ CURRENCY
  - How recent is the information?
  - Is it still relevant?

□ OBJECTIVITY
  - Is there potential bias?
  - Is it promotional/sponsored content?

□ COVERAGE
  - Is it comprehensive or selective?
  - What's missing?
```

### Red Flags

Watch for these quality issues:

| Red Flag | Risk | Mitigation |
|----------|------|------------|
| No author attribution | Low accountability | Triangulate with other sources |
| Promotional tone | Bias | Seek independent sources |
| No citations | Unverified claims | Find primary sources |
| Very old (>2 years for tech) | Outdated | Find recent sources |
| Single source for claim | Could be wrong | Require 2+ sources |
| AI-generated content | May hallucinate | Verify against primary sources |

### Triangulation Requirements

For claims supported only by lower-tier sources:

| Source Tier | Triangulation Requirement |
|-------------|---------------------------|
| Tier 1-2 | Single source acceptable |
| Tier 3 | Prefer 2 sources |
| Tier 4 | Require 2+ independent sources |
| Tier 5 | Require 3+ sources OR upgrade to higher tier |

---

## Confidence Indicators

### Three-Level System

| Indicator | Meaning | Display | Criteria |
|-----------|---------|---------|----------|
| 🟢 | **High confidence** | Use for decisions | 3+ quality sources, consistent findings |
| 🟡 | **Medium confidence** | Use with caution | 1-2 sources, OR some inconsistency |
| 🔴 | **Low confidence** | Verify before using | Single source, unverified, speculation |

### When to Apply Confidence Indicators

Apply to:
- Key findings and conclusions
- Specific claims (especially quantitative)
- Recommendations

Don't apply to:
- Background information
- Definitions
- Obvious facts

### Example Usage

```markdown
## Key Findings

### Performance
MongoDB handles 100K+ reads/sec with proper indexing 🟢
(Confirmed by official benchmarks + 3 production case studies)

Migration typically takes 2-6 weeks 🟡
(Based on 2 case studies; varies significantly by complexity)

### Reliability
Some users report data consistency issues under load 🔴
(Single Reddit thread; not reproduced in official testing)
```

### Aggregating Confidence

For synthesis/recommendations based on multiple findings:

| Underlying Confidence | Synthesis Confidence |
|-----------------------|---------------------|
| All 🟢 | 🟢 |
| Mix of 🟢 and 🟡 | 🟡 |
| Any 🔴 critical findings | 🔴 (note uncertainty) |

---

## Methodology Documentation

### Why Document Methodology

- **Reproducibility:** Others can verify findings
- **Trust:** Transparency builds confidence
- **Improvement:** Learn from what worked
- **Limitations:** Honest about constraints

### Methodology Section Template

```markdown
## Methodology

### Search Strategy
- **Sources searched:** [List source types: official docs, academic, community, etc.]
- **Search terms:** [Key terms used]
- **Date range:** [If time-bounded]
- **Geographic focus:** [If location-specific]

### Selection Criteria
- **Included:** [What made the cut]
- **Excluded:** [What was filtered out and why]

### Quality Assessment
- **Sources evaluated:** [N]
- **Sources included:** [N]
- **Primary exclusion reasons:** [Brief list]

### Synthesis Approach
- [How findings were combined and analyzed]

### Limitations
- [Known limitation 1]
- [Known limitation 2]
- [Areas not covered and why]
```

### Common Limitations to Acknowledge

| Limitation | Description |
|------------|-------------|
| **Time constraints** | Limited depth due to time |
| **Source availability** | Some sources paywalled/unavailable |
| **Language** | Only English sources consulted |
| **Recency** | Fast-moving field, may already be dated |
| **Bias risk** | Specific sources may have bias |
| **Sample** | Community opinions may not be representative |

---

## Research Quality Checklist

### Before Research

```
□ Research question is specific and answerable
□ Scope is defined (what's in/out)
□ Success criteria established
□ MECE sub-questions defined
□ Source strategy identified
```

### During Research

```
□ Sources evaluated for quality
□ Quality ratings applied (Tier 1-5)
□ Triangulation applied for low-tier sources
□ Contradictions noted
□ Gaps identified
□ Search expanded if needed
```

### After Research (Before Delivery)

```
□ All sub-questions addressed
□ All claims have sources
□ Confidence indicators applied
□ "So What" section is actionable
□ Methodology documented
□ Limitations acknowledged
□ Contradictions resolved or explained
□ Progressive disclosure structure (TL;DR → Details)
□ Next steps defined
```

---

## Iterative Refinement Protocol

### Quality Threshold Check

After initial research pass:

```
1. SUB-QUESTION COVERAGE
   □ All MECE sub-questions addressed
   If NO → Identify gaps → Research gaps

2. EVIDENCE STRENGTH
   □ At least 2 sources per key claim
   If NO → Find additional sources OR note confidence

3. CONSISTENCY
   □ Major contradictions resolved or explained
   If NO → Research to resolve OR document uncertainty

4. ACTIONABILITY
   □ "So What" provides specific recommendations
   If NO → Strengthen recommendations with evidence
```

### Refinement Loop

```
┌─────────────────────────────────────────┐
│        Initial Research Pass            │
└────────────────┬────────────────────────┘
                 ↓
┌─────────────────────────────────────────┐
│      Quality Threshold Check            │
│  □ Coverage □ Evidence □ Consistency    │
└────────────────┬────────────────────────┘
                 ↓
         ┌──────┴──────┐
         │  Pass?      │
         └──────┬──────┘
           NO   │   YES
            ↓   │    ↓
┌───────────────┴──┐  ┌─────────────────┐
│ Targeted         │  │ Proceed to      │
│ Follow-up        │  │ Synthesis       │
│ Research         │  │                 │
└────────┬─────────┘  └─────────────────┘
         │
         ↓ (max 3 iterations)
   [Loop back to check]
```

### When to Stop Iterating

- Quality threshold met
- Maximum iterations reached (3)
- Diminishing returns (additional research not improving quality)
- Time/resource constraints

---

## "So What" Framework

### The Three Levels

| Level | Question | Example |
|-------|----------|---------|
| **Observation** | What does the data show? | "Load times average 3.2 seconds" |
| **Analysis** | Why does this matter? | "This exceeds acceptable UX threshold" |
| **So What** | What should we do? | "Implement lazy loading to cut 40%" |

### "So What" Section Template

```markdown
## So What: Key Implications

### What This Means
[Synthesis of findings into meaningful insight—not just summary]

### Recommended Actions
1. **[Action 1]** – [Brief rationale]
2. **[Action 2]** – [Brief rationale]
3. **[Action 3]** – [Brief rationale]

### Decision Framework
[Conditional recommendations]
- If [condition A], then [recommendation]
- If [condition B], then [recommendation]
- If [condition C], then [recommendation]

### What We Don't Know
[Key uncertainties that could change recommendations]
```

### Weak vs Strong "So What"

| Weak (Just Observations) | Strong (Actionable) |
|--------------------------|---------------------|
| "MongoDB is faster for reads" | "Use MongoDB if read-heavy workload; stick with Postgres if ACID critical" |
| "Costs range from $500-2000/mo" | "At your scale, expect $800/mo; budget $1200 for safety margin" |
| "Users report mixed experiences" | "3 patterns of success: X, Y, Z. Avoid: A, B" |

---

## Quick Reference Card

### Source Quality Tiers
1. Official docs, peer-reviewed (3x weight)
2. Industry reports, experts (2x weight)
3. Community consensus, case studies (1.5x weight)
4. General web (1x, triangulate)
5. Unverified (0.5x, avoid)

### Confidence Indicators
- 🟢 High: 3+ quality sources, consistent
- 🟡 Medium: 1-2 sources, some inconsistency
- 🔴 Low: single source, unverified

### "So What" Formula
Observation → Analysis → So What (Action)

### Iteration Rule
Max 3 passes; stop when quality threshold met or diminishing returns
