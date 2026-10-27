# art/figures/

What the arena draws for each unit: `heroes/<hero>/<form>` (a hero's base form, one per path, one per apex as drawn; Kestra's companions have folders too) and `enemies/<enemy>` (and `<enemy>_<specialization>` as drawn). Every figure shares a 300 × 520 canvas, facing right, feet at (150, 500); a boss marked `"scale": 2` in `figures.json` has twice the canvas.

- `figures.json`: the manifest, by hand from what the artist supplies: each figure's `head`, `muzzle`, `hand`, `scale`, and `parts`, in canvas units.
- `bounds.json`: what each figure covers of its canvas, written by `tools/art/figure_bounds.gd` (a test checks it's current).

## Folders

| Folder | What it holds |
| --- | --- |
| `enemies/` | A figure per enemy, summons included, and one per specialization as they're drawn. |
| `heroes/` | One folder per hero, a figure per form: `base`, one per path, and one per apex as they're drawn. |
