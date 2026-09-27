"""The rest of the item icons, and the relic icons (docs/ui-asset-design.md,
8.1 and 8.2). item_icons.py writes them all; this file just holds the
drawings, built from a few shared shapes (bows, shields, bottles, censers,
books) so the set stays consistent. Same 64x64 canvas and rules as
item_icons.py. Relic icons are drawn inside the hex token, so they keep to
the middle of the canvas.
"""
from item_icons import (
    INK, OAK_D, OAK, OAK_L, BRASS_D, BRASS, BRASS_L, STEEL_D, STEEL, STEEL_L, BONE_D, BONE, BONE_L, PARCH,
    EMBER, FLAME_Y, FROST_D, FROST, FROST_L, MOSS_D, MOSS, RIFT_D, RIFT, RIFT_L, BLOOD, SLATE_D, SLATE, SLATE_L, RUST,
    path, line, circle, rect, group, svg, flame, knife,
)

VENOM, VENOM_L = "#7ED14F", "#C8F0A0"
STORM = "#E8C877"
RED_CLOTH = "#9A3A30"


def ellipse(cx, cy, rx, ry, fill, stroke=True, sw=3, extra=""):
    s = f' stroke="{INK}" stroke-width="{sw}"' if stroke else ""
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"{s}{extra}/>'


# --- shared shapes -------------------------------------------------------------

def bow(wood, wood_d, string=PARCH, accent="", rot=-40, long=26):
    limb = f"M22 {32 - long} Q46 32 22 {32 + long}"
    body = (line(limb, INK, 11) + line(limb, wood, 7) + line(f"M25 {36 - long} Q40 32 36 36", wood_d, 2)
            + line(f"M22 {32 - long} L22 {32 + long}", string, 2) + rect(35, 27, 8, 10, OAK_L, 2))
    if accent:
        body += circle(22, 32 - long, 3, accent) + circle(22, 32 + long, 3, accent)
    arrow = line("M14 32 L54 32", OAK_D, 2.5) + path("M54 28 L61 32 L54 36 Z", STEEL, sw=2.5)
    return svg(group(body + arrow, f"rotate({rot} 32 32)"))


def crossbow(wood, accent):
    stock = path("M10 40 L46 22 L50 28 L14 46 Z", wood) + rect(40, 20, 8, 22, OAK_D, 2)
    arms = line("M26 14 Q46 18 54 44", INK, 8) + line("M26 14 Q46 18 54 44", STEEL, 4.5)
    string = line("M26 14 L36 30 L54 44", PARCH, 1.8)
    bolt = line("M20 38 L50 23", OAK_L, 3) + path("M50 20 L57 20 L52 26 Z", STEEL, sw=2)
    feathers = path("M10 44 L18 38 L20 44 Z", accent, sw=2)
    return svg(stock + arms + string + bolt + feathers)


def round_shield(face, rim, boss, detail=""):
    return svg(circle(32, 33, 25, face) + detail + f'<circle cx="32" cy="33" r="22" fill="none" stroke="{rim}" stroke-width="3.5"/>'
               + f'<circle cx="32" cy="33" r="25" fill="none" stroke="{INK}" stroke-width="3"/>'
               + circle(32, 33, 7, boss) + circle(29.5, 30.5, 2, BRASS_L, stroke=False) + line("M13 26 Q17 16 28 11", "#FFFFFF", 2.5, ))


def kite_shield(face, trim, emblem=""):
    return svg(path("M32 6 L56 14 Q56 42 32 60 Q8 42 8 14 Z", face)
               + path("M32 10 L52 17 Q52 40 32 55 Q12 40 12 17 Z", "none", stroke=False, extra=f' stroke="{trim}" stroke-width="3"')
               + emblem + line("M15 18 L15 32", "#FFFFFF", 2.5, ))


def bottle(liquid, liquid_l, glass="#B9D0C8", cork=OAK_L, label="", round_=True):
    neck = rect(27, 12, 10, 10, glass, 1) + rect(26, 6, 12, 8, cork, 2)
    body = circle(32, 40, 18, glass) if round_ else rect(16, 22, 32, 36, glass, 8)
    fill = (path("M14.5 40 Q23 36 32 40 Q41 44 49.5 40 Q49 57 32 57.5 Q15 57 14.5 40 Z", liquid, stroke=False) if round_
            else rect(17.5, 34, 29, 22.5, liquid, 7, stroke=False))
    outline = (f'<circle cx="32" cy="40" r="18" fill="none" stroke="{INK}" stroke-width="3"/>' if round_
               else f'<rect x="16" y="22" width="32" height="36" rx="8" fill="none" stroke="{INK}" stroke-width="3"/>')
    return neck + body + fill + circle(26, 48, 2, liquid_l, stroke=False) + circle(38, 51, 1.6, liquid_l, stroke=False) + label + outline + line("M21 31 Q23 27 27 25", "#FFFFFF", 2.5)


def censer(metal, metal_d, smoke, glow):
    chains = line("M20 6 L26 24", INK, 2) + line("M44 6 L38 24", INK, 2) + line("M32 4 L32 20", INK, 2)
    body = path("M14 30 Q14 54 32 54 Q50 54 50 30 Z", metal) + path("M16 24 Q32 14 48 24 L48 30 L16 30 Z", metal_d)
    holes = circle(24, 40, 2.5, glow, stroke=False) + circle(32, 44, 2.5, glow, stroke=False) + circle(40, 40, 2.5, glow, stroke=False)
    puffs = circle(48, 16, 6, smoke, stroke=False, ) + circle(54, 8, 4, smoke, stroke=False)
    return svg(chains + puffs + body + holes + rect(26, 54, 12, 5, metal_d, 2) + line("M18 34 Q20 44 26 50", "#FFFFFF", 2))


def book(cover, spine, emblem):
    pages = path("M14 14 L50 10 L52 52 L16 56 Z", PARCH)
    body = path("M10 12 Q10 9 13 9 L46 6 Q49 6 49 9 L50 48 Q50 51 47 51 L14 54 Q11 54 11 51 Z", cover)
    sp = path("M10 12 Q10 9 13 9 L17 8.7 L18 53.6 L14 54 Q11 54 11 51 Z", spine, sw=2.5)
    corners = path("M44 6.2 L49 6 L49 11 Z", BRASS, sw=2) + path("M50 45 L50 48 Q50 51 47 51 L45 51.2 Z", BRASS, sw=2)
    return svg(pages + body + sp + emblem + corners)


