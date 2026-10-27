# src/sim/core/

The fight's engine and its foundations: `CombatSim` (the tick loop), the log (`CombatLog`, `LogEntry`), the seeded RNG, fixed-point math, the damage rule, and the result.

## Files

| File | What it is |
| --- | --- |
| `combat_log.gd` | Everything that happened in a fight, in order. |
| `combat_sim.gd` | Runs one fight in the arena, tick by tick. |
| `damage_rule.gd` | The damage rule: a number is its base times one factor per bonus kind. |
| `fight_result.gd` | How a fight ended. |
| `fixed_math.gd` | Integer math helpers shared by the whole sim. |
| `log_entry.gd` | One line of the combat log. |
| `sim_rng.gd` | The combat sim's only source of randomness. |
