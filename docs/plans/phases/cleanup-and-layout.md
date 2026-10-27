# The clean-up and the new layout

Status: **built (2026-10-27).** The playtester asked for a full sweep: dead code and needless complexity out, and a folder layout where everything has its own place (a folder for the heroes with one per hero, a folder for the UI, and so on), with a `README.md` in every folder for quick familiarization, by people and by agents. Nothing here changes a fight: the sim's code and numbers stay the same, and the bench's fingerprints must not move.

## 1. What the survey found

- **The data is in 18 flat files,** some very large: `paths.json` (522 KB, every hero's three paths and their apexes), `upgrades.json` (271 KB, 585 cards), `relics.json`, `enemies.json`, `items.json`, and `statuses.json` (205 statuses: the base ones, and those that a hero's paths, cards, or relics set).
- **The code** is already split by system (`src/sim`, `src/run`, `src/ui`), but `src/sim/` has 23 loose files beside its folders, and `src/ui/` 7. The code isn't per hero: a hero's "pieces" are general mechanics that other heroes, relics, and cards reuse, so hero folders belong to the data, the tests, and the docs, not the code.
- **The tests:** `tests/sim/` has 93 loose files, 52 of them named for a hero (`test_kestra_paths.gd`, and so on).
- **The tools:** 18 loose files in `tools/`: runners, reports, the bench, the validator, the screenshots, the progress writer, GUT's hooks, and the teams' JSON.
- **The docs:** `docs/plans/` has 44 loose plans of four kinds: the design by system, the build plan of each phase, the act rosters, and the tuning notes.
- **Dead code** (no callers anywhere): `UiStyle.stat_row`, `icon_label`, `icon`, `rarity_color`, `MOSS_500`, and `ACCENT`; `UnitToken.HERO_TEXT`; `HoverCard.title_text` and `body_text`; `HeroPanel._unhandled_key_input` (checked before it goes: Godot calls it, so it's dead only if it does nothing); `CombatSim.crumbled_depth`; `SimRng.get_state`; `TacticDef.SIGNATURE_KINDS`; `EffectDef.scales_from_rate_stats`; `DeedDef.COUNT_LABELS`; `UnitDef.has_mana`; `UnitStats.with_hp_bp`; `AbilityState.needed_bp`; `RunRandom.PACKAGE` and `STOPS`; `RunFlow.RELIC_SHOP`; `GoodBot.REROLLS`. Used only by tests (kept where a test needs a window into the code, removed where the test only tests the dead function): `NavGrid.is_free`, `estimate_safe`, `settled_count`; `RunRandom.pick_weighted`; `TriggerDef.is_once`; `AuraDef.is_unit_stat`; `FightResult.guild_won`; `Placement.formation_score`, and a few more, each judged in the build.
- **Dead art:** `art/ui/chrome/` (no code draws it; `tools/art/ui_art.py` writes it), the old icons (`stop_*`, `gold`, `key`, `fight_*`, `day`, `loss`; nothing loads `art/ui/icons/`), and seven camp icons from options that are gone (`dare`, `choose_the_ground`, `meditate`, `study`, `track_the_elite`, `lay_traps`, `mentor`), each checked with a search before it goes.
- **Duplication to fold:** `RunContent.art_exists` repeats `ArtFile.resolve`'s rule (7a kept them apart so `src/run` doesn't reach into the UI; a small shared helper in a neutral place removes the copy).
- **The biggest files** (`run_flow.gd` 2151 lines, `effect_def.gd` 1591, `effect_runner.gd` 1376, `combat_sim.gd` 1335, `kit_mod.gd` 1284): candidates for splitting, listed in section 4, not split in this pass unless approved.

## 2. The new layout

