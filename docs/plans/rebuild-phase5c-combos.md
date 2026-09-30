# Rebuild phase 5c: combos, the pools, and the new day

Status: **step 1 built (2026-09-30): the damage rule, walkable crumbled ground, and the Act 1 retune; steps 2–9 outlined, each waiting for its full section and approval.** Builds part 7 (`rebuild-combos.md`) and the plans agreed with it on 2026-09-30: the relic pool (`relics/`), the loadout pool (`loadout/`), the Magpie (`magpie.md`), the upgrade pools (`upgrade-pools.md`), duo bonds as keys to bond relics (`duo-bonds.md`), the economy (`economy.md`), the new day and its nodes (`days-and-nodes.md`), events (`events.md`), rift modifiers (`enemy-growth.md`, section 4), and what the UI must show for them (`ui-new-systems.md`). It comes before phase 6 (the good bot and tuning), starting with the damage rule (`rebuild-build-order.md`).

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
| **2. Stat amounts** | Every card's stat change says its amount (part 7, section 6): a numbers line generated from the mod, like abilities' (`UnitInfo`), on items, upgrades, and relics; their `text` loses vague words | `src/ui/unit_info.gd`, a `ModInfo` for kit mods, `data/*.json` texts | every card with a stat mod shows its amount |
| **3. Keywords and triggers** | Keyword flag on `StatusDef` (Marked, Rooted, Burning, Shielded, Stealthed; Bleeding joins with its sources); the new triggers (`on_crit`, `on_kill`, `on_apply`, `on_hit_keyword`, `on_shield_broken`, `on_ally_signature`, `on_heal`, `on_hop`) read from the log in `Events`; the chain guard (8 a tick) | `status_def.gd`, `events.gd`, `passives.gd`, `test_arena_log.gd`'s audit | each trigger, the guard, determinism with long chains, the chaos fight uses them |
| **4. Permanent scaling** | Counters in run state, per hero and per run, fed from `FightResult` like deeds; growing mods take the counter into the fight's setup as a bonus; "Now: +X" on cards | `run_state.gd`, `run_flow.gd`, `HeroExtras` | counters survive a save; a growing card's value |
| **5. The relic pool** | Five tiers plus bond relics, the pool's relics as data (built ones changed or cut, `relics/README.md`), one relic per shop with climbing rerolls, the pre-boss shop, boss relics after the boss, the Shrine's offerings, the income in `economy.md` | `relics.json`, `relic_def.gd`, `offers.gd`, `run_flow.gd`, `act1.json` | shop draws by tier, rerolls' prices, bond relics only with their bond, every relic's effect in a small fight |
| **6. The loadout pool** | Tactics, gambits, sigils, and charms from `loadout/`, three ranks with each kind's counter, a bought copy skips a rank, selling at half, no "no effect" marker, grafts removed; gambits' placement rules (in `FightSetup.validate` and `Encounters.setup`); the Magpie as a node with his stall | `items.json`, `item_def.gd`, `run_flow.gd`, `tactics.gd`, `fight_setup.gd`, `magpie` offers | ranks and their counters, selling, each gambit's placement, the Magpie's stall |
| **7. The upgrade pools** | `upgrade-pools.md`: each hero's 12, two taste upgrades per path until the hero transforms, four path upgrades and a growing one after; stacking stat upgrades locked in as a flat amount; Volley's taste back to every 4th | `upgrades.json`, `offers.gd`, `run_state.gd`, `paths.json` | the draw by stage, stacking's lock-in, the paths report for Volley |
| **8. The new day** | Fight, pick, shop, then a node (Event, Camp, Rift Tear, the Magpie); camp as a node with its options; Rift Tear's three depths with rift modifiers; events and the Bloodied Oath; the day screen follows | `act_def.gd`, `run_flow.gd`, `offers.gd`, `camps.json`, `events.json` (new), `run_day_screen.gd`, `run_bot.gd` | the day's order, each node, each event, the bot plays whole runs |
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

## Answered (2026-09-30)

- **A. Casters first's +20%:** power (Decision 5).
- **B. Walkers and crumbled ground:** avoid it when they can (Decision 7).
- **C. The collapse's damage:** starts at 15 and grows as now (Decision 8).
- **D. Kit mods on an ability's amount:** power (Decision 6).
