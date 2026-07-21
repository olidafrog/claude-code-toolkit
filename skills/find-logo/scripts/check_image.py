#!/usr/bin/env python3
"""Raster transparency QA for the find-logo skill.

Usage: python3 check_image.py <file>

Prints a JSON verdict about whether the image has a *genuinely* transparent background.
A white box can carry an alpha channel, so we sample the actual corner/edge pixels rather
than trusting `hasAlpha` alone. Requires Pillow (installed on this machine).

Exit code: 0 = transparent, 1 = not transparent / uncertain, 2 = error.
"""
import sys
import json

try:
    from PIL import Image
except ImportError:
    print(json.dumps({"error": "Pillow not available", "verdict": "error"}))
    sys.exit(2)


def main(path):
    out = {"file": path}
    try:
        im = Image.open(path)
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"file": path, "error": str(e), "verdict": "unreadable"}))
        return 2

    out["format"] = im.format
    out["width"], out["height"] = im.size

    has_alpha = (
        im.mode in ("RGBA", "LA", "PA")
        or (im.mode == "P" and "transparency" in im.info)
    )
    out["has_alpha"] = bool(has_alpha)

    rgba = im.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    # four corners + the midpoint of each edge = 8 border samples
    pts = [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
           (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]
    samples = [px[x, y] for (x, y) in pts]
    alphas = [s[3] for s in samples]
    out["border_alpha_min"] = min(alphas)
    out["border_alpha_max"] = max(alphas)

    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    out["corners_transparent"] = all(c[3] <= 8 for c in corners)

    opaque_border = all(a >= 250 for a in alphas)

    def near(c1, c2, tol=12):
        return all(abs(a - b) <= tol for a, b in zip(c1[:3], c2[:3]))

    uniform = all(near(s, samples[0]) for s in samples)
    out["likely_fake_transparent"] = bool((not has_alpha) or (opaque_border and uniform))

    if out["corners_transparent"] and has_alpha:
        out["verdict"] = "transparent"
    elif opaque_border and uniform:
        r, g, b, _ = samples[0]
        out["background_rgb"] = [r, g, b]
        out["verdict"] = "opaque-background"
    elif not has_alpha:
        out["verdict"] = "no-alpha"
    else:
        out["verdict"] = "uncertain"

    print(json.dumps(out, indent=2))
    return 0 if out["verdict"] == "transparent" else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({"error": "usage: check_image.py <file>"}))
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
