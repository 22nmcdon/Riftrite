# Rebuild plan, part 5: build order and what gets gutted

Status: **agreed (2026-09-27). Phase 0 is done; phase 1 is next.** This turns parts 1–4 (`rebuild-heroes.md`, `rebuild-arena.md`, `rebuild-enemies.md`, `rebuild-run.md`) into a build order, and marks everything in the current code that goes. Each phase below gets its own detailed build plan (files, data shape, tests) before code is written, as `CLAUDE.md` asks.

## Principles

- **Find out early whether arena fights are fun.** The first playable goal is a single fight with the three base heroes, before paths, camps, or a run exist.
- **Gut first, on its own.** Removing the old systems is one clean step, so later phases never work around dead code.
- **Keep the foundation.** Determinism, integer math, the combat log, data loading, the effect system, tests, CI, and playtest builds are all worth keeping.
- **Placeholder art until the run works.** The art rehaul starts with a style guide in parallel, but real art goes in late, once the game is known to be fun.
- **A playtest gate after each playable phase.** If a gate fails, fix it before moving on.

---

## Part A: what gets gutted

Three labels: **Remove** (deleted), **Rewrite** (the file or idea stays, the contents are mostly new), **Keep** (stays, with small changes).

### The combat sim (`src/sim/`)

| File(s) | Label | Why |
| --- | --- | --- |
| `infusions.gd`, `effects/conversions.gd`, `state/essence_application.gd` | Remove | Essences are gone |
| `defs/essence_def.gd`, `defs/alloy_def.gd`, `defs/keyword_def.gd`, `defs/modifier_def.gd` | Remove | Essences, alloys, keywords, and item modifiers are gone |
| `defs/item_def.gd`, `defs/loadout_entry.gd`, `defs/legendary_def.gd`, `setup/item_setup.gd`, `state/item_state.gd`, `state/item_aura.gd` | Remove (replaced) | Items are gone. A hero's basic attack, signature, and passive become **abilities** on the hero (a new, smaller `AbilityDef` / `AbilityState`), reusing `EffectDef` |
| `synergies.gd`, `defs/synergy_def.gd` | Rewrite | Only **duo bonds** survive (path + path); pairs, transformations, signatures, resonance, and affinities go |
| `damage_meter.gd` | Remove | Per-item totals; the per-hero fight chart (`FightTally`) replaces it |
| `combat_sim.gd` | Rewrite | The core loop becomes spatial: positions, movement, reservations, pathfinding, areas, knockback, mana, signature triggers, the shrinking arena, summons |
| `effects/targeting.gd` | Rewrite | Row targeting goes; targeting rules become spatial (nearest reachable, weakest back-liner, largest group, farthest hero, lowest HP ally, and so on) |
| `effects/effect_runner.gd`, `defs/effect_def.gd` | Keep (trim) | Remove item targets, charge, spill, and essence fields; add shapes (circle, line, cone, ring), leaps, pulls, charges, knockback, summons |
| `effects/relic_runner.gd`, `defs/relic_def.gd`, `state/relic_state.gd` | Keep (trim) | Relics stay, rarer and with costs; drop item filters and keyword filters |
| `statuses.gd`, `defs/status_def.gd`, `state/status_state.gd` | Keep (trim) | Keep Root, Slow, Stun, Taunt, Engaged, Marked, Bleed, Burn, Poison, Shield, Silence; remove Golden Flame, Plasma, Blight, Blind, and item Slow; add Knockback handling |
| `events.gd` | Keep (trim) | Event triggers stay useful for deeds, passives, and enemies; drop item-specific ones |
| `defs/hero_def.gd` | Rewrite | Stats, movement, range, basic attack, signature and trigger, passive, traits, 3 paths |
| `defs/specialization_def.gd`, `defs/deed_def.gd`, `defs/deed_track_def.gd`, `setup/deed_setup.gd` | Rewrite | Become **paths**: taste, cost, deed, transformation, upgrade pool, apexes. The `Part` kinds (aura, grant, ability, basic_attack, replace_status) are reused |
| `defs/enemy_def.gd`, `defs/encounter_def.gd`, `defs/phase_def.gd` | Keep (extend) | Add targeting rule, signature trigger, traits, threat line, archetype, hand-placed positions, summons |
| `defs/collapse_def.gd` | Rewrite | Rift Collapse becomes the shrinking arena |
| `defs/tuning_def.gd` | Keep (trim) | Remove essence, spill, tier, rank, and slot values; add grid, mana, and collapse values |
| `defs/aura_def.gd`, `defs/aura_filter.gd`, `defs/grant_def.gd` | Keep (trim) | Drop item and keyword filters |
| `defs/unit_stats.gd`, `state/unit_state.gd` | Keep (extend) | Add position, movement, mana, vow and path state |
| `setup/setup_builder.gd`, `setup/unit_setup.gd`, `setup/fight_setup.gd` | Rewrite | Setups carry hex positions and path state instead of rows and loadouts |
| `sim_rng.gd`, `fixed_math.gd`, `data_reader.gd`, `combat_log.gd`, `log_entry.gd`, `fight_result.gd`, `state/effect_source.gd`, `state/sourced_effect.gd`, `state/value_breakdown.gd` | Keep | The foundation. `LogEntry` gains move, push, and area kinds |
| `content_db.gd` | Rewrite | Loads the new data set |

