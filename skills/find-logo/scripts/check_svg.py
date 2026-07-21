#!/usr/bin/env python3
"""SVG quality QA for the find-logo skill.

Usage: python3 check_svg.py <file.svg>

Checks that an SVG is a real vector (not a base64 <image> in disguise), has a viewBox, and
carries no opaque full-canvas background rect behind the mark. Prints a JSON verdict.
Standard library only.

Exit code: 0 = clean-vector, 1 = otherwise, 2 = error.
"""
import sys
import json
import re
import xml.etree.ElementTree as ET

DRAW = {"path", "circle", "ellipse", "line", "polyline", "polygon", "text"}


def local(tag):
    return tag.split("}")[-1].lower() if isinstance(tag, str) else tag


def num(v):
    if v is None:
        return None
    m = re.match(r"\s*(-?[\d.]+)", v)
    return float(m.group(1)) if m else None


def main(path):
    out = {"file": path}
    try:
        txt = open(path, "rb").read().decode("utf-8", "replace")
    except Exception as e:  # noqa: BLE001
        print(json.dumps({"file": path, "error": str(e), "verdict": "unreadable"}))
        return 2

    if "<svg" not in txt.lower():
        print(json.dumps({"file": path, "is_svg": False, "verdict": "not-svg"}, indent=2))
        return 1
    out["is_svg"] = True

    try:
        root = ET.fromstring(txt)
    except ET.ParseError:
        # regex fallback for messy or fragment markup
        locals_ = [t.split(":")[-1].lower() for t in re.findall(r"<\s*([a-zA-Z:]+)", txt)]
        has_draw = any(t in DRAW for t in locals_)
        has_image = "image" in locals_ or "base64" in txt.lower()
        out.update({
            "parse": "regex-fallback",
            "has_viewbox": "viewbox" in txt.lower(),
            "has_vector_content": has_draw,
            "is_fake_vector": has_image and not has_draw,
            "has_full_canvas_opaque_bg": None,
        })
        out["verdict"] = (
            "fake-vector(raster-inside)" if out["is_fake_vector"]
            else "clean-vector" if has_draw else "empty/uncertain"
        )
        print(json.dumps(out, indent=2))
        return 0 if out["verdict"] == "clean-vector" else 1

    vb = root.get("viewBox")
    out["viewBox"] = vb
    out["has_viewbox"] = vb is not None
    out["width"], out["height"] = root.get("width"), root.get("height")

    vbw = vbh = None
    if vb:
        parts = re.split(r"[ ,]+", vb.strip())
        if len(parts) == 4:
            try:
                _, _, vbw, vbh = map(float, parts)
            except ValueError:
                pass
    elif num(root.get("width")) and num(root.get("height")):
        vbw, vbh = num(root.get("width")), num(root.get("height"))

    # Resolve simple <style> class fills. CorelDRAW / Illustrator exports commonly wrap a logo in a
    # full-canvas `<rect class="fil0"/>` whose fill (often `fill:none`) is defined in a <style> block,
    # not inline — a transparent bounding box that must NOT read as an opaque background.
    css_fill = {}
    for m in re.finditer(r"\.([A-Za-z0-9_\-]+)\s*\{([^}]*)\}", txt):
        fm = re.search(r"fill\s*:\s*([^;]+)", m.group(2), re.I)
        if fm:
            css_fill[m.group(1)] = fm.group(1).strip().lower()

    draw = image = 0
    cover_rect = False

    def walk(el):
        nonlocal draw, image, cover_rect
        t = local(el.tag)
        if t in DRAW:
            draw += 1
        elif t == "image":
            image += 1
        elif t == "rect":
            x, y = num(el.get("x") or "0"), num(el.get("y") or "0")
            rw, rh = num(el.get("width")), num(el.get("height"))
            fill = (el.get("fill") or "").strip().lower()
            style = (el.get("style") or "").lower()
            if not fill and "fill:" not in style:  # fall back to a class-based fill from <style>
                for c in (el.get("class") or "").split():
                    if c in css_fill:
                        fill = css_fill[c]
                        break
            fo, op = el.get("fill-opacity"), el.get("opacity")
            transparent = (
                fill in ("none", "transparent")
                or "fill:none" in style
                or (fo is not None and num(fo) == 0)
                or (op is not None and num(op) == 0)
            )
            covers = (
                vbw and vbh and rw and rh and x is not None and y is not None
                and x <= 1 and y <= 1 and rw >= vbw * 0.98 and rh >= vbh * 0.98
            )
            if (el.get("width", "").strip() == "100%" and el.get("height", "").strip() == "100%"):
                covers = True
            if covers and not transparent:
                cover_rect = True
        for c in list(el):
            walk(c)

    walk(root)

    # A `fill` on the <svg> root only sets the inherited default fill for children — it does NOT
    # paint the viewport, so it is not a background. Only a CSS `background` on the root does.
    root_bg = False
    rootstyle = (root.get("style") or "").lower()
    if re.search(r"background(-color)?\s*:\s*(?!transparent|none)[^;]+", rootstyle):
        root_bg = True

    opaque_bg = root_bg or (cover_rect and draw > 0)

    out["draw_elements"] = draw
    out["image_elements"] = image
    out["has_vector_content"] = draw > 0
    out["is_fake_vector"] = image > 0 and draw == 0
    out["covering_opaque_rect"] = cover_rect
    out["has_full_canvas_opaque_bg"] = opaque_bg
    if not out["has_viewbox"]:
        out["warning"] = "no viewBox — may not scale cleanly"

    if out["is_fake_vector"]:
        out["verdict"] = "fake-vector(raster-inside)"
    elif opaque_bg:
        out["verdict"] = "opaque-background"
    elif draw > 0:
        out["verdict"] = "clean-vector"
    else:
        out["verdict"] = "empty/uncertain"

    print(json.dumps(out, indent=2))
    return 0 if out["verdict"] == "clean-vector" else 1


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({"error": "usage: check_svg.py <file.svg>"}))
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
