# data/

All game content, as JSON. Content is data, not code (`CLAUDE.md` rule 3): heroes, enemies, encounters, paths, upgrades, relics, items, and duo bonds are entries built from the effect, trigger, and part types the sim already has.

- **Who reads it:** `ContentDb` (the sim's content) and `RunContent` (the run's), both through `DataLayout` (`src/sim/content/data_layout.gd`), which names every file below and joins each kind's entries in a set order. A test checks that no file here is left unread.
- **Check it:** `godot --headless --path . -s tools/validate_data.gd` (the test run does this too).
- **Units:** durations in milliseconds (multiples of 50), percentages in basis points (10000 = 100%), distances in hexes.
- **`_note`:** any entry may carry a `_note` for people; the game ignores it.

## Folders

| Folder | What it holds |
| --- | --- |
| `acts/` | The rift: one folder per act, and what makes enemies grow across acts: `enemy_upgrades.json` and `rift_learns.json`. |
| `core/` | The shared rules every fight uses: the tuning numbers, the statuses more than one hero or the enemies use, and the tactics. |
| `heroes/` | One folder per hero, each with the same files; each folder's README lists its paths, apexes, cards, and bonds. |
| `run/` | What the run offers between fights: relics, loadout items, duo bonds, camp and the day's nodes, and the Event node's scenes and oaths. |
