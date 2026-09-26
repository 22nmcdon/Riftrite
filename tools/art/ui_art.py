#!/usr/bin/env python3
"""Writes the UI art (docs/plans/ui-overhaul.md, section 5) as SVG.

  art/ui/chrome/  nine-slice panels and button plaques (StyleBoxTexture in
                  UiStyle; the slice margins are in CHROME below and in
                  UiStyle.CHROME_MARGINS: keep them in sync)
  art/ui/icons/   stat, currency, stop, and fight-kind icons (64x64 canvas)

Same look as the item icons (tools/art/item_icons.py): bold shapes, ink
outline, flat fills with one shade and one highlight, light from the top left.
Panels use flat fills so their edges and centers tile cleanly at any size;
buttons stretch (their gradients would band if tiled).

Run from the repo root:  python3 tools/art/ui_art.py
then `godot --headless --import`, then this script once more (it sets the
import settings), as with item_icons.py.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from item_icons import (  # noqa: E402
    INK, OAK_D, OAK, OAK_L, BRASS_D, BRASS, BRASS_L, STEEL_D, STEEL, STEEL_L, BONE, BONE_L, PARCH,
    EMBER, FLAME_Y, FROST, FROST_L, MOSS, RIFT_D, RIFT, RIFT_L, BLOOD, SLATE_D, SLATE, SLATE_L,
    path, line, circle, rect, group, flame,
)

ROOT = Path(__file__).resolve().parents[2] / "art" / "ui"


def doc(w: int, h: int, body: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            + body + "</svg>\n")


def grad(gid: str, top: str, bottom: str) -> str:
    return (f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0" y2="1">'
            f'<stop offset="0" stop-color="{top}"/><stop offset="1" stop-color="{bottom}"/></linearGradient></defs>')


# --- chrome ---------------------------------------------------------------------

def brackets(w: int, h: int, inset: float, arm: float, color: str, rivet: str) -> str:
    """Brass corner brackets with a rivet, at all four corners."""
    out = ""
    for (x, y, dx, dy) in [(inset, inset, 1, 1), (w - inset, inset, -1, 1), (inset, h - inset, 1, -1), (w - inset, h - inset, -1, -1)]:
        d = f"M{x} {y + dy * arm} L{x} {y} L{x + dx * arm} {y}"
        out += line(d, INK, 7) + line(d, color, 3.5)
        out += circle(x + dx * 5, y + dy * 5, 2.2, rivet, stroke=False)
    return out


def panel_oak() -> str:
    w = h = 96
    grain = "".join(line(f"M4 {y} L92 {y}", "#34241b", 1.5) for y in (22, 37, 55, 71))
    return doc(w, h, f'<rect x="1.5" y="1.5" width="93" height="93" rx="10" fill="#3C2B23" stroke="{INK}" stroke-width="3"/>'
               + grain
               + f'<rect x="6" y="6" width="84" height="84" rx="6" fill="none" stroke="{BRASS_D}" stroke-width="1.5"/>'
               + brackets(w, h, 6, 16, BRASS, BRASS_L))


def panel_parchment() -> str:
    w = h = 96
    return doc(w, h, '<defs><radialGradient id="p" cx="0.5" cy="0.45" r="0.75">'
               f'<stop offset="0.6" stop-color="{PARCH}"/><stop offset="1" stop-color="#DCCB9F"/></radialGradient></defs>'
               + f'<rect x="1.5" y="1.5" width="93" height="93" rx="6" fill="url(#p)" stroke="{OAK_D}" stroke-width="3"/>'
               + f'<rect x="6" y="6" width="84" height="84" rx="3" fill="none" stroke="#C9B48A" stroke-width="1.2"/>')


def panel_slate() -> str:
    w = h = 96
    cracks = (line("M7 30 L14 24 L13 16 L20 9", RIFT, 4) + line("M7 30 L14 24 L13 16 L20 9", RIFT_L, 1.5)
              + line("M89 66 L82 72 L84 80 L76 88", RIFT, 4) + line("M89 66 L82 72 L84 80 L76 88", RIFT_L, 1.5))
    return doc(w, h, f'<rect x="1.5" y="1.5" width="93" height="93" rx="4" fill="#241E2C" stroke="{INK}" stroke-width="3"/>'
               + f'<rect x="5" y="5" width="86" height="86" rx="2" fill="none" stroke="#3E3548" stroke-width="2"/>'
               + cracks)


def panel_stall() -> str:
    """The Caravan's cloth: deep red felt, a stitched hem, brass tacks."""
    w = h = 96
    stitch = f'<rect x="9" y="9" width="78" height="78" rx="5" fill="none" stroke="#D9B98A" stroke-width="1.6" stroke-dasharray="5 4"/>'
    tacks = "".join(circle(x, y, 2.6, BRASS_L) for x, y in [(6, 6), (90, 6), (6, 90), (90, 90)])
    return doc(w, h, f'<rect x="1.5" y="1.5" width="93" height="93" rx="8" fill="#4E2427" stroke="{INK}" stroke-width="3"/>'
               + stitch + tacks)


