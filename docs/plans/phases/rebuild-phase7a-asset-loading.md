# Phase 7a: loading commissioned art

Status: **built (2026-10-27).** The first part of phase 7 (the art rehaul): the code changes `asset-contract.md` asks for in its section 10, so commissioned art drops into `art/` under the contract's names and replaces its placeholder with no code change. It changes no fight: the sim, results, and the bench's fingerprints stay as they are. The style guide (`../art-style-guide.md`) and the commissioning come after.

## 1. What's there

- **Figures** (`FigureArt`) load only `.svg`, and the bars, the hover rect, and where shots and swipes are drawn come from the drawn box in `art/figures/bounds.json`. Everything assumes a 300 × 520 texture, so a 4× PNG master (1200 × 2080) would break the crops in `FigureArt.portrait` and `Portrait`.
- **Other art** is loaded by `.svg` paths written into a dozen places (`ArenaView.art`, `ItemIcon`'s frames and glyphs, `Glyph.relic_art`, `UiStyle.icon`, the shops, the act map, the day screen, the title).
- **Statuses** are drawn shapes; nothing loads status art.
- **No portraits:** the hero bar and the hero panel crop the arena figure.
- **Dead code:** `CharacterArt`, the `Figure` widget, and `Glyph.portrait` (the old `art/ui/characters/` set) have no callers.
- **No `CREDITS.md`,** though the fonts (Cinzel and Alegreya, OFL) aren't the game's own.

## 2. What it builds

1. **One loader** (`ArtFile`, `src/ui/art_file.gd`): any art path loads `<name>.png` if it exists, otherwise `<name>.svg`, cached. Every art load goes through it; the code's paths name no extension.
2. **Figures by resolution and scale:** `FigureArt` loads a PNG before the SVG and works out its pixels per canvas unit from the texture's size, so a 4× master draws exactly as the 1× placeholder did. Bounds stay in canvas units, and `tools/art/figure_bounds.gd` measures a PNG where there is one. A figure the manifest marks `"scale": 2` (bosses) has a canvas twice the size (600 × 1040, feet at (300, 1000)) and is drawn twice as tall.
3. **The manifest** (`art/figures/figures.json`, written by hand from what the artist supplies; each point in its figure's canvas units): `head` puts the bars and status tags; `muzzle` is where the figure's shots leave from; `scale` as above; `hand` and `parts` are read and checked, for cut-out animation later. A missing field falls back to the drawn box (the head at the drawn top, the muzzle at the drawn middle).
4. **Shots from the shooter:** a shot is drawn from its shooter's muzzle (the drawn middle without a manifest point) to its target's body, not at the target's height from the start.
5. **Portraits** (`art/portraits/<hero>_<form>`, `art/portraits/<enemy>`): the `Portrait` widget (the hero bar, the hero panel) shows one where there is one, else the figure's crop as now. New places for portraits (the vow screen, the fight card, the shop and pick cards, the Codex) come with the UI redesign.
6. **Status icons** (`art/ui/statuses/<status>`): a status with art is drawn as its art, not its shape.
7. **Two fallbacks from the contract's section 3:** an apex stands as `heroes/<hero>_<apex>` where that art exists (else its path's form, as now), and a specialized enemy as `enemies/<enemy>_<spec>` (else its own figure).
8. **Import settings:** mipmaps on for every texture, as the project's import default, so a dropped PNG imports right untouched; figures and portraits draw with linear filtering and mipmaps.
9. **Housekeeping:** the dead `CharacterArt`, `Figure`, `Glyph.portrait`, and `art/ui/characters/` go; `CREDITS.md` lists the fonts.
10. **Tests:** the contract (every hero's forms and every enemy have a figure; every manifest point is inside its canvas; every PNG has the contract's size: figures 1200 × 2080, or 2400 × 4160 at scale 2, portraits 1024 × 1024, glyphs 512 × 512, status and UI icons 256 × 256; every figure and portrait imports with mipmaps), and the loader against small fixture PNGs (`tests/fixtures/art/`): a PNG wins over its SVG, a 4× texture draws at canvas size, the manifest's points place the bars and the shots, and the fallbacks hold.

## 3. Built

- **The loader:** `ArtFile` (`resolve`, `exists`, `texture`, cached by path) takes every art load: the board's ground, frame, props, backdrop, and Rift Collapse's tiles; the title; `ItemIcon`'s frames and glyphs; `UiStyle.icon`; the shops; the act map; the day screen's icons; FigureArt; portraits; and status art. The paths in the code name no extension (the data's icon paths may keep theirs). `RunContent.art_exists` is the run's own check of its data against the art (a PNG or an SVG), so `src/run/` never reaches into the UI. `ArenaView.art` is gone.
- **Figures:** `FigureArt.texture` takes the PNG first; `canvas`, `feet`, `scale_of`, and `pixels_per_unit` come from the manifest and the texture; `bounds` are in canvas units, and `tools/art/figure_bounds.gd` measures a PNG where there is one (its rect widened to whole units). `UnitToken` keeps each figure's canvas, feet, head, and muzzle (`canvas_offset` mirrors a point when it faces left): the bars sit at the head (`head_offset`), and `muzzle_offset` is where shots leave. `FigureArt.use_root` points FigureArt at the test fixtures; `FigureArt.portrait` (no callers) is gone.
- **The manifest:** `art/figures/figures.json`, empty for now: the placeholders keep the drawn box, and no placeholder boss is marked `"scale": 2` (that would draw today's 1x boss SVGs twice as tall). A commissioned boss comes with its entry.
- **Shots:** `FightFx.shot_at` draws a shot from its shooter's muzzle (as the shooter stands now; the target's body height once the shooter is gone) to its target's body.
- **Portraits:** `Portrait.make` shows `art/portraits/<figure>` (covering the box from the top) where it exists, else the figure's crop as before. None are drawn yet.
- **Status art:** a status with `art/ui/statuses/<status id>` is drawn on the board's tags as its icon and its stacks, not its word (`UnitToken.status_tag`'s third and fourth fields). None are drawn yet.
- **Fallbacks:** `ArenaView.form_of` stands an apex as `heroes/<hero>_<apex>` where it's drawn; `figure_for` stands a specialized enemy as `enemies/<enemy>_<word>` (the specialization's word in snake case: `rift_hound_ashback`) where it's drawn.
- **Imports:** `project.godot`'s `[importer_defaults]` turns mipmaps on for every texture, and the 180 existing imports in `art/` that had them off (the figures from phase 8 among them) now have them on; `art/look-tests/` is left alone. Figures, portraits, and icons already draw with linear filtering and mipmaps.
- **Removed:** `CharacterArt`, the `Figure` widget, `Glyph` (all of it: nothing called its other shapes either), `FrameDecor`, `tools/art/characters.py`, `art/ui/characters/`, and the old relic art in `art/ui/relics/` (only `Glyph` loaded it). Left for the clean-up pass: `UiStyle.stat_row`, `icon_label`, and `icon` (no callers) and the old icons in `art/ui/icons/` (`stop_*`, `gold`, `key`).
- **`CREDITS.md`:** the four fonts (Cinzel, Alegreya, Work Sans, Young Serif; OFL 1.1) and GUT.
- **Tests:** `tests/ui/test_art_contract.gd` (the import default and every game texture's mipmaps, every manifest entry's figure, fields, scale, and points, every PNG's size) and `tests/ui/test_art_loading.gd` against `tests/fixtures/art/` (a PNG over its SVG, a 4x master drawn at canvas size and measured in canvas units, a boss's canvas, the manifest's head and muzzle and their mirroring, portraits' fallback, the apex and specialization fallbacks); `test_fight_view.gd` checks a shot leaves the muzzle. The sim and the data are untouched, so the bench's fingerprints stand.

## Decisions

1. **Approved as proposed** (the playtester, 2026-10-27), the dead code removed here; a clean-up pass follows this part.
