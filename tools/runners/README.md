# tools/runners/

The long-running entry points: `sim_runner.gd` (fights every encounter from placed teams; the placement gate, and the tactics, paths, deeds, apexes, and builds reports) and `run_runner.gd` (plays many runs with a bot; `--jobs=N` splits them over processes). Their work is in `tools/reports/`.

## Files

| File | What it is |
| --- | --- |
| `run_runner.gd` | The run report: plays many runs with a bot and prints how they pace. |
| `sim_runner.gd` | Fights the Act 1 encounters with placed parties and reports whether placement matters. |
