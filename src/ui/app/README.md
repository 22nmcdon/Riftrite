# src/ui/app/

The app's frame: `Main` (the main scene, `main.tscn`, moving between screens), the look (`UiStyle`: colors, fonts, boxes), the art loader (`ArtFile`), and names for units in a fight.

## Files

| File | What it is |
| --- | --- |
| `art_file.gd` | Every art file the game loads: the file ArtPath names, loaded once and cached. |
| `fight_names.gd` | Display names for a fight's units, and the log's lines with them. |
| `main.gd` | The game's root: the title backdrop, the current screen in the middle, and the hover card and a toast floating over everything. |
| `main.tscn` | The main scene (project.godot's run/main_scene): a full-screen Control running main.gd. |
| `ui_style.gd` | The look, from the playtester's mock: deep navy panels with thin blue-grey rims, a teal accent for what's done or chosen, gold for the primary action and what's current, and cream text. |
