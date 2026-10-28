"""Look tests for the acts' palettes (docs/plans/art/art-style-guide.md,
section 7, Question SC): each act's arena on its floating island, in the act's
sky and ground, with the same three heroes (transformed) against the act's
enemies, beside the act's palette. Act 2, the Glassmere: a drowned lake of
glass, colder, the gold low. Act 3, the Shattered Crown: broken islands over
the void under a crown of shattered light, the darkest act. Act 1 is drawn the
same way for the side-by-side.

Writes art/look-tests/act2_look_test.svg, act3_look_test.svg, and
acts_side_by_side.svg. Placeholder quality: the figures are the kits' (Acts 2's
and 3's enemies are recolors of Act 1's shapes); what's on test is the color.

Usage: python3 tools/art/act_look_tests.py
then render the PNGs: node tools/art/render_svg.js art/look-tests/act2_look_test.svg ...
"""
import math, os, random, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import enemy_kit as E  # noqa: E402
import hero_kit as H  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
OUT = os.path.join(ROOT, "art", "look-tests")
INK = H.INK

# The board: 8 x 7 flat-top hexes, odd columns shifted (HexGrid), heroes at the
# bottom (row 0). HEX is the flat-to-flat height in pixels.
COLS, ROWS = 8, 7
HEX = 74
R = HEX / math.sqrt(3)
STEP = 0.866 * HEX
BOARD_W = (COLS - 1) * STEP + 2 * R
BOARD_H = ROWS * HEX + HEX / 2
SCENE_W, SCENE_H = 1060, 750
BX = (SCENE_W - BOARD_W) / 2
BY = 62
# A figure's canvas is 1.35 hexes tall (UnitToken.FIGURE_HEXES).
FIG = 1.35 * HEX / 520

TEAM = [("hero", "brannoc_hearthwall", (3, 2)), ("hero", "maren_deadeye", (1, 0)), ("hero", "vell_lanternbearer", (5, 1))]

ACTS = {
    1: {
        "name": "Act 1", "place": "the rift's edge",
        "sky": [(0, "#FFF3CF"), (0.45, "#BFF0E2"), (0.8, "#6CC7B6"), (1, "#3F8F8A")],
        "ground": ["#C8B56A", "#BFAB62", "#CDBB72"], "line": "#F4EAD0", "side": "#6F6A38", "side_dk": "#4C4826",
        "far": "#C8B56A", "far_side": "#8A8456", "motes": ["#FFD66E", "#62F2DF"], "sun": ("#FFD66E", 0.22, 0.12),
        "enemies": [("rift_hound", (2, 4)), ("rift_pup", (5, 4)), ("hollow_archer", (4, 6)), ("gloam_witch", (2, 6)), ("cairn_guardian", (6, 5))],
        "rocks": [("broken_column", (1, 3)), ("rift_altar", (6, 3))],
        "water": [], "void": [], "bridges": [],
    },
    2: {
        "name": "Act 2, the Glassmere", "place": "a drowned lake of glass",
        "sky": [(0, "#EEF1E4"), (0.35, "#D2E7E3"), (0.7, "#8CC1C1"), (1, "#3A747C")],
        "ground": ["#9DAE86", "#93A57D", "#A6B68E"], "line": "#EAF3E6", "side": "#4F6650", "side_dk": "#33463A",
        "far": "#9DAE86", "far_side": "#5E7462", "motes": ["#62F2DF", "#62F2DF", "#F2DE9A"], "sun": ("#F2DE9A", 0.5, 0.62),
        "water": [(c, r) for c in range(2, 6) for r in (4, 5)] + [(0, 3), (1, 3), (6, 3), (7, 3), (3, 6), (4, 6)],
        "enemies": [("mire_eel", (2, 4)), ("drowned_warden", (4, 4)), ("glass_shambler", (6, 4)),
                    ("tidecaller", (5, 6)), ("reedline_slinger", (1, 6)), ("drowned_bellringer", (6, 6))],
        "rocks": [("broken_column", (0, 5)), ("headless_statue", (7, 5))],
        "void": [], "bridges": [],
    },
    3: {
        "name": "Act 3, the Shattered Crown", "place": "the rift's heart",
        "sky": [(0, "#1D1740"), (0.4, "#382C6C"), (0.75, "#6A58A8"), (1, "#9A86D4")],
        "ground": ["#9A8A78", "#8E7E6C", "#A39382"], "line": "#E8E0FF", "side": "#5E4C78", "side_dk": "#3A2E52",
        "far": "#8E7E6C", "far_side": "#4A3C64", "motes": ["#E8E0FF", "#62F2DF", "#9C88D8"], "sun": None,
        "void": [(c, 3) for c in range(COLS) if c not in (1, 6)] + [(0, 6), (7, 6)],
        "bridges": [(1, 3), (6, 3)],
        "enemies": [("cragram", (2, 4)), ("cliffmite", (4, 4)), ("unbinder", (5, 5)), ("mirrorwight", (1, 5)),
                    ("gulf_angler", (3, 6)), ("spire_chanter", (6, 6))],
        "rocks": [("rift_crystal", (7, 4)), ("broken_column", (0, 1))],
        "water": [],
    },
}

