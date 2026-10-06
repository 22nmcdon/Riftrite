"""The luminous hero kit (docs/art-style-guide.md): code-generated placeholder
figures for the heroes in every form (base and each path).

Every figure uses the same canvas: 300 x 520, feet at y = 500, facing right,
centered on x = 150. Writes one SVG per form to art/figures/heroes/ (what
the arena draws; the Godot import scales them to half size) and a lineup
sheet to art/look-tests/hero_lineup.svg.

Usage: python3 tools/art/hero_kit.py
"""
import math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "art", "look-tests")

# ------------------------------------------------------------------ palette
INK = "#1a1024"
GOLD = "#ffd66e"        # rift light
AQUA = "#62f2df"        # rift power
EMBER = "#ff9a3c"
SHADE = "#20164a"       # flat painted shadow, laid over at low opacity

MOSS, MOSS_DK = "#1f7a68", "#135247"
LEATHER, LEATHER_DK = "#9a6236", "#6a3f25"
PLUM, PLUM_DK = "#46355e", "#2e2140"
BOOT = "#2b1d33"
SKIN, SKIN_DK = "#e6b48c", "#c98f6a"
WOOD, BONE = "#a8703c", "#f4ead0"
IRON, IRON_DK = "#8a95a8", "#566075"
WINE, WINE_DK = "#a8323f", "#74222d"
BEARD = "#8a4a2a"
ROBE, ROBE_DK = "#f1e6c8", "#cdb98e"
HAIR_DK, HAIR_RED = "#3a2320", "#8a3a22"


# ------------------------------------------------------------------ helpers
def P(d, fill, sw=3, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{sw}" stroke-linejoin="round" {extra}/>'


def poly(pts, fill, sw=3):
    return P("M" + " L".join(f"{x:.1f},{y:.1f}" for x, y in pts) + " Z", fill, sw)


def limb(a, b, wa, wb, fill, sw=3):
    """A tapered limb from point a (width wa) to point b (width wb), with round ends."""
    (x1, y1), (x2, y2) = a, b
    dx, dy = x2 - x1, y2 - y1
    n = math.hypot(dx, dy) or 1
    px, py = -dy / n, dx / n
    pts = [(x1 + px * wa / 2, y1 + py * wa / 2), (x2 + px * wb / 2, y2 + py * wb / 2),
           (x2 - px * wb / 2, y2 - py * wb / 2), (x1 - px * wa / 2, y1 - py * wa / 2)]
    return (poly(pts, fill, sw) +
            f'<circle cx="{x1}" cy="{y1}" r="{wa/2:.1f}" fill="{fill}" stroke="{INK}" stroke-width="{sw}"/>'
            f'<circle cx="{x2}" cy="{y2}" r="{wb/2:.1f}" fill="{fill}" stroke="{INK}" stroke-width="{sw}"/>'
            + poly(pts, fill, 0))


def circle(cx, cy, r, fill, sw=3, extra=""):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="{INK}" stroke-width="{sw}" {extra}/>'


def rim(d, color=GOLD, w=2.6, op=0.95):
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{w}" stroke-linecap="round" '
            f'filter="url(#glow)" opacity="{op}"/>')


