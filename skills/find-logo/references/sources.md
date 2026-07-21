# Logo sources — ranked, with exact queries

Work top-down. Stop at the first candidate that passes the verification gate. Prefer a
**direct SVG URL you can `curl`** before resorting to the browser. All commands below are
keyless unless noted.

## 0. Resolve identity (always first)

- Find the official site/domain: `WebSearch` for `"<name>" official website` or `<name> company`.
- **Disambiguate before fetching.** If the name maps to more than one well-known entity, ASK:
  - Jaguar (car) vs jaguar (animal); Apple (tech) vs apple (fruit); Shell (energy) vs shell.
  - Two real companies sharing a name (e.g. "Sun" — Sun Microsystems vs others).
- Note the domain — several sources key off it (e.g. `stripe.com`).

## 1. Curated keyless SVG (fastest, cleanest — try these first)

### SVGL — best first stop for popular tech/consumer brands
- Search: `curl -s "https://api.svgl.app?search=<name>"` → JSON array.
- Each item: `title`, `route` (SVG URL **or** `{ "light": url, "dark": url }` for theme
  variants), sometimes `wordmark` (alternate route), `brandUrl`, `category`.
- Pick `route` (or `route.light` for light backgrounds / `route.dark` for dark), then
  `curl -sL "<route>" -o "<file>.svg"`. Full-color, transparent, clean.
- Full list (to eyeball slugs): `curl -s "https://api.svgl.app"`.

### Wikipedia / Wikimedia Commons — broad, authoritative, transparent SVG
Good for brands SVGL doesn't cover; often the official wordmark/lockup.
1. Find the article: `curl -s "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=<name>&format=json"`.
2. List the page's images: `curl -s "https://en.wikipedia.org/w/api.php?action=query&titles=<Page>&prop=images&format=json"` — look for a `File:*logo*.svg` (or `*wordmark*`, `*.svg`).
3. Fetch the original file directly (redirects to the real asset URL):
   `curl -sL "https://commons.wikimedia.org/wiki/Special:FilePath/<File name>.svg" -o "<file>.svg"`
   (or resolve via `action=query&titles=File:<name>&prop=imageinfo&iiprop=url&format=json`).

### Simple Icons — ONLY for monochrome-icon requests
Single-color glyph, **icon only** (no wordmark, no brand color). Not a substitute for a
full-color lockup.
- `curl -sL "https://cdn.simpleicons.org/<slug>" -o "<file>.svg"` (add `/<hexcolor>` to tint).
- Slug ≈ lowercase brand name without spaces; confirm at simpleicons.org if unsure.

## 2. Official website (authoritative / most current)

Use when tier 1 misses, or when the user wants the *current* official logo. Best spots:
`/brand`, `/press`, `/media`, `/newsroom`, `/about/brand`, a "Brand assets" / "Media kit" link
in the footer, `press.<domain>` — then the masthead/nav, then the favicon/apple-touch-icon.
Many big brands (Stripe, Figma, Notion…) publish official SVG packs on these pages — check them
before scraping the nav. Full how-to: `references/extraction.md`.

## 3. Aggregators + image search (fallback)

- **WorldVectorLogo** — `https://worldvectorlogo.com/search/<name>` → logo page → "Download SVG"
  (often a direct SVG; may need the browser to click through).
- **SVGRepo** — `https://www.svgrepo.com/vectors/<name>/` — sometimes free brand SVGs.
- **Seeklogo** — `https://seeklogo.com/search?q=<name>` — SVG often gated behind login; PNG
  frequently free. Use the browser.
- **Google Images** (last resort for a raster) — search `<name> logo png transparent`; prefer
  the largest dimensions; **verify transparency** (many "transparent" hits are checkerboard-baked
  or watermarked). Fetch via `WebFetch` / browser, then run the gate.

## 4. Optional keyed accelerators — OFF by default

Only if Oli adds a free API key (store it in an env var; the skill reads it, otherwise skips):
- **Brandfetch** — logo CDN `https://cdn.brandfetch.io/<domain>?c=<CLIENT_ID>`; returns
  SVG/PNG, light/dark, icon/logo/symbol. Fast + high quality when keyed.
- **logo.dev** — `https://img.logo.dev/<domain>?token=<KEY>&format=png` (svg on paid).
- **Clearbit** — `https://logo.clearbit.com/<domain>` — no key, **PNG only, often not
  transparent**, officially sunsetting. Use only as a quick probe, never as the final answer.

## Choosing among candidates
SVG > PNG. Official/curated > aggregator > image search. Full-color primary unless a variant was
asked for. Higher resolution for rasters. **Always run the verification gate before committing.**
