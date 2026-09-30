"""The item language's pieces (docs/plans/rebuild-phase5b-art.md, section 5).

Each uploaded icon in art/ui/items/ is its kind's frame (the first three
paths) with a glyph drawn on it (the rest). This writes each glyph alone,
white on transparent, to art/ui/items/glyphs/<name>.svg, so the game can
put any glyph in any kind's frame and tint it (ItemIcon). The uploaded icons
stay the source: run this again when more are added.

It also writes art/ui/items/frames/graft.svg, a rose octagon in the upload's
style (Decision 5), until a graft frame is drawn.

Usage: python3 tools/art/item_glyphs.py
"""
import math, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
ITEMS = os.path.join(HERE, "..", "..", "art", "ui", "items")
GLYPHS = os.path.join(ITEMS, "glyphs")
FRAME_PATHS = 3
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'


def glyph_of(svg):
    paths = re.findall(r"<path[^>]*/>", svg)
    glyph = paths[FRAME_PATHS:]
    # Every color becomes white; the game tints it by the frame's kind.
    return [re.sub(r'"#[0-9a-fA-F]{3,6}"', '"#ffffff"', p) for p in glyph]


def octagon(radius):
    points = []
    for i in range(8):
        angle = math.radians(22.5 + 45 * i)
        points.append(f"{50 + radius * math.cos(angle):.1f} {50 + radius * math.sin(angle):.1f}")
    return "M" + " L".join(points) + " Z"


def graft_frame():
    outer, inner = octagon(46), octagon(36)
    return "\n".join([
        HEAD,
        f'<path d="{outer}" fill="#2e1420" stroke="#1a1024" stroke-width="8" stroke-linejoin="round"/>',
        f'<path d="{outer}" fill="none" stroke="#ff8fa3" stroke-width="4" stroke-linejoin="round"/>',
        f'<path d="{inner}" fill="none" stroke="#e0708a" stroke-width="2" stroke-linejoin="round" opacity="0.8"/>',
        "</svg>", ""])


if __name__ == "__main__":
    os.makedirs(GLYPHS, exist_ok=True)
    for name in sorted(os.listdir(ITEMS)):
        if not name.endswith(".svg"):
            continue
        with open(os.path.join(ITEMS, name)) as f:
            glyph = glyph_of(f.read())
        if not glyph:
            continue
        with open(os.path.join(GLYPHS, name), "w") as f:
            f.write("\n".join([HEAD] + glyph + ["</svg>", ""]))
    with open(os.path.join(ITEMS, "frames", "graft.svg"), "w") as f:
        f.write(graft_frame())
    print("ok")
