# Notion Upload Guide for Research Reports

## Critical Rules

### 0. Use Correct API Version

**CRITICAL:** Always use Notion API version `2022-06-28` (NOT the latest `2022-06-28`)

**Why:**
- Newer API versions (`2022-06-28`) have silent failure issues
- Database property creation/updates return 200 OK but don't actually add properties
- Block uploads may succeed but create empty pages
- `2022-06-28` is stable and reliable for all operations

**How:**
```bash
curl -H "Notion-Version: 2022-06-28" ...
```

```python
notion_client = Client(
    auth=api_key,
    notion_version="2022-06-28"
)
```

**Never use:** `2022-06-28`, `2025-01-XX`, or any 2025+ versions until verified stable.

### 1. Always Use Batched Uploads for Large Content

**Notion API Constraints:**
- Maximum ~100-120 blocks per request (unofficial limit)
- Requests >100 blocks often fail silently
- Failed uploads create empty pages (title exists, no content)

**Solution:**
Upload in batches of 100 blocks at a time.

### 2. Verify Upload Success

After each batch:
```python
# Check block count
response = notion.blocks.children.list(page_id)
actual_count = len(response['results'])
expected_count = len(blocks_uploaded_so_far)

if actual_count != expected_count:
    raise Exception(f"Upload verification failed: {actual_count} vs {expected_count}")
```

### 3. Upload Pattern

```
1. Create page with properties (title, type, status)
2. Split content into batches of 100 blocks
3. For each batch:
   a. Upload blocks
   b. Verify count
   c. Sleep 0.3-0.5s (rate limit courtesy)
4. Final verification: check total block count
5. Return URL with block count confirmation
```

## Content Size Guidelines

| Report Size | Block Count (est.) | Upload Strategy |
|-------------|-------------------|-----------------|
| <5 KB | <50 blocks | Single request OK |
| 5-10 KB | 50-100 blocks | Single request OK |
| 10-20 KB | 100-300 blocks | **Batch required** (2-3 batches) |
| 20-50 KB | 300-600 blocks | **Batch required** (3-6 batches) |
| >50 KB | 600+ blocks | **Batch required** + consider splitting |

## Block Conversion Estimates

From markdown to Notion blocks:

| Element | Blocks per instance |
|---------|-------------------|
| Paragraph | 1 block |
| Heading (any level) | 1 block |
| Bulleted/numbered list item | 1 block each |
| Table row | 1 block (entire table) |
| Code block | 1 block |
| Callout | 1 block |
| Divider | 1 block |

**Example:** A typical research report with:
- 10 headings
- 50 paragraphs
- 100 list items
- 5 tables
- 10 code blocks
- 5 callouts
- 5 dividers

= **~185 blocks** → Requires 2 batches

## Error Handling

### Silent Failures

**Problem:** Notion API may return 200 OK but not actually create blocks.

**Detection:**
```python
response = create_blocks(page_id, blocks)
# Response looks successful but...

# Verify immediately:
actual = get_block_count(page_id)
if actual == 0 and len(blocks) > 0:
    raise Exception("Silent failure: blocks not created")
```

### Rate Limiting

**Problem:** Too many requests → 429 errors or silent failures

