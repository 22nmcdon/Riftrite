"""The luminous enemy kit (docs/art-style-guide.md, section 5): code-generated
placeholder figures for the Act 1 enemies, in the hero kit's style and on its
canvas (300 x 520, feet at y = 500, centered on x = 150, facing right).

Enemies wear the palette's darker side (deep plum, ink, dark teal) with more
aquamarine rift glow than heroes, and each archetype has its own shape.
Writes art/figures/enemies/<id>.svg and a lineup sheet to
art/look-tests/enemy_lineup.svg.

Usage: python3 tools/art/enemy_kit.py
"""
import math, os, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hero_kit import (P, poly, limb, circle, rim, glow_dot, rune, shade, bow, FILTERS,  # noqa: E402
                      INK, GOLD, AQUA, EMBER, IRON, IRON_DK, BONE, WOOD)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")

# The enemy side of the palette.
DUSK, DUSK_DK = "#56407e", "#3a2a58"      # deep plum (light enough to read on the meadow)
TIDE, TIDE_DK = "#2a6570", "#1a4650"      # dark teal
STONE, STONE_DK = "#6f7b86", "#46505c"
ASH, ASH_DK = "#4a3f4a", "#2c252e"
BOG, BOG_DK = "#2f4a36", "#1c2e22"


def ground(rx=70):
    return f'<ellipse cx="150" cy="500" rx="{rx}" ry="11" fill="#2a2010" opacity="0.35"/>'


def eyes(points, r=3.2, color=AQUA):
    return "".join(glow_dot(x, y, r, color) + f'<circle cx="{x}" cy="{y}" r="{r*0.45:.1f}" fill="#effffc"/>'
                   for x, y in points)


def rift_pup(uid):
    body = "M96,452 C92,420 120,404 158,406 C190,408 206,424 204,448 C202,468 180,474 150,474 C118,474 100,470 96,452 Z"
    o = [ground(64),
         limb((114, 460), (108, 496), 12, 10, DUSK_DK), limb((136, 466), (136, 498), 12, 10, DUSK_DK),
         limb((170, 466), (174, 498), 12, 10, DUSK_DK), limb((192, 458), (198, 496), 12, 10, DUSK_DK),
         P("M96,440 C80,428 74,410 80,398 C88,414 96,420 104,424 Z", DUSK),
         P(body, DUSK), shade(uid, [body], cut=140, top=400),
         P("M186,420 C188,396 206,382 226,386 C244,390 250,408 244,424 C236,436 214,440 198,436 Z", DUSK),
         P("M200,392 L204,368 L214,388 Z", DUSK_DK), P("M220,388 L232,366 L234,392 Z", DUSK_DK),
         P("M236,418 C246,418 252,424 252,430 C244,432 238,430 234,426 Z", DUSK_DK, 2),
         eyes([(228, 406)]), rim("M160,408 C184,410 200,420 204,440", color=AQUA, w=2.2),
         rune(150, 438, 5)]
    return "".join(o)


def ashling(uid):
    body = ("M150,380 C176,380 194,404 196,436 C198,466 186,494 150,496 C114,494 102,466 104,436 "
            "C106,404 124,380 150,380 Z")
    cracks = "".join(rim(d, color=EMBER, w=2.4) for d in
                     ("M132,410 l10,14 l-6,12 l10,14", "M166,404 l-8,16 l10,10 l-4,16", "M150,462 l6,12 l-4,12"))
    o = [ground(56), glow_dot(150, 440, 30, EMBER, strong=True),
         P(body, ASH), shade(uid, [body], cut=146, top=370), cracks,
         P("M128,386 C126,366 136,350 150,346 C164,350 174,366 172,386 Z", ASH_DK),
         P("M140,352 l-6,-18 l12,10 l4,-16 l6,16 l10,-12 l-4,20 Z", EMBER, 2, 'filter="url(#glow)"'),
         eyes([(142, 372), (160, 372)], r=3, color=EMBER),
         limb((106, 430), (86, 456), 12, 10, ASH_DK), limb((194, 430), (214, 452), 12, 10, ASH_DK)]
    return "".join(o)


