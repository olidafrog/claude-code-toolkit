# Extracting a logo from a company's website

Reach here when the keyless SVG sources (`references/sources.md` §1) miss, or the user wants the
*current* official logo — including logos that exist **only as inline `<svg>` in the page's DOM**
(common on Wix / Webflow / Framer sites). **Prefer Playwright CLI**: its `eval` command runs JS on
a selector-targeted element, so it extracts inline SVG markup directly. The `mcp__playwright__*`
tools are the fallback if the CLI is unavailable.

## Browser setup

Playwright CLI lives under Node v22.17.1 (not the active PATH). Put it on PATH or use the full path;
run headless:

```bash
export PATH="$HOME/.nvm/versions/node/v22.17.1/bin:$PATH"   # or: nvm use 22
playwright-cli open "<url>"
playwright-cli snapshot                 # a11y tree — locate the logo link/img/ref
playwright-cli eval "<func>" [target]   # run JS on the page, or on a selector-targeted element
playwright-cli screenshot               # visual confirmation
playwright-cli close
```

## Extract an inline `<svg>` by selector (the reliable path)

When the logo is inline in the DOM, grab it with the bundled extractor via `eval --filename`:

```bash
playwright-cli open "<url>"
playwright-cli eval "$(cat <skill>/scripts/extract_inline_svg.js)" "<css-selector>" --filename raw.svg
playwright-cli close
```

- **Selector:** use one the user gives you, or DevTools → right-click the node → *Copy selector*
  (Wix ids look like `#comp-xxxxxxxx > a > div > svg`), or one of the logo heuristics below. The
  extractor accepts the `<svg>` itself **or any ancestor** (it drills down to the first `<svg>`).
- **`extract_inline_svg.js`** clones the SVG, **inlines computed `fill`/`stroke`** (so CSS- or
  `currentColor`-driven logos survive standalone), ensures `xmlns` (+ `xmlns:xlink`) and a `viewBox`,
  and strips `<script>` / `on*` / `data-*` / `class`. Returns a clean, standalone SVG string.
- **Unwrap:** `eval --filename` writes the return value **JSON-quoted** (leading `"`, escaped `\"`).
  Normalize to raw SVG before using it:
  ```bash
  python3 -c 'import json,sys; p=sys.argv[1]; s=open(p).read().strip(); open(p,"w").write(json.loads(s) if s[:1]==chr(34) else s)' raw.svg
  ```
- **Verify + finish:** `python3 <skill>/scripts/check_svg.py raw.svg` must be `clean-vector`, then
  save to the library and run `make_variants.py` like any other SVG.

## Where the mark lives (when you have no selector)

1. **Press / brand pages first** for known brands: `/brand`, `/press`, `/media`, `/newsroom`,
   `/about/brand`, `press.<domain>`, or a footer "Brand assets" / "Media kit" link. These give the
   cleanest official SVGs (usually light + dark + icon). Download those directly.
2. **Masthead / nav** `<svg>` or `<img>`: `header a[href="/"] svg`, `a[aria-label*="home" i] svg`,
   `[class*="logo" i], [id*="logo" i]`, the first `<header>`'s first `<img>`/`<svg>`.
3. **Favicon / touch icon** (icon-only, fine if an icon was requested):
   `<link rel="icon" type="image/svg+xml">`, `apple-touch-icon`.

### Locator heuristic (auto-find when no selector is given)

Run via `playwright-cli eval "<this func>"` to classify the logo, then extract the inline `<svg>` or
`curl` the `img`/`css-bg` asset:

```js
(() => {
  const pick = document.querySelector(
    'header a[href="/"] svg, [class*="logo" i] svg, header svg, a[aria-label*="home" i] svg'
  );
  if (pick) return { type: 'inline-svg', svg: pick.outerHTML };
  const img = document.querySelector(
    'header a[href="/"] img, [class*="logo" i] img, header img[alt*="logo" i], img[src*="logo" i]'
  );
  if (img) return { type: 'img', src: img.currentSrc || img.src };
  const el = document.querySelector('[class*="logo" i], [id*="logo" i]');
  if (el) {
    const bg = getComputedStyle(el).backgroundImage;
    const m = bg && bg.match(/url\(["']?(.*?)["']?\)/);
    if (m) return { type: 'css-bg', src: new URL(m[1], location.href).href };
  }
  return { type: 'none' };
})();
```

### Handle each type

- **`inline-svg`** → extract with `scripts/extract_inline_svg.js` (see "Extract an inline `<svg>` by
  selector" above); pass the heuristic selector as the `eval` target. Verify with `check_svg.py`.
- **`img` / `css-bg`** → resolve to an absolute URL, then `curl -sL "<url>" -o "<file>"`. Could be
  `.svg` (best), `.png`, `.webp`, `.avif`. Convert webp/avif→png with `sips` if a PNG is needed
  (`references/verify-and-convert.md`).

## Manual cleanup fallbacks (rare — the extractor handles the common cases)

`extract_inline_svg.js` already inlines computed fills, adds `xmlns`/`viewBox`, and strips
`<script>` / `on*` / `data-*` / `class`. Reach for manual work only when a logo still renders blank
or wrong:

- **Sprite `<use>`.** If the mark is `<use xlink:href="#id">` into a sprite, find the matching
  `<symbol id="id">` (often an inline `<svg style="display:none">` elsewhere on the page) and inline
  its contents — the extractor does not chase cross-element sprite references.
- **Gradient / pattern paint.** If shapes fill from `url(#grad)`, keep the `<defs>` gradient (it is
  copied with the clone) or set an explicit fill.
- Re-run `check_svg.py` after any manual fix.
