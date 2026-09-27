# Rebuild phase 1: the arena sim (build plan)

Status: **approved (2026-09-27), after two rounds of answers; phase 0 is done, so this is next.** Phase 1 of `docs/plans/rebuild-build-order.md`. Design sources: `rebuild-arena.md` (placement, movement, tanks, areas, the collapse), `rebuild-heroes.md` (mana and signature triggers), and `rebuild-enemies.md` (what enemies need from the sim). Numbers are placeholders to tune.

**The big change in this revision:** hexes are only for **placement**. Once the fight starts, units move freely on a flat plane. So there are no reservations, no hex-by-hex steps, and no snapping to six directions. Distances are still counted in hexes, because that's how every design doc talks about them.

**Goal:** a headless combat sim on a free plane. Units start on hex centers, then walk, block each other, pick targets by rule, and attack in melee or with shots that fly. They also get pushed and pulled, fire signatures on mana or other triggers, drop warned area attacks, and are squeezed by a shrinking arena. **Done when** seeded fights repeat exactly, and every move, push, shot, and hit is in the log with its source.

**Written before phase 0** (the gut), as the build order asks. **What phase 0 left** (`rebuild-build-order.md`, Decisions):
- **Kept:** the data reader, RNG, fixed math, the combat log and `LogEntry` (already `source_ability` / `source_ability_name`), `EffectSource`, `FightResult` (outcome, end tick, log, errors), `ValueBreakdown`, `UnitStats`, `EffectDef` and `AuraDef` (no item targets, charges, row targets, keywords, or multi-strike), `StatusDef` (damage over time only), `TuningDef`, `CollapseDef`, and a `ContentDb` that loads `tuning.json` and `statuses.json`.
- **Removed, not stubbed:** every piece of the old row-based sim that couldn't run without items: `CombatSim`, `EffectRunner`, `Targeting`, `Statuses`, `Events`, `UnitState`, `UnitSetup`, `FightSetup`, the relic runner, `SpecializationDef.Part`, `PhaseDef`, and the test kit.

So everything this plan calls **rewritten** is written fresh, using the old version (in git history before the gut) as a reference. The pieces the old sim already had that phase 1 needs back:
- **`Events`** comes back in step 4 (the `count` trigger and event passives), adapted from abilities instead of items.
- **The `Part` kinds** (aura, ability on an event trigger, replace_status) come back in step 4 as a `PartDef`.
- **`PhaseDef`** comes back on top of `PartDef` in step 8, so enemies can have phases in phase 2.

## Scope

**In phase 1:**

- The placement grid, rocks, and the plane.
- Positions, movement, blocking, and pathfinding.
- Targeting rules, with sticky targets.
- Melee attacks, and ranged attacks as flying shots.
- Engage, Taunt, and Knockback (with a stun on collision).
- Pulls, leaps, charges, hops, and flying.
- Area shapes (circle, line, cone, ring) with warnings.
- The slice's statuses.
- Mana, and the signature triggers (mana, HP threshold, a set time, a count, and would-fall).
- The shrinking arena.
- Summons.
- Full logging, and a text dump of the board for tests and debugging.

**Not in phase 1:**

- Real hero and enemy content: the three heroes' kits and the 9 Act 1 enemies are phase 2. Phase 1 tests use small units defined inside the tests.
- Paths, vows, taste and cost, and deeds on the new sim (phase 4).
- **Lasting areas and walls** (Arrow Storm, Night Lantern, Warding Circle, snares, Hearthwall, hazards). Phase 4 adds them on top of shapes. Only instant, warned areas come now.
  - Flying shots are built so a wall can stop one in the air later.
- Relics and duo bonds (phase 5). The relic runner comes back then.
- The UI (phase 3) and the sim runner's placed parties (phase 2).

## Decisions this plan builds on

From the rebuild plans:

- The placement board is **8 wide × 7 tall**. Each side has a 3-row zone, with one neutral row between them, and one unit per hex.
- **Speed** is a stat: its number is hexes per second.
- **Nearest** means the shortest path, with ties broken by fight order.
- **Cones** widen 1, 2, 3.
- **The collapse** takes one ring every 10s from 45s. Standing on crumbled ground deals flat damage per second.
- **Flying** passes over units, but **Engage still stops fliers**.
- **Rocks** come in phase 1.
- Integer math, a fixed 20 ticks per second, the seeded RNG only, and no Dictionary iteration that affects outcomes (CLAUDE.md rule 1).

The first round of answers on this plan (2026-09-27):