def rift_hound(uid):
    body = "M80,420 C80,384 120,366 170,370 C212,374 232,392 230,420 C228,446 200,456 160,456 C112,456 82,450 80,420 Z"
    o = [ground(94),
         limb((98, 440), (80, 474), 16, 12, TIDE_DK), limb((80, 474), (92, 498), 12, 10, TIDE_DK),
         limb((122, 446), (118, 498), 16, 12, TIDE_DK),
         limb((196, 446), (206, 498), 16, 12, TIDE_DK), limb((216, 436), (236, 470), 16, 12, TIDE_DK),
         limb((236, 470), (232, 498), 12, 10, TIDE_DK),
         P("M84,404 C64,392 48,370 44,346 C62,366 76,378 96,386 Z", TIDE),
         P(body, TIDE), shade(uid, [body], cut=150, top=360),
         # a crest of rift light along its back
         P("M100,378 L112,350 L122,374 L136,344 L146,370 L162,340 L170,368 L186,346 L190,374 Z",
           AQUA, 2, 'filter="url(#glow)" opacity="0.9"'),
         P("M214,392 C220,360 246,346 268,354 C286,362 290,382 282,398 C272,412 248,414 228,410 Z", TIDE),
         P("M232,360 L236,332 L250,356 Z", TIDE_DK), P("M252,358 L266,332 L268,362 Z", TIDE_DK),
         P("M276,392 C290,392 296,400 294,408 C284,412 274,408 270,402 Z", TIDE_DK, 2),
         f'<path d="M276,404 l4,8 l4,-7" fill="{BONE}" stroke="{INK}" stroke-width="1.5"/>',
         eyes([(266, 378)], r=3.6), rim("M184,372 C212,378 228,394 230,416", color=AQUA, w=2.4)]
    return "".join(o)


def cinder_moth(uid):
    # drawn high on the canvas: it flies
    wings = ("M150,300 C110,250 60,240 40,270 C30,300 60,330 110,322 C70,340 70,380 100,390 "
             "C126,396 144,360 150,330 C156,360 174,396 200,390 C230,380 230,340 190,322 "
             "C240,330 270,300 260,270 C240,240 190,250 150,300 Z")
    o = [f'<ellipse cx="150" cy="500" rx="46" ry="9" fill="#2a2010" opacity="0.22"/>',
         P(wings, DUSK), shade(uid, [wings], cut=150, top=230),
         "".join(glow_dot(x, y, 7, EMBER) for x, y in ((86, 284), (214, 284), (112, 362), (188, 362))),
         P("M150,270 C162,270 168,296 166,330 C164,364 158,386 150,390 C142,386 136,364 134,330 "
           "C132,296 138,270 150,270 Z", ASH_DK),
         glow_dot(150, 330, 16, EMBER, strong=True),
         f'<path d="M144,272 C136,252 128,244 118,240 M156,272 C164,252 172,244 182,240" fill="none" '
         f'stroke="{INK}" stroke-width="3"/>',
         eyes([(144, 286), (156, 286)], r=2.6, color=EMBER),
         rim("M150,300 C190,250 240,240 260,270", color=GOLD, w=2)]
    return "".join(o)


def hollow_archer(uid):
    cloak = ("M150,150 C122,156 104,196 100,240 C94,310 92,380 88,470 L104,462 L116,476 L130,462 "
             "L144,476 L158,462 L172,476 L186,462 L200,472 C202,380 198,300 194,240 C190,196 176,156 150,150 Z")
    o = [ground(70), P(cloak, DUSK_DK), shade(uid, [cloak], cut=146, top=140),
         P("M150,118 C172,118 188,138 188,166 C188,188 176,204 164,210 L136,210 C124,204 112,188 112,166 "
           "C112,138 128,118 150,118 Z", DUSK),
         P("M156,146 C172,150 178,168 172,188 C164,198 150,198 144,192 C142,174 146,156 156,146 Z", "#0d0a14", 2),
         eyes([(160, 170)], r=3.4),
         limb((180, 226), (246, 266), 16, 12, DUSK), bow(250, 150, 390, 50, wood="#5a4a66"),
         f'<line x1="206" y1="266" x2="296" y2="266" stroke="{INK}" stroke-width="4"/>'
         f'<line x1="206" y1="266" x2="296" y2="266" stroke="{BONE}" stroke-width="2"/>',
         P("M294,259 L312,266 L294,273 Z", AQUA, 1.5, 'filter="url(#glow)"'),
         limb((126, 230), (206, 262), 14, 12, DUSK),
         rim("M190,220 C196,300 200,380 200,466", color=AQUA, w=2)]
    return "".join(o)


