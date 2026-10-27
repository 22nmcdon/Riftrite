# tests/sim/

The sim's tests, by part, and the kits most tests build fights with: `sim_test_kit.gd` (tiny fights: `K.kit`, `K.at`, `K.foe`, `K.sim`, `K.step`), `chaos_fight.gd` (one seeded fight using every piece, for determinism and the log audit), and `path_fights.gd` (fights with paths).

## Folders

| Folder | What it holds |
| --- | --- |
| `arena/` | The plane: the grid, walking and routes, attacks and shots, Engage, pushes, areas, Rift Collapse, summons, statuses, phases, the fight's end, shallow water, islands, and `test_arena_log.gd`. |
| `content/` | Loading and checking content: `ContentDb`, effect and tactic definitions, kits and their text, paths and apexes as kits, and kit mods. |
| `core/` | The engine's foundations: determinism, the damage rule, fixed math, the RNG, and the log's values. |
| `enemies/` | Every enemy kit in small fights, each act's new enemies, elites' pieces, and enemy growth. |
| `pieces/` | The sim pieces that cards, items, relics, and apexes added, each tested by the content that uses it: apexes, bonds, engines, the loadout, paths, relics, sigils, the upgrade pools, and the tuning phase's relics. |
| `tally/` | The read-only counts over a fight: the chart, the combo readout, and the growth tallies. |
| `units/` | Passives' triggers and chains, keywords, deeds, tactics, gambits, copies, habits, and the heroes' rules from relics. |

## Files

| File | What it is |
| --- | --- |
| `chaos_fight.gd` | The chaos fight: one seeded fight that uses every piece of the arena sim, for the determinism tests and the log audit. |
| `path_fights.gd` | Seeded fights with the heroes on their paths, for the tests that need the real paths in play: the determinism test, the log's audit, and the log kinds the chaos fight leaves to them. |
| `sim_test_kit.gd` | Helpers for building tiny arena fights in tests. |
