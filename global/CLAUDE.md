# Global preferences

## About me

I'm a Product Designer, so my strengths are on the design side. I understand engineering
concepts well, but I'm not an engineer — when a decision is primarily an engineering one,
give me a bit more context so I can follow the reasoning and make a good call.

**Where I'm comfortable (don't over-explain):**

- Front end: HTML and CSS, basic JavaScript.
- Component thinking: components, variants, props, state, design tokens.

**Where I need more guidance (slow down and explain):**

- Backend: APIs, servers, databases, auth, deployment, infrastructure. I'm much less familiar
  here, so explain what things are and why they matter, not just how to do them.

## How to communicate with me

- When an engineering decision has trade-offs, briefly explain the options and **give a clear
  recommendation** rather than leaving it open. Lead with the recommendation, then the why.
- Define backend/infra jargon the first time it comes up in a thread (a short parenthetical is fine).
- Use front-end and design analogies where they help (e.g. relate a backend concept to components,
  props, or design-system patterns).
- For backend work, tell me what a change affects and what could break, so I understand the
  consequences before approving it.
- It's fine to be concise on front-end and design topics — I don't need those spelled out.

## Design principles (apply by default to apps & UI)

**Use a 4-pixel grid.** Spatial values should be multiples of 4 by default:

- **Spacing:** margin, padding, gaps, and spacing between elements — all multiples of 4
  (4, 8, 12, 16, 24, 32, 40, 48, …).
- **Sizing:** component dimensions too — heights, widths, icon sizes, control/touch targets —
  multiples of 4.

This keeps elements consistent and fitting together cleanly. When in doubt, round to the nearest
multiple of 4.

**Defer to the design system when there is one.** If a component library or design system defines
its own sizing/spacing scale, follow that scale — don't fight it to force a 4px value. Most modern
systems already align with this anyway: **Tailwind**'s spacing scale is built on 4px (`1` = 4px),
and **Radix** follows the same convention. So in practice the 4px grid and these tools agree.

## UI Polish Principles

Polish is not a feature you prompt for. You can't type "make it premium" and get there. The model
is a phenomenal pair of hands — the taste, the rules, and the hundred tiny decisions are still
mine. These principles encode that taste. Apply them unless a brief explicitly overrides them.

### 1. Design tokens first, always

Before building any component, define the full token set and paste it into your prompt. Forbid
one-off values explicitly — this single instruction kills 80% of generic AI output.

```css
:root {
  /* Easing */
  --ease-smooth: cubic-bezier(0.22, 1, 0.36, 1);    /* default for almost everything */
  --ease-out:    cubic-bezier(0.17, 1, 0.32, 1);     /* decorative entrances */
  --ease-spring: cubic-bezier(0.35, 1.55, 0.65, 1);  /* badges, pops, overshoot */
  --ease-in-out: cubic-bezier(0.66, 0, 0.34, 1);     /* symmetric moves */

  /* Duration */
  --duration-fast:   150ms;
  --duration-normal: 200ms;
  --duration-slow:   280ms;

  /* Corner radius — scaled to component size */
  --radius-xs: 12px;   /* buttons, tags, chips */
  --radius-sm: 16px;   /* cards, inputs, dropdowns */
  --radius-md: 24px;   /* modals, panels, sheets */

  /* Shadows */
  --shadow-card:
    0 1px 2px rgba(0, 0, 0, 0.05),
    0 2px 4px rgba(0, 0, 0, 0.02),
    0 0 0 0.5px rgba(0, 0, 0, 0.08);

  --shadow-elevated:
    0 4px 8px rgba(0, 0, 0, 0.02),
    0 8px 12px rgba(0, 0, 0, 0.02),
    0 2px 4px rgba(0, 0, 0, 0.02),
    0 1px 2px rgba(0, 0, 0, 0.04),
    0 0 0 0.5px #e0e0e0;
}
```

Prompt instruction: *"Use only these tokens. No one-off values, no magic numbers."*

### 2. Easing: default curves are banned

The browser's built-in `ease` and `ease-in-out` read as generic. Never use them. Always reference
the house easing set above by variable name. Specificity is the whole game — never say "smooth",
give the exact curve.

