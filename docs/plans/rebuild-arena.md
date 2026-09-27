# Rebuild plan, part 2: the arena

Status: **agreed in discussion (2026-09-27), not built.** Part of the from-scratch rethink; part 1 is `docs/plans/rebuild-heroes.md`. Numbers are placeholders to tune.

**Why:** with two fixed rows, attacks simply hit the front row, so a tank only absorbs hits and never protects anyone. An arena makes tanks matter, makes placement the main tactical skill, and lets enemies be hard in fair, readable ways.

## Goals

- **Tanks protect people by standing in the way**, not only by absorbing hits.
- **Placing your heroes before the fight is the main tactical skill**, and it's where difficulty comes from.
- **Readable:** you can always tell who's attacking whom and why.
- **Deterministic and integer-only**, like the current sim.

## 1. The grid

- **Hexes, 8 wide × 7 tall.**
- **Your zone is the 3 rows nearest you; the enemy zone is the 3 rows nearest them.** The middle row belongs to no one.
- **One unit per hex.** Every unit takes one hex, bosses included, for now.
- **Terrain:** start flat. Once the basics work, add a few **rocks** per encounter that block movement, so each fight's layout differs. No line of sight at first (rocks don't block arrows); it adds a lot of complexity for little gain.

## 2. Placement before each fight

- **You see the enemies' positions first**, then place your three heroes anywhere in your zone.
- **Some paths add placements:** Trapper places her first 2 snares; Lanternbearer (with an upgrade) places her lantern.
- **Your last formation is remembered**, so you only adjust it.
- **The fight card previews enemy threats**, for example "a Hound will leap to your back line."

## 3. Movement and targeting

- **Units move one hex at a time**, at a speed set per unit (hexes per second, converted to ticks).
- **A unit reserves the hex it's moving into**, so two units never collide. Ties are settled in a fixed order (by unit id), so the sim stays deterministic.
- **Pathfinding** takes the shortest route around other units and rocks (breadth-first, with a fixed neighbor order). If there's no route, the unit waits.
- **Default targeting: the nearest enemy it can reach.** Once a unit picks a target, it keeps it until the target dies, a taunt pulls it away, or the target becomes unreachable.
- **Some units target differently:** Vell heals the ally lowest on HP; enemy flankers go for the weakest back-liner. Targeting rules are data on the unit.
- **Units stop to attack.** Melee has to be adjacent; ranged units fire from their range. Units that can fire while moving (Volley Maren, once transformed) say so in their data.

## 4. What makes tanks matter

- **Blocking:** nobody moves through anyone else. A tank standing in a gap physically closes it.
- **Engage (Brannoc's trait):** enemies next to him must spend 1s breaking free to walk away from him.
- **Taunt:** pulls enemies' targeting onto him.
- **Knockback:** pushes a unit a number of hexes. If it hits another unit or a rock, it's stunned.

A good formation (Brannoc in the lane, Maren behind him) keeps a melee enemy off Maren. A bad one (Maren exposed on a flank) gets her killed.

## 5. Area shapes and statuses

- **Shapes:** circle (radius), line, cone (a 3-hex arc), and ring, all measured in hex distance.
- **Warnings:** the hexes a big area attack will hit light up briefly before it lands, so it's always clear why someone got hit.
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

- **At 45s, the outer ring of hexes starts crumbling inward**, one ring at a time.
- **Anyone standing on a crumbling hex takes damage.**
- Fights still end, but through positioning: slow, defensive teams get squeezed toward the middle, into each other's area attacks.
- This replaces the flat damage ramp. A fight still running at **180s is a tie, and a tie counts as a win.**

## 8. What it means for the code

- The combat sim gets a **spatial layer**: positions, movement, pathfinding, reservations, areas, knockback, and the shrinking arena.
- **Carried over:** effects, statuses, the combat log (every move and push is logged with its source), determinism, and integer math.
- **Replaced:** front-row and back-row targeting (`enemy_front`, `enemy_back`, and the row targets).
- **UI:** a hex board, a placement screen, area warnings, and movement animation.
- It's the biggest single piece of work in the rebuild, so it gets its own build plan.

## Open questions

- **Grid size:** is 8 × 7 right with 3 heroes against 3–6 enemies? Playtesting decides.
- **When rocks arrive:** in the first build, or after the flat arena works?
- **Large units:** should bosses ever take more than one hex?
- **Collapse numbers:** how often a ring crumbles, and how much damage it deals.