def panel_bar() -> str:
    """The day bar and guild bar: ink with a brass rule along the inside."""
    w = h = 64
    return doc(w, h, f'<rect x="1.5" y="1.5" width="61" height="61" rx="6" fill="#1B1522" stroke="{INK}" stroke-width="3"/>'
               + f'<rect x="4.5" y="4.5" width="55" height="55" rx="4" fill="none" stroke="{BRASS_D}" stroke-width="1.5"/>')


def plaque(top: str, bottom: str, rim: str, shine: str, dy: float = 0) -> str:
    """A button: a wooden (or ember) plaque with a brass rim."""
    w, h = 72, 44
    return doc(w, h, grad("g", top, bottom)
               + f'<rect x="1.5" y="{1.5 + dy}" width="69" height="{41 - dy}" rx="8" fill="url(#g)" stroke="{INK}" stroke-width="3"/>'
               + f'<rect x="4.5" y="{4.5 + dy}" width="63" height="{35 - dy}" rx="5" fill="none" stroke="{rim}" stroke-width="2"/>'
               + line(f"M10 {9 + dy} L62 {9 + dy}", shine, 1.6))


CHROME = {
    "panel_oak": (panel_oak, 22),
    "panel_parchment": (panel_parchment, 16),
    "panel_slate": (panel_slate, 30),
    "panel_stall": (panel_stall, 24),
    "panel_bar": (panel_bar, 12),
    "button_normal": (lambda: plaque("#6E4A33", "#4E3324", BRASS, "#8A6448"), 14),
    "button_hover": (lambda: plaque("#80573D", "#5C3C2A", BRASS_L, "#A57A58"), 14),
    "button_pressed": (lambda: plaque("#4A3022", "#5A3B2A", BRASS_L, "#4A3022", dy=2), 14),
    "button_disabled": (lambda: plaque("#3A3340", "#2E2934", "#5A5060", "#3A3340"), 14),
    "button_primary": (lambda: plaque("#E0703A", "#A9471F", BRASS_L, "#F4A070"), 14),
    "button_primary_hover": (lambda: plaque("#EE8450", "#BA5428", "#FFF0C0", "#FFC090"), 14),
    "button_primary_pressed": (lambda: plaque("#A9471F", "#C45A2A", BRASS_L, "#A9471F", dy=2), 14),
}


# --- icons ----------------------------------------------------------------------

def icon(body: str) -> str:
    return doc(64, 64, body)


def heart() -> str:
    return icon(path("M32 56 C12 42 6 32 8 22 C10 12 22 8 32 18 C42 8 54 12 56 22 C58 32 52 42 32 56 Z", BLOOD)
                + line("M16 20 Q18 15 23 14", "#E07070", 3))


