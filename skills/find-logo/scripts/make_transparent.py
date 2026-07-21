#!/usr/bin/env python3
"""LAST-RESORT background remover for the find-logo skill.

Usage: python3 make_transparent.py <in> <out> [tolerance]

Flood-fills from the image corners, making the connected background color (within <tolerance>
of the corner color, default 24) transparent. Flooding from the edges — rather than a global
color threshold — preserves enclosed same-color regions (e.g. the white counter inside an 'O').

LOSSY: frays anti-aliased edges, can eat legitimately-white parts of a logo, may leave halos.
Only use after flagging the trade-off to the user; prefer a genuinely transparent source.
Requires Pillow.
"""
import sys
from collections import deque

try:
    from PIL import Image
except ImportError:
    print("Pillow not available")
    sys.exit(2)


def main(inp, outp, tol=24):
    im = Image.open(inp).convert("RGBA")
    w, h = im.size
    px = im.load()
    bg = px[0, 0]

    def close(c):
        return all(abs(c[i] - bg[i]) <= tol for i in range(3))

    seen = bytearray(w * h)
    q = deque()
    for (x, y) in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        if close(px[x, y]) and not seen[y * w + x]:
            seen[y * w + x] = 1
            q.append((x, y))

    removed = 0
    while q:
        x, y = q.popleft()
        r, g, b, _ = px[x, y]
        px[x, y] = (r, g, b, 0)
        removed += 1
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx] and close(px[nx, ny]):
                seen[ny * w + nx] = 1
                q.append((nx, ny))

    im.save(outp)
    print(f"wrote {outp} — flood-fill bg removal (tol={tol}, {removed}px cleared). "
          "INSPECT edges; this is lossy.")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("usage: make_transparent.py <in> <out> [tolerance]")
        sys.exit(2)
    t = int(sys.argv[3]) if len(sys.argv) > 3 else 24
    main(sys.argv[1], sys.argv[2], t)