PALETTES = {
    2: [("Dawn haze", "#EEF1E4"), ("Glass mist", "#D2E7E3"), ("Drowned sea", "#3A747C"), ("Wet sage", "#9DAE86"),
        ("Bank", "#4F6650"), ("Shallows", "#7FD3D6"), ("Glint", "#D8F6F4"), ("Glass", "#8FC9D2"),
        ("Tide", "#2A6570"), ("Low gold", "#F2DE9A"), ("Aquamarine", "#62F2DF"), ("Ink", "#1A1024")],
    3: [("Void night", "#1D1740"), ("Void dusk", "#382C6C"), ("Crown haze", "#9A86D4"), ("Crag", "#9A8A78"),
        ("Violet stone", "#5E4C78"), ("Deep stone", "#3A2E52"), ("Crown", "#9C88D8"), ("Crown light", "#E8E0FF"),
        ("Aquamarine", "#62F2DF"), ("Bridge stone", "#7A6A5A"), ("Ember (rare)", "#FF9A3C"), ("Ink", "#1A1024")],
}

NOTES = {
    2: ["The gold is low and thin: a dawn haze on the horizon, not noon.",
        "Wet sage ground, so the warm heroes still pop and the drowned teal enemies sit back.",
        "Water is glassy shallows with pale glints, never the reserved Slow blue.",
        "Mist bands and sunken bell towers say drowned; glass shards say Glassmere.",
        "Most motes are aquamarine now: the rift is nearer."],
    3: ["The darkest act: the sky is the void, indigo to violet, lit from below.",
        "Bright but wrong still holds: the crown of shattered light and the crag stay luminous.",
        "Islands are crag on violet stone; the void between them is the sky itself.",
        "Bridges are narrow stone spans, the only way across.",
        "Gold is almost gone; crown violet and aquamarine carry the light."],
}


def hex_center(col, row):
    x = BX + R + col * STEP
    y_plane = row * HEX + HEX / 2 + (HEX / 2 if col % 2 == 1 else 0)
    return x, BY + BOARD_H - y_plane


def hex_points(cx, cy, r=R):
    return " ".join(f"{cx + r * math.cos(math.radians(a)):.1f},{cy + r * math.sin(math.radians(a)):.1f}" for a in range(0, 360, 60))


def gradient(gid, stops):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">{s}</linearGradient>'


def nested(body, x, y, w, h, view_w, view_h, flip=False):
    """`body` drawn in a box at (x, y), w x h, from a view_w x view_h canvas."""
    inner = f'<g transform="translate({view_w},0) scale(-1,1)">{body}</g>' if flip else body
    return f'<svg x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" viewBox="0 0 {view_w} {view_h}" overflow="visible">{inner}</svg>'


def prop(name):
    text = open(os.path.join(ROOT, "art", "ui", "arena", "props", name + ".svg")).read()
    return text[text.index(">") + 1:text.rindex("</svg>")]


