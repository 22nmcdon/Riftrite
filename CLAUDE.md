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
| `rebuild-build-order.md` | the phases, and what was gutted |
| `rebuild-phase1-arena-sim.md` | phase 1's build plan (approved): the arena sim |

**Where the rebuild is:** phase 0 (the gut) is done. Items, essences, shops, the run, and the old UI are gone; what's left is the foundation (the data reader, RNG, fixed math, the combat log, the effect and aura definitions, damage-over-time statuses, tuning) and the title screen. **Phase 1 (the arena sim) is under way:** steps 1 (the grid, plane geometry, and pathfinding, in `src/sim/arena/`) and 2 (a skeleton fight: kits, setups, walking, nearest targeting, melee and shots, the log) are built. Follow `rebuild-build-order.md` for the order of work. Each phase's plan has a **Decisions** section; those win. If the code and a plan disagree, stop and ask. Don't silently pick one.

The old game (items, the row-based sim, the run layer) is in git history: the commit before "Rebuild phase 0: gut items, essences, shops, the run, and the old UI". Its docs are in `docs/archive/`. Use them as a reference when a phase brings an old piece back, never as the design.

## Tech stack

- Engine: Godot 4.7, GDScript (static typing everywhere: `var hp: int`, typed function signatures). `project.godot` makes untyped declarations a compile error, and the test run fails if any script in `src/`, `tests/`, or `tools/` doesn't compile.
- Tests: GUT (Godot Unit Test)
- Game data: JSON files in `data/`, loaded at startup and validated
- **Pinned versions:** Godot `4.7.2-stable`, GUT `9.7.1` (vendored in `addons/gut/`). Upgrade either one only on purpose, in its own change, and rerun the determinism tests afterward. The Godot version also appears in `.claude/hooks/session-start.sh`, `.github/workflows/*.yml`, and `tests/test_project_setup.gd` (which checks the others); keep them all in sync.

## Commands

- Run the game: `godot --path .` (main scene `src/ui/main.tscn`; for now it shows the title screen)
- Screenshots of each screen (needs a display): `xvfb-run godot --path . -s tools/ui_screenshots.gd -- --out=/tmp/shots`
- Run all tests: `godot --headless -s addons/gut/gut_cmdln.gd -gexit` (settings in `.gutconfig.json`)
- Run one test file: add `-gselect=test_project_setup.gd`
- Fresh checkout: run `godot --headless --import` once first, so class names are registered. The session-start hook does this in cloud sessions.
- Validate game data: `godot --headless --path . -s tools/validate_data.gd` (also covered by the test run)
- The headless sim runner comes back in phase 2 (placed parties) and the run bot in phase 6.
- Cloud sessions: `.claude/hooks/session-start.sh` installs the pinned Godot as `godot` in `~/.local/bin`.
- CI: `.github/workflows/tests.yml` runs the tests and the data validator on every PR and push to main.
- Playtest builds (Windows and macOS, from `export_presets.cfg`): run the "Playtest build" workflow from the Actions tab (or push a `playtest-*` tag). It publishes the zips on a GitHub pre-release. Locally: `tools/ci/install_godot.sh --templates` (with `GODOT_VERSION` set), then `tools/ci/export_builds.sh` (zips land in `build/dist/`). Builds aren't code-signed; `tools/ci/HOW-TO-PLAY.txt` (shipped in each zip) covers the first-launch warnings.

## Folder layout

```
data/          tuning and statuses for now; heroes, enemies, encounters, paths, relics, and the run's data come back phase by phase
docs/          design.md, the rebuild plans (plans/), and the old design (archive/)
src/sim/       combat simulation: pure logic, NO nodes, NO rendering
src/run/       the run: days, camp, fights, save (only RunRandom until phase 5)
src/ui/        scenes and UI scripts (reads sim state, never changes it)
tests/         GUT tests, mirroring src/
tools/         data validator, screenshots, CI scripts, placeholder art scripts
```

## Rules the code must never break

1. **The combat sim is deterministic.** Same seed + same inputs = same fight, every time. Use only the sim's seeded RNG (never `randi()`, `randf()`, or unseeded RandomNumberGenerator). Use a fixed timestep, not frame delta. Never iterate a Dictionary where order affects the outcome.
   - **Integer math only in `src/sim/`.** No `float`: HP, damage, shields, stats, and positions are `int`; percentages are basis points (`10000` = 100%); time is ticks at a fixed **20 ticks per second**; on the arena's plane, **1 hex = 1000 units**. Data files give durations in milliseconds, and the loader converts them to ticks. Round with explicit integer division, in one shared helper.
2. **The sim is separate from presentation.** `src/sim/` never references nodes, scenes, animations, or UI. The UI plays back events the sim emits.
3. **Content is data, not code.** Heroes, enemies, encounters, paths, upgrades, relics, and duo bonds are JSON entries using existing effect, trigger, and part types. Only add a new effect type in code when no combination of existing ones can express it, and say so when you do.
4. **Every combat effect writes to the combat log** with its source (unit and ability, relic, duo bond, status, or Rift Collapse). Every move, push, shot, and area is logged too. If a player can't trace why something happened, it's a bug.
5. **Meta progression never adds stats.** Unlocks add variety (heroes, camp options, places, relics), cosmetics, and codex entries only.

## The design the rebuild builds toward

These are summaries; the plans have the details and the decisions. As each phase lands, move its rules into a "how the code works" section here.

- **Heroes** (`rebuild-heroes.md`): a team of 3 (Brannoc, Maren, Vell for now), kept all run. Stats (HP, ATK, MGK, DEF, CRIT, ATSP, speed, range), a basic attack, a signature, a passive, sometimes a trait. Three paths each: vow at the start (a taste and a cost), transform when the path's deed fills, then upgrade picks and later an apex. Every deed must be hard to fill without its taste. No ranks, items, or duplicates.
- **Signatures and mana:** a signature fires on a trigger: mana, HP threshold, a count, a set moment, or would-fall. Only signatures use mana; a unit without a mana signature has no mana bar. Silence stops mana gain. Stun doesn't, but a stunned unit can't fire a mana signature (other triggers still fire).
- **The arena** (`rebuild-arena.md`, `rebuild-phase1-arena-sim.md`): placement on flat-topped hexes (8 × 7, 3-row zones, a neutral middle row), then a fight on a free-moving plane. Units never overlap. Heroes come first in the fight's order. Targeting rules are data, with sticky targets. Melee lands when the attack finishes; ranged shots travel about 1 tick per hex and follow their target. Engage, Taunt, knockback (a stopped push stuns), pulls, leaps, charges, flying, hop-away. Areas are warned and hit by center. Rift Collapse shrinks the arena one ring every 10s from 45s, and nobody can walk onto crumbled ground. Up to 30 standing units per side. A fight still running at 180s is a tie, and a tie counts as a guild victory.
- **Enemies** (`rebuild-enemies.md`): each tests one positioning question; hand-placed formations; elites built around one mechanic; Old Mother Ash with phases. Every elite and boss says what it does and what answers it. Harder means new problems, not more HP.
- **The run** (`rebuild-run.md`): Act 1 is about 7 days; a day is camp, a pick of 2 fights (known from the act's start), placement, the fight, then deed rewards. No currency, items, or shops. Relics are rare and each has a cost. Duo bonds link two paths. A lost fight replays the day; the second loss ends the run. The run is deterministic from its seed, like the sim.
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
