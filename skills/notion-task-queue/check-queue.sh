#!/bin/bash
# Notion Task Processor - runs periodically to check and execute Nyx tasks

NOTION_KEY=$(cat ~/.config/notion/api_key)
DATA_SOURCE_ID="4d050324-79c8-4543-8a42-dac961761b93"
DATABASE_ID="5df03450-e009-47eb-9440-1bca190f835c"

# Query for tasks assigned to Nyx with Status = To do, In Progress, or Waiting Review (excludes Backlog)
TASKS=$(curl -s -X POST "https://api.notion.com/v1/data_sources/${DATA_SOURCE_ID}/query" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Notion-Version: 2025-09-03" \
  -H "Content-Type: application/json" \
  -d '{
    "filter": {
      "and": [
        {
          "property": "Assignee",
          "select": { "equals": "Nyx" }
        },
        {
          "or": [
            { "property": "Status", "select": { "equals": "To do" } },
            { "property": "Status", "select": { "equals": "In Progress" } },
            { "property": "Status", "select": { "equals": "Waiting Review" } }
          ]
        }
      ]
    },
    "sorts": [
      { "property": "Priority", "direction": "ascending" },
      { "property": "Created", "direction": "ascending" }
    ]
  }')

# Count tasks
TASK_COUNT=$(echo "$TASKS" | jq -r '.results | length')

if [ "$TASK_COUNT" -eq 0 ]; then
  echo "HEARTBEAT_OK"
  exit 0
fi

# Get task details (including Model and Thinking fields)
TASK_LIST=$(echo "$TASKS" | jq -r '.results[] | 
  {
    id: .id, 
    name: (.properties.Name.title[0].text.content // "Untitled"),
    type: (.properties.Type.select.name // "Task"),
    priority: (.properties.Priority.select.name // "Low"),
    status: .properties.Status.select.name,
    model: (.properties.Model.select.name // null),
    thinking: .properties.Thinking.checkbox
  } | @json' | jq -s .)

# Format message
MESSAGE="🌙 **Nyx Task Queue** ($TASK_COUNT pending)

$(echo "$TASK_LIST" | jq -r '.[] | 
  "• \(.name) [\(.type)] - Priority: \(.priority)" + 
  (if .model then " - Model: \(.model)" else "" end) +
  (if .thinking == false then " - Thinking: Off" else "" end)')"

# Send notification to Telegram
echo "$MESSAGE"