def far_island(rng, x, y, w, top, side, ruin=True):
    h = w * 0.55
    pts = [(x - w / 2, y), (x - w * 0.3, y - w * 0.08), (x + w * 0.25, y - w * 0.07), (x + w / 2, y)]
    top_d = "M" + " L".join(f"{a:.1f},{b:.1f}" for a, b in pts) + f" L{x + w * 0.42:.1f},{y + w * 0.06:.1f} L{x - w * 0.4:.1f},{y + w * 0.07:.1f} Z"
    side_d = f"M{x - w * 0.4:.1f},{y + w * 0.07:.1f} L{x + w * 0.42:.1f},{y + w * 0.06:.1f} L{x + w * 0.05:.1f},{y + h:.1f} Z"
    s = (f'<path d="{side_d}" fill="{side}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>'
         f'<path d="{top_d}" fill="{top}" stroke="{INK}" stroke-width="2" stroke-linejoin="round"/>')
    if ruin:
        cx = x + rng.uniform(-w * 0.2, w * 0.15)
        s += (f'<rect x="{cx:.1f}" y="{y - w * 0.32:.1f}" width="{w * 0.06:.1f}" height="{w * 0.3:.1f}" fill="#F4EAD0" stroke="{INK}" stroke-width="1.5"/>'
              f'<rect x="{cx + w * 0.18:.1f}" y="{y - w * 0.24:.1f}" width="{w * 0.06:.1f}" height="{w * 0.22:.1f}" fill="#F4EAD0" stroke="{INK}" stroke-width="1.5"/>')
    return s


def slab(rows, act):
    """An island under the hexes of `rows`: a jagged top edge round them and
    earth falling away below."""
    top = min(hex_center(c, r)[1] for c in range(COLS) for r in rows) - HEX / 2 - 14
    bottom = max(hex_center(c, r)[1] for c in range(COLS) for r in rows) + HEX / 2 + 10
    left, right = BX - 16, BX + BOARD_W + 16
    rng = random.Random(int(top))
    depth = 120 if min(rows) == 0 else 70
    side = (f'<path d="M{left},{bottom} L{right},{bottom} L{right - 40},{bottom + depth * 0.55} L{right - 140},{bottom + depth} '
            f'L{left + 200},{bottom + depth * 0.85} L{left + 30},{bottom + depth * 0.5} Z" fill="{act["side"]}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
            f'<path d="M{(left + right) / 2},{bottom} L{right - 140},{bottom + depth} L{right - 40},{bottom + depth * 0.55} L{right},{bottom} Z" fill="{act["side_dk"]}" opacity="0.55"/>')
    edge = []
    x = left
    while x < right:
        edge.append((x, top + rng.uniform(-4, 4)))
        x += 38
    edge.append((right, top))
    d = "M" + " L".join(f"{a:.1f},{b:.1f}" for a, b in edge) + f" L{right},{bottom} L{left},{bottom} Z"
    return side + f'<path d="{d}" fill="{act["ground"][0]}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'


def hex_island(cells, act, depth):
    """An island made of exactly `cells` (an island over the void): its earth
    hangs under each hex with void or the board's edge below it, then its
    ground, outlined in ink as one shape."""
    cells = set(cells)
    s = []
    for c, r in sorted(cells, key=lambda h: hex_center(*h)[1]):
        if (c, r - 1) in cells:
            continue
        cx, cy = hex_center(c, r)
        drop = depth * (0.7 + 0.3 * ((c * 5 + r) % 3) / 2)
        s.append(f'<path d="M{cx - R:.1f},{cy:.1f} L{cx - R / 2:.1f},{cy + HEX / 2:.1f} L{cx + R / 2:.1f},{cy + HEX / 2:.1f} L{cx + R:.1f},{cy:.1f} '
                 f'L{cx + R * 0.4:.1f},{cy + HEX / 2 + drop:.1f} L{cx - R * 0.5:.1f},{cy + HEX / 2 + drop * 0.7:.1f} Z" '
                 f'fill="{act["side"]}" stroke="{INK}" stroke-width="3" stroke-linejoin="round"/>'
                 f'<path d="M{cx:.1f},{cy + HEX / 2:.1f} L{cx + R / 2:.1f},{cy + HEX / 2:.1f} L{cx + R:.1f},{cy:.1f} L{cx + R * 0.4:.1f},{cy + HEX / 2 + drop:.1f} Z" '
                 f'fill="{act["side_dk"]}" opacity="0.6"/>')
    for c, r in cells:
        s.append(f'<polygon points="{hex_points(*hex_center(c, r), R + 3)}" fill="{INK}"/>')
    return "".join(s)


