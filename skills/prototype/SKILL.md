---
name: prototype
description: Use when the user runs /prototype or asks to set up a playground / prototyping / sandbox space, spin up a quick throwaway experiment, or build and compare multiple versions / iterations / variations of something. Triggers on "make a playground", "prototype this", "let me try a few versions", "sandbox for X".
---

# Prototype

## Overview

`/prototype` sets up a fast, **throwaway** playground for exploring an idea through **multiple
variations side-by-side**, with **live tweakable parameters** and **Agentation** wired in so the
user can annotate the running prototype and feed that back to me.

**This is rough, disposable code — optimize for speed of iteration, not production quality.**

## Core principles

- **Move fast, keep it rough.** No tests, no error boundaries, no accessibility passes, no
  perf tuning unless asked. Hardcode freely. Minimal dependencies.
- **Built to be thrown away.** Don't gold-plate. Don't refactor for reuse. Expect to delete it.
- **Variations are the point.** Make it trivial to add, remove, duplicate, and tweak versions.
- **Everything tweakable.** Expose the meaningful parameters as live controls by default.

## Setup recipe

### 1. Location (adapt to context)
- **Inside an existing project** → scaffold a `prototypes/<name>/` subfolder and reuse that
  project's stack/tooling.
- **Not in a project** (empty dir, home dir, etc.) → spin up a fresh standalone scaffold in its
  own folder.

### 2. Stack
Default to **React + Vite** unless the surrounding project dictates otherwise, or the user
specifies a stack. Use **vanilla HTML + JS** only when asked, or for something genuinely tiny.

### 3. Layout for variations
- **Default: side-by-side gallery.** Render every variation together on one page, each in its own
  labeled card/cell in a grid or row. Best for component-sized things you compare at a glance.
- **Switch to tabs / a switcher** when the prototype is full-page or heavy to render (only one
  fits / renders comfortably at a time).
- Structure variations as separate components (`VariationA`, `VariationB`, …) so adding or removing
  one is a one-line change. Label each clearly on screen.

### 4. Configurable parameters (on by default)
Add a live control panel bound to the meaningful parameters. **Pick the library per my global
CLAUDE.md "Configurable parameters" rule** (tweakpane for vanilla/no-framework; leva for
React/R3F; dialkit for Solid/Svelte/Vue or when I want the designer-grade feel). Bind controls to
the *actual* values used in the variations, with sensible defaults, ranges, and steps. A shared
panel driving all variations is usually best for fair comparison; give a variation its own panel
when it has unique knobs.

### 5. Agentation (on by default — in-page tool + MCP)
- `npm install agentation` and mount the in-page annotator at the app root so the annotation
  icon appears in the running prototype.
- Prefer the **MCP integration** so I can read annotations directly and act on them
  conversationally. If the Agentation MCP server isn't connected in this session, fall back to the
  copy/paste flow: the user annotates, copies the generated markdown, and pastes it to me.
- Check the package's current README/`--help` for the exact mount API rather than guessing.

### 6. Run and verify
Start the dev server and confirm the playground actually renders — variations, control panel, and
Agentation icon all present — following the **Browser verification** section of my global
CLAUDE.md (Playwright CLI, headless by default).

## Suggested structure (React + Vite default)

```
prototypes/<name>/
  index.html
  src/
    main.jsx              # mounts App + Agentation
    App.jsx               # control panel + variations gallery (or switcher)
    params.js             # shared parameter defaults
    variations/
      VariationA.jsx
      VariationB.jsx
```

## Quick reference

| Decision | Default | Override when |
|----------|---------|---------------|
| Location | subfolder in project, else standalone | — |
| Stack | React + Vite | project stack differs, or user specifies |
| Variations layout | side-by-side gallery | full-page / heavy → tabs/switcher |
| Params library | per CLAUDE.md rule (leva/dialkit/tweakpane) | user names one |
| Annotation | Agentation, in-page + MCP | user says skip |

## Common mistakes

- **Over-building.** Adding tests, abstractions, or polish to throwaway code. Don't.
- **Dead controls.** A control panel whose knobs aren't actually wired to the rendered output.
- **Variations that drift apart.** Compared variations should share inputs/params so differences
  are real, not incidental.
- **Guessing the Agentation API.** Confirm the current mount/MCP setup from its docs.
- **Reporting it "done" unseen.** Verify it renders in the browser first.