def bell(metal, metal_d, clapper=BRASS_D):
    return (path("M18 44 Q18 14 32 12 Q46 14 46 44 L52 50 L12 50 Z", metal)
            + path("M38 16 Q46 22 46 44 L52 50 L40 50 Z", metal_d, stroke=False, extra=' opacity="0.5"')
            + path("M18 44 Q18 14 32 12 Q46 14 46 44 L52 50 L12 50 Z", "none")
            + circle(32, 54, 5, clapper) + rect(28, 6, 8, 7, OAK, 2) + line("M22 22 Q24 16 29 15", "#FFFFFF", 2.5))


def spear(head, shaft, length=52, rot=45, tassel=""):
    body = (line(f"M32 {32 + length / 2} L32 {32 - length / 2 + 12}", INK, 7) + line(f"M32 {32 + length / 2} L32 {32 - length / 2 + 12}", shaft, 4)
            + path(f"M32 {32 - length / 2 - 4} L38 {32 - length / 2 + 10} L32 {32 - length / 2 + 14} L26 {32 - length / 2 + 10} Z", head))
    if tassel:
        body += path(f"M30 {32 - length / 2 + 16} L26 {32 - length / 2 + 26} L34 {32 - length / 2 + 24} Z", tassel, sw=2)
    return svg(group(body, f"rotate({rot} 32 32)"))


def rift_cracks(*ds):
    return "".join(line(d, RIFT, 5) + line(d, RIFT_L, 2) for d in ds)


# --- items ---------------------------------------------------------------------

def night_lantern():
    return svg(line("M26 10 Q32 1 38 10", INK, 6) + line("M26 10 Q32 1 38 10", STEEL_L, 3)
               + path("M20 16 L44 16 L40 9 L24 9 Z", "#4A4056") + rect(20, 16, 24, 28, "#3E3368", 2)
               + '<rect x="23" y="19" width="18" height="22" rx="2" fill="#B79CF0" opacity="0.85"/>'
               + path("M32 22 A7 7 0 1 0 33 36 A5.5 5.5 0 1 1 32 22 Z", "#FFFFFF", sw=1.5)
               + line("M26 16 L26 44", "#2A2248", 2.5) + line("M38 16 L38 44", "#2A2248", 2.5)
               + path("M17 44 L47 44 L44 54 L20 54 Z", "#4A4056") + circle(48, 22, 2, RIFT_L, stroke=False))


def grave_hook():
    hook = (line("M16 58 L34 14", INK, 7) + line("M16 58 L34 14", OAK_D, 4)
            + path("M32 10 Q52 4 54 22 Q54 34 42 36 L42 30 Q48 28 47 21 Q44 12 34 16 Z", STEEL))
    return svg(hook + line("M36 14 Q46 10 50 18", STEEL_L, 2) + circle(20, 50, 3, BONE_L))


def smokeglass_vial():
    smoke = circle(46, 10, 6, SLATE_L, stroke=False) + circle(54, 4, 4, SLATE_L, stroke=False) + circle(40, 4, 3, SLATE_L, stroke=False)
    return svg(bottle("#6E6878", "#B8B0C4", round_=False) + smoke)


def war_drum():
    shell = rect(12, 26, 40, 26, RED_CLOTH, 4) + line("M12 32 L52 32", BRASS, 3) + line("M12 46 L52 46", BRASS, 3)
    top = ellipse(32, 26, 20, 7, PARCH)
    ropes = "".join(line(f"M{x} 32 L{x + 6} 46", BONE, 2) + line(f"M{x + 6} 32 L{x} 46", BONE, 2) for x in (16, 29, 42))
    sticks = line("M40 6 L30 22", OAK, 4) + circle(40, 6, 3.5, BONE) + line("M52 12 L38 22", OAK, 4) + circle(52, 12, 3.5, BONE)
    return svg(shell + ropes + top + sticks)


def vespers_bell():
    return svg(bell(BRASS, BRASS_D) + line("M10 14 L14 18", FLAME_Y, 2.5) + line("M54 14 L50 18", FLAME_Y, 2.5))


def old_guards_standard():
    pole = line("M14 4 L14 60", INK, 6) + line("M14 4 L14 60", OAK, 3) + circle(14, 5, 3.5, BRASS)
    cloth = path("M16 10 L54 10 L54 44 L35 36 L16 44 Z", RED_CLOTH)
    emblem = flame(35, 29, 0.6)
    return svg(pole + cloth + emblem + line("M16 14 L54 14", BRASS, 2.5))


def gale_blades():
    wind = line("M6 20 Q20 14 30 20", FROST_L, 2.5) + line("M4 30 Q18 24 26 30", FROST_L, 2.5) + line("M10 40 Q22 36 28 40", FROST_L, 2)
    return svg(wind + group(knife("#DDE8F0", "#FFFFFF", STEEL_D, INK, long=30, width=10), "rotate(35 36 32)")
               + group(knife("#DDE8F0", "#FFFFFF", STEEL_D, INK, long=26, width=9), "rotate(55 44 40)"))


def vesper_chime():
    bar = line("M10 8 L54 8", INK, 6) + line("M10 8 L54 8", OAK, 3)
    tubes = "".join(line(f"M{x} 8 L{x} 14", INK, 1.5) + rect(x - 3.5, 14, 7, h, STEEL_L, 2) for x, h in ((18, 30), (27, 38), (36, 34), (45, 26)))
    return svg(bar + tubes + circle(31, 54, 5, MOSS) + line("M31 49 L31 44", INK, 1.5))


