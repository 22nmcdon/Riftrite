# src/sim/

The combat simulation: one fight on a free plane, tick by tick (20 a second), from a `FightSetup` to a `FightResult` and a combat log. Same seed and same setup make the same fight, every time: integer math only, the sim's own seeded RNG, no Dictionary iteration that affects the outcome. Everything a fight does is logged with its source. Start at `core/combat_sim.gd`; the design is `docs/plans/phases/rebuild-phase1-arena-sim.md`, and `CLAUDE.md`'s "How the arena sim works" maps each piece.

## Folders

| Folder | What it holds |
| --- | --- |
| `arena/` | The plane and what moves on it: the hex grid and the free plane, walking and routes, Engage, pushes and pulls, shots, warned areas and zones, Rift Collapse, summons, snares, walls, Guard, links, shallow water, and islands over the void. |
| `content/` | The content's shapes and loading: `ContentDb` reads `data/` into the definitions in `defs/`, and cross-checks them. |
| `core/` | The fight's engine and its foundations: `CombatSim`, the log, the seeded RNG, fixed-point math, the damage rule, and the result. |
| `effects/` | What abilities do: `EffectRunner` lands every effect by the damage rule, and `Targeting` picks who a unit attacks. |
| `setup/` | What a fight starts from: `FightSetup` and `UnitSetup`, `HeroExtras`, and `Encounters.setup`, which builds a setup from content. |
| `state/` | A fight's changing state: each unit's, each ability's and status's, an effect's source, and a value's breakdown for the log. |
| `tally/` | Read-only counts over a fight's log, shared by the UI and the tools: `FightTally` and `ComboTally`. |
| `units/` | What units do each tick beyond moving: passives and their events, signatures and mana, statuses, deeds counted during a fight, tactics, gambits, grips, copied signatures, boss phases, and keywords. |
