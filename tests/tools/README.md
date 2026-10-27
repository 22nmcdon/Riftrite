# tests/tools/

The tools run small: the bots, the reports, the sim runner, the easy start's Glass check, and the progress writer.

## Files

| File | What it is |
| --- | --- |
| `test_bots.gd` | Phase 6's bots: each plays whole runs through RunPlayer without a refused action, and a run repeats from its seed; and the run report's run lines survive --jobs. |
| `test_build_report.gd` | The sim runner's builds report: its teams file reads, and a small run gives each lineup's fights and the gains. |
| `test_easy_start.gd` | The Glass check: the weakest team, three back-liners with no front line, wins every day-1 fight at least GLASS_FLOOR of the time, on every vow set it can take, with the good bot placing. |
| `test_path_report.gd` | The sim runner's paths and deeds reports: the variants, a small run, where a hero stands, and the summaries' bars. |
| `test_progress.gd` | The long tools' progress files: a valid file, written at most every 2 seconds, renamed into place, finished with a status; and run_runner.gd's report the same with progress on and off. |
| `test_run_report.gd` | The run report, run small. |
| `test_sim_runner.gd` | The sim runner: its formations, drawn formations, a small run, and the gate. |
