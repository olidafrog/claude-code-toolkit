---
name: google-workspace
description: Create, edit, and style Google Docs and Sheets via the gog CLI using Oli's house style. Use when asked to create a Google Doc/Sheet, export work (reports, specs, research, analyses) into Google Docs, pull files from Google Drive, or format existing Docs/Sheets. Handles routing across multiple Google accounts (personal / work / org).
---

# Google Workspace (gog) — house style & workflows

Wraps the `gog` CLI for Drive, Docs, Sheets, and Slides across Oli's Google
accounts. For command syntax, defer to the installed service skills
(`gog`, `gog-docs`, `gog-sheets`, `gog-drive`, `gog-slides`) and
`gog schema <service> --json` — do not guess flags.

## Account routing

Three accounts are configured as aliases:

| Alias      | Use for |
|------------|---------|
| `personal` | Personal files and documents |
| `work`     | Company Workspace (Oli is admin) |
| `org`      | Oli's own small organization |

- **Default is `work`.** Unless Oli specifies an account (or context clearly
  points elsewhere, e.g. a personal-project file → `personal`), use `work`.
- Always pass `--account <alias>` explicitly on every command — including when
  defaulting to `work`; never omit the flag.
- `gog auth list --check --json --no-input` shows configured accounts.

## Safety defaults

- Never send email. Include `--gmail-no-send` whenever a command chain could
  touch Gmail; drafting is fine, sending requires an explicit ask.
- Reads: prefer `--json --wrap-untrusted`; add `--readonly` when the task
  must not mutate anything.
- Before overwriting an existing Doc (`--replace`) or deleting anything,
  confirm the exact document and account first. Prefer `--append` or a new
  doc when intent is unclear.
- Never `--force` a destructive command without an explicit user ask.

## House style — Google Docs

Starter template; refine as Oli gives feedback (update this file when he does).

**Structure**
- Doc title = filename; first line uses the TITLE named style.
- Heading hierarchy: H1 for major sections, H2 for subsections, H3 sparingly.
- Short intro paragraph before the first heading — what this doc is and why.
- Use native tables for structured comparisons, not ASCII tables.
- Horizontal rule before appendices/reference sections.

**Typography (applied after markdown conversion)**
- Body: 11 pt, line spacing 115%, space below paragraphs 6 pt.
- TITLE: 26 pt bold. H1: 18 pt. H2: 14 pt bold. H3: 12 pt bold.
- Accent color for H2 headings: `#1A56DB` (blue). Body text default black.
- Bold key terms on first use; italics for asides only.

**Sheets**
- Row 1 = header: bold, white text on `#1F2937` background, frozen.
- Apply banding (alternating row colors) to data ranges.
- Numbers: thousands separators; currency with symbol; dates as `yyyy-mm-dd`.
- One table per sheet tab; tab names short and descriptive.

## Workflow recipes

### Markdown → styled Google Doc

1. Write/collect the markdown content (file or string).
2. Create and fill:
   ```bash
   gog --account <alias> docs create "<Title>" --json
   gog --account <alias> docs write <docId> --file <path.md> --markdown --replace
   ```
   Markdown headings map to named styles automatically.
3. Styling pass with `gog docs format <docId>` per the typography rules, e.g.:
   ```bash
   gog --account <alias> docs format <docId> --match "<H2 text>" --font-size 14 --bold --text-color "#1A56DB"
   ```
   Use `gog docs headings <docId> --json` to enumerate headings, and
   `gog docs structure <docId>` to verify positions before targeted formatting.
4. Report the doc URL back to the user.

### Data → formatted Sheet

1. `gog --account <alias> sheets create "<Title>" --json`
2. Write values (see `gog-sheets` skill for `update`/`append` syntax; CSV or
   JSON values input).
3. Formatting pass: header row style + freeze + banding + number formats per
   house style (`gog sheets format` / batch update commands).
4. Report the sheet URL back to the user.

### Claude Code work → Google Doc

When asked to "put this in a Google Doc" after producing work in a session:
1. Assemble the work product as clean markdown first (this is the source of
   truth; save alongside the project when it belongs to a repo).
2. Run the *Markdown → styled Google Doc* recipe on it.
3. Default account: ask or infer from the project the work came from.

## Style feedback loop

When Oli corrects formatting ("make headings bigger", "don't use blue"),
update the **House style** section of this skill in
`claude-code-toolkit/skills/google-workspace/SKILL.md` so the change sticks
for future documents.
