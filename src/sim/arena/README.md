# src/sim/arena/

The plane and what moves on it: the hex grid and the free plane, walking and routes (`NavGrid`), Engage, pushes and pulls, shots, warned areas and zones, Rift Collapse, summons, snares, walls, Guard, links, shallow water, and islands over the void.

## Files

| File | What it is |
| --- | --- |
| `areas.gd` | Area effects. |
| `arena_debug.gd` | A plain-text picture of the arena, one character per nav cell, for tests and debugging. |
| `arena_plane.gd` | Integer geometry on the arena's plane. |
| `collapse.gd` | Rift Collapse, the shrinking arena. |
| `displacement.gd` | Knockback, pull, leap, and charge. |
| `engage.gd` | The Engage trait: a tank that holds enemies in place. |
| `guards.gd` | Guard: a unit with a guard passive takes a share of the hits on its allies. |
| `hex_grid.gd` | The placement board: flat-topped hexes in columns, odd columns shifted half a hex toward the enemy. |
| `islands.gd` | The void, Act 3's board rule. |
| `links.gd` | Linked Shields: a unit with a link passive links every ally holding one of its Shields. |
| `movement.gd` | Walking on the plane. |
| `nav_grid.gd` | Pathfinding on the plane: a hidden grid of square cells that nothing snaps to. |
| `shots.gd` | Shots in flight: an attack from 2 or more hexes away flies for 1 tick per hex and follows its target, so it can't miss. |
| `snares.gd` | Snares: a snare lies on the plane until the first enemy of its owner walks into it. |
| `summons.gd` | Summons: the summon effect brings new units of a kit the fight's setup lists onto the caster's side. |
| `walls.gd` | Walls that stop shots. |
| `water.gd` | Shallow water, Act 2's board rule. |