def rift_worn_sentinel(uid):
    body = "M86,190 L214,190 L226,420 L74,420 Z"
    o = [ground(100),
         P("M92,420 L138,420 L134,498 L88,498 Z", STONE_DK), P("M162,420 L208,420 L212,498 L166,498 Z", STONE_DK),
         P(body, STONE), shade(uid, [body], cut=150, top=180),
         P("M112,130 C112,96 188,96 188,130 L188,190 L112,190 Z", STONE),
         P("M126,146 L174,146 L174,160 L126,160 Z", "#0d0a14", 2), eyes([(140, 153), (160, 153)], r=2.8),
         P("M70,200 C58,200 52,212 54,226 L60,300 L82,300 L88,212 Z", STONE_DK),
         # a great slab of a shield
         P("M170,210 L262,210 L262,440 L216,476 L170,440 Z", STONE_DK),
         "".join(rim(d, color=AQUA, w=2.4) for d in
                 ("M196,240 l10,20 l-8,16 l12,22", "M236,300 l-10,18 l8,14 l-6,20", "M110,250 l12,16 l-6,18")),
         rune(216, 360, 8), rim("M262,212 L262,438", color=AQUA, w=2.5)]
    return "".join(o)


def cairn_guardian(uid):
    # a wedge of piled stone, head down, braced to charge (right)
    body = "M60,470 L96,300 C120,270 170,260 210,300 L276,420 L270,470 Z"
    stones = "".join(P(d, STONE_DK, 2) for d in
                     ("M106,330 L148,316 L154,350 L112,360 Z", "M160,300 L200,318 L190,348 L156,340 Z",
                      "M92,390 L140,378 L146,418 L96,426 Z", "M152,370 L204,362 L212,404 L160,410 Z",
                      "M214,380 L256,410 L240,440 L210,420 Z"))
    o = [ground(112),
         P("M78,460 L112,460 L110,500 L74,500 Z", STONE_DK), P("M200,460 L240,460 L246,500 L204,500 Z", STONE_DK),
         P(body, STONE), shade(uid, [body], cut=150, top=250), stones,
         P("M240,380 L292,420 L286,462 L236,446 Z", STONE_DK),
         eyes([(268, 424)], r=3.8),
         "".join(rim(d, color=AQUA, w=2.4) for d in ("M126,300 l14,-8 l8,12", "M176,286 l12,10 l12,-4")),
         rim("M210,300 L276,420", color=GOLD, w=2.5)]
    return "".join(o)


def bog_lurker(uid):
    body = "M96,420 C80,340 110,250 160,236 C204,226 226,270 222,330 C218,390 204,430 180,440 L120,440 Z"
    o = [ground(90),
         limb((122, 436), (112, 498), 18, 14, BOG_DK), limb((176, 436), (188, 498), 18, 14, BOG_DK),
         P(body, BOG), shade(uid, [body], cut=146, top=226),
         P("M110,290 C100,270 108,240 128,232 C122,258 124,276 132,290 Z", BOG_DK),
         # long reaching arms, one with a hook
         limb((200, 290), (246, 350), 16, 12, BOG_DK), limb((246, 350), (262, 420), 12, 10, BOG_DK),
         f'<path d="M262,420 C282,432 282,456 266,462 C256,466 248,458 252,450" fill="none" stroke="{INK}" stroke-width="7"/>'
         f'<path d="M262,420 C282,432 282,456 266,462 C256,466 248,458 252,450" fill="none" stroke="{IRON}" stroke-width="3.5"/>',
         limb((112, 300), (82, 370), 16, 12, BOG_DK), limb((82, 370), (70, 440), 12, 10, BOG_DK),
         P("M170,236 C196,226 222,244 226,270 C210,276 190,274 176,264 Z", BOG_DK, 2),
         eyes([(204, 258), (190, 262)], r=3.2),
         "".join(f'<path d="M{x},{y} q-4,14 2,24" fill="none" stroke="#5f8a4a" stroke-width="3" opacity="0.8"/>'
                 for x, y in ((130, 330), (160, 360), (150, 290))),
         rim("M206,248 C220,280 222,330 216,380", color=AQUA, w=2.2)]
    return "".join(o)


