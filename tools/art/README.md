# tools/art/

The placeholder art's makers (Python, writing SVGs) and their Godot helpers: the hero and enemy figures, the backdrops, the item glyphs split from their frames, and `figure_bounds.gd` (what each figure covers, into `art/figures/bounds.json`). Commissioned art replaces their files one at a time (`docs/plans/art/asset-contract.md`).

## Files

| File | What it is |
| --- | --- |
| `act_look_tests.py` | Look tests for the acts' palettes: each act's arena on its floating island, beside its palette, and Acts 1 to 3 side by side (the style guide's Question SC). |
| `art_kit.py` | The shared look for the placeholder art scripts: the palette and SVG drawing helpers. |
| `backdrops.py` | Writes the title backdrop. |
| `enemy_kit.py` | The luminous enemy kit: code-generated placeholder figures for the Act 1, 2, and 3 enemies, in the hero kit's style and on its canvas. |
| `figure_bounds.gd` | Writes art/figures/bounds.json: what each figure in art/figures/ covers of its canvas. |
| `hero_kit.py` | The luminous hero kit: code-generated placeholder figures for the heroes in every form. |
| `item_glyphs.py` | The item language's pieces. |
| `maren_look_test.py` | Code-generated look test for Maren, dark rift style with woodcut-style hatching. |
| `maren_luminous_test.py` | Luminous look test for Maren: a bright, eerie otherworld with bold ink outlines, saturated jewel colors, flat painted shadows, and gold and aquamarine glows. |
| `maren_silhouette_test.py` | Silhouette-style look test for Maren: black ink figures, with only rift light, glowing accents, and status colors breaking the black. |
| `pixel_look_tests.py` | Pixel art look tests: the luminous style as pixel art at the medium size (figures about 40 px tall, scaled 3x), Act 1 against its vector look, the three acts, and a lineup; needs Pillow. |
| `render_svg.js` | Renders SVG look tests to PNGs beside them (transparent where nothing is drawn), in the preinstalled Chromium. |
