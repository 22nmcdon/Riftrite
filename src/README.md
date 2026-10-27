# src/

The game's code, in three layers that only look down:

- `sim/`: the combat simulation. Pure, deterministic logic with integer math; no nodes, no rendering (`CLAUDE.md` rules 1 and 2).
- `run/`: the run around the fights (days, shops, relics, saves); uses the sim.
- `ui/`: scenes and screens; reads the sim and the run, never changes a fight.
- `shared/`: small helpers both the run and the UI need.

The code isn't per hero: a hero's "pieces" are general mechanics that other heroes, relics, and cards reuse. A hero's content is in `data/heroes/<hero>/` and its tests in `tests/heroes/<hero>/`.

## Folders

| Folder | What it holds |
| --- | --- |
| `run/` | The run: days, fights, shops, nodes, relics, the loadout, growth, endless, and saves. |
| `shared/` | Helpers the run and the UI both use, so neither reaches into the other. |
| `sim/` | The combat simulation: one fight on a free plane, tick by tick, from a `FightSetup` to a `FightResult` and a combat log. |
| `ui/` | Scenes and screens. |
