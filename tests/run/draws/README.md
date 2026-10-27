# tests/run/draws/

The run's seeded draws: the streams, the testing shop lean, specializations, enemy upgrades, what the rift learns, and the team draft.

## Files

| File | What it is |
| --- | --- |
| `test_enemy_upgrades.gd` | Enemy upgrades in the run: each elite day fight draws 1–2 when the day starts, carried by every enemy in it they change; the fight's kits and names, the save, and the fight card's line. |
| `test_hero_team.gd` | The team: who can be drafted, why a team can't be, the roles that place any team, and the run's team. |
| `test_offers_lean.gd` | The shop lean: RunContent.test_lean weights some items and relics up in the shops' and relic choices' draws, for the run report's test teams only. |
| `test_rift_learns.gd` | The rift learns: each fight's summary kept on its Fought, the habits scored from the last fights, the boss's adds' learned picks on a boss day of an act with rift_learns, the fight with them, the save, and the fight card's line. |
| `test_run_random.gd` | RunRandom: every offer draws from its own stream, seeded by the run seed and where it happens, so skipping one choice never changes a later one. |
| `test_specializations.gd` | Enemy specializations: the data, the draw, the fight's kits and names, the save, and the fight card's line. |
