# src/sim/effects/

What abilities do: `EffectRunner` lands every effect (damage, heals, Shields, statuses, moves, areas, summons) by the damage rule, and `Targeting` picks who a unit attacks.

## Files

| File | What it is |
| --- | --- |
| `effect_hits.gd` | Putting a number on a unit, for EffectRunner: a hit through crits, DEF, and Shields with its log line, the heroes' crit and echo rules, lifesteal and Engorge, heals and overheal, Shields given and spent, max HP gained and given up, and stored damage let go. |
| `effect_runner.gd` | Runs an ability's effects and writes each result to the combat log with its source. |
| `effect_targets.gd` | Who an effect reaches, for EffectRunner: its ability's target, the unit hit, the unit itself, every enemy or ally, near-target groups, the farthest, the toughest, the most targeted, the lowest on mana, and those round each ally. |
| `targeting.gd` | Who a unit attacks, and so where it walks. |
