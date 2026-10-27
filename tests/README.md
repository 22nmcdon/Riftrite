# tests/

GUT tests (`godot --headless -s addons/gut/gut_cmdln.gd -gexit`; one file: add `-gselect=<file>`). They mostly mirror `src/`, with each hero's tests together in `heroes/`. The run fails if any script in `src/`, `tests/`, or `tools/` doesn't compile (`test_project_setup.gd`).

## Folders

| Folder | What it holds |
| --- | --- |
| `fixtures/` | Small files tests load instead of the game's own: `art/` holds tiny figures, a manifest, bounds, and a portrait for `tests/ui/test_art_loading.gd`. |
| `heroes/` | Each hero's tests in its own folder: its base kit's pieces, its paths, its cards, its apexes, and any run pieces built for it. |
| `run/` | The run's tests, by topic, and `run_test_kit.gd`. |
| `sim/` | The sim's tests, by part, and the kits most tests build fights with: `sim_test_kit.gd`, `chaos_fight.gd`, and `path_fights.gd`. |
| `tools/` | The tools run small: the bots, the reports, the sim runner, the easy start's Glass check, and the progress writer. |
| `ui/` | The screens, run headless with time driven by hand, and `ui_test_kit.gd`. |

## Files

| File | What it is |
| --- | --- |
| `test_project_setup.gd` | Guards the pinned toolchain. |
