# src/run/flow/

The run's state and rules: `RunState` (saved by `RunSave` as versioned JSON), `RunFlow` (every action), the records file, and the team (`HeroTeam`: who can be drafted, and placing any team by role).

## Files

| File | What it is |
| --- | --- |
| `hero_team.gd` | A team: the three heroes a run or a Practice fight takes, drafted from the roster in data/heroes/<hero>/hero.json. |
| `run_flow.gd` | The run's rules: the only thing that changes a RunState, one action at a time. |
| `run_records.gd` | The player's records: the deepest endless floor reached, with the run's seed and vows, in user://records.json beside the run's save, one for each act an endless follows, and the furthest any run has gone through the acts. |
| `run_save.gd` | The run's save: the RunState as JSON, written after every action, read back by the title's Continue. |
| `run_state.gd` | Everything a run is, between fights. |
