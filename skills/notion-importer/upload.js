#!/usr/bin/env node

/**
 * Notion Importer - Upload Markdown to Notion
 * 
 * Default target: Nyx database (5df03450-e009-47eb-9440-1bca190f835c)
 * 
 * Usage:
 *   upload.js <file.md>                          Upload to Nyx database
 *   upload.js <file.md> --title "My Title"       With custom title
 *   upload.js <file.md> --page <page_id>         Upload to existing page
 *   upload.js <file.md> --page <page_id> --replace
 *   upload.js <file.md> --database <db_id>       Upload to different database
 *   upload.js <file.md> --properties '{"key":"value"}'
 */

const fs = require('fs');
const https = require('https');
const path = require('path');
const { markdownToNotionBlocks, addTableOfContents } = require('./markdown-to-notion.js');

// Configuration
const NOTION_API_KEY = fs.readFileSync(process.env.HOME + '/.config/notion/api_key', 'utf8').trim();
const NOTION_VERSION = '2022-06-28'; // CRITICAL: Do NOT use newer versions (silent failures)
const NYX_DATABASE_ID = '5df03450-e009-47eb-9440-1bca190f835c';

// Rate limiting configuration
const BATCH_SIZE = 100;
const BATCH_DELAY_MS = 400;
const MAX_RETRIES = 3;
const RETRY_DELAY_MS = 1000;

// Parse command line arguments
function parseArgs() {
  const args = process.argv.slice(2);
  const config = {
    filePath: null,
    pageId: null,
    databaseId: NYX_DATABASE_ID, // Default to Nyx
    replace: false,
    properties: {},
    title: null,
    toc: true, // Enable TOC by default
    tocMinHeadings: 3 // Minimum headings to auto-add TOC
  };
  
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    if (arg === '--help' || arg === '-h') {
      showHelp();
      process.exit(0);
    } else if (arg === '--page') {
      config.pageId = args[++i];
      config.databaseId = null; // Disable database mode
    } else if (arg === '--database') {
      config.databaseId = args[++i];
    } else if (arg === '--replace') {
      config.replace = true;
    } else if (arg === '--properties') {
      config.properties = JSON.parse(args[++i]);
    } else if (arg === '--title') {
      config.title = args[++i];
    } else if (arg === '--toc') {
      config.toc = true;
    } else if (arg === '--no-toc') {
      config.toc = false;
    } else if (arg === '--toc-min') {
      config.tocMinHeadings = parseInt(args[++i], 10);
    } else if (!arg.startsWith('--')) {
      config.filePath = arg;
    }
  }
  
  // Validation
  if (!config.filePath) {
    console.error('❌ Error: No markdown file specified');
    console.error('   Usage: upload.js <file.md> [options]');
    process.exit(1);
  }
  
  if (!fs.existsSync(config.filePath)) {
    console.error(`❌ Error: File not found: ${config.filePath}`);
    process.exit(1);
  }
  
  return config;
}

function showHelp() {
  console.log(`
Notion Importer - Upload Markdown to Notion

Usage:
  upload.js <file.md> [options]

Options:
  --database <id>     Target database (default: Nyx database)
  --page <id>         Upload to existing page (append by default)
  --replace           Replace page content (with --page only)
  --title <text>      Page title (default: filename)
  --properties <json> Set database properties as JSON
  --toc               Force table of contents (auto-enabled for 3+ headings)
  --no-toc            Disable table of contents
  --toc-min <num>     Minimum headings for auto-TOC (default: 3)
  --help              Show this help

Examples:
  # Upload to Nyx database (default)
  upload.js report.md

  # Upload with title and properties
  upload.js report.md --title "Research Report" \\
    --properties '{"Type":{"select":{"name":"Research"}}}'

  # Append to existing page
  upload.js notes.md --page 2f1e334e6d5f812d912dd7a0ffce7d24

  # Replace existing page content
  upload.js notes.md --page 2f1e334e6d5f812d912dd7a0ffce7d24 --replace

Default Database (Nyx): 5df03450-e009-47eb-9440-1bca190f835c
`);
}