### The run (`src/run/`)

| File(s) | Label | Why |
| --- | --- | --- |
| `run_item.gd`, `run_legendary.gd`, `defs/shop_def.gd`, `defs/economy_def.gd`, `defs/node_def.gd` | Remove | Items, Legendaries, shops, gold, and stop nodes are gone |
| `defs/event_def.gd` | Rewrite | Becomes rift events at camp |
| `run_flow.gd`, `run_actions.gd`, `run_state.gd` | Rewrite | New flow: choose heroes, vow, then days of camp, fight choice, placement, fight, deeds and picks |
| `run_hero.gd` | Rewrite | Vow, path progress, transformation, upgrades, apex |
| `defs/act_def.gd`, `run_content.gd` | Rewrite | Days, fight pairs, elites, boss, camp places |
| `run_fight.gd` | Keep (adapt) | Builds fights from a run and writes deed progress back |
| `run_random.gd`, `run_save.gd` | Keep | Seeded streams and save/resume still apply |
| `run_bot.gd`, `run_report.gd` | Rewrite | A bot that places heroes and picks vows, fights, and camps; new report lines |

### The UI (`src/ui/`)

| File(s) | Label | Why |
| --- | --- | --- |
| `infusion_look.gd`, `item_info.gd`, `widgets/essence_chip.gd`, `widgets/item_tile.gd`, `widgets/offer_view.gd`, `widgets/drop_zone.gd`, `widgets/inspector.gd`, `widgets/damage_meter_view.gd` | Remove | Items, essences, shops, and dragging items |
| `screens/shop_screen.gd`, `screens/stop_choice_screen.gd`, `screens/stop_screen.gd` | Remove | Replaced by a camp screen |
| `widgets/guild_bar.gd`, `widgets/hero_token.gd`, `widgets/hero_sheet.gd` | Rewrite | A team bar and hero sheet showing vows, deeds, paths, and upgrades |
| `screens/fight_screen.gd`, `fight_player.gd`, `fight_fx.gd`, `widgets/unit_card.gd`, `widgets/figure.gd` | Rewrite | A hex board with movement, area warnings, and mana bars |
| `screens/run_start_screen.gd`, `screens/rewards_screen.gd`, `screens/fight_choice_screen.gd` | Rewrite | Hero choice and vows; deed and upgrade picks; fight choice with threats |
| New | Build | A placement screen, a camp screen, vow and transformation popups, a fight sandbox |
| `fight_tally.gd`, `widgets/fight_chart.gd`, `widgets/fight_banners.gd`, `widgets/day_bar.gd`, `widgets/toast.gd`, `widgets/hover_card.gd`, `fight_names.gd`, `encounter_info.gd` | Keep (adapt) | Still useful as they are, with new content |
| `main.gd`, `main.tscn`, `run_session.gd`, `playtest_journal.gd`, `screens/ui_screen.gd`, `screens/title_screen.gd`, `screens/run_end_screen.gd` | Keep (adapt) | The shell, sessions, and playtest journal stay |
| `ui_style.gd`, `widgets/frame_decor.gd`, `widgets/glyph.gd`, `character_art.gd` | Keep as placeholders | Replaced in the art rehaul |

