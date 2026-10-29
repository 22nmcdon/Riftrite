# tests/ui/

The screens, run headless with time driven by hand (`ArenaScreen._process(delta)`), and `ui_test_kit.gd` (finds and presses controls by text). `test_every_encounter_plays.gd` checks the board plays exactly the sim's fight and shows every log kind; the art tests check the asset contract.

## Files

| File | What it is |
| --- | --- |
| `test_arena_view.gd` | ArenaView and UnitToken: the plane-to-pixel mapping, the board, and a token per unit. |
| `test_art.gd` | The uploaded art in the game: every piece the data or the UI names is there and loads. |
| `test_art_contract.gd` | The art in art/ keeps docs/plans/art/asset-contract.md: every manifest entry names a figure and keeps its points inside its canvas, every PNG has the contract's size, and every texture imports with mipmaps. |
| `test_art_loading.gd` | How the game loads art, against the small files in tests/fixtures/art/: a PNG wins over its SVG, a figure draws at its canvas size whatever its resolution, a boss's canvas is twice the size, the manifest's points place the bars and the shots, portraits... |
| `test_every_encounter_plays.gd` | Every Act 1 encounter plays to its end on ArenaScreen, with fake time: no errors, the same fight the sim runs on its own, every log line in the log panel, and every kind of log entry it produced shown on the board. |
| `test_fight_log.gd` | The log panel, the fight chart, and the banners: names instead of ids, lines colored by side, the chatter hidden, a unit's lines on a click, the chart's bars from FightTally, and banners for a phase, the collapse, and the end; then all of it on ArenaScreen... |
| `test_fight_player.gd` | FightPlayer and the fight on ArenaScreen: live stepping at every speed replays the fight exactly; pause, skip, restart, and seek; smooth drawn positions; and the screen's controls and keys, with fake time. |
| `test_fight_view.gd` | What the fight shows: tokens' bars and status tags from the sim's state, and FightFx's shots, swipes, numbers, and signature names from the log. |
| `test_figures.gd` | The units' figures on the board: every hero and enemy has one, each stands on its unit's point with its bars over its head, faces its target, and the nearer figures are drawn in front. |
| `test_mod_info.gd` | Every card's stat change says its amount: ModInfo's numbers line for kit mods, items, upgrades, relics, and duo bonds. |
| `test_paths_ui.gd` | Paths in Practice: the session keeping each hero's path and stage, the hero panel, choosing a path and stage, the board's figures and tags, placing a transformed Trapper's snares, the fight on screen being the sim's own, and the result's deeds. |
| `test_pixel_filter.gd` | Pixel art, for testing: off by default and remembered, the filter covers the board but not the side column, sits between the board and what stays sharp, takes no input, and leaves the fight the same. |
| `test_placement.gd` | Placement: PracticeSession's remembered formation, moving heroes on ArenaScreen by dragging, legality from the sim, the enemy panel, and the Fight button. |
| `test_practice_flow.gd` | Practice from the title, driven headless through a real Main: title -> encounter list -> placement -> fight -> result -> place again, rematch, watch again, and back. |
| `test_run_screens.gd` | The run on screen, driven headless through a real Main: the title's New run and Continue, vowing, a day, the fight on the arena, the pick after it, a Hunt, the hero bar and panel in a run, and the run's end. |
| `test_tactics_ui.gd` | Tactics in Practice: choosing one in the hero panel's Loadout tab while placing, the board naming it, remembering it, the fight on screen being the sim's own fight with it, what a tactic did showing over the hero, and the result naming them. |
| `test_title.gd` | The game boots to the title; its ways in are the run and Practice. |
| `test_unit_info.gd` | Unit details: every ability has its sentence, one with a reach names it, the numbers lines come from the kit; hovering an enemy fills the side panel, and clicking a hero opens its popup only while the fight isn't playing. |
| `ui_test_kit.gd` | Shared helpers for the UI tests: finding controls by their type or text. |