def hollow_maw():
    jaw = path("M8 34 Q10 12 32 10 Q54 12 56 34 Q44 26 32 26 Q20 26 8 34 Z", "#3A2A55") + path("M8 38 Q20 56 32 56 Q44 56 56 38 Q44 44 32 44 Q20 44 8 38 Z", "#3A2A55")
    teeth = "".join(path(f"M{x} 27 L{x + 3} 35 L{x + 6} 27 Z", BONE_L, sw=1.5) for x in (14, 22, 30, 38, 46))
    teeth += "".join(path(f"M{x} 43 L{x + 3} 35 L{x + 6} 43 Z", BONE_L, sw=1.5) for x in (18, 26, 34, 42))
    return svg(jaw + teeth + circle(32, 35, 4, RIFT_L, stroke=False) + rift_cracks("M22 14 L28 20"))


def gloom_spit():
    return svg(path("M10 40 Q24 28 40 30 Q30 34 28 40 Z", "#5A4A7A", sw=2) + circle(42, 34, 12, "#3E3368")
               + circle(38, 30, 3, RIFT_L, stroke=False) + circle(20, 48, 5, "#3E3368") + circle(12, 54, 3, "#3E3368")
               + circle(54, 50, 4, "#5A4A7A"))


def pack_bond():
    collar = f'<circle cx="32" cy="32" r="20" fill="none" stroke="{INK}" stroke-width="12"/>' + f'<circle cx="32" cy="32" r="20" fill="none" stroke="#4A3470" stroke-width="7"/>'
    spikes = "".join(group(path("M32 6 L36 14 L28 14 Z", BONE_L, sw=2), f"rotate({a} 32 32)") for a in range(0, 360, 60))
    tag = circle(32, 54, 6, RIFT_L) + path("M30 52 L34 52 L32 56 Z", RIFT_D, stroke=False)
    return svg(spikes + collar + tag)


def ember_maw():
    base = hollow_maw().replace("#3A2A55", "#55525E").replace(RIFT_L, FLAME_Y).replace(RIFT, EMBER)
    return base.replace("</svg>", flame(32, 40, 0.35) + "</svg>")


def birch_shortbow():
    return bow("#E6E0D6", "#A89F90", accent=INK, long=22)


def flint_arrows():
    arrows = ""
    for dx, rot in ((-8, -12), (0, 0), (8, 12)):
        arrows += group(line("M32 58 L32 16", OAK, 3) + path("M32 6 L37 16 L27 16 Z", SLATE, sw=2)
                        + path("M28 56 L32 50 L36 56 L32 60 Z", BLOOD, sw=1.5), f"translate({dx} 0) rotate({rot} 32 58)")
    return svg(arrows + rect(24, 42, 16, 16, OAK_D, 2))


def thorn_darts():
    darts = ""
    for y, x in ((18, 10), (32, 16), (46, 10)):
        darts += line(f"M{x} {y} L{x + 36} {y}", MOSS_D, 3) + path(f"M{x + 36} {y - 4} L{x + 46} {y} L{x + 36} {y + 4} Z", "#6A4B50", sw=2)
        darts += path(f"M{x} {y - 4} L{x + 6} {y} L{x} {y + 4} Z", MOSS, sw=1.5)
    return svg(darts)


def hatchet():
    return svg(group(line("M32 60 L32 10", INK, 8) + line("M32 60 L32 10", OAK, 4.5)
                     + path("M30 8 Q54 4 56 26 Q44 22 30 24 Z", STEEL) + line("M34 10 Q50 8 52 20", STEEL_L, 2), "rotate(-30 32 32)"))


def longspear():
    return spear(STEEL, OAK, length=56, tassel=RED_CLOTH)


def mudbrick_wall():
    bricks = ""
    for row, y in enumerate((12, 25, 38)):
        off = 0 if row % 2 == 0 else -10
        for x in range(off + 6, 58, 20):
            bricks += rect(max(x, 6), y, min(18, 58 - max(x, 6)), 12, "#A07850" if (x + row) % 3 else "#8A6440", 1.5)
    return svg(bricks + rect(4, 50, 56, 8, OAK_D, 2) + circle(20, 44, 2, MOSS, stroke=False))


def crow_crossbow():
    return crossbow("#3A2A2E", "#2A2230")


def hunters_snare():
    loop = f'<ellipse cx="30" cy="40" rx="20" ry="10" fill="none" stroke="{INK}" stroke-width="6"/>' + '<ellipse cx="30" cy="40" rx="20" ry="10" fill="none" stroke="#C9A870" stroke-width="3"/>'
    stake = path("M48 18 L54 18 L52 52 L50 52 Z", OAK) + line("M50 20 Q40 30 46 36", "#C9A870", 3)
    return svg(loop + stake + path("M14 36 L20 40 L14 44 Z", "#C9A870", sw=1.5))


def barbed_net():
    web = "".join(line(f"M{x} 8 L{x + 10} 56", "#9A8A6A", 2.5) for x in (8, 20, 32, 44))
    web += "".join(line(f"M6 {y} L58 {y + 8}", "#9A8A6A", 2.5) for y in (12, 26, 40))
    barbs = "".join(path(f"M{x} {y} L{x + 4} {y - 4} L{x + 6} {y + 2} Z", STEEL, sw=1.5) for x, y in ((14, 18), (38, 22), (24, 36), (48, 44), (12, 50)))
    return svg(path("M4 8 L60 8 L56 58 L8 58 Z", "#2A2433", stroke=False, extra=' opacity="0.25"') + web + barbs)


def menders_satchel():
    bag = rect(8, 22, 48, 34, "#8A5A3C", 8) + path("M8 30 Q32 40 56 30 L56 24 Q56 22 48 22 L16 22 Q8 22 8 24 Z", "#6E4A33")
    strap = line("M14 22 Q32 0 50 22", INK, 6) + line("M14 22 Q32 0 50 22", OAK_L, 3)
    cross = rect(28, 38, 8, 16, PARCH, 1.5) + rect(24, 42, 16, 8, PARCH, 1.5) + rect(29.5, 39.5, 5, 13, BLOOD, 0, stroke=False) + rect(25.5, 43.5, 13, 5, BLOOD, 0, stroke=False)
    return svg(strap + bag + cross + circle(32, 32, 2.5, BRASS))


