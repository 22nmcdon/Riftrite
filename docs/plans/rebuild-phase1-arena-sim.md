# Rebuild phase 1: the arena sim (build plan)

Status: **proposal (2026-09-27), waiting for approval.** Phase 1 of `docs/plans/rebuild-build-order.md`. Design sources: `rebuild-arena.md` (the grid, movement, tanks, areas, the collapse), `rebuild-heroes.md` (mana and signature triggers), and `rebuild-enemies.md` (what enemies need from the sim). Numbers are placeholders to tune.

**Goal:** a headless combat sim on a hex board. Units move, block each other, pick targets by rule, attack in melee or at range, get pushed and pulled, fire signatures on mana or other triggers, drop warned area attacks, and are squeezed by a shrinking arena. **Done when** seeded fights repeat exactly and every move, push, and hit is in the log with its source.

**Written before phase 0** (the gut), as the build order asks. It assumes phase 0 has removed items, essences, and rows, and left stubs where the rewrites go.

## Scope

**In phase 1:**

- The hex grid, rocks, positions, movement with reservations, and pathfinding.
- Targeting rules, with sticky targets.
- Melee and ranged basic attacks, and blocking.
- Engage, Taunt, and Knockback (with a stun on collision).
- Pulls, leaps, charges, and flying.
- Area shapes (circle, line, cone, ring) with warnings.
- The slice's statuses.
- Mana, and the four signature triggers.
- The shrinking arena.
- Summons.
- Full logging, and a text dump of the board for tests and debugging.

**Not in phase 1:**

- Real hero and enemy content: the three heroes' kits and the 9 Act 1 enemies are phase 2. Phase 1 tests use small units defined inside the tests.
- Paths, vows, taste and cost, and deeds on the new sim (phase 4).
- **Lasting areas** (Arrow Storm, Night Lantern, Warding Circle, snares, hazards). Phase 4 adds them on top of shapes. Only instant, warned areas come now.
- Relics and duo bonds (phase 5). The relic runner stays stubbed from phase 0.
- The UI (phase 3) and the sim runner's placed parties (phase 2).

## Decisions this plan builds on

From the rebuild plans and the 2026-09-27 answers:

- Hexes, **8 wide × 7 tall**. Each side has a 3-row zone, with one neutral row between. One unit per hex.
- **Speed** is a stat: its number is hexes per second.
- **Nearest** means the shortest path, with ties broken by fight order.
- **Cones** widen 1, 2, 3.
- **The collapse** takes one ring every 10s from 45s. A crumbled hex deals flat damage per second.
- **Flying** passes over units, but **Engage still stops fliers**.
- **Rocks** come in phase 1.
- Integer math, a fixed 20 ticks per second, the seeded RNG only, and no Dictionary iteration that affects outcomes (CLAUDE.md rule 1).

---

## 1. The board

- **Coordinates:** `(col, row)`, where `col` is 0–7 left to right and `row` is 0–6. **Row 0 is the heroes' back row, row 6 the enemies' back row.** The heroes' zone is rows 0–2, row 3 is neutral, and the enemies' zone is rows 4–6. Data (encounters, rocks) uses these board coordinates.
- **Layout:** pointy-top hexes in horizontal rows, with odd rows shifted half a hex right ("odd-r"). The sim stores a hex as one int, `row * 8 + col`. Distance, directions, and lines are computed in cube coordinates, all integers.
- **Neighbor order:** fixed, and **forward-first for each side**. A hero looks at north-east and north-west before east and west, then south. An enemy uses the mirror image. So neither side drifts toward one flank when routes tie.
- **Directions:** the 6 hex directions. Lines, cones, charges, knockback, and pulls all **snap to the direction closest to the target** (compared with integer dot products, ties by the fixed order). That keeps them readable and integer-only.
- **Rocks:** hexes that block movement and knockback, but not attacks (no line of sight). An encounter lists them; the fight setup carries them.

## 2. What a unit is (data shape)

Heroes and enemies share one **kit** (`UnitDef`). `HeroDef` (paths, phase 4) and `EnemyDef` (threat line, archetype, phases) each wrap one. Phase 1 only reads kits from inline test data. The real files are phase 2.