1. **Flat-top hexes**, not pointy-top.
2. **Hexes are only for the setup.** The fight takes place on a free-moving plane.
3. **Heroes come first in the fight order.**
4. **Engage:** a unit next to an engager can't move past it for 1s when it's trying to reach someone else.
5. **"Back-liner"** means a unit that **started** in its side's back two rows. It's fixed at the start and doesn't change during the fight.
6. **The board's edge stops a push** like a rock does, and stuns.
7. **Leaps and pushes are instant in the sim.** Only the UI animates them.
8. **Fliers pass over rocks too.**
9. **Stun doesn't stop mana gain,** but a stunned unit can't fire a mana signature.
10. **Crumbled ground can't be walked into,** only pushed into.
11. **Summon cap:** 30 standing units per side, because small summons may spawn often.
12. **Ranged hits travel:** a shot takes about 1 tick per hex.

The second round (2026-09-27):

13. **Every unit is the same size** for now.
14. **Shots follow their target** and can't miss. One whose target falls first fizzles.
15. **A shot's numbers are fixed when it's fired,** and the shooter falling doesn't make the arrow disappear.
16. **Melee lands the moment the attack finishes.** How long an attack takes comes from the unit's attack speed (a hammer-wielder attacks slower than a dagger-wielder), never from a weapon type.
17. **A unit is inside an area if its center is,** so whichever side most of it is on decides.
18. **Nothing snaps:** a push, pull, charge, line, or cone goes exactly its number of hexes along the line from the unit.
19. **Stun only holds back mana signatures.** Other triggers still fire while the unit is stunned: Brannoc dropping below 30% HP, or "when he hits 1 HP, he can't fall for 1s", has to work even if he's stunned.
20. **The collapse shrinks a rectangle** along the old hex rings, for now.
21. **Engage reaches 1 hex** from the engager.
22. **The speed budget** is under 100 ms for a 60s fight of 3 against 6.

---

## 1. Placement and the plane

### The placement grid (setup only)

- **Coordinates:** `(col, row)`, where `col` is 0–7 left to right and `row` is 0–6.
  - **Row 0 is the heroes' back row**, and row 6 the enemies' back row.
  - The heroes' zone is rows 0–2, row 3 is neutral, and the enemies' zone is rows 4–6.
  - Data (encounters, rocks, summon spots) uses these coordinates.
- **Layout:** flat-top hexes in **columns**, with odd columns shifted half a hex toward the enemy ("odd-q"). The setup stores a hex as one int, `row * 8 + col`.
- **Validation:** each unit stands in its own zone, no two share a hex, and none stands on a rock.

### The plane (the fight)

- **Units:** at the fight's start, each unit stands on its hex's center. From then on it has a free position `(x, y)`, in integers.
- **Scale:** **1 hex = 1000 units**, which is the distance between two neighboring hex centers.
  - A hex's center sits at `x = col × 866 + 500` and `y = row × 1000 + 500`, plus 500 more for odd columns.
  - 866 is 1000 × cos 30°. That makes neighbors in the same column exactly 1000 apart, and neighbors in the next column 999.98 apart. That's close enough, and it stays integer.
- **The arena's edge** is the rectangle around the hex centers, half a hex beyond the outermost ones.
- **Units are circles**, all with radius **400** (0.4 hex) for now. No two units overlap, so two neighbors on the grid start with a 200 gap between them, which is too narrow to walk through.
- **Rocks** are circles of radius **500** on a hex center. Rocks on neighboring hexes touch, so a row of rocks is a wall. Rocks block movement and pushes, but not attacks (no line of sight).
- **What gets through (built in step 1):**
  - **Units:** two units on neighboring hexes leave 200 between them, so nobody passes. One empty hex between two units leaves at least 932, so a unit (800 across) fits through.
  - **Rocks:** they're bigger. One missing rock in a row of rocks leaves only 732, so a unit can't pass. It takes two missing rocks.
  - **At the arena's edge:** a rock one hex in from the edge leaves too little room to pass behind it.
- **Distances** are straight-line, computed with a shared integer square root (`FixedMath.isqrt`) and compared squared where possible. Directions are integer vectors scaled to length 1000.

## 2. What a unit is (data shape)

Heroes and enemies share one **kit** (`UnitDef`). `HeroDef` (paths, phase 4) and `EnemyDef` (threat line, archetype, phases) each wrap one. Phase 1 only reads kits from inline test data; the real files are phase 2.

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

- **Stats:** the six we have, plus two new ones. Both are `UnitStats` stats, so auras and path costs can change them later.
  - **`speed`:** hexes per second.
  - **`range`:** the basic attack's reach in hexes. 1 means melee.
- **`targeting`:** the unit's rule for its basic attack, and so for where it walks (section 4). A signature can have its own rule.
- **`traits`:** `engage`, `flying`, and `hop_away` for now (section 6). Each one is a code path, and the validator names the allowed ones.
- **`mana`:** optional. **A unit without it has no mana bar**, and Silence and mana drain do nothing to it.
- **`basic_attack`** and **`signature`** are **abilities** (`AbilityDef`), with effects in the `EffectDef` vocabulary.
  - An ability with reach 2 or more fires a **shot** (section 5). An ability can say `"shot": false` to land at once, for example a beam.
