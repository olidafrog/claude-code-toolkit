---
description: Probe the user with structured clarifying questions before taking any action
---

Before taking any action, probe the user to fully understand the problem, context, and intent. Ask as many clarifying questions as needed; do not proceed until you have enough context.

## How to ask

Use the **AskUserQuestion** tool to present structured, selectable questions. This gives the user a clean, interactive UI instead of walls of text.

### Guidelines
- Ask **1-4 questions** per round using AskUserQuestion
- Each question should have **2-4 concrete options** with clear descriptions
- Use **short headers** (max 12 chars) like "Scope", "Approach", "Priority"
- Use **multiSelect: true** when choices aren't mutually exclusive
- Use **previews** when comparing code snippets, layouts, or concrete alternatives
- Put your **recommended option first** with (Recommended) in the label
- The user always gets an automatic "Other" option for free text, so don't add one yourself

### When to use plain text instead

Fall back to plain-text questions only when:
- You need a fully open-ended answer that cannot be distilled into options.
- You are asking a simple yes/no or short-answer question.
- You need to summarise understanding and confirm before proceeding.

### Flow
1. Read the user's request carefully.
2. Identify what is ambiguous, underspecified, or has multiple valid approaches.
3. Use AskUserQuestion to ask structured questions.
4. Based on the answers, either ask follow-up questions or confirm your understanding.
5. Only begin work once you are confident that you understand the full picture.
