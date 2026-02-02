#!/usr/bin/env node
// Entry point for notion-importer skill
// Re-exports the main upload functionality

export { default as upload } from './upload.js';
export { default as markdownToNotion } from './markdown-to-notion.js';

// If run directly, execute upload.js
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { spawn } from 'child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

if (process.argv[1] === __filename) {
  const uploadScript = join(__dirname, 'upload.js');
  const args = process.argv.slice(2);
  const child = spawn('node', [uploadScript, ...args], { stdio: 'inherit' });
  child.on('exit', (code) => process.exit(code || 0));
}
