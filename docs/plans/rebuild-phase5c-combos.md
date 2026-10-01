# Rebuild phase 5c: combos, the pools, and the new day

Status: **steps 1 and 2 built (2026-09-30 and 10-01): the damage rule, walkable crumbled ground, the Act 1 retune, and stat amounts on every card; step 3 (keywords and triggers, section 8) built (10-01); step 4 (permanent scaling, section 9) built (10-01); step 5 (the relic pool, section 10) split in four, 5a, 5b (section 11), and 5c (section 12) built (10-01), 5d (section 13) built (10-01): the relic pool is complete; step 6 (the loadout pool, section 14) built in five parts, 6a–6e (10-01); step 7 (the upgrade pools, section 15) built in four parts, 7a–7d (10-01); step 8 (the new day, section 16) approved, building in three parts: 8a built (10-01), 8b and 8c next; step 9 outlined.** Builds part 7 (`rebuild-combos.md`) and the plans agreed with it on 2026-09-30: the relic pool (`relics/`), the loadout pool (`loadout/`), the Magpie (`magpie.md`), the upgrade pools (`upgrade-pools.md`), duo bonds as keys to bond relics (`duo-bonds.md`), the economy (`economy.md`), the new day and its nodes (`days-and-nodes.md`), events (`events.md`), rift modifiers (`enemy-growth.md`, section 4), and what the UI must show for them (`ui-new-systems.md`). It comes before phase 6 (the good bot and tuning), starting with the damage rule (`rebuild-build-order.md`).

**How this plan works:** step 1 (the damage rule and walkable crumbled ground) is written in full below and is what's up for approval now. Steps 2–9 are outlined (what they build, the files, the tests); each gets its full section, like step 1's, added and approved before it's built. That keeps each approval to something small enough to check.

## Scope

In (in order): the damage rule; walkable crumbled ground; stat amounts on every card; keywords and triggers with the chain guard; permanent scaling; the relic pool with bond relics and the economy; the loadout pool with ranks, selling, gambits, and the Magpie; the upgrade pools; the new day (fight, pick, shop, node), Rift Tear's depths with rift modifiers, the Shrine's offerings, and events; the combo readout behind the testing toggle; then the Act 1 retune and a playtest build.

Out: apexes (phase 8, with Acts 2 and 3), enemy specializations, upgrades, and the rift learns (phase 8, "only when needed"), endless (after Act 3), the overall UI redesign (its own plan; this phase gives each system a working screen in today's style, with what `ui-new-systems.md` lists).

## Decisions

Decisions 1–4 were proposed with the plan; 5–8 are the playtester's answers (2026-09-30).

1. **One helper lands every number.** Damage, healing, Shields, and damage over time all go through one function that sums each kind's bonuses and multiplies the kinds, rounding once at the end (`rebuild-combos.md`, section 3).
2. **Every existing bonus gets a kind** (section 1.2's table). Nothing new is added in step 1: the only fights it changes are those where two bonuses of the same kind meet (they add instead of multiplying) and the rounding (once instead of at each step).
3. **Crumbled ground is walkable** (the decision of 2026-09-30): nobody is kept off it or walled off by it, and only rocks wall a target off. Standing on it hurts, as now.
4. **Act 1 is retuned once, after steps 1 and 2 together** (the build order's reason for pairing them).
5. **Casters first's +20% is power** (the playtester): it's the attacker's own bonus, so it multiplies with Marked (+38% on a Marked caster).
6. **Kit mods on an ability's amount are power** (the playtester): "Brand Slam hits 20% harder" is no longer baked into the ability when the kit is built; it's a power bonus of that effect, adding with the attacker's other power bonuses (the path costs' −2%, and later relics and charms). The same goes for heals and Shields (a heal's power, a Shield's power).
7. **Walkers avoid crumbled ground when they can** (the playtester): routes cost more across crumbled cells, so a unit goes round when a safe way isn't much longer, and steps off when it has nothing else to do; it crosses when that's the only way.
8. **The collapse's damage starts at 15 and grows as now** (the playtester): 15 a second at the first crumble (Act 1; it was 10), then +10 each second, the growth rising from the surge, so stalled fights still end.

## 1. Step 1a: the damage rule

### 1.1 What the sim does now

A hit is worked out in pieces, each rounding as it goes:

- **The base:** `EffectRunner.amount_of`: the effect's amount plus its scaling on ATK or MGK (ATK and MGK already include every stat change: `atk_bp` and `mgk_bp` auras, kit mods' `stats_bp`, and relics), times `bonus_bp_per_ally` if it has one. Kit mods that change an ability's amount (`amount_bp`, "Brand Slam hits 20% harder") are applied to the effect when the kit is built, so they're in the base too.
- **Power:** `Passives.boosted` multiplies by the unit's `damage_bp` aura (built: Volley's and Ironbrand's −2% costs); `heal_bp`, `shield_bp`, and `over_time_bp` the same way for heals, Shields, and statuses. Several auras of one stat **multiply** (`AuraDef.ADDITIVE` lists only crit chance, cooldown, and range as adding).
- **Crit:** `land` multiplies by `crit_damage_bp` (150%).
- **The tactic's payoff:** `deal_hit` multiplies by Casters first's +20% against casters and supports.
- **Vulnerability:** `deal_hit` multiplies by the target's Marked (+15%, the strongest one; a status doesn't stack with itself). Damage over time is marked up the same way (`Statuses`).
- **DEF, then Guard, then Shield:** after all of that (`mitigate_hit`, `Guards`, `apply_damage`).
- **Heals:** the tactic's heal payoff (Wait to heal +15%), `heal_bp`, then the target's `healing_taken_bp`.

So the kinds already multiply with each other. What changes is that bonuses **of one kind add**, and the rounding happens once.

### 1.2 The kinds

| Kind | For damage | Built sources |
| --- | --- | --- |
| **Base** | ATK or MGK times the ability's %, plus flat | the effect's amount and scaling; `bonus_bp_per_ally` |
| **Crit** | only when it crits: the crit's +50%, plus crit bonuses | `crit_damage_bp` |
| **Vulnerability** | the target's state | Marked |
| **Power** | the attacker's own bonuses | `damage_bp` auras (Volley's and Ironbrand's −2%); Casters first's +20% (Decision 5); kit mods' `amount_bp` on an ability (Decision 6) |
| **Relic** | relics' damage bonuses | none built (relics raise ATK or MGK) |

Heals, Shields, and damage over time use the same shape: base, then power (`heal_bp`, `shield_bp`, `over_time_bp`; Wait to heal's +15% is power, the healer's own), then the target's side (`healing_taken_bp` for heals, Marked for damage over time), then relic. DEF stays where it is: after the bonuses, never a bonus kind (part 7's "DEF works the same way" is about DEF bonuses adding within a kind, which `def_bp` auras then do too).

**Negative bonuses** are bonuses of their kind: Volley's −2% and a +20% power bonus make +18%. A kind's total never goes below −90% (a floor, so nothing hits for nothing).

### 1.3 The helper

- **`DamageRule`** (new, `src/sim/damage_rule.gd`): a small value that collects bonuses by kind (`add(kind, bp, note)`) and applies them (`apply(base) -> int`): `base × Π(1 + Σ kind)`, in basis points with `FixedMath`, rounded once. It also keeps the notes, so the log can say which bonuses applied.
- `EffectRunner.deal_hit`, `land`, `heal`, `give_shield`, and `Statuses`' damage over time build one `DamageRule` each and apply it; the scattered `apply_bp` calls go. `Passives.boosted` and `Tactics.damage_bonus_bp` stop multiplying and report their bonus to the rule instead.
- **Auras of one stat add** for `damage_bp`, `heal_bp`, `shield_bp`, `over_time_bp`, and `def_bp`/`atk_bp`/`mgk_bp`/`atsp_bp` (the stat auras): `AuraDef.ADDITIVE` grows to every stat, so two +10% auras make +20%, not +21%. (Two `atk_bp` auras don't exist yet on one unit; this is for the pools.)
- **The log:** a DAMAGE or HEAL entry's `bonus` keeps naming what applied ("+20% from Casters first"); nothing new is shown to players (part 7, section 7). The combo readout (step 9) reads the rule's notes.
- **Integers only** (rule 1): kinds are basis points; the product is taken with `FixedMath.mul_div` in a fixed order (crit, vulnerability, power, relic), so it's deterministic.

### 1.4 What moves

- **Fights:** only where rounding differs or two same-kind bonuses meet. The bench fingerprints (`tools/bench_sim.gd`) will move, since rounding once changes some hits by 1; the step records the new ones and checks the sim runner's gate still passes on all 18 encounters.
- **Numbers:** none change on purpose. The retune waits for step 2 (Decision 4).

**Built in step 1a (2026-09-30):** `DamageRule` (`src/sim/damage_rule.gd`): `apply(base, power, crit, vulnerability, relic)`, each kind floored at −90%, the factors combined at basis-point precision in that order and the number rounded once. `EffectRunner.land` takes the effect's power (`power_of`: `Passives.power_bp`, the unit's output aura for the effect's type plus the effect's `power_bp`, plus Wait to heal's payoff on heals); `deal_hit` adds Casters first's payoff to it, and applies the crit's +50% and the Mark; `heal` applies power and healing taken; Shields their power; damage over time the Mark. Shots, areas, and snares carry each effect's power (`powers`) to where it lands. A kit mod's `amount_bp` on damage, heals, and Shields is now `EffectDef.power_bp` (an echo's share still scales the numbers); the ability's numbers line shows it ("…, +20%"). Auras of one stat add their changes (`Passives.factor`). Tests: `tests/sim/test_damage_rule.gd`; three tests changed on purpose (two stacked auras, a per-fallen-ally aura twice, a heal mod as power). **The bench fingerprints are all unchanged:** no bench fight meets two bonuses of one kind or a rounding the rule changes.

## 2. Step 1b: walkable crumbled ground

### 2.1 What the sim does now

`Collapse` crumbles one ring every 10s from 45s. Nobody may walk onto crumbled ground (`CombatSim.fits`); a unit on it walks back first (`Movement.escape`, `NavGrid.find_safe`, `fits_leaving`); a unit whose target is past crumbled ground with no way round gives up on it (`Movement.walled_off`). From the first crumble, once a second, everyone whose center is on crumbled ground takes flat damage that **grows**: Act 1 starts at 10 a second and adds 10 each second, and from 90s the growth itself rises by 2 each second (`tuning.json`, `collapse_by_act`).

### 2.2 What changes

- **Walking:** crumbled ground is ordinary ground for `fits` and the nav grid. `fits_leaving`, `escape`, and `find_safe` go; `walled_off` counts only rocks.
- **Walkers avoid it when they can** (Decision 7): the nav grid's crumbled cells cost more than safe ones, so the shortest route goes round when a safe way isn't much longer; a unit with nothing to do (no target, or holding) steps off it; `fits` and `walled_off` no longer count it.
- **The damage** (Decision 8): Act 1's `base` goes from 10 to 15; the growth stays.
- **Knockback onto it** stays as it is (a push may end there; it hurts).
- **The log:** COLLAPSE damage entries stay; the "no way off crumbled ground" STOP goes.
- **The board:** nothing new to draw; units now walk across the collapse tiles.

### 2.3 What moves

Every fight that reaches 45s changes. After this step: the bench fingerprints, the sim runner's gate (all 18 encounters), and the Act 1 retune (Decision 4): encounters' `scale_bp` by tier, as in playtest gate 3 (`rebuild-phase5-run.md`, section 16), until the placement gate passes and the run report's pacing is back near where gate 3 left it (about 83% of bot runs won, every path transforming in most runs).

**Built in step 1b (2026-09-30):** crumbled ground is walkable. `NavGrid` keeps every cell of the arena free (obstacles aside) and charges 3x for a step onto a cell where the walker wouldn't stand wholly on safe ground (`CRUMBLED_COST_BP`), so routes go round it when they can; `Movement.walk` no longer escapes first, `CombatSim.fits_ground` is what walking checks, and `Movement.wait` replaces the escape: a unit with no target, holding its ground, planting, or planted by its feet steps off crumbled ground (`step_off`, the old way back), while one in reach fights where it stands. The spots a unit picks to land on (leaps, hops, a flier's landing, summons) still use `CombatSim.fits` (safe ground only). `walled_off` counts only rocks. Act 1's collapse starts at 15 a second (`tuning.json`). Tests: `test_collapse.gd`'s walking tests rewritten for the new rules (fighting on it, reaching a cornered target over it, a route round it, stepping off when idle, the way off round a rock or boxed in, a flier flying off), `test_nav_grid.gd`'s (walkable but dearer; the way back takes the fewest steps). The chaos fight's taunting ring is 1 hex out, not 2 (no longer herded inward, enemies stood two hexes off only by chance; seed 21 uses every piece again). Wardweaver's taste test (`test_path_kits.gd`) moved from Sentinel Gate to Hollow Line, where the taste still fills its deed after the retune. **The bench fingerprints change** for the fights that last past 45s (steady and crowded at x2–x3 HP now end at 47–52s, not 49–65s); the rest are unchanged.

**The retune** (the sim runner, `--seeds=5`; the gate passes on all 18): walkable ground made the long fights easier for the heroes (enemies that stood back now stand on crumbled ground and take its damage). Five fights were rescaled:

| Fight | Tier | scale_bp | Formations that win, of 44 (before the step, after the step, now) |
| --- | --- | --- | --- |
| Hollow Line | basic | 11250 → 11500 | 32, 36, 32 |
| Sentinel Gate | basic | 11750 → 12250 | 35, 42, 40 |
| Witch Circle | basic | 11250 → 11500 | 33, 40, 34 |
| Witch Coven | elite | 5750 → 7250 | 19, 39, 31 |
| Cairn Watch | elite | 12750 → 13000 | 21, 29, 25 |

The rest are as gate 3 left them (basic 30–35, harder 16–33, The Hunt 18, Old Mother Ash 19, which rose from 14 into its band). **The run report** (54 runs, the simple bot): 83% of runs won, as at gate 3; every path transforms in most runs vowed to it (Hearthwall least, 66%); 88% of Old Mother Ash fights won. **Two fights sit above their tier's band by formations, on purpose:** Sentinel Gate (40, 91%) and Witch Coven (31, 70%). Both flip at sharp steps: Sentinel Gate is 34 formations at 12500, but the bot's runs won only 71% of those fights; Witch Coven at 8500 was 19 (in the elite band), and the runs fell to 64% won, most lost to it (53% of its fights) on days 3 and 5, before most transformations. With the playtester's gate 3 finding (fights too hard) in mind, the easier step was kept for both; the playtester decides.

## 3. Steps 2–9 (outlined; each gets its full section before it's built)

