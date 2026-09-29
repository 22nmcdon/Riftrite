"""Code-generated look test for Maren (base and Deadeye), dark rift style with
woodcut-style hatching. Writes art/look-tests/maren_look_test.svg (docs/art-style-guide.md)."""
import math, os

INK = "#0b0a0e"
CLOAK = "#3a4636"
CLOAK_DK = "#28311f"
LEATHER = "#5b4532"
LEATHER_DK = "#3a2b20"
TROUSER = "#3b3129"
BOOT = "#1f1813"
SKIN = "#b39880"
HAIR = "#2a2320"
WOOD = "#6b4a2e"
BONE = "#cfc4ae"
RIFT = "#6fe3cc"
VIOLET = "#9b6cff"
STRING = "#d8d0c0"

def shape(d, fill, sw=3, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round" {extra}/>'

def hatch(clip_id, x0, x1, y0, y1, gap=7, angle=60, color=INK, width=1.3, opacity=0.55):
    lines = []
    slope = math.tan(math.radians(angle))
    span = (y1 - y0) / slope
    x = x0 - span
    while x < x1:
        lines.append(f'<line x1="{x:.1f}" y1="{y1}" x2="{x+span:.1f}" y2="{y0}"/>')
        x += gap
    return (f'<g clip-path="url(#{clip_id})" stroke="{color}" stroke-width="{width}" '
            f'opacity="{opacity}">{"".join(lines)}</g>')

def rim(d, color=RIFT, w=2.5):
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" '
            f'stroke-linecap="round" filter="url(#glow)" opacity="0.95"/>')

