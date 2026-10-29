# src/ui/arena/

The board: `ArenaView` (the plane in pixels, placement, tokens), `UnitToken` (a unit's figure, bars, and tags), `FightFx` (shots, swipes, numbers, areas), `FightPlayer` (steps and seeks the fight), and `FigureArt` (figures and the manifest).

## Files

| File | What it is |
| --- | --- |
| `arena_view.gd` | The arena on screen: one view for placement and the fight. |
| `fight_fx.gd` | The momentary things on the board during a fight, made from the log entries the FightPlayer hands out and drawn over the tokens. |
| `fight_player.gd` | Plays a fight live: it owns a CombatSim built from the fight's setup and steps it as real time passes, 20 ticks a second at 1x. |
| `figure_art.gd` | The figures the board draws for units. |
| `pixel_filter.gd` | The arena as pixel art, for testing: laid over the board, it redraws what's under it in square blocks, each the average of the screen pixels it covers, so the arena reads as about 360 pixels tall and is scaled up crisp. |
| `unit_token.gd` | One unit on the board: its figure, standing where the unit is on the plane, over a small ring, with its short name under it. |