def glow_dot(cx, cy, r, color, strong=False):
    f = "bloom" if strong else "glow"
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{color}" filter="url(#{f})"/>'


def rune(cx, cy, s=6, color=AQUA):
    return f'<path d="M{cx},{cy-s} l{s},{s} l{-s},{s} l{-s},{-s} Z" fill="{color}" filter="url(#glow)"/>'


def shadow(rx=80):
    return f'<ellipse cx="150" cy="500" rx="{rx}" ry="12" fill="#2a2010" opacity="0.35"/>'


def shade(uid, paths, cut=140, top=60, bottom=520):
    """Flat painted shadow over the left side of the given shapes."""
    clip = "".join(f'<path d="{d}"/>' for d in paths)
    return (f'<clipPath id="{uid}"><g>{clip}</g></clipPath>'
            f'<rect clip-path="url(#{uid})" x="0" y="{top}" width="{cut}" height="{bottom-top}" '
            f'fill="{SHADE}" opacity="0.3"/>')


def boot(x_heel, x_toe, y_top=452, y=498, fill=BOOT):
    return P(f"M{x_heel},{y_top} L{x_toe-8},{y_top} L{x_toe},{y} L{x_heel-4},{y} Z", fill)


def bow(x, top, bottom, bulge, wood=WOOD, recurve=False):
    mid = (top + bottom) / 2
    if recurve:
        d = (f"M{x-10},{top} Q{x+6},{top+8} {x+2},{top+30} Q{x+bulge},{mid} {x+2},{bottom-30} "
             f"Q{x+6},{bottom-8} {x-10},{bottom}")
    else:
        d = f"M{x},{top} Q{x+bulge},{mid} {x},{bottom}"
    return (f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="11" stroke-linecap="round"/>'
            f'<path d="{d}" fill="none" stroke="{wood}" stroke-width="6" stroke-linecap="round"/>'
            f'<line x1="{x-10 if recurve else x}" y1="{top}" x2="{x-10 if recurve else x}" y2="{bottom}" '
            f'stroke="#fff4d6" stroke-width="1.5" opacity="0.7"/>')


def arrows(x, y, n, lean=-6, fletch="#6d8f86", glow_i=None):
    out = []
    for i in range(n):
        x1, y1 = x + i * 7, y - i * 2
        x2, y2 = x1 + lean + i * 2, y1 - 44
        out.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{INK}" stroke-width="4"/>'
                   f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{WOOD}" stroke-width="2"/>')
        col = AQUA if i == glow_i else fletch
        g = ' filter="url(#glow)"' if i == glow_i else ""
        out.append(f'<path d="M{x2},{y2} l-6,10 l8,2 Z" fill="{col}" stroke="{INK}" stroke-width="1.5"{g}/>')
    return "".join(out)


# ---------------------------------------------------------------- Maren
HOOD = ("M150,108 C170,108 186,125 188,150 C189,170 182,188 170,198 L132,198 "
        "C120,186 114,168 116,148 C118,128 132,110 150,108 Z")


def maren_hood_head(dy=0):
    t = f'transform="translate(0,{dy})"'
    return (f'<g {t}>' + P("M124,128 C104,140 94,166 98,196 L114,172 C114,156 118,140 124,128 Z", MOSS_DK)
            + P(HOOD, MOSS)
            + P("M160,138 C174,142 180,158 176,176 C170,188 158,192 150,188 C146,172 148,150 160,138 Z", "#141318", 2)
            + P("M162,150 C172,154 175,166 171,178 C166,185 158,186 155,182 C156,170 157,158 162,150 Z", SKIN, 1.5)
            + f'<path d="M163,162 l6,-1" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>'
            + rim("M168,112 C182,122 188,140 188,152") + '</g>')


def maren_base(uid):
    cloak = ("M150,125 C120,130 100,170 95,210 C85,280 78,350 70,425 L85,418 L96,432 L110,420 L124,434 "
             "L138,422 L152,436 L166,422 L180,434 L194,420 L208,430 L222,418 C215,340 205,260 195,205 "
             "C190,165 175,132 150,125 Z")
    o = [shadow(78), P("M92,160 L116,152 L138,280 L114,288 Z", LEATHER_DK), arrows(100, 160, 3, lean=-12),
         P(cloak, MOSS),
         P("M128,330 L150,330 L146,470 L124,470 Z", PLUM), P("M152,330 L176,330 L182,470 L160,470 Z", PLUM),
         boot(122, 150), boot(160, 204),
         P("M128,205 L176,205 L182,335 L122,335 Z", LEATHER), P("M122,316 L182,316 L182,330 L122,330 Z", LEATHER_DK, 2),
         P("M150,140 C128,150 118,190 116,230 C112,300 110,360 104,418 L118,424 L128,300 C130,240 136,190 150,165 Z", MOSS),
         P("M150,140 C172,150 186,190 188,230 C192,300 198,360 206,414 L192,420 L178,300 C174,240 166,190 150,165 Z", MOSS),
         shade(uid, [cloak], cut=140), maren_hood_head(),
         limb((176, 222), (250, 290), 22, 16, MOSS_DK), bow(226, 100, 480, 60), circle(252, 291, 8, SKIN, 2),
         rim("M198,215 C205,260 214,340 220,414"), rim("M240,150 Q262,230 258,290", w=2), rune(122, 214)]
    return "".join(o)


def maren_deadeye(uid):
    mantle = ("M150,128 C122,132 104,166 98,206 C92,240 88,270 84,300 L98,294 L110,306 L124,296 L138,308 "
              "L152,298 L166,308 L180,296 L194,306 L208,296 C204,262 200,232 195,205 C190,165 175,134 150,128 Z")
    o = [f'<ellipse cx="152" cy="500" rx="104" ry="18" fill="{AQUA}" opacity="0.25" filter="url(#glow)"/>',
         f'<ellipse cx="152" cy="500" rx="92" ry="13" fill="none" stroke="{AQUA}" stroke-width="2" '
         f'stroke-dasharray="6 5" filter="url(#glow)"/>', shadow(80),
         P("M88,150 L118,140 L142,286 L112,296 Z", LEATHER_DK), arrows(96, 150, 5, lean=-14, glow_i=2),
         P("M126,318 L150,318 L134,470 L110,470 Z", PLUM), P("M152,318 L178,318 L198,470 L172,470 Z", PLUM),
         boot(106, 136), boot(172, 220),
         P("M126,200 L178,200 L184,326 L120,326 Z", LEATHER), P("M120,306 L184,306 L184,320 L120,320 Z", LEATHER_DK, 2),
         P(mantle, MOSS), shade(uid, [mantle], cut=140),
         P("M168,196 C186,190 202,200 204,218 C194,224 180,224 170,218 Z", LEATHER_DK),
         P("M150,108 C170,106 184,120 184,142 C184,158 176,168 166,172 L140,172 C128,164 124,148 128,132 C132,118 140,110 150,108 Z", HAIR_RED),
         P("M158,126 C172,130 178,144 176,158 L150,162 C146,146 148,134 158,126 Z", SKIN, 1.5),
         P("M130,156 L184,152 L190,182 L128,188 Z", MOSS_DK),
         glow_dot(168, 143, 5, AQUA), '<circle cx="168" cy="143" r="2.2" fill="#effffc"/>',
         limb((178, 214), (258, 290), 22, 16, MOSS_DK), bow(234, 56, 506, 78),
         f'<line x1="196" y1="289" x2="300" y2="289" stroke="{INK}" stroke-width="5"/>'
         f'<line x1="196" y1="289" x2="300" y2="289" stroke="{WOOD}" stroke-width="2.5"/>',
         P("M298,281 L318,289 L298,297 Z", AQUA, 1.5, 'filter="url(#glow)"'), circle(262, 291, 8, SKIN, 2),
         P("M234,56 q-10,-4 -14,6", "none", 5), P("M234,506 q-10,4 -14,-6", "none", 5),
         rim("M170,110 C182,118 186,132 184,146", w=3), rim("M198,212 C202,240 206,268 208,296", w=3),
         rim("M246,120 Q274,210 270,282"), rune(140, 222), rune(126, 246, 5)]
    return "".join(o)


def maren_trapper(uid):
    # crouched: the whole upper body sits 40 lower
    cloak = ("M150,165 C120,170 100,210 95,250 C88,310 84,380 78,440 L92,432 L104,446 L118,434 L132,448 "
             "L146,436 L160,448 L174,436 L188,446 L202,432 L214,440 C210,380 204,300 195,245 "
             "C190,205 175,172 150,165 Z")
    briar = []
    rnd = random.Random(4)
    for bx in (70, 120, 190, 232):
        briar.append(f'<path d="M{bx},500 q-8,-26 6,-44 q14,-16 4,-34" fill="none" stroke="#2c5a2a" stroke-width="4"/>')
        for k in range(4):
            ty = 494 - k * 18
            briar.append(f'<path d="M{bx + rnd.randint(-6, 6)},{ty} l-6,-4 l2,6 Z" fill="#2c5a2a"/>')
    o = [shadow(96), "".join(briar),
         P("M92,200 L116,192 L136,300 L112,308 Z", LEATHER_DK), arrows(100, 200, 2, lean=-12),
         P(cloak, MOSS),
         limb((138, 380), (104, 432), 26, 22, PLUM), limb((104, 432), (80, 490), 22, 18, PLUM),
         limb((162, 380), (196, 430), 26, 22, PLUM), limb((196, 430), (192, 488), 22, 18, PLUM),
         boot(70, 104, 470), boot(180, 222, 470),
         P("M128,245 L176,245 L182,380 L122,380 Z", LEATHER),
         P("M120,362 L184,362 L184,378 L120,378 Z", LEATHER_DK, 2)]
    # snares on the belt, thorn wire at the hip
    for i, sx in enumerate((130, 150, 170)):
        o.append(f'<circle cx="{sx}" cy="388" r="7" fill="none" stroke="{INK}" stroke-width="4"/>'
                 f'<circle cx="{sx}" cy="388" r="7" fill="none" stroke="#c9b27a" stroke-width="2"/>')
    o.append('<path d="M186,366 q14,6 6,16 q-12,8 -2,18 q14,6 4,16" fill="none" stroke="#1a1024" stroke-width="4"/>'
             '<path d="M186,366 q14,6 6,16 q-12,8 -2,18 q14,6 4,16" fill="none" stroke="#7a8f5a" stroke-width="2"/>')
    o += [P("M150,180 C128,190 118,230 116,270 C112,330 110,390 104,440 L118,446 L128,330 C130,280 136,230 150,205 Z", MOSS),
          shade(uid, [cloak], cut=140), maren_hood_head(dy=40),
          # a low hood brim over the eyes
          P("M150,150 C168,150 184,160 190,176 L170,172 C160,166 150,164 140,168 Z", MOSS_DK),
          limb((176, 262), (236, 318), 22, 16, MOSS_DK), bow(220, 210, 430, 44), circle(238, 320, 8, SKIN, 2),
          rim("M196,256 C202,300 208,370 212,432"),
          f'<path d="M142,470 l10,-6 l10,6 l-10,6 Z" fill="{AQUA}" filter="url(#glow)"/>', rune(124, 256, 5)]
    return "".join(o)


def maren_volley(uid):
    scarf = "M140,196 C120,190 96,176 70,184 C84,194 100,196 110,206 C92,210 80,222 66,224 C92,230 120,222 144,212 Z"
    o = [shadow(90),
         # a quiver on the back and one at the hip
         P("M100,168 L124,160 L142,270 L118,278 Z", LEATHER_DK), arrows(108, 168, 4, lean=-16, glow_i=1),
         limb((140, 330), (118, 410), 24, 20, PLUM), limb((118, 410), (92, 486), 20, 16, PLUM),
         limb((160, 330), (192, 408), 24, 20, PLUM), limb((192, 408), (212, 484), 20, 16, PLUM),
         boot(82, 112, 468), boot(202, 240, 466),
         P("M128,205 L176,205 L184,340 L120,340 Z", MOSS),
         P("M120,318 L184,318 L184,334 L120,334 Z", LEATHER_DK, 2),
         P("M176,300 L196,296 L206,360 L186,364 Z", LEATHER_DK), arrows(184, 300, 3, lean=10),
         P(scarf, AQUA, 2.5, 'opacity="0.95"'), shade(uid, ["M128,205 L176,205 L184,340 L120,340 Z"], cut=148),
         '<g transform="translate(0,30)">',
         P("M150,108 C170,106 184,120 184,142 C184,158 176,168 166,172 L140,172 C128,164 124,148 128,132 C132,118 140,110 150,108 Z", HAIR_RED),
         P("M124,122 C110,118 100,126 94,140 C106,136 116,138 126,142 Z", HAIR_RED),
         P("M158,126 C172,130 178,144 176,158 L166,172 L150,170 C146,146 148,134 158,126 Z", SKIN, 1.5),
         f'<path d="M166,142 l6,-1" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>',
         rim("M170,110 C182,118 186,132 184,146"), '</g>',
         limb((124, 214), (104, 288), 20, 16, MOSS_DK), circle(103, 294, 8, SKIN, 2),
         limb((176, 214), (240, 256), 20, 16, MOSS_DK),
         P("M226,244 L242,250 L238,264 L222,258 Z", LEATHER_DK, 2),
         bow(250, 186, 330, 26, recurve=True), circle(248, 258, 7, SKIN, 2),
         rim("M180,214 C184,260 186,300 186,336"),
         rim("M258,200 Q276,258 258,316", w=2)]
    return "".join(o)


# --------------------------------------------------------------- Brannoc
def brannoc_head(helm=IRON, visor=IRON_DK, crest=False, dented=False):
    top = "M118,152 C118,112 182,112 182,152 L182,178 L118,178 Z" if not dented else \
          "M118,152 C118,118 150,108 166,118 L172,126 L182,132 L182,178 L118,178 Z"
    o = []
    if crest:
        o.append(P("M130,118 C140,84 176,78 196,96 C178,96 166,104 160,120 Z", WINE))
    o += [P(top, helm), P("M128,164 L172,164 L170,194 C160,202 140,202 130,194 Z", SKIN, 2),
          P("M126,182 C130,214 170,214 174,182 L176,198 C164,228 136,228 124,198 Z", BEARD),
          P("M120,152 L180,152 L180,162 L120,162 Z", visor, 2),
          f'<path d="M146,174 l6,0 M160,174 l6,0" stroke="{INK}" stroke-width="2.4" stroke-linecap="round"/>',
          rim("M168,118 C178,126 182,138 182,152")]
    return "".join(o)


def brannoc_legs(spread=0, boots=True):
    return (P(f"M{118-spread},340 L148,340 L144,470 L{112-spread},470 Z", IRON_DK)
            + P(f"M152,340 L{182+spread},340 L{188+spread},470 L156,470 Z", IRON_DK)
            + (boot(108 - spread, 150) + boot(156, 204 + spread) if boots else ""))


def round_shield(cx, cy, r, bite=False):
    o = [circle(cx, cy, r, IRON), circle(cx, cy, r - 10, WINE, 2)]
    o.append(P(f"M{cx},{cy-22} C{cx+14},{cy-6} {cx+10},{cy+14} {cx},{cy+20} "
               f"C{cx-10},{cy+14} {cx-14},{cy-6} {cx},{cy-22} Z", EMBER, 2))
    o.append(circle(cx, cy, 7, IRON_DK, 2))
    if bite:
        o.append(P(f"M{cx+r-4},{cy-26} l14,8 l-10,10 l12,10 l-16,4 Z", "#1c2430", 0))
    o.append(rim(f"M{cx+r*0.5},{cy-r*0.86} A{r},{r} 0 0 1 {cx+r*0.5},{cy+r*0.86}"))
    return "".join(o)


def brannoc_base(uid):
    torso = "M100,200 L200,200 L206,350 L94,350 Z"
    o = [shadow(92), brannoc_legs(),
         limb((104, 214), (96, 318), 26, 20, IRON),
         f'<line x1="96" y1="318" x2="96" y2="400" stroke="{INK}" stroke-width="9"/>'
         f'<line x1="96" y1="318" x2="96" y2="400" stroke="#c9ced8" stroke-width="5"/>', circle(96, 318, 11, SKIN, 2),
         P(torso, IRON), P("M122,215 L178,215 L186,420 L150,436 L114,420 Z", WINE),
         P("M98,330 L204,330 L204,346 L98,346 Z", LEATHER_DK, 2),
         f'<ellipse cx="100" cy="212" rx="28" ry="20" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         f'<ellipse cx="200" cy="212" rx="28" ry="20" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         shade(uid, [torso, "M122,215 L178,215 L186,420 L150,436 L114,420 Z"], cut=146),
         brannoc_head(), limb((200, 218), (226, 290), 26, 20, IRON), round_shield(226, 300, 60),
         rim("M206,236 L208,300", w=2)]
    return "".join(o)


def brannoc_hearthwall(uid):
    torso = "M96,196 L204,196 L210,352 L90,352 Z"
    plates = "".join(P(f"M{x},{y} L{x+30},{y-6} L{x+34},{y+120} L{x+4},{y+126} Z", IRON_DK)
                     for x, y in ((84, 110), (110, 92), (136, 100)))
    tower = "M188,130 C188,112 262,112 262,130 L262,462 L225,486 L188,462 Z"
    o = [shadow(110), plates, brannoc_legs(spread=14),
         limb((100, 210), (90, 320), 28, 22, IRON), circle(90, 322, 12, SKIN, 2),
         P(torso, IRON), P("M120,212 L180,212 L188,410 L150,428 L112,410 Z", WINE),
         P("M92,332 L208,332 L208,350 L92,350 Z", LEATHER_DK, 2),
         f'<ellipse cx="98" cy="208" rx="32" ry="24" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         shade(uid, [torso], cut=146), brannoc_head(crest=True),
         P(tower, IRON), P("M212,140 L238,140 L238,452 L225,462 L212,452 Z", WINE, 2),
         P("M225,250 C240,268 236,292 225,302 C214,292 210,268 225,250 Z", EMBER, 2),
         rune(225, 200, 8), rune(225, 360, 6),
         rim("M262,132 L262,460", w=3), rim("M170,120 C180,128 184,140 184,152"),
         f'<ellipse cx="150" cy="500" rx="118" ry="10" fill="none" stroke="{GOLD}" stroke-width="1.5" '
         f'opacity="0.6" filter="url(#glow)"/>']
    return "".join(o)


def brannoc_ironbrand(uid):
    torso = "M104,202 L198,202 L204,346 L98,346 Z"
    upper = [round_shield(104, 250, 48),  # strapped on his back
             P(torso, IRON), P("M124,216 L180,216 L184,370 L120,370 Z", WINE),
             P("M98,326 L206,326 L206,342 L98,342 Z", LEATHER_DK, 2),
             f'<ellipse cx="104" cy="212" rx="26" ry="18" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
             shade(uid, [torso], cut=146), brannoc_head(),
             # bare, scarred arm raising the branding mace
             limb((196, 214), (228, 264), 26, 22, LEATHER_DK),
             P("M212,236 L234,250 L226,266 L204,252 Z", IRON, 2),
             f'<ellipse cx="198" cy="214" rx="24" ry="17" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
             f'<line x1="232" y1="276" x2="258" y2="96" stroke="{INK}" stroke-width="12"/>'
             f'<line x1="232" y1="276" x2="258" y2="96" stroke="{WOOD}" stroke-width="7"/>',
             circle(232, 266, 11, SKIN, 2),
             P("M238,70 L282,80 L278,124 L234,114 Z", IRON_DK),
             P("M244,82 L276,88 L273,116 L241,110 Z", EMBER, 2, 'filter="url(#glow)"'),
             glow_dot(259, 99, 10, GOLD, strong=True),
             rim("M204,206 L208,300", w=2.5), rim("M282,80 L278,124", color=EMBER, w=3)]
    o = [shadow(96), brannoc_legs(spread=8),
         f'<g transform="rotate(7 150 350)">{"".join(upper)}</g>']
    return "".join(o)


def brannoc_last_watch(uid):
    torso = "M100,204 L200,204 L206,350 L94,350 Z"
    banner = "M94,72 L38,84 L42,212 L56,196 L64,222 L76,200 L94,214 Z"
    cracks = "".join(rim(d, color=EMBER, w=2.4) for d in
                     ("M120,230 l10,14 l-6,12 l12,16", "M170,250 l-8,16 l10,10 l-6,18", "M136,300 l12,8 l4,16",
                      "M180,440 l-6,14 l8,12"))
    o = [shadow(90),
         f'<line x1="100" y1="480" x2="92" y2="60" stroke="{INK}" stroke-width="9"/>'
         f'<line x1="100" y1="480" x2="92" y2="60" stroke="{WOOD}" stroke-width="5"/>',
         P(banner, WINE_DK), f'<path d="M60,120 l12,-6 l10,10" stroke="{GOLD}" stroke-width="2" fill="none" opacity="0.7"/>',
         brannoc_legs(spread=4),
         limb((104, 216), (100, 320), 26, 20, IRON_DK), circle(100, 322, 11, SKIN, 2),
         P(torso, IRON_DK), P("M122,218 L178,218 L182,380 L162,366 L150,392 L136,370 L118,384 Z", WINE_DK),
         P("M96,330 L204,330 L204,346 L96,346 Z", LEATHER_DK, 2),
         f'<ellipse cx="102" cy="214" rx="26" ry="18" fill="{IRON_DK}" stroke="{INK}" stroke-width="3"/>',
         shade(uid, [torso], cut=146), cracks,
         brannoc_head(helm=IRON_DK, dented=True),
         limb((198, 220), (222, 292), 26, 20, IRON_DK), round_shield(224, 300, 56, bite=True),
         glow_dot(150, 470, 3, EMBER), glow_dot(120, 440, 2, EMBER), glow_dot(186, 420, 2.5, EMBER)]
    return "".join(o)


# ------------------------------------------------------------------ Vell
VEIL = ("M150,108 C172,108 186,128 186,154 C186,178 178,196 170,206 L130,206 C122,196 114,178 114,154 "
        "C114,128 128,108 150,108 Z")


def vell_head(veil=ROBE, halo=False, sigil=False, hood=True):
    o = []
    if halo:
        o.append(f'<circle cx="152" cy="150" r="46" fill="none" stroke="{GOLD}" stroke-width="4" filter="url(#bloom)" opacity="0.9"/>')
    if hood:
        o.append(P(VEIL, veil))
        o.append(P("M160,134 C176,140 180,160 176,178 C168,192 156,194 148,190 C144,170 148,146 160,134 Z", "#4a3a44", 2))
    else:
        o.append(P("M150,110 C170,108 184,122 184,144 C184,160 176,170 166,174 L140,174 C128,166 124,150 128,134 C132,120 140,112 150,110 Z", "#d8c6a0"))
    o.append(P("M162,146 C172,150 175,164 171,176 C166,184 158,186 154,182 C155,168 156,156 162,146 Z", SKIN, 1.5))
    o.append(f'<path d="M163,160 l6,-1" stroke="{INK}" stroke-width="2" stroke-linecap="round"/>')
    if sigil:
        o.append(f'<circle cx="160" cy="124" r="7" fill="{GOLD}" stroke="{INK}" stroke-width="1.5" filter="url(#glow)"/>')
        o.append("".join(f'<line x1="{160+10*math.cos(a):.1f}" y1="{124+10*math.sin(a):.1f}" '
                         f'x2="{160+15*math.cos(a):.1f}" y2="{124+15*math.sin(a):.1f}" stroke="{GOLD}" stroke-width="2"/>'
                         for a in [i * math.pi / 4 for i in range(8)]))
    o.append(rim("M170,112 C182,122 186,138 186,152"))
    return "".join(o)


def lantern(cx, cy, s=1.0, bright=False):
    w, h = 26 * s, 38 * s
    o = [f'<line x1="{cx}" y1="{cy-h/2-10*s}" x2="{cx}" y2="{cy-h/2}" stroke="{INK}" stroke-width="3"/>',
         glow_dot(cx, cy, 22 * s if bright else 14 * s, GOLD, strong=True),
         P(f"M{cx-w/2},{cy-h/2} L{cx+w/2},{cy-h/2} L{cx+w/2-3*s},{cy+h/2} L{cx-w/2+3*s},{cy+h/2} Z", "none", 3),
         f'<rect x="{cx-w/2+5*s}" y="{cy-h/2+5*s}" width="{w-10*s}" height="{h-10*s}" fill="#fff3c0"/>',
         P(f"M{cx-w/2-4*s},{cy-h/2} L{cx+w/2+4*s},{cy-h/2} L{cx},{cy-h/2-9*s} Z", IRON_DK, 2)]
    return "".join(o)


def vell_robe(uid, color=ROBE, trim=PLUM, hem=494):
    robe = (f"M150,140 C128,145 112,190 108,240 C100,320 92,400 86,{hem} L214,{hem} C208,400 200,320 192,240 "
            f"C188,190 172,145 150,140 Z")
    return (P(robe, color) + P(f"M144,210 L156,210 L162,{hem} L138,{hem} Z", trim, 2)
            + P(f"M88,{hem-16} L212,{hem-16} L214,{hem} L86,{hem} Z", trim, 2)
            + shade(uid, [robe], cut=140) + rim(f"M196,240 C202,320 208,400 212,{hem-6}"))


def vell_base(uid):
    o = [shadow(76), vell_robe(uid), limb((128, 222), (132, 300), 22, 18, ROBE_DK), circle(136, 304, 8, SKIN, 2),
         vell_head(), limb((176, 218), (222, 282), 22, 18, ROBE_DK), circle(224, 286, 8, SKIN, 2),
         lantern(230, 318)]
    return "".join(o)


def vell_lanternbearer(uid):
    o = [shadow(84), f'<circle cx="150" cy="300" r="170" fill="{GOLD}" opacity="0.10" filter="url(#bloom)"/>',
         vell_robe(uid, color="#fbf3dc", trim="#d9a441"),
         limb((126, 222), (128, 300), 24, 20, "#f4e9cf"), circle(132, 304, 8, SKIN, 2),
         vell_head(veil="#fbf3dc", halo=True),
         f'<path d="M226,500 L226,96 C226,70 262,66 266,92" fill="none" stroke="{INK}" stroke-width="10" stroke-linecap="round"/>'
         f'<path d="M226,500 L226,96 C226,70 262,66 266,92" fill="none" stroke="{WOOD}" stroke-width="5" stroke-linecap="round"/>',
         limb((176, 218), (222, 272), 24, 18, "#f4e9cf"), circle(226, 274, 9, SKIN, 2),
         lantern(266, 128, s=1.4, bright=True)]
    return "".join(o)


def vell_wardweaver(uid):
    threads = "".join(rim(d, color=AQUA, w=2.2) for d in
                      ("M188,226 C220,236 214,262 196,266 C176,270 186,296 214,294",
                       "M110,250 C80,262 90,300 120,304",
                       "M100,380 C140,400 170,392 204,370"))
    o = [shadow(86),
         limb((138, 400), (128, 470), 24, 20, PLUM), limb((162, 400), (174, 470), 24, 20, PLUM),
         boot(118, 150, 460), boot(164, 204, 460),
         vell_robe(uid, color=ROBE, trim=AQUA, hem=420),
         P("M118,200 L182,200 L188,300 L150,318 L112,300 Z", IRON),
         P("M150,206 L150,312", "none", 2),
         limb((124, 220), (108, 292), 22, 18, IRON_DK),
         circle(104, 304, 32, IRON), circle(104, 304, 20, "#6fb8ad", 2), rune(104, 304, 7),
         vell_head(veil=ROBE),
         f'<path d="M160,134 C176,140 180,160 176,178 C168,192 156,194 148,190 C144,170 148,146 160,134 Z" '
         f'fill="none" stroke="{AQUA}" stroke-width="3"/>',
         P("M130,206 L170,206 L166,214 L134,214 Z", AQUA, 2),
         limb((178, 218), (224, 276), 22, 18, IRON_DK), circle(226, 280, 8, SKIN, 2),
         threads, rim("M136,300 A32,32 0 0 0 104,272", w=2)]
    return "".join(o)


def vell_vigil_keeper(uid):
    mantle = ("M150,132 C120,136 100,160 76,176 L96,196 L102,250 L120,238 L150,256 L180,238 L198,250 "
              "L204,196 L224,176 C200,160 180,136 150,132 Z")
    o = [shadow(80), vell_robe(uid, color=PLUM, trim=GOLD),
         P(mantle, PLUM_DK), shade(uid + "m", [mantle], cut=140),
         limb((122, 226), (126, 300), 22, 18, PLUM_DK), circle(130, 304, 8, SKIN, 2),
         vell_head(veil=PLUM_DK, sigil=True),
         limb((178, 222), (228, 262), 22, 18, PLUM_DK), circle(230, 266, 8, SKIN, 2),
         f'<path d="M230,272 C236,300 248,330 252,352" fill="none" stroke="{INK}" stroke-width="4"/>'
         f'<path d="M230,272 C236,300 248,330 252,352" fill="none" stroke="#c9b27a" stroke-width="2" stroke-dasharray="3 2"/>',
         glow_dot(254, 372, 18, GOLD, strong=True), circle(254, 372, 18, "#b88a3a"),
         f'<path d="M242,368 l24,0 M246,378 l16,0" stroke="{GOLD}" stroke-width="3" filter="url(#glow)"/>',
         f'<circle cx="268" cy="338" r="9" fill="{AQUA}" opacity="0.35" filter="url(#bloom)"/>'
         f'<circle cx="280" cy="318" r="6" fill="{AQUA}" opacity="0.3" filter="url(#bloom)"/>',
         rim("M204,196 L224,176", w=3), rim("M198,250 C204,330 208,410 212,488")]
    return "".join(o)



# ------------------------------------------------------------------ Garrow (8d-1)
RUST, RUST_DK = "#9a4a2c", "#6a2e1c"
CHAIN = "#b7bcc6"


def chain_links(x0, y0, x1, y1, n, w=12):
    """A run of oval links from (x0, y0) to (x1, y1)."""
    o = []
    for i in range(n):
        t = i / max(n - 1, 1)
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        rx, ry = (w, w * 0.6) if i % 2 == 0 else (w * 0.6, w)
        o.append(f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="none" stroke="{INK}" stroke-width="7"/>'
                 f'<ellipse cx="{x:.1f}" cy="{y:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="none" stroke="{CHAIN}" stroke-width="4"/>')
    return "".join(o)


def garrow_head():
    return "".join([P("M122,150 C120,112 180,112 178,150 L178,186 C168,204 132,204 122,186 Z", SKIN),
                    P("M124,172 C134,196 166,196 176,172 L178,190 C166,214 134,214 122,190 Z", HAIR_DK),
                    f'<path d="M140,160 l8,0 M156,160 l8,0" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>',
                    f'<path d="M160,128 l8,22" stroke="{WINE_DK}" stroke-width="3" stroke-linecap="round"/>',
                    rim("M168,120 C176,130 178,140 178,150")])


def garrow_base(uid):
    torso = "M92,198 L208,198 L214,352 L86,352 Z"
    o = [shadow(104),
         P("M112,340 L148,340 L142,470 L104,470 Z", RUST_DK), P("M152,340 L190,340 L196,470 L158,470 Z", RUST_DK),
         boot(98, 146) + boot(156, 208),
         limb((100, 212), (84, 318), 30, 26, RUST), circle(84, 322, 15, SKIN, 2),
         P(torso, IRON_DK), P("M116,212 L184,212 L190,346 L110,346 Z", RUST),
         P("M88,332 L212,332 L212,352 L88,352 Z", LEATHER_DK, 2),
         chain_links(98, 214, 196, 330, 9),
         f'<ellipse cx="98" cy="210" rx="32" ry="22" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         f'<ellipse cx="202" cy="210" rx="32" ry="22" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         shade(uid, [torso], cut=150), garrow_head(),
         limb((202, 216), (226, 300), 30, 26, RUST), circle(228, 306, 17, IRON, 2),
         chain_links(228, 320, 250, 460, 8, w=11),
         rim("M208,230 L212,300", w=2)]
    return "".join(o)


def garrow_legs():
    return "".join([P("M112,340 L148,340 L142,470 L104,470 Z", RUST_DK), P("M152,340 L190,340 L196,470 L158,470 Z", RUST_DK),
                    boot(98, 146) + boot(156, 208)])


def garrow_aegisfang(uid):
    """Plates over plates, the armour glowing where it thickens: the Shield is the weapon."""
    torso = "M86,194 L214,194 L220,356 L80,356 Z"
    plates = "".join(P(f"M{x},{y} L{x+44},{y-4} L{x+46},{y+30} L{x+2},{y+34} Z", IRON) for x, y in
                     ((92, 214), (152, 210), (96, 256), (150, 252), (100, 298), (148, 294)))
    o = [shadow(112), garrow_legs(),
         limb((98, 212), (80, 318), 32, 28, IRON_DK), circle(80, 324, 17, IRON, 2),
         P(torso, IRON_DK), plates,
         P("M84,334 L216,334 L216,356 L84,356 Z", LEATHER_DK, 2),
         f'<ellipse cx="96" cy="206" rx="38" ry="26" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         f'<ellipse cx="204" cy="206" rx="38" ry="26" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         shade(uid, [torso], cut=150), garrow_head(),
         limb((204, 214), (230, 294), 32, 28, IRON_DK),
         P("M214,286 L252,280 L258,322 L220,330 Z", IRON, 2),
         "".join(f'<path d="M{x},{y} l14,-10 l-2,16 Z" fill="{BONE}" stroke="{INK}" stroke-width="2"/>' for x, y in ((250, 288), (254, 304), (256, 318))),
         rim("M96,214 L214,208", color=AQUA, w=2.4), rim("M100,256 L196,250", color=AQUA, w=2),
         f'<ellipse cx="150" cy="270" rx="96" ry="110" fill="none" stroke="{AQUA}" stroke-width="2" opacity="0.5" filter="url(#glow)"/>']
    return "".join(o)


def garrow_chainwarden(uid):
    """Chains in both fists and coiled round him, hooks at their ends: they come to him."""
    torso = "M92,198 L208,198 L214,352 L86,352 Z"
    o = [shadow(118),
         chain_links(30, 470, 96, 330, 9, w=10), chain_links(270, 470, 214, 330, 9, w=10),
         garrow_legs(),
         limb((100, 212), (70, 300), 30, 26, RUST), circle(66, 304, 16, SKIN, 2),
         P(torso, IRON_DK), P("M116,212 L184,212 L190,346 L110,346 Z", RUST),
         P("M88,332 L212,332 L212,352 L88,352 Z", LEATHER_DK, 2),
         chain_links(96, 214, 204, 332, 11), chain_links(204, 214, 96, 332, 11),
         f'<ellipse cx="98" cy="210" rx="32" ry="22" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         f'<ellipse cx="202" cy="210" rx="32" ry="22" fill="{IRON}" stroke="{INK}" stroke-width="3"/>',
         shade(uid, [torso], cut=150), garrow_head(),
         limb((202, 216), (236, 290), 30, 26, RUST), circle(240, 296, 17, SKIN, 2),
         chain_links(66, 304, 28, 150, 8, w=10), chain_links(240, 296, 278, 140, 8, w=10),
         f'<path d="M22,150 C6,130 14,104 34,108" fill="none" stroke="{INK}" stroke-width="9"/>'
         f'<path d="M22,150 C6,130 14,104 34,108" fill="none" stroke="{CHAIN}" stroke-width="5"/>',
         f'<path d="M282,140 C298,120 290,94 270,98" fill="none" stroke="{INK}" stroke-width="9"/>'
         f'<path d="M282,140 C298,120 290,94 270,98" fill="none" stroke="{CHAIN}" stroke-width="5"/>',
         glow_dot(34, 108, 4, WINE), glow_dot(270, 98, 4, WINE)]
    return "".join(o)


def garrow_spitemail(uid):
    """Every plate grown spikes, wet with what they gave back."""
    torso = "M92,198 L208,198 L214,352 L86,352 Z"
    spikes = "".join(f'<path d="M{x},{y} l{dx},{dy} l{8 if dx < 0 else -8},8 Z" fill="{BONE}" stroke="{INK}" stroke-width="2"/>'
                     for x, y, dx, dy in ((96, 236, -36, -8), (94, 270, -38, 0), (92, 304, -36, 8),
                                          (124, 236, -4, -26), (150, 228, 0, -28), (176, 236, 4, -26),
                                          (130, 284, -4, -24), (170, 284, 4, -24),
                                          (80, 196, -10, -20), (98, 186, -2, -24), (202, 186, 2, -24), (220, 196, 10, -20)))
    o = [shadow(104), garrow_legs(),
         limb((100, 212), (84, 318), 30, 26, RUST_DK), circle(84, 322, 15, SKIN, 2),
         P(torso, IRON_DK), P("M116,212 L184,212 L190,346 L110,346 Z", WINE_DK),
         P("M88,332 L212,332 L212,352 L88,352 Z", LEATHER_DK, 2),
         shade(uid, [torso], cut=150), spikes,
         f'<ellipse cx="98" cy="210" rx="32" ry="22" fill="{IRON_DK}" stroke="{INK}" stroke-width="3"/>',
         f'<ellipse cx="202" cy="210" rx="32" ry="22" fill="{IRON_DK}" stroke="{INK}" stroke-width="3"/>',
         garrow_head(),
         limb((202, 216), (226, 300), 30, 26, RUST_DK), circle(228, 306, 17, IRON, 2),
         "".join(f'<path d="M{x},{y} l6,-14 l6,14 Z" fill="{BONE}" stroke="{INK}" stroke-width="2"/>' for x, y in ((220, 296), (230, 292), (240, 298))),
         "".join(glow_dot(x, y, 2.5, WINE) for x, y in ((70, 236), (66, 264), (234, 236), (236, 262), (150, 300))),
         rim("M208,230 L212,300", color=WINE, w=2)]
    return "".join(o)


# ------------------------------------------------------------------ Tamsin (8d-3)
DUSKCLOTH, DUSKCLOTH_DK = "#2f3a4a", "#1f2633"
DUSK = "#5b4a7a"
STEEL = "#d7dde6"


def tamsin_head(hood=DUSKCLOTH_DK):
    return "".join([P("M128,150 C126,118 174,118 172,150 L170,180 C162,196 138,196 130,180 Z", SKIN),
                    P("M114,160 C110,104 190,104 186,160 L178,190 C174,150 126,150 122,190 Z", hood),
                    P("M132,170 L168,170 L164,192 C156,200 144,200 136,192 Z", hood),
                    f'<path d="M140,160 l7,1 M154,161 l7,-1" stroke="{INK}" stroke-width="2.6" stroke-linecap="round"/>',
                    rim("M120,150 C120,126 134,112 150,110", color=AQUA, w=2)])


def tamsin_legs(fill=DUSKCLOTH_DK):
    return "".join([P("M126,330 L148,330 L140,468 L114,468 Z", fill), P("M152,330 L174,330 L190,468 L164,468 Z", fill),
                    boot(108, 150) + boot(162, 204)])


def knife(x, y, angle=-30, length=44):
    return (f'<g transform="translate({x},{y}) rotate({angle})">'
            f'<path d="M0,-4 L{length},0 L0,4 Z" fill="{STEEL}" stroke="{INK}" stroke-width="2"/>'
            f'<rect x="-14" y="-4" width="14" height="8" fill="{LEATHER_DK}" stroke="{INK}" stroke-width="2"/></g>')


def tamsin_base(uid):
    """A slip of a figure in a dusk-grey hood, low and leaning, a knife in each hand."""
    torso = "M118,196 L182,196 L188,338 L112,338 Z"
    o = [shadow(70), tamsin_legs(),
         limb((122, 208), (96, 288), 18, 14, DUSKCLOTH), circle(94, 292, 8, SKIN, 2), knife(94, 292, 150),
         P(torso, DUSKCLOTH), P("M124,206 L176,206 L180,330 L120,330 Z", DUSK),
         P("M112,318 L188,318 L188,338 L112,338 Z", LEATHER_DK, 2),
         P("M118,196 C104,220 100,300 108,360 L120,330 Z", DUSKCLOTH_DK),
         shade(uid, [torso], cut=150), tamsin_head(),
         limb((178, 208), (214, 270), 18, 14, DUSKCLOTH), circle(216, 274, 8, SKIN, 2), knife(216, 274, -40),
         rim("M182,212 L186,300", color=AQUA, w=2)]
    return "".join(o)


HEROES = [
    ("maren", "Maren", [("base", "Base", maren_base), ("deadeye", "Deadeye", maren_deadeye),
                        ("trapper", "Trapper", maren_trapper), ("volley", "Volley", maren_volley)]),
    ("brannoc", "Brannoc", [("base", "Base", brannoc_base), ("hearthwall", "Hearthwall", brannoc_hearthwall),
                            ("ironbrand", "Ironbrand", brannoc_ironbrand), ("last_watch", "Last Watch", brannoc_last_watch)]),
    ("vell", "Vell", [("base", "Base", vell_base), ("lanternbearer", "Lanternbearer", vell_lanternbearer),
                      ("wardweaver", "Wardweaver", vell_wardweaver), ("vigil_keeper", "Vigil Keeper", vell_vigil_keeper)]),
    ("garrow", "Garrow", [("base", "Base", garrow_base), ("aegisfang", "Aegisfang", garrow_aegisfang),
                          ("chainwarden", "Chainwarden", garrow_chainwarden), ("spitemail", "Spitemail", garrow_spitemail)]),
    ("tamsin", "Tamsin", [("base", "Base", tamsin_base)]),
]

FILTERS = ('<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.4" result="b"/>'
           '<feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>'
           '<filter id="bloom" x="-200%" y="-200%" width="500%" height="500%"><feGaussianBlur stdDeviation="4" result="b"/>'
           '<feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>')


def standalone(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="300" height="520" viewBox="0 0 300 520">'
            f'<defs>{FILTERS}</defs>{body}</svg>')


def lineup():
    cw, ch, scale = 300, 360, 0.56
    W, H = 60 + 4 * cw, 130 + len(HEROES) * ch
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Georgia, serif">',
         f'<defs>{FILTERS}'
         '<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3cf"/>'
         '<stop offset="0.45" stop-color="#bff0e2"/><stop offset="1" stop-color="#6cc7b6"/></linearGradient>'
         '<linearGradient id="meadow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c8b56a"/>'
         '<stop offset="1" stop-color="#6f6a38"/></linearGradient></defs>',
         f'<rect width="{W}" height="{H}" fill="#1b2433"/>',
         '<text x="30" y="52" fill="#fff3cf" font-size="30">Riftrite heroes: luminous placeholder kit</text>',
         '<text x="30" y="82" fill="#a9c9c4" font-size="16">Each hero in every form (base and three paths). Code-generated from tools/art/hero_kit.py; '
         'placeholder quality, meant to test shapes, colors, and how each path reads.</text>']
    for r, (hid, hname, forms) in enumerate(HEROES):
        for c, (fid, fname, fn) in enumerate(forms):
            x, y = 30 + c * cw, 110 + r * ch
            s.append(f'<clipPath id="cl{r}{c}"><rect x="{x+6}" y="{y}" width="{cw-12}" height="{ch-14}" rx="6"/></clipPath>')
            s.append(f'<g clip-path="url(#cl{r}{c})"><rect x="{x+6}" y="{y}" width="{cw-12}" height="{ch-14}" fill="url(#sky)"/>'
                     f'<path d="M{x+6},{y+ch-90} C{x+100},{y+ch-104} {x+200},{y+ch-96} {x+cw-6},{y+ch-102} L{x+cw-6},{y+ch} L{x+6},{y+ch} Z" fill="url(#meadow)"/>'
                     f'<g transform="translate({x + cw/2 - 150*scale},{y + 48}) scale({scale})">{fn(f"s{r}{c}")}</g></g>')
            label = hname if fid == "base" else fname
            sub = "base form" if fid == "base" else hname
            s.append(f'<rect x="{x+14}" y="{y+8}" width="{cw-28}" height="34" rx="4" fill="#1b2433" opacity="0.78"/>'
                     f'<text x="{x+26}" y="{y+31}" fill="#fff3cf" font-size="17">{label}</text>'
                     f'<text x="{x+cw-26}" y="{y+31}" fill="#a9c9c4" font-size="13" text-anchor="end">{sub}</text>')
    s.append('</svg>')
    return "".join(s)


if __name__ == "__main__":
    figures = os.path.join(HERE, "..", "..", "art", "figures", "heroes")
    os.makedirs(figures, exist_ok=True)
    for hid, _, forms in HEROES:
        for fid, _, fn in forms:
            with open(os.path.join(figures, f"{hid}_{fid}.svg"), "w") as f:
                f.write(standalone(fn(f"{hid}_{fid}")))
    with open(os.path.join(OUT, "hero_lineup.svg"), "w") as f:
        f.write(lineup())
    print("ok")