// Notion API request helper with retry
async function notionRequest(method, path, body = null, retries = MAX_RETRIES) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'api.notion.com',
      port: 443,
      path: path,
      method: method,
      headers: {
        'Authorization': `Bearer ${NOTION_API_KEY}`,
        'Notion-Version': NOTION_VERSION,
        'Content-Type': 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', async () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(JSON.parse(data));
        } else if (res.statusCode === 429 && retries > 0) {
          // Rate limited - retry
          console.log(`   ⏳ Rate limited, waiting ${RETRY_DELAY_MS}ms...`);
          await sleep(RETRY_DELAY_MS);
          try {
            const result = await notionRequest(method, path, body, retries - 1);
            resolve(result);
          } catch (e) {
            reject(e);
          }
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });

    req.on('error', reject);
    
    if (body) {
      req.write(JSON.stringify(body));
    }
    
    req.end();
  });
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Get all child blocks of a page
async function getAllChildBlocks(blockId) {
  const blocks = [];
  let cursor = undefined;
  
  while (true) {
    const params = cursor ? `?start_cursor=${cursor}` : '';
    const response = await notionRequest('GET', `/v1/blocks/${blockId}/children${params}`);
    
    blocks.push(...response.results);
    
    if (!response.has_more) break;
    cursor = response.next_cursor;
    
    await sleep(200);
  }
  
  return blocks;
}

// Delete a block
async function deleteBlock(blockId) {
  await notionRequest('DELETE', `/v1/blocks/${blockId}`);
}

// Delete all child blocks (for --replace mode)
async function deleteAllChildren(pageId) {
  console.log('🗑️  Deleting existing content...');
  
  const blocks = await getAllChildBlocks(pageId);
  
  if (blocks.length === 0) {
    console.log('   No existing content to delete');
    return;
  }
  
  console.log(`   Found ${blocks.length} blocks to delete`);
  
  for (let i = 0; i < blocks.length; i++) {
    await deleteBlock(blocks[i].id);
    if ((i + 1) % 20 === 0 || i === blocks.length - 1) {
      console.log(`   Deleted ${i + 1}/${blocks.length} blocks...`);
    }
    await sleep(100);
  }
  
  console.log(`   ✓ Deleted all ${blocks.length} blocks`);
}

// Upload blocks in batches with rate limiting
async function uploadBlocks(pageId, blocks) {
  let uploaded = 0;
  const totalBatches = Math.ceil(blocks.length / BATCH_SIZE);
  
  for (let i = 0; i < blocks.length; i += BATCH_SIZE) {
    const batch = blocks.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    
    console.log(`   Batch ${batchNum}/${totalBatches}: uploading ${batch.length} blocks...`);
    
    // Track blocks with pending children
    const blocksWithChildren = [];
    
    // Clean batch: remove _pendingChildren and track them
    const cleanBatch = batch.map((block, idx) => {
      if (block._pendingChildren) {
        blocksWithChildren.push({
          batchIndex: idx,
          children: block._pendingChildren
        });
        // Clone block without _pendingChildren
        const { _pendingChildren, ...cleanBlock } = block;
        return cleanBlock;
      }
      return block;
    });
    
    // Upload the clean batch
    const response = await notionRequest('PATCH', `/v1/blocks/${pageId}/children`, {
      children: cleanBatch
    });
    
    uploaded += cleanBatch.length;
    
    // Handle pending children
    if (blocksWithChildren.length > 0 && response.results) {
      for (const { batchIndex, children } of blocksWithChildren) {
        const blockId = response.results[batchIndex]?.id;
        if (blockId) {
          console.log(`   └─ Adding ${children.length} child block(s) to toggle...`);
          await notionRequest('PATCH', `/v1/blocks/${blockId}/children`, {
            children: children
          });
          await sleep(200); // Small delay after nested upload
        }
      }
    }
    
    // Rate limit delay between batches (not after the last one)
    if (i + BATCH_SIZE < blocks.length) {
      await sleep(BATCH_DELAY_MS);
    }
  }
  
  return uploaded;
}

// Verify upload by checking block count
async function verifyUpload(pageId, expectedCount) {
  const blocks = await getAllChildBlocks(pageId);
  return blocks.length >= expectedCount;
}