# ---------------------------------------------------------------- base Maren
def maren_base(pid):
    cloak_back = ("M150,125 C120,130 100,170 95,210 C85,280 78,350 70,425 L85,418 L96,432 "
                  "L110,420 L124,434 L138,422 L152,436 L166,422 L180,434 L194,420 L208,430 "
                  "L222,418 C215,340 205,260 195,205 C190,165 175,132 150,125 Z")
    front_l = ("M150,140 C128,150 118,190 116,230 C112,300 110,360 104,418 L118,424 "
               "L128,300 C130,240 136,190 150,165 Z")
    front_r = ("M150,140 C172,150 186,190 188,230 C192,300 198,360 206,414 L192,420 "
               "L178,300 C174,240 166,190 150,165 Z")
    hood = ("M150,108 C170,108 186,125 188,150 C189,170 182,188 170,198 L132,198 "
            "C120,186 114,168 116,148 C118,128 132,110 150,108 Z")
    hood_tail = "M124,128 C104,140 94,166 98,196 L114,172 C114,156 118,140 124,128 Z"
    out = []
    out.append(f'<defs><clipPath id="{pid}c"><path d="{cloak_back}"/><path d="{hood}"/>'
               f'<path d="{hood_tail}"/></clipPath>'
               f'<clipPath id="{pid}l"><rect x="0" y="0" width="140" height="520"/></clipPath></defs>')
    out.append('<ellipse cx="150" cy="500" rx="78" ry="12" fill="#000" opacity="0.55"/>')
    # quiver behind
    out.append(shape("M92,160 L116,152 L138,280 L114,288 Z", LEATHER_DK))
    for (x1, y1, x2, y2) in [(100, 160, 86, 116), (108, 157, 99, 110), (116, 155, 113, 114)]:
        out.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{INK}" stroke-width="4"/>'
                   f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{WOOD}" stroke-width="2"/>')
        out.append(f'<path d="M{x2},{y2} l-6,10 l8,2 Z" fill="#6d8f86" stroke="{INK}" stroke-width="1.5"/>')
    out.append(shape(cloak_back, CLOAK))
    # legs and boots
    out.append(shape("M128,330 L150,330 L146,470 L124,470 Z", TROUSER))
    out.append(shape("M152,330 L176,330 L182,470 L160,470 Z", TROUSER))
    out.append(shape("M122,440 L148,440 L150,498 L106,498 C106,488 114,484 122,480 Z", BOOT))
    out.append(shape("M158,440 L184,440 L186,480 C196,484 202,490 202,498 L158,498 Z", BOOT))
    # torso
    out.append(shape("M128,205 L176,205 L182,335 L122,335 Z", LEATHER))
    out.append(shape("M122,316 L182,316 L182,330 L122,330 Z", "#2a1f18", 2))
    out.append('<rect x="146" y="318" width="10" height="10" fill="#8a7147" stroke="#0b0a0e" stroke-width="1.5"/>')
    out.append(shape(front_l, CLOAK))
    out.append(shape(front_r, CLOAK))
    # hatching in shadow side
    out.append(f'<g clip-path="url(#{pid}l)">{hatch(pid + "c", 60, 200, 100, 440)}</g>')
    # hood
    out.append(shape(hood_tail, CLOAK_DK))
    out.append(shape(hood, CLOAK))
    out.append(shape("M160,138 C174,142 180,158 176,176 C170,188 158,192 150,188 C146,172 148,150 160,138 Z", "#141318", 2))
    out.append(shape("M162,150 C172,154 175,166 171,178 C166,185 158,186 155,182 C156,170 157,158 162,150 Z", SKIN, 1.5))
    out.append(f'<path d="M163,162 l6,-1" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
    # bow arm, hand, bow
    out.append(shape("M174,210 C200,225 225,258 250,284 L242,298 C218,274 192,252 170,236 Z", CLOAK_DK))
    out.append(f'<path d="M226,100 Q286,290 226,480" fill="none" stroke="{INK}" stroke-width="11" stroke-linecap="round"/>')
    out.append(f'<path d="M226,100 Q286,290 226,480" fill="none" stroke="{WOOD}" stroke-width="6" stroke-linecap="round"/>')
    out.append(f'<line x1="226" y1="100" x2="226" y2="480" stroke="{STRING}" stroke-width="1.5" opacity="0.7"/>')
    out.append('<circle cx="252" cy="291" r="8" fill="#b39880" stroke="#0b0a0e" stroke-width="2"/>')
    out.append(shape("M246,282 L262,282 L262,300 L246,300 Z", "#2a1f18", 2))
    # rift rim light (the rift is to her right)
    out.append(rim("M168,112 C182,122 188,140 188,152"))
    out.append(rim("M198,215 C205,260 214,340 220,414"))
    out.append(rim("M240,150 Q262,230 258,290", w=2))
    out.append(rim("M182,440 L184,470", w=2))
    # violet rune on the quiver strap
    out.append(f'<path d="M122,214 l6,-8 l6,8 l-6,8 Z" fill="{VIOLET}" filter="url(#glow)"/>')
    return "".join(out)

# -------------------------------------------------------------- Deadeye Maren
def maren_deadeye(pid):
    mantle = ("M150,128 C122,132 104,166 98,206 C92,240 88,270 84,300 L98,294 L110,306 "
              "L124,296 L138,308 L152,298 L166,308 L180,296 L194,306 L208,296 C204,262 "
              "200,232 195,205 C190,165 175,134 150,128 Z")
    out = []
    out.append(f'<defs><clipPath id="{pid}c"><path d="{mantle}"/></clipPath>'
               f'<clipPath id="{pid}l"><rect x="0" y="0" width="140" height="520"/></clipPath>'
               f'<radialGradient id="{pid}sig"><stop offset="0" stop-color="{RIFT}" stop-opacity="0.55"/>'
               f'<stop offset="1" stop-color="{RIFT}" stop-opacity="0"/></radialGradient></defs>')
    # planted sigil under her feet
    out.append(f'<ellipse cx="152" cy="500" rx="110" ry="20" fill="url(#{pid}sig)"/>')
    out.append(f'<ellipse cx="152" cy="500" rx="92" ry="14" fill="none" stroke="{RIFT}" '
               f'stroke-width="1.5" stroke-dasharray="6 5" opacity="0.8" filter="url(#glow)"/>')
    out.append('<ellipse cx="152" cy="500" rx="80" ry="11" fill="#000" opacity="0.5"/>')
    # bigger quiver, more arrows
    out.append(shape("M88,150 L118,140 L142,286 L112,296 Z", LEATHER_DK))
    for i, (x1, y1, x2, y2) in enumerate([(96, 150, 80, 100), (103, 147, 91, 96), (110, 145, 103, 94),
                                          (117, 143, 115, 96), (124, 142, 127, 100)]):
        out.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{INK}" stroke-width="4"/>'
                   f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{WOOD}" stroke-width="2"/>')
        col = RIFT if i == 2 else "#6d8f86"
        glow = ' filter="url(#glow)"' if i == 2 else ""
        out.append(f'<path d="M{x2},{y2} l-6,10 l8,2 Z" fill="{col}" stroke="{INK}" stroke-width="1.5"{glow}/>')
    # wide planted legs
    out.append(shape("M126,318 L150,318 L134,470 L110,470 Z", TROUSER))
    out.append(shape("M152,318 L178,318 L198,470 L172,470 Z", TROUSER))
    out.append(shape("M106,440 L134,440 L134,498 L88,498 C88,488 96,484 106,480 Z", BOOT))
    out.append(shape("M170,440 L198,440 L202,480 C212,484 218,490 218,498 L172,498 Z", BOOT))
    # torso with a leather jerkin
    out.append(shape("M126,200 L178,200 L184,326 L120,326 Z", LEATHER))
    out.append(shape("M120,306 L184,306 L184,320 L120,320 Z", "#2a1f18", 2))
    out.append(f'<path d="M134,210 L170,210 M132,236 L172,236 M130,262 L174,262" stroke="{LEATHER_DK}" stroke-width="3"/>')
    # short mantle instead of the long cloak
    out.append(shape(mantle, CLOAK))
    out.append(f'<g clip-path="url(#{pid}l)">{hatch(pid + "c", 60, 210, 100, 320)}</g>')
    # shoulder guard on the bow side
    out.append(shape("M168,196 C186,190 202,200 204,218 C194,224 180,224 170,218 Z", LEATHER_DK))
    # head: hood down, scarf over the mouth, one rift-lit eye
    out.append(shape("M150,108 C170,106 184,120 184,142 C184,158 176,168 166,172 L140,172 C128,164 124,148 128,132 C132,118 140,110 150,108 Z", HAIR))
    out.append(shape("M158,126 C172,130 178,144 176,158 L150,162 C146,146 148,134 158,126 Z", SKIN, 1.5))
    out.append(shape("M130,156 L184,152 L190,182 L128,188 Z", CLOAK_DK))
    out.append(f'<path d="M150,108 C140,104 128,110 124,122" fill="none" stroke="{INK}" stroke-width="3"/>')
    out.append(f'<circle cx="168" cy="143" r="7" fill="{RIFT}" opacity="0.5" filter="url(#glow)"/>')
    out.append(f'<circle cx="168" cy="143" r="2.6" fill="#e9fffb"/>')
    # longer bow with bone tips, drawn arm
    out.append(shape("M176,206 C202,222 228,256 256,282 L248,298 C222,274 194,252 172,234 Z", CLOAK_DK))
    out.append(f'<path d="M234,56 Q312,290 234,506" fill="none" stroke="{INK}" stroke-width="12" stroke-linecap="round"/>')
    out.append(f'<path d="M234,56 Q312,290 234,506" fill="none" stroke="{WOOD}" stroke-width="7" stroke-linecap="round"/>')
    out.append(f'<path d="M234,56 q-10,-4 -14,6" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
               f'<path d="M234,56 q-10,-4 -14,6" fill="none" stroke="{BONE}" stroke-width="3.5" stroke-linecap="round"/>')
    out.append(f'<path d="M234,506 q-10,4 -14,-6" fill="none" stroke="{INK}" stroke-width="7" stroke-linecap="round"/>'
               f'<path d="M234,506 q-10,4 -14,-6" fill="none" stroke="{BONE}" stroke-width="3.5" stroke-linecap="round"/>')
    out.append(f'<line x1="234" y1="56" x2="234" y2="506" stroke="{STRING}" stroke-width="1.5" opacity="0.7"/>')
    # a heavy rift-tipped arrow along the grip
    out.append(f'<line x1="196" y1="289" x2="300" y2="289" stroke="{INK}" stroke-width="5"/>')
    out.append(f'<line x1="196" y1="289" x2="300" y2="289" stroke="{WOOD}" stroke-width="2.5"/>')
    out.append(f'<path d="M298,281 L318,289 L298,297 Z" fill="{RIFT}" stroke="{INK}" stroke-width="1.5" filter="url(#glow)"/>')
    out.append('<circle cx="262" cy="291" r="8" fill="#b39880" stroke="#0b0a0e" stroke-width="2"/>')
    out.append(shape("M255,281 L271,281 L271,301 L255,301 Z", "#2a1f18", 2))
    # stronger rift light: transformation brings more of the rift into her
    out.append(rim("M170,110 C182,118 186,132 184,146", w=3))
    out.append(rim("M198,212 C202,240 206,268 208,296", w=3))
    out.append(rim("M246,120 Q274,210 270,282", w=2.5))
    out.append(rim("M198,446 L202,478", w=2))
    out.append(f'<path d="M140,222 l6,-8 l6,8 l-6,8 Z" fill="{VIOLET}" filter="url(#glow)"/>')
    out.append(f'<path d="M126,246 l5,-6 l5,6 l-5,6 Z" fill="{VIOLET}" filter="url(#glow)" opacity="0.8"/>')
    return "".join(out)

# ------------------------------------------------------------------- the sheet
def hexagon(cx, cy, r):
    pts = " ".join(f"{cx + r*math.cos(math.radians(60*i)):.1f},{cy + r*math.sin(math.radians(60*i)):.1f}" for i in range(6))
    return f'<polygon points="{pts}"/>'

def sheet():
    W, H = 1400, 900
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Georgia, serif">']
    s.append('<defs>'
             '<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.2" result="b"/>'
             '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
             '<filter id="sil"><feColorMatrix type="matrix" values="0 0 0 0 0.78  0 0 0 0 0.76  0 0 0 0 0.72  0 0 0 1 0"/></filter>'
             '<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0e0c13"/>'
             '<stop offset="1" stop-color="#1c1722"/></linearGradient>'
             f'<radialGradient id="riftglow" cx="0.85" cy="0.35" r="0.6"><stop offset="0" stop-color="{RIFT}" stop-opacity="0.16"/>'
             f'<stop offset="0.5" stop-color="{VIOLET}" stop-opacity="0.07"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>'
             f'<g id="mbase">{maren_base("b")}</g><g id="mdead">{maren_deadeye("d")}</g>'
             '</defs>')
    s.append(f'<rect width="{W}" height="{H}" fill="url(#bg)"/><rect width="{W}" height="{H}" fill="url(#riftglow)"/>')
    s.append('<text x="40" y="54" fill="#e6ddcc" font-size="30">Maren Thistledown: code-generated look test</text>')
    s.append('<text x="40" y="84" fill="#9a90a6" font-size="16">Dark world, rift light from the right, ink outlines with woodcut-style hatching. '
             'Placeholder quality, meant to test direction, not final art.</text>')

    def panel(x, label, sub, ref):
        s.append(f'<rect x="{x}" y="110" width="400" height="760" rx="6" fill="#15121a" stroke="#2c2634"/>')
        s.append(f'<text x="{x+20}" y="146" fill="#e6ddcc" font-size="22">{label}</text>')
        s.append(f'<text x="{x+20}" y="170" fill="#9a90a6" font-size="14">{sub}</text>')
        s.append(f'<ellipse cx="{x+200}" cy="820" rx="170" ry="26" fill="#221c29"/>')
        s.append(f'<use href="#{ref}" transform="translate({x+12},178) scale(1.26)"/>')

    panel(40, "Base form", "Hood up, long cloak, plain longbow. Rift light only on her edges.", "mbase")
    panel(470, "Deadeye (transformed)", "New silhouette: hood down, short mantle, huge bone-tipped bow,", "mdead")
    s.append('<text x="490" y="190" fill="#9a90a6" font-size="14">wide planted stance, a rift-lit eye and arrow. More rift in her.</text>')

    # right column: silhouettes and arena scale
    x0 = 900
    s.append(f'<rect x="{x0}" y="110" width="460" height="360" rx="6" fill="#15121a" stroke="#2c2634"/>')
    s.append(f'<text x="{x0+20}" y="146" fill="#e6ddcc" font-size="22">Silhouette test</text>')
    s.append(f'<text x="{x0+20}" y="170" fill="#9a90a6" font-size="14">Filled flat: the two forms must read as different at a glance.</text>')
    s.append(f'<use href="#mbase" filter="url(#sil)" transform="translate({x0+40},192) scale(0.52)"/>')
    s.append(f'<use href="#mdead" filter="url(#sil)" transform="translate({x0+250},192) scale(0.52)"/>')

    s.append(f'<rect x="{x0}" y="490" width="460" height="380" rx="6" fill="#15121a" stroke="#2c2634"/>')
    s.append(f'<text x="{x0+20}" y="526" fill="#e6ddcc" font-size="22">At arena size</text>')
    s.append(f'<text x="{x0+20}" y="550" fill="#9a90a6" font-size="14">On the placement hexes (they fade during the fight).</text>')
    s.append(f'<g fill="#1f1a26" stroke="#3a3346" stroke-width="1.5">')
    for row in range(2):
        for col in range(5):
            cx = x0 + 80 + col * 78
            cy = 620 + row * 90 + (45 if col % 2 else 0)
            s.append(hexagon(cx, cy, 52))
    s.append('</g>')
    s.append(f'<g fill="none" stroke="{RIFT}" stroke-width="2" opacity="0.6">{hexagon(x0+158, 665, 52)}{hexagon(x0+314, 665, 52)}</g>')
    s.append(f'<use href="#mbase" transform="translate({x0+128},565) scale(0.2)"/>')
    s.append(f'<use href="#mdead" transform="translate({x0+284},565) scale(0.2)"/>')
    s.append(f'<text x="{x0+20}" y="856" fill="#9a90a6" font-size="13">About 100 px tall: the bow and the glowing eye still read; the hatching disappears.</text>')
    s.append('</svg>')
    return "".join(s)

out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "look-tests")
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, "maren_look_test.svg"), "w") as f:
    f.write(sheet())
print("ok")
