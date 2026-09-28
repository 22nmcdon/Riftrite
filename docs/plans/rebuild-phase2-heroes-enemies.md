# Rebuild phase 2: base heroes and the Act 1 enemies (build plan)

Status: **approved (2026-09-28), with the answers under Decisions.** Phase 2 of `docs/plans/rebuild-build-order.md`. Design sources: `rebuild-heroes.md` (the three base kits), `rebuild-enemies.md` (the Act 1 roster and how encounters scale), and `rebuild-arena.md`. It builds on the arena sim from phase 1 (`rebuild-phase1-arena-sim.md`). Numbers are placeholders; step 7 tunes them.

**Goal:** Brannoc, Maren, and Vell's base kits and the 9 Act 1 enemies as data, hand-placed encounters, and a headless sim runner that fights placed parties against them. **Done when** (the build order's gate) the sim runner shows **placement matters**: against each archetype, the same team wins clearly more with a good formation than with a bad one.

## Scope

**In phase 2:**

- A speed pass so summon swarms fit the sim's budget (the phase 1 plan's step 9 measured a 25-unit fight at 2.5s).
- Content files for heroes, enemies, and encounters, loaded and validated like `tuning.json` and `statuses.json`.
- The three base hero kits: no paths, vows, or deeds yet.
- The 9 Act 1 enemies, each with its threat line and archetype.
- About 9 hand-placed encounters: one question each, then a few combinations.
- The few sim pieces the kits need that the arena sim doesn't have yet (section 4). Each is listed so you can approve or change it.
- `tools/sim_runner.gd`: fights formations against encounters over many seeds, and reports how much placement changes the result.
- A first tuning pass, so fights run 30–60s and good placement pays.

**Not in phase 2:**

- **Paths, vows, tastes and costs, deeds, and upgrades** (phase 4).
- **The elites** (Hound Alpha, Witch Coven, Cairn Watch) and **Old Mother Ash**. The build order puts Old Mother Ash in phase 5 with the run, and the elites go there too (decided), since each needs a mechanic of its own (section 8).
- **Enemy specializations and upgrades** (phase 8).
- **The run:** days, fight choice, camp, relics, and duo bonds (phase 5).
- **Any UI** (phase 3). The fight card's threat line and archetype are stored now, so phase 3 only has to show them.
- **Difficulty for the whole act** (a good player clearing about half the time). That needs the run and the bot (phases 5 and 6). Phase 2 only makes each fight a fair positioning problem.

## Decisions this plan builds on

From the design plans:

- **A team is Brannoc, Maren, and Vell,** kept all run, with no draft until hero 4.
- **Every enemy tests one positioning question** and has an answer somewhere in the heroes' paths. Its threat line and archetype are shown before placement.
- **Harder means new problems, not more HP.** Stats grow only a little per day.
- **Enemy formations are hand-placed;** later encounters add rocks.
- **Fights last 30–60s.**
- **Heroes never step out of marked areas.** Placement is the skill.
- **Only signatures use mana.** A unit without a mana signature has no bar.
- Everything in phase 1's **Decisions** still holds (integer math, the fight's order, Engage, shots, the collapse, and so on).

---

## 1. Speed first: making swarms affordable

Step 9 of phase 1 measured the chaos fight (up to 25 units, 16 of them summoned) at about 2.5s for 65s, 2.1s of it in pathfinding. Old Mother Ash and every swarm encounter depend on this, so it comes first.

**Where the time goes** (the chaos fight):

| What | Searches | Cells settled | Share |
| --- | --- | --- | --- |
| `nearest` that finds no one | about 400 | 137,000 | the biggest |
| Walking back to safe ground | about 190 | 82,000 | next |
| Routes that find no way | about 80 | 27,000 | |
| Everything that succeeds | about 110 | 17,000 | small |

Each search also costs more when the board is crowded (about 8 µs a cell with 25 units, against 5 with 9).

