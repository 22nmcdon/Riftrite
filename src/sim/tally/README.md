# src/sim/tally/

Read-only counts over a fight's log, shared by the UI and the tools: `FightTally` (the chart) and `ComboTally` (the testing-only combo readout).

## Files

| File | What it is |
| --- | --- |
| `combo_tally.gd` | The combo readout's counts: what each engine did in a fight, read only from the combat log, like FightTally, so it can't disagree with it. |
| `fight_tally.gd` | What each hero has done in a fight, added up from the combat log: the fight chart's numbers and the sim runner's. |