def sword() -> str:
    blade = path("M32 4 L39 14 L37 40 L27 40 L25 14 Z", STEEL) + line("M32 10 L32 38", STEEL_L, 2)
    guard = rect(18, 40, 28, 6, BRASS, 2)
    grip = rect(28, 46, 8, 10, OAK, 2) + circle(32, 59, 3.5, BRASS)
    return icon(group(blade + guard + grip, "rotate(40 32 32)"))


def spark() -> str:
    star = path("M32 4 L37 25 L58 30 L37 36 L32 60 L27 36 L6 30 L27 25 Z", RIFT_L)
    core = circle(32, 31, 6, "#FFFFFF", stroke=False)
    return icon(star + core + circle(50, 12, 3, RIFT_L) + circle(13, 50, 2.5, RIFT_L))


def shield() -> str:
    return icon(path("M32 5 L54 12 Q54 40 32 59 Q10 40 10 12 Z", FROST)
                + path("M32 5 L54 12 Q54 40 32 59 Z", "#3F8FA5", stroke=False, extra=' opacity="0.55"')
                + path("M32 5 L54 12 Q54 40 32 59 Q10 40 10 12 Z", "none")
                + line("M17 16 L17 30", FROST_L, 3))


def crit() -> str:
    burst = path("M32 4 L37 22 L54 12 L44 28 L60 34 L42 38 L50 56 L34 44 L24 60 L24 42 L6 44 L18 32 L6 18 L24 22 Z", FLAME_Y)
    return icon(burst + circle(32, 32, 7, EMBER))


def speed() -> str:
    """Attack speed: a winged hourglass."""
    glass = (path("M20 8 L44 8 L44 12 L34 30 L44 50 L44 56 L20 56 L20 50 L30 30 L20 12 Z", "#D9C79E")
             + path("M24 50 L32 38 L40 50 Z", BRASS_L, stroke=False) + rect(17, 5, 30, 5, OAK, 2) + rect(17, 54, 30, 5, OAK, 2))
    wing = path("M44 22 Q58 16 61 24 Q54 25 50 30 Q56 30 58 36 Q50 36 44 34 Z", PARCH, sw=2.5)
    return icon(glass + wing)


def coin() -> str:
    stack = (path("M10 44 L10 50 Q10 56 26 56 Q42 56 42 50 L42 44 Z", BRASS_D)
             + f'<ellipse cx="26" cy="44" rx="16" ry="6" fill="{BRASS}" stroke="{INK}" stroke-width="3"/>')
    top = circle(40, 26, 18, BRASS) + circle(40, 26, 12, "none", stroke=False, extra=f' stroke="{BRASS_D}" stroke-width="2"')
    mark = line("M40 18 L40 34", BRASS_D, 3.5) + line("M28 16 Q30 10 36 9", BRASS_L, 3)
    return icon(stack + top + mark)


def key() -> str:
    bow = circle(20, 22, 13, BRASS) + circle(20, 22, 5, "#1B1522")
    shaft = path("M30 28 L56 50 L51 55 L46 51 L42 55 L38 51 L42 47 L26 33 Z", BRASS)
    return icon(shaft + bow + line("M12 16 Q14 12 19 11", BRASS_L, 2.5))


def cracked_heart() -> str:
    """A loss: a heart split by a rift crack."""
    return icon(path("M32 56 C12 42 6 32 8 22 C10 12 22 8 32 18 C42 8 54 12 56 22 C58 32 52 42 32 56 Z", "#5E3A44")
                + line("M32 18 L27 28 L35 34 L29 44 L32 56", INK, 5) + line("M32 18 L27 28 L35 34 L29 44 L32 56", RIFT_L, 2))


def lantern_day() -> str:
    """The day: a small lantern."""
    return icon(line("M26 12 Q32 3 38 12", INK, 6) + line("M26 12 Q32 3 38 12", BRASS, 3)
                + path("M20 14 L44 14 L40 9 L24 9 Z", BRASS) + rect(20, 14, 24, 30, "#F6C667", 3)
                + flame(32, 38, 0.7) + path("M17 44 L47 44 L44 54 L20 54 Z", BRASS))