def ashwood_staff():
    staff = line("M18 60 L40 8", INK, 8) + line("M18 60 L40 8", "#8A8078", 4.5) + line("M24 46 L30 32", "#B0A89E", 1.5)
    crook = path("M38 6 Q52 2 52 14 Q50 22 42 20", "none", stroke=False, extra=f' stroke="{INK}" stroke-width="8" stroke-linecap="round"') + path("M38 6 Q52 2 52 14 Q50 22 42 20", "none", stroke=False, extra=' stroke="#8A8078" stroke-width="4.5" stroke-linecap="round"')
    return svg(staff + crook + circle(46, 13, 4, EMBER) + circle(46, 13, 7, EMBER, stroke=False, extra=' opacity="0.3"'))


def bramble_mail():
    plate = path("M8 44 Q10 16 34 14 Q56 14 58 36 L58 44 Q40 34 8 44 Z", STEEL) + path("M12 42 Q22 34 40 34", "none", sw=0)
    spikes = "".join(path(f"M{x} {y} L{x + dx} {y - 14} L{x + 7} {y} Z", STEEL_L, sw=2) for x, y, dx in ((16, 24, -2), (28, 17, 1), (42, 18, 5)))
    return svg(spikes + plate + line("M12 40 Q30 30 56 38", STEEL_D, 3) + circle(22, 34, 2, BRASS, stroke=False) + circle(46, 32, 2, BRASS, stroke=False))


def greywood_warbow():
    return bow("#7A7686", "#4A4756", accent=BRASS, long=28)


def stormglass_arrowheads():
    heads = ""
    for x, y, rot in ((18, 30, -20), (32, 22, 0), (46, 30, 20)):
        heads += group(path(f"M{x} {y - 14} L{x + 7} {y + 4} L{x} {y + 10} L{x - 7} {y + 4} Z", "#C4D8F0") + line(f"M{x} {y - 10} L{x} {y + 6}", "#FFFFFF", 1.5), f"rotate({rot} {x} {y})")
    return svg(heads + path("M28 44 L34 50 L30 50 L36 58 L26 48 L30 48 Z", STORM, sw=1.5))


def venom_censer():
    return censer("#5E7A3A", "#3E5A24", VENOM_L, VENOM)


def gatekeepers_pavise():
    q = (path("M32 10 L32 33 L10 33 L10 14 Z", RED_CLOTH, stroke=False) + path("M32 33 L54 33 Q52 48 32 58 Z", RED_CLOTH, stroke=False)
         + path("M32 10 L54 14 L54 33 L32 33 Z", PARCH, stroke=False) + path("M10 33 L32 33 L32 58 Q12 48 10 33 Z", PARCH, stroke=False))
    return kite_shield("#D9C79E", BRASS, q + line("M32 8 L32 58", BRASS, 3) + line("M9 33 L55 33", BRASS, 3))


def reapers_sickle():
    blade = path("M20 12 Q54 4 56 34 Q46 18 22 20 Z", STEEL) + line("M24 14 Q48 8 52 26", STEEL_L, 2)
    return svg(line("M18 58 L22 14", INK, 8) + line("M18 58 L22 14", "#4A3438", 4.5) + blade + rect(16, 50, 8, 8, BONE, 2))


def grimoire_of_cinders():
    emblem = flame(30, 38, 0.72) + circle(40, 18, 2, FLAME_Y, stroke=False)
    return book("#6A2A22", "#4A1E18", emblem)


def rimewood_longbow():
    return bow("#9FC8D8", FROST_D, string="#E6F4FA", accent=FROST_L, long=28)


def tower_shield():
    body = path("M12 6 L52 6 L52 44 Q32 62 12 44 Z", SLATE) + rect(16, 10, 32, 34, "none", 2)
    return svg(body + line("M32 8 L32 56", SLATE_D, 4) + line("M14 26 L50 26", SLATE_D, 4) + circle(32, 26, 6, BRASS)
               + line("M16 12 L16 28", SLATE_L, 2.5) + "".join(circle(x, y, 1.8, BRASS_L, stroke=False) for x, y in ((18, 12), (46, 12), (18, 40), (46, 40))))


def ashen_censer():
    return censer("#6B6875", "#45424E", "#9C99A6", EMBER)


def twinfang_stilettos():
    one = knife("#D6DCE1", "#FFFFFF", "#4A3470", RIFT_D, long=34, width=8)
    return svg(group(one, "rotate(-25 32 34) translate(-4 0)") + group(one, "rotate(25 32 34) translate(4 0)") + circle(32, 50, 3, RIFT_L, stroke=False))


def clockwork_owl():
    body = ellipse(32, 38, 18, 20, BRASS) + path("M16 22 L22 10 L28 20 Z", BRASS_D) + path("M48 22 L42 10 L36 20 Z", BRASS_D)
    eyes = circle(25, 32, 7, STEEL_L) + circle(39, 32, 7, STEEL_L) + circle(25, 32, 3, INK, stroke=False) + circle(39, 32, 3, INK, stroke=False)
    gear = circle(32, 48, 6, BRASS_D) + circle(32, 48, 2, INK, stroke=False) + path("M30 38 L34 38 L32 42 Z", EMBER, sw=1.5)
    return svg(body + eyes + gear + rect(20, 56, 24, 4, OAK_D, 1.5))


def wyrdglass_orb():
    return svg(ellipse(32, 56, 16, 5, OAK_D) + circle(32, 32, 22, "#7A4FD1") + circle(32, 32, 22, "#B79CF0", stroke=False, extra=' opacity="0.35"')
               + path("M22 30 Q32 18 42 30 Q32 42 22 30 Z", "#E0C8FF", sw=0) + circle(32, 30, 5, "#FFFFFF", stroke=False)
               + line("M16 24 Q20 14 30 12", "#FFFFFF", 3) + f'<circle cx="32" cy="32" r="22" fill="none" stroke="{INK}" stroke-width="3"/>')


def hearthkeepers_kettle():
    body = path("M12 30 Q10 56 32 56 Q54 56 52 30 Z", "#4A4756") + ellipse(32, 30, 20, 6, "#5E5A68")
    spout = path("M50 36 L60 26 L62 30 L54 42 Z", "#4A4756", sw=2.5)
    handle = line("M18 24 Q32 6 46 24", INK, 6) + line("M18 24 Q32 6 46 24", OAK, 3)
    steam = line("M60 20 Q56 14 60 8", PARCH, 3)
    return svg(handle + body + spout + steam + flame(32, 50, 0.35) + line("M16 36 Q18 46 24 50", "#8A8698", 2.5))