### 3. Corner radius scales with component size

Using the same radius everywhere makes small and large components feel unbalanced. Scale it:

- `--radius-xs: 12px` → buttons, tags, chips, badges
- `--radius-sm: 16px` → cards, inputs, dropdowns, list rows
- `--radius-md: 24px` → modals, bottom sheets, panels

As components get larger, increasing the radius preserves the same visual softness. Prompt:
*"Use --radius-xs for the button, --radius-sm for the card wrapper."*

### 4. Entrances: never a plain fade

A flat opacity transition is the most overused entrance and the least premium. Always combine
three things:

```
opacity: 0 → 1
translateY: 6px → 0
filter: blur(2px) → blur(0)
duration: ~280ms on --ease-smooth
```

The blur is the key ingredient — content focuses into place instead of flicking on. No new easing
needed: the smooth preset handles everything.

Prompt: *"Entrance = fade + 6px rise + 2px blur clearing, ~280ms on --ease-smooth."*

### 5. Depth: layered shadows, never single drop-shadow

A flat single-blur shadow is an immediate tell. Stack multiple layers at low opacities (2–8%):

- A hairline ring (`0 0 0 0.5px`) replaces the border — this is the single biggest mark of a
  hand-crafted UI
- A tight contact shadow for the edge
- A wide soft ambient for the lift

Heavy shadows look cheap. Depth is the sum of many faint layers, not one dark one.

### 6. Tactility: every interactive element has a press state

```css
.interactive:active {
  transform: scale(0.98);
  transition: transform var(--duration-fast) var(--ease-smooth);
}
```

`0.98` — not `0.9` (too dramatic), not absent (too dead). Apply to buttons, tabs, swatches, list
rows, cards. Tooltips never appear instantly — they fade + lift 4px + clear a 2px blur.

### 7. Expand / collapse: grid rows, not max-height

`max-height: 9999px` is jittery and times wrong. The correct technique:

```css
.reveal {
  display: grid;
  grid-template-rows: 0fr;
  transition: grid-template-rows var(--duration-normal) var(--ease-smooth);
}
.reveal[data-open="true"] { grid-template-rows: 1fr; }
.reveal > * { overflow: hidden; }
```

Animates to the content's real height, perfectly smooth. For elements moving between containers,
use FLIP (First–Last–Invert–Play).

### 8. Auto-growing textareas

Never introduce nested scrolling in a form. Let textareas grow with their content:

```css
textarea {
  field-sizing: content;
}
```

One line. Always better for writing experiences and form scannability.

### 9. Proximity-based responsiveness

UI shouldn't be binary (hover on / off). Use cursor proximity to create a gradient of response.

**Dock / icon scaling by proximity:**
```js
onpointermove = e => document.querySelectorAll(".dock > *").forEach(el => {
  const r = el.getBoundingClientRect();
  const t = Math.max(0, 1 - Math.abs(e.clientX - r.x - r.width / 2) / 120);
  el.style.scale = 1 + t * 0.5;
});
```

Apply this principle selectively to navigation, toolbars, and floating action areas — not
globally. The effect makes interfaces feel alive rather than digital.

### 10. Backdrop blur: use motion state, not static value

A navbar blur that stays constant reads as decoration. Blur that responds to scroll state reads as
physics:

```js
let t;
const nav = document.querySelector(".navbar");
window.addEventListener("scroll", () => {
  nav.style.backdropFilter = "blur(8px)";
  clearTimeout(t);
  t = setTimeout(() => {
    nav.style.backdropFilter = "blur(24px)";
  }, 120);
});
```

Light blur while moving (8px), settles to deeper blur at rest (24px). Pair with a subtle tint
(`linear-gradient` at 10–15% black) rather than flat opacity — this reads as glass, not a dark
overlay.

### 11. State-driven thinking: a component is a system, not a picture

Always enumerate states before building: `idle / hover / pressed / loading / disabled / success /
error`. Expect to discover 2–3 additional states during build — that's where polish actually lives.

Prefer expressive micro-state transitions:
- Digits roll rather than hard-cut
- Labels shimmer while a task is working
- Icons cross-fade and scale between states, never swap

