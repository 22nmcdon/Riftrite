# src/run/

The run: days, fights, shops, nodes, relics, the loadout, growth, endless, and saves. `RunState` is everything a run is; `RunFlow` is the only thing that changes it, one action at a time; offers are pure functions of the seed and the state. The design is `docs/plans/phases/rebuild-phase5-run.md`, and `CLAUDE.md`'s "How the run works" maps each piece.

## Folders

| Folder | What it holds |
| --- | --- |
| `content/` | The run's content: `RunContent` reads the run's half of `data/` and answers what a hero's kit, cards, Tithe, and shop rules are now. |
| `draws/` | Everything random in a run, each from its own seeded stream so an offer is a pure function of the seed and the state: the act's fights, shops, picks, nodes, specializations, enemy upgrades, and what the rift learns. |
| `flow/` | The run's state and rules: `RunState`, `RunFlow`, the records file, and the team. |
