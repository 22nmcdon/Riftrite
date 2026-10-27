# src/sim/state/

A fight's changing state: each unit's (`UnitState`), each ability's and status's, an effect's source, and a value's breakdown for the log.

## Files

| File | What it is |
| --- | --- |
| `ability_state.gd` | An ability in a fight. |
| `effect_source.gd` | Who caused an effect: the unit and its ability; or a relic, which has no unit. |
| `status_state.gd` | One status on one unit. |
| `unit_state.gd` | One unit in a fight: where it stands on the plane, its health, its target, the route it's walking, and its abilities. |
| `value_breakdown.gd` | How one of an ability's numbers is built, kept so the UI can show base and final values side by side. |