**Where it stands when this plan was written** (`tools/bench_sim.gd` and the chaos fight, 2026-09-28, the same code as the end of phase 1; every fingerprint matched phase 1's last run):

| Fight | Time |
| --- | --- |
| Steady, 3 against 6, 42–57s | 105–117 ms per 60s (99–107 in phase 1's last run: this container varies by about 10%) |
| Steady, short fights (22–33s) | 113–156 ms per 60s (the first tick's searches weigh more in a short fight) |
| Crowded worst case (taunts every second, engaging hounds) | 168–263 ms per 60s |
| The chaos fight (up to 25 units, 65s) | 2.5s, three runs within 6% |

So the steady fight sits at the edge of its 100 ms budget again since the collapse (heroes walk round the crumbled edge to reach the back row), and swarms are far over. The speed pass aims at both.

**What I'll try, in this order, measuring each:**

1. **A failed search is remembered until the board changes.** A search that found no one reached a region of the board. While nobody enters or leaves that region's edge, searching again gives the same answer. So a unit keeps its "no one reachable" result until a unit that bounded it moves, falls, or joins, or the ground crumbles. This gives the same results as now, so the log fingerprints must stay the same.
2. **Cheaper search setup.** Each search clears three arrays of 3,420 cells and re-files every obstacle. The fix is to keep the obstacle buckets between searches in a tick and clear only the cells the last search touched. Results stay the same.
3. **Only if 1 and 2 aren't enough: look again less often after a failed `nearest`** (1s instead of 0.5s). This changes results; approved as a fallback only (Decisions).

**Budget:** the steady 3-against-6 fight stays under 100 ms per 60s. I propose a new **swarm** case in `tools/bench_sim.gd`: 3 heroes against a caller that brings 2 pups every 10s (about 12 at once), under **300 ms per 60s**. The chaos fight should drop from about 2.5s to under 0.5s.

**Built in step 1** (every log fingerprint unchanged: the steady, crowded, and swarm fights and the chaos fight all give the same logs as before):

- **The swarm case** in `tools/bench_sim.gd`: a tank, an archer, and a bruiser against a caller behind rocks with 4 pups, bringing 2 more pups every 5s near the heroes. At the caller's 1x and 2x HP, 10 and 16 pups stand at once, and the heroes lose at 45–49s.
- **Where its time went:** mostly `nearest` and route searches that find nothing, each flooding everything the pup can reach (about 1,000 cells).
  - With 2x HP, the pups packed every spot around the heroes, so no goal cell was free at all.
  - With 1x, free spots existed, but other pups walled them in.
- **What changed:** a walker whose last search of the same kind found nothing (`UnitState.nearest_failed`, or `no_path_since` for a route) first checks the goal cells around its targets (`NavGrid._pocket_closed`).
  - It floods out from the free goal cells, with the same moves the search uses (they work the same both ways), for up to 120 cells. If they're all taken, or they close off into a pocket without reaching the walker, the search can't succeed, so it fails at once.
  - The check only runs for melee reach (up to 1.5 hexes) and at most 4 targets. Ranged walkers' goal cells, and `nearest` over a crowd of enemies, rarely close off, and checking them cost more than it saved: in the chaos fight it first made fights about 8% slower.
  - `test_suspect_searches_match_plain_ones` checks, on 60 random crowds, that a checked search gives exactly the plain one's result.
- **Results** (the new code and the old run alternately, fastest of 2–3; this container varies by up to 40% between runs, so only side-by-side numbers compare):

| Fight | Before | After |
| --- | --- | --- |
| Swarm, 1x (49s, up to 10 pups) | 1.9–2.1s | 1.15–1.55s |
| Swarm, 2x (45s, up to 16 pups) | 2.2–3.0s | 0.64–0.87s |
| Chaos fight (65s) | 2.5–3.6s | 2.9–3.1s (no change within the noise) |
| Steady and crowded | unchanged within the noise | |

- **Not reached: the swarm's 300 ms per 60s.** The swarm at 1x still takes about 1.3s for 49s. What's left:
  - About 120 successful route searches (routes are planned again every 0.5s in a crowd) and the first failed search of each attempt.
  - The update of 15–20 units every tick.
  - Speeding up the search's setup (idea 2) wouldn't help much: setting up takes about 1.5% of the fight.
  - Looking again less often after a failed `nearest` (idea 3) would save about 5% now, since the checks already make those failures cheap. So I haven't used it: it changes results for little.
  - What would get there is fewer searches, and every way to get them changes results:
    - planning routes less often in a crowd (`repath_ms`);
    - keeping a route while it's still clear;
    - one search per side shared by all its walkers (a flow field) instead of one per walker.
  - That's a decision for you (see the report on step 1).

## 2. Content files

Kits stay `UnitDef`s (phase 1). Heroes and enemies each wrap one, as the phase 1 plan says.

**`data/heroes.json`:**

```json
{
  "id": "maren", "name": "Maren Thistledown", "title": "the ranger", "role": "damage",
  "kit": {...a UnitDef: stats, targeting, traits, mana, basic_attack, signature, passives...}
}
```

- `role` is one of `tank`, `damage`, `support`, `control`. Paths (phase 4) are added to this entry later.

**`data/enemies.json`:**

```json
{
  "id": "rift_hound", "name": "Rift Hound", "archetype": "flanker",
  "threat": "Pounces on your weakest back-liner",
  "kit": {...a UnitDef, phases included...}
}
```

- `archetype` is one of `swarm`, `flanker`, `caster`, `ranged`, `anchor`, `charger`, `disruptor`, `support`. The UI (phase 3) shows an icon for each.
- A summon names an enemy id. The fight's `summon_kits` are filled from content, so `FightSetup.summon_kits` stops being hand-built.

**`data/encounters.json`:**

```json
{
  "id": "the_pack", "name": "The Pack", "tests": "protecting the back line",
  "act": 1, "days": [2, 3],
  "enemies": [{"enemy": "rift_hound", "hex": [2, 4]}, {"enemy": "rift_hound", "hex": [5, 4]}],
  "rocks": [[3, 3]],
  "scale_bp": 10000
}
```

- `days` says when it can appear (the run uses it in phase 5).
- `scale_bp` multiplies enemy HP and ATK, for the small growth per day. It's 10000 in phase 2.
- **Validation:** known enemies and summons, each enemy in its own zone on its own hex, no rocks under units, and every status named exists (`FightSetup.validate` already does most of this). Ids are unique across heroes and enemies, so fight ids stay clear.

**Building a fight:** `Encounters.setup(content, encounter_id, formation, seed)` returns a `FightSetup` of the three heroes on the formation's hexes plus the encounter's enemies. A **formation** is `{"brannoc": [3, 2], "maren": [3, 0], "vell": [4, 0]}`.

**Built in step 2** (`HeroDef`, `EnemyDef`, `EncounterDef`, `Encounters`; the three files start empty, and steps 4–6 fill them):

- **A hero's or enemy's kit has no `id` or `name` of its own;** it takes the entry's. Heroes and enemies share one space of ids, since a fight names its units by them.
- **ContentDb checks across files:**
  - every kit's statuses exist (and aren't Engaged, which only the trait sets);
  - every summon names an enemy, onto hexes on the board;
  - every encounter's enemies exist, stand in the enemies' zone, and share no hex with each other or a rock;
  - its rocks are on the board, and its act has Rift Collapse numbers.
  - A placement with a malformed hex is reported once and skipped, so it doesn't cause a second, misleading error.
- **`Encounters.setup`:**
  - The heroes go in the fight's order as `heroes.json` lists them, never in the formation's own order (a Dictionary's). Then come the enemies, in the encounter's order.
  - `scale_bp` makes copies of the enemies' kits with HP and ATK scaled, and keeps their phases. Summoned enemies are scaled the same way; heroes never are.
  - Every enemy a unit may summon becomes a summon kit, and so do the ones those summon, in the order they're first named.
  - An unknown encounter or hero returns null with the reason. `FightSetup.validate` checks the formation (zones, shared hexes).

## 3. The three base kits

From `rebuild-heroes.md`, sections 4 and 6–8. Hero numbers are the design's; the mana columns come from its table.

| | **Brannoc** (tank) | **Maren** (damage) | **Vell** (support) |
| --- | --- | --- | --- |
| **Stats** | HP 420, ATK 14, DEF 30 | HP 270, ATK 22, DEF 8, CRIT 8, ATSP 10 | HP 300, ATK 6, MGK 20, DEF 10 |
| **Speed / range** | 2 / 1 | 2 / 4 | 2 / 3 |
| **Basic attack** | Shield Bash | Longshot (a shot) | Lantern Glow (a shot) |
| **Signature** | **Hold the Line** (80 mana): taunts enemies within 2 hexes for 3s; he has x1.5 DEF while any enemy is taunted by him | **Marking Shot** (50): Marked (+15% damage taken) for 4s | **Mend** (60): heals the ally lowest on HP% within 3 hexes |
| **Mana** | +8 an attack, +1 per 10 damage taken, starts at 30 | +10 an attack, 2/s, starts at 0 | +12 an attack, 2/s, starts at 20 |
| **Passive** | **Hearthguard:** the first ally to drop below 40% HP gets a Shield from him (once a fight) | **Keep Your Distance:** hops 1 hex away from an enemy next to her, once every 6s (`hop_away`) | **Hearthlight:** allies within 1 hex of her (not Vell herself) regenerate 1% of their max HP a second |
| **Trait** | Engage | | |

Hold the Line's DEF, Hearthguard, and Hearthlight need new pieces (section 4). Everything else is data on phase 1's sim.

**Built in step 4** (`data/heroes.json`, `test_hero_kits.gd`). The stats, mana, and texts are the table's. The table leaves some numbers open, so these are first numbers for step 7 to tune:

- **Basic attacks** deal 100% ATK. Cooldowns: Shield Bash 1.2s, Longshot 1s (0.9s with her ATSP 10), Lantern Glow 1.5s. With Vell's +12 an attack and 2/s regen, that's about 10 mana a second while she attacks, as `rebuild-heroes.md` expects.
- **Mend** heals 20 + 100% MGK (40 for Vell). It can pick Vell herself, since `lowest_hp_ally` includes the unit.
- **Hearthguard's Shield** is 60.
- **Hold the Line** is an unwarned 2-hex circle around Brannoc that applies Taunt for Taunt's own 3s. The DEF is a separate aura passive, also named Hold the Line (id `hold_the_line_guard`), so the log credits both to Hold the Line.
- **Marking Shot** Marks the nearest enemy in her range, for Marked's own 4s.
- **Hearthlight** heals 1% of each ally's max HP a second, rounded to the nearest whole HP (Brannoc 4, Maren 3).
- **Keep Your Distance** is the `hop_away` trait with a 6s cooldown. The log names it "Hop Away" (the trait's own name), not "Keep Your Distance".
- **The tests:** each kit's text in a small fight against still dummies, and a whole fight of the three against four brutes (a victory at 27.6s that uses every ability). All 21 mutations of the kit data are caught.

## 4. What the kits need that the sim doesn't have

CLAUDE.md rule 3: a new effect, trigger, or part type only when no combination of existing ones can express it, and said out loud. These are the ones I found, **approved** (Decisions).

| # | Needed by | Proposal | Why existing pieces can't do it |
| --- | --- | --- | --- |
| 1 | Brannoc's Hold the Line ("he gains DEF while they're taunted") | **An aura that holds while its holder is taunting:** `"while": "taunting"` on an `AuraDef` (`{"target": "holder", "stat": "def_bp", "value": 15000, "while": "taunting"}`). It's on while at least one standing enemy's Taunt in effect is the holder's, and auras are folded in again whenever one of the holder's Taunts starts or ends, or a taunted unit falls. It lives in Brannoc's kit as a passive credited to Hold the Line | Auras only follow the fight's clock. A timed boost can't follow the taunt: another unit's newer Taunt takes a taunted enemy away, and an upgrade may make the Taunt last longer or shorter (Decisions) |
| 2 | Brannoc's Hearthguard | **Let ability passives use `on_ally_below_hp`** (it exists for relics: `threshold_bp`, `once`), with `trigger_ally` as the target | The trigger exists but only relics can use it |
| 3 | Vell's Hearthlight | **A timed passive trigger `every_ms`**, **areas in passive effects** (unwarned, around the unit), and **heal `amount_bp_of_max_hp`** (of the healed unit's max HP) | Passives only react to events, and areas are only cast as abilities fire |
| 4 | Rift Pup ("+ATK for each adjacent pup") | **Damage `bonus_bp_per_ally_within`** (hexes and bp), counted as the attack fires | An aura that follows positions would have to be refolded every tick, which is costly; counting on the attack is cheap and reads the same |
| 5 | Ashling ("bursts into Burn on adjacent units when it dies") | **A passive trigger `on_fall`**: its effects run where the unit fell, as it falls (an area around it) | Nothing runs for a unit once it's down |

With these, every Act 1 enemy and base kit is data. The elites and Old Mother Ash need more (section 8).

**Built in step 3** (every log fingerprint unchanged: no existing fight uses the new pieces). Two names differ from the table above: the timed trigger is `on_interval` with `interval_ms` (like the other `on_` triggers), and the pup's bonus is an object on the damage effect, `"bonus_per_ally": {"bp": 2500, "within_hexes": 1, "kit": "rift_pup"}`, where `kit` is optional and limits the count to that kit.

- **`"while": "taunting"` on an aura:** it's on while at least one standing enemy's Taunt names its holder as the source. A newer Taunt from someone else takes that enemy over. Auras are folded in again when a Taunt starts or ends, and when a taunted unit falls. This only happens in fights where some unit has such an aura (`CombatSim.taunt_auras`), so other fights pay nothing for it. The AURA log shows each start and end, like a window's.
- **Passive triggers that aren't events** (`EffectDef.UNIT_TRIGGERS`). None of them names a hit, so none of them can use `hit_target` or `amount_bp_of_damage`.
  - They run in tick step 6, after the events are read and before phases, for each standing unit in the fight's order (`Passives.run_timed`).
  - `on_ally_below_hp` runs for an ally (never the holder itself) the first time it's below the threshold while it still has HP. It runs once per ally, or with `"once": true` only for the first ally, in the fight's order. `trigger_ally` aims at that ally. The allies it has run for carry over through a phase, like event counts.
  - `on_interval` runs every `interval_ms`, counted from the tick the unit joined the fight (a summon counts from when it was summoned). It never runs at the tick the unit joins.
  - `on_fall` runs as the unit falls, in the deaths step. Its area is anchored on where the unit fell, or it aims at `all_enemies` or `all_allies` (aiming at `self`, `target`, or `hit_target` is refused). Anyone it fells falls in the same deaths step, and their own `on_fall` runs too. The fallen unit is never hit by its own burst.
  - What these triggers do is marked from_event, like other passive effects, so it never sets off an event.
- **Areas in passives:** a passive's effect may be an area on any passive trigger (never `on_hit` or `on_crit`). It's anchored on the unit (`self`), on the unit the event names, or else on the unit's target. `"hits": "other_allies"` hits the unit's side, not the unit itself.
- **`amount_bp_of_max_hp` on a heal:** a share of the healed unit's max HP, taken as it lands, then the healer's heal auras. A heal takes exactly one of `amount` or `amount_bp_of_max_hp`, and it can't take `scaling` with the share.
- **`bonus_per_ally` on damage:** each other standing ally (of `kit`, if given) whose center is within `within_hexes` of the unit's center adds `bp` to the hit. It's counted as the attack fires (a shot or an area keeps the number it left with).
- **Tests:** `test_kit_pieces.gd`. All 48 mutation checks of the new code are caught.

## 5. The Act 1 enemies

First numbers, to tune in step 7. Every enemy has its archetype and threat line.

| Enemy | Archetype | Stats (HP / ATK / DEF, speed, range) | Kit | Threat line |
| --- | --- | --- | --- | --- |
| **Rift Pup** | swarm | 60 / 8 / 0, 3, 1 | **Pack Bite:** +25% damage for each other pup within 1 hex | "Swarms, stronger in packs" |
| **Ashling** | swarm | 80 / 6 / 0, 2, 1 | **Cinder Burst** (on falling): 3 Burn on every unit within 1 hex | "Bursts into flame when it falls" |
| **Rift Hound** | flanker | 180 / 14 / 4, 3, 1 | **Pounce** (fight start): leaps to the weakest back-liner within 4 hexes, then bites | "Pounces on your weakest back-liner" |
| **Cinder Moth** | caster | 140 / 8 / 0, 2, 3; flying | **Ember Dust** (40 mana): a warned 2-hex circle on your largest group that Burns | "Burns whoever stands together" |
| **Hollow Archer** | ranged | 160 / 16 / 4, 2, 5 | Hops away when approached (`hop_away`, 4s) | "Outranges your archers" |
| **Rift-Worn Sentinel** | anchor | 450 / 10 / 25, 1, 1; Engage | **Bulwark** (60 mana, mostly from hits taken): taunts heroes within 2 hexes for 3s | "Holds the line and draws your attacks" |
| **Cairn Guardian** | charger | 380 / 16 / 20, 2, 1 | **Rampart Charge** (60 mana): charges 3 hexes and knocks the first hero back 2 | "Charges through your front line" |
| **Bog Lurker** | disruptor | 260 / 12 / 8, 1, 1 | **Drag** (50 mana, within 5 hexes): pulls the farthest hero 2 hexes and Roots them | "Drags your back line forward" |
| **Gloam Witch** | support | 200 / 8 / 4, 2, 4 | **Ward** (every third attack): Shields every ally for 15. **Hush** (50 mana): Silences the hero with the most mana for 3s | "Shields her allies and silences your casters" |

- **Cinder Burst** hits every unit within 1 hex, heroes and enemies alike: bursting in the middle of its own swarm is part of the puzzle (decided for now).
- **The Witch's Ward** is a passive on her attacks, and Hush is her signature, since a unit has one signature.

**Built in step 5** (`data/enemies.json`, `test_enemy_kits.gd`). Stats, archetypes, threat lines, and kits are the table's. The table leaves some numbers open, so these are first numbers for step 7 to tune:

- **Basic attacks** deal 100% ATK. Cooldowns: pups and hounds 1s, Ashlings and Archers 1.2s, the Witch 1.3s, the Sentinel, the Guardian, and the Lurker 1.4s, and the Moth 1.5s.
- **Mana:**

  | Enemy | Signature cost | Per attack | Per 10 damage taken | Regen |
  | --- | --- | --- | --- | --- |
  | Cinder Moth | 40 | +10 | none | 2/s |
  | Sentinel ("mostly from hits taken") | 60 | +4 | +3 | none |
  | Cairn Guardian | 60 | +10 | none | 3/s |
  | Bog Lurker | 50 | +10 | none | 4/s |
  | Gloam Witch | 50 | +10 | none | 2/s |

- **Cinder Burst** puts 3 Burn on every unit within 1 hex. **Ember Dust** is a 2-hex circle (radius 2, the same reach `largest_group` counts by), warned for 1s, that puts 4 Burn on each hero in it. It's aimed within 5 hexes.
- **Pounce's bite** is 100% ATK. **Rampart Charge** does no damage of its own, as the table says: the charge and the 2-hex knockback are the threat.
- **Reach:** Drag and Hush can pick targets up to 5 and 6 hexes away, beyond the unit's own range, so they fire as shots and land a few ticks later. A pull stops at anyone in the way, and both units are Stunned, like any stopped push.
- **Ward** shields every standing ally, the Witch included.
- **The tests:** each enemy's threat in a small fight built for it. Every kit also fights together in the log tests: the three heroes against one of each enemy (`test_arena_log.content_setup`) must replay exactly from the log, with every entry naming its source. That fight is a loss at 23s, as expected against nine enemies at once. All 28 mutations of the enemy data are caught.

## 6. Encounters

About 9 for phase 2, hand-placed, each asking one question and then a few combining two:

| Encounter | Enemies | What it asks |
| --- | --- | --- |
| **Pup Warren** | 6 Rift Pups | closing lanes against a swarm |
| **Ash Nest** | 3 Ashlings, 2 Rift Pups | not fighting in a crowd |
| **The Pack** | 3 Rift Hounds | protecting the back line |
| **Moth Cloud** | 3 Cinder Moths, 2 Rift Pups | spreading out |
| **Hollow Line** | 3 Hollow Archers behind 2 rocks | closing distance |
| **Bog Crossing** | a Bog Lurker, 3 Rift Pups | back-line safety |
| **Sentinel Gate** | a Sentinel, 2 Hollow Archers | going around a wall |
| **Cairn Road** | a Cairn Guardian, 2 Rift Hounds | a tank knocked out of place, then flankers |
| **Witch Circle** | a Gloam Witch, a Sentinel, a Cinder Moth | target priority |

Placements and rocks are set in step 6 and tuned in step 7.

**Built in step 6** (`data/encounters.json`; tests in `test_encounters.gd`). Placements, rocks, and days are first choices for step 7 to tune:

| Encounter | Enemies (col, row) | Rocks | Days |
| --- | --- | --- | --- |
| Pup Warren | pups spread across the front and flanks: (0,4) (2,4) (5,4) (7,4) (1,5) (6,5) | (2,3) (5,3), making three lanes | 1–2 |
| Ash Nest | Ashlings clumped in the middle: (3,4) (4,4) (3,5); pups on the flanks: (1,4) (6,4) | | 1–2 |
| The Pack | hounds (1,4) (4,4) (6,4) | (3,3) | 1–3 |
| Moth Cloud | Moths at the back: (2,6) (4,6) (6,6); pups (2,4) (5,4) | | 2–3 |
| Hollow Line | Archers (2,6) (4,6) (6,6) | (3,5) (5,5), in front of them | 2–4 |
| Bog Crossing | the Lurker (3,5); pups (1,4) (4,4) (6,4) | (1,3) (6,3) | 3–4 |
| Sentinel Gate | the Sentinel (3,4) between rocks; Archers (1,6) (5,6) | (2,4) (4,4), a wall with the Sentinel | 4–6 |
| Cairn Road | the Guardian (3,4); hounds (1,5) (6,5) | | 4–6 |
| Witch Circle | the Sentinel (3,4), the Witch (3,6) behind it, a Moth (5,5) | | 5–6 |

- **Days:** Act 1 is about 7 days, with elites on two of them (phase 5) and the boss on day 7 (`rebuild-run.md`). So these fill days 1–6: single questions early, combinations from day 4. Every day offers at least two, since a day is a pick of two fights.
- **An encounter with no rocks leaves `rocks` out.** An empty list is refused, like every list the reader takes.
- **The tests:**
  - each encounter has section 6's roster, act 1, and scale 10000;
  - every day from 1 to 6 offers at least two encounters, and none comes on day 7;
  - each builds a valid fight from Brannoc guarding the other two, with its enemies and rocks where it says, and plays out with no errors and no tie.
  - Mutations that change an encounter's enemies or rocks are caught. Moving one encounter's days isn't: the test checks every day is covered, not which days each encounter comes on.
- **How they play now:** with the first numbers, every encounter is won from all four of the runner's formations (guarded, exposed, spread, clumped) on every seed, in 10–30s. That's too easy, and placement doesn't matter yet. Getting fights to 30–60s with the 30-point gap is step 7's work.

## 7. The sim runner

`tools/sim_runner.gd` comes back for placed parties:

```
godot --headless --path . -s tools/sim_runner.gd -- [--encounter=id] [--seeds=50] [--sweep=40]
```

- **Formations** live in `tools/sim_formations.json`: a few named ones every encounter is fought with, for example **guarded** (Brannoc in front of the other two), **exposed** (Maren and Vell up front, Brannoc behind), **spread** (three corners), and **clumped** (all three together).
- **The sweep** also fights `--sweep` formations drawn from the seed (every legal placement is 24 × 23 × 22, too many to try all). It reports the best, the median, and the worst, and prints the best and worst formations as boards (`ArenaDebug`).
- **For each encounter × formation,** it reports the win rate over the seeds (which only change crits), the median fight length, deaths per hero, and damage dealt and taken per hero.
- **"Placement matters"** (the gate): for each archetype's encounter, the best formation's win rate is at least **30 points** above the worst's, and the best isn't "any formation wins". 30 points is the bar for now, to revisit once the runner's first results are in (Decisions).
- A test runs the runner on one encounter with a few seeds, so it can't rot.

**Built in step 7:**

- **The runner:** `tools/sim_runner.gd`, as above, with its work in `tools/sim_report.gd` so `tests/tools/test_sim_runner.gd` can run it small.
  - The named formations live in `tools/sim_formations.json`: guarded, exposed, spread (Brannoc in front, the other two in the back corners), and clumped (the three side by side).
  - It also takes `--draw-seed` and `--no-boards`, and exits 1 if any encounter fails the gate.
  - The fight seeds only change crits, so a formation almost always wins every fight or none. The gate then really asks whether any formation loses while another wins, and one odd formation is enough. So the report also counts **how many formations win** (at least half their fights). The tuning aimed for about a third to two thirds of them.
- **The first tuning pass** changed only enemies, each in the encounter that asks its question, in this order: pups, hounds, Archers, Ashlings, Moths, the Lurker, the Sentinel, the Guardian, and the Witch. Heroes keep the design's numbers.

  | Enemy | HP (was) | ATK (was) | Other changes |
  | --- | --- | --- | --- |
  | Rift Pup | 210 (60) | 10 (8) | |
  | Ashling | 220 (80) | 18 (6) | Cinder Burst: 6 Burn (3) |
  | Rift Hound | 420 (180) | 16 (14) | |
  | Cinder Moth | 260 (140) | 8 | |
  | Hollow Archer | 460 (160) | 18 (16) | |
  | Rift-Worn Sentinel | 520 (450) | 10 | |
  | Cairn Guardian | 440 (380) | 16 | |
  | Bog Lurker | 640 (260) | 24 (12) | Drag about every 6s (8 regen, was 4), and a 3s Root (its own 1.5s) |
  | Gloam Witch | 300 (200) | 18 (8) | Ward: 30 Shield (15) |

- **Results** (10 seeds; 4 named and 40 drawn formations; draw seed 1, and draw seed 2 in brackets): every encounter passes the gate with a 100-point gap.

  | Encounter | Formations that win (of 44) | Median fight | Named formations that win |
  | --- | --- | --- | --- |
  | Pup Warren | 29 (21) | 33s | guarded, exposed, clumped; spread loses |
  | Ash Nest | 28 (29) | 31s | guarded, exposed; spread and clumped lose |
  | The Pack | 29 (36) | 35s | guarded, exposed, spread; clumped mostly loses |
  | Moth Cloud | 24 (26) | 33s | only spread |
  | Hollow Line | 28 (28) | 41s | none: the winners stand back and let the Archers come |
  | Bog Crossing | 32 (31) | 40s | exposed and spread |
  | Sentinel Gate | 28 (27) | 47s | only spread (around the wall) |
  | Cairn Road | 26 (29) | 40s | exposed (Brannoc behind the charge's reach); guarded and clumped sometimes |
  | Witch Circle | 31 (32) | 53s | guarded, spread, clumped; exposed loses |

- **What the results say, for later passes:**
  - Most encounters' losing formations fit their question: spreading out loses to the swarm, crowding loses to the Ashlings and the Moths, and only going around wins Sentinel Gate.
  - Hollow Line doesn't fit yet. It's won by standing back out of the Archers' first reach, not by closing distance.
  - Brannoc falls in almost every fight, wins included. The tank dying last is fine; dying every time may not be.
  - The swarm enemies are no longer small: a pup has 210 HP, most of Maren's 270. Heroes kept the design's numbers, so enemies grew instead. Shrinking heroes' damage instead would keep the table's enemy numbers; that's a choice for the next pass.

## 8. What the elites and the boss will need (phase 5, noted now)

The elites and Old Mother Ash come in phase 5 (decided). What they'll need, so the sim is ready when they come:

- **The Hound Alpha, "The Hunt":** when any hound Pounces, every hound Pounces on the same hero. It needs one unit's signature to set off its allies' signatures at a shared target: an "an ally fires X" trigger.
- **The Witch Coven, "Gloam Totem":** a totem that Shields every enemy within 2 hexes until it's destroyed. That's a unit with no attack and an `every_ms` area (piece 3).
- **The Cairn Watch, "Stone Ward":** data only (a Cairn Guardian and two Archers behind rocks).
- **Old Mother Ash:** her phases work now. **Molt's "stalks into the middle"** needs a way to walk to a spot rather than a unit. **Pack Bond** ("the pack takes less damage while a hound lives") needs an aura that checks whether allies are standing. **Summoning pups every 10s** is a mana signature with regen and no other mana source (possible now).

## 9. Files

**New:**

| File | What it holds |
| --- | --- |
| `src/sim/defs/hero_def.gd`, `enemy_def.gd`, `encounter_def.gd` | the entries in section 2 |
| `src/sim/setup/encounters.gd` | building a `FightSetup` from an encounter and a formation |
| `data/heroes.json`, `data/enemies.json`, `data/encounters.json` | the content |
| `tools/sim_runner.gd`, `tools/sim_formations.json` | the runner and its formations |

**Changed:**

- `content_db.gd`: loads the three new files, with cross-checks.
- `tools/validate_data.gd`: reports them.
- `nav_grid.gd`, `targeting.gd`, `movement.gd`: the speed pass.
- `tools/bench_sim.gd`: the swarm case.
- For section 4: `aura_def.gd`, `passives.gd`, and `statuses.gd` (the taunting aura and when it's folded in again), `effect_def.gd`, `events.gd`, and `effect_runner.gd` (the triggers, the heal and damage fields, areas in passives).

## 10. Tests

| Test file | Covers |
| --- | --- |
| `test_content_db.gd` | the new files load; every validation error reads clearly |
| `test_encounters.gd` | every encounter builds a valid fight from a formation; its enemies stand where it says; summons resolve to enemies |
| `test_hero_kits.gd` | each base kit does what its text says: Hold the Line taunts, and Brannoc's DEF holds exactly while an enemy is taunted by him (not after another unit's newer Taunt, and for as long as a longer Taunt lasts); Hearthguard shields once; Maren hops and Marks; Mend heals the lowest HP%; Hearthlight heals allies within 1 hex, not Vell |
| `test_enemy_kits.gd` | each enemy's threat happens: in a small fight built for it, the Pounce lands on the back-liner, the Moth's circle lands on the group, the Lurker drags the farthest hero, and so on |
| `test_kit_pieces.gd` | section 4's pieces, one rule at a time |
| `test_sim_runner.gd` | the runner's report on a small run |
| Determinism | the chaos fight and the log audit keep passing. The audit gets rules for any new log kind |

**Speed:** `tools/bench_sim.gd` gets the swarm case; the speed pass keeps the steady and crowded fingerprints the same.

## 11. Order of work (each step: code, tests, green run, commit)

1. **Swarm speed pass** (section 1), measured with the new bench case and the chaos fight. **Done,** with results unchanged; the swarm's budget isn't met yet (section 1).
2. **Content files and loading:** hero, enemy, and encounter defs, `ContentDb`, the validator, `Encounters.setup`, and summon kits from content. **Done.**
3. **Section 4's new pieces,** each with its tests. **Done.**
4. **The three base kits** in `heroes.json`, and `test_hero_kits`. **Done.**
5. **The nine enemies** in `enemies.json`, and `test_enemy_kits`. **Done.**
6. **The encounters,** hand-placed, and `test_encounters`. **Done.**
7. **The sim runner and the first tuning pass,** until the gate holds and fights run 30–60s. The results go in this plan. **Done** (section 7).
8. **Docs:** CLAUDE.md's "how it works" gains the content files and the runner; the design's open questions are updated.

## Decisions

Answers to the proposal's questions (2026-09-28):

1. **Section 4's new pieces are approved,** with piece 1 reshaped by answer 5.
2. **The elites come in phase 5,** with Old Mother Ash and the run.
3. **Cinder Burst hits every unit within 1 hex,** enemies included, for now.
4. **Hearthlight heals allies within 1 hex, not Vell herself:** 1% of the healed ally's max HP a second.
5. **Hold the Line's DEF follows the taunt itself, not a timer.** A fixed boost tied to the Taunt's length won't work: another unit can apply a newer Taunt, and an upgrade could make the Taunt longer or shorter. So the DEF and the Taunt are separate pieces: an aura that holds while any enemy is taunted by Brannoc (section 4, piece 1).
6. **The gate is 30 points** between the best and worst formation, probably; to revisit with the runner's first results.
7. **The speed pass's third idea** (looking again less often after a failed search) is tried only if the first two fall short.

After step 1 (2026-09-28):

8. **The swarm's remaining cost waits.** Step 1 made swarms 35–75% faster with the same results, but not within 300 ms per 60s. The rest needs a change to how fights play (fewer route plans, or one shared search per side), and it waits until Old Mother Ash's continuous summons come in phase 5, measured on real encounters then. Phase 2 moves on.
