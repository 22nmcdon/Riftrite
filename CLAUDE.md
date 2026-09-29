# CLAUDE.md

## Project

A PvE roguelite auto-battler (working title **Riftrite**, a placeholder). The player leads three heroes into the rift, one day at a time: they place the heroes in an arena before each fight, then watch it play out. Each hero is vowed to a path and transforms into it by doing what the path asks in fights.

**The game is being rebuilt from scratch.** The design is `docs/design.md`, built from the rebuild plans in `docs/plans/`:

| Plan | What it covers |
| --- | --- |
| `rebuild-heroes.md` | heroes, paths, vows, taste and cost, deeds, transformations, upgrades, apexes, mana |
| `rebuild-arena.md` | placement, the free-moving fight, tanks, areas, statuses, the shrinking arena |
| `rebuild-enemies.md` | archetypes, the Act 1 roster, elites, the boss, enemy specializations |
| `rebuild-run.md` | days, camp, fight choice, relics with costs, duo bonds, losing, pacing |
| `rebuild-between-fights.md` | part 6: after-fight picks, loadout slots (charms, tactics, sigils) bought with a currency, wounds; it changes parts 1 and 4 where they disagree |
| `rebuild-build-order.md` | the phases (tactics come as phase 3b, before paths), and what was gutted |
| `rebuild-phase1-arena-sim.md` | phase 1's build plan (built): the arena sim |
| `rebuild-phase2-heroes-enemies.md` | phase 2's build plan (built): base heroes, the Act 1 enemies, encounters, the sim runner |
| `rebuild-phase3-fight-sandbox.md` | phase 3's build plan (built; waiting on playtest gate 1): Practice mode, the hex board, placement, fight playback |
| `rebuild-phase3b-tactics.md` | phase 3b's build plan (built; waiting on its playtest): three tactics in Practice (Casters first, Hold your ground, Wait to heal) |

**Where the rebuild is:** phase 0 (the gut) is done. Items, essences, shops, the run, and the old UI are gone; what was left was the foundation (the data reader, RNG, fixed math, the combat log, the effect and aura definitions, damage-over-time statuses, tuning) and the title screen. **Phase 1 (the arena sim) is done:** a headless fight on a free plane, described under "How the arena sim works" below. **Phase 2 (base heroes and the Act 1 enemies) is done:** the three base kits, the nine Act 1 enemies, and nine hand-placed encounters are data, and the sim runner shows placement matters in every encounter. See "How the content works" below; `rebuild-phase2-heroes-enemies.md` has what each step built and measured. **Phase 3 (the fight sandbox, with placeholder art) is built:** Practice on the title screen (pick an Act 1 encounter, place, watch the fight, see the result), described under "How the UI works" below; `rebuild-phase3-fight-sandbox.md` has what each step built. It's **waiting on playtest gate 1** (is a single fight fun and readable?), judged in playtest build 4. What the playtest finds goes back into the plans before phase 4 starts. **Phase 3b (tactics in Practice) is built:** each hero can take one of three tactics (see "How the arena sim works" and "How the UI works"), and the sim runner has a tactics report; `rebuild-phase3b-tactics.md` has what each step built and the report's first read. It waits on its own playtest. Follow `rebuild-build-order.md` for the order of work. Each phase's plan has a **Decisions** section; those win. If the code and a plan disagree, stop and ask. Don't silently pick one.

The old game (items, the row-based sim, the run layer) is in git history: the commit before "Rebuild phase 0: gut items, essences, shops, the run, and the old UI". Its docs are in `docs/archive/`. Use them as a reference when a phase brings an old piece back, never as the design.

## Tech stack

- Engine: Godot 4.7, GDScript (static typing everywhere: `var hp: int`, typed function signatures). `project.godot` makes untyped declarations a compile error, and the test run fails if any script in `src/`, `tests/`, or `tools/` doesn't compile.
- Tests: GUT (Godot Unit Test)
- Game data: JSON files in `data/`, loaded at startup and validated
- **Pinned versions:** Godot `4.7.2-stable`, GUT `9.7.1` (vendored in `addons/gut/`). Upgrade either one only on purpose, in its own change, and rerun the determinism tests afterward. The Godot version also appears in `.claude/hooks/session-start.sh`, `.github/workflows/*.yml`, and `tests/test_project_setup.gd` (which checks the others); keep them all in sync.

## Commands

