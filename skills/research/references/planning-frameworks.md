# Planning Frameworks

Reference for research planning: MECE decomposition, hypothesis-driven investigation, and research planning patterns.

---

## MECE Framework

**MECE** = Mutually Exclusive, Collectively Exhaustive

### Core Principles

- **Mutually Exclusive:** Categories don't overlap (no double-counting)
- **Collectively Exhaustive:** Categories cover all possibilities (no gaps)

### Why MECE Matters

Without MECE:
```
Research Question: "Why are users churning?"
Sub-questions (BAD):
- Are users unhappy with pricing? ← overlaps with value
- Is the product too hard to use? ← overlaps with UX
- Do users not see value? ← overlaps with pricing
- Is the UX bad? ← overlaps with hard to use
```

With MECE:
```
Research Question: "Why are users churning?"
Sub-questions (GOOD):
1. External factors (market, competition)
2. Acquisition issues (wrong users)
3. Activation issues (never got value)
4. Product issues (got value, then problems)
5. Support issues (couldn't get help)
```

### MECE Decomposition Patterns

#### Pattern 1: Lifecycle/Process
Break by stages of a process:

```
Before → During → After
Input → Process → Output
Acquire → Activate → Retain → Revenue → Refer
```

**Example:** "Why is conversion low?"
```
├── Awareness stage issues
├── Consideration stage issues
├── Decision stage issues
└── Purchase stage issues
```

#### Pattern 2: Internal vs External
Break by source/origin:

```
Internal factors (within control)
External factors (outside control)
```

**Example:** "Why did the project fail?"
```
├── Internal factors
│   ├── Team issues
│   ├── Technical issues
│   └── Process issues
└── External factors
    ├── Market changes
    ├── Competitor actions
    └── Regulatory changes
```

#### Pattern 3: Quantitative vs Qualitative
Break by measurement type:

```
Quantitative (measurable)
Qualitative (subjective)
```

**Example:** "How good is this solution?"
```
├── Quantitative metrics
│   ├── Performance
│   ├── Cost
│   └── Scalability
└── Qualitative factors
    ├── Developer experience
    ├── Community support
    └── Future trajectory
```

#### Pattern 4: Problem/Solution
Break by diagnosis vs prescription:

```
What is the problem?
What are the solutions?
What is the recommendation?
```

#### Pattern 5: Stakeholder-Based
Break by who is affected:

```
Users
Business
Engineering
Operations
```

#### Pattern 6: Time-Based
Break by temporal dimension:

```
Past (what happened)
Present (current state)
Future (trajectory)
```

### MECE Examples by Research Type

#### Comparative Analysis MECE
```
Compare X vs Y
├── What they do (capabilities)
├── How they differ (differentiators)
├── Where they fall short (limitations)
├── When to use each (context)
└── What others say (validation)
```

#### Feasibility Study MECE
```
Is X feasible?
├── Technical viability
├── Resource requirements
├── Risk factors
├── Alternatives
└── Go/no-go factors
```

#### Cost-Benefit MECE
```
Is X worth it?
├── Direct costs
├── Indirect costs
├── Direct benefits
├── Indirect benefits
└── Net assessment
```

---

## Hypothesis-Driven Investigation

### When to Use

| Use Hypothesis-Driven | Use Exploratory |
|-----------------------|-----------------|
| User has a belief to test | Unknown territory |
| Specific claim to validate | Landscape mapping |
| Decision-focused | Learning-focused |
| Time-constrained | Thorough understanding needed |

### Hypothesis Format

```
Hypothesis: [Specific, falsifiable statement]
Test by examining: [What evidence would support/refute]
Decision criteria: [How to interpret results]
```

**Good Hypothesis Examples:**
- "Switching to Postgres RDS will reduce our operational overhead significantly"
- "React Native is mature enough for our enterprise mobile app requirements"
- "The performance issues are caused by N+1 queries, not database sizing"

**Bad Hypothesis Examples:**
- "React is good" (not specific)
- "We should use microservices" (not falsifiable)
- "The system is slow" (just an observation)

### Hypothesis Testing Framework

