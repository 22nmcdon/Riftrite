# src/run/draws/

Everything random in a run, each from its own seeded stream (`RunRandom`) so an offer is a pure function of the seed and the state: the act's fights, shops, picks, nodes, specializations, enemy upgrades, and what the rift learns.

## Files

| File | What it is |
| --- | --- |
| `act_draw.gd` | Every day's fight options, drawn when the act starts, from the run's seed alone, so the whole act is known from the start. |
| `offers.gd` | What the run offers, drawn from the run's seed and where it happens, so an offer is a pure function of the seed and the state. |
| `rift_learns.gd` | The rift learns. |
| `run_random.gd` | Seeded randomness for the run layer. |