A mockup always looks complete. Building surfaces the holes.

### 12. Accessibility and performance are part of polish

- Always honour `prefers-reduced-motion` — animations collapse to instant, decorative loops stop
  entirely
- Animate `transform` and `opacity` on large surfaces and long lists
- Reserve heavier properties (layered shadows, height reveals) for deliberate, small moments
- 60fps is a baseline requirement, not a bonus

### 13. Font smoothing: always override browser defaults

Browsers default to subpixel antialiasing, which renders text heavier and slightly blurrier
than intended — and nothing like how it looks in Figma. Set this globally on every project:

```css
* {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}
```

This shifts from subpixel (colour-based, heavier) to grayscale antialiasing (lighter, cleaner).
Nothing moves — layout, spacing, and line breaks are unaffected. It's a purely visual fix.

**Caveats to apply with judgment:**
- **Mac only.** Windows uses ClearType, which CSS cannot override. Windows users always see
  subpixel rendering — this fix targets the Mac/Retina side of the equation, which is where
  the Figma-to-browser delta is most visible.
- **Watch thin weights at small sizes.** `antialiased` removes weight from letterforms, which
  is the point — but on `font-weight: 300` or below at 14px or smaller, it can push text into
  feeling too faint. Compensate by bumping weight as size decreases: what reads at 400/16px
  may need 500/13px to hold the same presence.
- **Dark backgrounds amplify the difference.** Subpixel is at its heaviest on dark surfaces.
  This fix is especially important for light text on dark UI.

**Use WOFF2 for web fonts.** Format doesn't affect rendering (the OS rasterizer handles that
regardless), but WOFF2 is the smallest and best-supported format — use it for load performance.

### Prompting rules for UI work

1. **Give numbers, never adjectives.** "Smooth" is meaningless. `cubic-bezier(0.22, 1, 0.36, 1) at
   280ms` is buildable.
2. **Paste token block first.** Explicitly forbid one-off values.
3. **List all states explicitly.** Claude builds exactly what's named — no more.
4. **Isolate when iterating.** *"Now only tune the shadow stack."* One variable at a time reaches
   polish without thrashing.
5. **Describe the feeling + a reference.** *"Like an iOS sheet: weighty, slightly springy, settles
   fast."* Reference-anchored requests land better than abstract ones.
6. **On Figma handoff:** Name every property to extract — padding, gaps, tokens, radius, type
   sizes and weights. Never assume the handoff carries everything automatically.

## Markdown checklists

I read markdown in **MacDown**, which only renders task lists with `*` bullets. When writing
checkboxes/checklists in any `.md` file, use:

```markdown
* [ ] unchecked
* [x] checked
```

Not `- [ ]` — MacDown renders that as a literal `[ ]` instead of a checkbox. This applies only to
task-list items; ordinary bullets can stay as `-`.

## Documentation structure

Treat a project's `CLAUDE.md` as a **high-level index and reference point**, not a dump for all
detail. It should hold:

- A short, high-level project overview (what it is, the stack, how to run it).
- Conventions and context that apply to **most** tasks in the project.
- An **index that links out** to the detailed docs (e.g. `- [Auth flow](docs/auth.md) — how login
  and sessions work`).