### Data (`data/`)

| File | Label |
| --- | --- |
| `essences.json`, `alloys.json`, `keywords.json`, `items.json`, `economy.json`, `nodes.json` | Remove |
| `synergies.json` | Rewrite (duo bonds only) |
| `specializations.json` | Rewrite (becomes paths, perhaps `paths.json`) |
| `heroes.json` | Rewrite (3 heroes) |
| `enemies.json`, `encounters.json`, `acts.json` | Rewrite |
| `relics.json` | Rewrite (fewer, each with a cost) |
| `events.json` | Rewrite (rift events for camp) |
| `statuses.json`, `tuning.json` | Keep (trim) |
| New | `camps.json` (places and options), `upgrades.json` (hero and role layers, if not inside paths) |

### Art, tools, tests, and docs

| What | Label | Notes |
| --- | --- | --- |
| `art/` (items, relics, characters, chrome, backgrounds, icons) and `tools/art/` | Remove after the rehaul | Placeholders until the new style exists. Item icons can go right away |
| `art/fonts/` | Review | The rehaul may keep or replace them |
| `tools/sim_parties.json`, `tools/balance_run.gd`, `tools/sim_runner.gd`, `tools/run_runner.gd` | Rewrite | Parties become placed heroes on paths; reports change |
| `tools/validate_data.gd`, `tools/ui_screenshots.gd`, `tools/ci/`, `.github/workflows/`, `export_presets.cfg`, `addons/gut/` | Keep | |
| Tests for removed systems (`test_alloys`, `test_essences`, `test_infusions`, `test_slice_alloys`, `test_spread_and_conduits`, `test_item_def`, `test_loadout`, `test_hero_epics`, `test_strikes_and_rows`, `test_damage_meter`, `test_legendary`, `test_item_art`, `test_inspector`, and parts of the rest) | Remove | Written fresh alongside each phase |
| `test_determinism`, `test_sim_rng`, `test_fixed_math`, `sim_test_kit`, `ui_test_kit` | Keep | The determinism tests must keep passing throughout |
| `docs/design.md` | Rewrite | Rebuilt from the rebuild plans |
| `CLAUDE.md` | Rewrite | New rules: heroes and paths, the arena, mana, enemies, the run; the infusion, item, and synergy rules go |
| `docs/tiers-backup-specialization.md`, `docs/ui-asset-design.md`, all earlier `docs/plans/*` | Move to `docs/archive/` | Kept for history, marked as superseded |

---

## Part B: build order