def gloam_witch(uid):
    robe = ("M150,150 C126,156 110,196 106,246 C100,320 94,400 86,494 L214,494 C206,400 200,320 194,246 "
            "C190,196 174,156 150,150 Z")
    o = [ground(76),
         f'<line x1="224" y1="496" x2="236" y2="120" stroke="{INK}" stroke-width="9"/>'
         f'<line x1="224" y1="496" x2="236" y2="120" stroke="#4a3a5a" stroke-width="5"/>',
         glow_dot(238, 112, 16, AQUA, strong=True), circle(238, 112, 10, "#c9f7ef", 2),
         P(robe, DUSK), P("M144,230 L156,230 L164,494 L136,494 Z", TIDE, 2),
         shade(uid, [robe], cut=140, top=140),
         P("M150,104 C178,104 192,130 192,160 C192,186 180,204 168,214 L132,214 C120,204 108,186 108,160 "
           "C108,130 122,104 150,104 Z", DUSK_DK),
         P("M112,150 C130,170 170,170 188,150 L188,180 C170,196 130,196 112,180 Z", TIDE_DK, 2),
         eyes([(140, 168), (160, 168)], r=2.8),
         limb((180, 232), (228, 290), 16, 12, DUSK_DK), circle(230, 292, 7, "#b8a6c8", 2),
         limb((122, 236), (112, 310), 16, 12, DUSK_DK),
         rune(150, 262, 6), rune(150, 330, 5),
         rim("M194,246 C200,320 206,400 212,488", color=AQUA, w=2.2)]
    return "".join(o)


ENEMIES = [("rift_pup", "Rift Pup", rift_pup), ("ashling", "Ashling", ashling),
           ("rift_hound", "Rift Hound", rift_hound), ("cinder_moth", "Cinder Moth", cinder_moth),
           ("hollow_archer", "Hollow Archer", hollow_archer), ("rift_worn_sentinel", "Rift-Worn Sentinel", rift_worn_sentinel),
           ("cairn_guardian", "Cairn Guardian", cairn_guardian), ("bog_lurker", "Bog Lurker", bog_lurker),
           ("gloam_witch", "Gloam Witch", gloam_witch)]


def standalone(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="300" height="520" viewBox="0 0 300 520">'
            f'<defs>{FILTERS}</defs>{body}</svg>')


def lineup():
    cw, ch, scale = 240, 330, 0.5
    cols = 5
    rows = math.ceil(len(ENEMIES) / cols)
    W, H = 60 + cols * cw, 120 + rows * ch
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Georgia, serif">',
         f'<defs>{FILTERS}<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff3cf"/>'
         '<stop offset="0.45" stop-color="#bff0e2"/><stop offset="1" stop-color="#6cc7b6"/></linearGradient>'
         '<linearGradient id="meadow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#c8b56a"/>'
         '<stop offset="1" stop-color="#6f6a38"/></linearGradient></defs>',
         f'<rect width="{W}" height="{H}" fill="#1b2433"/>',
         '<text x="30" y="50" fill="#fff3cf" font-size="28">Riftrite: Act 1 enemies (luminous placeholder kit)</text>',
         '<text x="30" y="78" fill="#a9c9c4" font-size="15">Code-generated from tools/art/enemy_kit.py. Darker palette and more rift glow than the heroes; '
         'one shape per archetype.</text>']
    for i, (eid, name, fn) in enumerate(ENEMIES):
        x, y = 30 + (i % cols) * cw, 100 + (i // cols) * ch
        s.append(f'<clipPath id="c{i}"><rect x="{x+6}" y="{y}" width="{cw-12}" height="{ch-14}" rx="6"/></clipPath>'
                 f'<g clip-path="url(#c{i})"><rect x="{x+6}" y="{y}" width="{cw-12}" height="{ch-14}" fill="url(#sky)"/>'
                 f'<path d="M{x+6},{y+ch-80} C{x+80},{y+ch-92} {x+160},{y+ch-86} {x+cw-6},{y+ch-90} L{x+cw-6},{y+ch} L{x+6},{y+ch} Z" fill="url(#meadow)"/>'
                 f'<g transform="translate({x + cw/2 - 150*scale},{y + 44}) scale({scale})">{fn(f"e{i}")}</g></g>'
                 f'<rect x="{x+14}" y="{y+8}" width="{cw-28}" height="30" rx="4" fill="#1b2433" opacity="0.78"/>'
                 f'<text x="{x+24}" y="{y+29}" fill="#fff3cf" font-size="16">{name}</text>')
    s.append('</svg>')
    return "".join(s)


if __name__ == "__main__":
    out = os.path.join(ROOT, "art", "figures", "enemies")
    os.makedirs(out, exist_ok=True)
    for eid, _, fn in ENEMIES:
        with open(os.path.join(out, f"{eid}.svg"), "w") as f:
            f.write(standalone(fn(eid)))
    with open(os.path.join(ROOT, "art", "look-tests", "enemy_lineup.svg"), "w") as f:
        f.write(lineup())
    print("ok")