// Upload to existing page
async function uploadToPage(config, blocks) {
  console.log(`📄 Uploading to existing page: ${config.pageId}\n`);
  
  if (config.replace) {
    await deleteAllChildren(config.pageId);
    console.log();
  }
  
  console.log('📤 Uploading content...');
  const uploaded = await uploadBlocks(config.pageId, blocks);
  
  // Verify
  const success = await verifyUpload(config.pageId, config.replace ? uploaded : 1);
  
  const pageUrl = `https://notion.so/${config.pageId.replace(/-/g, '')}`;
  
  if (success) {
    console.log(`\n✅ SUCCESS! ${config.replace ? 'Replaced' : 'Appended'} ${uploaded} blocks`);
    console.log(`   View at: ${pageUrl}`);
  } else {
    console.log(`\n⚠️  Upload completed but verification failed`);
    console.log(`   Expected: ${uploaded} blocks`);
    console.log(`   View at: ${pageUrl}`);
  }
  
  return { success, url: pageUrl, blocks: uploaded };
}

// Create page in database
async function createInDatabase(config, blocks) {
  console.log(`📊 Creating page in database: ${config.databaseId}\n`);
  
  // Determine title from config or filename
  const title = config.title || path.basename(config.filePath, '.md');
  
  // Build properties
  const properties = {
    Name: {
      title: [{ text: { content: title } }]
    },
    ...config.properties
  };
  
  console.log('📝 Creating page...');
  console.log(`   Title: ${title}`);
  if (Object.keys(config.properties).length > 0) {
    console.log(`   Properties: ${JSON.stringify(config.properties)}`);
  }
  
  const page = await notionRequest('POST', '/v1/pages', {
    parent: { database_id: config.databaseId },
    properties: properties
  });
  
  const pageId = page.id;
  console.log(`   ✓ Page created: ${pageId}\n`);
  
  console.log('📤 Uploading content...');
  const uploaded = await uploadBlocks(pageId, blocks);
  
  // Verify
  const success = await verifyUpload(pageId, uploaded);
  
  const pageUrl = `https://notion.so/${pageId.replace(/-/g, '')}`;
  
  if (success) {
    console.log(`\n✅ SUCCESS! Created page with ${uploaded} blocks`);
    console.log(`   View at: ${pageUrl}`);
  } else {
    console.log(`\n⚠️  Upload completed but verification failed`);
    console.log(`   Expected: ${uploaded} blocks`);
    console.log(`   View at: ${pageUrl}`);
  }
  
  return { success, url: pageUrl, blocks: uploaded };
}

// Main execution
async function main() {
  const config = parseArgs();
  
  console.log('🚀 Notion Importer\n');
  
  // Read markdown file
  console.log(`📖 Reading: ${config.filePath}`);
  const markdown = fs.readFileSync(config.filePath, 'utf8');
  const lineCount = markdown.split('\n').length;
  const byteCount = Buffer.byteLength(markdown, 'utf8');
  console.log(`   ${lineCount} lines, ${(byteCount / 1024).toFixed(1)} KB\n`);
  
  // Parse markdown to Notion blocks
  console.log('🔧 Converting markdown...');
  let blocks = markdownToNotionBlocks(markdown);
  console.log(`   → ${blocks.length} Notion blocks`);
  
  // Add table of contents if enabled
  const headingCount = blocks.filter(b => 
    ['heading_1', 'heading_2', 'heading_3'].includes(b.type)
  ).length;
  
  if (config.toc) {
    const beforeCount = blocks.length;
    blocks = addTableOfContents(blocks, {
      enabled: config.toc,
      minHeadings: config.tocMinHeadings
    });
    
    if (blocks.length > beforeCount) {
      console.log(`   → Added table of contents (${headingCount} headings detected)`);
    }
  }
  
  // Estimate batches
  const batchCount = Math.ceil(blocks.length / BATCH_SIZE);
  if (batchCount > 1) {
    console.log(`   → Will upload in ${batchCount} batches\n`);
  } else {
    console.log();
  }
  
  // Upload based on mode
  let result;
  if (config.pageId) {
    result = await uploadToPage(config, blocks);
  } else {
    result = await createInDatabase(config, blocks);
  }
  
  return result;
}

main().catch(error => {
  console.error('\n❌ ERROR:', error.message);
  process.exit(1);
});
