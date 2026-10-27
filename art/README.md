# art/

All art. The game is asset-driven: every file follows `docs/plans/art/asset-contract.md`, and a commissioned `<name>.png` replaces the placeholder `<name>.svg` beside it with no code change (`ArtPath`: a PNG before its SVG). Anything not made for the game is listed in `CREDITS.md`.

- `figures/`: what the arena draws for each unit (see its README).
- `portraits/`: head-and-shoulders portraits, as they're commissioned (`art/portraits/heroes/<hero>/<form>`, `art/portraits/enemies/<enemy>`).
- `fonts/`: Cinzel, Alegreya, Work Sans, and Young Serif, each with its license.
- `ui/`: the screens' art: `arena/` (the island, ground, Rift Collapse's tiles, ruins, the sky), `backgrounds/` (the title), `camp/` (camp options' icons), `items/` (each kind's frame and the glyphs), `map/` (the act map), `nodes/` (the day's nodes), `shops/` (the keepers and their scenes), and `statuses/` (status icons, as they're drawn).
- `look-tests/`: style tests, left out of builds.

## Folders

| Folder | What it holds |
| --- | --- |
| `figures/` | What the arena draws for each unit: `heroes/<hero>/<form>` and `enemies/<enemy>`. |
| `fonts/` | The game's fonts, each with its license: Cinzel for headings and names, Alegreya for body text, Work Sans as the fallback, and Young Serif. |
| `look-tests/` | Style tests: the look of the figures, the arena, the map, and the shops, tried before they were built. |
| `ui/` | The screens' art, by where it shows: `arena/`, `backgrounds/`, `camp/`, `items/`, `map/`, `nodes/`, and `shops/`. |
