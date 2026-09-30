# Rebuild plan, part 2: the arena

Status: **agreed in discussion (2026-09-27), not built.** Part of the from-scratch rethink; part 1 is `docs/plans/rebuild-heroes.md`. Numbers are placeholders to tune.

**Why:** with two fixed rows, attacks simply hit the front row, so a tank only absorbs hits and never protects anyone. An arena makes tanks matter, makes placement the main tactical skill, and lets enemies be hard in fair, readable ways.

## Goals

- **Tanks protect people by standing in the way**, not only by absorbing hits.
- **Placing your heroes before the fight is the main tactical skill**, and it's where difficulty comes from.
- **Readable:** you can always tell who's attacking whom and why.
- **Deterministic and integer-only**, like the current sim.

## 1. The grid

- **Hexes, 8 wide × 7 tall, flat-topped** (decided). **The hexes are only for placing units before the fight;** the fight itself takes place on a free-moving plane (decided, section 3).
- **Your zone is the 3 rows nearest you; the enemy zone is the 3 rows nearest them.** The middle row belongs to no one.
- **One unit per hex** when placing. Every unit takes one hex, bosses included, for now.
- **Terrain:** start flat, then add a few **rocks** per encounter, each on a hex, that block movement, so each fight's layout differs. No line of sight at first (rocks don't block arrows); it adds a lot of complexity for little gain.

## 2. Placement before each fight

- **You see the enemies' positions first**, then place your three heroes anywhere in your zone.
- **Some paths add placements:** Trapper places her first 2 snares; Lanternbearer (with an upgrade) places her lantern.
- **Your last formation is remembered**, so you only adjust it.
- **The fight card previews enemy threats**, for example "a Hound will leap to your back line."

## 3. Movement and targeting

- **Units move freely**, not hex to hex, at a speed set per unit (hexes per second; a hex is the distance between two neighboring hex centers).
- **Units never overlap.** Within each tick, units are updated one after another in a fixed order with heroes first, so the sim stays deterministic. The fight itself is real-time: everyone acts at once as far as the player can see.
- **Pathfinding** takes the shortest route around other units and rocks, with a fixed tie-break. If there's no route, the unit waits.
- **Default targeting: the nearest enemy it can reach.** Once a unit picks a target, it keeps it until the target dies, a taunt pulls it away, or the target becomes unreachable.
- **Some units target differently:** Vell heals the ally lowest on HP; enemy flankers go for the weakest back-liner. Targeting rules are data on the unit.
- **Units stop to attack.** Melee has to be touching; ranged units fire from their range, and **their shots travel** (about 1 tick per hex) instead of landing at once. Units that can fire while moving (Volley Maren, once transformed) say so in their data.

## 4. What makes tanks matter

