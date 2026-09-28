"""Luminous look test for Maren (base and Deadeye): a bright, eerie otherworld
with bold ink outlines, saturated jewel colors, flat painted shadows, and gold
and aquamarine glows. Reuses the shapes from maren_look_test.py. Writes
art/look-tests/maren_luminous_test.svg (docs/art-style-guide.md)."""
import math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "..", "art", "look-tests")

src = open(os.path.join(HERE, "maren_look_test.py")).read()
src = src.split("# ------------------------------------------------------------------- the sheet")[0]
ns = {}
exec(src, ns)

# A jewel-toned palette in place of the dark one.
ns.update({
    "INK": "#1a1024",
    "CLOAK": "#1f7a68", "CLOAK_DK": "#135247",
    "LEATHER": "#9a6236", "LEATHER_DK": "#6a3f25",
    "TROUSER": "#46355e", "BOOT": "#2b1d33",
    "SKIN": "#e6b48c", "HAIR": "#5a2e22",
    "WOOD": "#a8703c", "BONE": "#f4ead0",
    "RIFT": "#ffd66e",      # rift light: warm gold
    "VIOLET": "#62f2df",    # rift power: aquamarine
    "STRING": "#fff4d6",
})
GOLD, AQUA = ns["RIFT"], ns["VIOLET"]

# Flat painted shadow instead of woodcut hatching.
def flat_shadow(clip_id, x0, x1, y0, y1, **_):
    return (f'<rect clip-path="url(#{clip_id})" x="{x0}" y="{y0}" width="{x1 - x0}" '
            f'height="{y1 - y0}" fill="#20164a" opacity="0.32"/>')
ns["hatch"] = flat_shadow

# Rim light is gold now (the look test's default was bound at import).
def gold_rim(d, color=None, w=2.5):
    return (f'<path d="{d}" fill="none" stroke="{color or GOLD}" stroke-width="{w}" '
            f'stroke-linecap="round" filter="url(#glow)" opacity="0.95"/>')
ns["rim"] = gold_rim


def hexagon(cx, cy, r):
    pts = " ".join(f"{cx + r*math.cos(math.radians(60*i)):.1f},{cy + r*math.sin(math.radians(60*i)):.1f}" for i in range(6))
    return f'<polygon points="{pts}"/>'


def scenery(x, w, top, bottom, seed):
    """Luminous sky, distant ruins, glowing grass and motes, clipped to a panel."""
    rnd = random.Random(seed)
    g = [f'<rect x="{x}" y="{top}" width="{w}" height="{bottom-top}" fill="url(#sky)"/>']
    # distant columns and an arch, low contrast
    for i in range(4):
        cx = x + 30 + i * (w / 4) + rnd.randint(-10, 10)
        h = rnd.randint(170, 260)
        g.append(f'<rect x="{cx}" y="{bottom-150-h}" width="22" height="{h}" fill="#8fd6c6" opacity="0.45"/>'
                 f'<rect x="{cx-6}" y="{bottom-156-h}" width="34" height="10" fill="#8fd6c6" opacity="0.45"/>')
    g.append(f'<path d="M{x+w*0.55},{bottom-150} L{x+w*0.55},{bottom-330} Q{x+w*0.72},{bottom-420} {x+w*0.9},{bottom-330} '
             f'L{x+w*0.9},{bottom-150} L{x+w*0.84},{bottom-150} L{x+w*0.84},{bottom-320} Q{x+w*0.72},{bottom-385} '
             f'{x+w*0.61},{bottom-320} L{x+w*0.61},{bottom-150} Z" fill="#a6e3d3" opacity="0.4"/>')
    # meadow
    g.append(f'<path d="M{x},{bottom-150} C{x+w*0.3},{bottom-175} {x+w*0.7},{bottom-160} {x+w},{bottom-172} '
             f'L{x+w},{bottom} L{x},{bottom} Z" fill="url(#meadow)"/>')
    for _ in range(70):
        gx = x + rnd.uniform(0, w)
        gy = bottom - rnd.uniform(0, 150)
        hgt = rnd.uniform(8, 22)
        lean = rnd.uniform(-5, 5)
        col = rnd.choice(["#8a8a44", "#b9a458", "#fff0b0"])
        g.append(f'<path d="M{gx:.1f},{gy:.1f} q{lean:.1f},{-hgt/2:.1f} {lean*1.6:.1f},{-hgt:.1f}" stroke="{col}" '
                 f'stroke-width="2" fill="none" opacity="0.8"/>')
    for _ in range(28):
        mx = x + rnd.uniform(0, w)
        my = top + rnd.uniform(40, bottom - top - 60)
        r = rnd.uniform(1.5, 3.5)
        col = rnd.choice([GOLD, AQUA, "#ffffff"])
        g.append(f'<circle cx="{mx:.1f}" cy="{my:.1f}" r="{r:.1f}" fill="{col}" filter="url(#bloom)" opacity="0.9"/>')
    return "".join(g)


