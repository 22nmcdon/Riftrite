# tools/

Scripts for building, measuring, and tuning the game; none ship in a build. Run each from the repo root with `godot --headless --path . -s <script> -- [options]` (the options are in each script's header and in `CLAUDE.md`'s Commands).

- `validate_data.gd`: checks `data/` (the test run does too).
- `ui_screenshots.gd`: a picture of every screen (needs a display: `xvfb-run`).
- `progress.gd`: the long tools' progress files, read by the run-status mod (`.claude/skills/run-status/`).
- `gut_pre_run.gd`, `gut_post_run.gd`: GUT's hooks (`.gutconfig.json`).

## Folders

| Folder | What it holds |
| --- | --- |
| `art/` | The placeholder art's makers and their Godot helpers: the hero and enemy figures, the backdrops, the item glyphs split from their frames, and `figure_bounds.gd`. |
| `bench/` | `bench_sim.gd` times the sim against its budget and prints each fight's log fingerprint, so a change that shouldn't alter fights can be checked to leave them alone. |
| `bots/` | The bots that play runs for the reports: the simple run bot, and phase 6's random, simple, good, and expert bots. |
| `ci/` | What CI and the playtest builds run: installing the pinned Godot, exporting the Windows and macOS builds, and `HOW-TO-PLAY.txt`, shipped in each build. |
| `reports/` | The reports the runners print, as libraries the runners and tests call: the encounter gate, paths and deeds, apexes, builds, and runs. |
| `runners/` | The long-running entry points: `sim_runner.gd` and `run_runner.gd`. |
| `teams/` | The teams the reports and bots play: formations by role for the sim runner, the apex report's teams, the builds report's teams, and the test teams with their fixed vows. |

## Files

| File | What it is |
| --- | --- |
| `gut_post_run.gd` | GUT post-run hook: fail the run if the pre-run hook found scripts that don't compile. |
| `gut_pre_run.gd` | GUT pre-run hook: compile every project script before tests run. |
| `progress.gd` | Progress files for the long tools, so a run's status shows while it goes. |
| `ui_screenshots.gd` | Renders each screen to PNGs. |
| `validate_data.gd` | Validates every file in data/ and exits non-zero if anything is wrong. |