**Solution:**
- Add 0.3-0.5s delay between batches
- Implement exponential backoff for retries
- Maximum 3 requests/second (Notion's documented limit)

### Batch Failures

**Problem:** Batch 2 fails → page has partial content

**Solution:**
```python
try:
    for batch_num, batch in enumerate(batches):
        upload_batch(page_id, batch, batch_num)
        verify_batch(page_id, batch_num)
except Exception as e:
    # Page exists but is incomplete
    # Option 1: Continue from last successful batch
    # Option 2: Delete page and retry
    # Option 3: Return partial URL with warning
    return f"⚠️  Partial upload: {url} (batch {batch_num} failed)"
```

## Implementation Example

```python
def upload_research_report_to_notion(content_md, database_id, title):
    """
    Upload large research report with automatic batching.
    """
    # 1. Create page
    page = notion.pages.create(
        parent={"database_id": database_id},
        properties={
            "Name": {"title": [{"text": {"content": title}}]},
            "Type": {"select": {"name": "Notes"}},
            "Status": {"status": {"name": "Done"}}
        }
    )
    page_id = page['id']
    
    # 2. Convert markdown to Notion blocks
    blocks = markdown_to_notion_blocks(content_md)
    
    # 3. Split into batches of 100
    batches = [blocks[i:i+100] for i in range(0, len(blocks), 100)]
    
    # 4. Upload each batch
    total_uploaded = 0
    for batch_num, batch in enumerate(batches):
        try:
            notion.blocks.children.append(page_id, children=batch)
            total_uploaded += len(batch)
            
            # Verify
            actual = len(notion.blocks.children.list(page_id)['results'])
            if actual != total_uploaded:
                raise Exception(f"Verification failed at batch {batch_num}")
            
            # Rate limit courtesy
            if batch_num < len(batches) - 1:  # Not last batch
                time.sleep(0.4)
                
        except Exception as e:
            return {
                "status": "partial",
                "url": f"https://notion.so/{page_id}",
                "blocks_uploaded": total_uploaded,
                "total_blocks": len(blocks),
                "error": str(e)
            }
    
    # 5. Final verification
    final_count = len(notion.blocks.children.list(page_id)['results'])
    if final_count != len(blocks):
        return {
            "status": "warning",
            "url": f"https://notion.so/{page_id}",
            "blocks_uploaded": final_count,
            "expected": len(blocks),
            "message": "Upload completed but block count mismatch"
        }
    
    return {
        "status": "success",
        "url": f"https://notion.so/{page_id}",
        "blocks_uploaded": len(blocks)
    }
```

## Shell Script Pattern

For bash-based uploads (using curl):

```bash
upload_to_notion() {
    local page_id=$1
    local blocks_json=$2
    
    # Count blocks
    local total_blocks=$(echo "$blocks_json" | jq '. | length')
    local batch_size=100
    local uploaded=0
    
    echo "Uploading $total_blocks blocks in batches of $batch_size..."
    
    # Split into batches
    for ((offset=0; offset<total_blocks; offset+=batch_size)); do
        local batch_num=$((offset / batch_size + 1))
        local batch=$(echo "$blocks_json" | jq ".[$offset:$((offset+batch_size))]")
        
        echo "  Uploading batch $batch_num..."
        
        # Upload batch
        curl -s -X PATCH "https://api.notion.com/v1/blocks/$page_id/children" \
            -H "Authorization: Bearer $NOTION_KEY" \
            -H "Notion-Version: 2022-06-28" \
            -H "Content-Type: application/json" \
            -d "{\"children\": $batch}" > /dev/null
        
        uploaded=$((uploaded + $(echo "$batch" | jq '. | length')))
        
        # Verify
        local actual=$(curl -s "https://api.notion.com/v1/blocks/$page_id/children?page_size=1" \
            -H "Authorization: Bearer $NOTION_KEY" \
            -H "Notion-Version: 2022-06-28" | jq '.results | length')
        
        if [[ $actual -eq 0 ]] && [[ $uploaded -gt 0 ]]; then
            echo "ERROR: Batch upload failed (silent failure detected)"
            return 1
        fi
        
        # Rate limit
        sleep 0.4
    done
    
    echo "✅ Uploaded $uploaded blocks"
}
```

## Debugging Failed Uploads

### Check if page exists but is empty:

```bash
PAGE_ID="xxx"
NOTION_KEY="yyy"

# Get block count
curl -s "https://api.notion.com/v1/blocks/$PAGE_ID/children?page_size=1" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  | jq '{has_children: .has_more, block_count: (.results | length)}'

# Expected: {"has_children": true, "block_count": 1}
# If empty: {"has_children": false, "block_count": 0}
```

### Fix empty page:

```bash
# Option 1: Upload content to existing empty page
./upload-to-notion.sh --page-id $PAGE_ID content.md

# Option 2: Delete and recreate
curl -X PATCH "https://api.notion.com/v1/pages/$PAGE_ID" \
  -H "Authorization: Bearer $NOTION_KEY" \
  -H "Notion-Version: 2022-06-28" \
  -d '{"archived": true}'
```

## Best Practices

1. **Always batch for research reports** (they're typically >100 blocks)
2. **Verify each batch** before proceeding
3. **Return block count** in success message
4. **Handle partial failures** gracefully
5. **Log batch progress** for debugging
6. **Add delays** between batches (0.3-0.5s)
7. **Implement retries** with exponential backoff
8. **Test with small reports** first

## Task Brief Template for Notion Uploads

When spawning research agents that upload to Notion, include:

```
**Notion Upload:**
After completing research, upload report to Notion database: {DATABASE_ID}

CRITICAL UPLOAD REQUIREMENTS:
1. Create page with properties first (Title, Type: Notes, Status: Done)
2. Convert markdown to Notion blocks
3. Count total blocks - if >100, upload in batches of 100
4. For each batch:
   - Upload blocks to page
   - Verify blocks were created (check block count)
   - Sleep 0.4 seconds (rate limit courtesy)
5. After all batches, verify total block count matches expected
6. Return: "✅ Uploaded to Notion: {URL} ({BLOCK_COUNT} blocks)"

If any batch fails:
- Stop immediately
- Return: "⚠️  Partial upload: {URL} ({BLOCKS_UPLOADED}/{TOTAL_BLOCKS} blocks)"
```

## Common Mistakes to Avoid

❌ **Don't:** Upload 300 blocks in one request  
✅ **Do:** Split into 3 batches of 100

❌ **Don't:** Assume 200 OK means success  
✅ **Do:** Verify block count after upload

❌ **Don't:** Continue after silent failure  
✅ **Do:** Check block count after each batch

❌ **Don't:** Upload without rate limit delays  
✅ **Do:** Add 0.3-0.5s between batches

❌ **Don't:** Return just the URL  
✅ **Do:** Include block count in confirmation
