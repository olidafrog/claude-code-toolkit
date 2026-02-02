# Notion Task Queue

Automated workflow for processing tasks assigned to Nyx in the Notion database with comprehensive feedback loop via comments.

## Quick Start

**Test the queue checker:**
```bash
bash /root/clawd/skills/notion-task-queue/check-queue.sh
```

**Get un-actioned comments on a task:**
```bash
bash /root/clawd/skills/notion-task-queue/get-unprocessed-comments.sh <page-id>
```

**Reply to a comment:**
```bash
bash /root/clawd/skills/notion-task-queue/mark-comment-processed.sh <discussion-id> "✅ Summary"
```

## Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Full documentation and workflow details |
| `REVIEW_WORKFLOW.md` | Feedback loop guide (Oli ↔ Nyx iteration) |
| `check-queue.sh` | Query and summarize pending tasks |
| `get-unprocessed-comments.sh` | Get comments without Nyx replies |
| `mark-comment-processed.sh` | Reply to a comment thread |
| `UPLOAD_PROCESS.md` | Guide for uploading reports to Notion |
| `SETUP.md` | Initial setup instructions |

## Key Feature: Comment-Based Feedback Loop

### Status Flow
```
Backlog → To do → In Progress → Waiting Review → Done
```

### Priority Order
1. **Tasks with un-actioned comments** → by Priority → by Created
2. **Tasks without comments** → by Priority → by Created

### Comment Protocol
- Reply to **each comment individually** (don't bundle)
- Use ✅ when actioned, ❓ for questions
- Let Oli close tasks (stay in Waiting Review)

See `REVIEW_WORKFLOW.md` for full details.

## Output Directories

Task outputs are stored in:
```
/root/clawd/output/{Type}/
```

Examples:
- `/root/clawd/output/Research/`
- `/root/clawd/output/Task/`
- `/root/clawd/output/Documentation/`

## Timing

Runs automatically at: **07:00, 12:00, 16:00, 19:00, 22:00**

## How It Works

1. Query tasks assigned to Nyx with Status = Backlog, To do, In Progress, or Waiting Review
2. Prioritize tasks with un-actioned comments
3. Sort by Priority, then Created date
4. Process based on Type (Research/Task/Documentation/etc.)
5. Reply to each comment individually with ✅ or ❓
6. Move to Waiting Review (let Oli close)

## Customization

All configuration in `SKILL.md`. Common tweaks:
- **Change timing:** Edit cron schedule
- **Change filters:** Edit `check-queue.sh`
- **Change processing logic:** Edit the cron job message payload
