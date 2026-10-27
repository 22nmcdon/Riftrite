# docs/plans/

Every plan the rebuild is built from. `rebuild-build-order.md` is the order of work; each phase's build plan has a **Decisions** section, and those win. If the code and a plan disagree, stop and ask. `CLAUDE.md`'s table lists every plan and its state.

Plans name each other by file name. When the clean-up (`phases/cleanup-and-layout.md`) moved code, tools, and docs, the full paths in the plans moved with them; the old flat data files (`paths.json`, `act1.json`) are named as kinds, which `DataLayout` maps to their new files.

## Folders

| Folder | What it holds |
| --- | --- |
| `acts/` | The rosters for Act 2 and Act 3: their terrain, enemies, elites, bosses, fights, and the playtester's decisions. |
| `art/` | The asset contract and `incoming/`, the playtester's change files still waiting on a file the repo doesn't have yet. |
| `design/` | The design, system by system: heroes, the arena, enemies, the run, between fights, combos, the content pool, apexes, upgrade pools, duo bonds, enemy growth, endless, the economy, days and nodes, events, the Magpie, the UI's new systems, and the relic and... |
| `phases/` | Each phase's build plan, in the order they were built: what it built, step by step, what it measured, and its **Decisions**. |
| `tuning/` | How paths and teams are judged: path types with floor and ceiling targets, the team builds and the roster's gaps, and the teams the bots play. |

## Files

| File | What it is |
| --- | --- |
| `rebuild-build-order.md` | Rebuild plan, part 5: build order and what gets gutted |
