# tools/bots/

The bots that play runs for the reports: the simple run bot (`run_bot.gd`, which the tests use), and phase 6's random, simple, good, and expert bots (`bot.gd` answers each decision; `run_player.gd` plays a run with them). The good bot places by fitted weights (`placement.gd`, `placement_weights.json`, refit with `placement_data.gd` and `fit_placement.py`) and judges choices by practice fights (`practice.gd`). Details: `docs/plans/phases/rebuild-phase6-bot-tuning.md`.

## Files

| File | What it is |
| --- | --- |
| `bot.gd` | A run bot: it answers each decision tools/bots/run_player.gd asks of it, and never changes the run itself. |
| `expert_bot.gd` | The expert: the good bot, except that it tries its candidate formations in the real fight and keeps the one worth most. |
| `fit_placement.py` | Fits the good bot's placement weights from tools/bots/placement_data.gd's CSV, in plain Python. |
| `good_bot.gd` | The good bot: it places by reading the fight, never by fighting it, and judges its choices by practice fights: each option is tried on a copy of the run and is worth what the coming fights on the act map are worth after it, plus the shards it gains or spends. |
| `placement.gd` | The good bot's placement: it reads a fight's setup and scores a formation by features of it, never by fighting it. |
| `placement_check.gd` | Checks the good bot's placement: for each encounter, teams drawn as placement_data.gd draws them but from another stream, each placed by placement.gd's best formation and fought on a practice seed; against the same teams placed at random. |
| `placement_data.gd` | Placement data for fitting the good bot's weights: for each encounter of every act, random legal formations of a random team, each fought on a practice seed. |
| `placement_weights.json` | The good bot's placement weights: one per feature times context, context-major, fitted by tools/bots/fit_placement.py on tools/bots/placement_data.gd's practice fights; water_weights on the fights with water alone, for placement.gd to score those by;... |
| `practice.gd` | Practice fights: how much a fight is worth to the heroes, and how much a choice is worth to a run, for the good bot's judgments and the expert's tries. |
| `random_bot.gd` | The random bot: a random legal answer to every decision, from its own SimRng seeded by the run's seed, so a run repeats. |
| `run_bot.gd` | The simple run bot: plays whole runs through RunFlow, for tests and pacing, not for a win rate. |
| `run_player.gd` | Plays a run with a bot: one RunFlow action at a time, each one the bot's answer to what the run is waiting on. |