def scene(n, uid):
    """Act `n`'s arena scene, SCENE_W x SCENE_H, ids prefixed by `uid`."""
    act = ACTS[n]
    rng = random.Random(n * 101)
    s = [f'<defs>{gradient(uid + "sky", act["sky"])}'
         f'<radialGradient id="{uid}sun" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="{(act["sun"] or ("#fff", 0, 0))[0]}" stop-opacity="0.8"/>'
         f'<stop offset="1" stop-color="{(act["sun"] or ("#fff", 0, 0))[0]}" stop-opacity="0"/></radialGradient>'
         f'<radialGradient id="{uid}crown" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#E8E0FF" stop-opacity="0.75"/>'
         f'<stop offset="1" stop-color="#9C88D8" stop-opacity="0"/></radialGradient></defs>',
         f'<rect width="{SCENE_W}" height="{SCENE_H}" fill="url(#{uid}sky)"/>']
    if act["sun"]:
        color, fx, fy = act["sun"]
        s.append(f'<ellipse cx="{SCENE_W * fx}" cy="{SCENE_H * fy}" rx="{SCENE_W * 0.45}" ry="{SCENE_H * 0.3}" fill="url(#{uid}sun)"/>')
    if n == 1:
        s.append(f'<path d="M820,0 L800,140 L835,260 L812,420" fill="none" stroke="#62F2DF" stroke-width="3" opacity="0.5" filter="url(#glow)"/>')
    if n == 2:
        for y, op in ((210, 0.35), (300, 0.25), (520, 0.3)):
            s.append(f'<rect x="0" y="{y}" width="{SCENE_W}" height="34" fill="#FFFFFF" opacity="{op}" rx="17"/>')
        for x, h in ((70, 120), (960, 150)):
            s.append(f'<path d="M{x},{SCENE_H} L{x},{SCENE_H - h} L{x + 16},{SCENE_H - h - 30} L{x + 32},{SCENE_H - h} L{x + 32},{SCENE_H} Z" fill="#3A747C" opacity="0.55"/>'
                     f'<circle cx="{x + 16}" cy="{SCENE_H - h + 12}" r="8" fill="none" stroke="#F2DE9A" stroke-width="2" opacity="0.6"/>')
    if n == 3:
        # The crown of shattered light: a ring of shards round the sky's top,
        # wide enough to show either side of the board.
        s.append(f'<ellipse cx="{SCENE_W / 2}" cy="60" rx="560" ry="200" fill="url(#{uid}crown)"/>')
        for i in range(17):
            a = math.pi * 1.04 + i * math.pi * 0.92 / 16
            cx, cy = SCENE_W / 2 + 500 * math.cos(a), 250 + 210 * math.sin(a)
            h = 38 + (i % 3) * 16
            col = ("#E8E0FF", "#9C88D8", "#62F2DF")[i % 3]
            s.append(f'<path d="M{cx:.1f},{cy - h:.1f} L{cx + 9:.1f},{cy:.1f} L{cx:.1f},{cy + h * 0.35:.1f} L{cx - 9:.1f},{cy:.1f} Z" '
                     f'fill="{col}" stroke="{INK}" stroke-width="1.5" filter="url(#glow)" transform="rotate({(i - 6) * 9},{cx:.1f},{cy:.1f})"/>')
    for x, y, w in ((110, 150, 120), (950, 120, 150), (150, 560, 160), (930, 520, 130), (60, 380, 70), (1010, 340, 60)):
        s.append(far_island(rng, x, y, w, act["far"], act["far_side"], ruin=(n != 3)))
        if n == 2:
            s.append(f'<path d="M{x - 10},{y - 4} L{x - 4},{y - 40} L{x + 2},{y - 4} Z" fill="#BFE8F0" stroke="{INK}" stroke-width="1.5" opacity="0.9"/>')
        if n == 3:
            s.append(f'<path d="M{x - 6},{y - 4} L{x},{y - w * 0.5} L{x + 8},{y - 4} Z" fill="#7A6A5A" stroke="{INK}" stroke-width="1.5"/>')
    for _ in range(70):
        x, y = rng.uniform(0, SCENE_W), rng.uniform(0, SCENE_H)
        s.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{rng.uniform(1.2, 3):.1f}" fill="{rng.choice(act["motes"])}" opacity="{rng.uniform(0.5, 0.95):.2f}"/>')

    void = set(act["void"])
    bridges = set(act["bridges"])
    if void:
        solid = [(c, r) for c in range(COLS) for r in range(ROWS) if (c, r) not in void and (c, r) not in bridges]
        s.append(hex_island([h for h in solid if h[1] > 3], act, 90))
        s.append(hex_island([h for h in solid if h[1] < 3], act, 150))
    else:
        s.append(slab(range(0, ROWS), act))
    water = set(act["water"])
    for r in range(ROWS - 1, -1, -1):
        for c in range(COLS):
            cx, cy = hex_center(c, r)
            if (c, r) in void:
                continue
            if (c, r) in bridges:
                s.append(f'<rect x="{cx - R * 0.35:.1f}" y="{cy - HEX * 0.62:.1f}" width="{R * 0.7:.1f}" height="{HEX * 1.24:.1f}" fill="#7A6A5A" stroke="{INK}" stroke-width="2.5"/>'
                         + "".join(f'<line x1="{cx - R * 0.35:.1f}" y1="{cy + k * 14:.1f}" x2="{cx + R * 0.35:.1f}" y2="{cy + k * 14:.1f}" stroke="{INK}" stroke-width="1" opacity="0.5"/>' for k in range(-2, 3)))
                continue
            fill = "#7FD3D6" if (c, r) in water else act["ground"][(c * 7 + r * 3) % 3]
            s.append(f'<polygon points="{hex_points(cx, cy, R + 0.6)}" fill="{fill}"/>')
            if (c, r) in water:
                s.append(f'<path d="M{cx - 18:.1f},{cy + 6:.1f} q9,-6 18,0 t18,0" fill="none" stroke="#D8F6F4" stroke-width="2.2" opacity="0.9"/>'
                         f'<path d="M{cx - 8:.1f},{cy - 12:.1f} q6,-4 12,0" fill="none" stroke="#D8F6F4" stroke-width="1.8" opacity="0.8"/>')
            elif void:
                # Bare crag: a crack, not a tuft.
                k = rng.uniform(-14, 10)
                s.append(f'<path d="M{cx + k:.1f},{cy - 12:.1f} l5,8 l-4,6 l6,9" fill="none" stroke="{act["side_dk"]}" stroke-width="1.5" opacity="0.55"/>')
            else:
                tuft = rng.uniform(-14, 14)
                s.append(f'<path d="M{cx + tuft:.1f},{cy + 10:.1f} l-3,-9 M{cx + tuft:.1f},{cy + 10:.1f} l2,-10 M{cx + tuft:.1f},{cy + 10:.1f} l6,-7" '
                         f'stroke="{act["side_dk"]}" stroke-width="1.4" opacity="0.5"/>')
    for r in range(ROWS):
        for c in range(COLS):
            if (c, r) in void or (c, r) in bridges:
                continue
            cx, cy = hex_center(c, r)
            s.append(f'<polygon points="{hex_points(cx, cy)}" fill="none" stroke="{act["line"]}" stroke-width="1.4" opacity="0.4"/>')

    things = []
    for name, (c, r) in act["rocks"]:
        cx, cy = hex_center(c, r)
        things.append((cy, nested(prop(name), cx - HEX * 0.6, cy - HEX * 0.95, HEX * 1.2, HEX * 1.2, 300, 300)))
    for i, (_, fn, (c, r)) in enumerate(TEAM):
        cx, cy = hex_center(c, r)
        ring = f'<ellipse cx="{cx:.1f}" cy="{cy + 4:.1f}" rx="{R * 0.62:.1f}" ry="{R * 0.25:.1f}" fill="none" stroke="#FFD66E" stroke-width="3"/>'
        body = getattr(H, fn)(f"{uid}h{i}")
        things.append((cy, ring + nested(body, cx - 150 * FIG, cy + 4 - 500 * FIG, 300 * FIG, 520 * FIG, 300, 520)))
    for i, (eid, (c, r)) in enumerate(act["enemies"]):
        cx, cy = hex_center(c, r)
        ripple = (f'<ellipse cx="{cx:.1f}" cy="{cy + 4:.1f}" rx="{R * 0.8:.1f}" ry="{R * 0.3:.1f}" fill="none" stroke="#D8F6F4" stroke-width="2" opacity="0.8"/>'
                  if (c, r) in water else "")
        ring = f'<ellipse cx="{cx:.1f}" cy="{cy + 4:.1f}" rx="{R * 0.62:.1f}" ry="{R * 0.25:.1f}" fill="none" stroke="#E0503C" stroke-width="3"/>'
        body = getattr(E, eid)(f"{uid}e{i}")
        things.append((cy, ripple + ring + nested(body, cx - 150 * FIG, cy + 4 - 500 * FIG, 300 * FIG, 520 * FIG, 300, 520, flip=True)))
    for _, svg in sorted(things, key=lambda t: t[0]):
        s.append(svg)
    return "".join(s)


