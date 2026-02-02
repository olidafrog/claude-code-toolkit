# Setup Instructions

## 1. Verify Status Options

The workflow requires these status options in your Notion database:

| Status | Purpose |
|--------|---------|
| **Backlog** | Items assigned but not yet prioritized |
| **To do** | Ready for Nyx to work on |
| **In Progress** | Currently being worked on |
| **Waiting Review** | Work complete, awaiting feedback |
| **Done** | Approved and complete |

### To check/add statuses:

1. Open your Nyx database in Notion: https://www.notion.so/oliingram/5df03450e00947eb94401bca190f835c
2. Click on any task's **Status** field
3. Click "Edit property"
4. Verify all statuses exist, add any missing ones
5. Suggested colors:
   - Backlog: Gray
   - To do: Blue
   - In Progress: Purple
   - Waiting Review: Orange/Yellow
   - Done: Green

### Status Flow

```
Backlog → To do → In Progress → Waiting Review → Done
                        ↑              │
                        └──────────────┘
                        (feedback loop)
```

## 2. Verify Cron Job

Check that the cron job is running:

```bash
clawdbot cron list | grep notion-task-queue
```

Should show:
- Schedule: `0 7,12,16,19,22 * * *`
- Enabled: `true`

## 3. Create Output Directories

The workflow saves outputs locally:

```bash
mkdir -p /root/clawd/output/{Task,Research,Documentation,Note,Idea}
```

## 4. Test the Queue

```bash
bash /root/clawd/skills/notion-task-queue/check-queue.sh
```

Should return `HEARTBEAT_OK` if no tasks, or list pending tasks.

## 5. Create a Test Task

1. In Notion, create a new task:
   - **Name**: "Test: Hello Nyx"
   - **Assignee**: Nyx
   - **Type**: Task
   - **Status**: To do
   - **Priority**: High

2. Wait for next cron run (or trigger manually)

3. Nyx should:
   - Move task to "In Progress"
   - Process the task
   - Move it to "Waiting Review"
   - Notify you on Telegram

4. Add a comment: "Great! Now add more details about X"

5. Next cron run: Nyx reads your comment and acts on it

## 6. Optional: Adjust Timing

Default schedule (5x daily):
- 07:00, 12:00, 16:00, 19:00, 22:00

To change:

```bash
clawdbot cron update <job-id> --schedule "0 9,17 * * *"  # Example: 9am and 5pm only
```

## Troubleshooting

**Tasks not being processed?**
- Check Assignee = "Nyx"
- Check Status = "Backlog", "To do", "In Progress", or "Waiting Review"
- Check cron is enabled: `clawdbot cron list`

**Comments not being read?**
- Verify "Waiting Review" status exists and is spelled correctly
- Check Notion API permissions (should have comment read access)
- Use: `bash get-unprocessed-comments.sh <page-id>` to debug

**Reports not uploading?**
- Check notion-importer skill is available
- Verify Notion API key is valid: `cat ~/.config/notion/api_key`

**Output directories missing?**
- Run: `mkdir -p /root/clawd/output/{Task,Research,Documentation,Note,Idea}`
