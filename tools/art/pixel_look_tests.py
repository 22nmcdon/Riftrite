"""Pixel art look tests (the playtester's idea, 2026-10-29): what the luminous
style would look like as pixel art, at the medium size (the screen as about
640 x 360, scaled 3x to 1080p: an arena figure about 40 px tall).

Built from the placeholder art, then finished the way pixel art is drawn:
each figure is drawn at its pixel size, its colors snapped to a fixed palette
(the kits' materials), a 1-pixel ink outline round it, and a gold rim light on
its top and left (the style guide's light, art-style-guide.md section 2). The
arena's sky and ground snap to the act's palette in bands; the hex lines and
motes are single pixels. Everything is scaled up whole pixels, never smoothed.

Writes art/look-tests/pixel_act1_vs_vector.png, pixel_acts.png, and
pixel_lineup.png. Needs Pillow and the preinstalled Chromium (render_svg.js).

Usage: python3 tools/art/pixel_look_tests.py
"""
import os, random, re, subprocess, sys, tempfile

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import act_look_tests as A  # noqa: E402
import enemy_kit as E  # noqa: E402
import hero_kit as H  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "..")
OUT = os.path.join(ROOT, "art", "look-tests")
FONT = os.path.join(ROOT, "art", "fonts", "Alegreya-Regular.ttf")
TITLE_FONT = os.path.join(ROOT, "art", "fonts", "Cinzel-Bold.ttf")

# The arena scene at pixel size: 0.4 of the vector scene, so a figure's
# canvas (1.35 hexes) is 40 px tall, then scaled 3x.
S = 0.4
UP = 3
PX_W, PX_H = round(A.SCENE_W * S), round(A.SCENE_H * S)
FIG_H = 40
FIG_W = round(FIG_H * 300 / 520)
FEET = (round(150 * FIG_H / 520), round(500 * FIG_H / 520))
SUPER = 4  # render at 4x the pixel size, then reduce

INK = (26, 16, 36)
GOLD = (255, 214, 110)
RIM_MIX = 0.38


def rgb(hex_color):
    h = hex_color.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def kit_colors():
    """Every color the hero and enemy kits name: the figures' palette."""
    found = set()
    for name in ("hero_kit.py", "enemy_kit.py"):
        for m in re.finditer(r'#[0-9a-fA-F]{6}\b', open(os.path.join(HERE, name)).read()):
            found.add(rgb(m.group(0)))
    found.add(INK)
    return sorted(found)


FIGURE_PALETTE = kit_colors()


def nearest(color, palette):
    best, best_d = palette[0], 1 << 30
    for p in palette:
        d = (color[0] - p[0]) ** 2 * 3 + (color[1] - p[1]) ** 2 * 4 + (color[2] - p[2]) ** 2 * 2
        if d < best_d:
            best, best_d = p, d
    return best


def render(svgs):
    """Renders each (name, svg text) in Chromium; returns name -> RGBA image."""
    out = {}
    with tempfile.TemporaryDirectory() as tmp:
        paths = []
        for name, text in svgs:
            path = os.path.join(tmp, name + ".svg")
            with open(path, "w") as f:
                f.write(text)
            paths.append(path)
        subprocess.run(["node", os.path.join(HERE, "render_svg.js")] + paths, check=True, stdout=subprocess.DEVNULL)
        for (name, _), path in zip(svgs, paths):
            out[name] = Image.open(path[:-4] + ".png").convert("RGBA")
    return out


def svg_doc(body, view_w, view_h, w, h, transparent=True):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {view_w} {view_h}">'
            f'<defs>{H.FILTERS}</defs>{body}</svg>')


