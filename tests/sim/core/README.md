# tests/sim/core/

The engine's foundations: determinism (the chaos fight repeats exactly), the damage rule, fixed math, the RNG, and the log's values.

## Files

| File | What it is |
| --- | --- |
| `test_damage_rule.gd` | The damage rule: bonuses of one kind add, the kinds multiply, and the number is rounded once. |
| `test_determinism.gd` | CLAUDE.md rule 1: same seed, same inputs, same fight, every time. |
| `test_fixed_math.gd` | FixedMath: basis points applied with explicit integer rounding, the one helper the sim rounds with. |
| `test_log_and_values.gd` | The log lines, effect sources, and value breakdowns kept through the rebuild's gut. |
| `test_sim_rng.gd` | Pins SimRng's output so fights replay identically across Godot versions. |
