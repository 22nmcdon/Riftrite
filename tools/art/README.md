# tools/art/

The placeholder art's makers (Python, writing SVGs) and their Godot helpers: the hero and enemy figures, the backdrops, the item glyphs split from their frames, and `figure_bounds.gd` (what each figure covers, into `art/figures/bounds.json`). Commissioned art replaces their files one at a time (`docs/plans/art/asset-contract.md`).

## Files

| File | What it is |
| --- | --- |
| `art_kit.py` | The shared look for the placeholder art scripts: the palette and SVG drawing helpers. |
| `backdrops.py` | Writes the title backdrop. |
| `enemy_kit.py` | The luminous enemy kit: code-generated placeholder figures for the Act 1, 2, and 3 enemies, in the hero kit's style and on its canvas. |
| `figure_bounds.gd` | Writes art/figures/bounds.json: what each figure in art/figures/ covers of its canvas. |
| `hero_kit.py` | The luminous hero kit: code-generated placeholder figures for the heroes in every form. |
| `item_glyphs.py` | The item language's pieces. |
| `maren_look_test.py` | Code-generated look test for Maren, dark rift style with woodcut-style hatching. |
| `maren_luminous_test.py` | Luminous look test for Maren: a bright, eerie otherworld with bold ink outlines, saturated jewel colors, flat painted shadows, and gold and aquamarine glows. |
| `maren_silhouette_test.py` | Silhouette-style look test for Maren: black ink figures, with only rift light, glowing accents, and status colors breaking the black. |
