# Sub-Agent Task Completion Instructions

## ⚠️ CRITICAL: You MUST complete ALL steps below before finishing

You have been spawned to work on a Notion task. Your work is NOT complete until you have done ALL of the following:

---

## Required Completion Steps

### 1. Do the Work
Complete the task as instructed (research, coding, documentation, etc.)

### 2. Save Output Locally
Save your output to a markdown file:
```bash
# Use this naming convention
OUTPUT_FILE="/root/nyx/output/{Type}/{task_name}_{date}.md"

# Examples:
# /root/nyx/output/Research/gemini-flash-evaluation_2026-02-05.md
# /root/nyx/output/Task/cosmic-orb-updates_2026-02-05.md
# /root/nyx/output/Documentation/api-reference_2026-02-05.md
```

### 3. ⭐ UPLOAD TO NOTION AND UPDATE STATUS (MANDATORY)

**Use the `complete-task.sh` script - this is the ONLY correct way to finish:**

```bash
/root/nyx/skills/notion-task-queue/complete-task.sh {PAGE_ID} {OUTPUT_FILE}
```

This script:
- ✅ Uploads your content to the Notion page
- ✅ Updates status to "Waiting Review"  
- ✅ Verifies both steps succeeded
- ✅ Logs the completion

### 4. Report Success

Only report completion AFTER `complete-task.sh` succeeds:
```
✅ Task completed:
- Content uploaded to Notion
- Status: Waiting Review
- Output file: {OUTPUT_FILE}
```

---

## ❌ DO NOT:

- ❌ Finish without uploading to Notion
- ❌ Upload to Notion without updating status
- ❌ Call `upload.js` and `update-task-status.sh` separately (use `complete-task.sh` instead)
- ❌ Report success if any step failed
- ❌ Leave the task in "In Progress" status

---

## Error Recovery

If `complete-task.sh` fails:

1. **Upload failed?** 
   - Check if the markdown file exists and is valid
   - Check Notion API key permissions
   - Retry: `node /root/nyx/skills/notion-importer/upload.js {file} --page {PAGE_ID}`

2. **Status update failed?**
   - Retry: `/root/nyx/skills/notion-task-queue/update-task-status.sh {PAGE_ID} "Waiting Review"`

3. **Both failed?**
   - Report the error clearly
   - DO NOT claim the task is complete

---

## Verification Checklist

Before reporting completion, verify:
- [ ] Output saved to `/root/nyx/output/{Type}/`
- [ ] `complete-task.sh` ran successfully (no errors)
- [ ] Status is "Waiting Review" (script confirms this)

---

## Task Details

**Page ID:** `{PAGE_ID}`
**Task Name:** `{TASK_NAME}`
**Task Type:** `{TASK_TYPE}`
**Output Path:** `/root/nyx/output/{TASK_TYPE}/{sanitized_name}_{date}.md`

---

## Example Complete Workflow

```bash
# 1. Do research/work and save to file
cat > /root/nyx/output/Research/gemini-flash-research_2026-02-05.md << 'EOF'
# Gemini Flash Evaluation

## Summary
[Your research content here]

## Findings
...
EOF

# 2. Complete the task (uploads AND updates status)
/root/nyx/skills/notion-task-queue/complete-task.sh \
  "2f6e334e-6d5f-8060-91f4-ed979d32e712" \
  "/root/nyx/output/Research/gemini-flash-research_2026-02-05.md"

# 3. Verify it worked (script does this automatically)
# ✅ TASK COMPLETED SUCCESSFULLY
```

Remember: **Your task is NOT done until `complete-task.sh` succeeds!**
