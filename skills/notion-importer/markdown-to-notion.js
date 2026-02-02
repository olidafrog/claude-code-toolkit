#!/usr/bin/env node

/**
 * Robust Markdown to Notion Block Converter
 * 
 * Handles:
 * - Headings (h1-h3)
 * - Paragraphs
 * - Bullet and numbered lists
 * - Checkboxes (to_do blocks)
 * - Code blocks with syntax highlighting
 * - Tables (converted to Notion simple tables)
 * - Blockquotes (converted to callouts)
 * - Dividers
 * - Inline formatting: bold, italic, code, links
 */

// Check if position is inside a markdown link [text](url)
function isInsideMarkdownLink(text, pos) {
  // Look backwards for [ without a closing ]
  let openBracket = -1;
  for (let i = pos - 1; i >= 0; i--) {
    if (text[i] === ']') return false; // Found closing bracket first
    if (text[i] === '[') {
      openBracket = i;
      break;
    }
  }
  
  // If we found an opening bracket, check if there's a matching ](url) ahead
  if (openBracket >= 0) {
    const remaining = text.substring(pos);
    // Check if we're between ] and ) in a link pattern
    if (/^\S*?\)/.test(remaining)) {
      return true;
    }
  }
  
  return false;
}

// Extract URL from markdown link, handling balanced parentheses
function extractBalancedUrl(str) {
  // str starts after "[text](" - find matching closing paren
  let depth = 1;
  let i = 0;
  while (i < str.length && depth > 0) {
    if (str[i] === '(') depth++;
    else if (str[i] === ')') depth--;
    if (depth > 0) i++;
  }
  return i > 0 ? str.substring(0, i) : null;
}