- Run the game: `godot --path .` (main scene `src/ui/main.tscn`: the title, then Practice)
- Screenshots of each screen (needs a display): `xvfb-run godot --path . -s tools/ui_screenshots.gd -- --out=/tmp/shots` (the title, the encounter list, placement and choosing a tactic, fights mid-way with a popup and an area warning, the result, and Rift Collapse with the log open)
- Placeholder figures and the title backdrop: `python3 tools/art/hero_kit.py` (and `enemy_kit.py`, `backdrops.py`), then `godot --headless --path . -s tools/art/figure_bounds.gd` to refresh `art/figures/bounds.json` (a test checks it)
- Run all tests: `godot --headless -s addons/gut/gut_cmdln.gd -gexit` (settings in `.gutconfig.json`)
- Run one test file: add `-gselect=test_project_setup.gd`
- Fresh checkout: run `godot --headless --import` once first, so class names are registered. The session-start hook does this in cloud sessions.
- Validate game data: `godot --headless --path . -s tools/validate_data.gd` (also covered by the test run)
- Time the arena sim against its budget (a 60s fight of 3 against 6 in under 100 ms): `godot --headless --path . -s tools/bench_sim.gd`. It runs a steady fight, a crowded worst case, and a summon swarm, and prints each fight's log fingerprint, so a speed-up can be checked to change nothing.
- Fight every encounter from placed parties and check that placement matters: `godot --headless --path . -s tools/sim_runner.gd -- [--encounter=id] [--seeds=50] [--sweep=40] [--no-boards]` (formations in `tools/sim_formations.json`; exits 1 if an encounter fails the gate). Seeds only change crits, so `--seeds=5` is enough while tuning. Add `--tactics` for the tactics report instead (phase 3b): the same formations with each tactic on each hero, against no tactics; a report, not a gate. The run bot comes back in phase 6.
- Cloud sessions: `.claude/hooks/session-start.sh` installs the pinned Godot as `godot` in `~/.local/bin`.
- CI: `.github/workflows/tests.yml` runs the tests and the data validator on every PR and push to main.
- Playtest builds (Windows and macOS, from `export_presets.cfg`): run the "Playtest build" workflow from the Actions tab (or push a `playtest-*` tag). It publishes the zips on a GitHub pre-release. Locally: `tools/ci/install_godot.sh --templates` (with `GODOT_VERSION` set), then `tools/ci/export_builds.sh` (zips land in `build/dist/`). Builds aren't code-signed; `tools/ci/HOW-TO-PLAY.txt` (shipped in each zip) covers the first-launch warnings.

## Folder layout

```
data/          tuning, statuses, heroes, enemies, and encounters; paths, relics, and the run's data come back phase by phase
docs/          design.md, the rebuild plans (plans/), and the old design (archive/)
src/sim/       combat simulation: pure logic, NO nodes, NO rendering
src/run/       the run: days, camp, fights, save (only RunRandom until phase 5)
src/ui/        scenes and UI scripts (reads sim state, never changes it)
tests/         GUT tests, mirroring src/
tools/         data validator, sim runner and bench, screenshots, CI scripts, placeholder art scripts
```

## Rules the code must never break

1. **The combat sim is deterministic.** Same seed + same inputs = same fight, every time. Use only the sim's seeded RNG (never `randi()`, `randf()`, or unseeded RandomNumberGenerator). Use a fixed timestep, not frame delta. Never iterate a Dictionary where order affects the outcome.
   - **Integer math only in `src/sim/`.** No `float`: HP, damage, shields, stats, and positions are `int`; percentages are basis points (`10000` = 100%); time is ticks at a fixed **20 ticks per second**; on the arena's plane, **1 hex = 1000 units**. Data files give durations in milliseconds, and the loader converts them to ticks. Round with explicit integer division, in one shared helper.
2. **The sim is separate from presentation.** `src/sim/` never references nodes, scenes, animations, or UI. The UI plays back events the sim emits.
3. **Content is data, not code.** Heroes, enemies, encounters, paths, upgrades, relics, and duo bonds are JSON entries using existing effect, trigger, and part types. Only add a new effect type in code when no combination of existing ones can express it, and say so when you do.
4. **Every combat effect writes to the combat log** with its source (unit and ability, relic, duo bond, status, or Rift Collapse). Every move, push, shot, and area is logged too. If a player can't trace why something happened, it's a bug.
5. **Meta progression never adds stats.** Unlocks add variety (heroes, camp options, places, relics), cosmetics, and codex entries only.

