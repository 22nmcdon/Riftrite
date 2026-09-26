#!/usr/bin/env python3
"""Writes the title backdrop (art/ui/backgrounds/title.svg, 1920x1080).

The game's two moods in one picture (docs/ui-asset-design.md, 1): the warm,
lamplit Guildhall on a hill at the left, and the cold rift splitting the sky
at the right, over the dark Hollow. Layered strokes stand in for glow.

Run from the repo root:  python3 tools/art/backdrops.py
then `godot --headless --import`.
"""
import random
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from item_icons import INK, RIFT, RIFT_L  # noqa: E402

OUT = Path(__file__).resolve().parents[2] / "art" / "ui" / "backgrounds"
W, H = 1920, 1080


def title() -> str:
    rng = random.Random(7)  # fixed, so the picture never changes between runs
    parts = ['<defs><linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">'
             '<stop offset="0" stop-color="#0B0811"/><stop offset="0.6" stop-color="#231733"/>'
             '<stop offset="1" stop-color="#2E1E3A"/></linearGradient>'
             '<radialGradient id="warm" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#F6C667" stop-opacity="0.55"/>'
             '<stop offset="1" stop-color="#F6C667" stop-opacity="0"/></radialGradient>'
             '<radialGradient id="cold" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#B79CF0" stop-opacity="0.35"/>'
             '<stop offset="1" stop-color="#7A4FD1" stop-opacity="0"/></radialGradient></defs>',
             f'<rect width="{W}" height="{H}" fill="url(#sky)"/>']
    for _ in range(140):
        x, y, r = rng.uniform(0, W), rng.uniform(0, H * 0.6), rng.choice([1.0, 1.4, 1.8, 2.4])
        parts.append(f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{r}" fill="#EDE3F8" opacity="{rng.uniform(0.25, 0.9):.2f}"/>')
    # The rift: a jagged tear across the upper right, glowing.
    pts = [(1180, 40)]
    x, y = 1180, 40
    while y < 640:
        x += rng.uniform(-60, 90)
        y += rng.uniform(40, 80)
        pts.append((x, y))
    d = "M" + " L".join(f"{px:.0f} {py:.0f}" for px, py in pts)
    parts.append(f'<ellipse cx="1420" cy="340" rx="420" ry="360" fill="url(#cold)"/>')
    for width, color, alpha in [(70, RIFT, 0.12), (40, RIFT, 0.22), (18, RIFT_L, 0.55), (6, "#F4EEFF", 0.95)]:
        parts.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linejoin="round" stroke-linecap="round" opacity="{alpha}"/>')
    for i in range(1, len(pts) - 1, 2):
        bx, by = pts[i]
        ex, ey = bx + rng.choice([-1, 1]) * rng.uniform(40, 110), by + rng.uniform(-20, 40)
        parts.append(f'<path d="M{bx:.0f} {by:.0f} L{ex:.0f} {ey:.0f}" stroke="{RIFT_L}" stroke-width="4" opacity="0.7" stroke-linecap="round"/>')
    # Hills: far, then near.
    parts.append(f'<path d="M0 760 Q300 650 620 720 Q940 790 1260 700 Q1580 620 1920 700 L1920 {H} L0 {H} Z" fill="#1B1426"/>')
    parts.append(f'<path d="M0 640 Q200 560 420 600 Q560 630 640 700 Q900 860 1300 850 Q1650 840 1920 900 L1920 {H} L0 {H} Z" fill="#130E1B"/>')
    # The Guildhall on its hill: warm light, two roofs, a chimney.
    parts.append('<ellipse cx="330" cy="560" rx="360" ry="220" fill="url(#warm)"/>')
    hall = ('<path d="M180 610 L180 500 L270 430 L360 500 L360 610 Z" fill="#0F0B15"/>'
            '<path d="M340 610 L340 520 L420 460 L500 520 L500 610 Z" fill="#0F0B15"/>'
            '<rect x="300" y="440" width="22" height="50" fill="#0F0B15"/>')
    parts.append(hall)
    for (wx, wy) in [(215, 530), (250, 530), (285, 530), (215, 570), (285, 570), (380, 545), (440, 545), (410, 585)]:
        parts.append(f'<rect x="{wx}" y="{wy}" width="20" height="24" rx="3" fill="#F6C667"/>')
        parts.append(f'<circle cx="{wx + 10}" cy="{wy + 12}" r="26" fill="#F6C667" opacity="0.12"/>')
    parts.append('<rect x="250" y="575" width="30" height="35" rx="10" fill="#E0703A"/>')
    for i, (sx, sy) in enumerate([(311, 425), (322, 395), (310, 360), (328, 325)]):
        parts.append(f'<circle cx="{sx}" cy="{sy}" r="{12 + i * 5}" fill="#6B6875" opacity="{0.28 - i * 0.05:.2f}"/>')
    # Lanterns down the road toward the Hollow.
    for i, (lx, ly) in enumerate([(560, 660), (700, 720), (860, 770), (1030, 800)]):
        parts.append(f'<rect x="{lx - 2}" y="{ly - 34}" width="4" height="34" fill="{INK}"/>')
        parts.append(f'<circle cx="{lx}" cy="{ly - 38}" r="{6 - i * 0.6:.1f}" fill="#F6C667"/>')
        parts.append(f'<circle cx="{lx}" cy="{ly - 38}" r="{22 - i * 2}" fill="#F6C667" opacity="0.15"/>')
    # Ground mist.
    parts.append('<defs><linearGradient id="mist" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#B79CF0" stop-opacity="0"/>'
                 '<stop offset="1" stop-color="#B79CF0" stop-opacity="0.22"/></linearGradient></defs>')
    parts.append(f'<rect x="0" y="880" width="{W}" height="200" fill="url(#mist)"/>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">' + "".join(parts) + "</svg>\n"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "title.svg").write_text(title(), encoding="utf-8")
    print(f"wrote {OUT / 'title.svg'}")


if __name__ == "__main__":
    main()