```json
{
  "id": "rift_hound",
  "name": "Rift Hound",
  "stats": {"hp": 220, "atk": 16, "def": 6, "crit": 5, "atsp": 0, "speed": 2, "range": 1},
  "targeting": "nearest",
  "traits": ["flying"],
  "mana": {"max": 60, "start": 0, "per_attack": 10, "per_10_damage_taken": 0, "regen_per_s": 2},
  "basic_attack": {
    "id": "bite", "name": "Bite", "cooldown_ms": 1200,
    "effects": [{"type": "damage", "amount": 4, "target": "target", "scaling": {"atk": 6000}}]
  },
  "signature": {
    "id": "pounce", "name": "Pounce",
    "trigger": {"kind": "fight_start"},
    "targeting": "weakest_backliner", "max_range": 4,
    "effects": [{"type": "leap", "target": "target"}, {"type": "damage", "amount": 20, "target": "target"}]
  },
  "passives": []
}
```

- **Stats:** the six we have, plus **`speed`** (hexes per second) and **`range`** (the basic attack's reach in hexes; 1 = melee). Both are `UnitStats` stats, so auras and path costs can change them later.
- **`targeting`:** the unit's rule for its basic attack, and so for where it walks (section 4). A signature can have its own rule.
- **`traits`:** `engage`, `flying`, and `hop_away` for now (section 6). Each one is a code path, and the validator names the allowed ones.
- **`mana`:** optional. **A unit without it has no mana bar**, and Silence and mana drain do nothing to it.
- **`basic_attack`** and **`signature`:** these are **abilities** (`AbilityDef`), with effects in the `EffectDef` vocabulary.
- **`passives`:** the `Part` kinds that survive phase 0 (aura, ability on an event trigger, replace_status).

## 3. The tick

Each tick, in this order (resolution order = the fight's unit order: heroes in setup order, then enemies, then summons in the order they join):

1. **Collapse:** a ring's warning or crumble, and damage once per second to everyone on crumbled hexes.
2. **Statuses tick:** damage over time, and timers running out.
3. **Warned areas land** if they're due, in the order they were cast.
4. **Each standing unit acts** in resolution order:
   1. Stunned: skip to the next unit.
   2. Mana regen (unless Silenced).
   3. **Signature:** if its trigger is met and it has a valid target, it fires (see section 5).
   4. **Target:** keep or pick one (section 4).
   5. If the target is in range, the unit is standing still, and it isn't mid-step, the **basic attack** advances its cooldown and fires when ready. Otherwise it **moves** (section 4).
5. **Event effects**, read from this tick's log (the `Events` code we keep); then **phases**.
6. **Deaths:** units at 0 HP fall, and their hexes free up. Then on_kill effects, and any deaths those cause.
7. **Victory, defeat, or a tie** (180s, or both sides falling on the same tick; a tie counts as a win).

Units act one after another inside a tick, but **deaths wait until step 6**, as now. So a unit knocked to 0 this tick still acts if its turn comes later in the tick, and neither side gets an edge from going first.

- **Heroes come first in the order.** The old sim's "fires regardless of who died this tick" makes that mostly harmless. The one place it shows is **reservations**: when a hero and an enemy want the same free hex on the same tick, the hero gets it. (A proposal; see section 14.)

## 4. Movement, targeting, and blocking

### Moving

- **One hex at a time.** A step takes `step_ticks = 20 / speed` ticks (one shared rounding helper; speed 2 = 10 ticks, speed 3 = 7). Slow stretches it.
- **Reservation:** when a unit starts a step, it **reserves the next hex**. It keeps its current hex until it arrives, then frees it. While a step is under way, both hexes are blocked for everyone else, so two units never collide.
- **Pathfinding:** breadth-first search with the fixed neighbor order. Units, reserved hexes, rocks, and crumbled hexes block it (a unit standing on a crumbled hex can still leave). The goal is **any free hex from which the target is in range**. The unit takes the first step of that path, and paths again before each new step, so it reacts to a board that keeps changing.
- **No path:** the unit waits. After **1s with no path** (tuning `repath_give_up_ms`), it drops its target and picks again.
- **Units stop to attack.** A unit with its target in range doesn't move (it may finish a step already begun). A `fires_while_moving` flag on the unit (Volley Maren, phase 4) is left for later; phase 1 only reserves the field name.

### Targeting rules (`Targeting`)

| Rule | Picks | Used by (later) |
| --- | --- | --- |
| `nearest` | the enemy with the shortest path to a hex in range | most units |
| `weakest_backliner` | among enemies in their side's **back two rows**, the lowest HP%; if none stand there, the lowest HP% anywhere | Rift Hound's Pounce, flankers |
| `largest_group` | the enemy whose 2-hex circle holds the most enemies | Cinder Moth, Brand Slam, Ember Breath |
| `farthest` | the enemy farthest away (hex distance) | Bog Lurker's Drag |
| `lowest_hp_ally` | the ally lowest on HP% (the unit itself included) | Vell's Mend |
| `highest_mana` | the enemy with the most mana (units with no mana are never picked) | Gloam Witch's Hush |
| `self` | the unit itself | Hold the Line |

- Ties always go to the earlier unit in fight order.
- **Sticky:** a unit keeps its basic-attack target until the target falls, **Taunt** overrides it, or the target stays unreachable for `repath_give_up_ms`. Each pick is logged with its reason ("Rift Hound targets Maren: nearest"), so the fight can always answer "who is attacking whom, and why?"
- **Signatures pick fresh each time they fire**, with their own rule and optional `max_range`. If nothing fits, a mana signature stays full and waits.

### What makes tanks matter

- **Blocking:** units never share a hex or pass through each other (fliers aside, section 6).
- **Engage** (trait): a unit next to an engager is **Engaged** by it. **Before taking any step, an engaged unit spends `break_free_ms` (1s) breaking free.** It can't move or attack during that time, and it's logged. Once free, it can move until it's no longer next to that engager, and then the engagement ends. Coming back into contact engages it again. **Fliers break free too** (decided). Knockback or a pull out of contact ends the engagement at once.
- **Taunt** (status, with the taunter as its source): the taunted unit's target becomes the taunter while the status lasts. If a second Taunt lands, the newer one wins.

## 5. Attacks, mana, and signatures

- **Basic attack:** its cooldown runs all the time (sped up by ATSP, slowed by Slow), so a unit arriving in range with the attack ready hits at once. It fires only when its target is in range and the unit isn't moving. **Hits are instant**: the sim has no projectiles, and the UI can draw arrows.
- **Mana** (for units that have it) is kept in hundredths internally, so "1 per 10 damage" stays an integer. The data gives whole mana.
  - **Sources:** `per_attack` (each basic attack that fires), `per_10_damage_taken` (HP and Shield damage both count), `regen_per_s`, and `start`.
  - **Silence** blocks all of them. `mana_drain` is an effect type.
- **Signature triggers:**

| Trigger | Data | Fires |
| --- | --- | --- |
| `mana` | cost = `mana.max` | when the bar is full; the bar empties |
| `hp_below` | `threshold_bp` | once, the first time the unit drops below it while standing |
| `fight_start` / `at_time` | `at_ms` | once, at that moment |
| `count` | an event trigger (`on_hit_taken`, `on_heal`, `on_kill`, …), `every` | on every Nth such event |

- **`cast_ms`** (optional): the unit stands still for that long before the signature lands. Stun during a cast cancels it, and a mana signature keeps its mana. Big area attacks use **`warning_ms`** instead (section 7), so the caster doesn't have to stand still while the warning shows.
- Every fire logs `FIRE` with the ability as its source, as now.

## 6. Displacement and flying

All four displacements **move the unit instantly in the sim** and log the full path. The UI animates them. A moving unit that gets displaced loses its step and its reservation.

| Effect | What it does | Data |
| --- | --- | --- |
| `knockback` | pushes the target away from the source, straight along one hex direction | `hexes` |
| `pull` | drags the target toward the source, straight | `hexes` |
| `leap` | the source jumps to the free hex **next to its target** that is closest to where it stands, ignoring anything in between | `max_hexes`, `land_ms` (it can't act while landing) |
| `charge` | the source runs straight toward its target, up to N hexes, stopping before the first unit. If that unit is an enemy, it knocks it back | `hexes`, `knockback` |

- **Collision:** a knockback or pull that's stopped early by a unit, a rock, or the **board's edge** stops at the last free hex. **The pushed unit is Stunned** for `collision_stun_ms` (1s). If it hit a unit, that unit is stunned too. (The rebuild plans name units and rocks; counting the edge is a proposal, section 14.)
- **Pushed into a crumbled hex:** allowed. It hurts.
- **Leap with no free landing hex:** the leap fails, and it's logged. A mana signature keeps its mana.
- **Flying** (trait): a flier's path ignores units and rocks. It **only stops on a free hex**, which it reserves when it chooses its path; it can pass over occupied hexes. It can be targeted wherever it is, including over another unit. If a push leaves it over an occupied hex, it drops to the nearest free hex. **Engage still stops it** (section 4).
- **Hop away** (trait, Maren's Keep Your Distance and the Hollow Archer's step back): when an enemy **moves next to** the unit, it steps 1 hex to the free neighbor farthest from that enemy. It has `hop_cooldown_ms` (in the trait's data) and is logged. Engaged units have to break free first.

## 7. Areas and warnings

- **Shapes** (`ShapeDef`), all in hex distance:
  - `circle` (radius r: every hex within r).
  - `ring` (the hexes at exactly r).
  - `line` (length n, 1 wide, along the snapped direction).
  - `cone` (depth 3 by default; widths 1, 2, 3 along the snapped direction).
- **Anchor:** `target` (centered on the target's hex), `self`, or `target_direction` (lines and cones start next to the caster and point at the target).
- **`area` effect:** a shape, an anchor, `warning_ms`, `hits` (`enemies`, `allies`, or `all`), and nested `effects` that run on every unit standing in the area **when it lands**. The hexes are fixed when it's cast, so a warned area doesn't follow anyone.
- **Warning:** at cast, the log gets `AREA_WARNING` with the hexes and the landing tick, and the UI lights them. At the landing tick it gets `AREA_LANDED`, then one entry per unit hit. Areas without `warning_ms` land at once.
- Heroes **never step out of marked areas** (decided in the enemies plan). Placement is the answer, so movement ignores warnings.

## 8. Statuses for the slice

`statuses.json` keeps Bleed, Burn, and Poison. It drops Golden Flame, Plasma, Blight, Blind, Freeze, the item Slow, and the rest of the essence statuses. It adds new **kinds**:

| Status | Kind | Effect in the sim |
| --- | --- | --- |
| Root | `root` | can't move (can still attack and cast) |
| Stun | `stun` | skips its turn: no moving, attacking, casting, or regen (hits taken still give mana) |
| Slow | `slow` | the unit's steps and attack cooldown run `slow_bp` slower; strongest wins, no stacking |
| Taunt | `taunt` | target forced to the status's source |
| Silence | `silence` | no mana gain |
| Marked | `marked` | takes `damage_taken_bp` more damage from every source |
| Engaged | `engaged` | set and cleared by the Engage trait, never by effects; see section 4 |
| Bleed, Burn, Poison | `damage_over_time` | as now |

- Timed statuses have `duration_ms`; a new application refreshes it. **Shield** stays a unit value, not a status, as now.
- Knockback isn't a status. It's an effect (section 6), and its stun is Stun.

## 9. Rift Collapse: the shrinking arena

- **Rings are rectangular:** a hex's ring is `min(col, 7 − col, row, 6 − row)`. On 8 × 7 that gives ring 0 (the border, 26 hexes), ring 1 (18), ring 2 (10), and ring 3 (the 2 middle hexes, which never crumble).
- **Timing:** from `collapse_start_ms` (45s), one ring every `collapse_ring_ms` (10s). Each ring is **warned** `collapse_warning_ms` (3s) before it crumbles, and the warning is logged like an area's.
- **Damage:** anyone on a crumbled hex takes flat damage once per second, starting at `base` and growing per second (the current `collapse_by_act` numbers, reused). It hits Shield before HP, and never deals % of max HP.
- **Crumbled hexes block paths**, except for a unit leaving one.
- **`start_collapse` effect:** starts the collapse now if it hasn't started yet (Old Mother Ash's Last Ember).
- **Tie at 180s**, as now.

## 10. Summons

- **`summon` effect:** a kit id, a count, and where they appear: `edges` (the nearest free hexes on ring 0, closest to the anchor first), `adjacent` (free hexes next to the caster), or `hexes` (a fixed list, each falling back to the nearest free hex).
- A summoned unit joins **at the end of the fight order**, gets a unique id (`rift_pup#2`), and starts with no target and empty mana (unless its kit says otherwise). It's logged as `SUMMON` with its source.
- **Cap:** at most `max_units_per_side` (placeholder 10) standing units per side. Extra summons are dropped, and that's logged too.

## 11. The combat log

- **New kinds:** `MOVE` (from, to), `TARGET` (who, whom, and the rule or Taunt), `BREAK_FREE`, `PUSH` (knockback or pull: from, to, and what it hit), `LEAP`, `CHARGE`, `HOP`, `AREA_WARNING` (hexes, landing tick), `AREA_LANDED`, `COLLAPSE_RING` (warned or crumbled), `SUMMON`, and `MANA_DRAIN`.
- **`LogEntry` gains** `from_hex`, `to_hex`, and `hexes`. Phase 0 renames the item fields to ability fields (`source_ability`, `source_ability_name`).
- Every entry that changes the board or a unit names its source unit and ability (or "Rift Collapse", or a status). A test walks every entry of the determinism fight and checks this.
- **`ArenaDebug.render(sim)`:** a plain-text board (rocks, units by short tag, crumbled hexes, warned hexes). Tests use it to show the board when an assertion fails; it doesn't touch the fight.

## 12. Files

**New** (`src/sim/arena/`):

| File | What it holds |
| --- | --- |
| `hex_grid.gd` | board size, index ↔ (col, row) ↔ cube, neighbors in side order, distance, snapped directions, straight lines, shapes, rings |
| `pathfinder.gd` | breadth-first search over a blocked mask: first step toward any goal hex, and path length |
| `arena_state.gd` | per fight: rocks, occupancy, reservations, crumbled and warned hexes |
| `movement.gd` | steps, reservations, break free, hop away, flying |
| `displacement.gd` | knockback, pull, leap, charge, collisions |
| `areas.gd` | casting shapes, pending warned areas, landing them |
| `collapse.gd` | ring timing, warnings, crumbling, damage |
| `arena_debug.gd` | the text board |

**New elsewhere:**

- `src/sim/defs/unit_def.gd` (the shared kit), `ability_def.gd`, `mana_def.gd`, `shape_def.gd`, `trigger_def.gd` (signature triggers).
- `src/sim/state/ability_state.gd` (cooldown, event count, fired once).
- `src/sim/mana.gd`.

**Rewritten:**

- `combat_sim.gd`: the tick above.
- `effects/targeting.gd`: the rules above.
- `effects/effect_runner.gd`: damage, heal, shield, apply_status, cleanse, mana_drain, knockback, pull, leap, charge, area, summon, start_collapse.
- `defs/effect_def.gd`: targets `target`, `self`, `all_enemies`, `all_allies`, `trigger_ally`, plus the new types.
- `defs/status_def.gd`, `statuses.gd`: the new kinds.
- `defs/collapse_def.gd`, `defs/tuning_def.gd`: the new values.
- `defs/unit_stats.gd`: adds speed and range.
- `state/unit_state.gd`: hex, step, reservation, target, mana, engagement, abilities.
- `setup/unit_setup.gd`, `setup/fight_setup.gd`: positions and rocks, and validation (in your own zone, no overlaps, not on a rock).
- `log_entry.gd`: new kinds and hex fields.

**Data:** `tuning.json` gains:

- `grid` (width, height, zone rows)
- `break_free_ms`, `collision_stun_ms`, `repath_give_up_ms`, `leap_land_ms`
- `collapse_ring_ms`, `collapse_warning_ms`
- `max_units_per_side`

It keeps `collapse_start_ms`, `collapse_by_act`, `tie_ms`, `crit_damage_bp`, `crit_bp_per_point`, `atsp_bp_per_point`, and `defense_constant`. `statuses.json` is trimmed (section 8). No hero or enemy content yet.

## 13. Tests

Each rule gets its own test file under `tests/sim/`. They build tiny boards through a rewritten `sim_test_kit.gd` (`K.kit(...)`, `K.at(kit, col, row)`, `K.fight(heroes, enemies, rocks, seed)`).

| Test file | Covers |
| --- | --- |
| `test_hex_grid.gd` | coordinates both ways, distance, neighbor order per side, snapped directions, each shape's exact hexes, rings |
| `test_pathfinder.gd` | routes around units and rocks, the fixed tie-break, no route, leaving a crumbled hex |
| `test_movement.gd` | speed → ticks, reservations (two units, one hex: the earlier unit wins, no overlap ever), stop in range, Slow, Root, repath give-up |
| `test_targeting.gd` | every rule and its ties, sticky targets, Taunt overriding and ending, TARGET log lines |
| `test_attacks_and_mana.gd` | melee needs adjacency, range by hex distance, ATSP, every mana source, Silence, units with no mana |
| `test_signature_triggers.gd` | mana (bar empties), hp_below once, fight_start, at_time, count; cast_ms cancelled by Stun keeps its mana |
| `test_engage.gd` | break free takes 1s, freedom ends on leaving contact, fliers still stop, a push ends the engagement |
| `test_displacement.gd` | knockback distance and direction, collisions with a unit, a rock, and the edge (both stunned), pull, leap landing and failure, charge, a displaced mover losing its reservation |
| `test_flying.gd` | passing over units, stopping only on free hexes, dropping after a push |
| `test_areas.gd` | warnings are logged, and the area hits whoever stands there at landing, not at cast; each shape; `hits` filters |
| `test_statuses.gd` | rewritten for the new kinds, plus damage over time as now |
| `test_collapse.gd` | ring timing and warnings, damage only on crumbled hexes, flat and Shield-first, start_collapse, the 180s tie |
| `test_summons.gd` | placement per mode, fight order, the cap, the log |
| `test_arena_log.gd` | in a busy fight, every entry that changes state names a source |
| `test_determinism.gd` | rewritten: a chaotic seeded fight using everything above (plus random crits) runs twice with identical logs; a third run whose setup lists units in a different order gives a different log (proving the order is actually used) |

`test_sim_rng`, `test_fixed_math`, and `test_project_setup` stay as they are.

**Speed budget:** a 60s fight of 3 against 6 should sim in well under 100 ms headless. Pathfinding runs only when a unit is about to take a step, not every tick. `tools/sim_runner.gd` (phase 2) needs hundreds of fights at a time.

## 14. Order of work (each step: code, tests, green run, commit)

1. **Board:** `hex_grid`, `pathfinder`, `arena_debug`, and their tests. Pure functions, no sim.
2. **Skeleton fight:** kits, setups with positions and rocks, the new `CombatSim` tick, movement with reservations, `nearest` targeting, melee and ranged basic attacks, deaths, the end of the fight, and the MOVE and TARGET logs. First determinism test.
3. **Statuses:** Root, Stun, Slow, Taunt, Silence, Marked, and damage over time.
4. **Mana and signatures:** the four triggers, and cast_ms.
5. **Tanks:** Engage, and blocking checks.
6. **Displacement and flying:** knockback, pull, leap, charge, collisions, flying, and hop away.
7. **Areas:** shapes, warnings, landing, and the rest of the targeting rules.
8. **Collapse and summons:** rings, damage, start_collapse, and summons.
9. **The full determinism fight and the log audit.** Update `CLAUDE.md`'s sim rules to describe the arena.

## 15. Proposals to confirm (defaults I picked)

These aren't answered in the rebuild plans. I'll build them as written unless you say otherwise:

1. **Fight order puts heroes first.** It only matters for two units reserving the same hex on the same tick. Alternatives: alternate hero and enemy, or order by unit id alphabetically.
2. **Engage is strict:** any step at all needs a break-free first, including sliding sideways along Brannoc. That's what makes "can't walk past him" true.
3. **"Back-liner" means the back two rows of your side's zone** (rows 0–1 for heroes), wherever the units actually stand at that moment.
4. **The board's edge stops a push like a rock does** (and stuns).
5. **Leaps and pushes are instant in the sim**, with only the UI animating them. A leaper can't act for `leap_land_ms`.
6. **Fliers also pass over rocks.**
7. **Stun stops regen** but not mana from hits taken.
8. **Crumbled hexes can't be walked into** (only pushed into), so the squeeze is about space, not a choice to stand in fire.
9. **Summon cap:** 10 standing units per side.
10. **No projectiles:** ranged hits land the tick they fire.
