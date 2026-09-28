"""Silhouette-style look test for Maren (base and Deadeye): black ink figures,
with only rift light, glowing accents, and status colors breaking the black.
Reuses the shapes from maren_look_test.py. Writes
art/look-tests/maren_silhouette_test.svg (docs/art-style-guide.md)."""
import math, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "..", "..", "art", "look-tests")

# Load the look test's figure functions without running its sheet.
src = open(os.path.join(HERE, "maren_look_test.py")).read()
src = src.split("# ------------------------------------------------------------------- the sheet")[0]
src = src.replace('return "".join(out)', "return out")
ns = {}
exec(src, ns)
RIFT, VIOLET = ns["RIFT"], ns["VIOLET"]


def is_accent(part):
    return ("url(#glow)" in part or "sig)" in part or "#e9fffb" in part
            or ns["STRING"] in part)


def split(parts):
    body = [p for p in parts if not is_accent(p)]
    accents = [p for p in parts if is_accent(p)]
    return "".join(body), "".join(accents)


def figure(parts, eye=None):
    body, accents = split(parts)
    extra = ""
    if eye:  # a faint glint so the base form still has a face in the dark
        x, y = eye
        extra = (f'<circle cx="{x}" cy="{y}" r="5" fill="{RIFT}" opacity="0.35" filter="url(#glow)"/>'
                 f'<circle cx="{x}" cy="{y}" r="1.8" fill="#dffcf6"/>')
    # Violet back-rim on the shadow side, so black shapes separate from dark ground.
    return (f'<g filter="url(#ink)">{body}</g>'
            f'<g filter="url(#backrim)" opacity="0.55">{body}</g>'
            f'{accents}{extra}')


def hexagon(cx, cy, r):
    pts = " ".join(f"{cx + r*math.cos(math.radians(60*i)):.1f},{cy + r*math.sin(math.radians(60*i)):.1f}" for i in range(6))
    return f'<polygon points="{pts}"/>'