- **`passives`:** `Part` kinds (aura, ability on an event trigger, replace_status), rebuilt as `PartDef` in step 4.

## 3. The tick

Each tick runs these steps in order. Resolution order is the fight's unit order: heroes in setup order, then enemies, then summons in the order they join.

1. **Collapse:** a ring's warning or crumble, and damage once per second to everyone on crumbled ground.
2. **Statuses tick:** damage over time, and timers running out.
3. **Shots land** if they're due, in the order they were fired.
4. **Warned areas land** if they're due, in the order they were cast.
5. **Each standing unit acts**, in resolution order:
   1. Mana regen (unless Silenced).
   2. **Signature:** if its trigger is met and it has a valid target, it fires (section 5). A stunned unit can fire any signature except a mana one.
   3. **Stunned:** stop here.
   4. **Target:** keep the current one or pick a new one (section 4).
   5. **Attack or move:**
      - If the target is in range and the unit isn't being displaced, it stands still. Its **basic attack** fires when its cooldown is ready.
      - Otherwise, it **moves** (section 4).
6. **Event effects**, read from this tick's log (`Events`, rebuilt from the old sim's); then **phases**.
7. **Deaths:** units at 0 HP fall, unless Undying holds them or a `would_fall` signature saves them. Then on_kill effects run, and any deaths those cause.
8. **Victory, defeat, or a tie:** a fight still running at 180s is a tie, as is both sides falling on the same tick. A tie counts as a win.

- **Deaths wait until step 7**, as now. A unit knocked to 0 this tick still acts if its turn comes later in the tick, so neither side gets an edge from going first.
- **Movement is resolved one unit at a time,** each against the positions everyone else already has. So two units can never overlap. When a hero and an enemy want the same gap on the same tick, the hero gets it (decided).

## 4. Movement, targeting, and blocking

### Moving

- **Speed:** a unit covers `speed × 1000 / 20` units per tick (speed 2 = 100 per tick). Slow reduces it.
- **Straight when it can:** if the straight way to a spot in range of its target is clear, the unit walks straight at it.
- **Around when it must:** otherwise it finds a path and walks along it, straight between the path's corners.
  - **Pathfinding** runs on a **hidden grid of eighth-hex cells** (125 across, 57 × 60). It isn't a hex grid, and nothing snaps to it. (Quarter-hex cells were planned, but they miss the one-hex gap between two staggered units, a corridor only 132 wide.)
  - **Blocked cells:** a cell is blocked if the walker standing on its center would overlap a unit, a rock, crumbled ground, or the edge. The test is exact, never optimistic, so a path never leads into a gap the walker can't fit. Cells are only checked when a search reaches them. The walker's own target doesn't block cells, so it can reach it.
  - **The search** is A* with integer costs (125 straight, 177 diagonal, never cutting past a blocked cell) and a fixed neighbor order, forward-first for each side (the enemies' order is the heroes' turned around). So neither side drifts toward one flank when routes tie.
    - Its estimate is the larger of the x and y distances to the target, less the reach.
    - `nearest` uses the same search against every enemy at once, and keeps going until no closer tie is possible.
  - **Its goal** is any free cell from which the target is in range.
  - **Leaving crumbled ground:** a walker standing on crumbled ground may cross crumbled cells, so it can always get back to safe ground.
- **Repathing:** a unit keeps its path until it's blocked, its target changes, or 0.5s passes (`repath_ms`). The board keeps changing, so it looks again regularly.
- **Straight or around (built in step 2):** when it plans, the unit sweeps its circle along the straight line to the point where its target would be in reach. If nothing is in the way it walks straight at the target; otherwise it asks the pathfinder.
- **Blocked:** if the next piece of movement would overlap anything, the unit first tries to **slide**: it drops the part of the step heading into the circle it hit and keeps the rest. That lets it brush past what a straight leg grazes. If the slide doesn't fit either, it doesn't move this tick and repaths on its next turn. A slide is logged as a leg of its own, one tick long.
- **No path:** the unit waits. After **1s with no path** (`repath_give_up_ms`), it drops its target and picks again.
- **Units stop to attack.** A unit whose target is in range stands still. A `fires_while_moving` flag (Volley Maren, phase 4) is left for later; phase 1 only reserves the field name.

### Range

- **In range** means the centers are at most `range × 1000` apart.
- Two touching units are 800 apart, so melee (range 1) works when they touch or nearly touch.
- A ranged unit with range 4 fires from up to 4000 away.

### Targeting rules (`Targeting`)

