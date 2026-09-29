# Rebuild phase 4: paths (build plan)

Status: **in progress. Step 1 (paths, stages, and deeds in the sim) is built (2026-09-29).** Its questions are answered (Decisions), except Guard's reach, which waits on step 3's measurements. Phase 4 of `docs/plans/rebuild-build-order.md`. Design source: part 1, `rebuild-heroes.md` (paths, vows, tastes and costs, deeds, transformations), changed by part 6, `rebuild-between-fights.md` (upgrade picks come after every won fight, not from deeds). It builds on the arena sim (phase 1), the content (phase 2), Practice (phase 3), and tactics (phase 3b). What playtest gate 1 and the 3b playtest find goes into this plan before its code starts.

**Goal:** each of the three heroes gets their three paths. In Practice you can vow a hero to a path (the taste and its cost) or take them straight to the transformed form, and see how far each deed moved in a fight.

**Done when:** **playtest gate 2: each path changes where you place the hero and how the fight plays.** This plan's own bar, before the playtest:
- with every hero on their base kit, every fight is exactly what it was (the bench's fingerprints don't move);
- every deed is hard to fill without its taste: in the sim runner's deed report, the vowed path's deed averages at least 4 times what the same hero puts into it on base or on another vow;
- each path moves its hero: in the paths report, the hero's best spots on each path differ from the other two paths in at least one encounter;
- every new mechanic writes to the log with its source (rule 4), and has a form on the board.

## Scope

**In phase 4:**
- The 9 paths as data: each one's taste, cost, deed, and transformation (new signature, reshaped stats, the full mechanic, mana changes).
- A hero's **stage** in a fight: base, vowed (taste and cost), or transformed.
- **Deeds**, counted in every fight for all three of a hero's paths (the design: they count what the hero does, with no bonus for the vow).
- The sim pieces the paths need that no existing effect, trigger, or part can express (section 5). Each is named as new code, per rule 3.
- Practice: the hero panel from the playtester's mock (section 6), where you choose each hero's path and stage, the transformed figures (already drawn in `art/figures/heroes/`), deed progress in the result, and Trapper's two placed snares.
- The sim runner: a paths report and a deed report.

**Not in phase 4:**
- Deed **thresholds**, when a transformation happens, vow switching, and pacing: they belong to the run (phase 5), which decides how many fights a transformation takes. Phase 4 measures what a fight puts into each deed, so phase 5 can set thresholds from real numbers.
- Apexes (Acts 2–3; phase 8).
- Upgrade pools: the path and hero layers come in phase 5 with the after-fight pick (Decision 2); the role layer in phase 8.
- Duo bonds (phase 5).
- Retuning enemies. Transformed heroes will win Practice fights more often; the run's days scale enemies up (phases 5–6).

## Decisions this plan builds on

- **Vows happen when the team is chosen; transformations are permanent** (part 1). In Practice both are free choices, since there's no run yet.
- **The taste is small** (about 5–10% of the path, one piece of it) **and the transformation must feel like a different, stronger hero** (part 1).
- **The taste is the tool for the deed:** all three deeds count whatever the hero does, all the time, and each measures something the taste makes possible (part 1).
- **Every path changes where you'd place the hero** (part 1, rule 3); **every path has a real cost** (rule 4).
- **Upgrade picks come after every won fight, not from deeds** (part 6). Deeds bring the transformation (and later the apex).
- **Content is data** (rule 3): paths are JSON. The new sim pieces in section 5 are code, since no existing piece can express them.
- **Tactics survive a transformation** (part 6). This is where it gets tested (question 4).

## 1. What a path is

A path is an entry in a new `data/paths.json`, loaded by `ContentDb` as a `PathDef`. For example, Deadeye:

```json
{
  "id": "deadeye",
  "hero": "maren",
  "name": "Deadeye",
  "fantasy": "She plants her feet and makes one shot count.",
  "placement": "A corner with a long sightline.",
  "vowed": {
    "taste": "Steady: after 2s without moving, she reaches 1 hex farther.",
    "cost": "She attacks 10% slower.",
    "patch": {
      "parts": [{"id": "steady", "name": "Steady", "kind": "aura", "text": "...",
                 "aura": {"target": "holder", "stat": "range", "value": 1, "while": "planted", "after_ms": 2000}}],
      "stats_bp": {"atsp": 9000}
    }
  },
  "transformed": {
    "text": "Planted, she reaches 6 hexes and crits more. Heartseeker replaces Marking Shot.",
    "cost": "After moving, she needs 1.5s to plant before firing again.",
    "patch": {"signature": {"id": "heartseeker", "...": "..."}, "parts": ["..."], "stats_bp": {"atk": 12000, "atsp": 8500}, "stats_add": {"crit": 6}}
  },
  "deed": {"text": "Damage dealt from 5 or more hexes away", "counts": "damage", "from_hexes": 5}
}
```

