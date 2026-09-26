#!/usr/bin/env python3
"""Writes the character art (docs/plans/ui-overhaul.md, sections 4 and 5).

For each hero and enemy id, into art/ui/characters/:
  <id>_body.svg      the figure without what it holds (128x160 canvas,
                     facing right, feet at y=150)
  <id>_held.svg      what it holds (weapon, shield, lantern...), on the same
                     canvas, so it can swing around the hand; absent for
                     beasts, which bite and claw with their whole body
  <id>_portrait.svg  head and shoulders in a round frame (96x96)
and rig.json: each id's hand point (the held layer's pivot) and whether
it's a beast.

Same look as the item icons: bold shapes, ink outline, flat fills with one
shade and one highlight, light from the top left. Heroes are warm and
cozy; rift creatures are violet-black with glowing eyes and cracks.

Run from the repo root:  python3 tools/art/characters.py
then `godot --headless --import`, then this script once more (it sets the
import settings: 2x with mipmaps).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from item_icons import (  # noqa: E402
    INK, OAK_D, OAK, OAK_L, BRASS_D, BRASS, BRASS_L, STEEL_D, STEEL, STEEL_L, BONE_D, BONE, BONE_L, PARCH,
    EMBER, FLAME_Y, FROST, FROST_L, MOSS_D, MOSS, RIFT_D, RIFT, RIFT_L, BLOOD, SLATE_D, SLATE, SLATE_L,
    path, line, circle, rect, group, flame,
)
from ui_art import fix_imports  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "art" / "ui" / "characters"
W, H = 128, 160
HAND = (88, 108)

SKIN, SKIN_D = "#F0C8A0", "#D9A57C"
SKIN_OLD = "#E2B894"
CLASS_RING = {"warden": "#C98B4A", "striker": "#D65A4A", "mender": "#8DBF76", "arcanist": "#9B6FE0",
              "ranger": "#6FAE6A", "trickster": "#D6A24A", "enemy": "#7A3B4A"}


def canvas(body: str, w: int = W, h: int = H) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            + body + "</svg>\n")


def ellipse(cx: float, cy: float, rx: float, ry: float, fill: str, stroke: bool = True, extra: str = "") -> str:
    s = f' stroke="{INK}" stroke-width="3"' if stroke else ""
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}"{s}{extra}/>'


def shadow() -> str:
    return ellipse(64, 151, 30, 6, "#000000", stroke=False, extra=' opacity="0.25"')


# --- humanoid parts -------------------------------------------------------------

def legs(color: str, boots: str) -> str:
    return (rect(50, 118, 11, 26, color, 3) + rect(67, 118, 11, 26, color, 3)
            + path("M47 142 L62 142 L63 150 L46 150 Z", boots) + path("M66 142 L81 142 L84 150 L65 150 Z", boots))


def torso(color: str, shade: str, wide: float = 0) -> str:
    return (path(f"M{42 - wide} 90 Q64 80 {86 + wide} 90 L{84 + wide} 124 Q64 130 {44 - wide} 124 Z", color)
            + path(f"M{74 + wide} 92 Q{84 + wide} 94 {84 + wide} 104 L{83 + wide} 122 Q76 126 70 126 Z", shade, stroke=False, extra=' opacity="0.5"'))


def back_arm(color: str, skin: str = SKIN) -> str:
    return ellipse(42, 104, 8, 14, color) + circle(41, 118, 6, skin)


def front_arm(color: str, skin: str = SKIN) -> str:
    return path("M76 94 Q92 96 90 108 L84 110 Q80 102 74 102 Z", color) + circle(HAND[0], HAND[1], 6.5, skin)


def head(skin: str = SKIN, cy: float = 58, r: float = 28) -> str:
    # The ear sits at the back of the head (figures face right).
    return circle(39, cy + 4, 5, skin) + circle(64, cy, r, skin)


def face(cy: float = 60, look: str = "calm", eye: str = INK) -> str:
    out = ellipse(62, cy, 3, 4, eye, stroke=False) + ellipse(78, cy, 3, 4, eye, stroke=False)
    out += circle(61, cy - 1.5, 1, "#FFFFFF", stroke=False) + circle(77, cy - 1.5, 1, "#FFFFFF", stroke=False)
    out += ellipse(56, cy + 8, 4, 2.5, "#E88C7A", stroke=False, extra=' opacity="0.6"')
    if look == "smile":
        out += line(f"M66 {cy + 10} Q71 {cy + 14} 76 {cy + 10}", INK, 2.2)
    elif look == "stern":
        out += line(f"M57 {cy - 7} L66 {cy - 5}", INK, 2.5) + line(f"M74 {cy - 5} L83 {cy - 7}", INK, 2.5)
        out += line(f"M67 {cy + 11} L76 {cy + 11}", INK, 2.2)
    elif look == "sly":
        out += line(f"M57 {cy - 6} L66 {cy - 7}", INK, 2) + line(f"M74 {cy - 8} L83 {cy - 5}", INK, 2)
        out += line(f"M66 {cy + 10} Q72 {cy + 13} 77 {cy + 8}", INK, 2.2)
    else:
        out += line(f"M67 {cy + 11} Q71 {cy + 13} 75 {cy + 11}", INK, 2.2)
    return out


def humanoid(*, outfit: str, outfit_d: str, trousers: str, boots: str, skin: str = SKIN, back: str = "",
             behind_head: str = "", hair: str = "", front: str = "", look: str = "calm", wide: float = 0,
             sleeve: str = "") -> str:
    sleeve = sleeve or outfit
    return (shadow() + back + legs(trousers, boots) + back_arm(sleeve, skin) + torso(outfit, outfit_d, wide)
            + behind_head + head(skin) + face(look=look) + hair + front + front_arm(sleeve, skin))


# --- held things (on the same canvas, gripped at HAND) -------------------------------

def held_sword(blade: str = STEEL, length: float = 44, width: float = 7) -> str:
    x, y = HAND
    return (path(f"M{x - width / 2} {y - 8} L{x - width / 2} {y - 8 - length} L{x} {y - 14 - length} L{x + width / 2} {y - 8 - length} L{x + width / 2} {y - 8} Z", blade)
            + line(f"M{x} {y - 12} L{x} {y - 6 - length}", STEEL_L, 1.8)
            + rect(x - 9, y - 10, 18, 5, BRASS, 1.5) + rect(x - 3, y - 5, 6, 12, OAK, 2))


def held_dagger() -> str:
    return held_sword(length=22, width=7)


def held_shield(color: str = "#4A6A8C", rim: str = BRASS, r: float = 20) -> str:
    x, y = HAND
    return (circle(x + 6, y - 4, r, color) + f'<circle cx="{x + 6}" cy="{y - 4}" r="{r - 3}" fill="none" stroke="{rim}" stroke-width="3"/>'
            + circle(x + 6, y - 4, 5, rim) + line(f"M{x - 6} {y - 14} Q{x - 2} {y - 20} {x + 4} {y - 22}", "#8FB0CF", 2.5))


def held_tower() -> str:
    x, y = HAND
    return (path(f"M{x - 6} {y - 38} L{x + 22} {y - 38} L{x + 22} {y + 14} Q{x + 8} {y + 24} {x - 6} {y + 14} Z", "#6B6875")
            + rect(x - 2, y - 34, 20, 44, "none", 2) + line(f"M{x + 8} {y - 36} L{x + 8} {y + 18}", SLATE_D, 3)
            + line(f"M{x - 4} {y - 12} L{x + 20} {y - 12}", SLATE_D, 3) + circle(x + 8, y - 12, 4, BRASS))


def held_lantern_staff() -> str:
    x, y = HAND
    return (line(f"M{x} {y + 18} L{x} {y - 40}", INK, 7) + line(f"M{x} {y + 18} L{x} {y - 40}", OAK, 4)
            + line(f"M{x} {y - 40} Q{x + 12} {y - 44} {x + 14} {y - 34}", INK, 3)
            + rect(x + 7, y - 34, 14, 16, "#F6C667", 2) + flame(x + 14, y - 20, 0.35)
            + path(f"M{x + 5} {y - 34} L{x + 23} {y - 34} L{x + 19} {y - 38} L{x + 9} {y - 38} Z", BRASS, sw=2))


def held_wand(tip: str = RIFT_L) -> str:
    x, y = HAND
    return (line(f"M{x - 2} {y + 6} L{x + 8} {y - 34}", INK, 7) + line(f"M{x - 2} {y + 6} L{x + 8} {y - 34}", OAK_D, 4)
            + path(f"M{x + 9} {y - 48} L{x + 12} {y - 39} L{x + 21} {y - 37} L{x + 12} {y - 34} L{x + 9} {y - 25} L{x + 6} {y - 34} L{x - 3} {y - 37} L{x + 6} {y - 39} Z", tip, sw=2))


def held_bow(wood: str = OAK) -> str:
    x, y = HAND
    limb = f"M{x - 4} {y - 42} Q{x + 22} {y} {x - 4} {y + 40}"
    return (line(limb, INK, 8) + line(limb, wood, 4.5) + line(f"M{x - 4} {y - 42} L{x - 4} {y + 40}", PARCH, 1.5)
            + rect(x + 3, y - 6, 7, 12, OAK_L, 2))


def held_cards() -> str:
    x, y = HAND
    card = lambda a: group(rect(x - 6, y - 30, 14, 20, PARCH, 2) + circle(x + 1, y - 20, 3, BLOOD, stroke=False), f"rotate({a} {x} {y})")
    return card(-20) + card(0) + card(20) + circle(x + 18, y - 34, 5, BRASS)


def held_flame() -> str:
    x, y = HAND
    return flame(x + 4, y - 6, 0.75) + circle(x + 14, y - 26, 2.5, FLAME_Y, stroke=False) + circle(x - 2, y - 30, 1.8, EMBER, stroke=False)


def held_torch() -> str:
    x, y = HAND
    return (line(f"M{x} {y + 14} L{x + 4} {y - 22}", INK, 7) + line(f"M{x} {y + 14} L{x + 4} {y - 22}", OAK, 4)
            + flame(x + 4, y - 20, 0.7).replace(EMBER, "#7ED14F").replace(FLAME_Y, "#D8F5A0"))


def held_hatchet() -> str:
    x, y = HAND
    return (line(f"M{x} {y + 8} L{x + 4} {y - 30}", INK, 7) + line(f"M{x} {y + 8} L{x + 4} {y - 30}", OAK_D, 4)
            + path(f"M{x + 2} {y - 34} Q{x + 22} {y - 36} {x + 20} {y - 18} Q{x + 10} {y - 22} {x + 3} {y - 20} Z", SLATE))


# --- heroes ---------------------------------------------------------------------

def brannoc() -> tuple[str, str]:
    helm = (path("M36 52 Q36 26 64 26 Q92 26 92 52 Z", STEEL) + rect(34, 48, 60, 7, BRASS, 2)
            + line("M64 27 L64 48", STEEL_D, 3) + line("M44 34 Q50 29 58 28", STEEL_L, 2.5))
    beard = path("M50 66 Q64 94 80 66 Q84 76 78 84 Q64 96 50 84 Q44 76 50 66 Z", "#7A4A2A")
    tabard = path("M54 90 L74 90 L72 124 L56 124 Z", "#3E5A7A", sw=2) + circle(64, 102, 5, BRASS, stroke=False)
    body = humanoid(outfit=STEEL, outfit_d=STEEL_D, trousers="#4A3A30", boots=OAK_D, hair=beard + helm, front=tabard, look="stern", wide=4)
    return body, held_shield()


def wren() -> tuple[str, str]:
    hair = path("M36 56 Q34 28 64 28 Q90 28 92 50 Q80 40 64 44 Q52 42 44 50 Z", "#3A2A2A")
    scarf = path("M42 84 Q64 92 86 84 L88 94 Q64 102 40 94 Z", BLOOD) + path("M44 92 L38 112 L48 110 L52 96 Z", BLOOD, sw=2.5)
    vest = path("M50 92 L78 92 L76 122 L52 122 Z", "#5A3A2A", sw=2) + line("M64 92 L64 122", OAK_D, 2)
    body = humanoid(outfit="#6E4A33", outfit_d=OAK_D, trousers="#3A3040", boots="#2A2028", hair=hair, front=vest + scarf, look="sly")
    return body, held_dagger()


def vell() -> tuple[str, str]:
    hood_back = path("M30 66 Q28 24 64 24 Q100 24 98 66 L96 96 Q64 104 32 96 Z", PARCH)
    hood_front = path("M34 60 Q36 30 64 30 Q92 30 94 60 Q88 40 64 40 Q40 40 34 60 Z", PARCH) + line("M36 60 Q38 34 64 32", MOSS, 3)
    robe_trim = line("M64 92 L64 124", MOSS, 4) + circle(64, 98, 4, BRASS)
    body = humanoid(outfit="#EDE3C8", outfit_d="#C9B48A", trousers="#C9B48A", boots=OAK_D, back=hood_back, hair=hood_front, front=robe_trim, look="smile", sleeve="#EDE3C8")
    return body, held_lantern_staff()


def odo() -> tuple[str, str]:
    hat = (path("M30 42 Q64 30 98 42 Q64 50 30 42 Z", "#5A3E8C") + path("M44 40 Q58 -4 88 6 Q72 14 80 40 Z", "#5A3E8C")
           + path("M46 38 Q64 34 80 38 L80 42 Q64 38 46 42 Z", BRASS, sw=2))
    quill = path("M88 44 Q104 30 108 16 Q100 30 92 48 Z", BONE_L, sw=2)
    glasses = (circle(62, 60, 7, "none", extra=' fill-opacity="0"') + circle(78, 60, 7, "none")
               + line("M69 60 L71 60", INK, 2))
    hair = path("M38 52 Q36 44 44 42 L44 58 Z", "#C9C0B0", sw=2) + path("M88 52 Q92 44 86 42 L86 56 Z", "#C9C0B0", sw=2)
    body = humanoid(outfit="#5A3E8C", outfit_d="#3A2860", trousers="#3A2860", boots=OAK_D, hair=hair + quill + hat + glasses, look="calm", wide=6)
    return body, held_wand()


def maren() -> tuple[str, str]:
    cloak = path("M34 84 Q30 120 36 140 L92 140 Q98 120 94 84 Z", "#3F6A3A")
    hood = path("M34 60 Q32 26 64 26 Q96 26 94 60 Q90 38 64 38 Q38 38 34 60 Z", "#4F7F48") + line("M40 50 Q46 34 60 32", "#7FAE6A", 2.5)
    braid = path("M36 60 Q28 80 34 96 L40 94 Q36 80 42 62 Z", "#E0B860", sw=2.5)
    body = humanoid(outfit="#6E8A4A", outfit_d="#4F6A34", trousers="#5A4A34", boots=OAK_D, back=cloak, behind_head=braid, hair=hood, look="calm")
    return body, held_bow()


def pell() -> tuple[str, str]:
    hat = rect(46, 14, 36, 26, "#2E2438", 3) + rect(38, 38, 52, 6, "#2E2438", 3) + rect(46, 32, 36, 5, BLOOD, 1.5)
    candle = rect(60, 2, 7, 14, BONE_L, 2) + flame(63.5, 4, 0.3)
    hair = path("M38 52 Q40 42 48 44 L46 60 Z", "#C9783A", sw=2) + path("M88 50 Q86 42 80 44 L84 58 Z", "#C9783A", sw=2)
    vest = (path("M50 92 L78 92 L76 122 L52 122 Z", "#D6A24A", sw=2) + line("M56 92 L56 122", "#8E6A24", 3)
            + line("M64 92 L64 122", "#8E6A24", 3) + line("M72 92 L72 122", "#8E6A24", 3))
    body = humanoid(outfit="#6A3A5A", outfit_d="#4A2640", trousers="#2E2438", boots="#2A2028", hair=hair + hat + candle, front=vest, look="sly")
    return body, held_cards()


def hesk() -> tuple[str, str]:
    helm = path("M36 50 Q36 28 64 28 Q92 28 92 50 L92 56 L36 56 Z", SLATE) + line("M40 40 Q48 32 60 30", SLATE_L, 2.5)
    visor = rect(56, 44, 30, 6, SLATE_D, 2)
    beard = path("M46 64 Q64 108 84 64 Q90 80 80 92 Q64 104 48 92 Q40 80 46 64 Z", "#E6E0D6")
    mantle = path("M36 86 Q64 76 92 86 L94 98 Q64 90 34 98 Z", "#7A3A2A")
    body = humanoid(outfit=SLATE, outfit_d=SLATE_D, trousers="#3A3440", boots="#2A2028", skin=SKIN_OLD, hair=beard + helm + visor, front=mantle, look="stern", wide=6)
    return body, held_tower()


def ysolde() -> tuple[str, str]:
    hair_back = path("M34 50 Q30 100 40 118 L54 110 Q46 80 50 50 Z", "#B8B0B8") + path("M92 50 Q98 90 90 110 L80 104 Q84 80 80 50 Z", "#B8B0B8")
    fringe = path("M36 56 Q34 28 64 28 Q94 28 92 54 Q80 38 66 42 Q52 38 36 56 Z", "#CFC8D0")
    embers = circle(40, 34, 2.5, EMBER, stroke=False) + circle(96, 70, 2, FLAME_Y, stroke=False) + circle(30, 90, 2, EMBER, stroke=False)
    sash = path("M48 92 L80 116 L76 122 L44 98 Z", FLAME_Y, sw=2)
    body = humanoid(outfit="#A83A2A", outfit_d="#7A2A1E", trousers="#5A2A22", boots="#2A2028", back=hair_back, hair=fringe + embers, front=sash, look="calm")
    return body, held_flame()


# --- rift creatures ------------------------------------------------------------------

def beast(*, fur: str, fur_d: str, eye: str, size: float = 1.0, mane: str = "", cracks: str = RIFT_L,
          maw: str = "", tail: bool = True, horns: bool = False) -> str:
    """A four-legged rift beast facing right, scaled about its feet."""
    body = shadow()
    parts = ""
    if tail:
        parts += path("M36 104 Q16 96 14 78 Q26 90 40 96 Z", fur_d)
    parts += rect(40, 112, 10, 30, fur_d, 3) + rect(78, 112, 10, 30, fur_d, 3)
    parts += ellipse(62, 108, 30, 18, fur)
    parts += rect(48, 116, 10, 28, fur, 3) + rect(86, 114, 10, 30, fur, 3)
    if mane:
        parts += path("M72 84 Q66 104 80 116 L96 110 Q104 92 96 80 Z", mane)
    parts += path("M78 92 Q76 66 96 66 Q112 66 114 82 L120 90 Q116 98 104 100 Q90 104 78 92 Z", fur)
    parts += path("M84 70 L82 52 L94 64 Z", fur_d) + path("M96 66 L102 50 L106 68 Z", fur_d)
    if horns:
        parts += path("M86 68 Q76 48 84 38 Q86 54 94 64 Z", BONE_D, sw=2)
    parts += ellipse(100, 80, 5, 4, eye, stroke=False) + circle(100, 80, 8, eye, stroke=False, extra=' opacity="0.3"')
    parts += path("M108 92 L112 98 L116 92 Z", BONE_L, sw=1.5) + path("M114 91 L117 96 L119 90 Z", BONE_L, sw=1.5)
    if maw:
        parts += path("M104 94 Q114 100 120 90 Q114 96 104 94 Z", maw, sw=2)
    parts += line("M50 100 L56 106 L54 114", cracks, 2.5) + line("M70 98 L66 106 L72 112", cracks, 2.5)
    return body + group(parts, f"translate(64 150) scale({size}) translate(-64 -150)")


def rift_pup() -> tuple[str, str]:
    return beast(fur="#3A2A55", fur_d="#2A1B45", eye="#E0C8FF", size=0.8), ""


def rift_hound() -> tuple[str, str]:
    return beast(fur="#3A2A55", fur_d="#2A1B45", eye="#E0C8FF", size=1.05, mane="#4A3470"), ""


def ash_hound() -> tuple[str, str]:
    return beast(fur="#6B6875", fur_d="#45424E", eye=FLAME_Y, cracks=EMBER, mane="#55525E"), ""


def mother_ash() -> tuple[str, str]:
    return beast(fur="#55525E", fur_d="#3C3A44", eye=FLAME_Y, cracks=EMBER, mane=EMBER, maw=FLAME_Y, size=1.2, horns=True), ""


def rift_sentinel() -> tuple[str, str]:
    armor = (path("M34 64 L94 64 L100 128 L28 128 Z", "#3C3446") + rect(36, 128, 20, 18, "#2A2433", 3) + rect(72, 128, 20, 18, "#2A2433", 3)
             + path("M40 30 L88 30 L92 64 L36 64 Z", "#4A4056"))
    maw = path("M46 44 Q64 62 82 44 L78 56 Q64 64 50 56 Z", RIFT_D, sw=2) + circle(64, 50, 5, RIFT_L, stroke=False)
    eyes = rect(46, 36, 10, 4, RIFT_L, 1) + rect(72, 36, 10, 4, RIFT_L, 1)
    arms = ellipse(26, 96, 11, 24, "#3C3446") + ellipse(102, 96, 11, 24, "#3C3446")
    cracks = line("M44 80 L54 92 L50 106", RIFT_L, 3) + line("M84 76 L76 92 L84 110", RIFT_L, 3)
    return shadow() + arms + armor + maw + eyes + cracks, ""


def gloam_witch() -> tuple[str, str]:
    cloak = path("M30 146 Q34 90 48 70 Q64 58 80 70 Q94 90 98 146 Z", "#2A2433")
    hood = path("M40 70 Q40 30 66 26 Q90 30 90 70 Q80 58 66 58 Q50 58 40 70 Z", "#3A3246")
    face_ = ellipse(66, 64, 14, 12, "#9AB08A") + circle(60, 62, 2.5, "#D8F5A0", stroke=False) + circle(72, 62, 2.5, "#D8F5A0", stroke=False)
    nose = path("M70 64 L80 70 L70 70 Z", "#8AA07A", sw=2)
    hand = circle(HAND[0], HAND[1], 6, "#9AB08A") + path("M76 92 Q90 96 88 108 L82 110 Q80 102 74 102 Z", "#2A2433")
    return shadow() + cloak + hood + face_ + nose + hand, held_torch()


def ashling() -> tuple[str, str]:
    body = (shadow() + rect(54, 124, 8, 20, "#45424E", 3) + rect(68, 124, 8, 20, "#45424E", 3)
            + ellipse(65, 112, 18, 18, "#55525E") + circle(66, 80, 20, "#6B6875")
            + path("M50 66 L44 50 L58 62 Z", "#45424E") + path("M80 64 L90 48 L84 66 Z", "#45424E")
            + circle(60, 80, 3.5, FLAME_Y, stroke=False) + circle(74, 80, 3.5, FLAME_Y, stroke=False)
            + line("M62 92 L70 92", EMBER, 2) + line("M58 108 L64 114 L60 120", EMBER, 2.5)
            + circle(HAND[0] - 4, HAND[1] + 2, 5.5, "#6B6875"))
    return body, held_hatchet()


def cinder_moth() -> tuple[str, str]:
    wings = (path("M64 90 Q20 40 14 80 Q18 110 64 100 Z", "#A8471F") + path("M64 90 Q108 40 114 80 Q110 110 64 100 Z", "#C45A2A")
             + circle(34, 78, 7, FLAME_Y) + circle(94, 78, 7, FLAME_Y)
             + path("M64 100 Q34 110 32 134 Q50 128 64 108 Z", "#7A3A2A") + path("M64 100 Q94 110 96 134 Q78 128 64 108 Z", "#7A3A2A"))
    body = ellipse(64, 104, 8, 22, "#3C3A44") + circle(64, 80, 8, "#3C3A44") + circle(61, 78, 2, FLAME_Y, stroke=False) + circle(68, 78, 2, FLAME_Y, stroke=False)
    antennae = line("M60 74 Q52 60 48 58", INK, 2) + line("M68 74 Q76 60 80 58", INK, 2)
    embers = circle(40, 130, 2, EMBER, stroke=False) + circle(88, 136, 2.5, FLAME_Y, stroke=False)
    return group(wings + antennae + body + embers, "translate(0 -10)") + ellipse(64, 151, 18, 4, "#000000", stroke=False, extra=' opacity="0.2"'), ""


def bog_lurker() -> tuple[str, str]:
    body = (shadow() + path("M20 146 Q16 96 48 80 Q80 70 104 90 Q118 110 110 146 Z", "#4A5A34")
            + path("M84 84 Q116 78 120 100 Q112 112 92 108 Z", "#5A6A40")
            + circle(92, 86, 5, "#E8D86A", stroke=False) + circle(104, 86, 4, "#E8D86A", stroke=False)
            + path("M96 104 L100 112 L104 104 Z", BONE_L, sw=1.5) + path("M106 104 L109 110 L112 103 Z", BONE_L, sw=1.5)
            + path("M30 120 Q40 112 50 122", "#3A4A28", sw=0) + line("M30 118 Q40 110 52 120", "#6B7A48", 3)
            + circle(40, 100, 4, "#6B7A48", stroke=False) + circle(60, 92, 3, "#6B7A48", stroke=False)
            + path("M20 146 Q28 136 36 146 Q44 136 52 146 Q60 136 68 146 Q76 136 84 146 Q92 136 100 146 Q106 138 110 146 Z", "#3E5A6A", sw=2))
    return body, ""


def hollow_archer() -> tuple[str, str]:
    cloak = path("M38 146 Q36 100 44 84 L84 84 Q92 100 90 146 Z", "#2A2433")
    hood = path("M38 70 Q38 28 64 26 Q90 28 90 70 Q80 60 64 60 Q48 60 38 70 Z", "#3A3246")
    skull = ellipse(66, 64, 13, 13, BONE) + circle(61, 62, 3, RIFT_L, stroke=False) + circle(72, 62, 3, RIFT_L, stroke=False) + line("M62 72 L72 72", INK, 1.8)
    quiver = rect(34, 76, 10, 30, OAK_D, 2) + line("M36 76 L32 66", PARCH, 2) + line("M40 76 L40 64", PARCH, 2)
    hand = path("M76 92 Q90 96 88 108 L82 110 Q80 102 74 102 Z", "#2A2433") + circle(HAND[0], HAND[1], 5.5, BONE)
    return shadow() + quiver + cloak + hood + skull + hand, held_bow(wood="#4A3438")


def cairn_guardian() -> tuple[str, str]:
    stones = (shadow() + ellipse(64, 138, 34, 12, SLATE) + ellipse(64, 116, 30, 16, "#7A7686")
              + ellipse(64, 90, 24, 16, SLATE) + ellipse(64, 64, 18, 14, "#7A7686")
              + ellipse(30, 104, 10, 16, SLATE_D) + ellipse(98, 104, 10, 16, SLATE_D)
              + circle(58, 62, 3, FROST_L, stroke=False) + circle(70, 62, 3, FROST_L, stroke=False)
              + line("M56 88 L64 96 L60 104", FROST, 2.5) + path("M60 48 Q64 40 70 48 Z", MOSS, sw=2) + line("M52 118 Q64 112 76 118", MOSS, 3))
    return stones, ""


HEROES = {"brannoc": ("warden", brannoc), "wren": ("striker", wren), "vell": ("mender", vell), "odo": ("arcanist", odo),
          "maren": ("ranger", maren), "pell": ("trickster", pell), "hesk": ("warden", hesk), "ysolde": ("arcanist", ysolde)}
ENEMIES = {"rift_pup": rift_pup, "rift_hound": rift_hound, "rift_sentinel": rift_sentinel, "gloam_witch": gloam_witch,
           "ash_hound": ash_hound, "mother_ash": mother_ash, "ashling": ashling, "cinder_moth": cinder_moth,
           "bog_lurker": bog_lurker, "hollow_archer": hollow_archer, "cairn_guardian": cairn_guardian}
BEASTS = {"rift_pup", "rift_hound", "ash_hound", "mother_ash", "bog_lurker", "cinder_moth", "rift_sentinel", "cairn_guardian"}


## Where each portrait looks: (x, y, zoom) on the figure's canvas.
PORTRAIT_FOCUS = {
    "humanoid": (66, 64, 1.3), "beast": (100, 84, 1.25),
    "rift_pup": (92, 97, 1.5), "rift_hound": (101, 81, 1.2), "mother_ash": (104, 74, 1.0),
    "rift_sentinel": (64, 52, 1.1), "cairn_guardian": (64, 70, 1.2), "cinder_moth": (64, 80, 0.85),
    "bog_lurker": (96, 92, 1.1), "ashling": (66, 80, 1.3), "gloam_witch": (66, 62, 1.2), "hollow_archer": (66, 62, 1.2),
}


def portrait(char_id: str, body: str, held: str, ring: str, beast_: bool) -> str:
    """Head and shoulders in a round frame: the figure, scaled up around its head."""
    x, y, zoom = PORTRAIT_FOCUS.get(char_id, PORTRAIT_FOCUS["beast" if beast_ else "humanoid"])
    focus = f"translate(48 50) scale({zoom}) translate({-x} {-y})"
    return canvas('<defs><clipPath id="c"><circle cx="48" cy="48" r="42"/></clipPath></defs>'
                  + circle(48, 48, 44, ring) + circle(48, 48, 42, "#2A2233", stroke=False)
                  + f'<g clip-path="url(#c)">{group(body + held, focus)}</g>'
                  + f'<circle cx="48" cy="48" r="42" fill="none" stroke="{INK}" stroke-width="3"/>', 96, 96)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rig: dict = {}
    for kind, table in (("hero", HEROES), ("enemy", ENEMIES)):
        for char_id, entry in table.items():
            ring_name, draw = entry if kind == "hero" else ("enemy", entry)
            body, held = draw()
            beast_ = char_id in BEASTS
            (OUT / f"{char_id}_body.svg").write_text(canvas(body), encoding="utf-8")
            if held:
                (OUT / f"{char_id}_held.svg").write_text(canvas(held), encoding="utf-8")
            (OUT / f"{char_id}_portrait.svg").write_text(portrait(char_id, body, held, CLASS_RING[ring_name], beast_), encoding="utf-8")
            rig[char_id] = {"hand": list(HAND), "beast": beast_, "held": bool(held)}
    (OUT / "rig.json").write_text(json.dumps(rig, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {len(rig)} characters to {OUT}")
    fixed = fix_imports(OUT, {"mipmaps/generate": "true", "svg/scale": "2.0"})
    if fixed:
        print(f"set import settings on {fixed} files: run `godot --headless --import` to apply them")


if __name__ == "__main__":
    main()
