# tools/bench/

`bench_sim.gd` times the sim against its budget (a 60s fight of 3 against 6 in under 100 ms) and prints each fight's log fingerprint, so a change that shouldn't alter fights can be checked to leave them alone. `states/` holds the run states its later fights start from.

## Folders

| Folder | What it holds |
| --- | --- |
| `states/` | Saved run states that `bench_sim.gd` builds fights from. |

## Files

| File | What it is |
| --- | --- |
| `bench_sim.gd` | Times the arena sim against its budget and prints a fingerprint of each fight's log, so a speed-up can be checked to change nothing. |