| Phase | What | Done when |
| --- | --- | --- |
| **0. Gut** | New branch. Archive old docs; remove everything marked Remove and its tests and data; stub what's being rewritten; rewrite `design.md` and `CLAUDE.md` from the rebuild plans | The project compiles, the game boots to the title screen, the tests that remain pass |
| **1. Arena sim** | Headless: hex placement, free movement on a plane, blocking, pathfinding, shots in flight, targeting rules, melee and ranged, Engage, taunt, knockback, area shapes and warnings, the slice's statuses, mana and signature triggers, the shrinking arena, summons, full logging | Seeded fights repeat exactly; every move, push, and hit is in the log with its source |
| **2. Base heroes and Act 1 enemies** | Brannoc, Maren, and Vell's base kits; the 9 Act 1 enemies; hand-placed encounters; the sim runner reports on placed parties | The sim runner shows **placement matters**: the same team wins clearly more with a good formation than a bad one against each archetype |
| **3. Fight sandbox (placeholder art)** | Hex board, placement screen, fight playback with movement, area warnings, mana bars, the fight chart and log; a sandbox mode: pick an encounter, place, fight | **Playtest gate 1:** a single arena fight with base heroes is fun and readable |
| **3b. Tactics in Practice** | The first three tactics (part 6): target casters first, hold your hex, and a heal threshold. A targeting override and a movement rule in the sim; Practice lets each hero take one before the fight | Tactics change how a fight plays, readably, in Practice |
| **4. Paths** | Vows, tastes and costs, path deeds, transformations for all 9 paths (in three waves), vow and transformation popups, the sandbox can set a hero's path | **Playtest gate 2:** each path changes where you place the hero and how the fight plays |
| **5. The run (Act 1)** | Hero choice and vows, the hero bar on every screen between fights (it opens phase 4's hero panel), 7 days, fight choice, camps (a first set of options and places), deed progress, after-fight picks and the upgrade pools (path and hero layers), loadout slots and the currency (the Pedlar; the Magpie, with other heroes' gear and grafts), wounds, relics with costs (and the relic choice), the screens in part 6's item language (its section 9, from the playtester's mock), losing, save and resume, the elites, Old Mother Ash, duo bonds, the run end screen | **Playtest gate 3:** a full Act 1 run is playable start to finish |
| **5b. The uploaded art** | The playtester's art on the screens that exist (`rebuild-phase5b-art.md`) | Built (2026-09-30) |
| **5c. Combos (part 7)** | Build plan: `rebuild-phase5c-combos.md`. `rebuild-combos.md` and the relic pool (`relics/`), in this order: **the damage rule first** (every bonus sorted into a kind, one helper), with walkable crumbled ground beside it (both change fights, so Act 1 is retuned once, on both); then stat amounts on every card, keywords and triggers (with the chain guard), permanent scaling, the relic pool (five tiers, a relic in every shop with climbing rerolls, the shop before each boss, boss relics, the new income, the built relics changed or cut), the loadout pool (`loadout/`: tactics, gambits, sigils, and charms with ranks, the built items mapped or cut, grafts cut into charms, selling items at any shop; after keywords and triggers, which most of it is written on), the Magpie as a node (`magpie.md`: rank II charms, a relic at 25% off, selling and swapping relics), the bond relics (`duo-bonds.md`: bonds lose their boosts and unlock a free relic in the shop pool), the upgrade pools (`upgrade-pools.md`: each hero's 12, taste and path upgrades, stacking), the new day (`days-and-nodes.md`: fight, pick, shop, node; Rift Tear's depths, the Shrine's offerings) with its events (`events.md`) and the rift modifiers Rift Tear's depths add (`enemy-growth.md`, section 4), and the testing-only combo readout. The endless mode (`endless.md`) waits for Acts 2 and 3 (phase 8) | The damage rule applies to every hit, heal, and Shield, with Act 1 retuned on it; a few of section 9's combos work in the sim runner's report |
| **6. Bot and tuning** | A good-player bot (placement heuristics, vows, fight and camp picks); tune Act 1 | The good bot clears about 45–50%; a random bot clears far less |
| **7. Art rehaul** | Style guide first (can start any time after phase 3), then the asset contract's loader changes (`asset-contract.md`, section 10), then commissioned art in the contract's order: characters, enemies, arena, UI chrome, effects | The game no longer uses any placeholder or old art |
| **8. Later** | Rocks and more camp options, role-layer upgrades (a role pool once a second hero shares a role; `upgrade-pools.md`), apexes (Acts 2–3; `apexes.md`: the vow opens after the Act 1 boss), enemy specializations and upgrades and the rift learns (`enemy-growth.md`; Act 1's day-5 specializations too, only when needed), difficulty tiers, endless (`endless.md`), the Codex, hero 4 and the team draft, Acts 2 and 3 | — |

**Notes**

- **Rocks** are needed by the camp options Dig In and Choose the Ground. They're built in phase 1 (decided).
- **Apexes** only matter in Acts 2 and 3, so the Act 1 slice can ship without them.
- **Phase 1 is the biggest risk.** Its build plan should be written and approved before phase 0 starts, so the gut doesn't leave the project unplayable for longer than needed.

## Decisions (2026-09-27)

- **Branch strategy:** gut straight on the main working branch (no long-lived rebuild branch).
- **Rocks:** in phase 1.
- **The fight sandbox:** it stays in the game as a **Practice** mode on the title screen, so playtest builds can reach it for gate 1. It can stay rough until the art rehaul.
- **Old saves:** the gut bumps the save version, and the title screen quietly drops a save it can't load.
- **Phase 1's build plan** is `docs/plans/rebuild-phase1-arena-sim.md`. **Phase 1 is done (2026-09-28);** its notes list what each step built and what it measured. **Phase 2 is done (2026-09-28)** (`docs/plans/rebuild-phase2-heroes-enemies.md`): the sim runner shows placement matters in all nine encounters, with its results in that plan's section 7. **Phase 3 is built (2026-09-28)** (`docs/plans/rebuild-phase3-fight-sandbox.md`): Practice on the title screen, with every Act 1 encounter playable. It waits on **playtest gate 1**, judged in playtest build 4 (https://github.com/22nmcdon/Riftrite/releases/tag/playtest-4); what the playtest finds goes back into the plans before phase 4.
- **The elites** (Hound Alpha, Witch Coven, Cairn Watch) **come in phase 5** with Old Mother Ash and the run (decided 2026-09-28), not in phase 2.
- **Part 6** (`docs/plans/rebuild-between-fights.md`, 2026-09-29): after-fight picks, loadout slots bought with a currency, and wounds land in phase 5. **Tactics come first, as phase 3b**, in Practice, before paths: they're the part-6 idea most likely to change how fights feel, and the riskiest. Before either charms or enemy specializations are built, decide their one shared modifier shape.
- **Phase 3b's build plan** is `docs/plans/rebuild-phase3b-tactics.md`. **Phase 3b is built (2026-09-29):** three tactics in Practice, with a tactics report in the sim runner. Round 2 the same day gave each tactic a small payoff tied to its behavior (+20% damage to casters, +20% attack speed while holding, +15% on the heal that waited), tuned with the report. It waits on its playtest (build 9).
- **Phase 4's build plan** is `docs/plans/rebuild-phase4-paths.md`. **Phase 4 is built (2026-09-29):** all nine paths as data (built together, Decision 1), deeds counted in every fight, the sim pieces the paths needed, the hero panel in Practice, and the paths and deeds reports, with the paths tuned to its bars (its section 7). Upgrade pools moved to phase 5. It waits on **playtest gate 2**; five choices made while the playtester was away are flagged in its Decisions.
- **Phase 5's build plan** is `docs/plans/rebuild-phase5-run.md`. **Phase 5 is built (2026-09-29):** a whole Act 1 run, all at once with lean content (Decisions 1-4, and 5-14 as proposed defaults): the run layer and save, growth (thresholds, transformations, Switch vow, upgrades, the pick), the economy (items, shards, the Pedlar and the Magpie, wounds), camp, relics, duo bonds, five harder fights, the three elites, Old Mother Ash, the run's screens, the simple run bot, and the run report. Choices made while building it are in its steps' Decisions. It waits on **playtest gate 3** (a full Act 1 run, playable start to finish).
- **The relic pool** (`docs/plans/relics/`, 2026-09-30) is built with phase 5c. Its decisions win over part 7, part 6, and the run and arena plans where they disagree: relics have no downsides, five tiers, a relic in every shop, new income, and walkable crumbled ground.
- **The loadout pool** (`docs/plans/loadout/`, 2026-09-30) is built with phase 5c, after keywords and triggers. Its decisions win over part 6 where they disagree: four kinds (gambits new, grafts cut into charms), three ranks each, new prices, no "no effect" marker, no shop filtering, and items sell back at any shop. The Magpie (`docs/plans/magpie.md`) becomes a node with a fixed stall, built with it. The rest of the shops' setup is being redone by the playtester.
- **The upgrade pools, the new day, and events** (`upgrade-pools.md`, `days-and-nodes.md`, `events.md`, 2026-09-30) are placed in phase 5c for now, after the relic and loadout pools they sell and offer; phase 5c's build plan orders them. They win over part 1's layers, part 4's day, and part 6's Pedlar camp option.
- **UI for the new systems** (`ui-new-systems.md`, 2026-09-30): what the screens must show for everything above. An overall UI redesign comes next and decides the layout; each system's UI lands with the system, and the redesign's place in the order is still to be set.
- **Enemy growth and endless** (`enemy-growth.md`, `endless.md`, 2026-09-30): the rift modifiers come with Rift Tear's depths in phase 5c. Specializations, upgrades, and the rift learns stay in phase 8, Act 1's day-5 specializations included: **later, only when needed** (the playtester, 2026-09-30). Endless needs Act 3.
- **Part 7** (`docs/plans/rebuild-combos.md`, 2026-09-30): keywords, triggers, the damage rule, permanent scaling, relic tiers with a boss relic after every boss, stat amounts on every card, and the endless mode. **It's phase 5c, before phase 6, starting with the damage rule** (the playtester, 2026-09-30): every later tuning pass depends on it, and phase 6's bot tunes a game that already has it. The endless mode waits for Acts 2 and 3 (phase 8). Section 12 of the plan lists what it changes in what's built; phase 5c gets its own build plan before code.
- **Phase 5c is built (2026-10-01)**, all nine steps of `rebuild-phase5c-combos.md`: the damage rule and walkable crumbled ground, stat amounts on every card, keywords and triggers, permanent scaling, the relic pool, the loadout pool, the upgrade pools, the new day with its nodes and events, and the testing-only combo readout with the engine report and a retune of the deeds' thresholds. It waits on playtest gate 3 with the rest of phase 5; phase 6 (the good bot and tuning) is next.
- **Phase 6 is built (2026-10-02)**, all six steps of `rebuild-phase6-bot-tuning.md`: four bots (random, simple, good, expert) in `tools/bots/`, the good bot placing by reading the fight (weights fitted on practice fights) and judging its choices by practice fights never of the next fight (Decision 5), the `--compare` and `--choices` reports, and Act 1 tuned: **the good bot wins 53%** (a point over 45–50%, within the noise), the random bot 0%, the expert 62%. Every change is in the plan's section 5.5. Left for the next tuning pass: the transformations (+5 to +15, under the 15–25 band), Hearthwall's lumpy deed, and the bot's blind spot for shards and growth.
- **The second tuning pass is built (2026-10-02)**, `rebuild-phase6-bot-tuning.md` section 11: every transformation +16 to +21 over all base on the paths report (a 5% lift and each path's own abilities), Hearthwall's vowed Guard covering every ally within 2 hexes, and Act 1 retuned to them: **the good bot wins 49%**, the random bot 1%, the expert 75%, no day ending more than 29% of lost runs, every path transformed by the boss in 86–100% of runs. Every change is in sections 11.3 and 11.4.
- **After phase 6** (the playtester, 2026-10-02): the second tuning pass (above), then **phase 8 before phase 7**, starting with endless after Act 1 (on Act 1's encounters until Acts 2 and 3 exist), then apexes, enemy specializations and the rift learns, Acts 2 and 3, and the rest. The art rehaul waits until the systems settle.
- **Phase 8 part 1, endless after Act 1, is built (2026-10-02)**, `rebuild-phase8-endless.md`: the choice after the boss shop, floors as days (one fight each from Act 1's day 4 on; an elite every 5th floor, the boss every 10th), enemies ×1.15 a floor, a rift modifier every 3rd, the collapse sooner and the ground hotter, legendaries from floor 10, the first loss ending the run, the records file, the screens, and `run_runner.gd --endless`. Not tuned (Decision 5); the plan's 8a-3 note has how far the good bot gets. Next in phase 8: apexes, then enemy specializations and the rift learns.
- **Phase 8 part 2, apexes, is built (2026-10-03)**, `rebuild-phase8-apexes.md`: all 18 apexes of Maren, Brannoc, and Vell, their 36 cards, the `--apexes` report, a first tuning, and stand-in deed sizes. Endless floors have no shops and no upgrades (its Decision 11). Endless's tuning and Overkill Tithe wait until after the heroes are tuned (its Decision 12).
- **Phase 5b's build plan** is `docs/plans/rebuild-phase5b-art.md` (2026-09-30). The playtester uploaded art (gathered into `art/`) and asked for it in the game before phase 6. **Phase 5b is built (2026-09-30):** Cinzel and Alegreya, the arena turned with heroes at the bottom (which overturns phase 3's sideways board) on the floating island, the item language (each kind's frame with a glyph; grafts a rose octagon), camp's icons and the shops' scenes, and the act map as the route. It changes no fight and no run. The old placeholder widgets this table keeps until phase 7 stay.
- **After Act 3** (the playtester, 2026-10-06): heroes 4 to 6, Garrow, Tamsin, and Aldous, come in together with the team draft (`rebuild-phase8-heroes.md`), and then a tuning phase tunes all six heroes and the acts at once. Built (2026-10-07, playtest build 24): the tuning phase is next, starting from the first check, the bots' runs over all 20 teams, and the questions left in `rebuild-phase8-heroes.md` (HI).
- **More balance testing** comes once things are more settled (the playtester, 2026-09-29).
- **Part 6, section 8 and the screens** (2026-09-29): any hero can hold any slotted thing; the Pedlar sells only what the team can use; the Magpie (about once per act) sells other heroes' gear, grafts, and a relic. The playtester's mock (`docs/mockups/hero-panel-layout.pdf`, part 6 section 9) sets the item language, the after-fight pick, the Pedlar, and relic choices. All of it lands in phase 5, in placeholder art styled after the mock; the final frames come with the art rehaul (phase 7).
- **How the gut went (phase 0, done 2026-09-27):**
  - **Removed, not stubbed:** runtime code labeled Keep (trim) or Keep (adapt) that couldn't run without items was removed rather than stubbed or left as dead code: `events.gd`, the statuses runtime, the relic runner, `sim_test_kit`, `test_determinism`, `fight_tally`, and the other fight UI.
  - **Written fresh from history:** each later phase writes these fresh, using the old versions in git history. The phase 1 plan lists which ones come back in phase 1.
  - **Kept:** the definitions that stand alone (effects, auras, damage-over-time statuses, tuning, unit stats), the log, and the foundation. The title screen stays, with no run to start yet.
  - **Determinism tests:** they return with the arena sim in phase 1, step 2.
  - **Placeholder art:** `tools/art/item_icons.py` and `item_icons_more.py` went with the item icons. Their shared palette and helpers moved to `tools/art/art_kit.py`. The relic icons stay, but nothing draws them anymore.
  - **Saves:** the title drops `user://run.json` quietly, since no save from before the rebuild can load.