def wagon() -> str:
    cover = path("M8 34 Q8 10 32 10 Q56 10 56 34 Z", PARCH) + line("M22 12 L20 34", "#C9B48A", 2) + line("M42 12 L44 34", "#C9B48A", 2)
    bed = rect(6, 32, 52, 12, OAK, 2)
    wheels = "".join(circle(x, 48, 8, OAK_D) + circle(x, 48, 2.5, BRASS, stroke=False) for x in (18, 46))
    return icon(cover + bed + wheels)


def anvil() -> str:
    body = path("M6 20 L50 20 Q60 20 60 26 L46 30 L42 38 L46 46 L18 46 L22 38 L18 30 L10 28 Q6 26 6 20 Z", SLATE)
    top = path("M8 20 L50 20 Q58 20 59 24 L10 24 Z", SLATE_L, stroke=False)
    base = rect(12, 46, 40, 8, SLATE_D, 2)
    sparks = line("M28 12 L26 5", FLAME_Y, 3) + line("M36 12 L40 6", FLAME_Y, 3) + circle(46, 9, 2, EMBER, stroke=False)
    return icon(sparks + body + top + base)


def sack() -> str:
    bag = path("M20 22 Q8 34 10 46 Q12 58 32 58 Q52 58 54 46 Q56 34 44 22 Z", "#A07850")
    neck = path("M22 22 L42 22 L38 14 L26 14 Z", "#A07850") + line("M20 22 L44 22", OAK_D, 4)
    coins = circle(44, 12, 6, BRASS) + circle(52, 20, 4, BRASS)
    return icon(coins + bag + neck + line("M18 36 Q19 44 24 50", "#C49A6C", 3))


def chest() -> str:
    lid = path("M8 26 Q8 10 32 10 Q56 10 56 26 Z", OAK)
    body = rect(8, 26, 48, 28, OAK, 2)
    bands = rect(8, 24, 48, 5, BRASS, 1.5) + rect(18, 10, 5, 44, BRASS, 1.5) + rect(41, 10, 5, 44, BRASS, 1.5)
    lock = rect(27, 30, 10, 12, BRASS_L, 2) + circle(32, 35, 1.8, INK, stroke=False)
    return icon(lid + body + bands + lock)


def retrain() -> str:
    """Retrain: an open book with a looping arrow."""
    book = path("M6 18 Q20 12 32 18 Q44 12 58 18 L58 50 Q44 44 32 50 Q20 44 6 50 Z", PARCH) + line("M32 18 L32 50", OAK_D, 2.5)
    lines_ = line("M12 26 L26 24", "#C9B48A", 2) + line("M12 33 L26 31", "#C9B48A", 2) + line("M38 24 L52 26", "#C9B48A", 2)
    arrow = line("M36 38 Q44 30 52 38 Q48 46 40 44", MOSS, 4) + path("M36 34 L36 42 L43 39 Z", MOSS, sw=2)
    return icon(book + lines_ + arrow)


def scroll_event() -> str:
    paper = path("M14 10 L46 10 Q52 10 52 16 L52 54 L18 54 Q12 54 12 48 L12 16 Q12 10 14 10 Z", PARCH)
    roll = rect(10, 6, 12, 10, "#D9C79E", 4) + rect(40, 48, 16, 10, "#D9C79E", 4)
    mark = line("M26 24 Q32 16 38 24 Q38 30 32 32 L32 37", RIFT, 4.5) + circle(32, 44, 2.8, RIFT, stroke=False)
    return icon(paper + roll + mark)


def upgrade() -> str:
    arrow = path("M32 4 L50 24 L40 24 L40 38 L24 38 L24 24 L14 24 Z", MOSS)
    base = path("M8 42 L56 42 L50 50 L54 58 L10 58 L14 50 Z", SLATE)
    return icon(base + arrow + line("M28 26 L28 34", "#A8D08C", 2.5))