def cinder_dust():
    pile = path("M8 56 Q18 36 32 34 Q46 36 56 56 Z", "#55525E")
    motes = "".join(circle(x, y, r, c, stroke=False) for x, y, r, c in ((20, 28, 3, EMBER), (32, 20, 4, FLAME_Y), (44, 26, 3, EMBER), (26, 12, 2, FLAME_Y), (40, 10, 2.5, EMBER)))
    return svg(pile + motes + circle(28, 46, 3, EMBER, stroke=False) + circle(38, 48, 2.5, FLAME_Y, stroke=False))


def lurker_fang():
    fang = path("M20 8 Q44 6 46 16 Q40 40 30 58 Q26 36 20 8 Z", BONE_L) + line("M26 14 Q34 30 30 48", BONE_D, 2)
    slime = path("M30 56 Q26 62 32 62 Q36 60 30 56 Z", "#6B7A48", sw=1.5)
    return svg(fang + slime + rect(18, 6, 30, 6, "#4A5A34", 2))


def cairn_stone():
    return svg(ellipse(32, 52, 22, 8, SLATE) + ellipse(32, 38, 17, 8, "#7A7686") + ellipse(32, 25, 12, 7, SLATE) + ellipse(32, 14, 7, 5, "#7A7686")
               + line("M28 36 L34 40 L30 44", FROST, 2) + circle(32, 25, 2.5, FROST_L, stroke=False))


# --- Legendaries (docs/plans/legendary-items.md) ----------------------------------

def _with(svg_text, extra):
    """An icon from a shared shape, with extra marks drawn on top."""
    return svg_text.replace("</svg>", extra + "</svg>")


def tallymans_bow():
    # A longbow notched with tally marks: it counts every hit.
    tallies = "".join(line(f"M{x} 50 L{x + 3} 60", BONE_L, 2.5) for x in (38, 43, 48, 53)) + line("M36 58 L57 51", BLOOD, 2.5)
    return _with(bow(OAK, OAK_D, accent=BRASS, rot=-40, long=27), tallies)


def hungering_censer():
    # A censer whose vents glow like a hungry mouth.
    teeth = path("M22 30 L25 35 L28 30 L31 35 L34 30 L37 35 L40 30 L43 35 L44 30 Z", BONE_L, sw=1.5)
    return _with(censer(SLATE, SLATE_D, RIFT_L, EMBER), teeth + circle(54, 8, 3, EMBER, stroke=False))


def maw_of_the_hollow():
    # A crescent blade lined with fangs, on a dark grip.
    blade = path("M12 44 Q14 12 46 8 Q30 20 30 36 Q30 46 36 52 Q20 54 12 44 Z", SLATE_D)
    fangs = "".join(path(f"M{x} {y} L{x + 5} {y + 1} L{x + 1} {y + 7} Z", BONE_L, sw=1.5) for (x, y) in ((28, 16), (25, 24), (24, 32), (25, 40)))
    grip = line("M36 52 L54 58", INK, 8) + line("M36 52 L54 58", OAK_D, 4) + circle(56, 58, 3, RIFT_L)
    return svg(blade + fangs + grip + line("M16 38 Q18 22 34 14", RIFT_L, 2))


def kinstone_aegis():
    # A kite shield set with two linked stones: bound to its holder.
    stones = (f'<circle cx="27" cy="30" r="7" fill="none" stroke="{BRASS_L}" stroke-width="3"/>'
              + f'<circle cx="37" cy="30" r="7" fill="none" stroke="{BRASS_L}" stroke-width="3"/>'
              + circle(27, 30, 3.5, FROST_L, stroke=False) + circle(37, 30, 3.5, EMBER, stroke=False))
    return kite_shield(SLATE, BRASS, stones)


def last_hearth_lantern():
    # A small iron lantern whose flame outlives its keeper.
    handle = line("M26 10 Q32 1 38 10", INK, 6) + line("M26 10 Q32 1 38 10", STEEL_L, 3)
    body = path("M20 16 L44 16 L40 9 L24 9 Z", SLATE_D) + rect(20, 16, 24, 28, OAK_D, 2)
    glass = '<rect x="23" y="19" width="18" height="22" rx="2" fill="#F2C14E" opacity="0.85"/>'
    return svg(handle + body + glass + flame(32, 38, 0.7) + line("M26 16 L26 44", INK, 2.5) + line("M38 16 L38 44", INK, 2.5)
               + path("M17 44 L47 44 L44 54 L20 54 Z", SLATE_D) + circle(48, 22, 2, EMBER, stroke=False))


def riftbreakers_brand():
    # A long blade split by rift light: forged in boss fights.
    blade = group(knife(STEEL_D, STEEL_L, "#3A3040", INK, long=40, width=11), "rotate(35 32 32)")
    return svg(blade + rift_cracks("M26 20 L31 26 L28 31", "M34 30 L38 35"))


LEGENDARIES = {
    "tallymans_bow": tallymans_bow, "hungering_censer": hungering_censer, "maw_of_the_hollow": maw_of_the_hollow,
    "kinstone_aegis": kinstone_aegis, "last_hearth_lantern": last_hearth_lantern, "riftbreakers_brand": riftbreakers_brand,
}

MORE_ITEMS = {
    "night_lantern": night_lantern, "grave_hook": grave_hook, "smokeglass_vial": smokeglass_vial,
    "war_drum": war_drum, "vespers_bell": vespers_bell, "old_guards_standard": old_guards_standard, "gale_blades": gale_blades, "vesper_chime": vesper_chime, "hollow_maw": hollow_maw,
    "gloom_spit": gloom_spit, "pack_bond": pack_bond, "ember_maw": ember_maw, "birch_shortbow": birch_shortbow,
    "flint_arrows": flint_arrows, "thorn_darts": thorn_darts,
    "hatchet": hatchet, "longspear": longspear,
    "mudbrick_wall": mudbrick_wall, "crow_crossbow": crow_crossbow, "hunters_snare": hunters_snare,
    "barbed_net": barbed_net, "menders_satchel": menders_satchel, "ashwood_staff": ashwood_staff,
    "bramble_mail": bramble_mail, "greywood_warbow": greywood_warbow, "stormglass_arrowheads": stormglass_arrowheads, "venom_censer": venom_censer, "gatekeepers_pavise": gatekeepers_pavise, "reapers_sickle": reapers_sickle, "grimoire_of_cinders": grimoire_of_cinders,
    "rimewood_longbow": rimewood_longbow, "tower_shield": tower_shield, "ashen_censer": ashen_censer,
    "twinfang_stilettos": twinfang_stilettos, "clockwork_owl": clockwork_owl, "wyrdglass_orb": wyrdglass_orb,
    "hearthkeepers_kettle": hearthkeepers_kettle, "cinder_dust": cinder_dust, "lurker_fang": lurker_fang, "cairn_stone": cairn_stone,
}