| Rule | Picks | Used by (later) |
| --- | --- | --- |
| `nearest` | the enemy with the shortest path to a spot in range | most units |
| `weakest_backliner` | among enemies that **started** in their side's back two rows, the lowest HP%; if none of them stand, the lowest HP% anywhere | Rift Hound's Pounce, flankers |
| `largest_group` | the enemy with the most enemies within 2 hexes of it | Cinder Moth, Brand Slam, Ember Breath |
| `farthest` | the enemy farthest away (straight line) | Bog Lurker's Drag |
| `lowest_hp_ally` | the ally lowest on HP% (the unit itself included) | Vell's Mend |
| `highest_mana` | the enemy with the most mana (units with no mana are never picked) | Gloam Witch's Hush |
| `self` | the unit itself | Hold the Line |

- **Ties** always go to the earlier unit in fight order.
- **One search, every distance:** a single search from the unit gives its path length to every enemy, so `nearest` costs one search per pick.
- **Sticky:** a unit keeps its basic-attack target until one of these happens:
  - the target falls
  - a **Taunt** overrides it
  - the target stays unreachable for `repath_give_up_ms`
- **Each pick is logged with its reason** ("Rift Hound targets Maren: nearest"). The fight can always answer "who is attacking whom, and why?"
- **Signatures pick fresh each time they fire**, with their own rule and optional `max_range`. If nothing fits, a mana signature stays full and waits.

### What makes tanks matter

- **Blocking:** units never overlap or pass through each other (fliers aside, section 6).
- **Engage** (trait): a unit whose center is within `engage_reach` (1 hex, 1000) of an engager is next to it. How it works:
  - **Holding:** a unit next to an engager whose target is **someone else** has to spend `break_free_ms` (1s) breaking free before it can move (decided). It can't move during that time, and it's logged. It can still attack if its target is already in range.
  - **Attacking the engager:** a unit whose target *is* the engager isn't held; it just fights.
  - **Once free:** the unit can move until it's no longer next to that engager, and then the engagement ends. Coming back into contact engages it again.
  - **Fliers break free too** (decided).
  - **Displacement:** a knockback or pull out of contact ends the engagement at once.
- **Taunt** (status, with the taunter as its source): the taunted unit's target becomes the taunter while the status lasts. If a second Taunt lands, the newer one wins.

## 5. Attacks, shots, mana, and signatures

- **Basic attack:** its cooldown runs all the time, sped up by ATSP and slowed by Slow. So a unit arriving in range with the attack ready hits at once. It fires only when its target is in range and the unit is standing still.
- **Shots** (decided: ranged hits travel):
  - An attack with reach 2 or more fires a **shot**. It flies for `ceil(distance / 1000)` ticks, that is 1 tick per hex, at least 1.
  - The shot **follows its target**, so it can't miss or be dodged.
  - **The numbers are set when it's fired:** damage, crit, and the attacker's stats. It still lands if the attacker falls first.
  - **If the target falls before it lands**, the shot fizzles, and that's logged.
  - **Melee (reach 1) lands at once,** the moment the attack finishes (decided). How long an attack takes is the unit's attack speed: its basic attack's cooldown and ATSP.
  - The log gets `SHOT` when it's fired and the hit when it lands, so the UI can draw the arrow in flight.
- **Mana** (for units that have it) is kept in hundredths internally, so "1 per 10 damage" stays an integer. The data gives whole mana.
  - **Sources:** `per_attack` (each basic attack that fires), `per_10_damage_taken` (HP and Shield damage both count), `regen_per_s`, and `start`.
  - **Silence** blocks all of them. `mana_drain` is an effect type.
  - **Stun doesn't stop mana gain** (decided). A stunned unit still regenerates and still gains mana from hits.
- **Signature triggers:**

| Trigger | Data | Fires |
| --- | --- | --- |
| `mana` | cost = `mana.max` | when the bar is full; the bar empties |
| `hp_below` | `threshold_bp` | once, the first time the unit drops below it while standing |
| `fight_start` / `at_time` | `at_ms` | once, at that moment |
| `count` | an event trigger (`on_hit_taken`, `on_heal`, `on_kill`, …), `every` | on every Nth such event |
| `would_fall` | — | once, the first time the unit would fall: it's left at 1 HP instead, and the signature fires (proposed, section 15) |

- **Stun only holds back mana signatures** (decided). A full mana bar waits and fires once the stun ends. Every other trigger fires even while the unit is stunned, so a tank's last stand still happens when he's stunned.
- **`cast_ms`** (optional, **mana signatures only**; the validator refuses it on other triggers): the unit stands still for that long before the signature lands. A stun during the cast cancels it, and the signature keeps its mana.
- Big area attacks use **`warning_ms`** instead (section 7), so the caster doesn't have to stand still while the warning shows.
- Every fire logs `FIRE`, with the ability as its source, as now.

## 6. Displacement and flying

All the displacements **move the unit instantly in the sim** and log the start and end points (decided). The UI animates them. A unit that gets displaced loses its path and repaths on its next turn.