def sheet():
    W, H = 1400, 900
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Georgia, serif">']
    s.append(
        '<defs>'
        '<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.4" result="b"/>'
        '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
        '<filter id="bloom" x="-200%" y="-200%" width="500%" height="500%"><feGaussianBlur stdDeviation="3" result="b"/>'
        '<feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
        '<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3cf"/>'
        '<stop offset="0.35" stop-color="#bff0e2"/><stop offset="0.7" stop-color="#6cc7b6"/><stop offset="1" stop-color="#2f7f78"/></linearGradient>'
        '<linearGradient id="meadow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c8b56a"/>'
        '<stop offset="1" stop-color="#6f6a38"/></linearGradient>'
        f'<radialGradient id="sun" cx="0.75" cy="0.2" r="0.5"><stop offset="0" stop-color="{GOLD}" stop-opacity="0.55"/>'
        f'<stop offset="1" stop-color="{GOLD}" stop-opacity="0"/></radialGradient>'
        f'<g id="lbase">{ns["maren_base"]("lb")}</g><g id="ldead">{ns["maren_deadeye"]("ld")}</g>'
        '</defs>')
    s.append(f'<rect width="{W}" height="{H}" fill="#1b2433"/>')
    s.append('<text x="40" y="54" fill="#fff3cf" font-size="30">Maren Thistledown: luminous look test</text>')
    s.append('<text x="40" y="84" fill="#a9c9c4" font-size="16">A bright, eerie otherworld: bold ink outlines, saturated jewel colors, '
             'flat painted shadows, gold and aquamarine glows.</text>')

    def panel(x, w, label, sub, ref, seed):
        s.append(f'<clipPath id="clip{x}"><rect x="{x}" y="110" width="{w}" height="760" rx="6"/></clipPath>')
        s.append(f'<g clip-path="url(#clip{x})">{scenery(x, w, 110, 870, seed)}'
                 f'<rect x="{x}" y="110" width="{w}" height="760" fill="url(#sun)"/>'
                 f'<ellipse cx="{x+w/2}" cy="812" rx="150" ry="18" fill="#3a3016" opacity="0.4"/>'
                 f'<use href="#{ref}" transform="translate({x+w/2-189},178) scale(1.26)"/></g>')
        s.append(f'<rect x="{x}" y="110" width="{w}" height="760" rx="6" fill="none" stroke="#3a5566"/>')
        s.append(f'<rect x="{x+12}" y="122" width="{w-24}" height="58" rx="4" fill="#1b2433" opacity="0.72"/>')
        s.append(f'<text x="{x+24}" y="146" fill="#fff3cf" font-size="22">{label}</text>')
        s.append(f'<text x="{x+24}" y="170" fill="#cfe7e2" font-size="14">{sub}</text>')

    panel(40, 400, "Base form", "Same shapes; jewel colors, gold light, flat shadows.", "lbase", 3)
    panel(470, 400, "Deadeye (transformed)", "The rift shows as aquamarine: eye, arrow, runes, sigil.", "ldead", 7)

    x0 = 900
    s.append(f'<rect x="{x0}" y="110" width="460" height="360" rx="6" fill="#141c28" stroke="#3a5566"/>')
    s.append(f'<text x="{x0+20}" y="146" fill="#fff3cf" font-size="22">Palette</text>')
    sw = [("Sky", "#fff3cf"), ("Mist", "#bff0e2"), ("Meadow", "#c8b56a"), ("Deep", "#6f6a38"),
          ("Cloak", "#1f7a68"), ("Leather", "#9a6236"), ("Plum", "#46355e"), ("Skin", "#e6b48c"),
          ("Rift gold", GOLD), ("Aquamarine", AQUA), ("Ink", "#1a1024"), ("Bone", "#f4ead0")]
    for i, (name, col) in enumerate(sw):
        cx = x0 + 24 + (i % 4) * 108
        cy = 170 + (i // 4) * 96
        s.append(f'<rect x="{cx}" y="{cy}" width="92" height="56" rx="4" fill="{col}" stroke="#0b0a0e" stroke-width="1.5"/>'
                 f'<text x="{cx}" y="{cy+74}" fill="#cfe7e2" font-size="13">{name}</text>')

    s.append(f'<rect x="{x0}" y="490" width="460" height="380" rx="6" fill="#141c28" stroke="#3a5566"/>')
    s.append(f'<text x="{x0+20}" y="526" fill="#fff3cf" font-size="22">At arena size</text>')
    s.append(f'<text x="{x0+20}" y="550" fill="#a9c9c4" font-size="14">On a golden meadow: the teal cloak and ink outlines pop.</text>')
    s.append(f'<clipPath id="arena"><rect x="{x0+16}" y="566" width="428" height="260" rx="4"/></clipPath>')
    s.append(f'<g clip-path="url(#arena)"><rect x="{x0+16}" y="566" width="428" height="260" fill="url(#meadow)"/>')
    rnd = random.Random(5)
    for _ in range(60):
        gx = x0 + 16 + rnd.uniform(0, 428); gy = 566 + rnd.uniform(0, 260)
        col = rnd.choice(["#8a8a44", "#b9a458", "#fff0b0"])
        s.append(f'<path d="M{gx:.1f},{gy:.1f} q2,-5 3,-10" stroke="{col}" stroke-width="2" fill="none" opacity="0.7"/>')
    s.append('</g>')
    s.append('<g fill="none" stroke="#fff3cf" stroke-width="1.5" opacity="0.35">')
    for row in range(2):
        for col in range(5):
            cx = x0 + 80 + col * 78
            cy = 620 + row * 90 + (45 if col % 2 else 0)
            s.append(hexagon(cx, cy, 52))
    s.append('</g>')
    s.append(f'<g fill="none" stroke="{GOLD}" stroke-width="2.5" opacity="0.9">{hexagon(x0+158, 665, 52)}{hexagon(x0+314, 665, 52)}</g>')
    s.append(f'<use href="#lbase" transform="translate({x0+128},565) scale(0.2)"/>')
    s.append(f'<use href="#ldead" transform="translate({x0+284},565) scale(0.2)"/>')
    s.append(f'<text x="{x0+20}" y="856" fill="#a9c9c4" font-size="13">About 100 px tall: warm ground, cool units; both forms read.</text>')
    s.append('</svg>')
    return "".join(s)


os.makedirs(OUT_DIR, exist_ok=True)
with open(os.path.join(OUT_DIR, "maren_luminous_test.svg"), "w") as f:
    f.write(sheet())
print("ok")