# --- relics (drawn inside the hex token, so kept central) -------------------------------

def rsvg(body):
    return svg(group(body, "translate(32 32) scale(0.82) translate(-32 -32)"))


def warding_knot():
    knot = "".join(f'<ellipse cx="32" cy="32" rx="20" ry="9" fill="none" stroke="{INK}" stroke-width="8" transform="rotate({a} 32 32)"/>'
                   f'<ellipse cx="32" cy="32" rx="20" ry="9" fill="none" stroke="{FROST}" stroke-width="4" transform="rotate({a} 32 32)"/>' for a in (0, 60, 120))
    return rsvg(knot + circle(32, 32, 4, FROST_L))


def tinkers_loupe():
    return rsvg(f'<circle cx="28" cy="28" r="16" fill="#C4ECF4" stroke="{INK}" stroke-width="3"/>' + f'<circle cx="28" cy="28" r="16" fill="none" stroke="{BRASS}" stroke-width="4"/>'
                + line("M40 40 L56 56", INK, 8) + line("M40 40 L56 56", OAK, 4) + line("M20 20 Q24 16 30 16", "#FFFFFF", 2.5))


def kindled_seal():
    return rsvg(circle(32, 34, 20, BLOOD) + "".join(circle(32 + 20 * c, 34 + 20 * s, 5, BLOOD) for c, s in ((0.9, 0.4), (-0.8, 0.6), (0.2, -0.95), (-0.6, -0.8)))
                + flame(32, 44, 0.55))


def emberglass():
    return rsvg(path("M32 6 L50 24 L44 54 L20 54 L14 24 Z", "#E0703A") + path("M32 6 L50 24 L32 30 L14 24 Z", "#F4A070", stroke=False)
                + path("M32 6 L50 24 L44 54 L20 54 L14 24 Z", "none") + circle(32, 38, 5, FLAME_Y, stroke=False))


def vanguard_banner():
    return rsvg(line("M16 6 L16 60", INK, 6) + line("M16 6 L16 60", OAK, 3) + path("M18 10 L54 16 L46 26 L54 36 L18 40 Z", "#3E5A7A")
                + path("M26 18 L38 24 L26 32 Z", BRASS, sw=2))


def _hourglass(sand):
    return (rect(14, 6, 36, 6, OAK, 2) + rect(14, 52, 36, 6, OAK, 2)
            + path("M18 12 L46 12 Q46 26 32 32 Q46 38 46 52 L18 52 Q18 38 32 32 Q18 26 18 12 Z", "#D9E8F0")
            + path("M22 48 L32 38 L42 48 Z", sand, stroke=False) + path("M24 16 L40 16 L32 26 Z", sand, stroke=False))


def hourglass_relic():
    return rsvg(_hourglass(BRASS_L))


def frostbound_sigil():
    flake = "".join(line(d, INK, 7) + line(d, FROST_L, 3.5) for d in ("M32 8 L32 56", "M11 20 L53 44", "M11 44 L53 20"))
    return rsvg(circle(32, 32, 24, "#2F5F75") + flake + circle(32, 32, 5, "#FFFFFF"))


def pilgrims_flask():
    return rsvg(bottle("#6E9AD0", "#C4DCF4", glass="#D9E8F0", cork=OAK_L, round_=False) + line("M16 30 Q8 34 10 44", "#8A6A40", 3))


def _crown(gem, side):
    return (path("M8 50 L10 20 L22 34 L32 12 L42 34 L54 20 L56 50 Z", "#55525E") + rect(8, 46, 48, 10, "#45424E", 2)
            + circle(32, 22, 4, gem) + circle(14, 26, 3, side) + circle(50, 26, 3, side) + circle(32, 51, 3, gem, stroke=False))


def cinder_crown():
    return rsvg(_crown(EMBER, FLAME_Y))


def gloam_totem():
    return rsvg(rect(20, 8, 24, 50, "#3E3368", 4) + path("M14 10 L50 10 L44 18 L20 18 Z", "#5A3E8C")
                + circle(27, 28, 3, VENOM, stroke=False) + circle(37, 28, 3, VENOM, stroke=False) + line("M26 38 L38 38", VENOM, 2.5)
                + line("M24 48 L40 48", "#5A3E8C", 3))


def ashen_crown():
    return rsvg(_crown(RIFT_L, RIFT_L) + rift_cracks("M16 44 L22 38", "M44 38 L50 44"))


def undying_lantern():
    return rsvg(line("M26 10 Q32 1 38 10", INK, 6) + line("M26 10 Q32 1 38 10", BRASS_L, 3) + path("M18 16 L46 16 L42 9 L22 9 Z", BRASS)
                + rect(18, 16, 28, 30, "#F6C667", 2) + flame(32, 40, 0.75) + path("M15 46 L49 46 L46 56 L18 56 Z", BRASS)
                + rift_cracks("M20 20 L24 28", "M44 24 L40 30"))


def everflame_hourglass():
    return rsvg(_hourglass(EMBER) + flame(32, 50, 0.3) + rift_cracks("M16 34 L22 30"))


def rift_eaters_fang():
    return rsvg(path("M24 6 Q48 4 48 14 Q42 38 32 60 Q28 36 24 6 Z", "#E0C8FF") + line("M30 12 Q38 30 33 50", RIFT, 2.5)
                + rift_cracks("M40 18 L46 24", "M20 20 L26 24") + circle(36, 10, 3, RIFT, stroke=False))


