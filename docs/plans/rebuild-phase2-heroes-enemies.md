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
| `test_new_pieces.gd` | section 4's pieces, one rule at a time |
| `test_sim_runner.gd` | the runner's report on a small run |
| Determinism | the chaos fight and the log audit keep passing. The audit gets rules for any new log kind |

**Speed:** `tools/bench_sim.gd` gets the swarm case; the speed pass keeps the steady and crowded fingerprints the same.

## 11. Order of work (each step: code, tests, green run, commit)

1. **Swarm speed pass** (section 1), measured with the new bench case and the chaos fight.
2. **Content files and loading:** hero, enemy, and encounter defs, `ContentDb`, the validator, `Encounters.setup`, and summon kits from content.
3. **Section 4's new pieces,** each with its tests.
4. **The three base kits** in `heroes.json`, and `test_hero_kits`.
5. **The nine enemies** in `enemies.json`, and `test_enemy_kits`.
6. **The encounters,** hand-placed, and `test_encounters`.
7. **The sim runner and the first tuning pass,** until the gate holds and fights run 30–60s. The results go in this plan.
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