def pixelate_sprite(big, w, h, flip=False):
    """A super-sampled sprite reduced to w x h, snapped to the figures'
    palette, with a 1-pixel ink outline and a gold rim light top and left."""
    small = big.resize((w, h), Image.BOX)
    if flip:
        small = small.transpose(Image.FLIP_LEFT_RIGHT)
    px = small.load()
    solid = [[px[x, y][3] >= 110 for x in range(w)] for y in range(h)]
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    o = out.load()
    for y in range(h):
        for x in range(w):
            if solid[y][x]:
                o[x + 1, y + 1] = nearest(px[x, y][:3], FIGURE_PALETTE) + (255,)

    def is_solid(x, y):
        return 0 <= x < w and 0 <= y < h and solid[y][x]

    for y in range(-1, h + 1):
        for x in range(-1, w + 1):
            if not is_solid(x, y) and any(is_solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                o[x + 1, y + 1] = INK + (255,)
    for y in range(h):
        for x in range(w):
            if solid[y][x] and (not is_solid(x - 1, y) or not is_solid(x, y - 1)):
                c = o[x + 1, y + 1][:3]
                if c != INK:
                    o[x + 1, y + 1] = mix(c, GOLD, RIM_MIX) + (255,)
    return out


def figure_sprites(items):
    """(name, body, flip) list -> name -> pixel sprite (FIG_W+2 x FIG_H+2)."""
    big = render([(n, svg_doc(b, 300, 520, FIG_W * SUPER, FIG_H * SUPER)) for n, b, _ in items])
    return {n: pixelate_sprite(big[n], FIG_W, FIG_H, flip) for n, _, flip in items}


def act_palette(n):
    act = A.ACTS[n]
    colors = [rgb(c) for _, c in act["sky"]]
    sky = []
    for (_, a), (_, b) in zip(act["sky"], act["sky"][1:]):
        for t in (0, 0.25, 0.5, 0.75):
            sky.append(mix(rgb(a), rgb(b), t))
    colors += sky + [rgb(c) for c in act["ground"]] + [rgb(act[k]) for k in ("side", "side_dk", "far", "far_side", "line")]
    colors += [rgb(c) for c in act["motes"]] + [INK, rgb("#F4EAD0"), rgb("#D8CBA0"), rgb("#7FD3D6"), rgb("#D8F6F4"), rgb("#BFE8F0"),
                                                rgb("#7A6A5A"), rgb("#9C88D8"), rgb("#E8E0FF"), rgb("#62F2DF"), rgb("#FFFFFF")]
    if n in A.PALETTES:
        colors += [rgb(c) for _, c in A.PALETTES[n]]
    if act["sun"]:
        # The sun's glow steps out of the sky in bands, not as a disc.
        top = rgb(act["sky"][0][1])
        colors += [mix(top, rgb(act["sun"][0]), t) for t in (0.15, 0.3, 0.45, 0.6)]
    return sorted(set(colors))


def snap(img, palette):
    img = img.convert("RGB")
    p = img.load()
    cache = {}
    for y in range(img.height):
        for x in range(img.width):
            c = p[x, y]
            if c not in cache:
                cache[c] = nearest(c, palette)
            p[x, y] = cache[c]
    return img


def pixel_scene(n, backdrop, sprites):
    """Act n's arena at pixel size (PX_W x PX_H), before scaling up."""
    act = A.ACTS[n]
    img = snap(backdrop.resize((PX_W, PX_H), Image.BOX), act_palette(n))
    draw = ImageDraw.Draw(img)
    line = mix(rgb(act["line"]), rgb(act["ground"][0]), 0.55)
    void, bridges = set(act["void"]), set(act["bridges"])
    for r in range(A.ROWS):
        for c in range(A.COLS):
            if (c, r) in void or (c, r) in bridges:
                continue
            cx, cy = A.hex_center(c, r)
            pts = [tuple(round(float(v) * S) for v in p.split(",")) for p in A.hex_points(cx, cy).split()]
            draw.line(pts + [pts[0]], fill=line, width=1)
    rng = random.Random(n * 7)
    for _ in range(60):
        x, y = rng.randrange(PX_W), rng.randrange(PX_H)
        color = rgb(rng.choice(act["motes"]))
        img.putpixel((x, y), color)
        if rng.random() < 0.25 and 1 <= x < PX_W - 1 and 1 <= y < PX_H - 1:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img.putpixel((x + dx, y + dy), mix(color, img.getpixel((x + dx, y + dy)), 0.5))
    things = []
    for name, (c, r) in act["rocks"]:
        cx, cy = A.hex_center(c, r)
        things.append((cy, sprites["rock_" + name], round((cx - A.HEX * 0.6) * S) - 1, round((cy - A.HEX * 0.95) * S) - 1, None))
    for side, units in (("hero", [(fn, cr) for _, fn, cr in A.TEAM]), ("enemy", act["enemies"])):
        for fn, (c, r) in units:
            cx, cy = A.hex_center(c, r)
            fx, fy = round(cx * S), round((cy + 4) * S)
            ring = GOLD if side == "hero" else (224, 80, 60)
            things.append((cy, sprites[f"{side}_{fn}"], fx - FEET[0] - 1, fy - FEET[1] - 1, (fx, fy, ring, (c, r) in set(act["water"]))))
    for _, sprite, x, y, ring in sorted(things, key=lambda t: t[0]):
        if ring:
            fx, fy, color, wet = ring
            if wet:
                draw.ellipse((fx - 10, fy - 4, fx + 10, fy + 4), outline=rgb("#D8F6F4"))
            draw.ellipse((fx - 8, fy - 3, fx + 8, fy + 3), outline=color)
        img.paste(sprite, (x, y), sprite)
    return img


def up(img, k):
    return img.resize((img.width * k, img.height * k), Image.NEAREST)


def sheet(width, height, title, subtitle):
    img = Image.new("RGB", (width, height), rgb("#1B2433"))
    d = ImageDraw.Draw(img)
    d.text((30, 22), title, font=ImageFont.truetype(TITLE_FONT, 30), fill=rgb("#FFF3CF"))
    d.text((30, 64), subtitle, font=ImageFont.truetype(FONT, 18), fill=rgb("#A9C9C4"))
    return img, d


def main():
    acts = (1, 2, 3)
    # The vector backdrops (no units, lines, or motes), the Act 1 scene whole
    # for the comparison, and every sprite, in one Chromium run each.
    backdrops = render([(f"act{n}", f'<svg xmlns="http://www.w3.org/2000/svg" width="{A.SCENE_W}" height="{A.SCENE_H}" '
                                      f'viewBox="0 0 {A.SCENE_W} {A.SCENE_H}"><defs>{H.FILTERS}</defs>{A.scene(n, f"b{n}", units=False, lines=False, motes=False)}</svg>')
                        for n in acts])
    vector = render([("act1", f'<svg xmlns="http://www.w3.org/2000/svg" width="{PX_W * UP}" height="{PX_H * UP}" '
                               f'viewBox="0 0 {A.SCENE_W} {A.SCENE_H}"><defs>{H.FILTERS}</defs>{A.scene(1, "v")}</svg>')])["act1"]
    items = [(f"hero_{fn}", getattr(H, fn)(f"p{fn}"), False) for _, fn, _ in A.TEAM]
    for n in acts:
        items += [(f"enemy_{eid}", getattr(E, eid)(f"p{eid}"), True) for eid, _ in A.ACTS[n]["enemies"]]
    lineup_heroes = [(hid, name, forms[0][2]) for hid, name, forms in H.HEROES]
    act1_enemies = [e for e in E.ENEMIES[:9]]
    items += [(f"line_{hid}", fn(f"l{hid}"), False) for hid, _, fn in lineup_heroes]
    items += [(f"line_{eid}", fn(f"l{eid}"), False) for eid, _, fn in act1_enemies]
    seen, unique = set(), []
    for item in items:
        if item[0] not in seen:
            seen.add(item[0])
            unique.append(item)
    sprites = figure_sprites(unique)
    rock_px = round(A.HEX * 1.2 * S)
    rocks = sorted({name for n in acts for name, _ in A.ACTS[n]["rocks"]})
    big = render([(f"rock_{r}", svg_doc(A.prop(r), 300, 300, rock_px * SUPER, rock_px * SUPER)) for r in rocks])
    for r in rocks:
        sprites[f"rock_{r}"] = pixelate_sprite(big[f"rock_{r}"], rock_px, rock_px)
    scenes = {n: pixel_scene(n, backdrops[f"act{n}"], sprites) for n in acts}

    # 1. Act 1: the vector look and the pixel look, side by side at one size.
    w = PX_W * UP
    img, d = sheet(2 * w + 90, PX_H * UP + 150, "Pixel art: Act 1, vector against pixel",
                   f"Left: the luminous vector look as the game draws it. Right: the same arena as pixel art, {PX_W} x {PX_H} pixels scaled {UP}x "
                   "(about 640 x 360 for a whole screen). Figures 40 px tall.")
    img.paste(vector.convert("RGB"), (30, 110))
    img.paste(up(scenes[1], UP), (60 + w, 110))
    f = ImageFont.truetype(FONT, 18)
    d.text((30, 120 + PX_H * UP), "Vector (as now)", font=f, fill=rgb("#D8CFB8"))
    d.text((60 + w, 120 + PX_H * UP), "Pixel art (medium)", font=f, fill=rgb("#D8CFB8"))
    img.save(os.path.join(OUT, "pixel_act1_vs_vector.png"))

    # 2. The three acts in pixel art.
    k = 2
    img, d = sheet(3 * PX_W * k + 120, PX_H * k + 150, "Pixel art: the three acts",
                   "Each act's palette snapped to a fixed set of colors, in bands; the same heroes against each act's enemies. Scaled 2x here.")
    for i, n in enumerate(acts):
        x = 30 + i * (PX_W * k + 30)
        img.paste(up(scenes[n], k), (x, 110))
        d.text((x, 120 + PX_H * k), A.ACTS[n]["name"], font=f, fill=rgb("#D8CFB8"))
    img.save(os.path.join(OUT, "pixel_acts.png"))

    # 3. The lineup: the 13 heroes' base forms and the 9 Act 1 enemies, at 5x.
    k, cols = 5, 8
    cell_w, cell_h = (FIG_W + 2) * k + 30, (FIG_H + 2) * k + 44
    names = [(f"line_{hid}", name) for hid, name, _ in lineup_heroes] + [(f"line_{eid}", name) for eid, name, _ in act1_enemies]
    rows = (len(names) + cols - 1) // cols
    img, d = sheet(cols * cell_w + 60, rows * cell_h + 130, "Pixel art: the lineup",
                   f"Each figure at its true size ({FIG_W} x {FIG_H} px, plus its outline), scaled 5x: the 13 heroes' base forms, then the 9 Act 1 enemies.")
    sky = (rgb("#BFF0E2"), rgb("#C8B56A"))
    for i, (key, name) in enumerate(names):
        x, y = 30 + (i % cols) * cell_w, 110 + (i // cols) * cell_h
        cell = Image.new("RGB", (cell_w - 14, cell_h - 14), sky[0])
        ImageDraw.Draw(cell).rectangle((0, cell.height - 60, cell.width, cell.height), fill=sky[1])
        sprite = up(sprites[key], k)
        cell.paste(sprite, ((cell.width - sprite.width) // 2, cell.height - sprite.height - 20), sprite)
        img.paste(cell, (x, y))
        d.text((x + 8, y + 6), name, font=ImageFont.truetype(FONT, 16), fill=INK)
    img.save(os.path.join(OUT, "pixel_lineup.png"))
    print("ok")


if __name__ == "__main__":
    main()
