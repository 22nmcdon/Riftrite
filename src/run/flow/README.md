# src/run/flow/

The run's state and rules: `RunState` (saved by `RunSave` as versioned JSON), `RunFlow` (every action), the records file, and the team (`HeroTeam`: who can be drafted, and placing any team by role).

## Files

| File | What it is |
| --- | --- |
| `hero_team.gd` | A team: the three heroes a run or a Practice fight takes, drafted from the roster in data/heroes/<hero>/hero.json. |
| `run_events.gd` | The Event node's rules for RunFlow: a scene's choices, what each one's results do, and the Bloodied Oath. |
| `run_fight_setup.gd` | Building a run's fight for RunFlow: each hero's kit as the run has it, the enemies as the day has them, and the FightSetup that holds it all. |
| `run_flow.gd` | The run's rules: the only thing that changes a RunState, one action at a time. |
| `run_record.gd` | What a fight leaves behind, for RunFlow: RunFlow.record's work after each fight: pay, wounds, deeds and transformations, Tithe, the pick, growing cards and relics, the run's own counts, items ranking up, and the streak. |
| `run_records.gd` | The player's records: the deepest endless floor reached, with the run's seed and vows, in user://records.json beside the run's save, one for each act an endless follows, and the furthest any run has gone through the acts. |
| `run_save.gd` | The run's save: the RunState as JSON, written after every action, read back by the title's Continue. |
| `run_shop.gd` | The shops' rules for RunFlow: opening and closing the Pedlar, the boss shop, and the Magpie; prices, buying, selling, rerolls, treating wounds, transmuting, Hob's shop rules and black market, and buying, selling, and swapping relics. |
| `run_state.gd` | Everything a run is, between fights. |
