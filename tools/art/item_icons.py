#!/usr/bin/env python3
"""Writes the item icons in art/ui/items/ as SVG (docs/ui-asset-design.md, 8.1).

Each icon is drawn on a 64x64 canvas: a bold silhouette with a dark ink
outline, flat fills with one shade and one highlight, light from the top left,
and no text. They must still read at the item tile's small size (about 26 px),
so details stay few and chunky. Rarity lives on the tile's frame, not here.
Enemy-only items take the rift look (violet-black with glowing cracks).

Also writes the rest of the items and the relic icons (art/ui/relics/),
drawn in item_icons_more.py.

Run from the repo root:  python3 tools/art/item_icons.py
Then `godot --headless --import` so Godot picks up new files, and run this
script once more: it sets each icon's import settings (drawn at 2x, with
mipmaps, so it stays smooth when shown small) and the next import applies them.
tests/ui/test_item_art.gd checks those settings.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "art" / "ui" / "items"

# The palette (docs/ui-asset-design.md, section 3), plus material shades.
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


# --- blades --------------------------------------------------------------------

def knife(blade: str, blade_l: str, handle: str, handle_d: str, long: float = 30, width: float = 9) -> str:
    """A single-edged knife pointing up, centered on x=32, tip at the top."""
    top = 32 - long / 2 - 6
    base = top + long
    b = path(f"M32 {top} C{32 + width * 0.9} {top + long * 0.35} {32 + width * 0.7} {base - 4} {32 + width * 0.55} {base} "
             f"L{32 - width * 0.45} {base} L{32 - width * 0.45} {top + 8} Z", blade)
    shine = line(f"M{32 - width * 0.1} {top + 9} L{32 - width * 0.1} {base - 3}", blade_l, 2)
    guard = rect(32 - width * 0.95, base, width * 1.9, 5, BRASS, 1.5)
    grip = rect(32 - 4.5, base + 5, 9, 16, handle, 2.5)
    band = line(f"M28.5 {base + 13} L35.5 {base + 13}", handle_d, 2)
    return b + shine + guard + grip + band


def rusted_cleaver() -> str:
    blade = (path("M16 14 L46 10 Q50 10 50 14 L50 34 Q50 38 46 38 L22 40 Q16 40 16 34 Z", STEEL)
             + path("M18 16 L46 12.5 L46 18 L18 21 Z", STEEL_L, stroke=False)
             + path("M22 30 Q28 26 30 32 Q27 36 22 34 Z", RUST, stroke=False)
             + path("M38 18 Q43 17 44 21 Q41 24 38 22 Z", RUST, stroke=False)
             + circle(22, 20, 2.5, SLATE_D, stroke=False)
             + line("M18 36 L46 34", STEEL_D, 2))
    handle = (path("M46 22 L58 20 Q61 20 61 23 L61 27 Q61 30 58 30 L46 31 Z", OAK)
              + line("M50 21.5 L50 30", OAK_D, 2) + line("M55 21 L55 29.5", OAK_D, 2))
    return svg(group(blade + handle, "rotate(-28 32 32) translate(-4 6)"))




def twin_daggers() -> str:
    one = knife(STEEL, STEEL_L, BLOOD, "#7A2626", long=30, width=11)
    return svg(group(one, "rotate(-32 32 34) translate(-2 0)") + group(one, "rotate(32 32 34) translate(2 0)"))


# --- ranged --------------------------------------------------------------------





# --- defense -------------------------------------------------------------------



# --- light and fire ------------------------------------------------------------

def flame(cx: float, cy: float, s: float) -> str:
    """A three-tongued flame (the essence glyph's shape), base at cy."""
    outer = (f"M{cx} {cy - 22 * s} Q{cx + 4 * s} {cy - 12 * s} {cx + 8 * s} {cy - 16 * s} Q{cx + 14 * s} {cy - 6 * s} "
             f"{cx + 10 * s} {cy} Q{cx} {cy + 5 * s} {cx - 10 * s} {cy} Q{cx - 14 * s} {cy - 6 * s} {cx - 8 * s} {cy - 16 * s} "
             f"Q{cx - 4 * s} {cy - 12 * s} {cx} {cy - 22 * s} Z")
    inner = (f"M{cx} {cy - 12 * s} Q{cx + 6 * s} {cy - 5 * s} {cx + 4 * s} {cy - 1 * s} Q{cx} {cy + 2 * s} "
             f"{cx - 4 * s} {cy - 1 * s} Q{cx - 6 * s} {cy - 5 * s} {cx} {cy - 12 * s} Z")
    return path(outer, EMBER) + path(inner, FLAME_Y, stroke=False)






# --- food and drink ------------------------------------------------------------

def hearth_stew() -> str:
    steam = "".join(line(d, PARCH, 3) for d in ["M22 18 Q18 13 22 8", "M32 16 Q28 10 32 4", "M42 18 Q38 13 42 8"])
    spoon = path("M44 14 L50 8 Q53 6 54 9 L48 17 Z", OAK, sw=2.5) + line("M46 17 L36 29", OAK, 3)
    stew = path("M9 30 Q32 22 55 30 Q32 38 9 30 Z", "#9A5A2E")
    chunks = (circle(22, 29, 3, "#D98E3A", stroke=False) + circle(33, 27.5, 2.5, MOSS, stroke=False)
              + circle(42, 30, 3, "#C9784A", stroke=False) + circle(28, 31.5, 1.8, BONE_L, stroke=False))
    bowl = path("M7 30 Q32 38 57 30 Q55 50 40 55 L24 55 Q9 50 7 30 Z", OAK)
    bowl_shade = path("M44 33 Q52 42 40 52", "none", stroke=False) + line("M49 35 Q48 46 39 51.5", OAK_D, 2.5)
    bowl_shine = line("M13 36 Q15 43 20 47", OAK_L, 2.5)
    foot = rect(22, 55, 20, 4, OAK_D, 1.5)
    return svg(steam + stew + chunks + spoon + bowl + bowl_shade + bowl_shine + foot)




# --- tools and oddments ----------------------------------------------------------







# --- magic -------------------------------------------------------------------





# --- the rift (enemy-only) ------------------------------------------------------

def rift_claw() -> str:
    palm = path("M14 58 Q10 44 20 36 L44 34 Q54 40 50 58 Z", RIFT_D)
    talons = ""
    for (x0, x1, tip_x, tip_y) in [(19, 27, 12, 6), (28, 36, 30, 3), (37, 45, 50, 7)]:
        talons += path(f"M{x0} 37 Q{(x0 + x1) / 2 - 4} 20 {tip_x} {tip_y} Q{(x0 + x1) / 2 + 6} 20 {x1} 36 Z", "#4A3470")
        talons += line(f"M{(x0 + x1) / 2 - 1} 33 Q{(x0 + x1) / 2 - 2} 22 {(tip_x * 2 + (x0 + x1) / 2) / 3} {(tip_y * 2 + 30) / 3}", RIFT_L, 1.6)
    cracks = line("M22 50 L28 45 L27 40", RIFT_L, 2) + line("M40 54 L36 47 L41 42", RIFT_L, 2)
    glow = f'<path d="M22 50 L28 45 L27 40" fill="none" stroke="{RIFT}" stroke-width="5" opacity="0.5"/>'
    return svg(talons + palm + glow + cracks)


def alphas_bite() -> str:
    """The Hound Alpha's bite: a jaw of rift-glass fangs closing on a mark."""
    jaw = path("M8 30 Q32 6 56 30 Q32 20 8 30 Z", RIFT_D) + path("M8 36 Q32 60 56 36 Q32 46 8 36 Z", RIFT_D)
    fangs = ""
    for x in (16, 26, 38, 48):
        fangs += path(f"M{x - 4} 26 L{x} 36 L{x + 4} 26 Z", "#E8DDF5", sw=1.5)
        fangs += path(f"M{x - 4} 40 L{x} 31 L{x + 4} 40 Z", "#E8DDF5", sw=1.5)
    mark = f'<circle cx="32" cy="33" r="4" fill="{RIFT}" opacity="0.8"/>'
    return svg(jaw + fangs + mark + line("M12 29 Q32 14 52 29", RIFT_L, 1.6))


ICONS = {
    "rusted_cleaver": rusted_cleaver,
    "twin_daggers": twin_daggers,
    "hearth_stew": hearth_stew,
    "rift_claw": rift_claw,
    "alphas_bite": alphas_bite,
}


IMPORT_PARAMS = {"mipmaps/generate": "true", "svg/scale": "2.0"}


def fix_imports(folder: Path = OUT) -> int:
    """Sets IMPORT_PARAMS in every icon's .import file Godot has written."""
    fixed = 0
    for imp in sorted(folder.glob("*.svg.import")):
        lines = imp.read_text(encoding="utf-8").splitlines()
        out = []
        for ln in lines:
            key = ln.split("=", 1)[0]
            out.append(f"{key}={IMPORT_PARAMS[key]}" if key in IMPORT_PARAMS else ln)
        if out != lines:
            imp.write_text("\n".join(out) + "\n", encoding="utf-8")
            fixed += 1
    return fixed


RELIC_OUT = OUT.parent / "relics"


def main() -> None:
    # The rest of the items and the relics live in item_icons_more.py.
    from item_icons_more import MORE_ITEMS, RELICS
    OUT.mkdir(parents=True, exist_ok=True)
    RELIC_OUT.mkdir(parents=True, exist_ok=True)
    drawn = ICONS | MORE_ITEMS
    for item_id, draw in drawn.items():
        (OUT / f"item_{item_id}.svg").write_text(draw(), encoding="utf-8")
    # Items that left the game take their icons with them.
    for old in OUT.glob("item_*.svg"):
        if old.stem.removeprefix("item_") not in drawn:
            old.unlink()
            Path(str(old) + ".import").unlink(missing_ok=True)
    for relic_id, draw in RELICS.items():
        (RELIC_OUT / f"relic_{relic_id}.svg").write_text(draw(), encoding="utf-8")
    print(f"wrote {len(ICONS) + len(MORE_ITEMS)} item icons and {len(RELICS)} relic icons")
    fixed = fix_imports(OUT) + fix_imports(RELIC_OUT)
    if fixed:
        print(f"set import settings on {fixed} icons: run `godot --headless --import` to apply them")


if __name__ == "__main__":
    main()