## How the arena sim works

The details and every decision are in `docs/plans/rebuild-phase1-arena-sim.md`; each module's header comment has its rules. In short:

- **Setup** (`FightSetup`, `UnitSetup`): units on hexes of an 8 × 7 flat-top grid (`HexGrid`, odd columns shifted), rocks, a seed, an act, and the kits summons may use. `validate` refuses what can't be fought. Kits (`UnitDef`) are data: stats, a targeting rule, traits (`engage`, `flying`, `hop_away`), a basic attack, an optional signature and mana bar, passives (`PartDef`), and phases (`PhaseDef`).
- **The plane:** once the fight starts, units move freely (1 hex = 1000, units are circles of radius 100, so 0.2 hex wide, rocks 500) and never overlap. Melee (range 1) reaches half a hex (`melee_reach`), center to center; range 2 and up reach that many hexes. A unit with no way to its target keeps it and waits for an opening, unless rocks or crumbled ground wall the target off; then it picks again. A stealthed enemy (the `stealth` status) can't be picked, and a unit targeting one picks again. (Sizes, reach, that rule, and Stealth came with playtest gate 1.) Walking is straight when clear, otherwise along an A* route on hidden 125-unit cells (`NavGrid`). Every leg is logged, so the board replays from the log.
- **The tick** (`CombatSim.step`, 20 a second): auras whose window changes; Rift Collapse (`Collapse`); statuses (`Statuses`); shots landing (`Shots`); warned areas landing (`Areas`); each standing unit's update in the fight's order (heroes, enemies, then summons as they join): mana, signature (`Signatures`), Stun, attack cooldown, target (`Targeting`, sticky), then attack or walk (`Movement`, `Engage`, `Displacement`); events from this tick's log (`Events`, `Passives`), then timed passives, and phases (`Phases`); deaths (Undying, would_fall, on_fall); the end (180s is a tie, a guild win).
- **Effects** (`EffectRunner`, `EffectDef`): damage, heal, shield, statuses, cleanse, mana drain, knockback, pull, leap, charge, warned areas (circle, ring, line, cone; hit by center), summons (`Summons`), and start_collapse. From 2 hexes or more, an attack is a shot that flies about a tick per hex, with its numbers fixed as it leaves.
- **Passives** (`Passives`, `PartDef`): auras (a window, or `"while": "taunting"`), status swaps, and effects on the unit's events (read from the log), on `on_ally_below_hp` and `on_interval` (after the events each tick), or `on_fall` (in the deaths step). What they do is marked from_event, so it never sets off another event.
- **Tactics** (`Tactics`, `TacticDef`, phase 3b): a hero's one tactic changes how it behaves, never what it can do, and a unit without one never reaches the code, so tactic-free fights are unchanged.
  - Casters first: `Targeting.update` picks the nearest enemy of the tactic's archetypes first.
  - Hold your ground: no walking until an enemy is within 2 hexes, then let go for good.
  - Wait to heal: a full bar waits until the ally its signature picked is below 50%.
  Each logs TACTIC lines sourced to the unit and the tactic.