// Parse inline markdown formatting (bold, italic, code, links)
function parseInlineFormatting(text) {
  if (!text) return [{ type: 'text', text: { content: '' } }];
  
  const richText = [];
  let current = '';
  let i = 0;
  
  while (i < text.length) {
    // Plain text URLs: https://... or http://... or www....
    const urlMatch = text.substring(i).match(/^(https?:\/\/[^\s<>)\]]+|www\.[^\s<>)\]]+)/);
    if (urlMatch && !isInsideMarkdownLink(text, i)) {
      if (current) {
        richText.push(...parseBasicFormatting(current));
        current = '';
      }
      const url = urlMatch[1];
      const fullUrl = url.startsWith('www.') ? `https://${url}` : url;
      richText.push({
        type: 'text',
        text: {
          content: url,
          link: { url: fullUrl }
        }
      });
      i += url.length;
      continue;
    }
    
    // Links: [text](url) with balanced parenthesis support
    if (text[i] === '[') {
      const textMatch = text.substring(i).match(/^\[([^\]]+)\]\(/);
      if (textMatch) {
        const linkText = textMatch[1];
        const urlStart = i + textMatch[0].length;
        const url = extractBalancedUrl(text.substring(urlStart));
        if (url) {
          if (current) {
            richText.push(...parseBasicFormatting(current));
            current = '';
          }
          richText.push({
            type: 'text',
            text: {
              content: linkText,
              link: { url: url }
            }
          });
          i = urlStart + url.length + 1; // +1 for closing )
          continue;
        }
      }
    }
    
    // Bold: **text**
    if (text.substring(i, i + 2) === '**') {
      const boldMatch = text.substring(i).match(/^\*\*([^*]+)\*\*/);
      if (boldMatch) {
        if (current) {
          richText.push(...parseBasicFormatting(current));
          current = '';
        }
        const boldText = boldMatch[1];
        // Recursively parse content inside bold for links, code, etc.
        const innerParts = parseInlineFormattingNoRecurse(boldText);
        for (const part of innerParts) {
          part.annotations = { ...part.annotations, bold: true };
          richText.push(part);
        }
        i += boldMatch[0].length;
        continue;
      }
    }
    
    // Italic: *text* or _text_ (but not ** or __)
    if ((text[i] === '*' && text[i + 1] !== '*') || (text[i] === '_' && text[i + 1] !== '_')) {
      const italicChar = text[i];
      const italicRegex = italicChar === '*' ? /^\*([^*]+)\*/ : /^_([^_]+)_/;
      const italicMatch = text.substring(i).match(italicRegex);
      if (italicMatch) {
        if (current) {
          richText.push(...parseBasicFormatting(current));
          current = '';
        }
        // Recursively parse content inside italic for links, code, etc.
        const innerParts = parseInlineFormattingNoRecurse(italicMatch[1]);
        for (const part of innerParts) {
          part.annotations = { ...part.annotations, italic: true };
          richText.push(part);
        }
        i += italicMatch[0].length;
        continue;
      }
    }
    
    // Strikethrough: ~~text~~
    if (text.substring(i, i + 2) === '~~') {
      const strikeMatch = text.substring(i).match(/^~~([^~]+)~~/);
      if (strikeMatch) {
        if (current) {
          richText.push(...parseBasicFormatting(current));
          current = '';
        }
        // Recursively parse content inside strikethrough for links, code, etc.
        const innerParts = parseInlineFormattingNoRecurse(strikeMatch[1]);
        for (const part of innerParts) {
          part.annotations = { ...part.annotations, strikethrough: true };
          richText.push(part);
        }
        i += strikeMatch[0].length;
        continue;
      }
    }
    
    // Inline code: `text` (but not ```)
    if (text[i] === '`' && text[i + 1] !== '`') {
      const codeMatch = text.substring(i).match(/^`([^`]+)`/);
      if (codeMatch) {
        if (current) {
          richText.push(...parseBasicFormatting(current));
          current = '';
        }
        richText.push({
          type: 'text',
          text: { content: codeMatch[1] },
          annotations: { code: true }
        });
        i += codeMatch[0].length;
        continue;
      }
    }
    
    // Regular character
    current += text[i];
    i++;
  }
  
  if (current) {
    richText.push(...parseBasicFormatting(current));
  }
  
  return richText.length > 0 ? richText : [{ type: 'text', text: { content: '' } }];
}

// Parse inline formatting inside bold/italic (no recursion for bold/italic)
function parseInlineFormattingNoRecurse(text) {
  if (!text) return [{ type: 'text', text: { content: '' } }];
  
  const richText = [];
  let current = '';
  let i = 0;
  
  while (i < text.length) {
    // Links: [text](url) with balanced parenthesis support
    if (text[i] === '[') {
      const textMatch = text.substring(i).match(/^\[([^\]]+)\]\(/);
      if (textMatch) {
        const linkText = textMatch[1];
        const urlStart = i + textMatch[0].length;
        const url = extractBalancedUrl(text.substring(urlStart));
        if (url) {
          if (current) {
            richText.push({ type: 'text', text: { content: current } });
            current = '';
          }
          richText.push({
            type: 'text',
            text: {
              content: linkText,
              link: { url: url }
            }
          });
          i = urlStart + url.length + 1;
          continue;
        }
      }
    }
    
    // Inline code: `text`
    if (text[i] === '`' && text[i + 1] !== '`') {
      const codeMatch = text.substring(i).match(/^`([^`]+)`/);
      if (codeMatch) {
        if (current) {
          richText.push({ type: 'text', text: { content: current } });
          current = '';
        }
        richText.push({
          type: 'text',
          text: { content: codeMatch[1] },
          annotations: { code: true }
        });
        i += codeMatch[0].length;
        continue;
      }
    }
    
    current += text[i];
    i++;
  }
  
  if (current) {
    richText.push({ type: 'text', text: { content: current } });
  }
  
  return richText.length > 0 ? richText : [{ type: 'text', text: { content: '' } }];
}

