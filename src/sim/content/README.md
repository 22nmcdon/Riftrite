# src/sim/content/

The content's shapes and loading: `ContentDb` reads `data/` (through `DataLayout`, which names the files) into the definitions in `defs/`, and cross-checks them. `DataReader` reads one JSON entry and reports what's wrong with it by name.

## Folders

| Folder | What it holds |
| --- | --- |
| `defs/` | The definitions content is read into: kits, abilities, effects, auras, triggers, statuses, paths and apexes, deeds, encounters, kit mods, and the rest. |

## Files

| File | What it is |
| --- | --- |
| `content_db.gd` | All game content loaded from data/, validated, and converted to typed defs. |
| `data_layout.gd` | Where each kind of content lives under data/, and the reading both loaders share. |
| `data_reader.gd` | Reads one JSON object with typed accessors. |