- **A patch** (`KitPatch`) changes a copy of the hero's base kit. It can:
  - multiply stats (`stats_bp`: HP, ATK, MGK, DEF, ATSP) or add to them (`stats_add`: CRIT, speed, range);
  - replace the basic attack or the signature;
  - replace the mana bar, or remove it (`"mana": null`, for Last Watch);
  - add passives (`parts`), or remove them by id (`remove_parts`).
- **The vowed patch** is the taste plus the cost. **The transformed patch** replaces it: the transformed form carries the full mechanic, so it doesn't stack on the taste.
- **The texts** are the player's (the sim never reads them): the taste, the cost, what the transformation brings, the fantasy, and where the hero wants to stand. Like every ability's, they name every reach and leave numbers to a generated line.
- **Placeholders:** where the design says "+ATK" without a number, the first numbers are mine, tuned with the sim runner (section 7).
- `HeroDef` gains `paths` (its three ids, in the design's order). `ContentDb` checks each hero has exactly three, and that each patch's parts, abilities, and statuses exist.

## 2. A hero's stage in a fight

- **`UnitSetup` gains `path` and `stage`** (base, vowed, or transformed). `Encounters.setup` takes hero id → path and stage, as it takes tactics, and builds the kit: `Paths.kit(hero, path, stage)` copies the base kit and applies the patch. A base hero takes the base kit unchanged, so base fights are exactly what they were.
- **`FightSetup.validate`** refuses a path that isn't the hero's, and a stage without a path.
- **The log names the path's pieces like any other:** Steady is a passive on Maren's kit, Heartseeker her signature. Nothing new in the log for the stage itself; the setup shows it.
- **The figure:** a transformed hero is drawn as that path's figure (`FigureArt.key_for(hero, true, path)`); a vowed one keeps the base figure.

## 3. Deeds

A deed counts one thing, for its own hero (`DeedDef`, like the old engine's, rewritten):

| Counts | What it adds up | Filters |
| --- | --- | --- |
| `damage` | damage the hero deals (the full hit, Shield included) | `from_ability` (only these abilities or passives), `from_hexes` (the hit left from at least this far from its target), `while_below_bp` (only while the hero is below this share of max HP) |
| `healing` | HP the hero restores | `from_ability` |
| `shield` | Shield the hero gives | `from_ability` |
| `extra_hits` | enemies a single attack hits beyond its first | `from_ability` |
| `rooted_ms` | how long enemies stay rooted by the hero | none |
| `guarded` | damage the hero takes in place of allies (Guard) | none |

The nine:

| Path | Deed | Why it's hard without the taste |
| --- | --- | --- |
| Deadeye | damage from 5+ hexes | her range is 4; only Steady reaches 5 |
| Trapper | seconds enemies spend rooted by her | she has no roots without Snare |
| Volley | extra enemies hit by one shot | only Split Shot hits a second enemy |
| Hearthwall | damage taken in place of allies | only Guard redirects; a taunted hit is an attack on him, and doesn't count |
| Ironbrand | extra enemies hit by one Shield Bash | only Brand hits a second enemy |
| Last Watch | damage dealt below 30% HP | without Unyielding he rarely lasts long that low |
| Lanternbearer | healing Mend gives to allies next to its target | only Kindle heals a second ally |
| Wardweaver | Shield she gives | she gives none without Ward Thread |
| Vigil Keeper | damage dealt by smites | only Judgment smites |

- **Counted in the sim, as the fight runs** (`Deeds`, in the events step), since some filters need the fight's state (how far the shot flew, the hero's HP when it hit). Every hero with paths counts all three of their deeds, whatever their stage. **Counting never writes to the log or changes the fight**, so fingerprints stay put.
- **`FightResult.deeds`:** hero id → path id → amount. Practice shows it; phase 5 adds it up across a run.
- **Thresholds are phase 5's:** it sets them from the deed report, aiming at the run plan's pacing (the first transformation around days 3–4).

**Built in step 1 (2026-09-29):**
- **Data:** `data/paths.json` (empty until wave 1 adds its three), read as `PathDef`:
  - its title ("the sniper"), fantasy, and placement line;
  - `vowed` (taste, cost, patch) and `transformed` (text, cost, patch);
  - its deed.
- **`KitPatch`** reads `stats_bp`, `stats_add`, `basic_attack`, `signature`, `mana` (or `null`), `passives` (a base passive's id replaces it), and `remove_passives`. A new signature that doesn't fire on mana takes the bar away, like a phase. `DataReader.is_null` reads the `null`.
- **`ContentDb`** loads paths after the heroes and lists up to three per hero in file order (`HeroDef.paths`, `HeroDef.path(id)`). It builds and checks each path's two kits once, as `vowed_kit` and `transformed_kit`:
  - the patched kit must be sound;
  - HP and range must stay at least 1, speed and CRIT at least 0;
  - a removed passive must exist;
  - statuses must be known;
  - a deed's `from_ability` must name something in one of the hero's kits on that path.
- **`DeedDef`** counts `damage` (hits, not damage over time, Shield included), `healing`, or `shield`. Its filters are `from_ability`, `from_hexes`, and `while_below_pct`; the last two are for damage only. The waves add the other kinds (extra hits, time rooted, damage taken for allies) as they need them.
- **Setup:**
  - `UnitSetup` gains `path`, `stage`, and `deed_paths`.
  - `Encounters.setup(..., tactics, vows, transformed)`: `vows` maps a hero id to a path id; `transformed` lists the heroes past their vow. Every hero counts its paths' deeds.
  - `FightSetup.validate` refuses a path that isn't the unit's own hero's, a stage without a path, a path without a stage, and deeds that aren't the unit's.
- **Counting:**
  - `Deeds` counts at the end of each tick, the deaths step included, and only when some unit has deeds.
  - A shot's distance is taken as it's fired, from its SHOT entry; anything else counts where the two stand as it lands.
  - It never writes to the log.
  - `FightResult.deeds` (hero, path, amount) is in the fight's order; `deed_amount(hero, path)` reads one; `CombatSim.deed_amounts()` gives the same while a fight is being stepped (for the UI).
- **Tests:** `tests/sim/test_paths.gd` (10) and `tests/sim/test_deeds.gd` (7). The bench's 20 fingerprints are unchanged, and a fight with test paths loaded but taken by no one is identical to one without.
- **Mutation checks:** 31 on the new code, all caught, one after a test was added (a hero's kit on the enemies' side counting a deed). The full run: 497 tests, all passing.

## 4. The nine paths

What each path's taste, cost, and transformation need, by the pieces in section 5 ("data" means the existing pieces cover it).

### Maren

| Path | Taste and cost (vowed) | Transformed | Needs |
| --- | --- | --- | --- |
| **Deadeye** | Steady: +1 range after 2s still; –10% ATSP | +2 range planted (6), +CRIT; **Heartseeker** (a charged shot that pierces the first enemy: a cast, then a line); +ATK, –ATSP; double mana from shots from 5+ hexes; cost: 1.5s to plant after moving | P3 (planted, range), P4, P11 (plant delay) |
| **Trapper** | Snare: once a fight, a snare in the nearest enemy's path, rooting 1.5s; –10% basic damage | Snares root 2s and Bleed; **Bramble Field** (a snare on an enemy's predicted path, up to 3 standing); **you place her first 2 snares before the fight**; +DEF, –ATK; range 3 | P8 (snares) |
| **Volley** | Split Shot: every 4th attack also hits one enemy next to the target; range 3 | Every attack splits; **Arrow Storm** (a 3-hex circle of arrows for 3s); +ATSP, –damage per arrow; mana per extra enemy hit; she fires while moving | P4, P5, P7 (zones), P11 (fire while moving) |

### Brannoc

| Path | Taste and cost (vowed) | Transformed | Needs |
| --- | --- | --- | --- |
| **Hearthwall** | Guard: the ally behind him (Decision 6) takes 10% less, and he takes it; –10% Shield Bash damage | Guard covers every adjacent ally at 30%; **Hearthwall** (a wall of shields 3 hexes wide in front of him that stops ranged attacks for 4s); +HP, +DEF, –ATK; mana from damage he takes for allies; speed 1, and he can't move while the wall stands | P4, P9 (Guard), P10 (the wall) |
| **Ironbrand** | Brand: Shield Bash also hits one other adjacent enemy for 30%; Hold the Line taunts 1s less | **Hearthbrand Mace** (hits every adjacent enemy, heals him for 5% of the damage); **Brand Slam** (leaps up to 2 hexes into the largest group, damages, knocks back); +ATK, +HP, –DEF (his cost); mana per enemy the cleave hits | P4, P5, P6 (lifesteal) |
| **Last Watch** | Unyielding: once a fight, a hit that would fell him leaves him at 1 HP; –5% max HP | Below 30% HP he gains DEF and ATK, more for each fallen ally; **Last Rites** (below 30% HP, once: taunts every enemy within 3 hexes, and he can't fall for 3s); no mana bar; +ATK, –10% max HP; healing on him 30% weaker | P3 (below HP, per fallen ally, healing taken), P12 (Unyielding) |

Ironbrand's transformed cost: the design also said "Hold the Line only taunts adjacent enemies", but Brand Slam replaces Hold the Line, so that line is dropped; his cost is the lost DEF (Decision 5).

### Vell

| Path | Taste and cost (vowed) | Transformed | Needs |
| --- | --- | --- | --- |
| **Lanternbearer** | Kindle: Mend also heals one ally next to its target for 10%; Mend costs 5 more mana | Mend heals every ally next to its target at 50%; **Night Lantern** (a lantern on a hex: for 5s, allies within 2 hexes heal over time and lose Burn and Poison); +MGK, –HP; Lantern Glow deals no damage (still builds mana) | P5, P7 (zones) |
| **Wardweaver** | Ward Thread: Mend on an ally at full HP gives a Shield (10% of the heal) instead; Mend heals 10% less | Mend becomes **Weave** (mostly Shield, a little healing); **Warding Circle** (a ring 2 hexes wide for 4s: enemies entering are Slowed, allies inside take 20% less damage); +HP, +DEF, –MGK; healing 40% weaker | P6 (overheal to Shield), P7 (zones) |
| **Vigil Keeper** | Judgment: every 4th Mend also smites the enemy nearest its target (10% of the heal as damage); Mend's reach –1 | Every Mend smites; **Sunfall** replaces Mend (a line of light that damages enemies and heals allies in it); Mend becomes a smaller heal on every 4th basic attack; +MGK, +CRIT, –DEF; smites give mana; healing 30% weaker | P4, P5, P13 (an area that treats each side differently) |

## 5. New sim pieces (each is new code; rule 3)

Each piece is used by the paths named, and each is skipped entirely by a unit that doesn't have it, so base fights are unchanged.

| # | Piece | What it is | Paths |
| --- | --- | --- | --- |
| P1 | **Paths and stages** | `PathDef`, `KitPatch`, `UnitSetup.path` and `stage`, `Paths.kit` | all |
| P2 | **Deeds** | `DeedDef`, `Deeds` (counted as the fight runs), `FightResult.deeds` | all |
| P3 | **Aura conditions and stats** | `"while": "planted"` (hasn't walked for `after_ms`), `"while": "below_hp"` (below a share of max HP), `"per": "fallen_ally"` (stacks per fallen ally); the stats `range` (added hexes) and `healing_taken_bp` | Deadeye, Last Watch |
| P4 | **Gaining mana** | a `gain_mana` effect, and a basic attack's mana doubled from far enough away | Deadeye, Volley, Hearthwall, Ironbrand, Vigil Keeper |
| P5 | **Next to the target** | targets for "another enemy next to the target" and "an ally next to the target"; `lowest_hp_ally` for a passive's heal; amounts as a share of the hit or heal that set it off | Volley, Ironbrand, Lanternbearer, Vigil Keeper |
| P6 | **Lifesteal and overheal** | a heal worth a share of the damage dealt; a heal's overflow becoming Shield | Ironbrand, Wardweaver |
| P7 | **Zones** | an area that stays for a while: it applies its effects every so often to whoever is inside, can act on units entering it, and can give an aura to allies inside. Logged when it appears, each time it acts, and when it ends; drawn on the ground | Volley, Lanternbearer, Wardweaver |
| P8 | **Snares** | a snare on the plane that springs on the first enemy whose center enters it; set by an effect ("in the nearest enemy's path": on the line from that enemy to her, 1 hex ahead of it) or placed by the player before the fight. Logged and drawn | Trapper |
| P9 | **Guard** | a share of the damage an ally takes goes to the guard instead, while the ally is where Guard covers. Logged as its own line, so the deed and the chart can count it | Hearthwall |
| P10 | **A wall that stops shots** | a wall segment on the plane for a while; an enemy shot that crosses it is stopped (logged). Units still walk through it (the Unbroken Gate apex is what blocks walking) | Hearthwall |
| P11 | **Attack timing** | fire while walking (transformed Volley); a plant delay after walking before the next attack (transformed Deadeye) | Volley, Deadeye |
| P12 | **Unyielding** | would-fall as a passive's trigger, once a fight: the hero stays at 1 HP. (Today only a signature can fire on would-fall.) | Last Watch |
| P13 | **An area by side** | an area whose effects each say which side they hit (Sunfall damages enemies and heals allies in one line) | Vigil Keeper |

Heartseeker's pierce, Brand Slam, Last Rites, Weave, the stat changes, and the costs that are stat or ability changes are **data**, with the existing pieces (cast times, lines, leaps, largest group, HP-threshold signatures, Undying, auras).

**Built (2026-09-29), the pieces of waves 1 and 2** (each is skipped by a unit that doesn't use it; the bench's fingerprints are unchanged):
- **An ability's own `every`** (P5's Split Shot and Judgment): an on_fire effect with `"every": N` runs on every Nth time its ability fires (`AbilityState.fires`). Not inside an area.
- **Targets near the target** (P5):
  - `enemy_near_target`, `enemies_near_target`, `ally_near_target`, `allies_near_target`, with an optional `within_hexes` (the plural ones need it);
  - `lowest_hp_ally`, within `within_hexes` of the unit if given.
  - The center is the ability's target; on_hit, the unit hit; for an event, the unit's target. Stealthed enemies aren't picked. Near-target effects land as the ability fires, not on its shot (`EffectRunner.near`).
- **Share-of-the-hit amounts** (P6):
  - `amount_bp_of_damage` works for damage (Brand's 30%) and heal (lifesteal), not just Shield. It needs a hit, so it's on_hit or an event.
  - A heal's `overheal_shield_bp` turns what it would restore past full HP into Shield (Ward Thread).
- **Mana** (P4): a `gain_mana` effect (not logged, like every mana gain: the fire that gave it is). `ManaDef.far_hexes` and `per_far_attack`: a basic attack at a target that far gives that instead of `per_attack` (Deadeye).
- **Sides** (P13): an area's own effect can say `"side": "enemies"` or `"allies"`, so Sunfall's line hurts enemies and heals allies.
- **Zones** (P7): an area with `duration_ms` and `every_ms` is logged once (a new log kind, ZONE: shape, where, and when it ends). It then lands at once and every pulse until it ends (each pulse an AREA_LANDED), with numbers fixed as it was cast. No warning. It outlives its caster.
- **Aura conditions** (P3):
  - `"while": "planted"` with `after_ms`: the unit hasn't moved for that long. `UnitState.moved_at` counts walking, flying, hops, leaps, and pushes.
  - `"while": "below_hp"` with `below_pct`.
  - `"per": "fallen_ally"`: counts once per fallen unit of its side.
  - The units with these are checked at the end of every tick, and auras are folded in again when one changes, so it counts from the next tick. AURA lines log each start and end, as before.
  - New aura stats: `range` (adds hexes to its reach) and `healing_taken_bp` (scales heals the holder gets).
- **Attacking** (P11):
  - A kit's `plant_ms`: after it moves, its basic attack waits that long (Deadeye's cost).
  - The `fires_moving` trait: while it walks, a ready basic attack fires at the nearest enemy in reach without stopping, and it keeps its target (Volley).
  - `KitPatch` gains `add_traits` and `plant_ms`.
- **Unyielding** (P12): a passive's `on_would_fall` trigger. Once a fight, when the unit would fall (after Undying and a would_fall signature), it's left at 1 HP (SAVED, sourced to the passive) and the effect runs.
- **Warded**: a new status kind, `warded`, which takes `damage_reduced_bp` less. The strongest Ward wins and adds to a Mark. `data/statuses.json` gains `warded` (20% less, 0.6s), for Warding Circle to reapply each pulse.
- **Tests:** `tests/sim/test_path_pieces.gd` (one rule at a time).

**Built (2026-09-29), the pieces of wave 3:**
- **Snares** (P8, `Snares`):
  - A `snare` effect (its own effects, an optional `max_standing`) is set 1 hex ahead of the ability's target, toward what that target is going for (or else toward the unit), on safe ground.
  - It springs on the first standing enemy (not in the air) whose center comes within 0.3 hex, checked after every unit acts. It lands its effects, fixed when it was set, on that enemy.
  - Past `max_standing`, the oldest goes.
  - A kit's `placed_snares` lets the player place that many before the fight (`UnitSetup.snares`, by hex, set at tick 0 from the kit's first snare effect). `FightSetup.validate` checks the count, repeats, the board, the unit's half or the middle row, and rocks.
  - Logged as SNARE (set, sprung, gone).
- **Walls** (P10, `Walls`): a `wall` effect (`width_hexes`, `ahead_hexes`, `duration_ms`) stands square to the way to the target. While it stands, an enemy shot whose line from where it was fired to its target crosses the wall is stopped as it would land (SHOT_FIZZLED, "stopped by ..."). Logged as WALL.
- **Guard** (P9, `Guards`): a passive of kind `guard` (`share_pct`, `within_hexes`, `covers`: `behind` or `all`).
  - When an enemy's hit lands on an ally in reach, the guard takes that share of what got through the ally's DEF, into its Shield and HP, as damage taken (for mana).
  - The ally's DAMAGE line shows what it took; a GUARD line what the guard took.
  - Only hits (not damage over time or Rift Collapse). The first covering guard in the fight's order takes it.
- **The rest:**
  - `on_interval` can run `"once"` (the Snare taste).
  - Deeds count `extra_hits` (hits on a unit that isn't the target of that ability's latest fire), `rooted_ms` (Roots as applied), and `guarded`.
  - FightFx draws zones, snares, and walls from the sim's state (so a skip keeps them), and a brass number for GUARD.
  - The audit has rules for ZONE, SNARE, WALL, and GUARD.
  - The chaos fight leaves them (and Warded) to the paths fight, like TACTIC.
- **Checks:** 527 tests pass, and the bench's fingerprints are unchanged.

## 6. Practice: the hero panel

The playtester's mock (`docs/mockups/hero-panel-layout.pdf`, 2026-09-29) is the design: a **hero panel** that opens over the screen, with the hero's figure and name on the left and three tabs on the right. Phase 4 builds it for Practice, where it's how you choose a path; phase 5 fills in what needs the run.

**The panel** (opens when you click a hero while placing, instead of today's small popup; in a fight the small popup stays, with its live numbers, since the panel would cover the board):
- **The left side:** the hero's figure (the path's figure once transformed, with a "Base form" or path tag), name, title and role, and the HP bar.
- **Back, forward, and close** buttons at the top right: back and forward move between the three heroes.
- **The Path tab** (it opens on this one):
  - **The track:** Base → Vow → Transform → Upgrades → Apex, with the hero's place on it. Upgrades and Apex show as later ("Opens on transforming", "Later in the run").
  - **The vowed path's card:** its figure, name, title ("the sniper"), and VOWED or TRANSFORMED; the taste and the cost (or, transformed, what it brings and its cost); the deed.
  - **The other two paths' cards:** figure, name, a short line, and the deed.
  - **Choosing, in Practice:** each path card has Vow and Transform buttons, and the vowed card has Base (no path). Remembered while the game is open (`PracticeSession.paths`), like tactics. In the run, vowing happens at the start, transforming when the deed fills, and the vowed card's button is "Switch vow" (phase 5).
  - **The deed:** Practice has no thresholds, so each card shows what the **last fight** put into that deed ("last fight: 1,240") in place of the mock's progress bar ("1,240 / 2,000"), which comes with the run.
- **The Kit tab:** today's ability lines from `UnitInfo` (sentence and numbers line), built from the patched kit, so they're always what the hero has at their stage.
- **The Loadout tab:** the tactic choice (moved from today's popup). Charm and sigil slots come in phase 5.

**From the mock, left for phase 5 (the run):** the hero bar along the bottom of every screen between fights (it opens the panel), the day, place, shards, and relics at the top, wounds on the HP bar, deed progress toward a threshold, "Switch vow", upgrades taken, the duo bond, and the charm and sigil slots.

**Elsewhere in Practice:**
- **The board:** a transformed hero stands as its path's figure; a vowed one keeps the base figure, with its path named under it like a tactic.
- **Trapper's snares:** a transformed Trapper adds two snare markers to placement, dragged onto hexes like heroes, in your half; what's legal comes from the sim, like hero placement.
- **The result:** each hero's three deeds and what this fight put into each, the vowed one first. The result's "Heroes:" line names each hero's path and stage.
- **New log kinds** (zones, snares, Guard, the wall) each get a form on the board and a row in `test_every_encounter_plays.gd`'s table, and an audit rule.

## 7. The sim runner

Two reports, like the tactics report: reports, not gates.

- **The deed report** (`--deeds`): for each hero, each encounter, and each stage (base, each vow, each transformation), what a fight puts into each of the three deeds, on average over the formations. It answers **"is every deed hard to fill without its taste?"** (this plan's bar: vowed at least 4 times base or another vow), and gives phase 5 the numbers to set thresholds from.
- **The paths report** (`--paths`): each encounter fought with one hero on a path (vowed, then transformed) and the others on base, from the same formations as the placement report, plus formations drawn with that hero anywhere in the zone. For each: its win rate against base, and **where the hero stands in the best formations** (how far forward, how far to the side, how near the other heroes). It answers **"does each path move its hero?"** (this plan's bar) and **"is each transformation stronger?"** The target (Decision 3): a vowed hero's team wins about as often as base (the taste pays for its cost, within about 5 points), and a transformed hero's team wins **15–25 points more** than base across the encounters.
- **Where allies stand around Brannoc** (for Guard, Decision 6): the deed report also measures, over each fight, how often an ally is within 1, 2, and 3 hexes of him on the side away from his target.

## 8. Files

| File | Change |
| --- | --- |
| `data/paths.json` | New: the nine paths |
| `src/sim/defs/path_def.gd`, `kit_patch.gd`, `deed_def.gd` | New |
| `src/sim/defs/hero_def.gd`, `src/sim/content_db.gd` | A hero's paths; load and cross-check them |
| `src/sim/setup/unit_setup.gd`, `fight_setup.gd`, `encounters.gd` | Path and stage on a unit, validated; the patched kit |
| `src/sim/paths.gd`, `src/sim/deeds.gd` | New: building a kit, counting deeds |
| `src/sim/fight_result.gd` | `deeds` |
| `src/sim/defs/aura_def.gd`, `effect_def.gd`, `part_def.gd`, `src/sim/passives.gd`, `signatures.gd`, `mana.gd`, `effects/effect_runner.gd`, `effects/targeting.gd`, `combat_sim.gd`, `arena/shots.gd`, `arena/areas.gd`, `arena/movement.gd` | The pieces in section 5, each in its own step |
| `src/sim/arena/zones.gd`, `snares.gd`, `walls.gd`, `guard.gd` | New, by wave |
| `src/sim/log_entry.gd` | New kinds for zones, snares, Guard, and the wall |
| `src/ui/practice/practice_session.gd`, `src/ui/widgets/hero_popup.gd`, a new `hero_panel.gd` (and its path cards and track), `src/ui/arena/unit_token.gd`, `arena_view.gd`, `fight_fx.gd`, `src/ui/screens/arena_screen.gd` | The hero panel (choosing a path and stage), figures, snare placement, new forms, the result's deeds |
| `tools/sim_runner.gd`, `tools/sim_report.gd` | `--deeds`, `--paths` |
| `tests/sim/test_paths.gd`, `test_deeds.gd`, one test file per new piece, `tests/ui/test_paths_ui.gd` | New |
| `tests/sim/chaos_fight.gd`, `test_arena_log.gd`, `test_every_encounter_plays.gd`, `tests/tools/test_sim_runner.gd` | The new pieces in the chaos fight (or its own fight, like tactics), the audit, the board's forms, the reports |

## 9. Tests

- **Paths and stages:** a patch changes only what it names; a transformed kit carries no taste; a base kit is untouched; bad paths are refused (another hero's path, a stage without a path, an unknown part).
- **Deeds:** each kind counts what it says and nothing else, filter by filter (a shot from 4.9 hexes doesn't count for Deadeye, a hit at 31% HP doesn't count for Last Watch); counting doesn't change the log.
- **Each new piece:** its rules one by one, in small fights (`sim_test_kit.gd`), and its log line and audit rule.
- **Each path:** its taste, cost, and transformation do what the text says, in small fights, like `test_hero_kits.gd`; each path's texts name every reach (`test_unit_info.gd`).
- **Fingerprints:** base fights, the chaos fight, and the bench fights are unchanged.
- **Practice:** the hero panel (its tabs, track, cards, back and forward), choosing a path and stage, the figure, the result's deeds, placing Trapper's snares; the fight on screen is the fight `CombatSim.run` gives.
- **The runner:** both reports run small.
- **Mutation checks** on each new piece, as in earlier phases.

## 10. Order of work (each step: code, tests, green run, commit)

The paths come in **three waves** of one path per hero, so a playtest can check the first three before the rest are built (question 1). Each wave: its sim pieces, its three paths as data, tests, a tuning pass with the reports, and a playtest build.

1. **Paths and deeds (P1, P2):** `PathDef`, `KitPatch`, stages, `DeedDef`, counting, `FightResult.deeds`, tested with test paths. `data/paths.json` starts empty; each wave adds its three.
2. **Wave 1: Deadeye, Ironbrand, Vigil Keeper** (P3's planted and range, P4, P5, P6's lifesteal, P11's plant delay, P13), and Wait to heal for any healing signature (Decision 4). Three different spots: Maren in a far corner, Brannoc forward into the enemies, Vell off to the side for Sunfall's line.
3. **The hero panel and the reports:** the panel (section 6), figures, the result's deeds, `--deeds` (with where allies stand behind Brannoc, for Guard) and `--paths`. Tune wave 1 with them; **playtest build.**
4. **Wave 2: Volley, Last Watch, Wardweaver** (P7 zones, P11's firing while walking, P3's HP and fallen-ally conditions and healing taken, P12, P6's overheal).
5. **Wave 3: Trapper, Hearthwall, Lanternbearer** (P8 snares and their placement, P9 Guard with its reach set from step 3's measurements, P10 the wall, Night Lantern on P7).
6. **Docs** (CLAUDE.md, design.md, this plan's notes), screenshots, and the gate 2 playtest build.

## Decisions (2026-09-29, the playtester's answers)

1. **All nine paths together** (changed 2026-09-29: the playtester can't test for a while, so the three waves are built back to back, with one playtest build at the end). The waves still set the order of work: Deadeye, Ironbrand, Vigil Keeper; then Volley, Last Watch, Wardweaver; then Trapper, Hearthwall, Lanternbearer.
2. **Upgrade pools come in phase 5**, with the after-fight pick. Nothing in phase 4 could offer an upgrade, and gate 2 doesn't test them. (The build order moves them.)
3. **How much stronger:** a vowed hero's team wins about as often as base (within about 5 points: the taste pays for its cost); a transformed hero's team wins **15–25 points more** than base across the encounters. The paths report tunes toward it.
4. **Wait to heal works with any healing signature:** it holds a signature that heals until an ally within the signature's reach is below 60%, so it keeps working on Lanternbearer (Night Lantern) and Vigil Keeper (Sunfall), as part 6's rule asks. Built in wave 1, with Sunfall.
5. **Ironbrand's transformed cost:** the line "Hold the Line only taunts adjacent enemies" is dropped, since Brand Slam replaces Hold the Line. His cost is the lost DEF.
6. **Guard's "behind" is open.** Away from his target seems the right direction, but in Practice fights nobody stays 1 hex behind Brannoc: he walks forward and the others are ranged, so a 1-hex Guard would rarely fire and Hearthwall's deed couldn't fill. Step 3's report measures how often an ally is 1, 2, or 3 hexes behind him (away from his target) during fights. Guard's reach, or another rule, is decided from that before wave 3 builds Hearthwall. With the waves built together, the measurement runs first (a scratch run, later the deed report), and the reach it suggests is used provisionally and flagged for the playtester. **Measured (2026-09-29)**, over every encounter's named and 20 drawn formations with base kits, on the ticks Brannoc has a target:

   | An ally within | behind him (away from his target) | on any side |
   | --- | --- | --- |
   | 1 hex | 3% | 18% |
   | 2 hexes | 19% | 40% |
   | 3 hexes | 41% | 69% |

   **Provisionally (flagged):** the taste's Guard covers an ally **behind him within 3 hexes** (the "behind" picture, often enough to fill the deed), and the transformation's covers **every ally within 2 hexes** at 30% (the design's "every adjacent ally", widened, since 1 hex is rarely anyone).
7. **Vell's transformed kits hold two heals** (decided provisionally 2026-09-29, while the playtester was away; flagged for them): the design gives Lanternbearer and Wardweaver both a changed Mend (every ally next to the target; Weave) and a new signature (Night Lantern; Warding Circle), and the sim has one signature per unit. They follow Vigil Keeper's own rule from the design: **the new move is the mana signature, and the changed Mend becomes a smaller heal on every 4th basic attack.** Transformed Wardweaver's signature (Warding Circle) doesn't heal, so Wait to heal can't be taken there (Decision 4's "any healing signature"); that's the one tactic a transformation still breaks, and it's flagged too.

## Open questions

- **Guard** (Decision 6): its reach, or another rule for which ally it covers, once step 3's measurements are in.
