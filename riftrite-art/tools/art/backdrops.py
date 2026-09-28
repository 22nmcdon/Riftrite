#!/usr/bin/env python3
"""Writes the title backdrop (art/ui/backgrounds/title.svg, 1920x1080).

The luminous direction (docs/art-style-guide.md): a bright, eerie
otherworld. A warm gold-to-aquamarine sky, marble ruins in the haze, a
golden meadow, drifting motes, and a seam of aquamarine rift light down the
sky: beautiful, with something wrong about it.

Run from the repo root:  python3 tools/art/backdrops.py
then `godot --headless --import`.
"""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

OUT = Path(__file__).resolve().parents[2] / "art" / "ui" / "backgrounds"
W, H = 1920, 1080


def title() -> str:
    rng = random.Random(7)  # fixed, so the picture never changes between runs
    parts = ['<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
             '<stop offset="0" stop-color="#FFF3CF"/><stop offset="0.45" stop-color="#BFF0E2"/>'
             '<stop offset="0.8" stop-color="#6CC7B6"/><stop offset="1" stop-color="#3F8F8A"/></linearGradient>'
             '<radialGradient id="sun" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFD66E" stop-opacity="0.75"/>'
             '<stop offset="1" stop-color="#FFD66E" stop-opacity="0"/></radialGradient>'
             '<radialGradient id="seam" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#62F2DF" stop-opacity="0.45"/>'
             '<stop offset="1" stop-color="#62F2DF" stop-opacity="0"/></radialGradient>'
             '<linearGradient id="meadow" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#D9C47A"/>'
             '<stop offset="1" stop-color="#6F6A38"/></linearGradient>'
             '<linearGradient id="shade" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#121824" stop-opacity="0"/>'
             '<stop offset="1" stop-color="#121824" stop-opacity="0.55"/></linearGradient></defs>',
             f'<rect width="{W}" height="{H}" fill="url(#sky)"/>',
             '<ellipse cx="560" cy="300" rx="620" ry="420" fill="url(#sun)"/>']
    # Far ruins: columns and an arch, pale in the haze.
    for i in range(9):
        cx = 120 + i * 210 + rng.uniform(-40, 40)
        h = rng.uniform(170, 330)
        base = 700
        parts.append(f'<rect x="{cx:.0f}" y="{base - h:.0f}" width="34" height="{h:.0f}" fill="#9FDCCB" opacity="0.5"/>')
        parts.append(f'<rect x="{cx - 9:.0f}" y="{base - h - 14:.0f}" width="52" height="14" fill="#9FDCCB" opacity="0.5"/>')
    parts.append('<path d="M1180 700 L1180 470 Q1320 350 1460 470 L1460 700 L1410 700 L1410 480 Q1320 410 1230 480 L1230 700 Z" '
                 'fill="#AEE5D6" opacity="0.5"/>')
    # The rift: a seam of aquamarine light down the sky, soft then bright.
    pts = [(1500, 0)]
    x, y = 1500, 0
    while y < 620:
        x += rng.uniform(-35, 35)
        y += rng.uniform(50, 90)
        pts.append((x, y))
    d = "M" + " L".join(f"{px:.0f} {py:.0f}" for px, py in pts)
    parts.append('<ellipse cx="1500" cy="300" rx="260" ry="380" fill="url(#seam)"/>')
    for width, color, alpha in [(60, "#62F2DF", 0.14), (30, "#62F2DF", 0.25), (12, "#B8FFF4", 0.6), (4, "#FFFFFF", 0.95)]:
        parts.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" '
                     f'stroke-linecap="round" opacity="{alpha}"/>')
    # The meadow: far hills, then near, then grass.
    parts.append(f'<path d="M0 700 Q320 650 700 690 Q1100 730 1500 680 Q1760 650 1920 670 L1920 {H} L0 {H} Z" fill="#C8B56A"/>')
    parts.append(f'<path d="M0 780 Q420 730 900 790 Q1300 840 1920 780 L1920 {H} L0 {H} Z" fill="url(#meadow)"/>')
    for _ in range(420):
        gx, gy = rng.uniform(0, W), rng.uniform(700, H)
        hgt = rng.uniform(8, 26)
        lean = rng.uniform(-6, 6)
        col = rng.choice(["#8A8A44", "#B9A458", "#FFF0B0"])
        parts.append(f'<path d="M{gx:.0f},{gy:.0f} q{lean:.1f},{-hgt/2:.1f} {lean*1.6:.1f},{-hgt:.1f}" stroke="{col}" '
                     f'stroke-width="2" fill="none" opacity="0.8"/>')
    # Motes of light drifting up.
    for _ in range(90):
        mx, my = rng.uniform(0, W), rng.uniform(80, 1000)
        r = rng.uniform(1.5, 4.5)
        col = rng.choice(["#FFD66E", "#62F2DF", "#FFFFFF"])
        parts.append(f'<circle cx="{mx:.0f}" cy="{my:.0f}" r="{r * 3:.1f}" fill="{col}" opacity="0.18"/>')
        parts.append(f'<circle cx="{mx:.0f}" cy="{my:.0f}" r="{r:.1f}" fill="{col}" opacity="0.9"/>')
    # A soft shade at the bottom, so menus over it read.
    parts.append(f'<rect x="0" y="600" width="{W}" height="480" fill="url(#shade)"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "".join(parts) + "</svg>\n"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "title.svg").write_text(title(), encoding="utf-8")
    print(f"wrote {OUT / 'title.svg'}")


if __name__ == "__main__":
    main()
