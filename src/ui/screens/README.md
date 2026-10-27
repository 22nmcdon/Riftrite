# src/ui/screens/

One `UiScreen` at a time: the title, Practice's encounter list, the arena (placement, the fight, the result), the run's start (the draft and vows), and the run's day.

## Files

| File | What it is |
| --- | --- |
| `arena_screen.gd` | Placement and the fight on one screen: placement, then the fight played live by a FightPlayer on the same board. |
| `encounter_list_screen.gd` | Practice's list of fights: every encounter in encounters.json's order, a card each with its name, what it tests, its act and days, and its enemies. |
| `run_day_screen.gd` | A day of the run between fights: the top bar, the day's step in the middle, and the hero bar along the bottom. |
| `run_start_screen.gd` | A new run: the draft, then each drafted hero vows to one of its three paths, then Into the rift. |
| `title_screen.gd` | The title, over the backdrop: Continue, New run, and Practice. |
| `ui_screen.gd` | A screen of the game. |
