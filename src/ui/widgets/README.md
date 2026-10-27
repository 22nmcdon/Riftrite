# src/ui/widgets/

The pieces screens are built from: the hero bar and panel, popups and hover cards, the log, the fight chart, banners, the act map, item icons, portraits, the shop stage, the tactic picker, and toasts.

## Files

| File | What it is |
| --- | --- |
| `act_map.gd` | The act map: the route as the uploaded map, one island a day and the boss's last. |
| `enemy_panel.gd` | The side panel for a hovered enemy: its name, archetype, threat line, stats, and a line per ability, in placement or during the fight. |
| `fight_banners.gd` | A banner over the board for the fight's big moments: a unit entering a phase, the rift starting to collapse, and the end. |
| `fight_chart.gd` | The fight chart, shown above the log: three tabs, a legend, and a bar per hero, largest first, split into colored types. |
| `hero_bar.gd` | The hero bar along the bottom of the screen, from the playtester's mock: one card per hero, in heroes.json's order. |
| `hero_panel.gd` | A hero's panel, laid out and colored after the playtester's mock. |
| `hero_popup.gd` | A hero's details in a fight, opened by clicking the hero while the fight isn't playing: paused or over. |
| `hover_card.gd` | The hover popup: a parchment card beside whatever the mouse is over, showing what it is and does. |
| `item_icon.gd` | The item language: a kind's frame with a glyph drawn on it in the kind's color. |
| `log_panel.gd` | The combat log beside the board: each LogEntry's line as it happens, with names instead of ids and colored by side. |
| `portrait.gd` | A unit's portrait in a box, as the playtester's mock draws them: on a raised navy box, optionally with a soft circle behind. |
| `shop_stage.gd` | A shop's stage at camp: the Pedlar's or the Magpie's scene behind the wares, with the keeper standing in it as in the shops look test, and the wares over the scene's right side. |
| `tactic_picker.gd` | A hero's tactic, in the hero panel's Loadout tab while placing and in the hero popup in a fight: while it can be changed, a button for no tactic and one for each the hero can take; otherwise, the one it took. |
| `toast.gd` | A short message that fades out. |
