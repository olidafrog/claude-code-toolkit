#!/usr/bin/env python3
"""Generate light- and dark-background monochrome variants of an SVG logo.

Usage:
  python3 make_variants.py <file.svg> [<file2.svg> ...]
  python3 make_variants.py <company_dir>          # every top-level *.svg in the folder

For each input SVG it writes a recolored copy into a `light/` and a `dark/` subfolder beside
the file (same filename). SVG ONLY — PNGs and anything else are skipped. Geometry is never
touched (only color attributes change), so the mark's shape is preserved exactly.

Folders are named by the ASSET's own color (not the background). Both stay transparent:
  light/  = the light-colored (white) logo  → use on DARK backgrounds
  dark/   = the dark-colored (black) logo    → use on LIGHT backgrounds

── Configure the two asset colors here (single line each, editable). These recolor the logo's
   ink only; they never add a background.
"""
LIGHT_COLOR = "#FFFFFF"   # the light-colored asset (white) — for placing on dark backgrounds
DARK_COLOR  = "#000000"   # the dark-colored asset (black)  — for placing on light backgrounds
# ────────────────────────────────────────────────────────────────────────────────────────────

import sys
import os
import re

KEEP = {"none", "transparent"}          # colors we must never overwrite


def _repl_attr(text, attr, color):
    """Rewrite  attr="value"  ->  attr="color"  (unless value is none/transparent)."""
    pat = re.compile(r'(\b%s\s*=\s*)(["\'])(.*?)\2' % re.escape(attr), re.I | re.S)

    def f(m):
        return m.group(0) if m.group(3).strip().lower() in KEEP else '%s"%s"' % (m.group(1), color)

    return pat.sub(f, text)


def _repl_style_prop(text, prop, color):
    """Rewrite  prop:value  inside style="" or <style> blocks (unless value is none/transparent)."""
    pat = re.compile(r'(\b%s\s*:\s*)([^;"\'}]+)' % re.escape(prop), re.I)

    def f(m):
        return m.group(0) if m.group(2).strip().lower() in KEEP else '%s%s' % (m.group(1), color)

    return pat.sub(f, text)


def recolor(svg, color):
    for name in ("fill", "stroke", "stop-color"):
        svg = _repl_attr(svg, name, color)      # note: fill-rule / fill-opacity are untouched (need ':' or '=' right after 'fill')
        svg = _repl_style_prop(svg, name, color)

    # Ensure the root <svg> carries a fill so default-black inheriting shapes get colored too.
    def root(m):
        tag = m.group(0)
        if re.search(r'\bfill\s*=', tag, re.I):
            return re.sub(r'(\bfill\s*=\s*)(["\']).*?\2', r'\1"%s"' % color, tag, count=1, flags=re.I | re.S)
        if tag.rstrip().endswith('/>'):
            return re.sub(r'/>\s*$', ' fill="%s"/>' % color, tag)
        return re.sub(r'>\s*$', ' fill="%s">' % color, tag)

    return re.sub(r'<svg\b[^>]*>', root, svg, count=1, flags=re.I | re.S)


def distinct_colors(svg):
    cols = set()
    for m in re.finditer(
        r'(?:fill|stroke|stop-color)\s*[=:]\s*["\']?\s*(#[0-9a-fA-F]{3,8}|rgba?\([^)]*\)|url\([^)]*\))',
        svg, re.I,
    ):
        v = m.group(1).lower()
        if v not in KEEP:
            cols.add(v)
    return cols


def process(path):
    if not path.lower().endswith(".svg"):
        print("skip (not svg):", os.path.basename(path)); return
    d = os.path.dirname(os.path.abspath(path))
    if os.path.basename(d) in ("light", "dark"):
        print("skip (already a variant):", path); return
    name = os.path.basename(path)
    try:
        svg = open(path, "r", encoding="utf-8").read()
    except Exception as e:  # noqa: BLE001
        print("skip (unreadable):", path, e); return

    n_colors = len(distinct_colors(svg))
    for folder, color in (("light", LIGHT_COLOR), ("dark", DARK_COLOR)):
        od = os.path.join(d, folder)
        os.makedirs(od, exist_ok=True)
        open(os.path.join(od, name), "w", encoding="utf-8").write(recolor(svg, color))

    warn = "  ⚠ multi-color source — eyeball the mono result keeps its detail" if n_colors > 2 else ""
    print("%-22s -> light/ (%s, white) + dark/ (%s, black)  [%d source colors]%s"
          % (name, LIGHT_COLOR, DARK_COLOR, n_colors, warn))


def main(args):
    targets = []
    for a in args:
        if os.path.isdir(a):
            targets += [os.path.join(a, f) for f in sorted(os.listdir(a)) if f.lower().endswith(".svg")]
        else:
            targets.append(a)
    if not targets:
        print("no SVG inputs"); return 2
    for t in targets:
        process(t)
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: make_variants.py <file.svg|dir> ...")
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))