- **Blocking:** nobody moves through anyone else. A tank standing in a gap physically closes it.
- **Engage (Brannoc's trait):** an enemy next to him that's trying to reach someone else can't move past him for 1s.
- **Taunt:** pulls enemies' targeting onto him.
- **Knockback:** pushes a unit a number of hexes. If it hits another unit or a rock, it's stunned.

A good formation (Brannoc in the lane, Maren behind him) keeps a melee enemy off Maren. A bad one (Maren exposed on a flank) gets her killed.

## 5. Area shapes and statuses

- **Shapes:** circle (radius), line, cone (widening 1, 2, 3 hexes), and ring, all measured in hexes on the plane.
- **Warnings:** the ground a big area attack will hit lights up briefly before it lands, so it's always clear why someone got hit.
- **Statuses for the slice (kept small):**

| Status | What it does |
| --- | --- |
| **Root** | can't move |
| **Slow** | moves and attacks slower |
| **Stun** | can't do anything |
| **Knockback** | pushed a number of hexes |
| **Taunt** | must target the taunter |
| **Engaged** | must break free to walk away |
| **Marked** | takes more damage from everyone |
| **Bleed** | damage over time |
| **Burn, Poison** | enemy damage over time (Lanternbearer cleanses these) |
| **Shield** | absorbs damage before HP |
| **Silence** | no mana gain |

## 6. Where difficulty comes from

The arena has to support enemies that are hard because of positioning, not bigger numbers:

- **Flankers** leap to your back line.
- **Chargers** knock your tank out of position.
- **Casters** drop area attacks on groups that stand bunched up.
- **Ranged packs** outrange Maren.
- **Swarms** outnumber you and go around your tank.

Enemies get their own part of the plan.

## 7. Rift Collapse: the arena shrinks

- **At 45s, the arena's outer ring starts crumbling inward**, one ring at a time (the rings of the placement grid).
- **Anyone standing on crumbled ground takes damage.** ~~Nobody can walk onto it, but a push can put them there.~~ **Changed 2026-09-30 (`relics/README.md`, Decisions): crumbled ground is walkable.** It's just crumbling tiles: standing on it deals flat damage every second (15, a placeholder) to heroes and enemies alike, and only rocks wall a target off. Not built yet (phase 5c).
- Fights still end, but through positioning: slow, defensive teams get squeezed toward the middle, into each other's area attacks.
- This replaces the flat damage ramp. A fight still running at **180s is a tie, and a tie counts as a win.**

## 8. What it means for the code

- The combat sim gets a **spatial layer**: positions on a plane, movement, pathfinding, shots in flight, areas, knockback, and the shrinking arena.
- **Carried over:** effects, statuses, the combat log (every move and push is logged with its source), determinism, and integer math.
- **Replaced:** front-row and back-row targeting (`enemy_front`, `enemy_back`, and the row targets).
- **UI:** a hex placement screen, an open arena for the fight, area warnings, shots in flight, and movement animation.
- It's the biggest single piece of work in the rebuild, so it gets its own build plan.

## Decisions (2026-09-27)

- **Movement speed is a stat** (`speed`). Its number is hexes per second; the sim turns it into ticks per step.
- **"Nearest" means the shortest path**, not straight hex distance: an enemy behind a wall of units counts as farther away. Ties go to the unit that comes first in the fight's order.
- **A cone widens as it goes:** 1 hex, then 2, then 3 (3 hexes deep).
- **Rift Collapse, first numbers:** from 45s, one rectangular ring of the board crumbles every 10s. Standing on a crumbled hex deals flat damage each second (tuning values).
- **Flying units pass over other units**, but **Engage still stops them**: an engaged flier has to break free like anyone else.
- **Rocks come in phase 1.**

Answers to the phase 1 plan's proposals (2026-09-27; the details are in `rebuild-phase1-arena-sim.md`):

- **Flat-top hexes**, not pointy-top.
- **Hexes are for placement only.** Fights happen on a free-moving plane.
- **Heroes come first in the fight order** (it settles who gets a contested gap).
- **Engage** holds a unit for 1s when it's trying to get past the engager to someone else.
- **Back-liners** are the units that **started** in their side's back two rows; it's fixed at the start of the fight.
- **The arena's edge stops a push** like a rock does, and stuns.
- **Leaps and pushes are instant in the sim;** only the UI animates them.
- **Fliers pass over rocks** as well as units.
- **Stun doesn't stop mana gain,** but a stunned unit can't fire its mana signature.
- ~~**Crumbled ground can't be walked into,** only pushed into.~~ **Changed 2026-09-30:** walkable, damaging whoever stands on it (above, section 7).
- **Up to 30 standing units per side**, since summons may be small and frequent.
- **Ranged hits travel,** about 1 tick per hex.
- **Rocks keep their size for now** (1 hex across): one missing rock in a row is too narrow to walk through, and it takes two. You'll judge it in playtesting.
- **Shots follow their target** and can't miss; the numbers are fixed when fired, and the shooter falling doesn't stop the arrow. A shot whose target falls first fizzles.
- **Melee lands the moment the attack finishes.** How long an attack takes comes from the unit's attack speed, not a weapon type.
- **A unit is inside an area if its center is** (whichever side most of it is on).
- **Nothing snaps to hexes in the fight:** pushes, pulls, charges, lines, and cones go exactly their number of hexes along the line from the unit.
- **Stun only holds back mana signatures.** Other signature triggers (an HP threshold, "when he hits 1 HP") still fire while stunned.
- **Engage reaches 1 hex** from the engager. Every unit is the same size, for now.

## Open questions

- **Grid size:** is 8 × 7 right with 3 heroes against 3–6 enemies? Playtesting decides.
- **Large units:** should bosses ever take more than one hex?