def sheet(n):
    act = ACTS[n]
    W, Hh = 1600, 900
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{Hh}" viewBox="0 0 {W} {Hh}" font-family="Georgia, serif">',
         f'<defs>{H.FILTERS}<clipPath id="sceneclip"><rect width="{SCENE_W}" height="{SCENE_H}" rx="8"/></clipPath></defs>',
         f'<rect width="{W}" height="{Hh}" fill="#1b2433"/>',
         f'<text x="30" y="50" fill="#fff3cf" font-size="28">{act["name"]}: look test</text>',
         f'<text x="30" y="80" fill="#a9c9c4" font-size="15">{act["place"].capitalize()}, in the luminous style (art-style-guide.md, section 7, Question SC). '
         'Placeholder figures from the kits; what\'s on test is the color.</text>',
         f'<g transform="translate(30,110)"><g clip-path="url(#sceneclip)">{scene(n, "s")}</g>'
         f'<rect width="{SCENE_W}" height="{SCENE_H}" rx="8" fill="none" stroke="#395265" stroke-width="2"/></g>']
    px = 30 + SCENE_W + 30
    s.append(f'<rect x="{px}" y="110" width="{W - px - 30}" height="400" rx="8" fill="#121a26" stroke="#395265"/>'
             f'<text x="{px + 24}" y="148" fill="#fff3cf" font-size="22">Palette</text>')
    for i, (name, color) in enumerate(PALETTES[n]):
        x, y = px + 24 + (i % 3) * 145, 170 + (i // 3) * 82
        s.append(f'<rect x="{x}" y="{y}" width="125" height="48" rx="5" fill="{color}" stroke="#f4ead0" stroke-width="1.5"/>'
                 f'<text x="{x}" y="{y + 66}" fill="#d8cfb8" font-size="13">{name}  {color}</text>')
    s.append(f'<rect x="{px}" y="530" width="{W - px - 30}" height="330" rx="8" fill="#121a26" stroke="#395265"/>'
             f'<text x="{px + 24}" y="568" fill="#fff3cf" font-size="22">What changes from Act 1</text>')
    y = 600
    for note in NOTES[n]:
        words, line = note.split(), ""
        for w in words:
            if len(line) + len(w) > 50:
                s.append(f'<text x="{px + 24}" y="{y}" fill="#d8cfb8" font-size="14">{line}</text>')
                y, line = y + 20, ""
            line = (line + " " + w).strip()
        s.append(f'<text x="{px + 24}" y="{y}" fill="#d8cfb8" font-size="14">{line}</text>')
        y += 30
    s.append("</svg>")
    return "".join(s)


def side_by_side():
    scale = 0.5
    w, h = SCENE_W * scale, SCENE_H * scale
    W, Hh = int(3 * w + 4 * 24), int(h + 130)
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{Hh}" viewBox="0 0 {W} {Hh}" font-family="Georgia, serif">',
         f'<defs>{H.FILTERS}<clipPath id="small"><rect width="{SCENE_W}" height="{SCENE_H}" rx="12"/></clipPath></defs>',
         f'<rect width="{W}" height="{Hh}" fill="#1b2433"/>',
         '<text x="24" y="42" fill="#fff3cf" font-size="24">The climb: each act moves the palette a step</text>',
         '<text x="24" y="68" fill="#a9c9c4" font-size="14">Bright but wrong all the way; the dark is saved for the later acts (art-style-guide.md, Decision 3).</text>']
    for i, n in enumerate((1, 2, 3)):
        x = 24 + i * (w + 24)
        s.append(f'<g transform="translate({x},96) scale({scale})"><g clip-path="url(#small)">{scene(n, f"a{n}")}</g></g>'
                 f'<text x="{x}" y="{96 + h + 24}" fill="#d8cfb8" font-size="15">{ACTS[n]["name"]}</text>')
    s.append("</svg>")
    return "".join(s)


if __name__ == "__main__":
    for n in (2, 3):
        with open(os.path.join(OUT, f"act{n}_look_test.svg"), "w") as f:
            f.write(sheet(n))
    with open(os.path.join(OUT, "acts_side_by_side.svg"), "w") as f:
        f.write(side_by_side())
    print("ok")