def fletchers_quiver():
    return rsvg(path("M18 16 L46 10 L50 52 L22 58 Z", "#6E4A33") + line("M20 24 L48 18", BRASS, 3)
                + "".join(line(f"M{x} {y} L{x - 2} {y - 14}", OAK, 3) + path(f"M{x - 5} {y - 14} L{x - 2} {y - 20} L{x + 1} {y - 14} Z", BLOOD, sw=1.5) for x, y in ((26, 16), (34, 14), (42, 12))))


def rootbound_charm():
    return rsvg(circle(32, 34, 16, MOSS) + "".join(line(d, INK, 6) + line(d, OAK, 3) for d in ("M32 18 Q20 8 12 12", "M32 18 Q44 6 54 10", "M22 46 Q14 54 10 58", "M42 46 Q50 54 56 58"))
                + path("M32 26 Q40 34 32 42 Q24 34 32 26 Z", "#A8D08C", sw=2))


def tinkers_mainspring():
    teeth = "".join(group(rect(28, 6, 8, 10, BRASS, 1.5), f"rotate({a} 32 32)") for a in range(0, 360, 45))
    coil = (f'<circle cx="32" cy="32" r="11" fill="none" stroke="{BRASS_D}" stroke-width="3"/>'
            + f'<circle cx="32" cy="32" r="6" fill="none" stroke="{BRASS_D}" stroke-width="2.5"/>')
    return rsvg(teeth + circle(32, 32, 20, BRASS) + coil + circle(32, 32, 2.5, INK, stroke=False) + line("M18 22 Q22 16 28 14", BRASS_L, 2.5))


def adders_vial():
    snake = line("M14 52 Q8 40 18 36 Q28 32 22 22 Q18 14 26 10", INK, 7) + line("M14 52 Q8 40 18 36 Q28 32 22 22 Q18 14 26 10", "#6B8A3A", 3.5) + circle(27, 10, 3, "#6B8A3A")
    return rsvg(group(bottle(VENOM, VENOM_L), "translate(8 0)") + snake)


def mourning_bell():
    return rsvg(bell(SLATE, SLATE_D, clapper=RIFT_L) + line("M10 22 Q6 30 10 38", RIFT_L, 2) + line("M54 22 Q58 30 54 38", RIFT_L, 2))


def thiefs_glove():
    return rsvg(path("M16 58 L16 30 Q16 24 20 24 L20 12 Q20 8 24 8 Q28 8 28 12 L28 20 L30 8 Q30 4 34 4 Q38 4 38 8 L38 22 L40 12 Q40 8 44 8 Q48 8 48 12 L48 40 Q48 52 40 58 Z", "#3A3040")
                + line("M16 50 L46 50", "#5A4A60", 3) + circle(52, 18, 5, BRASS) + path("M50 16 L54 16 L52 20 Z", BRASS_D, stroke=False))


RELICS = {
    "warding_knot": warding_knot, "tinkers_loupe": tinkers_loupe, "kindled_seal": kindled_seal, "emberglass": emberglass,
    "vanguard_banner": vanguard_banner, "hourglass": hourglass_relic, "frostbound_sigil": frostbound_sigil,
    "pilgrims_flask": pilgrims_flask, "cinder_crown": cinder_crown, "gloam_totem": gloam_totem, "ashen_crown": ashen_crown,
    "undying_lantern": undying_lantern, "everflame_hourglass": everflame_hourglass, "rift_eaters_fang": rift_eaters_fang,
    "fletchers_quiver": fletchers_quiver, "rootbound_charm": rootbound_charm, "tinkers_mainspring": tinkers_mainspring,
    "adders_vial": adders_vial, "mourning_bell": mourning_bell, "thiefs_glove": thiefs_glove,
}

MORE_ITEMS |= LEGENDARIES


# --- redesign step 5: conduits and event passives ---------------------------------

def ember_censer():
    return censer(BRASS, BRASS_D, SLATE_L, EMBER)


def open_channel():
    swirl = line("M24 26 Q32 18 40 26 Q46 34 36 40 Q28 44 26 36 Q26 30 32 30", RIFT_L, 3)
    return book(RIFT_D, RIFT, circle(33, 32, 12, "#2E2450") + swirl)


def bond_chain():
    links = "".join(group(ellipse(0, 0, 11, 6, "none", sw=5) + ellipse(0, 0, 11, 6, "none", stroke=False, extra=f' stroke="{STEEL_L}" stroke-width="2.5"'),
                          f"translate({x} {y}) rotate({r})") for x, y, r in ((16, 44, -40), (27, 33, 50), (38, 22, -40), (49, 11, 50)))
    return svg(links)


def rift_prism():
    return svg(path("M32 6 L54 52 L10 52 Z", "#D8C8F8") + path("M32 6 L40 52 L10 52 Z", "#B79CF0", stroke=False)
               + path("M32 6 L54 52 L10 52 Z", "none") + line("M4 30 L22 30", PARCH, 3)
               + line("M42 30 L60 22", EMBER, 3) + line("M42 34 L60 34", FROST, 3) + line("M42 38 L60 46", VENOM, 3)
               + rift_cracks("M28 42 L34 36"))


def thorn_vest():
    thorns = "".join(path(f"M{x} {y} L{x + dx} {y + dy} L{x + 3} {y + 3} Z", MOSS_D, sw=2) for x, y, dx, dy in
                     ((10, 22, -6, -2), (10, 36, -6, 2), (54, 22, 6, -2), (54, 36, 6, 2), (26, 54, -2, 6), (38, 54, 2, 6)))
    body = path("M20 6 L26 10 L38 10 L44 6 L54 16 L50 26 L50 56 L14 56 L14 26 L10 16 Z", OAK)
    return svg(thorns + body + line("M32 12 L32 56", OAK_D, 2.5) + circle(32, 24, 2.5, BRASS) + circle(32, 36, 2.5, BRASS))


def leech_vial():
    leech = line("M22 44 Q28 38 34 44 Q40 50 44 44", INK, 6) + line("M22 44 Q28 38 34 44 Q40 50 44 44", "#3A1E24", 3.5)
    return svg(bottle(BLOOD, "#E07A70", label=leech))


