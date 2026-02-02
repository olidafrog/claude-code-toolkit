---
name: spec-writer
description: Interview user in-depth to create a detailed project specification. Use when asked to "create a spec", "spec out a project", "interview me about a feature", or "help me think through" a project idea.
---

# spec-writer

Deep-dive interview process to transform vague ideas into comprehensive specifications.

## Trigger Phrases
- "Create a spec for..."
- "Spec out this project"
- "Interview me about..."
- "Help me think through..."
- "I want to build..."
- "Write a specification for..."

## Core Principles

1. **Ask non-obvious questions** - Don't ask what they already told you
2. **Go deep, not wide** - Follow interesting threads before moving on
3. **Challenge assumptions** - "Why X instead of Y?"
4. **Uncover hidden complexity** - Edge cases, failure modes, scale concerns
5. **One question at a time** - Let answers inform the next question
6. **Know when to stop** - Don't over-interview; recognize completeness

## Interview Flow

### Phase 1: Problem & Context
Understand the why before the what.

- What problem does this solve? For whom?
- What's the current workaround (if any)?
- What triggered this now? Why is it important?
- Who are the stakeholders? Who decides success?
- What does failure look like?

**Non-obvious probes:**
- "What would make this not worth building?"
- "If you could only solve one part, which?"
- "Who would be upset if this shipped tomorrow?"

### Phase 2: Scope & Boundaries
Define the edges before filling the middle.

- What's explicitly OUT of scope?
- What's the MVP vs. the vision?
- What existing systems does this touch?
- What can you NOT change?
- What's the timeline pressure?

**Non-obvious probes:**
- "What would you cut if you had half the time?"
- "What's the most controversial decision you've already made?"
- "What are you intentionally ignoring for now?"

### Phase 3: Technical Architecture
Only ask what's relevant to their context.

- What's the deployment target? (web, mobile, CLI, API, etc.)
- What existing stack/infra must this use?
- What data exists? What's the source of truth?
- What are the performance requirements?
- What are the security/privacy constraints?

**Non-obvious probes:**
- "What's the scariest technical risk?"
- "Where would you expect the first production bug?"
- "What would make this 10x harder?"

### Phase 4: User Experience
Focus on flows, not screens.

- Walk me through the critical user journey
- What's the first thing a user sees/does?
- What information do they need at each step?
- What are the error states? How do users recover?
- What's the "aha moment"?

**Non-obvious probes:**
- "What would make a user abandon this mid-flow?"
- "What's the most annoying part of the current process?"
- "How would a power user use this differently?"

### Phase 5: Edge Cases & Failure Modes
Find the gotchas before they find you.

- What happens when [X] fails?
- What if there's no data? Too much data?
- What about concurrent users/actions?
- What's the worst case scenario?
- How do you handle partial success?

**Non-obvious probes:**
- "What would an adversarial user try?"
- "What happens at 3am when no one's watching?"
- "What's the rollback plan?"

### Phase 6: Tradeoffs & Priorities
Make implicit decisions explicit.

- Speed vs. quality vs. cost - rank them
- Build vs. buy decisions
- What are you willing to be bad at?
- What would you trade for faster delivery?
- What's non-negotiable?

**Non-obvious probes:**
- "If this took 3x longer than expected, would you still do it?"
- "What's the hidden cost you're not talking about?"
- "What's the decision you're avoiding?"

### Phase 7: Success Criteria
Define done before starting.

- How do you measure success?
- What metrics matter? What's the target?
- What does "good enough" look like?
- How will you know if this failed?
- What happens after launch?

**Non-obvious probes:**
- "If the metrics look good but users complain, what wins?"
- "What would make you kill this post-launch?"
- "What's the 6-month check-in question?"

## Interview Execution

### Starting the Interview
```
I'll interview you to create a detailed spec for: [TOPIC]

I'll ask one question at a time, going deep on each area. 
Don't worry about structure - I'll synthesize everything at the end.

Let's start: [FIRST QUESTION]
```

### During the Interview
- Ask ONE question, wait for answer
- Follow up on interesting threads (2-3 levels deep)
- Acknowledge insights: "Interesting - so [reframe]. That means..."
- Transition explicitly: "Good, let's shift to [next area]..."
- Track what's been covered mentally

### Knowing When to Stop
Stop interviewing when:
- You've covered all 7 phases (at least briefly)
- Answers are becoming repetitive
- User signals readiness ("I think that's everything")
- You have enough to write a useful spec

Ask: "Is there anything critical we haven't discussed?"

### Wrapping Up
```
Great, I have what I need. I'll now write up the spec.
Give me a moment to synthesize everything...
```

## Spec Output

Write to: `/root/clawd/output/specs/[project-name]-spec.md`

Use the template structure from `templates/spec-template.md`

### Spec Qualities
- **Actionable**: Someone could build from this
- **Honest**: Include uncertainties and open questions
- **Prioritized**: Clear on what's MVP vs. later
- **Testable**: Success criteria are measurable
- **Concise**: No fluff, every section earns its place

## After Writing

1. Share the spec location with the user
2. Offer to upload to Notion if appropriate
3. Ask if any sections need expansion
4. Note any unresolved questions that need answers

## Anti-Patterns to Avoid

❌ Asking obvious questions they already answered
❌ Rapid-fire questions without listening
❌ Generic questions that apply to anything
❌ Over-interviewing (20+ questions on a simple project)
❌ Jumping to solutions before understanding problems
❌ Ignoring interesting tangents
❌ Forgetting to ask about constraints
❌ Writing a spec that's longer than it needs to be