// Parse code within bold text
function parseCodeInBold(text) {
  const parts = [];
  let current = '';
  let i = 0;
  
  while (i < text.length) {
    if (text[i] === '`') {
      const codeMatch = text.substring(i).match(/^`([^`]+)`/);
      if (codeMatch) {
        if (current) {
          parts.push({
            type: 'text',
            text: { content: current },
            annotations: { bold: true }
          });
          current = '';
        }
        parts.push({
          type: 'text',
          text: { content: codeMatch[1] },
          annotations: { bold: true, code: true }
        });
        i += codeMatch[0].length;
        continue;
      }
    }
    current += text[i];
    i++;
  }
  
  if (current) {
    parts.push({
      type: 'text',
      text: { content: current },
      annotations: { bold: true }
    });
  }
  
  return parts;
}

// Basic formatting for text without special patterns
function parseBasicFormatting(text) {
  if (!text) return [];
  return [{
    type: 'text',
    text: { content: text }
  }];
}

/**
 * Dual-Mode Mermaid Theme Configuration
 * 
 * Optimized for dark mode with light mode compatibility:
 * - Medium-saturation backgrounds work on both light and dark Notion themes
 * - Dark text provides readability in both modes
 * - Strong border contrast for visibility
 * - Vibrant accents for key elements
 */
const HIGH_CONTRAST_MERMAID_THEME = {
  theme: 'base',
  themeVariables: {
    // Core colors - medium blue that works on dark/light backgrounds
    darkMode: false,
    background: '#ffffff',
    primaryColor: '#60a5fa',           // Medium blue (readable on dark, visible on light)
    primaryTextColor: '#1e293b',       // Dark slate text
    primaryBorderColor: '#2563eb',     // Bright blue border
    
    // Secondary elements - teal/green
    secondaryColor: '#34d399',         // Medium teal
    secondaryTextColor: '#064e3b',     // Dark green text
    secondaryBorderColor: '#10b981',   // Bright teal border
    
    // Tertiary elements - orange/amber
    tertiaryColor: '#fbbf24',          // Bright amber
    tertiaryTextColor: '#78350f',      // Dark brown text
    tertiaryBorderColor: '#f59e0b',    // Orange border
    
    // Lines and connectors - medium gray (visible on both modes)
    lineColor: '#6b7280',              // Medium gray
    
    // Notes - vibrant yellow background with dark text
    noteBkgColor: '#fde047',           // Vibrant yellow
    noteTextColor: '#713f12',          // Dark brown
    noteBorderColor: '#eab308',        // Yellow border
    
    // General text - dark for labels (works on light backgrounds in both modes)
    textColor: '#1e293b',              // Dark slate
    
    // Flowchart specific
    nodeBorder: '#2563eb',             // Bright blue
    clusterBkg: '#a5b4fc',             // Light indigo (visible in both modes)
    clusterBorder: '#6366f1',          // Indigo border
    edgeLabelBackground: '#f1f5f9',    // Very light gray
    
    // Sequence diagram
    actorBkg: '#60a5fa',               // Medium blue
    actorBorder: '#2563eb',
    actorTextColor: '#1e293b',         // Dark text
    signalColor: '#6b7280',
    signalTextColor: '#1e293b',
    
    // State diagram
    labelColor: '#1e293b',
    
    // Fonts
    fontFamily: 'ui-sans-serif, system-ui, sans-serif'
  }
};

/**
 * Inject high-contrast theme into Mermaid diagram code
 * Only adds theme if no %%{init...}%% directive already exists
 */
function injectMermaidTheme(mermaidCode) {
  // Check if there's already an init directive
  if (mermaidCode.match(/%%\s*\{.*init.*\}.*%%/is)) {
    return mermaidCode; // Already has custom theming
  }
  
  // Create the init directive
  const initDirective = `%%{init: ${JSON.stringify(HIGH_CONTRAST_MERMAID_THEME)}}%%`;
  
  // Find the first line that's a diagram type declaration
  const lines = mermaidCode.split('\n');
  const diagramTypes = ['graph', 'flowchart', 'sequenceDiagram', 'classDiagram', 
                        'stateDiagram', 'erDiagram', 'journey', 'gantt', 'pie',
                        'quadrantChart', 'requirementDiagram', 'gitGraph', 
                        'mindmap', 'timeline', 'sankey', 'xychart', 'block'];
  
  // Find first non-empty, non-comment line
  let insertIndex = 0;
  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i].trim();
    if (trimmed && !trimmed.startsWith('%%')) {
      insertIndex = i;
      break;
    }
  }
  
  // Insert the init directive before the diagram declaration
  lines.splice(insertIndex, 0, initDirective);
  
  return lines.join('\n');
}

// Map language names to Notion-accepted values
function mapLanguage(lang) {
  const langMap = {
    'text': 'plain text',
    'txt': 'plain text',
    'sh': 'shell',
    'bash': 'shell',
    'zsh': 'shell',
    'js': 'javascript',
    'ts': 'typescript',
    'yml': 'yaml',
    'py': 'python',
    'rb': 'ruby',
    'md': 'markdown',
    'dockerfile': 'docker',
    'htm': 'html'
  };
  
  const mapped = langMap[lang.toLowerCase()] || lang.toLowerCase();
  
  // Valid Notion languages
  const validLangs = [
    'abap', 'arduino', 'bash', 'basic', 'c', 'clojure', 'coffeescript', 'c++', 'c#',
    'css', 'dart', 'diff', 'docker', 'elixir', 'elm', 'erlang', 'flow', 'fortran',
    'f#', 'gherkin', 'glsl', 'go', 'graphql', 'groovy', 'haskell', 'html', 'java',
    'javascript', 'json', 'julia', 'kotlin', 'latex', 'less', 'lisp', 'livescript',
    'lua', 'makefile', 'markdown', 'markup', 'matlab', 'mermaid', 'nix', 'objective-c',
    'ocaml', 'pascal', 'perl', 'php', 'plain text', 'powershell', 'prolog', 'protobuf',
    'python', 'r', 'reason', 'ruby', 'rust', 'sass', 'scala', 'scheme', 'scss',
    'shell', 'sql', 'swift', 'typescript', 'vb.net', 'verilog', 'vhdl', 'visual basic',
    'webassembly', 'xml', 'yaml'
  ];
  
  return validLangs.includes(mapped) ? mapped : 'plain text';
}

// Truncate text to Notion's limit (2000 chars)
function truncate(text, limit = 2000) {
  if (!text) return '';
  return text.length > limit ? text.substring(0, limit - 3) + '...' : text;
}

// Parse markdown table row
function parseTableRow(row) {
  return row
    .split('|')
    .slice(1, -1) // Remove empty first/last elements
    .map(cell => cell.trim());
}

// Check if a line is a table separator
function isTableSeparator(line) {
  return /^\|[\s:-]+\|/.test(line.trim()) && /^[\s|:-]+$/.test(line.trim());
}

// Parse markdown to Notion blocks
function markdownToNotionBlocks(markdown) {
  const lines = markdown.split('\n');
  const blocks = [];
  let i = 0;
  
  while (i < lines.length) {
    const line = lines[i];
    const trimmedLine = line.trim();
    
    // Skip empty lines
    if (!trimmedLine) {
      i++;
      continue;
    }
    
    // Code block
    if (trimmedLine.startsWith('```')) {
      const lang = trimmedLine.substring(3).trim() || 'plain text';
      const codeLines = [];
      i++;
      
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(lines[i]);
        i++;
      }
      
      let codeContent = codeLines.join('\n');
      
      // For Mermaid diagrams, inject high-contrast theme
      if (lang.toLowerCase() === 'mermaid') {
        codeContent = injectMermaidTheme(codeContent);
      }
      
      codeContent = truncate(codeContent);
      blocks.push({
        type: 'code',
        code: {
          rich_text: [{ type: 'text', text: { content: codeContent } }],
          language: mapLanguage(lang)
        }
      });
      i++; // Skip closing ```
      continue;
    }
    
    // Headings
    if (trimmedLine.startsWith('# ')) {
      blocks.push({
        type: 'heading_1',
        heading_1: { rich_text: parseInlineFormatting(truncate(trimmedLine.substring(2).trim())) }
      });
      i++;
      continue;
    }
    
    if (trimmedLine.startsWith('## ')) {
      blocks.push({
        type: 'heading_2',
        heading_2: { rich_text: parseInlineFormatting(truncate(trimmedLine.substring(3).trim())) }
      });
      i++;
      continue;
    }
    
    if (trimmedLine.startsWith('### ')) {
      blocks.push({
        type: 'heading_3',
        heading_3: { rich_text: parseInlineFormatting(truncate(trimmedLine.substring(4).trim())) }
      });
      i++;
      continue;
    }
    
    // Heading 4-6 → map to heading_3 (Notion only supports h1-h3)
    if (trimmedLine.match(/^#{4,6}\s+/)) {
      const headingText = trimmedLine.replace(/^#{4,6}\s+/, '').trim();
      blocks.push({
        type: 'heading_3',
        heading_3: { rich_text: parseInlineFormatting(truncate(headingText)) }
      });
      i++;
      continue;
    }
    
    // Divider
    if (trimmedLine.match(/^[-*_]{3,}$/)) {
      blocks.push({ type: 'divider', divider: {} });
      i++;
      continue;
    }
    
    // Tables
    if (trimmedLine.startsWith('|') && trimmedLine.endsWith('|')) {
      const tableLines = [];
      
      while (i < lines.length && lines[i].trim().startsWith('|')) {
        const rowLine = lines[i].trim();
        // Skip separator lines
        if (!isTableSeparator(rowLine)) {
          tableLines.push(rowLine);
        }
        i++;
      }
      
      if (tableLines.length > 0) {
        const headers = parseTableRow(tableLines[0]);
        const dataRows = tableLines.slice(1).map(parseTableRow);
        
        // Ensure consistent column count
        const columnCount = headers.length;
        
        // Create table block
        blocks.push({
          type: 'table',
          table: {
            table_width: columnCount,
            has_column_header: true,
            has_row_header: false,
            children: [
              // Header row
              {
                type: 'table_row',
                table_row: {
                  cells: headers.map(h => parseInlineFormatting(truncate(h)))
                }
              },
              // Data rows
              ...dataRows.map(row => ({
                type: 'table_row',
                table_row: {
                  cells: row.slice(0, columnCount).map(cell => parseInlineFormatting(truncate(cell)))
                }
              }))
            ]
          }
        });
      }
      continue;
    }
    
    // Checkbox list items (must check before regular bullet lists)
    // Matches: - [ ] unchecked, - [x] checked, - [X] checked
    // Also handles: * [ ], + [ ], -[ ] (no space), - [x], - [X]
    // Note: The checkbox regex MUST be checked before bullet list regex
    // to prevent "- [ ] task" being parsed as a bullet with text "[ ] task"
    const checkboxMatch = trimmedLine.match(/^[-*+]\s*\[([ xX])\]\s*(.*)/);
    if (checkboxMatch) {
      const checkChar = checkboxMatch[1];
      const isChecked = checkChar === 'x' || checkChar === 'X';
      const text = checkboxMatch[2].trim();
      blocks.push({
        type: 'to_do',
        to_do: {
          rich_text: parseInlineFormatting(truncate(text)),
          checked: isChecked
        }
      });
      i++;
      continue;
    }
    
    // Bulleted list
    if (trimmedLine.match(/^[-*]\s+/)) {
      const text = trimmedLine.replace(/^[-*]\s+/, '').trim();
      blocks.push({
        type: 'bulleted_list_item',
        bulleted_list_item: {
          rich_text: parseInlineFormatting(truncate(text))
        }
      });
      i++;
      continue;
    }
    
    // Numbered list
    if (trimmedLine.match(/^\d+\.\s+/)) {
      const text = trimmedLine.replace(/^\d+\.\s+/, '').trim();
      blocks.push({
        type: 'numbered_list_item',
        numbered_list_item: {
          rich_text: parseInlineFormatting(truncate(text))
        }
      });
      i++;
      continue;
    }
    
    // Blockquote/Callout
    if (trimmedLine.startsWith('> ')) {
      // Collect consecutive blockquote lines
      let quoteText = trimmedLine.substring(2).trim();
      i++;
      while (i < lines.length && lines[i].trim().startsWith('> ')) {
        quoteText += '\n' + lines[i].trim().substring(2).trim();
        i++;
      }
      
      blocks.push({
        type: 'callout',
        callout: {
          rich_text: parseInlineFormatting(truncate(quoteText)),
          icon: { emoji: '💡' }
        }
      });
      continue;
    }
    
    // Regular paragraph
    if (trimmedLine) {
      blocks.push({
        type: 'paragraph',
        paragraph: {
          rich_text: parseInlineFormatting(truncate(trimmedLine))
        }
      });
    }
    
    i++;
  }
  
  return blocks;
}

