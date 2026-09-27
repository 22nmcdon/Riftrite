#!/usr/bin/env python3
"""The shared look for the placeholder art scripts (tools/art/): the palette
(docs/archive/ui-asset-design.md, section 3) and SVG drawing helpers.

The item and essence icons that used to live next to these helpers were
removed in the rebuild's gut; the art rehaul (rebuild phase 7) replaces the
rest.
"""
# The palette (docs/archive/ui-asset-design.md, section 3), plus material shades.
INK = "#14101A"
OAK_D, OAK, OAK_L = "#5B3A29", "#8A5A3C", "#B07A52"
BRASS_D, BRASS, BRASS_L = "#8E6A24", "#C9993B", "#E8C877"
STEEL_D, STEEL, STEEL_L = "#5E6670", "#9AA3AD", "#D6DCE1"
BONE_D, BONE, BONE_L = "#A8987A", "#DCCFAF", "#F4ECD8"
PARCH = "#F1E6CC"
EMBER, FLAME_Y = "#E0703A", "#F2C14E"
FROST_D, FROST, FROST_L = "#2F7F95", "#5FB4C9", "#C4ECF4"
MOSS_D, MOSS = "#44683A", "#6E9A5A"
RIFT_D, RIFT, RIFT_L = "#2A1B45", "#7A4FD1", "#B79CF0"
BLOOD = "#B33A3A"
SLATE_D, SLATE, SLATE_L = "#3C3A44", "#6B6875", "#9C99A6"
RUST = "#A0522D"

SW = 3  # outline width on the 64 canvas (about 1.2 px at 26 px)


def path(d: str, fill: str, stroke: bool = True, extra: str = "", sw: float = SW) -> str:
    s = f' stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round" stroke-linecap="round"' if stroke else ""
    return f'<path d="{d}" fill="{fill}"{s}{extra}/>'


def line(d: str, color: str, width: float) -> str:
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="round" stroke-linejoin="round"/>'


def circle(cx: float, cy: float, r: float, fill: str, stroke: bool = True, extra: str = "") -> str:
    s = f' stroke="{INK}" stroke-width="{SW}"' if stroke else ""
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}"{s}{extra}/>'


def rect(x: float, y: float, w: float, h: float, fill: str, rx: float = 0, stroke: bool = True) -> str:
    s = f' stroke="{INK}" stroke-width="{SW}" stroke-linejoin="round"' if stroke else ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}"{s}/>'


def group(body: str, transform: str) -> str:
    return f'<g transform="{transform}">{body}</g>'


def svg(body: str) -> str:
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">'
            + body + "</svg>\n")


def flame(cx: float, cy: float, s: float) -> str:
    """A three-tongued flame (the essence glyph's shape), base at cy."""
    outer = (f"M{cx} {cy - 22 * s} Q{cx + 4 * s} {cy - 12 * s} {cx + 8 * s} {cy - 16 * s} Q{cx + 14 * s} {cy - 6 * s} "
             f"{cx + 10 * s} {cy} Q{cx} {cy + 5 * s} {cx - 10 * s} {cy} Q{cx - 14 * s} {cy - 6 * s} {cx - 8 * s} {cy - 16 * s} "
             f"Q{cx - 4 * s} {cy - 12 * s} {cx} {cy - 22 * s} Z")
    inner = (f"M{cx} {cy - 12 * s} Q{cx + 6 * s} {cy - 5 * s} {cx + 4 * s} {cy - 1 * s} Q{cx} {cy + 2 * s} "
             f"{cx - 4 * s} {cy - 1 * s} Q{cx - 6 * s} {cy - 5 * s} {cx} {cy - 12 * s} Z")
    return path(outer, EMBER) + path(inner, FLAME_Y, stroke=False)
