#!/usr/bin/env python3
"""Writes the item icons in art/ui/items/ as SVG (docs/ui-asset-design.md, 8.1).

Each icon is drawn on a 64x64 canvas: a bold silhouette with a dark ink
outline, flat fills with one shade and one highlight, light from the top left,
and no text. They must still read at the item tile's small size (about 26 px),
so details stay few and chunky. Rarity lives on the tile's frame, not here.
Enemy-only items take the rift look (violet-black with glowing cracks).

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


def hearth_knife() -> str:
    return svg(group(knife(STEEL, STEEL_L, OAK, OAK_D, long=32, width=13), "rotate(35 32 32)"))


def twin_daggers() -> str:
    one = knife(STEEL, STEEL_L, BLOOD, "#7A2626", long=30, width=11)
    return svg(group(one, "rotate(-32 32 34) translate(-2 0)") + group(one, "rotate(32 32 34) translate(2 0)"))


# --- ranged --------------------------------------------------------------------

def blackthorn_bow() -> str:
    limb = "M22 6 Q44 32 22 58"
    bow = (line(limb, INK, 11) + line(limb, "#4A3438", 7) + line("M24 10 Q40 30 36 36", "#6A4B50", 2)
           + line("M22 6 L22 58", PARCH, 2))
    thorns = ""
    for (x, y, dx, dy) in [(30.5, 16, 6, -3), (36, 27, 6, -1), (36, 38, 6, 2), (30.5, 48, 6, 4)]:
        thorns += path(f"M{x - 1.5} {y - 2} L{x + dx} {y + dy} L{x + 1.5} {y + 2} Z", "#6A4B50", sw=2)
    grip = rect(34, 28, 8, 9, OAK_L, 2)
    arrow = (line("M14 32 L54 32", OAK_D, 2.5)
             + path("M54 28 L61 32 L54 36 Z", STEEL) + path("M10 28 L16 32 L10 36 L13 32 Z", BLOOD, sw=2))
    return svg(group(bow + thorns + grip + arrow, "rotate(-40 32 32)"))


def bone_sling() -> str:
    fork = path("M29 60 L29 36 Q29 32 26 29 L16 16 Q14 13 17 12 Q20 11 21 14 L32 28 L43 14 Q44 11 47 12 "
                "Q50 13 48 16 L38 29 Q35 32 35 36 L35 60 Z", BONE)
    knuckles = circle(17.5, 13.5, 4, BONE_L) + circle(46.5, 13.5, 4, BONE_L) + rect(27, 52, 10, 8, BONE_L, 3)
    shade = line("M33 36 L33 54", BONE_D, 2)
    band = line("M18 16 Q32 34 46 16", "#7A4A30", 3)
    pouch = path("M27 26 Q32 33 37 26 Q35 31 32 31 Q29 31 27 26 Z", "#7A4A30", sw=2)
    stone = circle(32, 25, 4.5, SLATE) + circle(30.5, 23.5, 1.5, SLATE_L, stroke=False)
    return svg(fork + shade + knuckles + band + pouch + stone)


# --- defense -------------------------------------------------------------------

def oak_buckler() -> str:
    body = circle(32, 33, 25, OAK)
    planks = (line("M22 10.5 L22 55.5", OAK_D, 2) + line("M42 10.5 L42 55.5", OAK_D, 2)
              + line("M32 8.5 L32 57.5", OAK_D, 1.5))
    shine = path("M14 26 Q18 16 28 12", "none", stroke=False) + line("M13 28 Q17 16 29 11.5", OAK_L, 3)
    rim = f'<circle cx="32" cy="33" r="23" fill="none" stroke="{BRASS}" stroke-width="3.5"/>'
    boss = circle(32, 33, 8, BRASS) + circle(29.5, 30.5, 2.5, BRASS_L, stroke=False)
    rivets = "".join(circle(32 + 23 * c, 33 + 23 * s, 1.8, BRASS_L, stroke=False)
                     for c, s in [(0.707, 0.707), (-0.707, 0.707), (0.707, -0.707), (-0.707, -0.707)])
    return svg(body + planks + shine + rim + f'<circle cx="32" cy="33" r="25" fill="none" stroke="{INK}" stroke-width="{SW}"/>'
               + boss + rivets)


# --- light and fire ------------------------------------------------------------

def flame(cx: float, cy: float, s: float) -> str:
    """A three-tongued flame (the essence glyph's shape), base at cy."""
    outer = (f"M{cx} {cy - 22 * s} Q{cx + 4 * s} {cy - 12 * s} {cx + 8 * s} {cy - 16 * s} Q{cx + 14 * s} {cy - 6 * s} "
             f"{cx + 10 * s} {cy} Q{cx} {cy + 5 * s} {cx - 10 * s} {cy} Q{cx - 14 * s} {cy - 6 * s} {cx - 8 * s} {cy - 16 * s} "
             f"Q{cx - 4 * s} {cy - 12 * s} {cx} {cy - 22 * s} Z")
    inner = (f"M{cx} {cy - 12 * s} Q{cx + 6 * s} {cy - 5 * s} {cx + 4 * s} {cy - 1 * s} Q{cx} {cy + 2 * s} "
             f"{cx - 4 * s} {cy - 1 * s} Q{cx - 6 * s} {cy - 5 * s} {cx} {cy - 12 * s} Z")
    return path(outer, EMBER) + path(inner, FLAME_Y, stroke=False)


def tallow_torch() -> str:
    stick = path("M28 34 L36 34 L34 60 Q32 62 30 60 Z", OAK) + line("M33.5 37 L32.5 57", OAK_D, 2)
    wrap = (rect(24, 26, 16, 10, BONE, 3) + line("M25 30 L39 32", BONE_D, 2) + line("M25 33 L39 34.5", BONE_D, 1.5))
    drip = path("M26 35 Q27 40 28.5 35 Z", BONE_L, sw=2)
    return svg(stick + flame(32, 25, 1.0) + wrap + drip)


def old_lantern() -> str:
    ring = f'<path d="M26 12 Q32 2 38 12" fill="none" stroke="{INK}" stroke-width="7"/>' + line("M26 12 Q32 2 38 12", BRASS, 3)
    cap = path("M20 18 L44 18 L40 11 L24 11 Z", BRASS) + line("M24 14 L40 14", BRASS_L, 1.5)
    glass = rect(20, 18, 24, 28, "#F6C667", 2) + f'<rect x="23" y="21" width="18" height="22" rx="2" fill="{FLAME_Y}" opacity="0.8"/>'
    glow = flame(32, 41, 0.62)
    bars = line("M26 18 L26 46", BRASS_D, 2.5) + line("M38 18 L38 46", BRASS_D, 2.5)
    base = path("M17 46 L47 46 L44 55 L20 55 Z", BRASS) + line("M20 50 L44 50", BRASS_D, 1.5)
    dent = path("M40 51 Q42 49 44 52", "none", stroke=False)
    shine = line("M22.5 22 L22.5 30", "#FFF4D0", 2)
    return svg(ring + glass + glow + bars + cap + base + dent + shine)


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


def bitter_draught() -> str:
    cork = rect(27, 6, 10, 8, OAK_L, 2) + line("M29 10 L35 10", OAK_D, 1.5)
    neck = rect(28, 13, 8, 10, "#A9C4B8", 1)
    flask = circle(32, 40, 18, "#A9C4B8")
    liquid = path("M14.5 40 Q23 36 32 40 Q41 44 49.5 40 Q49 57 32 57.5 Q15 57 14.5 40 Z", "#6B7A2E", stroke=False)
    surface = line("M15 40 Q23 36 32 40 Q41 44 49 40", "#8E9F3E", 2)
    bubbles = circle(26, 48, 2, "#8E9F3E", stroke=False) + circle(37, 51, 1.5, "#8E9F3E", stroke=False)
    outline = f'<circle cx="32" cy="40" r="18" fill="none" stroke="{INK}" stroke-width="{SW}"/>'
    shine = line("M20 32 Q22 27 27 25", "#FFFFFF", 2.5)
    label = path("M22 44 L42 44 L41 51 L23 51 Z", PARCH, sw=2) + line("M26 47.5 L38 47.5", BLOOD, 2)
    return svg(neck + flask + liquid + surface + bubbles + label + outline + shine + cork)


# --- tools and oddments ----------------------------------------------------------

def whetstone() -> str:
    stone = path("M8 38 Q8 30 16 28 L48 22 Q56 21 56 29 L56 33 Q56 40 48 41 L16 46 Q8 47 8 38 Z", SLATE)
    top = path("M10 33 Q12 29 17 28.5 L48 23 Q54 22.5 55 27 Z", SLATE_L, stroke=False)
    grain = line("M16 38 L30 36", SLATE_D, 2) + line("M34 35 L48 33", SLATE_D, 2)
    sparks = (line("M40 14 L43 8", FLAME_Y, 2.5) + line("M47 15 L53 10", FLAME_Y, 2.5)
              + line("M33 15 L32 9", FLAME_Y, 2) + circle(56, 16, 1.6, EMBER, stroke=False))
    blade = path("M14 18 L42 12 L44 17 L16 22 Z", STEEL, sw=2.5)
    return svg(blade + sparks + stone + top + grain)


def soot_bomb() -> str:
    smoke = (circle(46, 16, 6, SLATE_L, stroke=False, extra=' opacity="0.8"')
             + circle(53, 10, 4, SLATE_L, stroke=False, extra=' opacity="0.6"'))
    fuse = line("M37 20 Q40 14 45 13", OAK_L, 3)
    spark = (path("M45 7 L47 11 L51 11 L48 14 L49 18 L45 15.5 L41 18 L42 14 L39 11 L43 11 Z", FLAME_Y, sw=2))
    body = circle(29, 39, 19, "#2B2733")
    cap = rect(31, 18, 9, 7, SLATE, 1.5)
    shine = line("M18 33 Q20 26 27 24", "#6B6875", 3.5) + circle(17, 38, 1.8, "#6B6875", stroke=False)
    band = line("M11 43 Q29 51 47 43", "#4A4553", 2.5)
    return svg(smoke + fuse + body + cap + band + shine + spark)


def trick_coin() -> str:
    edge = circle(33, 34, 22, BRASS_D)
    face = circle(31, 32, 20, BRASS)
    inner = f'<circle cx="31" cy="32" r="15" fill="none" stroke="{BRASS_D}" stroke-width="2"/>'
    # Two faces split down the middle: a smile and a frown (it's a trick).
    split = line("M31 18 L31 46", BRASS_D, 2)
    eyes = circle(24, 28, 2, INK, stroke=False) + line("M36 28 L41 28", INK, 2.5)
    mouths = line("M20 35 Q24 40 28 35", INK, 2.5) + line("M34 38 Q38 33 42 38", INK, 2.5)
    shine = line("M15 26 Q18 17 26 14", BRASS_L, 3)
    sparkle = path("M52 8 L54 13 L59 15 L54 17 L52 22 L50 17 L45 15 L50 13 Z", BRASS_L, sw=2)
    return svg(edge + face + inner + split + eyes + mouths + shine + sparkle)


# --- magic -------------------------------------------------------------------

def rime_charm() -> str:
    cord = line("M16 6 Q32 20 48 6", "#7A4A30", 2.5)
    loop = f'<circle cx="32" cy="16" r="3.5" fill="none" stroke="{INK}" stroke-width="5"/>' + \
        f'<circle cx="32" cy="16" r="3.5" fill="none" stroke="{STEEL_L}" stroke-width="2"/>'
    gem = path("M32 19 L47 29 L47 45 L32 58 L17 45 L17 29 Z", FROST)
    facet = path("M32 19 L47 29 L32 36 L17 29 Z", FROST_L, stroke=False) + path("M32 36 L47 45 L47 29 Z", FROST_D, stroke=False, extra=' opacity="0.45"')
    outline = path("M32 19 L47 29 L47 45 L32 58 L17 45 L17 29 Z", "none")
    flake = "".join(line(d, "#FFFFFF", 2.2) for d in ["M32 33 L32 51", "M24.5 37.5 L39.5 46.5", "M24.5 46.5 L39.5 37.5"])
    return svg(cord + loop + gem + facet + outline + flake)


def dusk_tome() -> str:
    pages = path("M14 14 L50 10 L52 52 L16 56 Z", PARCH)
    cover = path("M10 12 Q10 9 13 9 L46 6 Q49 6 49 9 L50 48 Q50 51 47 51 L14 54 Q11 54 11 51 Z", "#3E3368")
    spine = path("M10 12 Q10 9 13 9 L17 8.7 L18 53.6 L14 54 Q11 54 11 51 Z", "#2A2248", sw=2.5)
    moon = path("M37 20 A10 10 0 1 0 38 40 A8 8 0 1 1 37 20 Z", BRASS_L, sw=2)
    stars = circle(42, 22, 1.6, BRASS_L, stroke=False) + circle(44, 33, 1.2, BRASS_L, stroke=False)
    corners = path("M44 6.2 L49 6 Q49 6 49 11 Z", BRASS, sw=2) + \
        path("M50 45 L50 48 Q50 51 47 51 L45 51.2 Z", BRASS, sw=2)
    ribbon = path("M36 53 L36 61 L39 58.5 L42 61 L42 52.5 Z", BLOOD, sw=2)
    return svg(pages + ribbon + cover + spine + moon + stars + corners)


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


ICONS = {
    "rusted_cleaver": rusted_cleaver,
    "hearth_knife": hearth_knife,
    "twin_daggers": twin_daggers,
    "blackthorn_bow": blackthorn_bow,
    "bone_sling": bone_sling,
    "oak_buckler": oak_buckler,
    "tallow_torch": tallow_torch,
    "old_lantern": old_lantern,
    "hearth_stew": hearth_stew,
    "bitter_draught": bitter_draught,
    "whetstone": whetstone,
    "soot_bomb": soot_bomb,
    "trick_coin": trick_coin,
    "rime_charm": rime_charm,
    "dusk_tome": dusk_tome,
    "rift_claw": rift_claw,
}


IMPORT_PARAMS = {"mipmaps/generate": "true", "svg/scale": "2.0"}


def fix_imports() -> int:
    """Sets IMPORT_PARAMS in every icon's .import file Godot has written."""
    fixed = 0
    for imp in sorted(OUT.glob("*.svg.import")):
        lines = imp.read_text(encoding="utf-8").splitlines()
        out = []
        for ln in lines:
            key = ln.split("=", 1)[0]
            out.append(f"{key}={IMPORT_PARAMS[key]}" if key in IMPORT_PARAMS else ln)
        if out != lines:
            imp.write_text("\n".join(out) + "\n", encoding="utf-8")
            fixed += 1
    return fixed


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for item_id, draw in ICONS.items():
        (OUT / f"item_{item_id}.svg").write_text(draw(), encoding="utf-8")
    print(f"wrote {len(ICONS)} icons to {OUT}")
    fixed = fix_imports()
    if fixed:
        print(f"set import settings on {fixed} icons: run `godot --headless --import` to apply them")


if __name__ == "__main__":
    main()