def sheet():
    W, H = 1400, 900
    base = figure(ns["maren_base"]("sb"), eye=(166, 163))
    dead = figure(ns["maren_deadeye"]("sd"))
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Georgia, serif">']
    s.append(
        '<defs>'
        '<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.4" result="b"/>'
        '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
        # every body color becomes near-black ink, keeping the shape's alpha
        '<filter id="ink" color-interpolation-filters="sRGB"><feColorMatrix type="matrix" values="0 0 0 0 0.02  0 0 0 0 0.02  0 0 0 0 0.035  0 0 0 1 0"/></filter>'
        # a thin violet edge on the left: the shape, shifted, minus the shape
        '<filter id="backrim" color-interpolation-filters="sRGB" x="-10%" y="-10%" width="120%" height="120%">'
        '<feColorMatrix in="SourceAlpha" type="matrix" values="0 0 0 0 0.45  0 0 0 0 0.3  0 0 0 0 0.75  0 0 0 1 0" result="c"/>'
        '<feOffset in="c" dx="-2.5" dy="0" result="o"/>'
        '<feComposite in="o" in2="SourceAlpha" operator="out" result="edge"/>'
        '<feGaussianBlur in="edge" stdDeviation="0.8"/></filter>'
        # the sky behind: lighter than the figures, so black shapes read
        '<radialGradient id="haze" cx="0.62" cy="0.55" r="0.75"><stop offset="0" stop-color="#3b5a5a"/>'
        '<stop offset="0.35" stop-color="#28303f"/><stop offset="0.75" stop-color="#171320"/><stop offset="1" stop-color="#0c0a10"/></radialGradient>'
        '<linearGradient id="ground" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1a1620"/><stop offset="1" stop-color="#0b090e"/></linearGradient>'
        f'<radialGradient id="panelglow" cx="0.55" cy="0.5" r="0.6"><stop offset="0" stop-color="{RIFT}" stop-opacity="0.22"/>'
        f'<stop offset="0.6" stop-color="{VIOLET}" stop-opacity="0.08"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>'
        f'<g id="sbase">{base}</g><g id="sdead">{dead}</g>'
        '<g id="obase">' + "".join(ns["maren_base"]("ob")) + '</g>'
        '<g id="odead">' + "".join(ns["maren_deadeye"]("od")) + '</g>'
        '</defs>')
    s.append(f'<rect width="{W}" height="{H}" fill="#0c0a10"/>')
    s.append('<text x="40" y="54" fill="#e6ddcc" font-size="30">Maren Thistledown: silhouette look test</text>')
    s.append('<text x="40" y="84" fill="#9a90a6" font-size="16">Black ink figures against rift haze. Only rift light, glowing accents, and status colors break the black. '
             'Cheap to make by code or by hand.</text>')

    def panel(x, label, sub, ref):
        s.append(f'<clipPath id="clip{x}"><rect x="{x}" y="110" width="400" height="760" rx="6"/></clipPath>')
        s.append(f'<g clip-path="url(#clip{x})"><rect x="{x}" y="110" width="400" height="760" fill="url(#haze)"/>'
                 f'<rect x="{x}" y="110" width="400" height="760" fill="url(#panelglow)"/>'
                 f'<path d="M{x},812 C{x+120},796 {x+280},800 {x+400},808 L{x+400},870 L{x},870 Z" fill="url(#ground)"/>'
                 f'<use href="#{ref}" transform="translate({x+12},178) scale(1.26)"/></g>')
        s.append(f'<rect x="{x}" y="110" width="400" height="760" rx="6" fill="none" stroke="#2c2634"/>')
        s.append(f'<text x="{x+20}" y="146" fill="#e6ddcc" font-size="22">{label}</text>')
        s.append(f'<text x="{x+20}" y="170" fill="#b8aec4" font-size="14">{sub}</text>')

    panel(40, "Base form", "The same shapes as before, all in ink. A faint eye glint.", "sbase")
    panel(470, "Deadeye (transformed)", "The rift shows more: the eye, the arrow, the runes, the sigil.", "sdead")

    x0 = 900
    s.append(f'<rect x="{x0}" y="110" width="460" height="360" rx="6" fill="#15121a" stroke="#2c2634"/>')
    s.append(f'<text x="{x0+20}" y="146" fill="#e6ddcc" font-size="22">Next to the first look test</text>')
    s.append(f'<text x="{x0+20}" y="170" fill="#9a90a6" font-size="14">Left pair: ink outlines and color. Right pair: silhouettes.</text>')
    s.append(f'<rect x="{x0+232}" y="186" width="212" height="270" rx="4" fill="url(#haze)"/>')
    for i, ref in enumerate(["obase", "odead", "sbase", "sdead"]):
        s.append(f'<use href="#{ref}" transform="translate({x0+14+i*108},196) scale(0.48)"/>')

    s.append(f'<rect x="{x0}" y="490" width="460" height="380" rx="6" fill="#15121a" stroke="#2c2634"/>')
    s.append(f'<text x="{x0+20}" y="526" fill="#e6ddcc" font-size="22">At arena size</text>')
    s.append(f'<text x="{x0+20}" y="550" fill="#9a90a6" font-size="14">The ground must be a mid value here, lighter than the figures.</text>')
    s.append(f'<rect x="{x0+16}" y="566" width="428" height="260" rx="4" fill="#3a3445"/>')
    s.append(f'<rect x="{x0+16}" y="566" width="428" height="260" rx="4" fill="url(#panelglow)"/>')
    s.append('<g fill="none" stroke="#51495e" stroke-width="1.5">')
    for row in range(2):
        for col in range(5):
            cx = x0 + 80 + col * 78
            cy = 620 + row * 90 + (45 if col % 2 else 0)
            s.append(hexagon(cx, cy, 52))
    s.append('</g>')
    s.append(f'<g fill="none" stroke="{RIFT}" stroke-width="2" opacity="0.6">{hexagon(x0+158, 665, 52)}{hexagon(x0+314, 665, 52)}</g>')
    s.append(f'<use href="#sbase" transform="translate({x0+128},565) scale(0.2)"/>')
    s.append(f'<use href="#sdead" transform="translate({x0+284},565) scale(0.2)"/>')
    s.append(f'<text x="{x0+20}" y="856" fill="#9a90a6" font-size="13">About 100 px tall: shapes and glows read cleanly; nothing is lost to small detail.</text>')
    s.append('</svg>')
    return "".join(s)


os.makedirs(OUT_DIR, exist_ok=True)
with open(os.path.join(OUT_DIR, "maren_silhouette_test.svg"), "w") as f:
    f.write(sheet())
print("ok")