```
data/
  README.md
  core/          tuning.json, statuses.json (the shared ones), tactics.json
  heroes/        README.md (the roster, the order heroes act in), order.json
    maren/       README.md, hero.json (the base kit), paths.json (her three paths
                 with their apexes), upgrades.json (her cards: own, taste, path,
                 apex), statuses.json (statuses only her content sets)
    brannoc/ ... one folder per hero, the same files
  acts/
    act1/        README.md, act.json, enemies.json (the enemies this act brings
                 in), encounters.json
    act2/, act3/
  run/
    relics/      common.json, rare.json, epic.json, legendary.json, boss.json, bond.json
    items/       charms.json, tactics.json, sigils.json, gambits.json
    bonds.json, camps.json, events.json, rift_learns.json, enemy_upgrades.json

src/
  sim/
    core/        combat_sim, combat_log, log_entry, sim_rng, fixed_math,
                 damage_rule, fight_result, data_reader
    units/       passives, signatures, statuses, mana, deeds, tactics, gambits,
                 grips, copies, phases, keywords, events
    arena/       (as now) movement, nav, areas, water, islands, ...
    effects/, state/, setup/  (as now)
    content/     content_db and defs/ (the data's shapes)
    tally/       fight_tally, combo_tally
  run/
    content/     run_content, act_def, camps_def, event_def, rift_learns_def
    flow/        run_flow, run_state, run_save, run_records, hero_team
    draws/       offers, act_draw, run_random, rift_learns
  ui/
    app/         main, ui_style, art_file, fight_names, ...
    arena/, screens/, widgets/, practice/, run/  (as now)
    info/        unit_info, mod_info (the cards' and panels' sentences and numbers)

tests/           mirrors src/, plus
  sim/heroes/<hero>/   that hero's tests (pieces, paths, cards, apexes)
  fixtures/

tools/
  runners/       sim_runner, run_runner (the entry points)
  reports/       sim_report, path_report, apex_report, build_report, run_report
  teams/         sim_formations, apex_teams, build_teams, test_teams
  bench/         bench_sim, bench_states/
  bots/, art/, ci/  (as now)
  validate_data.gd, ui_screenshots.gd, progress.gd, gut_pre_run.gd, gut_post_run.gd

docs/
  design.md
  plans/
    design/      the design by system (rebuild-heroes, rebuild-arena, apexes,
                 relics/, loadout/, economy, ...)
    phases/      each phase's build plan (rebuild-phase1 ... phase8, 7a, this one)
    acts/        act2-glassmere, act3-shattered-crown
    tuning/      build-tuning, build-map, test-teams, easy-start, tuning-phase
    art/         asset-contract, incoming/
  archive/, mockups/  (as now)
```

Every folder we own gets a `README.md` (what's in it, its key files, what reads it, where to look next), except `addons/`, `.godot/`, build output, and the folders that hold only art files under `art/ui/` (those share one `art/README.md` with a line each). `CLAUDE.md`'s folder layout, commands, and plan table follow the new paths.

## 3. How the data loads

- `ContentDb.load_dir` and `RunContent`'s loader walk the folders above and join each kind's entries into one list, in a set order (heroes by `data/heroes/order.json`, acts by number, relic tiers and item kinds in their order), so every id list the game draws from is what it was. `load_texts` (the tests' way in) keeps taking whole files by name, so the 18 tests that build content from text don't change.
- An error names the file it came from (`heroes/maren/paths.json (deadeye)`), not the joined list.
- A test checks that every file under `data/` is read (no file is left out by a typo), and the validator walks the same folders.
- **Order check:** before and after, the bench's fingerprints (fights) and a fingerprint of a small batch of runs (the run's draws: picks, shops, relics) must match. Where the old files interleaved heroes (the first three heroes' apex cards sit together after Vell's cards in `upgrades.json`), the loader's order is chosen to match the old one; Decision 1 settled it: heroes load in roster order and a reshuffle is accepted, so only the fights' fingerprints must match.

## 4. Complexity

In this pass, the safe simplifications only: dead code out, the duplicated art check folded, helpers that do the same thing under two names joined, and leftover comments that point at code that's gone. The big files are listed with a proposal each (for example, `run_flow.gd`'s shop, node, and event actions as their own files beside the flow), to be split later if approved, one file a change, since splitting them touches every test of the run.

## 5. Questions

- **CA. The run's draw order.** If the per-hero files can't reproduce the old order exactly, the run's random draws see the cards in a new order: the same odds, but a given seed plays a different run (fights are unchanged). Recommended: match the old order; accept a reshuffle only where matching it would need a special case.
- **CB. Hero art folders.** `art/figures/heroes/maren_base.svg` could become `art/figures/heroes/maren/base.svg` (and portraits the same), at the cost of changing the asset contract's names before any art is commissioned. Recommended: yes, now, while nothing is commissioned.
- **CC. Big files.** Split the five biggest files in this pass, or list them for later. Recommended: list them for later.

## 6. Steps

