#!/bin/bash

NOTION_KEY=$(cat ~/.config/notion/api_key)
DATABASE_ID="5df03450-e009-47eb-9440-1bca190f835c"

curl -s -X POST "https://api.notion.com/v1/databases/${DATABASE_ID}/query" \
  -H "Authorization: Bearer ${NOTION_KEY}" \
  -H "Content-Type: application/json" \
  -H "Notion-Version: 2022-06-28" \
  --data '{
    "filter": {
      "and": [
        {
          "property": "Assignee",
          "select": {
            "equals": "Nyx"
          }
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
  }' | jq -r '.results[] | {
    id: .id,
    name: .properties.Name.title[0].text.content,
    status: .properties.Status.select.name,
    type: .properties.Type.select.name,
    priority: .properties.Priority.select.name,
    model: (.properties.Model.select.name // "default"),
    thinking: (.properties.Thinking.checkbox // true),
    phased_research: (.properties["Phased Research"].checkbox // false)
  }'
