# Riftrite

A PvE roguelite auto-battler (a working title). The player leads three heroes into the rift one day at a time, placing them in an arena before each fight and then watching it play out. Each hero is vowed to a path and transforms into it by doing what the path asks in fights. Built in Godot 4.7 with GDScript; content is JSON.

`CLAUDE.md` is the full guide: where the rebuild stands, the commands, the rules the code must never break, and how each part works. Every folder has a `README.md` saying what's in it.

## Where things are

| Folder | What's there |
| --- | --- |
| `data/` | All content: `core/` (tuning, shared statuses, tactics), `heroes/<hero>/` (each hero's kit, paths, cards, and statuses), `acts/act<N>/` (each act, its enemies, and its fights), `run/` (relics, items, bonds, camp, events). |
| `src/sim/` | The combat simulation: deterministic, integer-only, no nodes. |
| `src/run/` | The run around the fights: days, shops, relics, saves. |
| `src/ui/` | Scenes and screens; they play back the sim and never change a fight. |
| `tests/` | GUT tests, mirroring `src/`, with each hero's in `tests/heroes/<hero>/`. |
| `tools/` | The validator, the sim and run runners and their reports, the bots, the bench, art scripts, and CI. |
| `docs/` | The design (`design.md`) and the plans it's built from (`plans/`). |
| `art/` | Figures, portraits, fonts, and the screens' art (`docs/plans/art/asset-contract.md` says what each file must be). |

## Common commands

- Play: `godot --path .`
- Test: `godot --headless -s addons/gut/gut_cmdln.gd -gexit` (one file: add `-gselect=<file>`)
- Check the data: `godot --headless --path . -s tools/validate_data.gd`
- A fresh checkout: run `godot --headless --import` once first.

Credits for assets not made for the game are in `CREDITS.md`.