1. **Dead code and art out,** the duplication folded (no moves yet, so the diff is reviewable). Full suite; the bench unchanged.
2. **Data split** into the folders, the loaders, the validator, the tests that name files. The order check; full suite.
3. **Code and tests moved** (`git mv`, so history follows; `preload` paths and `.tscn` references updated; `godot --headless --import`). Full suite.
4. **Tools and docs moved,** with the CI workflow, the session-start hook, the run-status mod, and every live doc's paths (old phase plans keep their history as written, with a note at the top of `docs/plans/README.md` that paths in finished plans are as they were then).
5. **READMEs** in every folder, `CLAUDE.md` updated, full suite, commit and push after each step.

## 7. Built

- **Step 1** (dead code and art): the symbols in section 1, removed after a search for each; `HeroPanel._unhandled_key_input` stayed (Godot calls it: Escape closes the panel). `RunRandom.pick_weighted` and `AuraDef.is_unit_stat` went with the test lines that only tested them; the other test windows stayed. `art/ui/chrome/`, `art/ui/icons/`, the seven old camp icons, and `tools/art/ui_art.py` went. `ArtPath` (`src/shared/art_path.gd`) holds the PNG-before-SVG rule for `ArtFile` and `RunContent`.
- **Step 2** (data): split by a script that cut the old files' text entry by entry, so every entry keeps its formatting. 133 statuses that only one hero's content names moved to that hero's folder; 72 stay shared. `DataLayout` (`src/sim/content/data_layout.gd`) names the files, joins each kind, and marks each entry with its file for errors; it took over `ContentDb`'s and `RunContent`'s copies of `_parse` and `_entries`. `test_content_db.gd` checks every file under `data/` is read; the status order it pins is the new one (Decision 1). The bench's fingerprints didn't move.
- **Step 3** (code, tests, hero art): as section 2 drew it, with `git mv` and every `res://` path rewritten; tests' support kits stay at the top of `tests/sim/` and `tests/run/`. Each hero's tests (sim and run) are in `tests/heroes/<hero>/`. Figures are `art/figures/heroes/<hero>/<form>`; Kestra's companions have folders of their own.
- **Step 4** (tools, docs): as section 2 drew it, plus `run_bot.gd` among the bots; paths rewritten in the docs too.
- **The audit's simplifications** (a read-only review of `src/`, `tools/`, and the test kits): fields nothing reads, the duo-bond source flag nothing sets, the `SYNERGY` and `DEED_LEVEL` log kinds nothing logs, parameters every caller passes the same way, one copy of each duplicated helper (`ValueBreakdown.percent`, `ratio`, `signed_percent`; `Targeting.straight_nearest` for the nearest enemy; `ArenaPlane` for distances; `RunSave.erase`; `UiStyle.wrapped`; `RunState.hero_ids`; `UnitInfo.status_name` and `hexes`; the relic tiers; the formations file), three forwarding wrappers folded, stale comments fixed, and comments naming `data/`'s old files pointed at the new ones. Left as found: the two placement tie orders (Practice's and the bot's), since sharing one would move placements; `run_report.teams`, which the tests call.
- **READMEs:** one in every folder but the per-figure and fixture leaves (their parents cover them) and those that are documents themselves (`docs/archive/`, `design/relics/`, `design/loadout/`, `art/incoming/`), each an intro and a table of the folder's files from their header comments; each hero's data and tests READMEs are generated from the data. A `README.md` at the root.
- **What the reshuffle turned up** (Decision 1): the path report's first eighteen variants now run in roster order (Brannoc's paths before Maren's), and its test follows; and the random bot's Shrine offered only the relics the Shrine refuses (its check was the wrong way round), a bug no seed had hit until the draws moved, now fixed.
- **Section 4's big files**, for later (Decision 3): `run_flow.gd` (its shop, node, and event actions as their own files beside the flow), `effect_def.gd` (its readers and checks apart from the shape), `effect_runner.gd` (moves and areas apart from landing), `combat_sim.gd` (the deaths step and the end apart from the tick), and `kit_mod.gd` (its knobs by slot).

## Decisions

1. **The run's draw order (Question CA):** a reshuffle is fine (the playtester, 2026-10-27). Heroes load in roster order; where that reorders a list the run draws from, a seed plays a different run with the same odds. Fights don't change, so the bench's fingerprints still must not move.
2. **Hero art folders (Question CB):** yes. Figures become `art/figures/heroes/<hero>/<form>` and portraits mirror the figures (`art/portraits/heroes/<hero>/<form>`, `art/portraits/enemies/<enemy>`); the asset contract's names change with them.
3. **Big files (Question CC):** listed for later, not split in this pass.