| Effect | What it does | Data |
| --- | --- | --- |
| `knockback` | pushes the target straight away from the source | `hexes` |
| `pull` | drags the target straight toward the source, stopping when it touches the source | `hexes` |
| `leap` | the source jumps to a free spot touching its target, the one closest to where it stands, ignoring anything in between | `max_hexes`, `land_ms` (it can't act while landing) |
| `charge` | the source runs straight at its target, up to N hexes, stopping when it touches the first unit in the way. If that unit is an enemy, it knocks it back | `hexes`, `knockback` |

- **Directions are exact** (decided): the unit goes its number of hexes along the line from source to target, with no snapping. If two units stand on the same point, the push goes straight forward for the source's side.
- **Collision:** a push is swept along its line in fixed small steps (50 units) and stops at the last clear point.
  - Anything stops it: a unit, a rock, or **the arena's edge** (decided).
  - **If it's stopped early, the pushed unit is Stunned** for `collision_stun_ms` (1s). If it hit a unit, that unit is stunned too.
- **Pushed onto crumbled ground:** allowed. It hurts.
- **Leap spots:** the candidates are 12 fixed points around the target, each 800 from its center. The first free one closest to the leaper wins.
  - If none is free, the leap fails, and that's logged. A mana signature keeps its mana.
- **Flying** (trait):
  - A flier **moving** ignores units and rocks (decided), and nothing blocks on it.
  - A flier **stopping** (to attack) has to stop on a free spot. If it's over someone, it keeps going to the nearest free spot that's still in range. A stopped flier blocks like anyone.
  - It can be targeted wherever it is.
  - If a push leaves it over another unit, it drops to the nearest free spot.
  - **Engage still stops it** (section 4).
- **Hop away** (trait, Maren's Keep Your Distance and the Hollow Archer's step back):
  - When an enemy comes within 1 hex, the unit hops 1 hex straight away from that enemy. The hop is instant, and stops early at anything in the way, with no stun: it's the unit's own move.
  - It has `hop_cooldown_ms` (in the trait's data) and is logged.
  - Units held by Engage have to break free first.

## 7. Areas and warnings

- **Shapes** (`ShapeDef`), measured in hexes (× 1000) on the plane. **A unit is hit if its center is inside** (decided), so whichever side most of it is on decides.
  - `circle` (radius r): within r.
  - `ring` (radius r): between r − ½ and r + ½.
  - `line` (length n): 1 hex wide, from the caster's edge along the aim.
  - `cone` (depth 3 by default): widens evenly from 1 hex wide at the caster to 3 hexes wide at its end, so it's 1, 2, 3 as decided.
- **Anchor:**
  - `target`: centered where the target stands.
  - `self`: centered on the caster.
  - `target_direction`: lines and cones start at the caster and aim straight at the target.
- **`area` effect:** a shape, an anchor, `warning_ms`, `hits` (`enemies`, `allies`, or `all`), and nested `effects`. The nested effects run on every unit inside the area **when it lands**. Where it lands is fixed when it's cast, so a warned area doesn't follow anyone.
- **Warning:** at cast, the log gets `AREA_WARNING` with the shape, where it is, and the landing tick, and the UI draws it. At the landing tick, the log gets `AREA_LANDED`, then one entry per unit hit. Areas without `warning_ms` land at once.
- Heroes **never step out of marked areas** (decided in the enemies plan). Placement is the answer, so movement ignores warnings.

## 8. Statuses for the slice

`statuses.json` keeps Bleed, Burn, and Poison. It drops Golden Flame, Plasma, Blight, Blind, Freeze, the item Slow, and the rest of the essence statuses. It adds new **kinds**:

| Status | Kind | Effect in the sim |
| --- | --- | --- |
| Root | `root` | can't move (can still attack and cast) |
| Stun | `stun` | can't move, attack, or fire mana signatures; mana still comes in, and other signature triggers still fire |
| Undying | `undying` | HP can't drop below 1 while it lasts; each save is logged (proposed, section 15) |
| Slow | `slow` | the unit moves and its attack cooldown runs `slow_bp` slower; the strongest Slow wins, no stacking |
| Taunt | `taunt` | target forced to the status's source |
| Silence | `silence` | no mana gain |
| Marked | `marked` | takes `damage_taken_bp` more damage from every source |
| Engaged | `engaged` | set and cleared by the Engage trait, never by effects; see section 4 |
| Bleed, Burn, Poison | `damage_over_time` | as now |

- Timed statuses have `duration_ms`, and a new application refreshes it.
- **Shield** stays a unit value, not a status, as now.
- Knockback isn't a status. It's an effect (section 6), and its stun is Stun.
- **Built in step 3** (`Statuses`, `StatusState`; Undying comes with step 4 and Engaged with step 5):
  - A timed status lasts from the tick it lands until `ends_at`, then ends at the start of that tick. An `apply_status` effect can give its own `duration_ms`; otherwise the status's own duration is used. A new application refreshes the timer and becomes the status's source.
  - Root and Stun both stop the unit where it stands (the log gets a STOP, "rooted" or "stunned"). A stunned unit's attack cooldown **waits** rather than running on. Silence has nothing to stop until mana arrives in step 4.
  - Slow scales both the step length and the cooldown's rate by `10000 − slow_bp`. Two Slows don't add up: the strongest wins. Marked works the same way.
  - Marked raises a hit before DEF, and damage over time too.
  - Taunt: each tick, a taunted unit's target is whoever taunted it (TARGET, "taunted"). When the taunter falls, it picks as usual.
  - Damage over time works as before phase 0. Burn, Poison, and Bleed are credited to whoever applied each stack. Heals weaken damage over time: the first heal in a 1s window strips `heal_cleanse_bp` (10%) of the stacks, and each later heal in that window strips half as much again.
  - Statuses sit on a unit in `statuses.json` order, so ticking them never depends on the order they arrived in.

## 9. Rift Collapse: the shrinking arena

- **Rings follow the placement grid:** a hex's ring is `min(col, 7 − col, row, 6 − row)`. On 8 × 7 that's ring 0 (the border), ring 1, ring 2, and ring 3, the 2 middle hexes, which never crumble.
- **On the plane,** each crumbled ring moves the safe rectangle's edge in by one ring: 866 at the sides and 1000 at the ends. The ends sit a further quarter hex in, because odd columns are shifted half a hex; that way a hex's center is on safe ground exactly when its ring hasn't crumbled. Everything outside the safe rectangle is crumbled ground. (Rings on 8 × 7 hold 26, 18, 10, and 2 hexes.)
- **Timing:** from `collapse_start_ms` (45s), one ring every `collapse_ring_ms` (10s). Each ring is **warned** `collapse_warning_ms` (3s) before it crumbles, and the warning is logged like an area's.
- **Damage:** anyone whose center is on crumbled ground takes flat damage once per second.
  - It starts at `base` and grows every second (the current `collapse_by_act` numbers, reused).
  - It hits Shield before HP, and is never a % of max HP.
- **Crumbled ground can't be walked into** (decided). A unit already on it can walk out, and pathfinding sends it back to safe ground first.
- **`start_collapse` effect:** starts the collapse now if it hasn't started yet (Old Mother Ash's Last Ember).
- **Tie at 180s**, as now.

## 10. Summons

- **`summon` effect:** a kit id, a count, and where the summons appear:
  - `edges`: free spots along the safe edge, closest to the anchor first.
  - `adjacent`: free spots touching the caster, from the same 12 points as leaps.
  - `hexes`: a fixed list of grid hexes, each falling back to the nearest free spot.
- **A summoned unit** joins **at the end of the fight order** and gets a unique id (`rift_pup#2`). It starts with no target and empty mana, unless its kit says otherwise. It's logged as `SUMMON`, with its source.
- **Cap:** at most `max_units_per_side` (**30**, decided) standing units per side. Extra summons are dropped, and that's logged too.

## 11. The combat log

- **New kinds:**
  - `MOVE`: one straight leg, with from, to, start tick, and arrival tick. A leg that's cut short (blocked, stunned, pushed, or re-aimed) ends with `STOP` at the point reached.
  - `TARGET`: who, whom, and the rule or Taunt.
  - `BREAK_FREE`.
  - `PUSH`: knockback or pull, with from, to, and what it hit.
  - `LEAP`, `CHARGE`, `HOP`.
  - `SHOT`: fired, with the landing tick; `SHOT_FIZZLED`.
  - `AREA_WARNING` (the shape, where it is, and the landing tick) and `AREA_LANDED`.
  - `COLLAPSE_RING`: warned or crumbled.
  - `SUMMON`.
  - `MANA_DRAIN`.
- **Moves are logged as legs, not per tick,** so a 60s fight's log stays small. A test replays every leg, push, and leap from the log, and checks that it gives each unit's exact position on every tick. So the UI can always draw the true board from the log alone.
- **`LogEntry` gains** `from_pos`, `to_pos`, `end_tick`, and `shape`. Phase 0 renames the item fields to ability fields (`source_ability`, `source_ability_name`).
- **Every entry that changes the board or a unit names its source unit and ability**, or "Rift Collapse", or a status. A test walks every entry of the determinism fight and checks this.
- **`ArenaDebug.render(sim)`:** a plain-text board (`ArenaDebug.draw` in step 1; `render(sim)` wraps it in step 2), one character cell per quarter hex, showing rocks, units by short tag, crumbled ground, and warned areas. Tests use it to show the board when an assertion fails; it doesn't touch the fight.

## 12. Files

**New** (`src/sim/arena/`):

| File | What it holds |
| --- | --- |
| `hex_grid.gd` | the placement grid: index ↔ (col, row), zones, rings, a hex's center on the plane |
| `arena_plane.gd` (`ArenaPlane`: Godot already has a `Plane` class) | integer vector helpers: length, direction to 1000, dot products, point-in-shape tests, sweeps |
| `nav_grid.gd` | the hidden eighth-hex cells: blocking for a given walker, A* paths and nearest, path corners, path lengths |
| `arena_state.gd` | per fight: rocks, the safe rectangle, pending warned areas and shots |
| `movement.gd` | walking, blocking, repathing, break free, hop away, flying |
| `displacement.gd` | knockback, pull, leap, charge, collisions |
| `shots.gd` | shots in flight and landing them |
| `areas.gd` | casting shapes, pending warned areas, landing them |
| `collapse.gd` | ring timing, warnings, crumbling, damage |
| `arena_debug.gd` | the text board |

**New elsewhere:**

- `src/sim/defs/unit_def.gd` (the shared kit), `ability_def.gd`, `mana_def.gd`, `shape_def.gd`, and `trigger_def.gd` (signature triggers).
- `src/sim/state/ability_state.gd` (cooldown, event count, fired once).
- `src/sim/mana.gd`.
- `FixedMath.isqrt` in `fixed_math.gd`.

**Rewritten** (written fresh; the old versions are in git history):

- `combat_sim.gd`: the tick above.
- `effects/targeting.gd`: the rules above.
- `effects/effect_runner.gd`: damage, heal, shield, apply_status, cleanse, mana_drain, knockback, pull, leap, charge, area, summon, and start_collapse.
- `defs/effect_def.gd`: targets `target`, `hit_target`, `self`, `all_enemies`, `all_allies`, and `trigger_ally` (step 2 dropped `enemy_random`, `enemy_lowest_hp`, and `ally_lowest_hp`; units and abilities pick with targeting rules instead), plus the new types. `"trigger"` is optional and defaults to `on_fire`.
- `defs/status_def.gd`, `statuses.gd`: the new kinds.
- `defs/collapse_def.gd`, `defs/tuning_def.gd`: the new values.
- `defs/unit_stats.gd`: adds speed and range.
- `state/unit_state.gd`: position, path, target, mana, engagement, where it started, and abilities.
- `setup/unit_setup.gd`, `setup/fight_setup.gd`: grid hexes and rocks, and validation.
- `log_entry.gd`: new kinds and position fields.
- `events.gd`, `defs/part_def.gd`, `defs/phase_def.gd`: back from the old sim, for abilities (see the top).

**Data:** `tuning.json` gains these values:

| Group | Values |
| --- | --- |
| The grid | `grid` (width, height, zone rows) |
| The plane | `unit_radius`, `rock_radius`, `nav_cell` |
| Movement | `engage_reach`, `repath_ms`, `repath_give_up_ms` |
| Timers | `break_free_ms`, `collision_stun_ms`, `leap_land_ms` |
| The collapse | `collapse_ring_ms`, `collapse_warning_ms` |
| Summons | `max_units_per_side` |

It keeps `collapse_start_ms`, `collapse_by_act`, `tie_ms`, `crit_damage_bp`, `crit_bp_per_point`, `atsp_bp_per_point`, and `defense_constant`. `statuses.json` is trimmed (section 8). No hero or enemy content yet.

## 13. Tests

Each rule gets its own test file under `tests/sim/`. They build tiny boards through a new `sim_test_kit.gd`: `K.kit(...)`, `K.at(kit, col, row)`, and `K.fight(heroes, enemies, rocks, seed)`.

| Test file | Covers |
| --- | --- |
| `test_hex_grid.gd` | coordinates both ways, zones, rings, hex centers on the plane (neighbors 1000 apart) |
| `test_arena_plane.gd` | isqrt, directions, each shape's point test, sweeps stopping at circles and edges |
| `test_nav_grid.gd` | routes around units and rocks, gaps too narrow to pass, the fixed tie-break, no route, leaving crumbled ground |
| `test_movement.gd` | speed → distance per tick, straight when clear, around when not, no overlap ever (checked every tick), the hero winning a contested gap, stopping in range, Slow, Root, the repath give-up |
| `test_targeting.gd` | every rule and its ties, back-liners by starting row, sticky targets, Taunt overriding and ending, TARGET log lines |
| `test_attacks_and_mana.gd` | melee reach, range by distance, ATSP, every mana source, Silence, Stun still gaining mana, units with no mana |
| `test_shots.gd` | flight time by distance, following a moving target, numbers fixed at firing, fizzling on a fallen target, landing after the shooter falls |
| `test_signature_triggers.gd` | mana (the bar empties), hp_below once, fight_start, at_time, count, would_fall (left at 1 HP, once); Stun holding back only mana signatures; a cast cancelled by Stun keeps its mana; cast_ms refused off mana |
| `test_engage.gd` | held 1s only when targeting someone else, the engager's attackers not held, freedom ending on leaving contact, fliers still held, a push ending the engagement |
| `test_displacement.gd` | knockback distance and direction, collisions with a unit, a rock, and the edge (both stunned), pull, leap landing and failure, charge, a displaced walker losing its path |
| `test_flying.gd` | passing over units and rocks, stopping only on free spots, dropping after a push |
| `test_areas.gd` | warnings are logged, and the area hits whoever stands there when it lands, not when it's cast; each shape; `hits` filters |
| `test_statuses.gd` | rewritten for the new kinds (Undying included), plus damage over time as now |
| `test_collapse.gd` | ring timing and warnings, the safe rectangle shrinking, damage only on crumbled ground, flat and Shield-first, can't walk in, start_collapse, the 180s tie |
| `test_summons.gd` | placement in each mode, fight order, the cap of 30, the log |
| `test_arena_log.gd` | in a busy fight, every entry that changes state names a source; replaying the log gives every unit's position on every tick |
| `test_determinism.gd` | new (see below) |

- **The determinism test:** a chaotic seeded fight that uses everything above, plus random crits, runs twice with identical logs. A third run, whose setup lists units in a different order, gives a different log, which proves the order is actually used.
- `test_sim_rng`, `test_fixed_math` (plus isqrt), and `test_project_setup` stay as they are.

**Speed budget:** a 60s fight of 3 against 6 should sim in **under 100 ms** headless. `tools/sim_runner.gd` (phase 2) needs hundreds of fights at a time. What keeps it cheap:

- Walking straight when the way is clear.
- Pathfinding only when blocked, on a new target, or every 0.5s.
- Searches guided toward the target, which touch a few hundred of the 3,420 cells.

**Measured in step 1** (one search, 3 heroes against 6 enemies):
- A clear path takes well under 1 ms.
- `nearest` takes about 2.5 ms.
- A path to an enemy boxed in at the back of its formation takes about 2.7 ms.
- So a fight can afford a few dozen searches, not hundreds. Repathing only when needed matters.

If step 2 measures slower, the cell size and repath interval are the knobs, and I'll report before going further.

**Measured in step 2** (whole fights, 3 against 6, with test kits):
- A 22s fight takes about 49 ms, and a 65s one about 80 ms. That's inside the budget, with nothing to spare.
- The costliest ticks are the first one, when all nine units pick a target, and the ones where units re-target across the board.
- The rest is the fixed cost of every unit's turn, about 50 µs a tick for all nine units together.
- Speed-ups so far, none of which change results:
  - The search loop works on plain integer arrays with its queue inline.
  - The collision check doesn't build lists.
  - Effect numbers are worked out without building a breakdown.
- Units point at their target weakly, so two units targeting each other don't keep each other alive after the fight.
- Watch the budget again once statuses, mana, and areas add their per-tick work.

## 14. Order of work (each step: code, tests, green run, commit)

1. **Grid and plane (done):** `hex_grid`, `arena_plane`, `nav_grid`, `arena_debug`, `FixedMath.isqrt`, and their tests. Pure functions, no sim.
2. **Skeleton fight (done):** kits, setups with hexes and rocks, the new `CombatSim` tick, walking and blocking, `nearest` targeting, melee attacks and shots, deaths, the end of the fight, the MOVE, STOP, TARGET, and SHOT logs, and the log replay test. The first determinism test, and a speed measurement.
3. **Statuses (done):** Root, Stun, Slow, Taunt, Silence, Marked, and damage over time.
4. **Mana and signatures:** the five triggers, cast_ms, Undying, `Events`, and `PartDef`.
5. **Tanks:** Engage.
6. **Displacement and flying:** knockback, pull, leap, charge, collisions, flying, and hop away.
7. **Areas:** shapes, warnings, landing, and the rest of the targeting rules.
8. **Collapse, summons, and phases:** rings, the safe rectangle, damage, start_collapse, summons, and `PhaseDef`.
9. **The full determinism fight and the log audit.** Update `CLAUDE.md`'s sim rules to describe the arena.

## 15. Proposals to confirm

The second round's answers are under **Decisions** above. Answer 19 needs two small pieces the plan didn't have, so I've added them:

1. **A `would_fall` trigger:** the first time a unit would fall, it's left at 1 HP instead, and the signature fires (once per fight). That's "when he hits 1 HP".
2. **An Undying status** (`undying`): the unit's HP can't drop below 1 while it lasts. That's "he can't fall for 1s", and Last Rites' "can't be felled for 3s" (phase 4) uses it too.

Brannoc's example is then a `would_fall` signature that applies Undying for 1s.
