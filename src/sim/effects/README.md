# src/sim/effects/

What abilities do: `EffectRunner` lands every effect (damage, heals, Shields, statuses, moves, areas, summons) by the damage rule, and `Targeting` picks who a unit attacks.

## Files

| File | What it is |
| --- | --- |
| `effect_runner.gd` | Runs an ability's effects and writes each result to the combat log with its source. |
| `targeting.gd` | Who a unit attacks, and so where it walks. |