/**
 * Add table of contents block at the start of a block array
 * 
 * @param {Array} blocks - Array of Notion blocks
 * @param {Object} options - TOC options
 * @param {boolean} options.enabled - Whether to add TOC (default: true)
 * @param {number} options.minHeadings - Minimum headings required to add TOC (default: 3)
 * @param {boolean} options.force - Force TOC even if below minimum headings
 * @returns {Array} - Blocks with TOC prepended if appropriate
 */
function addTableOfContents(blocks, options = {}) {
  const {
    enabled = true,
    minHeadings = 3,
    force = false
  } = options;
  
  // Don't add TOC if disabled
  if (!enabled) {
    return blocks;
  }
  
  // Count headings in the document
  const headingCount = blocks.filter(block => 
    ['heading_1', 'heading_2', 'heading_3'].includes(block.type)
  ).length;
  
  // Only add TOC if we have enough headings (or force is true)
  if (!force && headingCount < minHeadings) {
    return blocks;
  }
  
  // Create toggle heading labeled "Contents" with marker for children
  // Note: Notion API requires heading children to be added separately
  const tocToggle = {
    type: 'heading_2',
    heading_2: {
      rich_text: [
        {
          type: 'text',
          text: { content: 'Contents' }
        }
      ],
      is_toggleable: true
    },
    // Special marker for upload.js to handle separately
    _pendingChildren: [
      {
        type: 'table_of_contents',
        table_of_contents: {}
      }
    ]
  };
  
  // Create divider block
  const divider = {
    type: 'divider',
    divider: {}
  };
  
  // Prepend toggle TOC and divider to the beginning
  return [tocToggle, divider, ...blocks];
}

module.exports = { 
  markdownToNotionBlocks, 
  parseInlineFormatting, 
  mapLanguage,
  injectMermaidTheme,
  HIGH_CONTRAST_MERMAID_THEME,
  addTableOfContents
};

// CLI mode
if (require.main === module) {
  const fs = require('fs');
  const args = process.argv.slice(2);
  
  if (args.length < 1) {
    console.log('Usage: markdown-to-notion.js <input.md> [output.json]');
    process.exit(1);
  }
  
  const inputFile = args[0];
  const outputFile = args[1];
  
  const markdown = fs.readFileSync(inputFile, 'utf8');
  const blocks = markdownToNotionBlocks(markdown);
  
  if (outputFile) {
    fs.writeFileSync(outputFile, JSON.stringify(blocks, null, 2));
    console.log(`Converted ${blocks.length} blocks → ${outputFile}`);
  } else {
    console.log(JSON.stringify(blocks, null, 2));
  }
}