```
1. STATE HYPOTHESIS
   What do you believe? Why?

2. DEFINE EVIDENCE CRITERIA
   What would support it?
   What would refute it?
   What would be inconclusive?

3. GATHER EVIDENCE
   Look for both supporting AND contradicting evidence
   (Actively seek disconfirmation)

4. ASSESS EVIDENCE
   Weight by source quality
   Note confidence levels

5. VERDICT
   □ Supported (proceed with confidence)
   □ Partially supported (proceed with caveats)
   □ Refuted (abandon or revise)
   □ Inconclusive (need more evidence)

6. REFINE (if needed)
   Update hypothesis based on evidence
```

### Avoiding Confirmation Bias

Common traps:
- Only searching for supporting evidence
- Dismissing contradicting evidence
- Over-weighting sources that agree

Countermeasures:
- Explicitly search for contradicting evidence
- Give equal weight to all quality sources
- Steel-man the opposing view
- Ask: "What would change my mind?"

---

## Research Planning Template

Use this template to plan research before execution:

```markdown
# Research Plan

## 1. Question Definition

**Main Question:** [Clear, specific question]

**Success Criteria:** [What does a good answer look like?]

**Scope Boundaries:**
- In scope: [What to cover]
- Out of scope: [What to exclude]
- Depth: [Surface / Standard / Deep]

## 2. Mode Selection

**Mode:** □ Exploratory  □ Hypothesis-Driven

**If Hypothesis-Driven:**
- Hypothesis: [Statement]
- Support evidence: [What to look for]
- Refute evidence: [What would disprove]

## 3. MECE Decomposition

**Sub-Questions:**
1. [Sub-Q1] → Sources: [types]
2. [Sub-Q2] → Sources: [types]
3. [Sub-Q3] → Sources: [types]
4. [Sub-Q4] → Sources: [types]
5. [Sub-Q5] → Sources: [types]

**MECE Check:**
- [ ] No overlaps between sub-questions
- [ ] All aspects of main question covered

## 4. Source Strategy

| Sub-Question | Source Types | Quality Threshold | Min Sources |
|--------------|--------------|-------------------|-------------|
| SQ1 | [types] | 🟢/🟡/🔴 | [N] |
| SQ2 | [types] | 🟢/🟡/🔴 | [N] |
| ... | ... | ... | ... |

## 5. Quality Checkpoints

After initial pass:
- [ ] All sub-questions addressed
- [ ] Minimum sources per claim
- [ ] Contradictions noted
- [ ] Gaps identified

## 6. Deliverable Structure

- [ ] TL;DR
- [ ] Executive Summary  
- [ ] [Section 1]
- [ ] [Section 2]
- [ ] So What section
- [ ] Methodology
- [ ] Sources
```

---

## Issue Trees

Issue trees are visual MECE decompositions used in consulting:

### Problem-Solving Issue Tree

```
Problem: Revenue is declining
│
├── Volume declining?
│   ├── Market shrinking?
│   ├── Losing share?
│   └── Mix shifting?
│
└── Price declining?
    ├── Competitive pressure?
    ├── Mix shifting?
    └── Discounting?
```

### Solution Issue Tree

```
How to grow revenue?
│
├── Increase volume
│   ├── Acquire new customers
│   ├── Increase usage per customer
│   └── Reduce churn
│
└── Increase price
    ├── Raise prices
    ├── Shift mix to premium
    └── Reduce discounting
```

### Hypothesis Tree

```
Hypothesis: We should migrate to cloud
│
├── Cost hypothesis
│   ├── Reduces infrastructure cost
│   ├── Reduces ops cost
│   └── Capex → Opex benefits
│
├── Capability hypothesis
│   ├── Enables scalability
│   ├── Enables new features
│   └── Improves reliability
│
└── Strategic hypothesis
    ├── Industry moving this way
    ├── Talent expects it
    └── Competitive necessity
```

---

## The "Five Whys" Technique

Drill down to root cause by asking "Why?" repeatedly:

```
Problem: API latency is high

Why? → Database queries are slow
Why? → Too many queries per request
Why? → N+1 query pattern in the code
Why? → ORM eager loading not configured
Why? → Team wasn't aware of the pattern

Root Cause: Knowledge gap in team
Solution: Training + code review checklist
```

---

## Quick Reference: Planning Checklist

Before starting any research:

```
□ Question is specific and answerable
□ Scope is defined (in/out)
□ Mode selected (exploratory/hypothesis)
□ Sub-questions are MECE
□ Sources identified per sub-question
□ Quality thresholds set
□ Deliverable structure planned
□ Success criteria defined
```
