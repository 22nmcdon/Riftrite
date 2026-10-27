# tests/sim/arena/

The plane: the grid, walking and routes, attacks and shots, Engage, pushes, areas, Rift Collapse, summons, statuses, phases, the fight's end, shallow water, islands, and `test_arena_log.gd` (every log entry names its source; a new log kind needs a rule there).

## Files

| File | What it is |
| --- | --- |
| `test_areas.gd` | Areas and warnings: shapes, anchors, warnings, what's hit when it lands, and the log. |
| `test_arena_log.gd` | The log tells the whole story of the board: replaying every leg, stop, push, and summon from the log alone gives each unit's exact position on every tick, and every entry names its source, in a busy fight, the chaos fight, and the three heroes against... |
| `test_arena_plane.gd` | Integer geometry on the arena's plane. |
| `test_attacks.gd` | Basic attacks: reach, cooldowns, attack speed, and the numbers. |
| `test_attacks_and_mana.gd` | Mana: its sources, the cap, Silence, Stun, and drains. |
| `test_collapse.gd` | Rift Collapse: ring timing and warnings, the safe rectangle shrinking, damage only on crumbled ground, and start_collapse. |
| `test_displacement.gd` | Knockback, pull, leap, and charge: exact directions, collisions that stun, landing spots, and the log. |
| `test_encounters.gd` | Building fights from encounters and formations. |
| `test_engage.gd` | The Engage trait: held 1s when trying to reach someone else, not when fighting the engager, free until contact ends, and caught again on coming back. |
| `test_fight_end.gd` | How a fight ends. |
| `test_fight_setup.gd` | Kits and fight setups. |
| `test_flying.gd` | Flying and hop away. |
| `test_hex_grid.gd` | The placement board: flat-topped hexes in columns, 8 x 7, with 3-row zones. |
| `test_islands.gd` | The void, Act 3's board rule: the setup's checks, walkers going over a bridge, fliers crossing, landing off it, charges and hops stopping short, falls and what they set off, and the islands with their condition. |
| `test_kit_pieces.gd` | The sim pieces phase 2's kits need: an aura that holds while its holder is taunting, the on_ally_below_hp, on_interval, and on_fall passive triggers, areas in passives, heals of a share of max HP, and damage that grows with nearby allies. |
| `test_movement.gd` | Walking on the plane. |
| `test_nav_grid.gd` | Pathfinding on the plane's hidden grid, and the text board. |
| `test_passives.gd` | Passives: auras, ability passives on events, and status swaps. |
| `test_phases.gd` | Phases: entered once each as HP drops, in order, changing the kit from the next update; and the checks on reading them. |
| `test_shots.gd` | Shots in flight: 1 tick per hex, following the target, numbers fixed when fired, still landing after the shooter falls, fizzling if the target falls first. |
| `test_signature_triggers.gd` | Signatures and their triggers: mana, hp_below, fight_start, at_time, count, would_fall; Stun holding back only mana signatures; casts; picking a target. |
| `test_statuses.gd` | Statuses. |
| `test_summons.gd` | Summons: placement in each mode, the fight's order and ids, the cap of units per side, auras, the log, and the setup's checks. |
| `test_targeting.gd` | Picking targets. |
| `test_water.gd` | Shallow water, Act 2's board rule: half speed unless a unit swims or flies, routes round it when that's shorter, Burn halved on it, the on_water condition, the Steaming Ashling, and the setup's checks. |
