# Verify & convert

Everything here is local and offline except the `npx` fallbacks (which need network on first run).
Run the QA before delivering; convert only when the requested format differs from what you found.

## Verify transparency & vector quality

### SVG
```bash
python3 "<skill>/scripts/check_svg.py" "<file.svg>"
```
Prints JSON + exit code (0 = `clean-vector`). Flags:
- `is_fake_vector: true` → it's a base64 `<image>` wrapped in `<svg>`; treat as raster, not vector — reject.
- `has_full_canvas_opaque_bg: true` → an opaque rect/background sits behind the mark → **not transparent**.
  Exception: a logo whose *design itself* fills the canvas (app-tile style, e.g. a rounded colored
  square) is expected to be opaque — that's the logo, not a removable background. Use judgment.
- `has_viewbox: false` → warn (may not scale cleanly); add a viewBox if you can.

### PNG (or any raster)
```bash
sips -g hasAlpha -g format -g pixelWidth -g pixelHeight "<file.png>"     # channel + dimensions
python3 "<skill>/scripts/check_image.py" "<file.png>"                    # corner-pixel truth
```
`check_image.py` verdicts: `transparent` (corners at alpha 0 — good), `opaque-background`
(a solid/near-uniform bg is baked in — reports `background_rgb`), `no-alpha` (no alpha channel),
`uncertain`. **`sips -g hasAlpha` = yes is not enough on its own** — a white box can have an alpha
channel; the corner check is what proves real transparency.

## Convert (only when needed)

### SVG → transparent PNG  (user asked for PNG but only SVG exists)
Default **1024px on the long edge, transparent background.**
- **Preferred — headless screenshot with transparent bg** via Playwright/Chrome-DevTools MCP: load
  the SVG (or an HTML wrapper sizing it to the target), screenshot the SVG element with
  `omitBackground: true`. Keeps alpha, no extra install.
- **Alt — resvg** (no local rasterizer otherwise): `npx @resvg/resvg-js-cli "<in.svg>" -o "<out.png>" --width 1024`
  (downloads on first run; preserves transparency).

### PNG resize / format convert  (all preserve alpha)
```bash
sips -Z 1024 "<in.png>" --out "<out.png>"                  # scale long edge to 1024
sips -s format png "<in.webp>" --out "<out.png>"           # webp/avif/tiff → png
```
For a crisp @2x, also export at 2048px.

## Last-resort background removal — FLAGGED, never silent

Only after telling the user no genuinely-transparent source exists and they accept the trade-off:
```bash
python3 "<skill>/scripts/make_transparent.py" "<in.png>" "<out.png>" [tolerance]
```
Flood-fills from the corners, making the connected background color transparent. **Lossy:** frays
anti-aliased edges, can eat legitimately-white parts of the mark, may leave halos. Inspect the
result. Prefer finding a real transparent source over this.

## Light/dark variants (SVG only — runs automatically)

After an SVG passes the gate, produce monochrome background variants:
```bash
python3 "<skill>/scripts/make_variants.py" "<Library>/<Company>/"     # whole folder
python3 "<skill>/scripts/make_variants.py" "<file.svg>"               # one file
```
- Folders are named by the **asset's own color**, not the background (both stay transparent):
  `<Company>/light/<name>.svg` = the light-colored (**white**) logo → use on dark backgrounds;
  `<Company>/dark/<name>.svg` = the dark-colored (**black**) logo → use on light backgrounds.
- **Colors** are two constants at the top of the script — `LIGHT_COLOR = "#FFFFFF"` and
  `DARK_COLOR = "#000000"`. Edit those single lines to set different asset colors.
- **Geometry is never changed** — only `fill`/`stroke`/`stop-color` (attributes, inline `style`,
  and `<style>` blocks) are rewritten; `fill:none` is preserved. Output stays a real vector and
  passes `check_svg.py`.
- **PNGs and non-SVG files are skipped.** Files already inside a `light/`/`dark/` folder are skipped.
- **Monochrome caveat:** flattening to one color is correct for logos whose parts are separate
  opaque shapes on a transparent ground (most). It can *merge detail* on logos that use an opaque
  **white knockout** shape to carve negative space — those become a solid blob. The script prints
  a `⚠ multi-color source` heads-up when the source has >2 colors; eyeball those (render the `dark/`
  copy on a dark background). If it flattened badly, source a proper mono/white version instead.

## Tracing (raster → SVG)

No local tracer. Per the locked decision, **do not fabricate a vector** — deliver the best
transparent PNG plus a note. Only if the user *explicitly* asks to trace: `npx potrace` (monochrome
only) or `npx @neplex/vectorizer` — lossy, and flag the fidelity caveat.