def crossed_swords() -> str:
    one = path("M30 4 L35 10 L34 38 L28 38 L27 10 Z", STEEL) + rect(22, 38, 18, 4, BRASS, 1.5) + rect(28, 42, 6, 10, OAK, 1.5)
    return icon(group(one, "rotate(-35 32 34) translate(1 4)") + group(one, "rotate(35 32 34) translate(-1 4)"))


def skull(horns: bool = False, crown: bool = False) -> str:
    out = ""
    if horns:
        out += path("M16 24 Q4 20 6 6 Q12 16 22 18 Z", RIFT_D) + path("M48 24 Q60 20 58 6 Q52 16 42 18 Z", RIFT_D)
    head = path("M12 30 Q12 10 32 10 Q52 10 52 30 Q52 40 44 44 L44 54 L20 54 L20 44 Q12 40 12 30 Z", BONE)
    eyes = circle(24, 32, 5.5, RIFT_D, stroke=False) + circle(40, 32, 5.5, RIFT_D, stroke=False)
    if horns or crown:
        eyes += circle(24, 32, 2, RIFT_L, stroke=False) + circle(40, 32, 2, RIFT_L, stroke=False)
    teeth = line("M26 48 L26 54", INK, 2) + line("M32 48 L32 54", INK, 2) + line("M38 48 L38 54", INK, 2)
    nose = path("M32 38 L29 43 L35 43 Z", RIFT_D, stroke=False)
    out += head + eyes + nose + teeth + line("M17 22 Q19 15 26 13", BONE_L, 2.5)
    if crown:
        out = path("M14 16 L14 2 L22 10 L32 0 L42 10 L50 2 L50 16 Z", BRASS) + out
    return icon(out)


ICONS = {
    "stat_hp": heart, "stat_atk": sword, "stat_mgk": spark, "stat_def": shield, "stat_crit": crit, "stat_atsp": speed,
    "gold": coin, "key": key, "loss": cracked_heart, "day": lantern_day,
    "stop_caravan": wagon, "stop_forge": anvil, "stop_loot": sack, "stop_vault": chest,
    "stop_retrain": retrain, "stop_event": scroll_event, "stop_upgrade": upgrade,
    "fight_normal": crossed_swords, "fight_elite": lambda: skull(horns=True), "fight_boss": lambda: skull(crown=True),
}

ICON_IMPORT = {"mipmaps/generate": "true", "svg/scale": "2.0"}


def fix_imports(folder: Path, params: dict) -> int:
    fixed = 0
    for imp in sorted(folder.glob("*.svg.import")):
        lines = imp.read_text(encoding="utf-8").splitlines()
        out = [f"{ln.split('=', 1)[0]}={params[ln.split('=', 1)[0]]}" if ln.split("=", 1)[0] in params else ln for ln in lines]
        if out != lines:
            imp.write_text("\n".join(out) + "\n", encoding="utf-8")
            fixed += 1
    return fixed


def main() -> None:
    chrome_dir, icon_dir = ROOT / "chrome", ROOT / "icons"
    chrome_dir.mkdir(parents=True, exist_ok=True)
    icon_dir.mkdir(parents=True, exist_ok=True)
    for name, (draw, _margin) in CHROME.items():
        (chrome_dir / f"{name}.svg").write_text(draw(), encoding="utf-8")
    for name, draw in ICONS.items():
        (icon_dir / f"{name}.svg").write_text(draw(), encoding="utf-8")
    print(f"wrote {len(CHROME)} chrome pieces and {len(ICONS)} icons")
    fixed = fix_imports(icon_dir, ICON_IMPORT)
    if fixed:
        print(f"set import settings on {fixed} icons: run `godot --headless --import` to apply them")


if __name__ == "__main__":
    main()