- **The log** (`LogEntry`): every entry names its source by the rules in `test_arena_log.gd`'s audit. A new log kind needs a rule there.
- **Tests:** `tests/sim/sim_test_kit.gd` builds tiny fights (`K.sim(setup, true)` gives wide units, phase 1's 0.8 hex, for the few tests whose scenario needs units bulky enough to box a unit in; everything else uses the real tuning). `test_kit_pieces.gd` covers the passive pieces phase 2 added, one rule at a time. `tests/sim/chaos_fight.gd` is one seeded fight using everything; `test_determinism` checks it repeats exactly and still uses every piece, and `test_arena_log` replays it and audits its sources. A change that alters fights changes `tools/bench_sim.gd`'s fingerprints; one that shouldn't must leave them alone.

## How the content works

Phase 2's details are in `docs/plans/rebuild-phase2-heroes-enemies.md` (sections 2–7 and their "Built in step N" notes). In short:

- **Files** (`ContentDb` loads and cross-checks them): `heroes.json` (`HeroDef`: name, title, role, and a kit), `enemies.json` (`EnemyDef`: archetype, threat line, and a kit, phases included; the kit carries the archetype too), `encounters.json` (`EncounterDef`: enemies on hexes, optional rocks, act, days, and `scale_bp`), and `tactics.json` (`TacticDef`, phase 3b: a kind, its numbers, and the heroes who can take it; a hero takes one through `Encounters.setup`'s tactics map, as `UnitSetup.tactic`). A hero's or enemy's kit is a `UnitDef` without its own id or name; heroes and enemies share one space of ids. Heroes act in `heroes.json`'s order.
- **A fight from content:** `Encounters.setup(content, encounter_id, formation, seed, errors)`, where a formation is hero id -> hex. It adds every enemy a unit may summon as a summon kit, and scales enemies' HP and ATK by `scale_bp`.
- **Ability text:** every basic attack, signature, and passive of a hero or enemy has a `"text"`: the player's sentence for it (the sim never reads it). It says what the ability is for and **names every reach** ("within 4 hexes"), since the board never draws one; `test_unit_info.gd` checks both. Keep numbers out of it: the UI adds a numbers line generated from the kit.
- **Numbers:** hero stats are the design's. Enemy HP, ATK, and a few kit numbers come from step 7's first tuning pass. Change numbers with the sim runner, not by hand-feel.
- **The sim runner** (`tools/sim_runner.gd`, its work in `tools/sim_report.gd`) fights each encounter from the named formations in `tools/sim_formations.json` and from drawn ones. **The gate:** the best formation wins at least 30 points more often than the worst. Seeds only change crits, so formations mostly win all or nothing; the report also counts how many formations win, and tuning aims for about a third to two thirds.
- **Tests:** `test_hero_kits.gd` and `test_enemy_kits.gd` check each kit's text in small fights; `test_encounters.gd` checks every encounter builds and plays out; `test_arena_log.gd` replays and audits a fight of the three heroes against one of each enemy; `tests/tools/test_sim_runner.gd` runs the runner small. Content changes that should move numbers change these tests on purpose.

## How the UI works

Phase 3's details are in `docs/plans/rebuild-phase3-fight-sandbox.md` (sections 1-9, their "Built in step N" notes, and its Decisions). In short:

- **Screens:** `Main` shows one `UiScreen` at a time and moves between them on their signals: the title, then Practice's `EncounterListScreen`, then `ArenaScreen`, which holds placement, the fight, and the result. `PracticeSession` keeps the remembered formation, the speed, the log's state, and the seed while the game is open; nothing is saved to disk.
- **The UI never changes a fight** (rule 2). `FightPlayer` owns the `CombatSim` and is the only thing that steps it:
  - `advance(seconds)` steps whole ticks at 0.5x, 1x, or 2x; tests pass fake time.
  - A seek or restart builds a fresh sim and runs it to that tick.
  - Units are drawn between their last two ticks (`drawn_position`, `drawn_time`).
  `test_every_encounter_plays.gd` checks that each encounter played on the screen is exactly the fight `CombatSim.run` gives.
- **The board** (`ArenaView`): the plane mapped to pixels, turned sideways (landscape: heroes on the left, enemies on the right; the plane's rows run across the screen), centered at the screen's full height; one `UnitToken` per unit, drawn as its figure (`FigureArt`: `art/figures/`, a hero's base form for now) standing on its point, nearer units in front, with its bars over its head and status tags read from `UnitState` each frame; `FightFx` above them for what the log says happened (shots, swipes, numbers, areas, slides, ghosts, rings), plus the ground layer (areas, Rift Collapse, target and Engage lines). Effects run on the fight's clock; a batch of more than 60 entries (a skip) clears them instead. The view resolves clicks itself (`token_at`).
- **Placement:** heroes are dragged onto hexes; what's legal comes only from the sim (`Encounters.setup` and `FightSetup.validate`, through `PracticeSession.errors`). The board never draws an enemy's reach (Decision 5).
- **Beside the board:**
  - on the right, the side column: the encounter's name and hint, `EnemyPanel` on hover, the controls and the `FightChart` during the fight, and the result when it ends (outcome, seed, heroes, chart, Rematch, Watch again);
  - on the left, an empty gutter as wide as the side column (it keeps the board centered), where the combat log (`LogPanel`) pops up with its button or L;
  - `HeroPopup` beside a hero clicked while the fight isn't playing. It and `EnemyPanel` are built by `UnitInfo` (the data's sentence plus a generated numbers line). Its Tactic row (phase 3b) sets the hero's tactic while placing (`PracticeSession.tactics`; the board names it under the hero), and names it in a fight.
  `FightNames` turns ids into names ("Rift Hound 2"). `FightTally` (in `src/sim/`, shared with the sim runner) counts the chart. `FightBanners` shows a phase, the collapse, and the end.
- **Every kind of log entry needs a form on the board:** `test_every_encounter_plays.gd` has a table of them, and checks the board showed each kind a fight produced. A new log kind needs a row there as well as its audit rule in `test_arena_log.gd`.
- **Tests:** UI tests run headless and drive time by hand (`ArenaScreen._process(delta)`); `tests/ui/ui_test_kit.gd` finds and presses controls by text; `test_practice_flow.gd` drives a real `Main` from the title to the result. A test that replaces screens lets a frame pass before it ends, since `Main` frees the old screen on the next frame.

## The design the rebuild builds toward

These are summaries; the plans have the details and the decisions. As each phase lands, move its rules into a "how the code works" section here.

- **Heroes** (`rebuild-heroes.md`): a team of 3 (Brannoc, Maren, Vell for now), kept all run. Stats (HP, ATK, MGK, DEF, CRIT, ATSP, speed, range), a basic attack, a signature, a passive, sometimes a trait. Three paths each: vow at the start (a taste and a cost), transform when the path's deed fills, and later an apex. Upgrade picks come after every won fight, not from deeds. Every deed must be hard to fill without its taste. No ranks, items, or duplicates.
- **Between fights** (`rebuild-between-fights.md`): each hero has loadout slots for charms, tactics, and sigils (none are abilities; all are written against the slot, so they survive a transformation), bought with a currency and swapped freely. A hero who falls gets a wound (–15% max HP, up to 3); Rest clears them.
- **Signatures and mana:** a signature fires on a trigger: mana, HP threshold, a count, a set moment, or would-fall. Only signatures use mana; a unit without a mana signature has no mana bar. Silence stops mana gain. Stun doesn't, but a stunned unit can't fire a mana signature (other triggers still fire).
- **The arena** (`rebuild-arena.md`, `rebuild-phase1-arena-sim.md`): placement on flat-topped hexes (8 × 7, 3-row zones, a neutral middle row), then a fight on a free-moving plane. Units never overlap. Heroes come first in the fight's order. Targeting rules are data, with sticky targets. Melee lands when the attack finishes; ranged shots travel about 1 tick per hex and follow their target. Engage, Taunt, Stealth, knockback (a stopped push stuns), pulls, leaps, charges, flying, hop-away. Areas are warned and hit by center. Rift Collapse shrinks the arena one ring every 10s from 45s, and nobody can walk onto crumbled ground. Up to 30 standing units per side. A fight still running at 180s is a tie, and a tie counts as a guild victory.
- **Enemies** (`rebuild-enemies.md`): each tests one positioning question; hand-placed formations; elites built around one mechanic; Old Mother Ash with phases. Every elite and boss says what it does and what answers it. Harder means new problems, not more HP.
- **The run** (`rebuild-run.md`): Act 1 is about 7 days; a day is camp, a pick of 2 fights (known from the act's start), the loadout, placement, the fight, then the after-fight pick and deed rewards. No items or shops; a currency buys only loadout things (at the Pedlar camp option) and wound treatment. Relics are rare and each has a cost. Duo bonds link two paths. A lost fight replays the day; the second loss ends the run; a tie pays like a win. The run is deterministic from its seed, like the sim, with separate streams for shops, picks, camp, and fights.
- "Lowest HP" (heals and targeting) means lowest HP **percentage**.
- PvE only. Don't add networking or PvP code.

## How to work in this repo

- For any new system, propose a plan first (files, data shape, tests) and wait for approval before writing code. Each rebuild phase gets its own build plan before code is written.
- Write or update tests for sim logic in the same change. Determinism tests (run a seeded fight twice, compare logs) must keep passing once phase 1 brings them back.
- Keep changes small and focused. Don't refactor unrelated code.
- When adding content, validate the JSON with `tools/` before finishing, and run the balance sim on anything that changes numbers (once it's back).
- If a design question isn't answered in the design or the plans, ask instead of inventing an answer. Then note the answer in the matching plan's **Decisions**. Unanswered questions live under **Open questions** in `docs/design.md`.

## Tone and naming

The setting is the rift: dark and dangerous, with no warm hub to come home to. Content names should fit that. All art is placeholder until the art rehaul (rebuild phase 7). Don't use names, characters, or items from Guildrun, The Bazaar, or Enter the Gungeon.
