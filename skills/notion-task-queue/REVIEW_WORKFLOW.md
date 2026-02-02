# Review Feedback Loop Workflow

## How It Works

The task queue supports an iterative review process where Oli provides feedback via comments and Nyx actions each comment individually.

## Status Flow

```
Backlog → To do → In Progress → Waiting Review → Done
                        ↑              │
                        └──────────────┘
                        (more feedback)
```

## Workflow Diagram

```
┌─────────────┐
│   Backlog   │  Items assigned but not prioritized
└──────┬──────┘
       │ (Oli prioritizes)
       ▼
┌─────────────┐
│   To do     │  Ready for Nyx to work on
└──────┬──────┘
       │ (Nyx picks up)
       ▼
┌─────────────┐
│ In Progress │  Actively being worked on
└──────┬──────┘
       │ (Work complete)
       ▼
┌─────────────────────┐
│  Waiting Review     │◀─────────────────────┐
└──────┬──────────────┘                      │
       │                                      │
       │ Oli adds comments                    │
       ▼                                      │
┌─────────────────────┐                      │
│ Process Comments    │  EACH INDIVIDUALLY   │
│ Reply with ✅ or ❓ │──────────────────────┘
└──────┬──────────────┘     (More feedback)
       │
       │ Oli satisfied / moves manually
       ▼
┌─────────────┐
│    Done     │
└─────────────┘
```

---

## For Oli: How to Provide Feedback

1. **Wait for notification** - Nyx will ping you when a task moves to "Waiting Review"
2. **Open the Notion task page**
3. **Add comments** with your feedback:
   - "Add more detail about X"
   - "Research Y as well"
   - "Change the approach to Z"
   - "This looks good, ship it"
4. **Leave Status as "Waiting Review"** - Nyx will pick it up on the next cron run
5. **Resolve comments** when satisfied, or mark task as "Done"

### Comment Resolution
- Resolved comments become **invisible to the API**
- Resolve when you're satisfied with Nyx's ✅ response
- Leave unresolved if you want a record visible

---

## For Nyx: How to Process Feedback

### Priority: Un-actioned Comments First

The queue prioritizes tasks with un-actioned comments over new work:
1. Tasks with comments that don't have ✅ or ❓ replies → by Priority → by Created
2. Tasks without comments → by Priority → by Created

### Comment Processing Rules

**CRITICAL:** Respond to each comment **individually**

❌ **Don't do this:**
```
Here's my response to all your comments:
1. About X: ...
2. About Y: ...
3. About Z: ...
```

✅ **Do this instead:**
- Reply separately to each comment thread using its `discussion_id`
- Keep each reply focused on that specific comment
- Chunk information logically; avoid long, sectioned responses

### Reply Markers

| Marker | Meaning | Example |
|--------|---------|---------|
| ✅ | Actioned and complete | `✅ Added the cost comparison section` |
| ❓ | Follow-up question | `❓ Should I include deprecated methods?` |

### Thread Tracking

- Each `discussion_id` is a separate conversation
- Track each thread to completion
- If Nyx was the last to respond, skip that thread on future runs

---

## Processing a Task

### 1. Get Unprocessed Comments

```bash
bash /root/clawd/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
```

Returns JSON array of comments without Nyx replies.

### 2. For Each Comment

1. Read the comment content
2. Take appropriate action
3. Reply individually:
   ```bash
   bash /root/clawd/skills/notion-task-queue/mark-comment-processed.sh <discussion-id> "✅ Brief summary"
   ```

### 3. Update Task Content

If adding new content to the page:
1. Add horizontal line above existing content
2. Add timestamp at the start
3. Keep user's original query at the bottom

### 4. Status Transition

- Move to "In Progress" when starting work
- Move to "Waiting Review" when done
- **Don't move to "Done"** unless:
  - Oli explicitly requested it
  - All comments have ✅ and Oli indicated completion

---

## Example Flow

**Day 1, 12:00 cron:**
- Nyx finds "Research AxiDraw CLI" (Status: To do)
- Moves to "In Progress"
- Completes research, uploads full report
- Moves to "Waiting Review"
- Notifies Oli: "Research complete, please review"

**Day 1, afternoon:**
- Oli reviews report
- Adds comment: "Can you add cost comparison info?"
- Leaves Status as "Waiting Review"

**Day 1, 16:00 cron:**
- Nyx checks queue
- Finds "Research AxiDraw CLI" has un-actioned comment
- **Prioritizes it** over other tasks
- Reads comment, does additional research
- Appends cost section (with horizontal line + timestamp)
- Replies to comment: `✅ Added cost comparison section`
- Keeps in "Waiting Review"
- Notifies Oli: "Added cost comparison"

**Day 1, evening:**
- Oli reviews update
- Resolves the comment
- Moves to "Done" manually

---

## Benefits

✅ **Iterative refinement** - Work improves through feedback  
✅ **No context loss** - All work and comments in one place  
✅ **Async collaboration** - No back-and-forth chat needed  
✅ **Full audit trail** - Comments show the evolution  
✅ **Automated processing** - Nyx picks up feedback automatically  
✅ **Individual tracking** - Each comment thread is independent  

---

## Status Summary

| Status | Owner | Meaning |
|--------|-------|---------|
| **Backlog** | Oli | Items assigned but not prioritized |
| **To do** | Nyx | Ready to work on |
| **In Progress** | Nyx | Currently working |
| **Waiting Review** | Oli | Needs feedback/approval |
| **Done** | Oli | Complete (Oli typically closes) |