| Step | What | Files (mostly) | Tests |
| --- | --- | --- | --- |
| **2. Stat amounts** (section 7; built) | Every card's stat change says its amount (part 7, section 6): a numbers line generated from the mod, like abilities' (`UnitInfo`), on items, upgrades, and relics; their `text` loses vague words | `src/ui/unit_info.gd`, a `ModInfo` for kit mods, `data/*.json` texts | every card with a stat mod shows its amount |
| **3. Keywords and triggers** (section 8) | Keyword flag on `StatusDef` (Marked, Rooted, Burning, Shielded, Stealthed; Bleeding joins with its sources); the new triggers (`on_crit`, `on_kill`, `on_apply`, `on_hit_keyword`, `on_shield_broken`, `on_ally_signature`, `on_heal`, `on_hop`) read from the log in `Events`; the chain guard (8 a tick) | `status_def.gd`, `events.gd`, `passives.gd`, `test_arena_log.gd`'s audit | each trigger, the guard, determinism with long chains, the chaos fight uses them |
| **4. Permanent scaling** (section 9) | Counters in run state, per hero and per run, fed from `FightResult` like deeds; growing mods take the counter into the fight's setup as a bonus; "Now: +X" on cards | `run_state.gd`, `run_flow.gd`, `HeroExtras` | counters survive a save; a growing card's value |
| **5. The relic pool** (section 10) | Five tiers plus bond relics, the pool's relics as data (built ones changed or cut, `relics/README.md`), one relic per shop with climbing rerolls, the pre-boss shop, boss relics after the boss, the Shrine's offerings, the income in `economy.md` | `relics.json`, `relic_def.gd`, `offers.gd`, `run_flow.gd`, `act1.json` | shop draws by tier, rerolls' prices, bond relics only with their bond, every relic's effect in a small fight |
| **6. The loadout pool** (section 14; built) | Tactics, gambits, sigils, and charms from `loadout/`, three ranks with each kind's counter, a bought copy skips a rank, selling at half, no "no effect" marker, grafts removed; gambits' placement rules (in `FightSetup.validate` and `Encounters.setup`); the Magpie as a node with his stall | `items.json`, `item_def.gd`, `run_flow.gd`, `tactics.gd`, `fight_setup.gd`, `magpie` offers | ranks and their counters, selling, each gambit's placement, the Magpie's stall |
| **7. The upgrade pools** (section 15) | `upgrade-pools.md`: each hero's 12, two taste upgrades per path until the hero transforms, four path upgrades and a growing one after; stacking stat upgrades locked in as a flat amount; Volley's taste back to every 4th | `upgrades.json`, `offers.gd`, `run_state.gd`, `paths.json` | the draw by stage, stacking's lock-in, the paths report for Volley |
| **8. The new day** (section 16) | Fight, pick, shop, then a node (Event, Camp, Rift Tear, the Magpie); camp as a node with its options; Rift Tear's three depths with rift modifiers; events and the Bloodied Oath; the day screen follows | `act_def.gd`, `run_flow.gd`, `offers.gd`, `camps.json`, `events.json` (new), `run_day_screen.gd`, `run_bot.gd` | the day's order, each node, each event, the bot plays whole runs |
| **9. The combo readout, the retune, and a build** | A readout behind the testing toggle (the rule's notes per hit, snowball tags); the sim runner's trigger report; the run report on the new run; tuning; docs; a playtest build | `log_panel.gd`, `tools/`, docs | the readout stays hidden without the toggle |

## 4. Files for step 1

- New: `src/sim/damage_rule.gd`; `tests/sim/test_damage_rule.gd`.
- Changed: `src/sim/effects/effect_runner.gd`, `src/sim/passives.gd`, `src/sim/tactics.gd`, `src/sim/statuses.gd`, `src/sim/defs/aura_def.gd`, `src/sim/arena/collapse.gd`, `src/sim/arena/movement.gd`, `src/sim/arena/nav_grid.gd`, `src/sim/combat_sim.gd`, `data/tuning.json` (the collapse's damage), `data/encounters.json` (the retune), and the tests whose numbers move on purpose.
- Docs: this plan's "Built in step 1" notes, CLAUDE.md's "How the arena sim works", `rebuild-arena.md`.

## 5. Tests for step 1

- **The rule:** same kind adds (15% and 20% vulnerability make ×1.35), different kinds multiply (15% vulnerability and 20% power make ×1.38), a crit's bonus only on a crit, negatives, the −90% floor, rounding once.
- **Every built bonus lands in its kind:** Marked, Casters first, Wait to heal, the path costs' auras, `healing_taken_bp`, damage over time on a Marked unit.
- **Crumbled ground:** a unit walks onto and across it; a target past it isn't walled off; rocks still wall a target off; the damage per second as decided.
- **Unchanged:** determinism, the log's audit, and every encounter still plays the same on the screen as `CombatSim.run` (`test_every_encounter_plays.gd`).

## 6. Order of work (each step: code, tests, green run, commit)

1. Step 1a, the damage rule; record the new fingerprints; the gate still passes.
2. Step 1b, walkable crumbled ground; the Act 1 retune; the run report; docs; a playtest build if the playtester wants one here.
3. Steps 2–9, each after its full section is approved.

## 7. Step 2: stat amounts on every card

Part 7, section 6: every card that changes a stat says the amount ("+15% DEF", never "your DEF is higher"). Approved 2026-10-01 (the playtester: "let's do step 2").

**What's there now:** items, upgrades, relics, and duo bonds each carry a sentence (`text`, or a relic's `boon` and `cost`) and a kit mod (`KitMod`) with the actual numbers; many sentences name no amount ("You walk faster.", "Hearthwall needs less mana."). Abilities already solve this: the sentence says what it's for, and `UnitInfo` adds a numbers line generated from the kit.

**What step 2 builds:** the same for kit mods. `ModInfo` (`src/ui/mod_info.gd`) turns a mod into a numbers line, one part per change, joined by " · ":

| Mod part | Numbers line |
| --- | --- |
| `stats_bp` | "+15% DEF", "−8% HP" |
| `stats_add` | "+1 Speed", "+5 CRIT" |
| `on` (a slot's change) | the slot, then each change: "Signature: +20% damage, +2s duration, +1 hex area, −10% cooldown"; an added effect as the ability numbers line writes it ("on crit: Slow 2s"); a passive's delay ("Steady: 1s sooner") |
| `passives` | each added passive's name and numbers line, as the hero panel shows a passive |
| `mana` | "−15 max mana", "+20 starting mana", "+2 mana per attack" |
| `also_fires` | "Signature also fires: once, below 40% HP" (the trigger as `UnitInfo` writes it) |
| `echo` | "Signature fires again 2s later at 50%" |

A tactic item takes its tactic's numbers line (`UnitInfo.tactic_numbers`). A relic's line adds its run rules too: "+1 loadout slot", "+5% HP lost per wound", "every fight Scouted", "+1 shard on every price", "+2 shards per won fight", "2 cards on each pick", and says who each mod is for ("Heroes: …", "Enemies: …", "After a Rest: …"). A duo bond's line is its mod for that path's hero.

**Where it shows:** under the sentence on every card (shop and Magpie wares, the loadout, the after-fight pick, a relic choice), in the hero panel's item, upgrade, and bond rows, and in the tooltips of the hero bar's chips and the top bar's relics. Where a card is for one hero (an upgrade, a slotted item), amounts that scale with a stat are worked out from that hero's kit; a ware for anyone shows the formula ("50% ATK").

**Decisions:**
9. **The sentence stays; the amounts are generated** (as for abilities: the data's `text` says what it's for, the UI adds the numbers). The vague sentences aren't rewritten now: steps 5–7 replace nearly every item, upgrade, and relic with the pools', which are written with their amounts.
10. **Players see these lines** (they're the card's own numbers, not a combo readout; part 7, section 7).

**Built in step 2 (2026-10-01):** `ModInfo` (`src/ui/mod_info.gd`) as above; every item, upgrade, relic, and bond in the data gets a line (Sigil of Haste: "−12 max mana"; Bloodstone: "Heroes: −8% HP · +12% ATK"; Quick Footing: "Steady: 0.5s sooner · Steady Aim: 0.5s sooner · transformed: …"). It shows under the sentence on the shop's and the Magpie's wares, the after-fight pick, and relic choices; after the sentence in the hero panel's item, upgrade, and bond rows; and in the hero bar's chips' and the top bar's relics' tooltips. `UnitInfo`'s aura amounts now read as the damage rule adds them ("+50% DEF", not "x1.5 DEF"; `signed_percent`), and a kit mod's power on an ability shows after its amount (step 1a). Tests: `tests/ui/test_mod_info.gd` (each part's words, a scaled effect from the hero's kit, a line for every card in the data, every stat change named, relics' run rules, a tactic item), `test_run_screens.gd` (a ware's card shows its line), `test_unit_info.gd` (the aura amounts). No fight changed.

**Files:** `src/ui/mod_info.gd` (new); `run_day_screen.gd` (item, upgrade, relic cards), `hero_panel.gd` (items, upgrades, bonds), `hero_bar.gd` (chip tooltips), the top bar's relic tooltips. **Tests:** `tests/ui/test_mod_info.gd`: each mod part's words; every item, upgrade, relic, and bond in the data has a numbers line naming each of its stat changes; the cards show it (`test_run_screens.gd`). No fight changes: the bench fingerprints and the run report stay as they are.

## 8. Step 3: keywords and triggers

Part 7, sections 1 and 2: shared keywords, more triggers, and the chain guard. **Approved and built 2026-10-01** (8.9, 8.10). Step 3 builds the vocabulary that steps 5–7 write the relic, loadout, and upgrade pools in; it adds **no content** (no item, relic, or upgrade changes), so the only fights it can change are those where a built event passive now sets off another (8.4).

### 8.1 What the sim does now

- **Statuses** (`StatusDef`, `data/statuses.json`) have a kind and numbers; nothing groups them under a name cards can use. Shield isn't a status: it's a number on the unit (`UnitState.shield`).
- **Events** (`Events.dispatch`) are read from each tick's log after every unit has acted: `on_basic_attack`, `on_ability` (its signature fires), `on_holder_crit`, `on_shielded`, `on_hit_taken`, `on_heal`, `on_status` (with a `statuses` filter), `on_kill` (credited to the last hitter, damage over time included), and `on_hop`. Passives (`Passives.on_event`) and count signatures listen; `every` runs an effect on every Nth.
- **No chains:** what an event effect does is marked `from_event`, and `from_event` entries raise nothing, so one event effect never sets off another.
- **Conditions:** an aura can be on while its holder is taunting, planted, below an HP share, or has a kit ally standing; Casters first's +20% is the only bonus that looks at the target (by archetype, in `Tactics`).

### 8.2 Keywords

A keyword is a name for a state any card can refer to (part 7, section 1). Five, as agreed:

| Keyword | A unit has it while | From |
| --- | --- | --- |
| **Marked** | it has a `marked` status | `"keyword": "marked"` on Marked |
| **Rooted** | it has a `root` status | `"keyword": "rooted"` on Root |
| **Burning** | it has Burn stacks | `"keyword": "burning"` on Burn |
| **Stealthed** | it has a `stealth` status | `"keyword": "stealthed"` on Stealth |
| **Shielded** | its Shield is above 0 | built in (Shield isn't a status) |

- **`"keyword"` on a status** (`StatusDef.keyword`, optional; `ContentDb` checks it's one of the names, and that two statuses may share one). Bleed gets `"bleeding"` when its sources arrive (step 6, Bloodletter), as the outline says.
- **`Keywords`** (new, `src/sim/keywords.gd`): the names, and `has(unit, keyword)`. Keywords are team-wide by nature: they're the unit's state, whoever put it there.
- The flag alone changes nothing in a fight.

### 8.3 Conditions

One shape, `UnitCondition` (new, `src/sim/defs/unit_condition.gd`), for "a unit that is …", used wherever a card looks at a unit's state. Every field given must hold; a list holds if any of it does:

```
{"keywords": ["rooted"]}                          Rooted
{"statuses": ["root", "stun"]}                    Rooted or Stunned (any status id: Slow, Engaged, ...)
{"below_hp_pct": 30}                              below 30% HP
{"flying": true}                                  a flier
{"archetypes": ["caster", "support"]}             what Casters first looks for
```

Where it's used:

| Where | Data | What it does | For (steps 5–7) |
| --- | --- | --- | --- |
| **An event's other unit** | `"vs": {...}` on an event effect | runs only if the unit the event names meets it (the enemy hit, the one that fell, the one the status went on) | "crits on Marked enemies …", "when a Rooted enemy dies …" |
| **An attacker's bonus** | `"vs": {...}` on a `damage_bp` aura | power against targets that meet it, added in `deal_hit` (Casters first's shape, for any card) | "+25% damage to Rooted or Stunned enemies" (Opportunist), "Rooted enemies take +25% damage" (Thornwoven Cloak) |
| **The holder's own state** | `"while": "state", "state": {...}` on an aura | on while its holder meets it (checked each tick, like the other conditions) | "Shielded allies deal +15%", "+15% ATK while Stealthed" |

**Every "+X% damage to [some enemies]" bonus is power** (Decision 12), whether a hero's card or a relic says it ("Rooted enemies take +25% damage" is a `vs` aura on every hero, through the relic's `mod`). Only Marked, and later statuses that make a unit take more damage, are vulnerability. So no "damage taken" aura stat is added.

### 8.4 Triggers

Part 7's list, against what's built. Each names the unit it's about (`hit_target`) and, where there's one, a number (`amount_bp_of_damage`):

| Part 7 | In the sim | New? | The unit it names; the number |
| --- | --- | --- | --- |
| `on_crit` | `on_holder_crit` | gains `vs` | the enemy hit; the hit |
| `on_kill` | `on_kill` | gains `vs` (read as the enemy falls, before its statuses clear) | the enemy that fell; — |
| `on_apply(keyword)` | `on_status` | gains `keywords` (beside `statuses`) | the unit it went on; — |
| `on_hit_keyword(keyword)` | **`on_holder_hit`** | new: one of the unit's hits lands on an enemy (a DAMAGE entry, not damage over time), with `vs`, `every`, and `once` | the enemy hit; the hit |
| `on_shield_broken` | **`on_shield_broken`** | new: a hit or damage over time takes the last of the unit's Shield | whoever broke it; the Shield that hit took |
| `on_signature` | `on_ability` | — | — |
| `on_ally_signature` | **`on_ally_ability`** | new: an ally's signature fires (each standing ally of the caster) | the ally who fired; — |
| `on_heal` | `on_heal` | — | the unit healed |
| `on_hop` | `on_hop` | — | — |

- **`once`** on an event effect (it exists for timed ones): only the first time in a fight ("the first enemy each hero hits is Marked").
- **Team-wide cards are passives on every hero.** Relics are already kit mods applied to every hero (`RelicDef.mod`), so "when a hero fires a signature, the other heroes gain 6 mana" is an `on_ability` passive on each hero; only the caster's copy runs. "When a Burning enemy dies …" is an `on_kill` passive with `"vs": {"keywords": ["burning"]}` on each hero, so it runs once, for the hero credited with the kill (Decision 13).
- **A Shield isn't tracked by who gave it**, so `on_shield_broken` is the holder's (part 7's "or one it gave" is left out: Shields from several givers are one pool).
- **The log** gains no kinds: DAMAGE and STATUS_DAMAGE entries get `broke_shield`, set where the Shield runs out; every trigger is read from entries already logged (rule 4 holds as it does).
- **Not in step 3:** the pieces the pools need that come with their content: timed boosts ("+30% attack speed for 3s"), lifesteal from every source, crit damage bonuses, ignoring DEF, leaving Stealth, and each relic chain's own steps (Crown of Stars, Shared Pain, The Hungering Rift, Overcharge). Each step that brings a card needing one says so in its section.

### 8.5 The chain guard

Part 7: "an effect caused by a trigger can set off other triggers, but one chain stops after a set depth per tick."

- **Every log entry carries `chain`:** 0 for anything a unit does on its own; an event effect's entries get the `chain` of the entry that set it off, plus 1. `from_event` stays (true when `chain` > 0) for the chart's basic-attack split.
- **Chains resolve in the tick they start:** `Events.dispatch` keeps reading while the log grows, in log order, so the order is fixed (rule 1).
- **The limit:** an entry whose `chain` is at the limit raises nothing. The limit is `chain_limit` in `tuning.json` (8, part 7's guess), so Chain of Echoes (boss, step 5) can raise it for a fight.
- **Kills:** `on_kill` is raised in the deaths step; its chain is the killing hit's plus 1 (`UnitState.last_hit_chain`).
- **What changes for what's built:** event passives can now set each other off (a thorns item's damage raising the attacker's own `on_hit_taken`, say). That's the rule part 7 agreed; fights where it happens change. The step records the bench fingerprints and reruns the sim runner's gate; nothing is retuned for it unless the gate fails (the retune is step 9's).
- **Speed:** a fight with no listeners never enters the loop; the bench stays under its budget, and a fight built to chain at the limit every tick is benched too.

### 8.6 The UI

- **Numbers lines** (`UnitInfo`, `ModInfo`): the new triggers and conditions in words ("on a crit against a Marked enemy", "when your Shield breaks", "every 4th hit on a Rooted enemy", "+25% damage to Rooted or Stunned enemies", "while Rooted: takes +25% damage").
- **Nothing else:** keywords are status names the board already tags (Burn's tag stays "Burn"); chains show nothing to players (part 7, section 7; the readout is step 9's).

### 8.7 Files

- New: `src/sim/keywords.gd`, `src/sim/defs/unit_condition.gd`; `tests/sim/test_keywords.gd`, `tests/sim/test_triggers.gd`.
- Changed: `status_def.gd` (`keyword`), `content_db.gd` (checks), `data/statuses.json` (four keywords), `effect_def.gd` (the three triggers, `vs`, `keywords`, `once` on events), `aura_def.gd` (`vs`, `"while": "state"`), `events.gd` (the new events, the chain), `passives.gd` (filters, chain depth), `effect_runner.gd` (`vs` power, `broke_shield`), `statuses.gd` (`broke_shield`, Burning), `log_entry.gd` (`chain`, `broke_shield`), `unit_state.gd` (`last_hit_chain`), `tuning_def.gd` and `data/tuning.json` (`chain_limit`), `unit_info.gd` and `mod_info.gd` (the words), `tests/sim/chaos_fight.gd`.
- Docs: this section's "Built in step 3" note, CLAUDE.md's "How the arena sim works" (keywords, conditions, the triggers, chains), `rebuild-combos.md` (where part 7's names meet the sim's).

### 8.8 Tests

- **Keywords:** each of the five holds exactly while its state does (Burning ends with the last stack; Shielded ends when the Shield runs out); `ContentDb` refuses an unknown keyword.
- **Conditions:** each field, a list as any-of, all fields together.
- **Each trigger:** fires on its event, names the right unit and number, honors `vs`, `keywords`, `every`, and `once`; `on_shield_broken` from a hit and from damage over time, and not when a hit leaves Shield standing; `on_ally_ability` never for the caster itself; `on_kill` with `vs` reads the fallen's keywords.
- **Bonuses:** a `vs` aura is power (adds with the attacker's others, multiplies with a Mark) and counts only against targets that meet it; an aura `while` its holder is Rooted turns on and off with the Root.
- **The chain guard:** two units whose passives set each other off stop at the limit, in one tick, every time (determinism); a chain one step short of it runs in full; `chain_limit` from tuning; kills carry the chain.
- **Unchanged:** determinism, the log's audit (no new kinds, so no new rules), every encounter on the screen as `CombatSim.run` gives it, and the chaos fight, which gains a passive on each new trigger and a keyword condition and must still use every piece.

### 8.9 Decisions (the playtester, 2026-10-01: "approve, build it")

11. **Step 3 is built as this section says.**
12. **Every bonus against some enemies is power** (Question E: "all power"): a hero's "+X% damage to Rooted enemies" and a relic's "Rooted enemies take +X% damage" alike. Only Marked (and later statuses that make a unit take more damage) is vulnerability; Casters first stays power (Decision 5).
13. **A death counts for the hero credited with the kill** (Question F): the last to hit it, damage over time included. An enemy no hero hit sets off nothing, and team-wide cards stay passives on each hero.

### 8.10 Built in step 3 (2026-10-01)

- **Keywords:** `Keywords` (`src/sim/keywords.gd`) and `"keyword"` on Marked, Root, Burn, and Stealth (`data/statuses.json`); Shielded is a Shield above 0, and a status can't claim it.
- **Conditions:** `UnitCondition` (`src/sim/defs/unit_condition.gd`), with `describe()` for the log and cards ("Rooted or Stun, below 30% HP"). A `damage_bp` aura's `"vs"` isn't folded into the unit's multiplier: `Passives.rederive` keeps each one on the unit (`vs_conditions`, `vs_bonus_bp`) and `EffectRunner.deal_hit` adds the matching ones to the hit's power (only when some unit has one, `CombatSim.vs_auras`). `"while": "state"` is a conditional aura, checked each tick with the others. Status ids a condition names are checked like any the kit names.
- **Triggers:** `on_holder_hit`, `on_shield_broken`, and `on_ally_ability` in `EffectDef` and `Events`; `keywords` on `on_status`; `vs` and `once` on event effects (`vs` refused on events that name no unit); `on_kill` names the fallen. A hit or damage over time that takes the last of a Shield sets `broke_shield` on its entry; a Guard's share doesn't (its GUARD entry raises no events).
- **Chains:** `LogEntry.chain`, set by `CombatSim.new_entry` from `chain_depth` while a passive's effect runs (`Passives._run`), and checked against `chain_limit` (`tuning.json`, 8) in `Events.dispatch`, which now reads on while the log grows and returns where it stopped. Timed passives' and on_fall's effects are a chain's first link too (they were marked from_event before and raised nothing). A kill carries its hit's depth (`UnitState.last_hit_chain`).
- **The UI:** numbers lines name the new triggers and conditions ("Every 3rd hit on a unit that's Burning", "Once, on its first hit", "+20% damage against Marked", "+30% ATSP while Stealthed"), and a passive that answers more than one event names each trigger where it changes.
- **Tests:** `tests/sim/test_keywords.gd` (11) and `tests/sim/test_triggers.gd` (13). Two tests in `test_passives.gd` changed on purpose: what a passive does now sets off events (Spite's hits count for a count signature; a passive's own crits count as crits). The chaos fight gained a passive on each new trigger, a keyword filter, a `vs` aura, a state aura, and a two-link chain, and moved to seed 23 (21 lost its Taunt); `test_determinism` checks each. `test_unit_info.gd` has the new lines.
- **What moved:** nothing that's built. The bench's fingerprints are all unchanged, and the sim runner's gate passes on all 18 encounters with the same counts of formations that win as after step 1 (Hollow Line 32, Sentinel Gate 40, Witch Coven 31, Cairn Watch 25, The Hunt 18, Old Mother Ash 19, ...): no built kit has passives that set each other off in these fights. The bench gained a **chains** fight (steady with every unit hitting back on every hit taken, so every hit runs a chain to the limit): about 320–360 ms per 60s on this machine, against 150–200 for steady.

## 9. Step 4: permanent scaling

Part 7, section 4: some upgrades and relics **grow every fight for the rest of the run**, counting something the hero does the way deeds do, and the card shows its current value. **Approved and built 2026-10-01** (9.9, 9.10). Step 4 builds the machinery, the counters the agreed growing cards need, and the twelve growing upgrades (Decision 16).

### 9.1 What's there now

- **Deeds** are the model: every hero counts its three paths' deeds in every fight (`Deeds`, kinds and filters in `DeedDef`), the totals come back on `FightResult.deeds`, and `RunFlow.record` adds them to `RunState.Hero.deeds`. Counting never changes a fight.
- **Cards** are kit mods: `RunFlow.fight_setup` gathers each hero's upgrade, loadout, relic, camp, and bond mods into `HeroExtras`; nothing in a mod depends on the run's history.

### 9.2 The growing cards (agreed)

| Card | Where (built in) | Grows by | Counts |
| --- | --- | --- | --- |
| **Notched Bow** (Maren) | hero pool (step 7) | +1% ATK | per 10 enemies she Marks |
| **Weathered** (Brannoc) | hero pool (step 7) | +1% max HP | per 1,000 damage he takes |
| **Lamp Oil** (Vell) | hero pool (step 7) | +1% MGK | per 500 healing she gives |
| **Hunter's Tally** (Deadeye) | path pool (step 7) | +1% damage | per 500 damage dealt from 5+ hexes |
| **Patient Hunter** (Trapper) | path pool (step 7) | +1% damage to Rooted enemies | per 5s of root |
| **Arrow Glut** (Volley) | path pool (step 7) | +1% attack speed | per 25 extra targets hit |
| **Old Scars** (Hearthwall) | path pool (step 7) | +1 DEF | per 200 damage taken for allies |
| **Brandmarks** (Ironbrand) | path pool (step 7) | +1 ATK | per 30 extra enemies cleaved |
| **Borrowed Time** (Last Watch) | path pool (step 7) | +1% damage below 30% HP | per 3s spent below 30% HP |
| **Kindled Flame** (Lanternbearer) | path pool (step 7) | +1% healing | per 300 healing next to Mend's target |
| **Woven Deep** (Wardweaver) | path pool (step 7) | +1% Shield size | per 300 Shield given |
| **Sunwrought** (Vigil Keeper) | path pool (step 7) | +1% smite damage | per 200 smite damage |
| **Collector's Chain** | rare relic (step 5) | heroes +1 ATK | per 10 enemies the team kills |
| **Tally of the Dead** | rare relic (step 5) | heroes +2% max HP | per elite fight won |
| **Rift-Fed Blades** | legendary relic (step 5) | heroes +1% ATK | per 1,000 basic-attack damage the team deals |
| **Chalk Ledger** (a quest) | rare relic (step 5) | Marked enemies take +10% more damage, once | 40 enemies the team Marks |

Rift-Bound Heart (boss: "every growing upgrade and relic grows twice as fast") is step 5's; it doubles what's counted while it's held.

### 9.3 A growing card

A card gets `"grows"` beside (or instead of) its `"mod"`:

```
"grows": {"counts": {"counts": "damage", "beyond_hexes": 5}, "per": 500,
          "each": {"on": [{"slot": "abilities", "types": ["damage"], "amount_bp": 10100}]}}
```

- **`counts`:** a `DeedDef`'s counting (its kind and filters), so a growth counts exactly as a deed does.
- **`per`:** how much of it makes one step. Steps are whole (`count / per`, rounded down); **no cap** unless `"max_steps"` says so (a quest is `"max_steps": 1`).
- **`each`:** what one step gives, a kit mod limited to what scales cleanly: `stats_bp`, `stats_add`, an ability's `amount_bp`, and added auras. The fight gets that mod **times the steps** (`KitMod.times(n)`: each change n times, and by the damage rule changes of one kind add, so ten +1% steps are +10%, not x1.01¹⁰). A growth's mod goes in with the card's other mods, in the same place.
- **Who counts:** a hero's card counts its holder; a relic counts the whole team (each hero's count, added up). Tally of the Dead counts won elite fights in the run layer, not in the sim.

### 9.4 Counting in the fight

- **`UnitSetup.tallies`:** the growths a hero counts this fight (each a key and a `DeedDef`), beside `deed_paths`. `Deeds.Counter` counts them with the deeds, by the same rules; `FightResult.tallies` carries the totals (hero, key, amount). Counting never changes a fight (the bench fingerprints stay).
- **New kinds and filters** the agreed cards need (`DeedDef`; each a code change, skipped by a counter that doesn't use it):
  - `applied`: statuses the hero applies to enemies (with `keywords`: only those; Notched Bow, Chalk Ledger);
  - `taken`: damage the hero takes (Weathered);
  - `ms_below`: time the hero spends below `while_below_pct`, checked as each tick ends (Borrowed Time);
  - `kills`: enemies the hero is credited with felling (Decision 13's credit; Collector's Chain);
  - `from_basic: true`: only what the hero's basic attack does (Rift-Fed Blades).

### 9.5 The run

- **`RunState.Hero.growth`** (card id -> counted since it was taken) for upgrades and a held item, and **`RunState.growth`** for relics (relic id -> the team's count). `RunFlow.record` adds each fight's tallies; a lost fight counts too (it was fought). Saved with the run; old saves load with nothing counted (no version bump: the fields default to empty).
- **`RunFlow.fight_setup`** and **`kit_of`** add each growth's `each.times(steps)`.
- **When counting starts:** from when the card is taken (Decision 15).
- **The run report** gains what each growing card reached by the run's end (mean steps, and the most), so tuning can see how far they grow.

### 9.6 The UI (`ui-new-systems.md`, section 4)

- **The card's numbers line** (`ModInfo`): "Grows: +1% damage per 500 damage dealt from 5+ hexes" on a card not yet taken.
- **Once held:** "Now: +12% damage (412 / 500 damage to the next)" in the hero panel's upgrade row and the top bar's relic tooltip; a small "grows" mark on the card.
- **After a fight:** the after-fight screen lists what grew ("Notched Bow: +1% ATK"), only for cards that stepped up.
- Nothing during a fight (part 7, section 7).

### 9.7 Files

- New: `tests/run/test_growth_cards.gd`, `tests/sim/test_tallies.gd`.
- Changed: `deed_def.gd` (the kinds and filters), `deeds.gd` (tallies, the new kinds), `unit_setup.gd`, `encounters.gd` (`tallies` in `extras`), `fight_result.gd` (`tallies`), `kit_mod.gd` (`times`, the `each` limits), `upgrade_def.gd`, `relic_def.gd`, `item_def.gd` (`grows`), `run_content.gd` (checks), `run_state.gd`, `run_flow.gd`, `mod_info.gd`, `hero_panel.gd`, `run_day_screen.gd` (after the fight; the top bar), `tools/run_report.gd`, and `data/upgrades.json` (the twelve growing upgrades).
- Docs: this section's "Built in step 4" note; CLAUDE.md ("How the run works").

### 9.8 Tests

- **Counting:** each new kind and filter in a small fight; tallies come back on the result; a fight with tallies is the same fight as without (log equality).
- **`KitMod.times`:** each part scaled n times; 0 steps changes nothing; a mod outside the limits is refused at load.
- **The run:** a growing card's count rises fight by fight, its steps reach the next fight's kit, a relic's team count adds every hero's, a quest stops at one step, counting starts when the card is taken, and the counts survive a save and a load.
- **The UI:** the "Grows" and "Now" lines; the after-fight list.
- **Unchanged:** the bench's fingerprints; the sim runner's gate (no fight changes until a card grows).

### 9.9 Decisions (the playtester, 2026-10-01: "approve, build it")

14. **Step 4 is built as this section says.**
15. **A growing card counts from when it's taken** (Question G): it starts at +0% and grows from there; only owned cards are counted.
16. **The twelve growing upgrades come now** (Question H): Notched Bow, Weathered, Lamp Oil, and the nine paths' growing upgrades join `upgrades.json`; step 7 keeps them in its pools. Growing relics come with step 5.

### 9.10 Built in step 4 (2026-10-01)

- **The sim:** `DeedDef` gained `applied` (with `keywords`), `taken`, `ms_below`, `kills`, and the `from_basic` filter; `UnitSetup.tally_keys` and `tally_counts` (from `HeroExtras`) are counted by `Deeds` after the deeds (`_count_on_target` for taken and kills, `count_time` for time below an HP share), and come back as `FightResult.tallies` (`tally_amount`). Counting never changes a fight.
- **The cards:** `GrowthDef` (`src/sim/defs/growth_def.gd`) on `UpgradeDef` and `RelicDef` (`"grows"`; an upgrade may grow with no `"mod"`). `KitMod.times(n)` and `step_problem()` (a step may only change stats, an ability's `amount_bp`, or add auras); `stats_add` now also takes HP, ATK, MGK, and DEF (Old Scars' +1 DEF, Brandmarks' +1 ATK). No item grows (none in the agreed pools does), so `item_def.gd` is unchanged.
- **The run:** `RunState.Hero.growth`, `RunState.growth` (relics), and `RunState.grew`; `RunContent.held_upgrades`, `growth_tallies`, and growth folded into `upgrade_mods` and `relic_mods` (so `fight_setup`, `kit_of`, and the content checks all see it); `RunFlow._grow` after every fight (won or lost, a Hunt too), and a card starts at 0 when taken (Decision 15). RunContent checks a step 50 times over on every kit the card can meet, and that a growing card's `from_ability` names its hero's abilities.
- **The UI:** "Grows: +1% ATK per 3 enemies Marked" on cards, "Now: +7% ATK (2 / 3 enemies Marked to the next)" in the hero panel and the relic tooltip, and "What grew" on the day screen after a fight.
- **The twelve upgrades** (`data/upgrades.json`), each tuned with the run report to about one step a fight held: Notched Bow (3 Marks), Weathered (600 taken), Lamp Oil (200 healing), Hunter's Tally (300 damage from beyond 4 hexes), Patient Hunter (15s of Root), Arrow Glut (15 extra hits; +1% faster cooldowns, since Maren's ATSP of 10 is too small for a share of it to show), Old Scars (100 guarded), Brandmarks (15 extra hits by the mace), Borrowed Time (8s below 30% HP), Kindled Flame (300 healing beside the target), Woven Deep (200 Shield), Sunwrought (50 smite damage). Path kits count far more once transformed than while vowed, so the deeds' thresholds were no guide.
- **Tests:** `tests/sim/test_tallies.gd` (8), `tests/run/test_growth_cards.gd` (9), a "What grew" test in `test_run_screens.gd`, and `test_growth.gd`'s pool counts and offers (each hero and path has one growing upgrade more).
- **What moved:** no fight (tallies only count). **The run report fell from 83% to 72% of runs won** with the growing upgrades in the pools, and back to 83% with them taken out, at either tuning: the simple bot takes a pick's card blind, and a growing card at about a step a fight gives +4–5% by the boss where the stat card it displaced gives +8–10% at once. Growing cards are an engine for a run that takes them early and builds on them; whether Act 1's are too slow (or the bot too blind to pick them) is flagged for the playtester. Step 7 rebuilds the pools and step 9 retunes.

## 10. Step 5: the relic pool

`relics/` (86 relics in five tiers, with the rules every relic follows), the three bond relics (`duo-bonds.md`), and `economy.md`. **Approved 2026-10-01** (10.7): the split below, and step 5a in full.

### 10.1 Why it's split

Of the 86, about 40 can be written with what's built (kit mods, keywords and triggers, growth) plus small run rules. The rest need new sim pieces, and a dozen of those (the chains, Second Dawn, the engines) are each a piece of their own. One approval for all of it would be too big to check, so step 5 comes in four parts, each approved before it's built:

| Part | What | Relics |
| --- | --- | --- |
| **5a** (below, in full) | The tiers, the shop's relic with climbing rerolls, the pre-boss shop, where relics come from, the economy, the built relics changed or cut, and every relic the built pieces can write | 40 |
| **5b** | The pieces many relics share: lifesteal from every source, crit damage bonuses, timed boosts ("+30% attack speed for 3s"), the team's effects at a fight's start, lengthening a status, Shields of a share of max HP, taking less damage near an ally, and a few counters (overkill) | about 20 (Bramble Seed, Ember Bauble, Tithe of Iron, Smoke Pouch, Leech Tooth, Red Thirst, Moth-Eaten Banner, Salt Circle, Executioner's Mark, Hunter's Ledger, Pyre Ash, Grasping Mire, Shattered Aegis, Veil of the Lost, Keen Edge, Glutton's Chalice, Thicket Engine, Stormcaller's Bell, Overkill Tithe, Reliquary) |
| **5c** | The engines and chains, each its own piece: Crown of Stars, Shared Pain, The Hungering Rift, Overcharge, Second Dawn, Quickening, Stonebound, Hunter's, Warden's, Shadow, and Ashen Engines, Overflow Chalice, Blood Communion, Sanguine Frenzy, Knife's Edge | about 15 |
| **5d** | Duo bonds become keys to bond relics (the built boosts go), with the three bond relics and their shop odds | 3 |

**Boss relics** (11) come with the parts that build their pieces (Decision 18): 5a builds the choice of 3 after Old Mother Ash and the four the built pieces can write; the rest join in 5b and 5c.

### 10.2 What's there now (phase 5)

- **Relics:** eight, one tier, each with a boon and a cost (`RelicDef`: `mod`, `enemy_mod`, `rest_mod`, and run rules). Sources: an elite's win and a Rift Tear's (a choice of 2), the Shrine (a choice of 2), and one relic in the Pedlar's and the Magpie's shops (`shop_relic`, 9 shards; the Magpie's at 150%).
- **The economy** (`act1.json`): start 3; a win pays 3, harder 5, elite 6, boss 0, a Hunt 2; a wound costs 2, a reroll 1 (it rerolls the wares), a relic 9; items 2–5 by kind.
- **The day** is still phase 5's (camp, the route, the loadout, the fight, after it); the new day (fight, pick, shop, node) is step 8, so 5a's shops are the camp's Pedlar and Magpie.

### 10.3 Step 5a: tiers, shops, and the economy

- **`RelicDef`** gains `"tier"` (common, rare, epic, legendary; boss and bond later) and loses `"cost"` (no downsides); `"boon"` becomes `"text"`. `rest_mod` goes (only Pilgrim's Lantern used it).
- **The shop's relic:** each shop shows **1 relic** (2 with The Magpie's Scale). The Pedlar's is common 70%, rare 25%, epic 5% (placeholders). **A reroll replaces the relic and the wares** (Decision 19): the first costs 1 shard, each after it 1 more in that shop (Tinker's Purse: the first is free; Merchant's Covenant: the price never climbs). The Magpie's relic is epic or legendary, 25% off, no reroll (his node, selling, and swapping are step 6).
- **The pre-boss shop:** the boss day's camp always has the Pedlar, and its relics are **1 legendary plus 1 relic of another tier**, rerolls starting at 5.
- **Where else relics come from** (until step 8's nodes): an elite's win, a choice of 2 rares (1 in 3 chance that one is an epic); a Rift Tear's win, 2 rares; the Shrine, one rare for 15 shards (its other offerings are step 8's).
- **Prices** (`economy.md`): common 5, rare 12, epic 20, legendary 30; the Magpie's epic 15, legendary 22.
- **The economy** (`economy.md`): start 10; a win pays 10, the harder fight 13, an elite 15, the boss 25; a Hunt 5 (not set there; a placeholder); a wound costs 4; items by kind: tactics 4, charms 6, sigils 8, grafts 8 (until step 6 cuts them); taking shards instead of a pick pays 5 (scaled with the rest).
- **Run rules** the 5a relics need (`RelicDef`, read by `RunFlow`): `wound_price_add`, `free_reroll`, `flat_rerolls`, `elite_pay_add`, `shop_shards` (paid as a shop opens), `miser` (1 per 5 held, up to 6, as a shop opens), `shop_relics_add` and `wares_add`, `pick_cards_add`, a streak quest (`streak`: win 3 fights in a row with no hero falling, for 25 shards, once), and growth that pays shards instead of a mod (`"each_shards"`: Bloodied Coin, Lucky Strike). Two relics are worked out at setup from the run: Reliquary Lamp (+2% to HP, ATK, MGK, DEF, CRIT, and attack speed per relic held) and Gilded Rift (+1% ATK and MGK per 5 shards held).
- **Small sim and mod pieces:** `KitMod` `mana.regen_add` (Rift Candle) and `mana.max_bp` (Hollow Drum); `stats_add` takes ATSP (each point is 1% faster, so "+8% attack speed" is +8 ATSP; Arrow Glut moves to +1 ATSP a step); a `crits` tally kind (Lucky Strike); a growth counted by the run rather than the sim (`"run_counts": "elite_wins"`, Tally of the Dead); and a status, **Sunder** (no damage, never fades, each stack 1 DEF off; the `bleed` kind's shred with no damage), for the epic.
- **The built relics:** Ember Heart (rare: basic attacks apply 1 Burn), Hollow Crown (legendary: a 4th slot), Rift-Glass Eye (rare: Scouted), Bloodstone (common: +8% ATK), Warden's Chain (common: +10% DEF), and Gravedigger's Coin (common: +3 shards a win) lose their costs; Pilgrim's Lantern and Hungry Blade are cut.

- **After the boss** (Decision 18): a won fight against Old Mother Ash offers 3 boss relics (free, take one or none) before the run's end; the one taken is the run's, shown at its end. Act 1's run still ends there; the relic is for the acts to come. The 5a boss relics: **The Second Sun** (signatures fire twice: an echo at full strength 0.5s later, the built Echo piece), **Rift-Bound Heart** (growing cards count double while it's held), **The Hollow Throne** (take 2 cards from every pick), **The Hollow Covenant** (each hero uses the team's highest HP, ATK, MGK, DEF, CRIT, and attack speed, worked out at setup).

The 5a relics (44):

| Tier | Relics |
| --- | --- |
| **Common** (17) | Whetstone of the Fallen, Bloodstone, Iron Filings, Warden's Chain, Hearthstone Shard, Quickened Pulse, Bone Dice, Rift Candle, Brand of Guilt, Headsman's Coin, Rusted Fetter, Hollow Drum, Gravedigger's Coin, Mender's Purse, Tinker's Purse, Bounty Hunter's Tag, Loose Change |
| **Rare** (13) | Ember Heart, Ashen Censer, Thornwoven Cloak, Echoing Bell, Collector's Chain, Tally of the Dead, Chalk Ledger (a quest: growth with one step), Bounty Board, Bloodied Coin, The Magpie's Scale, Rift-Glass Eye, Haggler's Charm, Lucky Strike |
| **Epic** (5) | Mirror of Ash, The Ninth Arrow, Sunder, Miser's Vault, Merchant's Covenant |
| **Legendary** (5) | Rift-Fed Blades, Reliquary Lamp, Gilded Rift, Hollow Crown, Widened Offering |
| **Boss** (4) | The Second Sun, Rift-Bound Heart, The Hollow Throne, The Hollow Covenant |

With 13 rares, 5 epics, and 5 legendaries, the tiers are thin until 5b and 5c; the pre-boss shop's legendary comes from 5.

### 10.4 The UI

- A relic's card and tooltip show its tier (a word and the tier's color; the frames per tier are the UI redesign's), its text, and its numbers line (`ModInfo`, step 2), with growth's "Grows"/"Now" (step 4).
- The shop's relic slot (one or two) with **Reroll (N shards)** beside it; the pre-boss shop says so; the Magpie's says "One look".
- Run rules show in the numbers line ("+2 shards at every shop", "the first reroll in every shop is free").

### 10.5 Files

- Changed: `relic_def.gd`, `relics.json` (the 40), `act1.json` (the economy, tier odds, prices), `act_def.gd`, `run_state.gd` (shop relics as a list, rerolls this shop, the streak), `run_flow.gd`, `offers.gd` (draws by tier), `run_content.gd`, `kit_mod.gd`, `deed_def.gd`/`deeds.gd` (`crits`), `growth_def.gd` (`run_counts`, `each_shards`), `data/statuses.json` (Sunder), `data/upgrades.json` (Arrow Glut), `mod_info.gd`, `run_day_screen.gd` (shop and relic cards), `tools/run_bot.gd` (buys the shop's relic when it can, never rerolls), `tools/run_report.gd` (relics by tier).
- Docs: this section's "Built in step 5a" note; `relics/README.md` (what's built); CLAUDE.md.

### 10.6 Tests

- Every 5a relic's effect, in a small fight or on run state (one test per relic or per kind of relic).
- The shop's draw by tier (seeded), rerolls' climbing price, Tinker's Purse and Merchant's Covenant, the pre-boss shop's legendary and rerolls from 5, the Magpie's tier and discount, the elite's and Rift Tear's choices.
- The economy's numbers; each run rule; the streak quest; growth that pays shards.
- Saves keep the shop's relics and rerolls; the run report runs (runs won will move: the economy changes, and relics lose their costs).

### 10.7 Decisions (the playtester, 2026-10-01)

17. **Step 5 is split into 5a, 5b, 5c, and 5d** (Question K), each approved before it's built; 5a is built as this section says.
18. **Boss relics come now** (Question I: "build the choice now"): 1 of 3 after Old Mother Ash, from the boss relics the built pieces can write (four in 5a); the rest join with their pieces.
19. **A shop reroll replaces the relic and the wares together** (Question J).

### 10.8 Built in step 5a (2026-10-01)

- **Relics:** `RelicDef` (tier, text, no cost; the run rules of 10.3), 44 in `data/relics.json` (17 common, 13 rare, 5 epic, 5 legendary, 4 boss), icons reusing the placeholder glyphs. Pilgrim's Lantern and Hungry Blade are cut; `rest_mod`, `wound_bp_add`, and the old `pick_cards` cap are gone with them.
- **Shops and sources:** `Offers.shop_relics` and `Offers.relics` draw by tier (a tier with nothing left falls to the nearest one that has some); `RunState.shop_relics` (a list), `reroll_price()` (climbing; Tinker's Purse, Merchant's Covenant), a reroll replaces the relic and the wares, `pre_boss_shop()` (the boss day's camp always offers the Pedlar), the Magpie's relic at 75% of its tier's price, the Shrine's rare for 15 (`relic_choice_price`), an elite's 2 rares with a 1-in-3 epic, and 3 boss relics after Old Mother Ash (the run ends at `finish_day`).
- **The economy** (`act1.json`): start 10; a win 10, harder 13, elite 15, boss 25, a Hunt 5; a wound 4; items by kind (tactics 4, charms 6, sigils 8, grafts 8); pick shards 5.
- **Small pieces:** `KitMod` `mana.regen_add` and `mana.max_bp`, `stats_add` for ATSP (Arrow Glut now +1 ATSP a step); `DeedDef` `crits`; `GrowthDef` `each_shards` and `run_counts`; the Sunder status (and its chart family); The Hollow Covenant worked out in `RunFlow.fight_setup` from each placed hero's kit; Reliquary Lamp and Gilded Rift in `RunContent.relic_mods`.
- **A fix it needed:** a condition's statuses (UnitCondition) are checked apart from the statuses a kit applies (`UnitDef.condition_status_ids`), so Rusted Fetter's "vs Engaged" is allowed though only the Engage trait applies Engaged.
- **The UI:** relic cards and tooltips show the tier (a word in the tier's color), the text, and the numbers line, which now names every run rule; the shop shows its relics (one or two), "Reroll · N shards", the pre-boss shop's note, and the Magpie's "One look"; a priced relic choice says its price.
- **Tests:** `tests/run/test_relics.gd` (25: the tiers, every kind of 5a relic, the run rules, rerolls, the pre-boss shop, the elite's epic, saves, Rusted Fetter in a fight); `test_camp.gd`, `test_economy.gd`, `test_run_flow.gd` (the boss relic choice), `test_mod_info.gd`, and the status lists changed on purpose.
- **What moved:** no fight. **The run report** (54 runs): **66% of runs won** (72% after step 4); losses gather on day 3's elite (10 of 18), the bot buys few shop relics (it buys wares first and never rerolls: 0.2 commons and no legendaries a run; 1.7 rares, mostly from elites; 0.7 boss relics), and earns about 77 shards a run (the target before the pre-boss shop was 76–86). The bot's spending is simple on purpose (phase 6 is the good bot); the economy and the elites wait for step 9's retune.

## 11. Step 5b: the pieces relics share

The second part of the relic pool (Decision 17): twelve sim and run pieces that about twenty relics need, and those relics as data. **Approved and built 2026-10-01** (11.6, 11.7). The boss relics left (Chain of Echoes, Crown of the Hollow King, Everflame, The Unbending, Riftwalker's Soles, The Long Watch, Snaring Shot) each rewrite a rule of their own, so they go with 5c's engines and chains.

### 11.1 The pieces

| # | Piece | What it is | For |
| --- | --- | --- | --- |
| 1 | **Relic effects at a fight's start** | `RelicDef "at_start": [effects]`, run by the sim at tick 0, sourced to the relic (`EffectSource.relic`, already in the log's rules); a new target, `nearest_enemies` with a `count` (nearest to any hero); `shield` takes `amount_bp_of_max_hp` (as `heal` does) | Bramble Seed, Ember Bauble, Tithe of Iron, Smoke Pouch |
| 2 | **Lifesteal from every source** | an aura stat, `lifesteal_bp` (adds): the holder heals that share of the damage its hits deal (`deal_hit`), its own kind of line in the log (`LIFESTEAL`, not HEAL: relics/README rule 5, so healing triggers and bonuses ignore it); `"vs"` allowed on it | Leech Tooth, Glutton's Chalice, Red Thirst |
| 3 | **Crit bonuses** | an aura stat, `crit_damage_bp` (adds to the crit kind of the damage rule), and `"vs"` allowed on `crit_chance_bp` (rolled against the target as the attack fires) | Keen Edge, Executioner's Mark |
| 4 | **Timed boosts** | a status kind, `boost`: timed, carrying aura changes (`"auras": [{stat, value}]`) that count while it lasts (folded in like auras); a new aura stat, `atsp` (adds ATSP points, so "+30% attack speed" is +30) | Veil of the Lost, Stormcaller's Bell |
| 5 | **A status ending** | a new event, `on_status_ended` (the unit whose status ran out; `statuses` and `keywords` filters), from the STATUS_ENDED entries already logged | Veil of the Lost ("leaving Stealth") |
| 6 | **Lengthening some statuses** | a kit mod's ability change takes `"statuses"` (only apply_status effects of those) | Veil of the Lost (Stealth 1s longer) |
| 7 | **Extending a status** | a new effect, `extend_status` (`status`, `duration_ms`): a timed status already on the target lasts that much longer; nothing if it isn't there | Hunter's Ledger, Thicket Engine |
| 8 | **Around the unit, or the one the event names** | targets `enemies_near_self` and `enemies_near_named` / `enemy_near_named` (`within_hexes`), and `apply_status`'s `"stacks_of": "burn"` (as many stacks as the unit the event names has, read as the effect runs) | Shattered Aegis, Pyre Ash, Grasping Mire |
| 9 | **Close to an ally** | an aura `"while": "ally_near", "within_hexes": 1`, and a stat `damage_reduced_bp` (takes less damage, like Warded; adds with it) | Moth-Eaten Banner |
| 10 | **Salt Circle** | a rule the setup carries (`FightSetup.hero_rules`): the first enemy area each fight lands on nothing, logged ("broken by Salt Circle") | Salt Circle |
| 11 | **Overkill** | DAMAGE entries record the overkill (damage past the target's last HP); a tally kind, `overkill` | Overkill Tithe (1 shard per 150) |
| 12 | **Reliquary** | common relics count twice: their mods `times(2)` where a step could scale them (stats, amounts, auras), their numbers in run rules doubled; a common with an ability passive (Brand of Guilt) is unchanged | Reliquary |

### 11.2 The relics (20)

| Tier | Relics |
| --- | --- |
| **Common** (8) | Bramble Seed, Ember Bauble, Tithe of Iron, Smoke Pouch, Leech Tooth, Red Thirst, Moth-Eaten Banner, Salt Circle |
| **Rare** (8) | Executioner's Mark, Hunter's Ledger, Pyre Ash, Grasping Mire, Shattered Aegis, Veil of the Lost, Keen Edge, Glutton's Chalice |
| **Epic** (3) | Thicket Engine, Stormcaller's Bell, Overkill Tithe |
| **Legendary** (1) | Reliquary |

With these, commons are complete (25 of 25), rares 21 of 21, epics 8 of 14, legendaries 6 of 15.

### 11.3 The log and the board

- New log kinds: `LIFESTEAL` (source: the unit and what dealt the hit) and, for Salt Circle, an AREA_LANDED entry's note. Each new kind gets its audit rule (`test_arena_log.gd`) and its board form (`test_every_encounter_plays.gd`: a heal number in the lifesteal colour).
- Relic effects at the start show as the relic's name on the board's lines, like any relic source.

### 11.4 Files

- New: `tests/sim/test_relic_pieces.gd`.
- Changed: `relic_def.gd` (`at_start`), `combat_sim.gd` (running them; `hero_rules`), `effect_def.gd` (the targets, `extend_status`, `stacks_of`, `on_status_ended`, shield's share of max HP), `effect_runner.gd`, `targeting.gd`, `aura_def.gd` and `passives.gd` (the stats, `ally_near`, `vs` on more stats), `status_def.gd` and `statuses.gd` (`boost`), `events.gd`, `kit_mod.gd` (`statuses` on a change), `areas.gd` (Salt Circle), `deed_def.gd`/`deeds.gd` (`overkill`), `log_entry.gd`, `run_content.gd` and `run_flow.gd` (Reliquary, passing relic effects and rules into the setup), `data/relics.json`, `data/statuses.json` (the two boosts), `unit_info.gd`/`mod_info.gd` (the words), `fight_fx.gd` (lifesteal), the chaos fight.

### 11.5 Tests

- Each piece in a small fight (`test_relic_pieces.gd`): start effects with their source, nearest enemies, lifesteal (and that it isn't healing), crit damage and a sure crit, a boost's stats while it lasts, `on_status_ended`, a status lengthened by a mod and by `extend_status`, the near targets and `stacks_of`, `ally_near`, Salt Circle once, overkill.
- Each 5b relic's effect (`test_relics.gd`), Reliquary's doubling.
- Determinism, the log audit, every encounter on the screen, the chaos fight using the new pieces; the bench fingerprints unchanged (no built kit uses them).

### 11.6 Decisions (the playtester, 2026-10-01)

20. **Step 5b is built as this section says.**
21. **Lifesteal has its own log line** (`LIFESTEAL`) and board colour; healing triggers, heal power, and healing taken ignore it (until Blood Communion, 5c).

### 11.7 Built in step 5b (2026-10-01)

- **The pieces, as 11.1 says**, with these details:
  - Start effects are `RelicDef.at_start` (no trigger; apply_status, shield, heal, or damage at all_allies, all_enemies, or nearest_enemies), passed to the sim as `FightSetup.relic_effects` with their sources and scales and run in `CombatSim._init` once the units have joined. The log audit names a relic's entry by its relic.
  - Salt Circle is a count, `FightSetup.salt_circles`, rather than 11.1's `hero_rules`. Reliquary makes it 2.
  - Lifesteal heals the attacker after the hit lands (never past full HP), logged as `LIFESTEAL` with the hit's source; a pink number on the board.
  - Boosts fold into `aura_bp` in `Passives.rederive`, and applying or ending one refolds.
  - `on_status_ended` comes from the STATUS_ENDED entries, so it hears statuses a relic put there too.
  - `extend_status` logs `STATUS_EXTENDED`; the board's tag simply lasts longer.
  - `enemy_near_named` with no reach is the nearest enemy at any distance.
  - DAMAGE entries carry `overkill` (past the target's last HP, after Shield), and `DeedDef` counts `overkill`.
- **Reliquary:** `RunContent.counts_twice` (a common, while Reliquary is held). Its mod is `times(2)` when it has no `step_problem`: stats, auras, and amounts double; Brand of Guilt's ability, Rift Candle's mana, and Hollow Drum's mana are unchanged. Its run rules (`relic_sum`) and its start effects (scale 20000) double too.
- **Relics:** 20 more in `data/relics.json` (64: 25 common, 21 rare, 8 epic, 6 legendary, 4 boss), and two boost statuses (`veiled_haste`, `storm_call`). Some notes on how they read:
  - Shattered Aegis deals the Shield the breaking blow took (`on_shield_broken`'s amount), not the Shield's full first value.
  - Veil of the Lost lengthens the Stealth a hero's own abilities give (Maren's hop, Sidestep), not Smoke Pouch's. Maren's Slip Away and Sidestep now name their 1s, since a kit mod only changes durations an effect gives (the same 1s; no fight changed).
  - Stormcaller's Bell is on every hero (`on_ability`, which is the hero's signature).
- **The UI:** card and kit lines for every new piece ("As a fight starts: Root 1.5s to the 2 enemies nearest the heroes", "−8% damage taken while an ally is within 1 hex", "+2% lifesteal against enemies that are below 50% HP", "Every time its Stealth runs out · Veiled Haste 3s"), Reliquary's line, the boost's status tag ("UP"), and the log's lines for both new kinds.
- **Tests:**
  - `tests/sim/test_relic_pieces.gd` (17: each piece in a small fight).
  - `test_relics.gd` (8 more: start effects and Salt Circle in the run's setup, Ember Bauble and Smoke Pouch, Reliquary, lifesteal, crit relics, Hunter's Ledger and Thicket Engine, Veil of the Lost on Maren, Overkill Tithe).
  - The chaos fight uses the new pieces (a relic's start Shield, Salt Circle, lifesteal, a boost on leaving Stealth, an extended Mark, crit damage, Burn spreading from the fallen, an ally-near aura, a signature's boost to all). Its seed moved from 23 to 26, the first that still has every piece.
  - The log audit and the board's forms cover `LIFESTEAL` and `STATUS_EXTENDED`.
  - `test_unit_info`, `test_camp`, and `test_content_db` changed on purpose.
- **What moved:** no built kit's fight; the bench's fingerprints are unchanged. **The run report** (54 runs): **66% of runs won**, as after 5a. Losses still gather on day 3's elite (10 of 18), and there are 2.9 relics a run (0.2 common, 1.7 rare, 0.3 epic, 0.7 boss), since the simple bot still buys wares first.

## 12. Step 5c: the engines, the chains, and the rules boss relics rewrite

The third part of the relic pool (Decision 17): the 22 relics left that aren't bond relics, each its own piece. After 5c the epic, legendary, and boss tiers are complete (14, 15, 11). **Approved and built 2026-10-01** (12.8, 12.9, 12.10).

Two kinds of piece:

- **Small pieces in kit mods.** These relics are passives on every hero, like 5b's, and need a new stat, filter, or status kind.
- **Hero rules** (new: `SideRules`, `src/sim/defs/side_rules.gd`). These relics rewrite a rule of the fight for the heroes' side: how crits roll, how damage carries, how mana and chains work, falling, statuses, the collapse, the time-out. A relic names its rules (`RelicDef "rules": {...}`, each with its numbers in the data). `RunContent` merges the run's rules into `FightSetup.hero_rules`, and the sim reads them where the rule lives. Each rule is code, the way a new effect type is (CLAUDE.md rule 3): it's said here, and its numbers are data. A fight without the rules never reaches that code, so no built kit's fight changes.

### 12.1 The engines (kit mods and their small pieces)

| Relic | Tier | What it is in the sim | New piece |
| --- | --- | --- | --- |
| **Ashen Engine** | epic | +20% ATK and MGK; a passive: on a hit on a Burning enemy, apply `burn` to the enemy nearest it (`enemy_near_named`) with `"stacks_of": "burn", "stacks_share_bp": 500` (5% of its stacks, at least 1) | `stacks_share_bp` |
| **Overflow Chalice** | epic | an aura `overheal_shield_bp` 5000: half of what its heals would restore past full HP comes back as Shield, added to the heal's own (Ward Thread's), no cap; lifesteal isn't a heal, so it doesn't count (unless Blood Communion) | aura stat `overheal_shield_bp` |
| **Blood Communion** | epic | an aura `lifesteal_heals`: its lifesteal is a heal (a HEAL line noted "lifesteal": heal power, healing taken, `on_heal`, and Overflow Chalice all see it); +10% `heal_bp` and +10% `healing_taken_bp` | aura stat `lifesteal_heals` |
| **Sanguine Frenzy** | epic | a passive: on its lifesteal, apply `frenzy` to itself (+2 ATSP a stack, each stack its own 3s) | event `on_lifesteal`; **stacking boosts** (a boost with `"stacking": true`: each application adds a stack with its own timer, or none if it has no duration; its auras count per stack) |
| **Knife's Edge** | epic | an aura `crit_overflow_bp` 20000: on a crit, its crit chance past 100% (CRIT and crit-chance auras, not an ability's own or a `vs`) adds twice over to crit damage | aura stat `crit_overflow_bp` |
| **Stonebound** | epic | three auras `"while": "planted", "after_ms": 2000` (+15% ATK, +15% MGK, +15 DEF), each with `"step": {"every_ms": 2000, "value": ...}` (+5%, +5%, +5 more every 2s still); moving resets them, as planted auras do now | a planted aura's `step`; aura stat `def` (DEF points) |
| **Warden's Engine** | legendary | +30% `shield_bp`; auras `atk_bp` and `mgk_bp` `"per_shield_bp": 5` (+0.05% per point of the holder's Shield: 400 Shield is +20%), checked every tick | an aura's `per_shield_bp` |
| **Hunter's Engine** | legendary | the rule `marks_stack` (see 12.2); an aura `crit_damage_bp` 2000 `"per_target_stacks": "marked"` (per stack on the unit hit); a passive: a crit on a Marked enemy Marks every enemy within 1 hex (`enemies_near_named`, built) | an aura's `per_target_stacks` |
| **Shadow Engine** | legendary | while Stealthed: auras `damage_bp` 20000 and `lifesteal_bp` 500 `"from_basic": true` (only on its basic attack's hits), and `overheal_strike_bp` 50000 (what its lifesteal would heal past full HP hits its target for 500%, a DAMAGE line noted "Shadow Engine") | an aura's `from_basic`; aura stat `overheal_strike_bp` |
| **Quickening** | legendary | a passive: on each of its hits, apply `quickened` to itself (+1 ATSP a stack, stacking, no duration: the rest of the fight) | stacking boosts (above) |
| **Snaring Shot** | boss | a mod only for ranged heroes (`RelicDef "mod_for": "ranged"`: range 2 or more, checked at setup): every 3rd basic attack Roots its target for 1s with `"fresh_only": true` (nothing if it's already Rooted, so never stacked or extended) | `mod_for`; apply_status's `fresh_only` |

Two notes on reading them:

- **Rule 7** (two relics can use the same thing) holds: the same overheal feeds Overflow Chalice and Shadow Engine in full.
- **Shadow Engine's "basic attacks deal +100% damage"** is scoped to one kind of attack, so it's damage (rule 3), as power.

### 12.2 The hero rules

| Rule | Relic (tier) | What the sim does |
| --- | --- | --- |
| `crit_chain` `{"steps": 10, "fade_bp": 500}` | **Crown of Stars** (legendary) | A crit rolls again, as the hit lands (`deal_hit`, on the sim's RNG). The k-th extra roll's chance is the crit chance × (100% − 5%·k), and each extra crit adds the crit bonus × (100% − 5%·k) to the crit kind. CRIT past 100% keeps the chain going longer. Up to 10 extra. The DAMAGE line carries the count ("crit ×3"; `LogEntry.crits`) |
| `echo_keywords` `{"share_bp": 9000, "steps": 3}` | **Shared Pain** (legendary) | Damage a hero's hit deals to an enemy with a keyword echoes to every other enemy with that keyword at 90%. Only one keyword is used: the one the most other enemies share (ties go to Keywords' order). Then each echo echoes the same way (81%, 73%), each enemy hit at most once a step, 3 steps deep. Echoes are DAMAGE lines from the hero, noted "Shared Pain", mitigated by each target's DEF, never crits, one chain step deeper each. They don't echo outside the rule's own steps |
| `carry_overkill` `{"steps": 8}` | **The Hungering Rift** (legendary) | A hero's hit's overkill hits the standing enemy nearest the fallen (a DAMAGE line noted "carried", mitigated), and its overkill carries on, up to 8 times |
| `overcharge` `{"power_bp": 2500, "steps": 8}` | **Overcharge** (legendary) | A hero's mana isn't capped at a full bar. When its signature fires on mana, the bar loses one full bar, not all. Each further full bar left fires it again at once (no cast), each fire +25% power more than the last, up to 8. So mana gained while the bar is held (casting, Stunned, Wait to heal) is stored |
| `second_dawn` `{"after_ms": 5000, "hp_bp": 5000}` | **Second Dawn** (legendary) | The first time each hero falls in a fight, it rises 5s later at 50% HP where it fell (or the nearest free safe spot), its statuses gone and its mana as it was, and its auras and passives back. It's logged as RISE (a new kind: the token returns with a pulse). Heroes all down at once is still a defeat, a rise waiting or not |
| `deeper_chains` `{"steps": 4, "grow_bp": 1500}` | **Chain of Echoes** (boss) | Every chain the heroes start goes 4 steps deeper: event chains (the chain limit, for hero-sourced entries: 8 → 12), Crown of Stars, Shared Pain, The Hungering Rift, and Overcharge. Each step is 15% stronger than the one before, instead of fading: Crown of Stars' and Shared Pain's steps grow ×1.15 instead of shrinking, a carry is ×1.15 of the overkill, Overcharge's fires +15% on top, and an event effect at depth d is ×1.15^d (the relic kind of the damage rule) |
| `keywords_twice` | **Crown of the Hollow King** (boss) | A keyword status a hero (or a hero's relic) applies goes on twice: double stacks, or double duration |
| `keywords_last` | **Everflame** (boss) | A keyword status a hero applies to an enemy never ends that fight: timed ones don't run out, Burn's stacks don't fade, and enemies' heals and cleanses don't remove them (`StatusState.lasting`). Stealth on heroes still ends |
| `unbending` `{"def_bp": 100, "max_hp_bp": 100}` | **The Unbending** (boss) | A status an enemy applies to a hero is blocked, and logged as RESISTED (a new kind: "Resisted" over the hero). Each block gives the hero a stack of `unbending` (a stacking boost with no duration: +1% DEF, +1% max HP). Max HP rises by the share and HP by as much, through a new aura stat `max_hp_bp`. Engaged isn't blocked: it's the Engage trait, not an applied status |
| `collapse` `{"immune": true, "enemy_max_hp_bp": 500}` | **Riftwalker's Soles** (boss) | Heroes take no damage from crumbled ground. Enemies on it take 5% of their max HP a second on top, on the same COLLAPSE line (noted "Riftwalker's Soles") |
| `long_watch` `{"from_ms": 60000, "every_ms": 10000, "tie_ms": 300000}` | **The Long Watch** (boss) | No 180s tie: the fight runs to 300s, then ends as a tie (Decision 25). At 60s and every 10s after, every standing hero gains a stack of `long_watch` (a stacking boost, no duration: +10% HP, ATK, MGK, DEF, CRIT, and attack speed), sourced to the relic |
| `marks_stack` | **Hunter's Engine** (legendary, with its mod) | Marked applied by a hero stacks instead of only refreshing: each application adds a stack and refreshes the timer (`StatusState.stacks` for a timed status). Marked's vulnerability stays one Mark's; the stacks count for Hunter's Engine's crit damage |

### 12.3 The log and the board

- **New log kinds:** RISE (source: the relic Second Dawn, target the hero; board: the token returns with a pulse) and RESISTED (source: the enemy and ability whose status was blocked, target the hero, the status named; board: "Resisted" over the hero). Each gets its audit rule and its form.
- **DAMAGE lines gain** `crits` (Crown of Stars) and notes for echoes, carries, and Shadow Engine's strike. Boosts with stacks show their count on the tag ("UP 3").

### 12.4 Building it

One approval, built and committed in two parts:

- **5c-1, the engines:** 12.1's eleven relics and their pieces, with `marks_stack`, the one rule Hunter's Engine needs.
- **5c-2, the rules:** 12.2's other eleven rules and relics.

The chaos fight takes the new pieces part by part (its seed rescanned if it must be). The bench gets no new fight, but its fingerprints must stay the same.

### 12.5 Files

- **New:**
  - `src/sim/defs/side_rules.gd`
  - `tests/sim/test_engine_pieces.gd` (5c-1)
  - `tests/sim/test_hero_rules.gd` (5c-2)
- **Changed:**
  - `relic_def.gd` (`rules`, `mod_for`)
  - `aura_def.gd` and `passives.gd` (the new stats, `step`, `per_shield_bp`, `per_target_stacks`, `from_basic`)
  - `status_def.gd`, `status_state.gd`, and `statuses.gd` (stacking boosts, `stacks` on a timed status, `lasting`, blocking)
  - `effect_def.gd` (`on_lifesteal`, `stacks_share_bp`, `fresh_only`)
  - `effect_runner.gd` (crit chains, echoes, carries, the lifesteal routes, Knife's Edge)
  - `signatures.gd` and `mana.gd` (Overcharge)
  - `combat_sim.gd` (rises, the time-out, the Long Watch's stacks, chain depth by side)
  - `collapse.gd`, `events.gd`, `log_entry.gd`, `fight_setup.gd`
  - `run_content.gd` and `run_flow.gd` (merging rules, `mod_for`)
  - `data/relics.json`, `data/statuses.json` (`frenzy`, `quickened`, `unbending`, `long_watch`)
  - `unit_info.gd` and `mod_info.gd` (the words: a relic's rules get a numbers line)
  - `fight_fx.gd` and `unit_token.gd` (RISE, RESISTED, stack counts)
  - the chaos fight

### 12.6 Tests

- **Each engine piece in a small fight** (`test_engine_pieces.gd`):
  - the share of Burn spread
  - overheal to Shield from an aura
  - lifesteal as healing
  - a stacking boost with its own timers, and one with none
  - Knife's Edge's overflow
  - Stonebound's steps and reset
  - Warden's per-Shield aura
  - Marks stacking and crit damage per stack
  - Shadow Engine's scoped auras and strike
  - Snaring Shot only on ranged heroes, never extending a Root
- **Each rule in a small fight** (`test_hero_rules.gd`), each also shown changing nothing without its rule:
  - a crit chain and its fade
  - Shared Pain's keyword choice and steps
  - a carry running out
  - Overcharge storing and refiring
  - a rise, and defeat with every hero down
  - Chain of Echoes on each chain
  - doubled and lasting keywords
  - a block and its stacks
  - the collapse both ways
  - the Long Watch's stacks
- **Each of the 22 relics' effects** (`test_relics.gd`). The tier counts become 25, 21, 14, 15, 11.
- **Fight-wide checks:**
  - determinism
  - the log audit
  - every encounter on the screen
  - the chaos fight
  - the bench fingerprints unchanged
  - the run report runs

### 12.7 Questions (answered in 12.8)

- **L. Second Dawn and wounds:** does a hero who rose get a wound for that fall?
- **M. Everflame's reach:** only keywords heroes put on enemies, or every keyword heroes apply as written?
- **Q. The Long Watch's limit:** a sim must end; when?

### 12.8 Decisions (the playtester, 2026-10-01)

22. **Step 5c is built as this section says**, in two parts (5c-1, the engines; 5c-2, the rules), each committed on its own.
23. **Wounds count only for heroes who are down at the end of the fight** (Question L). Without a rise that's every hero who fell, as now; a hero Second Dawn raised and who is standing at the end takes no wound.
24. **Everflame reaches only the keywords heroes put on enemies** (Question M): Stealth on heroes still ends.
25. **Under The Long Watch a fight ends as a tie at 300s** (Question Q), a guild win like the 180s tie.

### 12.9 Built in step 5c-1 (2026-10-01)

- **The pieces, as 12.1 says**, with these details:
  - Per-hit auras: `vs`, `from_basic`, and `per_target_stacks` are worked out per hit (`AuraDef.is_per_hit`), and `Passives.vs_bonus_bp` takes the hit's ability, for `from_basic`. `crit_damage_bp` joined the stats they may hold.
  - Conditional auras give their change through `Passives.aura_change`: per fallen ally, planted steps, or per point of Shield. `condition_key` became a running hash, so a planted step or a new Shield refolds them.
  - A stacking boost keeps each stack's last tick (`StatusState.stack_ends`) and counts per stack. A Mark under `marks_stack` keeps `StatusState.stacks`. `Statuses.stacks_on` reads either, and both tags show the count ("UP 3").
  - Lifesteal that heals goes through `EffectRunner.heal` (`by_lifesteal`; heal power from the attacker's `heal_bp`). `heal` now returns its overheal, which feeds Shadow Engine's strike. The strike is a DAMAGE line noted "overheal from lifesteal" that never lifesteals itself (`deal_hit`'s `steals`).
  - A lifesteal that rounds to nothing now does nothing at all (it had logged a heal of 0 under Blood Communion).
  - A heal's Shield from overheal adds the healer's `overheal_shield_bp` (`CombatSim.overheal_auras`).
  - `SideRules` (`src/sim/defs/side_rules.gd`) holds the heroes' rules, read from a relic's `"rules"` and merged by `RunContent.hero_rules` into `FightSetup.hero_rules`. 5c-1's one rule is `marks_stack`.
  - `RelicDef.mod_fits`: a `"mod_for": "ranged"` mod goes only to heroes whose path's kit has range 2 or more (`relic_mods(state, kit)`).
- **Relics:** 11 more (75: 25 common, 21 rare, 14 epic, 10 legendary, 5 boss). Two statuses join them: `frenzy` (stacking, 3s) and `quickened` (stacking, the whole fight).
- **The UI:** card lines for every piece ("+15% ATK after 2s still, +5% more every 2s after", "+0.05% ATK per point of Shield", "+20% crit damage per Marked stack on the enemy hit", "Ranged heroes: ...", "Marks heroes apply stack"), a boost's numbers wherever a card applies it ("Frenzy 3s (+2 ATSP a stack)"), and a lifesteal heal's "(lifesteal)" in the log.
- **Tests:**
  - `tests/sim/test_engine_pieces.gd` (14: each piece).
  - `test_relics.gd` (5 more: the engines on a kit, Knife's Edge and Quickening in a fight, Blood Communion with Sanguine Frenzy, Hunter's Engine's rule, Snaring Shot only on Maren and Vell).
  - The chaos fight takes four pieces: stacking Marks, Frenzy on lifesteal, an aura per Shield, and a stepping planted aura. Its seed moved from 26 to 37, the first that still has every piece.
- **What moved:** no built kit's fight; the bench's fingerprints are unchanged. **The run report** (54 runs): **66% of runs won**, as after 5b; losses still gather on day 3's elite (10 of 18), with 2.9 relics a run (0.2 common, 1.7 rare, 0.3 epic, 0.7 boss), since the simple bot still buys wares first and rarely meets an epic.

### 12.10 Built in step 5c-2 (2026-10-01)

- **The rules, as 12.2 says**, in `SideRules` (every rule with its numbers from the relic) and where each lives:
  - **Crown of Stars:** `EffectRunner._crit_chain`, as the hit lands. The extra rolls use CRIT, crit-chance auras, and per-hit crit chance (not an ability's own), and the DAMAGE line counts them ("crit x11").
  - **Shared Pain:** `_echo`. Echoes are DAMAGE lines noted "Shared Pain", one chain step deeper each, and `ruled` so they start no echo of their own.
  - **The Hungering Rift:** `_carry`, reading each carry's overkill through `CombatSim.last_overkill`.
  - **Overcharge:** `UnitState.mana_store`. `mana_cap` stays the full bar, so the UI and the trigger are unchanged.
    - `Signatures._spend_bar` takes one bar; `_overcharge` fires again with `UnitState.fire_power_bp` (added in `Passives.power_bp`).
    - Each extra FIRE is noted "Overcharge N".
  - **Second Dawn:** `CombatSim._fall` sets `rise_at`, and `_rise_due` stands the hero again at the nearest free safe spot to where it fell (RISE, sourced to the relic). It's for the heroes of the setup, not their summons.
  - **Chain of Echoes:**
    - `CombatSim.chain_limit_of` deepens the heroes' event chains, read by `Events.dispatch` and `Events.kill`.
    - A hero's event effect at depth d carries `growth_bp(d)` in the relic kind (`UnitState.relic_bonus_bp`, set in `Passives._run` for damage, heals, and Shields that land at once). An event effect's shot or area that lands later doesn't carry it.
    - Crown of Stars, Shared Pain, The Hungering Rift, and Overcharge go 4 steps deeper and grow ×1.15 a step (`SideRules.growth_bp`).
  - **Crown of the Hollow King and Everflame:** in `Statuses.apply`, for keywords a hero (or its relic) applies.
    - Doubled: stacks, a timed status's duration, and stacking Marks get 2 a time.
    - Everflame (`StatusState.lasting`) applies on enemies only (Decision 24). A lasting status never ends, its Burn never fades, it can't be extended further, and the enemies' heals and cleanses skip it.
  - **The Unbending:** any status an enemy applies to a hero is blocked (RESISTED, sourced to the enemy's ability and noted "The Unbending"), and gives a stack of `unbending` (+1% DEF, +1% max HP). The new aura stat `max_hp_bp` raises max HP from `UnitState.base_max_hp`, and HP by as much.
  - **Riftwalker's Soles:** `Collapse._damage` skips heroes and adds 5% of an enemy's max HP to its COLLAPSE line (noted).
  - **The Long Watch:** `CombatSim._check_end` ties at 300s instead of 180s (Decision 25), and `_keep_watch` gives every standing hero a `long_watch` stack (+10% max HP, ATK, MGK, DEF, CRIT, and attack speed) at 60s and every 10s after.
- **Wounds** (Decision 23): `FightResult.down_at_end()` (a DEATH not followed by a RISE) decides them in `RunFlow.record`. Bounty Board's streak still breaks on any fall.
- **Relics:** 11 more, 86 in all (25 common, 21 rare, 14 epic, 15 legendary, 11 boss): every relic but the bond relics. There are two new stacking statuses, `unbending` and `long_watch`.
- **The UI:**
  - A rule relic's card says its rule with its numbers, the boosts' read from the statuses ("statuses enemies apply to heroes are blocked; each gives that hero +1% DEF, +1% max HP for the fight").
  - RISE shows as a pulse and "Rises" over the hero (whose token returns); RESISTED shows as "Resisted".
  - The mana bar stops drawing at full under Overcharge.
- **Tests:**
  - `tests/sim/test_hero_rules.gd` (14: each rule, and each without it).
  - The **rules fight**: the three heroes at 20% max HP against Old Mother Ash with every rule on, seed 6, where a hero falls and rises and The Unbending blocks. It repeats exactly (`test_determinism`), replays (`test_arena_log`), and passes the log audit. RISE and RESISTED are left to it, out of the chaos fight.
  - `test_relics.gd` (2 more: the rule relics in the setup and on cards, and no wound for a hero who rose).
  - The tier counts are now 25, 21, 14, 15, 11.
- **What moved:** no built kit's fight; the bench's fingerprints are unchanged. **The run report** (54 runs): **66% of runs won**, as after 5c-1; losses still gather on day 3's elite (10 of 18), and no run errs. The simple bot rarely meets the legendaries and boss relics the rules come on (the pre-boss shop's legendary is the only sure one), so the rules barely show in its runs; the good bot and the retune are phase 6 and step 9.


## 13. Step 5d: duo bonds as keys to bond relics

The last part of the relic pool (Decision 17), from `duo-bonds.md`: a duo bond has no boost of its own any more; it's the key to a **bond relic**, which joins the shops once the bond is on. **Approved and built 2026-10-01** (13.6, 13.7).

### 13.1 The bonds

- **`BondDef`** keeps its two paths, name, and line, and loses its per-path mods. It names its relic (`"relic": "the_watchtower_stone"`).
- **Switching on is as built:** both heroes transformed into the bonded paths. So are the "?" on the vow while it stirs, being found (`RunState.bonds_found`), and the reveal.
- **The built boosts go:** fights no longer take a bond's mods (`RunFlow.fight_setup`, `kit_of`).
- **The hero panel's bond line** becomes "Sentry and Sniper is on: The Watchtower Stone can show up in shops" (or "is yours", once held). The stirring line stays.
- **The Codex isn't built yet**, so a found bond goes in it when it is.

### 13.2 The bond relics in the shops

- **A new tier, `bond`:** free, never drawn by the tier odds, never at the Magpie, and never in an elite's, Rift Tear's, or the Shrine's choice.
- **The draw:** each time a shop draws its relic slot (the Pedlar's, and the pre-boss shop's slot beside the legendary), and a bond is on whose relic the run doesn't hold or the shop isn't already showing, there's a `bond_relic_pct` chance the slot is that bond relic.
  - 20: four times the Pedlar's epic odds (Decision 27), a placeholder.
  - With two bonds on, both relics join the draw, one of them per slot (Decision 28).
  - A reroll draws again, so it can come and go.
- **Taking it costs nothing**; it takes the relic's spot like any relic.

### 13.3 The three bond relics

| Bond | Bond relic | In the sim |
| --- | --- | --- |
| **Sentry and Sniper** (Hearthwall + Deadeye) | **The Watchtower Stone:** allies standing behind a wall gain +1 range | an aura `"while": "behind_wall"`, `range` +1. It holds while one of its side's walls stands with the holder behind it: on its raiser's side of the wall's line, between its ends (half a hex either way), and within 3 hexes of it. Each `Walls.Wall` keeps which side is behind |
| **Snare and Cleave** (Ironbrand + Trapper) | **The Hunter's Anvil:** enemies that are knocked back are Rooted for 1s when they land | a new trigger, `on_knockback` (the unit knocked an enemy back, from its PUSH lines noted "knocked back"; it names the enemy): apply `root` 1s to it |
| **Light and Iron** (Hearthwall + Wardweaver) | **The Hearth-Woven Mail:** when an ally takes a hit for another ally, the protected ally gains a Shield of 5% of their max HP (once every 2s per ally) | a new trigger, `on_guard` (the unit's Guard took a share of a hit on an ally, from its GUARD lines; it names the ally): a Shield of 5% of max HP (built) to it, with a new event effect field `"cooldown_per_unit_ms": 2000` (once per that long for each unit named) |

Each is a passive on every hero (a relic's mod). Each plays off both paths: Hearthwall raises the walls and the Guard, Ironbrand knocks back, Trapper roots, Deadeye shoots from behind, and Wardweaver shields.

### 13.4 Files and tests

- **Changed:**
  - `bond_def.gd` (`relic`, no mods)
  - `data/bonds.json` (the three bonds, now keys)
  - `relic_def.gd` (the `bond` tier)
  - `data/relics.json` (the three bond relics)
  - `act_def.gd` and `data/act1.json` (`bond_relic_pct` 20; `relic_prices.bond` 0)
  - `offers.gd` (the draw)
  - `run_flow.gd` and `run_content.gd` (no bond mods; `bond_relics(state)`, the on bonds' relics not yet held)
  - `aura_def.gd` and `passives.gd` (`behind_wall`)
  - `walls.gd` (the back side)
  - `effect_def.gd`, `events.gd`, and `passives.gd` (`on_knockback`, `on_guard`, `cooldown_per_unit_ms`)
  - `hero_panel.gd`, `mod_info.gd`, and `unit_info.gd` (the words); the run day screen's relic card (the tier, "Free")
  - the chaos fight (the two triggers, the aura behind a wall)
- **Tests:**
  - **`tests/sim/test_bond_pieces.gd`:** behind a wall, on and off; `on_knockback`; `on_guard` and its cooldown per unit.
  - **`tests/run/test_bonds.gd`, or the bond tests where they live:**
    - a bond on adds its relic to the shops' draw and never to the Magpie;
    - a bond relic is free;
    - held, it's drawn no more;
    - no bond, no bond relic;
    - fights no longer take the old boosts;
    - the tier counts (bond 3).
  - Fight-wide: determinism, the log audit, every encounter on the screen, the bench fingerprints unchanged; the run report runs.

### 13.5 Questions (answered in 13.6)

- **R.** How much more likely than an epic is a bond relic to show up?
- **S.** With two bonds on at once, do both relics join?
- **T.** All three Act 1 bonds include Brannoc: should Maren and Vell get one now?

### 13.6 Decisions (the playtester, 2026-10-01)

26. **Step 5d is built as this section says.**
27. **A bond relic shows up 20% of a shop's relic draws** while its bond is on (Question R), four times the Pedlar's epic chance.
28. **Two bonds on at once both join** (Question S): each draw picks one of their relics.
29. **The three Act 1 bonds stay** (Question T); a Maren–Vell bond is written when the roster grows.

### 13.7 Built in step 5d (2026-10-01)

- **The bonds:**
  - `BondDef` is two paths, a name, a line, and its `relic`. `RunContent` checks the relic is of the bond tier, and that every bond relic has its bond.
  - Fights take no bond mods (the built boosts are gone).
  - `RunContent.bond_relics(state)` is the on bonds' relics not yet held.
- **The tier** `bond` (`RelicDef.Tier.BOND`) costs 0 (`relic_prices.bond`). `RunFlow.relic_price` keeps 0 at 0 whatever the run's price rules (Haggler's Charm can't make it cost 1).
- **The draw** (`Offers._bond_relic`):
  - Each Pedlar relic draw, and the pre-boss shop's slot beside the legendary, is an on bond's relic `bond_relic_pct` (20) of the time, one of them at random with two on.
  - It rolls only when there's one to find, so a run without an on bond draws exactly as before.
  - Never at the Magpie or in an elite's, Rift Tear's, or the Shrine's choice.
- **The pieces:**
  - **Behind a wall:** `"while": "behind_wall"` (`Walls.behind`; each wall keeps where its raiser stood, `Wall.back`).
  - **`on_knockback`:** from PUSH lines noted "knocked back" on an enemy, so a pull or a charge's own move doesn't count.
  - **`on_guard`:** from GUARD lines.
  - **`cooldown_per_unit_ms`:** `Listener.last_for`, a lookup by the unit named.
- **Relics:** the three bond relics, 89 in all.
- **The UI:**
  - The hero panel's bond line: "Sentry and Sniper is on: The Watchtower Stone can show up in shops, free." Once held, "... is yours."
  - A bond relic's card says "BOND RELIC" in green.
  - The shop's button for a free relic reads "Take · free".
  - The Codex isn't built yet.
- **Tests:**
  - `tests/sim/test_bond_pieces.gd` (4).
  - `test_relics.gd` (3 more: about 20% of draws once on, never at the Magpie, beside the pre-boss legendary, none without a bond; free even with Haggler's Charm, and drawn no more once held; two bonds both join).
  - `test_camp.gd`'s bond test: the bond's relic joins and no boost.
  - The chaos fight's brand Roots an enemy it knocks back (`on_knockback`, seed 37 still has every piece).
  - `test_mod_info`, `test_unit_info`, and the tier counts changed on purpose.
- **What moved:** no built kit's fight; the bench's fingerprints are unchanged. **The run report** (54 runs): **66% of runs won**, the same to the decimal as after 5c-2. A bond switched on in 8 runs (all Sentry and Sniper), but late: on day 7 in seven of them and day 5 in one, with few shop draws left. The bot took no bond relic (0.0 a run), and losing the old boosts that late changed no outcome. How often a run meets its bond relic is for the playtest and phase 6's bot.

## 14. Step 6: the loadout pool

Status: **approved (2026-10-01, Decisions 30–33); built in five parts, 6a–6e (10-01).** Builds `loadout/` (its README's nine rules and its decisions; `tactics.md`, `gambits.md`, `sigils.md`, `charms.md`) and the Magpie's stall (`magpie.md`). The Magpie as a node (when he's offered, from day 3, at most twice an act) is step 8's; until then he keeps today's camp place, with the new stall.

### 14.1 What's there now (phase 5)

- **Items** (`ItemDef`, `data/items.json`): 22 (10 charms, 4 tactics, 5 sigils, 3 grafts). Each has one price, one kit mod (a tactic names `tactics.json`'s), and `needs` tags behind `works_on`, which drives the "no effect on this hero" marker and the Pedlar's filter (only items that work on someone).
- **Tactics** (`TacticDef`, `Tactics`): four kinds (prefer_target, hold_ground, signature_threshold, stop_near), one payoff each, and a `heroes` list (Wait to heal is Vell's).
- **The run:** a hero has `act.slots` (3) slots; the stash holds what isn't equipped; one tactic per hero (`RunFlow.equip`). The Pedlar draws `pedlar_wares` (4) from what works on the team; the Magpie (a camp place on his day) sells half grafts at 150%. Nothing ranks up, and nothing sells back.

### 14.2 Why it's split

62 items, and most of the new ones need something the sim can't do yet. Like step 5, it's built in parts, each a commit with the suite green and the bench's fingerprints unchanged:

| Part | What | Items |
| --- | --- | --- |
| **6a** | **The frame:** ranks, each kind's counter, buying a copy, selling at half, prices by kind, gambits as a kind (one per hero), `needs`/`works_on` and the marker gone, the Pedlar unfiltered, grafts cut, the built items mapped or cut (README's table); and every charm and sigil the built pieces already write | 27 (below) |
| **6b** | **The charms' and sigils' new pieces** and the rest of them | 15 |
| **6c** | **The tactics:** ranks for the four built ones, and ten new orders | 14 (10 new) |
| **6d** | **The gambits:** placement and fight-start rules | 6 |
| **6e** | **The Magpie's stall:** rank II charms, buying relics, the swap | — |

### 14.3 Ranks (6a)

- **An item has three ranks in its data:** `"ranks": [{...}, {...}, {...}]`, each rank whole (a charm's or sigil's kit mod; a tactic's numbers and payoff; a gambit's numbers and mod), so rank III's twist is just more of the mod. `ModInfo` reads the held rank's numbers line, and the card shows the next rank's line under it ("Rank II: ...").
- **A run owns at most one of each item**, at a rank: `RunState.items` (id -> `{rank, count}`, saved; the save's version goes up and an old save's stash and slots load at rank I). Moving it between heroes keeps its rank and count; ranks reset with the run (rule 5).
- **Buying a copy of an item you own** puts it a rank up and starts its count again. An item at rank III is never drawn into a shop. A copy bought at rank II (the Magpie's) lands on rank II, or one above what you hold, whichever is higher.
- **The counters** (counted only while it's equipped on a hero who fights; fights counted the way growing cards' are, `UnitSetup.tally_keys`, won or lost):

| Kind | Rank II after | Rank III after | Counted as |
| --- | --- | --- | --- |
| Tactic | 60s | 180s more | a new tally, `ms_standing`: how long its hero stands in the fight (Decision 32) |
| Gambit | 3 fights | 6 more | fights it was equipped in, its hero placed |
| Sigil | 10 casts | 25 more | the `casts` its signature fired (a new tally kind; an echo is its own ability, so it doesn't count) |
| Charm | 4 won fights | 8 more | won fights (a tie pays like a win, so counts) |

  The numbers are `act1.json`'s (`item_ranks`), so tuning moves them without code. After a fight the day screen lists what ranked up, beside what grew.

### 14.4 Buying and selling (6a)

- **Prices by kind** (`act1.json` `item_prices`: tactic 4, charm 6, sigil 8, gambit 12); items lose their own `price`. Relics' `price_add` (Haggler's Charm) still applies at the Pedlar.
- **Selling:** `RunFlow.sell(item_id)` at the Pedlar (the pre-boss shop too) pays half its kind's price, rounded down, whatever its rank, and takes it from the stash or a slot. The Magpie doesn't buy items (`magpie.md`: "Charms, tactics, sigils, and gambits are sold at the shop"; the README's "any shop" reads as any Pedlar).
- **The Pedlar's wares:** `pedlar_wares` (4) drawn from every item not at rank III, all four kinds evenly by count (no filter, no weighting; the shop mix waits on step 8's shop). An owned item can show up; its card says "Rank II" (what buying it makes it).
- **One gambit per hero**, the way one tactic per hero is checked now.
- **No warnings** (rule 2): `needs`, `works_on`, `has_need`, and the hero panel's marker go. A tactic a hero can't follow (Wait to heal without a signature that waits) does nothing; `Tactics` already skips it.

### 14.5 The items (6a and 6b)

**Charms (27).** The built pieces write 17 in 6a; 6b adds what the other 10 need, and Hunter's Chalk's rank III.

| Charm | Part | Built from |
| --- | --- | --- |
| Ember-Tipped (from Ember Charm), Bloodletter, Bramble Knot, Hunter's Chalk (I, II), Flint and Tinder, Kindling Ward, Mana Leech, Leech Fang, Opportunist, Headsman's Patience, Steady Stance, Spiteful Blood (from Thorned Mail), Fleet (from Swift Boots), Smoke Vial, Warding Thread, Last Breath, Purifying Light | 6a | basic attack's `add_effects`, `every`, `on_holder_crit`/`on_shield_broken` with `vs`, `vs` damage auras, planted auras, lifesteal, `on_hit_taken` with a share of damage, `on_fall`, a once-a-fight below-HP trigger, boosts, cleanse |
| Hunter's Chalk III (its Marks stack) | 6b | `"stacking": true` on one apply_status (the hero's own Hunter's Engine rule) |
| Fletched for Wings (III grounds) | 6b | a new status, **Grounded** (a flier can't fly: it walks, and rocks and walls stop it), with its keyword-free tag |
| Shadow Step | 6b | a new piece: a **next-hit boost** (a boost status that ends on its holder's next hit: +ATK, and at III a sure crit), applied on `on_status_ended` Stealth |
| Bloodhound | 6b | its `vs` aura, and a kit mod that sets the basic attack's targeting to prefer enemies below 50% (a new `KitMod` `"prefer"`: a `UnitCondition`, read by `Targeting` before the kit's own rule) |
| Armor Breaker | 6b | a new aura stat, **`def_ignore_bp`** (a hit ignores that share of the target's DEF), shared with Break the line |
| Braced | 6b | a new trigger, `on_charged` (a charge or leap hit the holder), and a new aura stat, `unpushable` (knockback and pulls don't move it; a stopped push doesn't stun) |
| Sidestep | 6b | a new piece, **dodge** (`"dodge_every_ms"`: a hit on the holder misses once that long has passed since the last; logged as DODGED, a new kind, "Miss" over the unit) |
| Iron Skin | 6b | a stacking status, **Iron Skin** (N stacks at the fight's start; each hit taken spends one and deals half damage, a `damage_reduced_bp` while it lasts) |
| Spite Brand | 6b | `on_hit_taken`'s new `"min_bp_of_max_hp"` and the built `cooldown_per_unit_ms` |
| Light Feet | 6b | a new `KitMod` `"hop": {"within_add": 500, "cooldown_add_ms": -1000}` (the hop trait's reach and cooldown) |
| Scavenger | 6b | a new trigger, `on_enemy_fell` (an enemy fell within `within_hexes` of the holder), and a stacking whole-fight boost (as Quickened) |

**Sigils (15).** 6a writes 10; 6b adds what 5 need.

| Sigil | Part | Built from |
| --- | --- | --- |
| Echo (from Sigil of Echoes), Thrift (from Sigil of Haste), Desperate (from the Last Breath sigil), Lingering, Tolling, Kindled, Grasping, Veiled, Bulwark, Surge | 6a | `echo`, `mana.max_bp`, `also_fires` hp_below, `duration_add_ms`, the signature's `add_effects`, boosts on `on_ability` |
| Opener (from Deep Well) | 6b | `mana.start_bp` (a share of the bar, not a flat amount) |
| Quickcast | 6b | a signature change `cast_bp` (0: instant) |
| Wide (from Sigil of Reach) | 6b | `radius_add` (built) and a new `targets_add` (one more target for a signature that picks a count) |
| Siphon, Execution | 6b | `"from_signature": true` on a per-hit aura (beside `from_basic`), and on `on_kill` (Execution III's refund) |

Bulwark III's "allies within 1 hex" is the built `allies_near_target` from the holder. Surge's three ranks are three boost statuses (`surge`, `surge_2`, `surge_3`), as a boost's numbers are the status's.

**Cut:** Frost-Tipped, Vital Stone, Whetstone, Serrated Edge, Mending Salve, Iron Skin as built (+15% DEF), Sigil of Grief, and the three grafts (Shake It Off, Second Wind, Sidestep as a graft). The `graft` kind, its frame, and the Magpie's graft wares go. **`ally_falls`** (Sigil of Grief's trigger) stays in the sim, since a relic or a path may want it; nothing uses it.

### 14.6 Tactics (6c)

Each tactic's ranks are its numbers and payoff (`TacticDef.ranks`); rank III's twist is code in `Tactics`, said here. `heroes` goes (rule 1): any hero takes any tactic.

| Tactic | Order (kind) | What's new | (proposed rank count, not taken: Decision 32) |
| --- | --- | --- | --- |
| Casters first | prefer_target (built) | III: its first hit on each caster Silences it 1s | an enemy it prefers stands |
| Fliers first | prefer_target, by a `UnitCondition` (`{"flying": true}`) instead of only archetypes | payoff `vs` fliers; III Grounds (6b's status) on the first hit on each | the same |
| Marked first | prefer_target by keyword | payoff +CRIT vs Marked; III: its crits on Marked enemies extend the Mark 0.5s (built `extend_status`) | the same |
| Finish them | prefer_target, a new pick: the lowest HP share within its reach | payoff vs below 50%; III: kills refund 10 mana | an enemy stands within its reach |
| Break the line | prefer_target, a new pick: the most DEF | payoff `def_ignore_bp` (6b); III: its first hit on each enemy gives 10 Sunder | an enemy stands |
| Guard the weakest | a new kind, `guard_ally`: targets the enemy nearest its lowest-HP-share ally (or attacking it, if one is) | +10 DEF while doing it; III: that ally +10 DEF too | it's on such a target |
| Hold your ground | hold_ground (built) | III: keeps half its payoff after letting go | it holds |
| Plant your feet | stop_near (built) | its payoff: +10 DEF while stopped (II +20); III +10% ATK and MGK too | it's stopped |
| Keep your distance | a new kind, `kite`: steps back along the line from its target when the target is nearer than its range minus a hex, if the ground behind is safe | +ATSP at full range; III: its first hit after a step back is a crit | at full range |
| Stay with the tank | a new kind, `leash`: walks back when the ally with the most DEF is more than 2 hexes away | +10% DEF within range; III: 1% max HP a second | within 2 hexes of that ally |
| Dive | prefer_target, a new pick: the farthest enemy; walks there | +20% ATK and MGK for the first 5s (a window aura); III: a kill in the dive restarts it | it's diving |
| Wait to heal | signature_threshold (built) | II: 70% instead of 60%; III: the heal it saved also cleanses one harmful status | its signature can wait |
| Wait for a crowd | a new kind, `signature_crowd`: a full bar waits until 3 enemies (or all left, if fewer) are in its area's reach, 4s at most | payoff on the held fire; III +10% for each enemy hit past 3 | its signature is an area that can wait |
| Save it for the kill | a new kind, `signature_finish`: a full bar waits until its target is below 50% | payoff on the held fire; III: a kill with it refunds 30% of its mana | its signature deals damage and can wait |

Each new behavior logs TACTIC lines like the built ones, and the board needs nothing new (the hero's walk and hits show it). Tactic-free fights never reach the code.

### 14.7 Gambits (6d)

A gambit is an item of the new kind `gambit`: a **rule** (code, named in the data, like a tactic's kind) and, per rank, its numbers and an optional kit mod. Placement rules live in `FightSetup.validate` (what's legal) and `Encounters.setup` (where it stands); the UI asks the sim what's legal, as now.

| Gambit | Rule | How |
| --- | --- | --- |
| **Infiltrate** | placement: also the neutral row (II: and the enemy zone's front row) | `UnitSetup.zone_rows`; III's Shield is a start effect in its mod |
| **Ambush** | none (fight start) | Stealth 3s at the start (`on_fight_start`, built) and 6b's next-hit boost (a sure crit; II +50% damage; III Marks) |
| **Rear Guard** | none (fight start; Decision 31: it stays on the board) | I: starts hidden until an enemy comes within 2 hexes (a Stealth that lasts until then: a new `"until_enemy_within"` on apply_status); II: +20% attack speed for its first 5s out of hiding; III: its first attack out of hiding Roots the target for 1s |
| **Late Arrival** | fight start: off the board until 5s (II 4s), then enters on the edge hex it was placed on (any of the board's edge hexes), or the nearest free safe spot, hidden 2s | built on Second Dawn's rise: a unit away from the plane, logged ARRIVE (a new kind: the token appears with a pulse); II's boost and III's Stun on its first attack are its mod |
| **Stand Together** | placement: may share a hex with another hero; both start side by side across it | `validate` allows the pair; `Encounters.setup` sets them a third of a hex apart; II/III are auras (a window; III `ally_near`, built) given to both |
| **Switch Places** | fight time: at 10s, swaps places with the ally farthest from it | a new effect, `swap` (both move, logged as two MOVE lines noted "swapped"); II lets the player pick 5, 10, or 15s (`RunState.Hero.gambit_at`, chosen in the loadout, like a snare's hex); III Shields both |

Gambits need a frame (the README's open question): until one is drawn, they use the sigil frame in a fourth color.

### 14.8 The Magpie's stall (6e)

On his day (today's camp place, until step 8 makes him a node):
- **2 charms at rank II**, 12 shards each (`magpie_charm_price`); bought, a charm lands at rank II (or one above yours).
- **1 relic, epic or legendary, at 25% off** (built: `magpie_odds`, `magpie_relic_pct` 75).
- **He buys relics** for half their tier's price (`relic_sell`: common 2, rare 6, epic 10, legendary 15, boss 15): `RunFlow.sell_relic`. A relic sold is gone (its growth with it); a bond relic sells for 0 and can come back while its bond is on.
- **The swap**, once a visit, free: `RunFlow.swap_relic(id)` gives a random relic of the same tier the run doesn't hold (a boss for a boss; a bond relic can't be swapped), drawn on the Magpie's stream.
- No rerolls, and he doesn't buy items. His markup (`magpie_markup_pct`) and graft wares go.

### 14.9 Files, tests, and the bot

- **Changed:** `item_def.gd` (ranks, gambit, no needs or price), `tactic_def.gd` and `tactics.gd` (ranks, the new kinds, no heroes), `data/items.json` (62), `data/tactics.json` (14), `data/statuses.json` (Grounded, Iron Skin, the next-hit boost, surges, Scavenger's), `act_def.gd`/`data/act1.json` (item prices and ranks, the Magpie's prices), `run_state.gd` and `run_save.gd` (items' ranks and counts, `gambit_at`), `run_flow.gd` (buy, sell, rank-ups, sell and swap relics), `offers.gd`, `run_content.gd`, the sim pieces in 14.5–14.7 with their log kinds (DODGED, ARRIVE), `fight_setup.gd`/`encounters.gd` (gambits), `deed_def.gd`/`deeds.gd` (`ms_standing`, `casts`), `mod_info.gd`/`unit_info.gd` (ranks, the words), `hero_panel.gd`, `hero_bar.gd`, and `run_day_screen.gd` (rank on chips and cards, Sell, the Magpie's stall), `item_icon.gd` (the gambit frame), `tools/run_bot.gd` (buys as before, never sells), `tools/run_report.gd` (items ranked up per run), the chaos fight.
- **Tests:** `tests/run/test_loadout.gd` (new: ranks from each counter, a copy skips a rank, rank III never drawn, selling at half from a slot or the stash, prices by kind, one gambit per hero, an old save loads at rank I); `tests/sim/test_loadout_pieces.gd` (each 6b piece and tactic kind and gambit rule in a small fight); `test_magpie` (the stall, selling, the swap); the item and tactic lists, `test_mod_info`, and `test_unit_info` changed on purpose; determinism, the log audit, every encounter on the screen (DODGED and ARRIVE get rows), the bench's fingerprints unchanged; the run report runs.

### 14.10 Questions (answered in 14.11)

- **U. Approve this section, split as 14.2** (6a–6e, a commit each)?
- **V. Rear Guard** stands one row behind the heroes' back row, but the board has no row there. (a) Add a strip one hex deep behind the back row to the plane, open to anyone and crumbling with the first ring (the plane, the routes, the collapse, and the board's drawing all change); (b) keep it on the board: rank I starts it hidden until an enemy comes within 2 hexes (today's rank III), II +20% attack speed for 5s, and III a new twist; or (c) cut Rear Guard for now and build five gambits.
- **W. What counts toward a tactic's rank:** the time its order applies, kind by kind (14.6's last column), or every second its hero stands in a fight with it equipped?
- **X. Charms in a relic's lane** (Leech Fang with Leech Tooth, Armor Breaker with Sunder): they stack, as the damage rule adds bonuses of one kind. Keep it?

### 14.11 Decisions (the playtester, 2026-10-01)

30. **Step 6 is built as this section says, in five parts** (Question U): 6a the frame, 6b the charms' and sigils' pieces, 6c the tactics, 6d the gambits, 6e the Magpie's stall.
31. **Rear Guard stays on the board** (Question V): rank I starts it hidden until an enemy comes within 2 hexes, II gives +20% attack speed for its first 5s out of hiding, III Roots the target of its first attack out of hiding for 1s. The board gains no row.
32. **A tactic ranks up by every second its hero stands in a fight with it equipped** (Question W), not only while its order applies: 60s, then 180s more (about 2 fights, then 6).
33. **Charms stack with relics in the same lane** (Question X), like any two bonuses of one kind.

### 14.12 Built in step 6a (2026-10-01)

- **Items** (`ItemDef`): four kinds (charm, tactic, sigil, gambit; graft is gone), each charm, sigil, and gambit with three whole kit mods in `"ranks"` (`mod_at(rank)`), a tactic naming `tactics.json`'s. `price`, `needs`, `answers`, `works_on`, and the "no effect on this hero" marker are gone. `RunContent` checks each rank's mod is sound on every kit and changes something on some hero's (a data check, never shown to players).
- **Prices and ranks** are `act1.json`'s `items` (`ActDef.item_prices`, `item_ranks`): tactic 4, charm 6, sigil 8, gambit 12; rank II after 60s / 3 fights / 10 casts / 4 won fights, rank III after 180s / 6 / 25 / 8 more.
- **The run** (`RunState.item_ranks`, `item_counts`, `ranked`; the save's version is 2, so a save from before the pool doesn't load: its items are gone):
  - A run owns one of each item. Buying one it owns puts it a rank up (`RunFlow._gain_item`; a rank II copy lands one above, or on II); its count starts again.
  - `_rank_items` (in `record`, Hunts too) counts each equipped item on a placed hero: charms won fights (a tie is a win), gambits fights, tactics `ms_standing` and sigils `casts` from the fight's tallies (`RunContent.growth_tallies` adds them under `item:<id>`). Reaching the need ranks it up; what's over carries on. `rank_progress` says how far.
  - `sell` at the Pedlar pays half the kind's price, rounded down, from a slot or the stash; the Magpie doesn't buy items.
  - One tactic and one gambit per hero (`equip`).
  - The Pedlar and the Magpie draw from every item not held at rank III, unfiltered (`Offers._for_sale`). `RunContent.loadout_tactic` hands the fight a tactic only if its hero can follow it (`can_follow`), silently.
- **New tally kinds** (`DeedDef`): `casts` (its signature's FIRE entries; an echo has its own id) and `ms_standing` (each tick it stands).
- **Small sim pieces:** a trigger `on_below_hp` (the unit itself drops below a share of its max HP; again after climbing back above, up to `"times"` a fight, default 1), the target `allies_near_self` (from where it falls too), and cleanse's `"statuses"`. Four boost statuses: `surge`, `surge_2`, `last_breath`, `purified`.
- **Items** (30 in `data/items.json`): 16 charms (Ember-Tipped, Bloodletter, Bramble Knot, Flint and Tinder, Kindling Ward, Mana Leech, Leech Fang, Opportunist, Headsman's Patience, Steady Stance, Spiteful Blood, Fleet, Smoke Vial, Warding Thread, Last Breath, Purifying Light), the four built tactics, and 10 sigils (Echo, Thrift, Desperate, Lingering, Tolling, Kindled, Grasping, Veiled, Bulwark, Surge). Hunter's Chalk moved to 6b with its rank III (its Marks stack). The cut items are gone. Kindling Ward's rank III Slow is the built Slow (30%, not the pool's 20%: a placeholder).
- **The UI:**
  - Item cards say the kind and rank ("CHARM · RANK II"), the rank's numbers, and the next rank's ("Rank III: ...").
  - The stash cards say how far each is ("3 of 4 won fights to rank II"), and so do the loadout slots' tooltips; slots, the hero bar's chips, and the hero panel name the rank.
  - A ware the run owns shows the rank buying it makes.
  - The Pedlar has a Sell button for each owned item.
  - After a fight, "Ranked up" lists what ranked up.
  - Mana changes by a share (Thrift, Hollow Drum) and regen now show in numbers lines.
  - Gambits take the rose frame grafts had, until theirs is drawn (`ItemIcon.FRAME_OF`).
- **The bot** buys a ware it owns (a rank up), else one that changes a hero's kit with a free slot (its own judgment, `RunBot.suits`); it never sells. **The run report** adds the items held at the end, by rank.
- **Tests:** `tests/run/test_loadout.gd` (11: prices and ranks by kind, a charm by won fights and a tie, sigils' and tactics' tallies with the carry-over, a real fight's casts and standing time, a bought copy, rank III never in a shop, the Pedlar unfiltered, selling, ranks reaching the fight, one gambit per hero, the save); `tests/sim/test_loadout_pieces.gd` (4: reading, on_below_hp, allies_near_self as it falls, a cleanse of some statuses); `test_economy.gd`, `test_mod_info.gd`, `test_art.gd`, `test_camp.gd`, and the status lists changed on purpose.
- **What moved:** no built kit's fight; the bench's fingerprints are unchanged. **The run report** (54 runs): **87% of runs won** (66% before), with 3.4 items held at the end (rank I 2.0, II 3.0, III 0.4). The new charms and sigils are stronger than the cut ones, and the bot now buys items it owns to rank them up. Their numbers are placeholders for step 9's retune.

### 14.13 Built in step 6b (2026-10-01)

- **The pieces** (each skipped by a fight that doesn't use it; the bench's fingerprints are unchanged):
  - **Aura stats that add** (`AuraDef`): `def_ignore_bp` (`CombatSim.mitigate_hit` takes the attacker's share off the target's DEF), `unpushable` (a knockback or pull on it logs RESISTED, "resists being knocked back", and moves nothing), `dodge_every_ms` (a hit on it misses, then not again for that long: a new log kind, **DODGED**, "Miss" over the unit; the miss sets off no on_hit effects), and `halved_hits` (its first N hits taken land at half, noted "halved").
  - **`from_signature`** on a per-hit aura (beside `from_basic`) and on `on_kill`.
  - **Events:** `on_charged` (a charge or leap's hit lands on the unit; `AbilityDef.moves_itself`) and `on_enemy_fell` (`Events.enemy_fell`, beside on_kill; `"fell_within_hexes"`). An event effect's `"cooldown_ms"` (whoever it names) and on_hit_taken's `"min_bp_of_max_hp"`.
  - **Statuses:** a kind, **`grounded`** (a flier walks while it lasts, set down on the nearest free safe spot if it's over something, logged as a PUSH noted "grounded"; it flies again when it ends; tag "GRND"), and a boost's `"until_attack"` (it ends at its holder's next FIRE: that attack had it; applying one starts the sim reading events).
  - **Effects:** apply_status's `"marks_stack"` (that Mark stacks, as under Hunter's Engine), gain_mana's `"amount_bp_of_max_mana"`.
  - **Kit mods:** `mana.start_bp` (Opener), a signature change's `cast_bp` (0: instant) and `targets_add` (copies of its effects on its target reach the N nearest others of the target's side; `one_of`: not on a signature with an area, whose radius grows instead), `"prefer"` (`UnitDef.prefer`: `Targeting.update` picks the nearest enemy meeting it first, logged with its label), and `"hop"` (`UnitDef.hop_within` and the hop's cooldown).
- **Items:** 16 more (46 in all): 11 charms (Hunter's Chalk, Fletched for Wings, Shadow Step, Bloodhound, Armor Breaker, Braced, Sidestep, Iron Skin, Spite Brand, Light Feet, Scavenger) and 5 sigils (Opener, Quickcast, Wide, Siphon, Execution). Six statuses join them: `grounded`, `shadow_step` (and `_2`, `_3`), `bloodhound`, `scavenged`. Some notes:
  - Fletched for Wings III grounds fliers on any of its holder's hits (an on_holder_hit `vs` fliers), not only the basic attack's: on_hit effects take no `vs`.
  - Wide's rank I is one or the other (`one_of`), rank II both, rank III +2 of both.
  - Braced's passive is `braced_charm`: Hearthwall already has a `braced`.
- **The UI:** card and kit words for each piece ("its hits ignore 10% of the target's DEF", "a hit on it misses, then not again for 6s", "its attacks go for enemies that are below 50% HP first", "+1 target (without an area)", "starts with 50% mana", "Every charge or leap that hits it"), and "Miss" for DODGED.
- **Tests:** `tests/sim/test_loadout_pieces.gd` (17 more: reading, DEF ignored, unpushable, a dodge and its wait, a dodge's on_hit effects, halved hits, Grounded on and off, a boost until the next attack, a Mark that stacks by its effect, a kit's preference, on_charged, a big hit with a cooldown, an enemy falling near, a kill by the signature refunding a share, Opener, Quickcast and Wide, lifesteal on the signature only, Light Feet); the item counts and status lists changed on purpose; DODGED has its audit rule and board row (the chaos fight doesn't use it: `test_loadout_pieces` does).
- **What moved:** no built kit's fight. **The run report** (54 runs): **81% of runs won** (87% after 6a), 3.1 items held at the end (rank I 1.9, II 3.0, III 0.2). The pool is wider, so the bot's buys are spread thinner. Numbers are placeholders for step 9.

### 14.14 Built in step 6c (2026-10-01)

- **`TacticDef`:** nine kinds (the built four, and `guard_ally`, `kite`, `leash`, `signature_crowd`, `signature_finish`); prefer_target by `archetypes`, `prefers` (a UnitCondition), or `pick` (`lowest_hp_in_reach`, `most_def`, `farthest`). A `"payoff"` takes any of the payoff keys (each optional), and `"ranks": [{...}, {...}]` change any number, payoff, or twist for ranks II and III, each on the one before (`at_rank()`). `heroes` is optional (empty: anyone, the loadout's rule 1).
- **`Tactics`:**
  - **Who can follow what** (`can_follow`): Wait to heal needs a healing mana signature, Wait for a crowd one with an area, Save it for the kill one that deals damage; the rest anyone. `FightSetup.validate`, Practice's picker, the run (`RunContent.can_follow`, silently), and the tactics report all use it.
  - **Stat payoffs** (DEF points, DEF, ATK and MGK, ATSP points) are auras `kit_with_payoff()` adds to the kit (`UnitState.from_setup`), on while `applies()`: a new aura condition, `"while": "tactic"` (code-made; data can't use it).
  - **Orders:** `preferred()` (guard_ally: the nearest enemy targeting its weakest other ally); `kite()` (between attacks, a step back while its target is nearer than its reach less a hex; `Movement.step_to`); `leash()` (walks back to its ally with the most DEF past `leash_hexes`, and waits at the edge rather than walk away); `crowd_ready()` and `finish_ready()` gate the mana signature (`Signatures`).
  - **Twists:** `on_hit()` (first_hit on each enemy once; a crit stretches a Mark), `on_kill()` (kill_mana, Dive's window again, the bar refunded for a kill by the signature), `tick()` (Stay with the tank's regeneration; Guard the weakest's `watched_over` on its ward, renewed every second), Hold your ground's `keep_bp`, Keep your distance's sure crit, Wait to heal's `cleanse_one` (`Statuses.end_now`, "cleansed by Wait to heal").
- **The run:** `RunContent.loadout_tactic` gives the tactic at its item's rank, and `RunFlow.fight_setup` sets it on the hero after `Encounters.setup`.
- **Data:** `data/tactics.json` has the 14 with their ranks (Plant your feet gains +10 DEF while stopped at rank I, as `loadout/tactics.md` says; Wait to heal is anyone's who can follow it); 10 tactic items (56 items in all); one status, `watched_over`.
- **The UI:** a tactic's numbers line names its order, payoffs, and twists ("The farthest enemy first · +20% ATK and MGK for its first 5s"); tactic cards show the next rank's line. Practice offers each hero every tactic it can follow (Maren 11, Vell 12, Brannoc 12).
- **Tests:** `tests/sim/test_loadout_tactics.gd` (13: each new order, each payoff kind, and the twists in small fights, with the data's tactics); `test_tactic_defs.gd` (the 14, ranks building on each other, `can_follow`, payoffs optional and checked); `test_tactics_ui.gd`, `test_unit_info.gd`, `test_sim_runner.gd` (the variants are each hero on each tactic it can follow), and the counts changed on purpose.
- **What moved:** no built kit's fight without a tactic; the bench's fingerprints are unchanged. Plant your feet's fights change (its new payoff), on purpose. **The run report** (54 runs): **87% of runs won** (81% after 6b), 3.6 items held at the end (rank I 2.1, II 3.1, III 0.4).

### 14.15 Built in step 6d (2026-10-01)

- **A gambit is a kit mod** with a `"gambit"` part (`KitMod` → `UnitDef.gambit_label`, `place_rule`, `arrive_ticks`, `swap_ticks`, `swap_shield_bp`, `swap_choice`); its other parts are passives. `Gambits` (`src/sim/gambits.gd`) has the rules, each code said here:
  - **Where it may start** (`may_place`, read by `FightSetup.validate`, so the board's drag follows it): `neutral` (Infiltrate), `front` (and the enemies' front row: Infiltrate II), `edge` (any edge hex, besides its zone: Late Arrival), `share` (two heroes on one hex, one holding it: Stand Together; they start two thirds of a hex apart across it).
  - **Arriving late** (`arrive_ms`): the hero starts away (`UnitState.arriving`: not on the board, not targetable, and not down, so its side isn't beaten while it's to come, and it isn't a fallen ally), then enters where it was placed or the nearest free safe spot, logged as a new kind, **ARRIVE** ("Arrives", with a pulse).
  - **Switching places** (`swap_ms`, or the player's 5, 10, or 15s from rank II: `RunState.Hero.gambit_at`, `RunFlow.set_gambit_at`, `UnitSetup.swap_at`): with the ally farthest from it, two PUSH lines noted "swapped places"; rank III Shields both.
- **New pieces:** passives' `on_fight_start` (`Passives.fight_start`, once as the fight starts) and the event `on_arrive`; apply_status's `"until_enemy_within_hexes"` (`StatusState.until_near`: it ends once an enemy stands that near, "an enemy came near").
- **The six** (62 items in all): Infiltrate (III: a 15% Shield at the start), Ambush (Stealth 3s and an `ambush` boost that crits its first attack; II 4s and +50% crit damage; III its first hit Marks 4s), Rear Guard (Decision 31: hidden until an enemy comes within 2 hexes; II `rear_guard` +20 ATSP for 5s out of hiding; III its first hit Roots 1s), Late Arrival (enters at 5s, hidden 2s; II at 4s with `late_surge`; III its first hit Stuns 1s), Stand Together (II +10 DEF for 5s; III +10% ATK and MGK while an ally is within 1 hex; the hero sharing its holder's hex gets the mod too, in `RunFlow.fight_setup`), Switch Places. Four statuses join them: `ambush`, `ambush_2`, `rear_guard`, `late_surge`.
- **The UI:** gambit cards in the rose frame grafts had; their numbers line ("may start on the middle row", "enters at 5s", "swaps with its farthest ally at 10s (or 5s or 15s, as you choose)"); the loadout's "Switch at 5s / 10s / 15s" buttons for a hero holding Switch Places at rank II or III.
- **Tests:** `tests/sim/test_gambits.gd` (7: where each lets a hero start, sharing a hex, a late arrival and its passives, an arriving hero isn't down, a swap at its moment and the chosen one, Ambush's and Rear Guard's Stealth, and the run's sharing, choosing, and saving); ARRIVE's audit rule and board row; `test_effect_defs.gd` (a passive may use on_fight_start) and the counts changed on purpose.
- **What moved:** no built fight; the bench's fingerprints are unchanged. **The run report** (54 runs): **88% of runs won**, 3.7 items held at the end. The bot buys gambits like anything else and places as before.

### 14.16 Built in step 6e (2026-10-01)

- **His wares** (`Offers.magpie`): `magpie_wares` (2) charms the run doesn't hold at rank III, `magpie_charm_price` (12) each; bought, one lands at rank II, or one above the rank held. His relic is as built (epic or legendary, 25% off). His markup and his other wares are gone.
- **He buys relics** (`RunFlow.sell_relic`, at `relic_sell`: common 2, rare 6, epic 10, legendary 15, boss 15, a bond relic 0) and **swaps one a visit** (`swap_relic`, `Offers.magpie_swap`: a relic of the same tier the run doesn't hold, a boss relic for a boss relic, on the Magpie's stream; a bond relic doesn't swap; `RunState.magpie_swapped`, cleared as a shop opens). A relic let go (`_lose_relic`) takes what it counted with it, and a loadout slot it gave (what was in it goes back to the stash).
- **He doesn't buy items** (only the Pedlar does), as before.
- **The UI:** his stall's line; a Sell and a Swap button for each relic held (Swap greyed once used, or for a bond relic); his charm cards say rank II (or III, for one held).
- **Tests:** `tests/run/test_magpie.gd` (5: two charms at rank II and a copy's rank III, never one at rank III, no item buying; selling relics and the slot one gave; one swap a visit and again the next; a boss relic for a boss relic, no bond swap, a bond sells for nothing; the save); `test_economy.gd`'s Magpie changed on purpose.
- **What moved:** no fight. **The run report** (54 runs): **90% of runs won**, 4.0 relics and 4.7 items held at the end (rank I 1.3, II 3.0, III 0.4). The bot buys the Magpie's charms like the Pedlar's, and never sells or swaps.

**Step 6 is built.** The loadout pool is whole: 62 items in four kinds with three ranks each, the Pedlar's selling back, and the Magpie's stall. Runs are won far more often than before step 6 (66% to 90%): every new item is stronger than the cut ones, and their numbers are placeholders for step 9's retune.

## 15. Step 7: the upgrade pools

Status: **approved (2026-10-01, Decisions 34–39); built in four parts, 7a–7d (10-01; 15.13–15.16).** Builds `upgrade-pools.md`: what the after-fight pick offers each hero (a hero pool of 12, two taste upgrades per path from the vow until the hero transforms, then four path upgrades and the path's growing one), stacking stat upgrades locked in as a flat amount, and Volley's taste back to every 4th shot. Apex upgrades wait for apexes (`apexes.md`).

### 15.1 What's there now (phases 5 and 5c step 4)

- **The upgrades** (`UpgradeDef`, `data/upgrades.json`): 48. Phase 5's 36 (3 per hero, any path; 3 per path, one of them a **vow pick** offered from the vow, with a `transformed_mod` for after the transformation; the other two once transformed), and step 4's 12 growing ones (one per hero, one per path).
- **The pick** (`Offers.pick`): one card per hero from what that hero can be offered (`RunContent.upgrades_for`: its own cards it doesn't hold, every card equally likely), and at `wild_card_pct` (25%) one card from anyone's instead. Take one, or `pick_shards` (5). Relics add cards and takes. Nothing can be taken twice.
- **The bot** takes the card for the hero with the fewest upgrades.

### 15.2 Why it's split

87 new cards (36 cut, the 12 growing ones kept), and about half need something the sim can't do yet. Like step 6, it's built in parts, each a commit with the suite green and the bench's fingerprints unchanged:

| Part | What | New cards |
| --- | --- | --- |
| **7a** | **The frame:** the three layers and the draw by stage (15.3), stacking with its lock-in (15.4), taste cards after the transformation (15.5), the 36 built cards cut, Volley's every 4th (15.8), the save's version; and every card the built pieces already write | 48 |
| **7b** | **The small knobs** on kit mods (one number or one filter each) and the cards they write | 18 |
| **7c** | **The new conditions and filters** (who a bonus counts against, when an effect runs) and their cards | 15 |
| **7d** | **The six big pieces:** a storm that follows, arrows that split again, a wall that sends arrows back, snares that catch leaps, a snare under an ally, and a lantern placed before the fight | 6 |

Until 7b–7d land, their cards aren't in the data, so the pools are smaller for a while (no card waits on a later part's piece).

### 15.3 The pools and the draw (7a)

- **Three layers** (`UpgradeDef.layer`): `hero` (`"hero": "maren"`), `taste` (`"path": "deadeye", "taste": true`), and `path` (`"path": "deadeye"`; its growing card too). The vow pick and `"vow"` go; a taste card has a `transformed_mod` instead (15.5).
- **What a hero can be offered** (`upgrades_for`, by stage): its hero cards always; its vowed path's taste cards while vowed and not transformed; its path's cards once transformed. Switch vow (before transforming) swaps which taste cards it's offered, as now.
- **What counts:** hero cards always; taste and path cards while the hero is on their path (as now).
- **Proposed, for the design's open questions** (Question AB): the pick keeps its shape (one card per hero, the wild card, Take 5 shards); every card a hero can be offered is equally likely, so a vowed hero sees a taste card about 1 pick in 7, and a transformed one a path card about 1 in 3; stacking cards show as often as any other and have no cap. The run report counts each layer's picks, and step 9 retunes the odds if they feel wrong.
- **Cards that would change nothing** (Question AA): a hero card can stop doing anything once its hero transforms: Maren's Mark cards (Deep Mark, Heavy Mark, and the built Notched Bow) on all three of her transformed paths, Brannoc's taunt cards (Long Hold, Stubborn Taunt) once Hearthwall or Ironbrand, and Grudge once Last Watch (no mana). Proposed: **the pick never offers a card that changes nothing on the hero's kit as it is now** (`KitMod.affects`, built for 6a's marker and kept), and a held one stays held. A pick is the day's reward, not a shop item you can sell, so a dead card costs more here than a dead charm does.

### 15.4 Stacking upgrades (7a)

- **The ten stacking cards** (Maren: Honed Tips, Keen Eye, Quick Draw, Fletcher's Leathers; Brannoc: Hearthblood, Iron Hide, Heavy Arm; Vell: Bright Soul, Pilgrim's Cloak, Quick Glow) have no mod but `"stacks": {"stat": "atk", "pct": 10}`. They can be offered again after they're taken.
- **The lock-in:** taking one adds the stat's share **of the hero's stat now**, rounded to the nearest whole point and at least 1, as a flat amount (a `stats_add` mod) that never changes again. "Now" is the hero's kit stat with its path's stage and the upgrades it holds (earlier locks included), before wounds, items, relics, and fight auras, which come and go. Keen Eye at 8 CRIT locks in +2; Heavy Arm at 14 ATK, +1; after a transformation that raises ATK, the next one locks in more.
- **Attack speed** (Quick Draw, Quick Glow): the built ATSP is a bonus in points (+10 is 10% faster), not a rate, so "10% of her attack speed" reads as **10% of 100 + ATSP**: Maren at 10 ATSP locks in +11, Vell at 0 locks in +10. Proposed; the design's "+1.5 at 15" assumed a rate.
- **State:** `RunState.Hero.upgrades` lists a stacking card once per take, and `RunState.Hero.locked` (upgrade id -> its locked amounts, in order) keeps the amounts; the save's version goes up to 3 (as 6a did, old saves don't load: the upgrade ids change).

### 15.5 Taste cards once the hero transforms (7a; Question Y)

The transformation replaces the taste's piece (Steady becomes Planted, Mend becomes Night Lantern or Weave or Sunfall), so a taste card's mod would land on the wrong ability or nothing. Proposed: **each taste card carries on after the transformation, as a `transformed_mod` that does the same job for the transformed kit**, as the built vow picks did. Those whose piece the transformation keeps (Restless, Crowd Sense, Hard to Kill, Steady Flame's mana) keep their mod.

| Path | Taste card | Once transformed |
| --- | --- | --- |
| Deadeye | Steady Hands (Steady after 1s, not 1.5s) | Planted and Sure Aim hold after 1s, not 1.5s |
| | Eyes Up (+5 CRIT while Steady) | +5 CRIT while planted (Sure Aim) |
| Trapper | Second Snare (Snare twice a fight) | Bramble Field: up to 4 snares at once, not 3 |
| | Tight Weave (snares root 0.5s longer) | Bramble Field's snares root 0.5s longer |
| Volley | Quick Split (Split Shot every 3rd shot) | every shot already splits: the split arrow deals 50%, not 40% |
| | Restless (+10% attack speed if she moved in the last 2s) | the same |
| Hearthwall | Broad Guard (Guard takes 15%, not 10%) | Guard takes 35%, not 30% |
| | Wide Guard (was Two Behind; Decision 39: Guard covers every ally within 3 hexes, not only those behind him) | Guard reaches 3 hexes, not 2 |
| Ironbrand | Heavy Brand (Brand's hit is 50%, not 30%) | the Mace's other hits are 50%, not 30% |
| | Crowd Sense (+10% ATK with 2 or more enemies adjacent) | the same |
| Last Watch | Grim Resolve (Unyielding also Shields him 10% of max HP) | Last Rites also Shields him 10% of max HP |
| | Hard to Kill (+20% DEF below 30% HP) | the same |
| Lanternbearer | Bright Kindle (Kindle heals 30% of Mend, not 20%) | Kindle (the spill to allies near her) heals 50% more |
| | Steady Flame (Mend costs 5 less mana) | Night Lantern costs 5 less mana |
| Wardweaver | Thick Thread (Ward Thread's Shield is 40% of the overheal, not 20%) | Weave's Shield is 30% larger |
| | Thread the Hurt (replaced, 15.6) | Weave also Wards its ally for 2s |
| Vigil Keeper | Swift Judgment (every Mend smites, not every 2nd) | Mend comes every 3rd Lantern Glow, not 4th |
| | Burning Judgment (smites deal 50% more) | Mend's smite deals 50% more |

### 15.6 Cards that don't fit the built kits (Question Z)

Four cards do nothing, or the same as what's built, against the kits as phases 4 and 5 tuned them. Proposed replacements, each in its path's spirit and from built pieces:

| Card | Why it doesn't fit | Proposed |
| --- | --- | --- |
| **Thread the Hurt** (Wardweaver taste: "Ward Thread also works on allies above 80% HP") | the built Ward Thread works on anyone Mend overheals; there's no 80% limit to lift | **Thread the Hurt:** Mend also Wards its target for 2s (15% less damage; the transformation's status) |
| **Drawing Hold** (Hearthwall: "his taunts pull enemies 1 hex toward him") | transformed Hearthwall has no taunt (Hearthwall replaces Hold the Line) | **Drawing Wall:** when his wall rises, enemies within 2 hexes of him are pulled 1 hex toward him |
| **Crushing Blow** (Ironbrand: "enemies knocked into other enemies are Stunned for 1s") | every push stopped by a unit already stuns for 1s (phase 1) | **Crushing Blow:** Brand Slam knocks enemies back 2 hexes, not 1 (more of them crash into something) |
| **Lasting Shields** (Wardweaver: "her Shields last until broken") | every Shield already lasts until broken | **Lasting Circle:** Warding Circle lasts 2s longer |

### 15.7 The cards by part

Numbers are `upgrade-pools.md`'s (placeholders); a card's `text` says what it's for, and `ModInfo` adds its amounts as for every card. "Slows 20%" is a new status, **Hobbled** (a 20% Slow, data only), beside the built 30% Slow.

**7a: the built pieces write 48.**
- **Stacking (10):** 15.4's.
- **Hero cards (14):** Maren's Deep Mark (her Marks, `statuses`), Light Step (the built `hop.cooldown_add_ms`), Long Vanish, Parting Shot (a next-hit boost on `on_hop`: a sure crit), First Blood (a next-hit boost at the fight's start: +100%); Brannoc's Long Hold, Stubborn Taunt (`on_status` taunt applies **Cowed**, a new boost status on the enemy: −10% damage for 3s), Deep Hearth, Staggering Bash (`every` 4, Hobbled), Opening Stand (an aura with a 5s window); Vell's Wide Hearth (`radius_add`), Warm Hearth, Deep Well (`per_attack_add`), Ember Glow.
- **Taste cards (7)** whose mods and transformed mods are both built: Steady Hands, Tight Weave, Grim Resolve, Hard to Kill, Steady Flame, Thread the Hurt, Burning Judgment.
- **Path cards (17):** Heart's Refund (`on_kill` `from_signature`, 6b), Tangle (`on_status` root, `enemies_near_named`), Hunter's Opening (`vs` Rooted), Shared Strength (`on_guard`), Drawing Wall, Lasting Wall, Hungry Mace, Crushing Blow, Cleaving Wounds, Final Gift (`on_fall`, Shields by max HP), Rites of Mercy, Long Night, Lasting Circle, Wide Circle, Leaping Smite (a second smite at `enemy_near_target`), Holy Crits (`on_holder_crit`), Searing.

**7b: the small knobs (18 cards).** Each is one more key in a kit mod's `on` entry (or its `mana`), read where the built ones are:

| Knob | What it changes | Cards |
| --- | --- | --- |
| `every_add` | an `every` N effect's N | Quick Split, Swift Judgment (and their transformed mods) |
| `times_add` | how many times a `once` effect runs a fight | Second Snare, Twice Guarded |
| `at` | only the effects aimed at these targets (`enemy_near_target`, `enemies_near_target`, `ally_near_target`) | Heavy Brand, Bright Kindle, Quick Split's transformed mod |
| `max_standing_add` | a snare's most standing at once | Second Snare's transformed mod |
| `value_add` | a passive's aura's value | Eyes Up |
| `overheal_shield_add_bp` | a heal's overheal-to-Shield share | Thick Thread |
| `guard` | Guard's `share_add`, `within_add`, and `covers_all` (every ally in reach, not only those behind; Decision 39) | Broad Guard, Wide Guard (was Two Behind) |
| `add_to_areas` | effects added inside the ability's areas (each unit the area hits), not after it | Seeker's Mark, Harrying Storm, Wide Cleanse |
| `width_add` | a line's width (lines gain a width; 1 hex now) | Wide Sunfall |
| `plant_add_ms` | how long it needs to plant after moving | Quick Plant |
| `prefer` on the signature | 6b's `prefer`, for a signature's own targeting | Brand the Marked |
| `engage.break_free_add_ms` | how long enemies it engages take to break free | Hard to Pass |
| `mana.taken_bp` | the mana it gains from damage taken, times this | Grudge |

**7c: the new conditions and filters (15 cards).**

| Piece | What | Cards |
| --- | --- | --- |
| `vs` on `heal_bp` and `shield_bp` auras | a heal's or Shield's bonus against allies who meet a condition | Urgent Mercy (below 30%), Front Ward |
| `front_most` (a `UnitCondition`) | the standing ally nearest the enemies' edge | Front Ward |
| `within_hexes` (a `UnitCondition`, from the holder) | targets that close | Close Quarters |
| `while: "moved"`, `"within_ms"` (an aura) | on while it moved in the last that long (Steady's opposite) | Restless |
| `while: "crowded"`, `"enemies"`, `"within_hexes"` (an aura) | on while that many enemies are that close | Crowd Sense |
| `holder` on an event effect (a `UnitCondition`) | runs only while its holder meets it | Scar Tissue (with a whole-fight stacking boost of +2 DEF), Bloody Kills |
| `target_was` on an ability's effect | runs only if the ability's target met it as the ability fired | Last-Minute Mercy |
| `beyond_hexes` on `on_holder_crit` | only hits from farther than that | Bleeding Shot |
| `from_split` on `on_kill` | only kills by an effect aimed at an enemy near the target | Glutton's Quiver |
| `once_per_ally` on `on_ally_below_hp` | once for each ally, not once a fight | Vigilant |
| cleanse `count` | removes that many harmful statuses (the newest first) | Cleansing Touch (on her signature's and Mend's heals), Cleansing Weave |
| apply_status `strength_add_bp` | a Mark it applies is that much stronger (`StatusState` carries it; a stronger Mark replaces a weaker one) | Heavy Mark |
| aura target `allies_near` | the other allies within `within_hexes` of the holder | Sanctuary |

**7d: the big pieces (6 cards).** Each is its own code, said here:
- **Chasing Storm** (Volley): a lasting area with `"follows": "largest_group"` moves its center toward the biggest group of enemies within its reach before each pulse, up to 1 hex a pulse; each move is logged (an AREA line noted "moves"), and the board slides the circle.
- **Ricochet** (Volley): a split arrow splits once more, to the enemy nearest the one it hit (not one already hit), at the same share; logged as its own DAMAGE line noted "ricochet".
- **Reflecting Wall** (Hearthwall): a shot his wall stops hits its shooter for half its damage, as a hit from his Hearthwall (a DAMAGE line noted "reflected"; the board's shot flies back).
- **Snag** (Trapper): a leap or a charge that passes over her snare springs it, and the leaper is rooted where it lands.
- **Guarded Ground** (Trapper): at the fight's start, a snare under the front-most ally (`front_most`, 7c), counted against Bramble Field's 3.
- **First Lantern** (Lanternbearer): you place her first Night Lantern before the fight, like transformed Trapper's snares (`UnitSetup.lantern`, a marker dragged on the board, kept in the session and the run); it's lit at 0s and its mana is spent at 0.

### 15.8 Volley's taste back to every 4th (7a)

`paths.json`: vowed Volley's Split Shot goes from every 6th shot to every 4th (`upgrade-pools.md`, the playtester's 2026-09-30 decision), and its texts say so. Phase 4 had set every 6th to hold the vow within its Decision 3 cap (5 points over base); the paths report (`--paths`) measures it again, and the number goes in the built notes for step 9's retune, not fixed here. The bench and the sim runner's gate use no vowed Volley, so their numbers don't move.

### 15.9 The UI

- **The pick's cards** say their layer under the name ("Maren · Taste: Deadeye"), and a stacking card says what it would lock in now ("+2 ATK now"; `ModInfo`).
- **The hero panel's upgrades** list a stacking card once, with how many times and each locked amount ("Honed Tips ×3: +2, +3, +5 ATK"; `ui-new-systems.md`, section 4), and a taste card says which mod it's using.
- First Lantern's marker in placement (7d). Nothing else on the board is new beyond 7d's moving circle and returning shot.

### 15.10 Files, tests, the bot, and the report

- **Changed:** `upgrade_def.gd` (layers, `stacks`, no `vow`), `data/upgrades.json` (99: 36 hero, 18 taste, 45 path), `data/statuses.json` (Hobbled, Cowed, the boosts), `data/paths.json` (Volley), `run_content.gd` (`upgrades_for` by stage and what changes something, the locked mods), `run_state.gd`/`run_save.gd` (`locked`, version 3), `run_flow.gd` (`take_pick` locks in), `offers.gd`; the sim pieces in 15.7 (`kit_mod.gd`, `effect_def.gd`, `aura_def.gd`, `unit_condition.gd`, `shape_def.gd`, `passives.gd`, `events.gd`, `effect_runner.gd`, `targeting.gd`, `statuses.gd`, `guards.gd`, `engage.gd`, `snares.gd`, `walls.gd`, `areas.gd`, `shots.gd`, `fight_setup.gd`, `unit_setup.gd`); `mod_info.gd`, `hero_panel.gd`, `run_day_screen.gd` (the pick), the arena (7d's board forms, First Lantern's marker), `practice_session.gd`/`run_session.gd` (the lantern's hex); `tools/run_bot.gd` (takes as now), `tools/run_report.gd` (picks per layer, stacking locks per run).
- **Tests:** `tests/run/test_upgrade_pools.gd` (new: the draw by stage, taste cards only while vowed, path cards once transformed, Switch vow, a dead card never offered, a stacking card's lock-in from the stat now and at least 1, ATSP's, a lock never recalculating after a transformation, a taste card's transformed mod, the save); `tests/sim/test_upgrade_pieces.gd` (new: each 7b–7d piece in a small fight); every card builds on every kit it can meet and changes it (a data test over all 99); `test_mod_info` and the upgrade lists changed on purpose; determinism, the log audit, every encounter on the screen (no new log kinds: 7d's lines are notes on AREA and DAMAGE), the bench's fingerprints unchanged; the run report runs.

### 15.11 Questions (answered in 15.12)

- **Y. Taste cards after the transformation:** carry on with a transformed mod that does the same job (15.5's table), or end when the hero transforms?
- **Z. The four cards that don't fit** (15.6): use the proposed replacements?
- **AA. Cards that would change nothing on the hero's kit now:** never offered (a held one stays held), or offered anyway, as items are?
- **AB. The design's open questions** (15.3): keep the pick's shape, every card equally likely, stacking without a cap, and retune in step 9?
- And: **approve this section, split as 15.2** (7a–7d, a commit each)?

### 15.12 Decisions (the playtester, 2026-10-01)

34. **Step 7 is built as this section says, in four parts** (the approval): 7a the frame and the 48 cards the built pieces write, 7b the small knobs, 7c the new conditions and filters, 7d the six big pieces.
35. **Taste cards carry on after the transformation** (Question Y), each with a transformed mod that does the same job (15.5's table).
36. **The four cards that don't fit are replaced** (Question Z): Thread the Hurt (Mend also Wards its target for 2s), Drawing Wall, Crushing Blow (Brand Slam knocks back 2 hexes), and Lasting Circle (15.6).
37. **The pick never offers a card that changes nothing on the hero's kit as it is now** (Question AA); a held one stays held.
38. **The pick keeps its shape** (Question AB): one card per hero and the wild card, every card a hero can be offered equally likely, stacking cards without a cap; the run report counts each layer's picks, and step 9 retunes.
39. **Two Behind becomes Wide Guard** (asked while building 7b, 2026-10-01): vowed Hearthwall's Guard already covers every ally behind him within 3 hexes, so "covers the 2 allies behind him" would change nothing. Wide Guard: Guard covers every ally within 3 hexes, not only those behind him; once transformed, Guard reaches 3 hexes, not 2.

### 15.13 Built in step 7a (2026-10-01)

- **The layers** (`UpgradeDef.layer`: hero, taste, path; `"taste": true`, no `vow`): `RunContent.upgrades_for` offers a hero's own cards always, its vowed path's taste cards until it transforms, and its path's cards (its growing one too) once it has. A taste card carries on after with its `transformed_mod` (Decision 35); a taste or path card counts only while its hero is on that path.
- **Cards that change nothing** (Decision 37): `RunContent.changes_something` is the mod touching the kit as it is now (`KitMod.affects_besides_passives`), an added passive that can fire there (one waiting `on_status` on statuses the kit never applies, or `on_hop` without the hop, can't), or a growing card that can count there (its abilities, and for Marks the keyword among the statuses the kit applies). The data check now asks a hero card to change at least one of its hero's kits (a taste card both of its kits, a path card the transformed one).
- **Stacking** (section 15.4): `"stacks": {"stat", "pct"}`; `RunContent.stack_amount` reads the stat from the hero's kit at its stage with its upgrades' mods, rounds half up, at least 1 (ATSP's share of 100 + ATSP); `RunFlow.take_pick` stores it in `RunState.Hero.locked`, and `upgrade_mods` gives a flat `stats_add` per take. The save is version 3; an older one doesn't load.
- **The cards:** 60 (48 new, the 12 growing ones kept, phase 5's 36 cut). New statuses: Hobbled (a 20% Slow), Cowed (−10% damage for 3s, a boost on the enemy), and two next-hit boosts, Parting Shot and First Blood.
- **Where the built pieces fell short, and what was added:**
  - **Durations named:** Marking Shot's Mark (4s) and Hold the Line's and Last Rites' Taunts (3s) now name their status's own duration in the data, so "lasts longer" cards (Deep Mark, Long Hold) can see them. No fight changes.
  - **A share of max HP counts as changed:** `KitMod`'s check now sees a power bonus on a heal or Shield by a share of max HP (Warm Hearth on Hearthlight).
  - **Crushing Blow's 2 hexes:** a mod's `amount_bp` now scales a knockback's or pull's `hexes` when its `types` names that type (`AbilityChange.moves`), so a mod on every effect never moves a push. It's the one new rule in code in 7a.
- **Volley's taste** goes back to every 4th shot (`paths.json`, its texts; `test_path_kits` changed on purpose). **The paths report** (`--paths --seeds=1 --sweep=20`): vowed Volley wins **10 points more than base** over every encounter, "too strong" against Decision 3's cap of 5 (it was +6 at every 6th in phase 4; the damage rule and the retunes have moved fights since); transformed Volley +13. Left for step 9's retune, as 15.8 says.
- **The UI:** the pick's cards say "TASTE · DEADEYE" or "PATH · DEADEYE" (taste cards wear the vow frame), and a stacking card what it would lock in now ("+2 ATK now · stacks"); the hero panel lists a stacking card once with each amount ("Honed Tips ×2: +2, +2 ATK").
- **Tests:** `tests/run/test_upgrade_pools.gd` (8: the pools by stage and Switch vow, cards that change nothing never offered and a held one kept, the lock-in from the stat now with ATSP's and the rounding, a lock unchanged by a transformation, at least 1, the save, the card labels, Crushing Blow's knockback); `tests/sim/test_upgrade_cards.gd` (5: First Blood, Parting Shot, Stubborn Taunt's Cowed, Staggering Bash's Hobbled, and a taste card's transformed mod on its new piece); `test_growth`'s upgrade tests rewritten for the layers (picks running out now use a one-card pool, since stacking cards never run out); the status lists, `test_path_kits`, and the run report's test changed on purpose. 857 tests pass; the data validates; the bench's 24 fingerprints are unchanged.
- **What moved:** no fight the bench or the gate fights (vowed Volley's every 4th moves fights with vowed Volley, on purpose). **The run report** (54 runs): **92% of runs won** (90% after step 6). Picks per run by layer: hero 6.9, taste 0.2, path 1.1; stacking cards taken 2.7 a run, 15.2 points each (mostly HP). Taste cards are rare for now: only 7 of the 18 are in the data until 7b and 7c.

### 15.14 Built in step 7b (2026-10-01)

- **The knobs** (`KitMod`, its header lists them): per "on" entry `at`, `every_add`, `times_add`, `max_standing_add`, `overheal_shield_add_bp`, `width_add`, `add_to_areas`, `value_add`, `guard` (`share_add`, `within_add`, `covers_all`), and `prefer` (a signature's); at the top `plant_add_ms`, `engage.break_free_add_ms`, and `mana.taken_bp`. Each is skipped by a kit no mod touches, so no built fight changed.
- **What they reach in the sim:** a "once" effect now runs `times` a fight (on an interval, on an ally below, and on events; `times_add` raises it; Second Snare, Twice Guarded); `UnitDef.break_free_add_ticks` (read by `Engage` from the engager), `ManaDef.taken_bp` (read by `Mana.on_damage_taken`), `AbilityDef.prefer` (`Targeting.pick` runs a signature's rule over the enemies in reach that meet it, if any; `Signatures.pick_target`), and `ShapeDef.width` (a line's; `ArenaPlane.in_line` takes a half width; logged "line 4 2" and drawn that wide by `FightFx`).
- **The cards:** 18, as 15.7's table, with **Two Behind as Wide Guard** (Decision 39, asked while building: vowed Hearthwall's Guard already covers every ally behind him). Heavy Brand's "50%, not 30%" is a power bonus of +67% on Brand's hit (the damage rule's kind for a kit mod, Decision 6), and Bright Kindle's +50% on Kindle's. Wide Cleanse clears Slow, Hobbled, and Bleed (the built cleanse's `statuses`, at full strength).
- **The cards' words:** `ModInfo` says each knob ("1 step sooner in its count", "+1 time a fight", "+1 standing at once", "+20% of overheal as Shield", "+1 hex wider", "+5% crit chance", "+5% of each hit", "covers every ally in reach, not only those behind", "goes for enemies that are Marked first", "in its area: ...", "plants 0.75s sooner", "enemies it engages take 1s longer to break free", "+50% mana from damage taken").
- **Tests:** `tests/sim/test_upgrade_pieces.gd` (8: `every_add` only where `at` says, `times_add` on an interval and on allies below, the snares and auras, the Guard knobs with an ally beside him, `add_to_areas` and a wider line in a fight, a signature's prefer, Hard to Pass breaking free 1s later, Grudge's mana). 865 tests pass; the data validates; the bench's 24 fingerprints are unchanged.
- **What moved:** no fight without these cards. **The run report** (54 runs): **87% of runs won** (92% after 7a); picks per run by layer: hero 6.4, taste 0.6, path 1.0; stacking cards 2.3 a run.

### 15.15 Built in step 7c (2026-10-01)

- **The pieces** (each skipped by a fight that doesn't use it):
  - **Heal and Shield bonuses on some allies:** `heal_bp` and `shield_bp` auras take `"vs"` (`AuraDef.VS_STATS`), worked out per heal or Shield in `EffectRunner.land` (Urgent Mercy, Front Ward).
  - **`front_most`** (a `UnitCondition`): its side's standing unit farthest toward the other side. `CombatSim.mark_front` sets `UnitState.front_most` each tick, only in a fight where some condition asks (`track_front`, from `UnitDef.uses_front_most`).
  - **A per-hit reach:** an aura's `"vs_within_hexes"` (`AuraDef.hit_range`, checked in `Passives.vs_bonus_bp`): only targets that near its holder (Close Quarters). The plan named it a `UnitCondition`; a condition only sees the unit it's about, not the holder, so it's the aura's.
  - **Auras `"while": "moved"`** (`"within_ms"`, Restless) and **`"crowded"`** (`"enemies"`, `"within_hexes"`, Crowd Sense), and the target **`"allies_near"`** (`"target_within_hexes"`: the other allies that near; Sanctuary). Who's near is part of its condition key, so the aura moves with them.
  - **An event's or timed effect's `"holder"`** (a `UnitCondition` its holder must meet; Scar Tissue, with a new stacking status **Scarred**, +2 DEF a stack for the fight; Bloody Kills).
  - **`on_holder_crit`'s `"beyond_hexes"`** (Bleeding Shot) and **`on_kill`'s `"off_target"`**: a kill by its basic attack on an enemy that isn't its target (a split arrow's; Glutton's Quiver).
  - **`on_heal`'s `"from_ability"` and `"was_below_pct"`** (the heal carries its ability and the HP healed): Cleansing Touch (Mend's, Weave's, and her signature's heals, not Hearthlight's) and **Last-Minute Mercy**, which the plan gave a `target_was` on Mend's effect. Transformed Mend is a passive that picks its own ally, so the check is on the heal, which knows who it healed and from how low.
  - **A cleanse's `"count"`** (`Statuses.cleanse_newest`): ends that many harmful statuses (damage over time, Root, Stun, Slow, Taunt, Silence, Marked, Grounded), the newest first (`StatusState.applied_at`).
  - **A stronger Mark:** apply_status's `strength_add_bp` and the kit mod knob of the same name (`StatusState.strength_add_bp`; the strongest applied holds; `Statuses.damage_taken_bp` adds it). Heavy Mark makes her Marks 20%.
  - **Vigilant needed nothing new:** a built `on_ally_below_hp` without `once` already runs once for each ally.
- **The cards:** 15, as 15.7's table. **Words:** `UnitInfo` says each ("for 2s after it moves", "while 2 or more enemies are within 1 hex", "for the other allies within 1 hex", "on targets within 1 hex", "while it's below 30% HP", "from more than 5 hexes away", "of an enemy it wasn't aiming at", "from Mend", "on an ally below 30% HP", "removes its newest harmful status"; 7b's Twice Guarded now reads "for the first 2 allies").
- **Tests:** `tests/sim/test_upgrade_conditions.gd` (10, one per piece on its card); the status lists changed on purpose (Scarred). 875 tests pass; the data validates; the bench's 24 fingerprints are unchanged.
- **What moved:** no fight without these cards. **The run report** (54 runs): **83% of runs won** (87% after 7b); picks per run by layer: hero 6.0, taste 0.7, path 1.2.

### 15.16 Built in step 7d (2026-10-01)

- **Chasing Storm** (`EffectDef.follows`, a kit mod's `"follows": "largest_group"`): before each pulse after the first, a following zone's center moves up to 1 hex toward the biggest group of its caster's enemies (`Targeting.pick`'s largest_group, anywhere on the board); that pulse's AREA_LANDED is noted "moved", and the board draws the zone where it now is (it reads the sim's zones).
- **Ricochet** (`EffectDef.ricochet`, `ricochet_add` with `"at": ["enemy_near_target"]`): after the split arrow lands, it hits again at the standing enemy nearest the one it hit (within its reach, never one already hit, the target included), with the same numbers; a DAMAGE line noted "ricochet" (`EffectRunner._ricochet`). It doesn't set off the ability's on-hit effects.
- **Reflecting Wall** (`EffectDef.reflect_bp` on a wall, `Walls.Wall.reflect_bp`): a shot the wall stops still fizzles, and each of its damage effects goes back at the shooter at half, as a hit from the wall (sourced to Brannoc's Hearthwall; a DAMAGE line noted "reflected"). The board shows it as the number on the shooter; a shot flying back isn't drawn (the plan's "the board's shot flies back").
- **Snag** (`EffectDef.snags`, `"snags": true`): a leap or a charge whose way passes within a snare's reach springs it on the leaper once it lands (`Snares.snag`, from `Displacement.leap` and `charge`).
- **Guarded Ground** (a snare effect's `"under": "front_ally"`): at the fight's start, one of her placed snares (Bramble Field's kind, so it counts toward its 3) under her side's front-most standing unit (`Snares.under_front`, `CombatSim.front_of`).
- **First Lantern** (a kit mod's `"places_lantern": true`, `UnitDef.placed_lantern`, `placed_markers`): the player places a lantern marker before the fight, by the snares' rules (own half or the middle row, not a rock; `FightSetup.validate`), kept with the snares in the session and passed to `RunFlow.fight_setup`; `UnitSetup.lantern`. At the fight's start her signature's zone is cast there (`Areas.cast`'s `at`; its ZONE is logged before the first tick) and her bar starts empty. The board draws it as a gold ring (`ArenaView.draw_lantern`), dragged like a snare. The simple bot never places markers, so First Lantern does nothing in its runs.
- **The cards:** 6; the pool is whole: **99** (36 hero, 18 taste, 45 path). **Words:** `ModInfo` and `UnitInfo` say each.
- **Tests:** `tests/sim/test_upgrade_big_pieces.gd` (8: each piece in a small fight, the run carrying the lantern, and the board's lantern marker). 883 tests pass; the data validates; the bench's 24 fingerprints are unchanged.
- **What moved:** no fight without these cards. **The run report** (54 runs): **81% of runs won** (83% after 7c, 90% after step 6); picks per run by layer: hero 5.9, taste 0.7, path 1.2; stacking cards 1.7 a run, 17.4 points each.

**Step 7 is built.** The after-fight pick offers each hero its own 12 cards, its vowed path's two taste cards until it transforms (and they carry on after), and its path's four cards and growing card once transformed; stacking cards lock in a share of the stat; nothing that changes nothing is offered. Runs are won less often as the pools fill (92% after 7a to 81%): the simple bot takes a card for whichever hero has the fewest, and the new cards are more often conditional (taunts, Marks, low HP, crowds) than the flat bonuses they replaced. The numbers are placeholders for step 9's retune.

## 16. Step 8: the new day

Status: **approved (2026-10-01, Decisions 40–43); building in three parts: 8a built (16.12), 8b and 8c next.** Builds `days-and-nodes.md` (a day is the fight, the pick, the shop, then a node), the Magpie as a node (`magpie.md`), Rift Tear's three depths with the rift modifiers (`enemy-growth.md`, section 4), the Shrine's offerings, and the Event node with its scenes and the Bloodied Oath (`events.md`).

### 16.1 What's there now (phase 5)

- **A day** (`RunFlow`, `RunState.Phase`: CAMP, ROUTE, LOADOUT, AFTER): camp first (a place drawn from `camps.json`, 3 of its menu's options, one taken), then the route (today's two fights), the loadout, the fight, then after it (transformations, the pick, a relic choice). A loss replays the day from camp.
- **Camp's options:** Train, Hunt, Pedlar, Rest, Scout, Map the Rift, Fortify, Dig In, Rift Tear (one flat Shield on the next fight's enemies; a win offers 2 rares), and the Shrine (one rare for 15 shards). On one drawn day (`magpie_days` 3–6) the Magpie is the camp's only option. The boss day's camp always has the Pedlar, as the pre-boss shop.
- **No Event node**, no Bloodied Oath, no rift modifiers.

### 16.2 Why it's split

| Part | What |
| --- | --- |
| **8a** | **The day's new order and the nodes:** the fight, the pick, the shop (the Pedlar every day; the pre-boss shop the day before the boss), then a node: Camp (a place and its options), Rift Tear (as built, until 8b), or the Magpie (from day 3, at most twice an act). The Pedlar, Rift Tear, and the Magpie leave camp's menus. The day screen, the act map, the bot, and the report follow. |
| **8b** | **Rift Tear's depths and the rift modifiers, and the Shrine's offerings.** |
| **8c** | **The Event node:** the eight scenes and the Bloodied Oath. |

Each is a commit with the suite green and the bench's fingerprints unchanged (only 8b adds sim pieces, each skipped by a fight that doesn't use it).

### 16.3 The day (8a)

```
Day N:  choose the fight (1 of 2) → loadout and placement → the fight
        → won: transformations, the pick, a relic choice (elite, Rift Tear)
        → the shop (the Pedlar)
        → choose a node, and do it
Day N+1
```

- **Phases** (`RunState.Phase`): ROUTE, LOADOUT, AFTER (the pick and relic choices), SHOP, NODES (choosing), NODE (in one: camp's options, a depth, an event, the Magpie's stall), ENDED. CAMP goes. The save's version goes up to 4.
- **Day 1 starts at the route**; there's no node before the first fight.
- **The shop** opens itself after the after-fight choices: the Pedlar's wares, its relic, rerolls, selling, treating wounds, as built. **The pre-boss shop** is the shop of the day before the boss (its legendary first, rerolls from 5), since that's the shop before the boss fight.
- **The boss day** is the fight and the boss relic choice; the run ends (no shop, no node).
- **A lost fight** replays the day from the route (the same two fights); no shop or node in between. What the last node set up for that fight (Fortify, Dig In's rock, a Rift Tear) **holds for the replay** (Question AE); it's spent once the day's fight is won.
- **A node's effect is now or for tomorrow's fight:** Rest, Train, Hunt, the Shrine, an event, and the Magpie now; Fortify, Dig In, Scout, Map the Rift, and Rift Tear for tomorrow (as built, since tomorrow's fight is the next one fought).

### 16.4 The nodes (8a, 8c)

- **Each day shows 3 nodes** (Decision 41): **Camp always**, and 2 each drawn from **Event** (from 8c), **Rift Tear**, and **the Magpie** (only from day 3, at most twice an act), each equally likely, on the node stream (`RunRandom.NODE`, by act and day); a second Rift Tear or Magpie is an Event instead, so two Events can show. Until 8c, with no Event, the two are Rift Tear and the Magpie when he can come, else Rift Tear alone (2 nodes).
- **Camp:** a place drawn as now, its menu's options (3 shown), one taken. The menus lose Pedlar, Rift Tear, and the Magpie (`camps.json`); Rift Scar's menu takes Rest and Scout in their place. Hunt pays 5 (`act1.json`, as built; economy.md leaves it open).
- **The Magpie:** his stall as built (14.16). `magpie_day` goes; `RunState.magpie_visits` counts.
- **Rift Tear:** as built until 8b.

### 16.5 Rift Tear's depths (8b)

Choosing Rift Tear asks for a depth; tomorrow's fight carries it, and winning that fight offers its relic choice:

| Depth | Tomorrow's enemies | Win it for |
| --- | --- | --- |
| Shallow | each starts with a Shield of 10% of its max HP | 2 rares |
| Deep | that, and one rift modifier | 2 epics |
| Abyssal | that, and two different rift modifiers | 1 legendary and 1 epic |

The modifiers are drawn as the depth is chosen (the node stream), shown on the route's card for tomorrow, and kept in `RunState.rift` (depth and modifier ids). **The ten modifiers** (`camps.json` `rift_modifiers`, each a kit mod on every enemy and summon kit, or a rule):

| Modifier | As data | New in code |
| --- | --- | --- |
| Hastened (+20% attack speed) | `stats_add` atsp 20 | — |
| Hardened (+20% DEF) | `stats_bp` def | — |
| Rift-Charged (start with 50% mana) | `mana.start_bp` | — |
| Bloodthirst (10% lifesteal) | an aura, `lifesteal_bp` | — |
| Thornskin (send 10% of damage taken back) | `on_hit_taken` damage, `amount_bp_of_damage` at the attacker | — |
| Nightfall (hidden the first 3s) | `on_fight_start` Stealth 3s | — |
| Blood Frenzy (+5% ATK for each that falls, stacking) | `on_fall` a stacking whole-fight boost on its allies (a new status) | — |
| Blight (heroes' healing taken −25%) | a kit mod on the **heroes** (`healing_taken_bp`) | the run applies it to heroes |
| Early Collapse (shrinks from 30s) | — | `FightSetup.collapse_start_ticks` (0: tuning's) |
| Reinforcements (at 15s, 2 more of a kind already in the fight join from the edge) | a summon effect at the edges | `FightSetup.rift_effects`: effects at a time, sourced to the Rift Tear (like a relic's start effects, the enemies' side); the kind is the encounter's first non-elite enemy, as its summon kit |

### 16.6 The Shrine's offerings (8b)

The Shrine (a camp option) offers a relic for an offering, one of: **a wound** on a hero you choose (not one at 3), for a rare; **15 shards**, for a rare; **a relic you own** (not a boss or bond relic), for a relic one tier higher (never boss; a legendary has nothing higher, so it isn't offered). Each draws one relic as you choose it (`RunFlow.shrine_offer(kind, hero_id or relic_id)`); you take it or keep your offering (nothing is spent until you take it).

### 16.7 Events (8c)

`data/events.json` (new, `EventDef`): each scene has a text and choices; each choice has a label, a text, and its **results**, a small set of named run actions (code in `RunFlow`, said here, like camp's options), some needing a hero, an item, or a relic you pick. **Every scene has a free "Walk away"** (events rule 1).

| Scene | Choices and their results |
| --- | --- |
| The Kneeling Knight | Take his blade: a random charm at rank II, and a wound on a hero you choose. Bury him: every wound cleared |
| The Rift Merchant | Take a relic: a random epic, and the next shop's wares and relic cost 50% more. Leave coin: pay 10 for a random rare |
| Whispering Stones | Listen: a hero you choose gains deed progress (Question AF), and has no signature next fight. Smash them: +8 shards |
| A Bleeding Tear | Reach in: a random relic of a random tier (common to legendary, by the shops' odds). Seal it: tomorrow's fight is skipped as a win at half pay, with its pick (no deeds, no ranks); not drawn when tomorrow is an elite or the boss |
| The Old Well | Drink: a random item you own a rank up (one below III), and a random hero −10% max HP for the rest of the act. Throw in a coin (5): an item you choose ranks up now |
| Carrion Birds | Drive them off: fight a Hunt's pack now (a Hunt: shards on a win, a loss isn't one). Let them feed: nothing |
| The Mirror Pool | Look in: a hero you choose (not transformed) switches its vow, keeping half its deed progress on the new path. Look away: nothing |
| Ashes of a Band | Search the ashes: 2 random items (charms, tactics, or sigils). Say their names: every wound cleared, and +5% max HP next fight |

A choice that can't be done (no shards, no item, no hero it fits) is shown greyed. **The pieces they need** (run-level, no sim change): an act-long max HP cut (`RunState.Hero.weakened_bp`, applied like wounds), "no signature next fight" and "+5% max HP next fight" (kit mods for tomorrow's fight, `RunState.Hero.next_fight`), "the next shop costs 50% more" (`RunState.dear_shop`), a skipped fight, and an item ranked up at once.

**The Bloodied Oath** (an Event node that's an oath, Question AF): 2 oaths, each already on a random hero (2 different heroes); take one or pass. Its burden and reward last the hero's next **2 day fights** (won or lost; Hunts don't count), kept in `RunState.Hero.oath` (id, fights left):

| Oath | Burden | Reward |
| --- | --- | --- |
| Blood | −25% max HP | its deed progress ×2 |
| Silence | no signature (a kit mod, `drops_signature`, new: the kit's signature and mana go) | deed ×2, +20% ATK and MGK |
| the Vanguard | must stand on the front row (a placement rule in `RunFlow.fight_setup`), and its tactic is set aside | deed ×2, +20 DEF |
| Blood Price | a fall is 2 wounds | deed ×2 |

### 16.8 The UI

- **The day screen** follows the phases: the route, the loadout, after the fight, **the shop** (the Pedlar's stage as built, now with Leave), **the nodes** (three cards: Camp names its place; Rift Tear and the Magpie), and **in a node** (camp's options as built; a depth's three cards with their modifiers; the Magpie's stall as built; an event's scene and its choices, with a hero, item, or relic chooser where a choice needs one).
- **The act map** marks each past day's node (its icon), and the route's card for tomorrow names a Rift Tear's depth and modifiers.
- **The hero bar** shows an oath's burden and fights left.

### 16.9 Files, tests, the bot, and the report

- **Changed:** `run_state.gd`/`run_save.gd` (the phases, `node`, `nodes`, `magpie_visits`, `rift`, `oath`, `next_fight`, `weakened_bp`, `dear_shop`; version 4), `run_flow.gd` (the order; `choose_node`, `leave_node`, `close_shop`/`leave_shop`, `choose_depth`, `shrine_offer`, `choose_event`), `offers.gd` (nodes, depths' modifiers, events, oaths), `act_def.gd`/`data/act1.json`, `camps_def.gd`/`data/camps.json` (menus, depths, modifiers), `event_def.gd` and `data/events.json` (new), `run_content.gd`; the sim pieces in 16.5 and `drops_signature` (`fight_setup.gd`, `combat_sim.gd`, `kit_mod.gd`); `run_day_screen.gd`, `act_map.gd`, `hero_bar.gd`, `run_session.gd`; `tools/run_bot.gd` (takes the shop as now, then Camp, and in camp its options as now; a Rift Tear at Shallow when it's shown and the team is healthy; an event's first choice it can do; an oath never), `tools/run_report.gd` (nodes taken, depths, events and choices, oaths).
- **Tests:** `tests/run/test_new_day.gd` (the order, day 1, the shop every day and the pre-boss shop, the boss day, a loss replaying with the node's setup kept, the node draw: Camp always, the Magpie from day 3 and at most twice, the save), `tests/run/test_rift_tear.gd` (depths, modifiers drawn and applied, each pays its choice; Early Collapse and Reinforcements in a fight), `tests/run/test_shrine.gd`, `tests/run/test_events.gd` (every scene's every choice, greyed ones, Walk away; each oath's burden, reward, and end); `test_camp.gd`, `test_economy.gd`, `test_magpie.gd`, `test_run_screens.gd`, and the run report's test changed on purpose; the bench's fingerprints unchanged; the run report runs.

### 16.10 Questions (answered in 16.11)

- **AC. Approve this section, split as 16.2** (8a–8c, a commit each)?
- **AD. The nodes a day shows** (`days-and-nodes.md` leaves 2 or 3 open): Camp always plus 2 drawn from Event, Rift Tear, and the Magpie (from day 3, at most twice), each equally likely?
- **AE. A lost fight's replay:** what the last node set up for it (Fortify, Dig In, a Rift Tear's depth and modifiers) holds for the replay, or is spent by the loss?
- **AF. The events' open questions:** an Event node is a Bloodied Oath 1 time in 4; Whispering Stones gives a third of the vowed path's deed threshold (never past it); the Mirror Pool can't take a transformed hero; A Bleeding Tear's seal isn't offered when tomorrow is an elite or the boss?

### 16.11 Decisions (the playtester, 2026-10-01)

40. **Step 8 is built as this section says, in three parts** (Question AC): 8a the day's new order and the nodes, 8b Rift Tear's depths, the rift modifiers, and the Shrine's offerings, 8c the Event node and the Bloodied Oath.
41. **Each day shows Camp and two more nodes** (Question AD): each of the two is drawn from Event, Rift Tear, and the Magpie (he only from day 3, at most twice an act), so a day can show two Events (two different scenes, or a scene and an oath). A second Rift Tear or Magpie in one day is drawn as an Event instead, since the same node twice would be no choice.
42. **What a node set up for tomorrow's fight holds for its replay** (Question AE): Fortify, Dig In's rock, and a Rift Tear's depth and modifiers stay through a lost fight's replay and are spent once the fight is won.
43. **The events' open questions** (Question AF): an Event node is a Bloodied Oath 1 time in 4; Whispering Stones gives a third of the vowed path's deed threshold, never past it; the Mirror Pool can't take a transformed hero; A Bleeding Tear's seal isn't offered when tomorrow is an elite or the boss.

### 16.12 Built in step 8a (2026-10-01)

- **The phases** (`RunState.Phase`): ROUTE, LOADOUT, AFTER, SHOP, NODES, NODE, ENDED; CAMP is gone, and the save is version 4. `RunState` keeps `nodes` (today's), `node` (the one taken), `taken_nodes` (each day's, "camp:<place>", "rift_tear", or "magpie", for the act map), and `magpie_visits`; `magpie_day` is gone.
- **The order** (`RunFlow`): a day starts at the route (`_start_day`), day 1 included. `finish_day` moves on from after the fight to the Pedlar (`open_shop("pedlar")`), or on the boss's day ends the run; `leave_shop` draws the nodes (`Offers.nodes`); `choose_node` takes one (Camp draws its place and options with `Offers.camp`, as built; Rift Tear sets `rift_tear`; the Magpie opens his stall and counts the visit); `leave_node` waits for what the node opened (a pick, a relic choice, a Hunt, Map the Rift's swap), keeps the node in `taken_nodes`, and starts the next day. `choose_camp` works only in a Camp node; `leave_camp` is gone. **The pre-boss shop** is the Pedlar of the day before the boss's (`pre_boss_shop`).
- **A loss** replays the day from the route; Fortify, Dig In's rock, a Rift Tear, and a steadying Rest hold until the day's fight is won (Decision 42).
- **The nodes** (`Offers.nodes`, on `RunRandom.NODE` by act and day): Camp, then two draws from Rift Tear and the Magpie (he from `magpie_from_day` 3 while `magpie_visits` < `magpie_per_act` 2); a repeat is skipped until 8c's Events, so a day shows 2 or 3. `camps.json`'s `nodes` name each (name, icon, text; `CampsDef.nodes`), and the Pedlar, Rift Tear, and the Magpie left the options and menus (Rift Scar's takes Rest and Scout).
- **The screens:** the day screen's shop (the Pedlar's stage, then Leave the Pedlar), the nodes (a card each, "Go to Camp"), and a node (camp's options, the Magpie's stall, or the Rift Tear taken; then "On to day N"); after the fight's button reads "To the Pedlar". The act map shows each past day's node (`taken_nodes`) and today's once taken. `HOW-TO-PLAY.txt` follows.
- **The bot** takes the Pedlar's wares as before, then the Magpie when he's shown, else Camp (and its options as before, without the Pedlar, the Magpie, and Rift Tear). **The run report** counts the nodes shown and taken.
- **Tests:** `tests/run/test_new_day.gd` (6: the Pedlar after every fight and the pre-boss shop, the boss's day, a node waiting for what it opened, a loss replaying with Fortify and a Rift Tear held, the node draw, the Magpie's visits, the save), with `tests/run/run_test_kit.gd` to drive a day; the run, camp, economy, growth, loadout, Magpie, relic, screen, and art tests follow the new order on purpose.
- **Checked:** 889 tests pass; the data validates; the bench's 24 fingerprints are unchanged (no fight changed). **The run report** (54 runs): **81% of runs won** (as after 7d); a run is shown Camp 5.4 times, Rift Tear 4.8, and the Magpie 1.7, and the bot takes Camp 3.6 and the Magpie 1.7 (never Rift Tear); 86.1 shards earned and 70.3 spent a run (the Pedlar every day: 57.8 spent after step 6), 3.5 relics.

## Answered (2026-09-30)

- **A. Casters first's +20%:** power (Decision 5).
- **B. Walkers and crumbled ground:** avoid it when they can (Decision 7).
- **C. The collapse's damage:** starts at 15 and grows as now (Decision 8).
- **D. Kit mods on an ability's amount:** power (Decision 6).