Put structured, detailed documentation in a **`/docs` folder at the project root**. Use it (create
it if it doesn't exist) for anything task-specific or deep: architecture, data models, API
contracts, integrations, setup runbooks, decisions, etc. One topic per file.

When you add or meaningfully change a feature, update the relevant `/docs` file (or create one) and
make sure `CLAUDE.md`'s index points to it. Keep `CLAUDE.md` lean — if a section is growing into
detail, move it into `/docs` and leave a link behind.

## Configurable parameters for prototypes & designs

I frequently want the parameters of a prototype or design (sizes, colors, timings, easing,
counts, physics, etc.) exposed as **live, tweakable controls** so I can dial them in by eye
instead of editing code. I use one of three control-panel libraries for this.

**Trigger phrases:** when I say "drop in a dialkit", "add leva", "use tweakpane", or similar, use
that exact library. When I say something vague like "expose the settings", "make these tweakable",
"let me play with the parameters", or "add controls" — **you pick** the best fit for the stack
using the guide below, tell me which you chose and why in one line, then wire it up.

**The three libraries:**

- **leva** (`leva`, pmndrs) — React-only, hooks-based (`useControls`). The de-facto standard in the
  React / React Three Fiber world; tons of examples and tight R3F integration.
- **dialkit** (`dialkit`, Josh Puckett) — multi-framework: React, Solid, Svelte 5, Vue 3. Mount
  `DialRoot` at the app root, then a per-framework hook (`useDialKit` in React). The most
  **designer-feeling** option: rubber-band drag, click-to-snap, inline (non-floating) mode,
  presets, and keyboard shortcuts. Needs `motion` as a peer dep.
- **tweakpane** (`tweakpane`, cocopon) — framework-agnostic vanilla JS. Works anywhere, no
  framework required. Clean, compact UI; the right call for plain HTML/JS or vanilla Three.js.

**How to pick when I leave it to you:**

1. **No framework / plain HTML + JS / vanilla Three.js** → **tweakpane** (it's the only one that
   doesn't assume a framework).
2. **React or React Three Fiber** → **leva** by default (best-supported in that ecosystem). Reach
   for **dialkit** instead if I want the nicer designer interactions, presets, or an inline panel.
3. **Solid, Svelte 5, or Vue 3** → **dialkit** (leva is React-only; dialkit covers these natively).

When you wire one up: install it, set up any required root/provider, bind the controls to the
actual parameters (don't leave them as dead UI), and give each control a sensible default, range,
and step so the panel is usable immediately.

## Browser verification (frontend + core functionality)

**Verify by default.** After front-end work or any change to core functionality, verify it
actually works in a browser — don't just report it as done. Use Playwright CLI for this by
default. Only reach for deeper/more sophisticated tooling (Chrome DevTools MCP) when the check
needs it — see below.

**Run headless by default.** Don't open a visible browser window unless I explicitly ask to
watch it live.

Machine-specific setup — where the Playwright browsers and `playwright-cli` live, exact versions,
and PATH-recovery steps — lives in the per-machine file imported at the bottom of this document.
Check there before concluding a tool is missing; **a missing PATH is not "no browser."**

### 1. Default: Playwright CLI

```bash
which playwright-cli   # should resolve; if not, see the machine file's PATH-recovery note

# Standard flow (start the project's dev server first):
npm run dev                                  # e.g. Vite serves http://localhost:5173
playwright-cli open http://localhost:5173/   # or a specific page, e.g. /metaballs.html
playwright-cli snapshot                      # accessibility-tree — preferred, token-efficient
playwright-cli screenshot                    # live visual capture when a picture is needed
playwright-cli close
```

Artifacts (snapshots + console logs) land in the project's `.playwright-cli/`.

### 2. Secondary: Chrome DevTools MCP

Use `mcp__chrome-devtools__*` when the check needs **console errors, network requests, performance
traces, or Lighthouse**. It auto-launches Chrome (no extension required):
`take_screenshot`, `list_console_messages`, `list_network_requests`, `performance_*`,
`lighthouse_audit`, `list_pages`.

### 3. Do NOT default to Claude-in-Chrome

`mcp__claude-in-chrome__*` requires the Chrome **extension** to be connected and is **not** the
default verification tool. Use it only to drive the user's real, logged-in browser, and only after
`list_connected_browsers` returns a **non-empty** list. An empty `[]` result, "no browser
detected," or "extension not connected" refers **only** to this stack — fall through to Playwright
CLI; it does not mean nothing is available.

### Troubleshooting the false negatives

- "browser isn't installed" → check the browser cache path listed in the machine file first (they
  are normally installed). Only if truly missing: `npx playwright install chromium`.
- "no browser detected" / "extension not connected" → that is Claude-in-Chrome only. Switch to
  Playwright CLI rather than reporting total failure.

---

<!-- Per-machine tooling notes. The sync script symlinks ~/.claude/machine.md to the correct file
     for this machine (global/machine-mac.md or global/machine-windows.md). -->
@~/.claude/machine.md