def hex_bag():
    bag = path("M18 26 Q10 56 32 58 Q54 56 46 26 Z", "#5A3E8C") + path("M20 26 L44 26 L40 18 L24 18 Z", "#4A3278")
    tie = line("M22 24 L42 24", BONE, 3) + path("M30 22 L22 12 L32 18 L42 12 L34 22 Z", MOSS, sw=2)
    rune = line("M26 36 L38 48 M38 36 L26 48", VENOM_L, 3) + circle(32, 42, 7, "none", stroke=False, extra=f' stroke="{VENOM}" stroke-width="2"')
    return svg(bag + tie + rune)


MORE_ITEMS |= {
    "ember_censer": ember_censer, "open_channel": open_channel, "bond_chain": bond_chain, "rift_prism": rift_prism, "thorn_vest": thorn_vest, "leech_vial": leech_vial, "hex_bag": hex_bag,
}


# --- redesign step 7: hero Epics (docs/plans/items-and-clarity.md) -------------------------

def hearthbrand_mace():
    handle = line("M16 58 L36 22", INK, 8) + line("M16 58 L36 22", OAK, 4.5)
    head = circle(40, 16, 12, STEEL) + "".join(path(f"M{40 + dx} {16 + dy} L{40 + dx * 1.7} {16 + dy * 1.7} L{40 + dx + dy * 0.3} {16 + dy - dx * 0.3} Z", STEEL_L, sw=2)
                                              for dx, dy in ((10, 0), (0, -10), (-10, 0), (0, 10), (7, 7), (-7, -7)))
    return svg(handle + head + flame(40, 20, 0.35) + rect(14, 52, 8, 8, BRASS, 2))


def watchmans_horn():
    horn = path("M8 44 Q24 50 40 36 Q50 26 52 12 L60 16 Q58 34 44 46 Q28 58 8 52 Z", BONE) + path("M52 12 L60 16 L58 22 L50 18 Z", BRASS, sw=2)
    bands = line("M20 48 Q22 52 20 54", BRASS_D, 3) + line("M36 40 Q40 44 38 48", BRASS_D, 3)
    return svg(horn + bands + line("M6 44 L6 52", INK, 3) + line("M2 18 Q8 12 14 18", PARCH, 2) + line("M4 26 Q10 20 16 26", PARCH, 2))


def hunters_moon():
    moon = path("M40 6 A20 20 0 1 0 58 34 A15 15 0 1 1 40 6 Z", "#E8E0C8")
    blade = group(knife(STEEL_L, "#FFFFFF", "#4A3438", INK, long=30, width=10), "rotate(-30 26 38)")
    return svg(moon + blade + circle(18, 50, 3, BLOOD, stroke=False) + circle(24, 56, 2, BLOOD, stroke=False))


def ember_grimoire():
    return book("#7A2E20", "#4A1A12", flame(30, 40, 0.8) + circle(40, 16, 2.5, FLAME_Y, stroke=False) + circle(20, 18, 2, EMBER, stroke=False))


def hexbinders_rod():
    rod = line("M16 60 L42 12", INK, 8) + line("M16 60 L42 12", "#3E3368", 4.5)
    orb = circle(44, 10, 7, VENOM) + circle(44, 10, 11, VENOM, stroke=False, extra=' opacity="0.25"') + circle(42, 8, 2, VENOM_L, stroke=False)
    runes = line("M24 44 L28 40 M27 46 L31 42", RIFT_L, 2)
    return svg(rod + runes + orb)


def bramble_snares():
    loop = f'<ellipse cx="32" cy="40" rx="22" ry="12" fill="none" stroke="{INK}" stroke-width="7"/>' + f'<ellipse cx="32" cy="40" rx="22" ry="12" fill="none" stroke="{MOSS}" stroke-width="3.5"/>'
    thorns = "".join(path(f"M{x} {y} L{x + dx} {y - 8} L{x + 4} {y} Z", MOSS_D, sw=1.5) for x, y, dx in ((12, 34, -3), (24, 29, 0), (38, 29, 2), (50, 34, 4)))
    stake = line("M32 6 L32 28", INK, 6) + line("M32 6 L32 28", OAK, 3)
    return svg(stake + loop + thorns + circle(20, 50, 2.5, BLOOD, stroke=False))


def stormfeather_quiver():
    quiver = path("M18 20 L44 12 L50 52 L26 58 Z", "#6E4A33") + line("M20 28 L46 20", BRASS, 3)
    arrows = "".join(line(f"M{x} {y} L{x + 4} {y - 16}", OAK_L, 2.5) + path(f"M{x + 2} {y - 22} L{x + 8} {y - 16} L{x + 1} {y - 13} Z", STORM, sw=1.5)
                     for x, y in ((22, 22), (30, 19), (38, 17)))
    bolt = path("M34 34 L40 40 L36 40 L42 50 L30 38 L34 38 Z", STORM, sw=1.5)
    return svg(arrows + quiver + bolt)


def cutpurses_kris():
    blade = group(knife("#C8C0D8", "#FFFFFF", "#3E3368", INK, long=34, width=9), "rotate(30 32 32)")
    coin = circle(48, 48, 7, BRASS) + circle(48, 48, 4, BRASS_D, stroke=False)
    return svg(blade + coin + line("M10 12 Q14 8 18 12", RIFT_L, 2))


def heartfire_wand():
    wand = line("M16 58 L40 18", INK, 7) + line("M16 58 L40 18", "#8A5A3C", 4) + rect(18, 48, 6, 8, BRASS, 2)
    heart = path("M42 18 Q42 8 50 10 Q58 12 52 22 L44 30 Q34 22 36 14 Q40 8 42 18 Z", EMBER)
    return svg(wand + heart + flame(46, 14, 0.35) + circle(56, 6, 2, FLAME_Y, stroke=False))


MORE_ITEMS |= {
    "hearthbrand_mace": hearthbrand_mace, "watchmans_horn": watchmans_horn, "hunters_moon": hunters_moon,
    "ember_grimoire": ember_grimoire, "hexbinders_rod": hexbinders_rod, "bramble_snares": bramble_snares,
    "stormfeather_quiver": stormfeather_quiver, "cutpurses_kris": cutpurses_kris, "heartfire_wand": heartfire_wand,
}
