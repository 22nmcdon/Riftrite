# Rebuild phase 5b: the uploaded art in the game

Status: **agreed (2026-09-30); being built.** The playtester uploaded a set of art (the `22nmcdon-art` branch, gathered into `art/` in "Gather the uploaded art into art/, without duplicates"). This phase puts it on the screens that exist: the arena, the act's route, camp and the shops, and the item language. It comes before phase 6, like 3b did, and it doesn't wait on gate 3: the gate 3 build (playtest-13) stays as it is, and this phase ends in a new playtest build.

It changes no fight and no run: the sim, `RunFlow`, and the data's numbers stay as they are. The bench fingerprints and the run report must not move.

## Scope

In:
- the fonts: Cinzel and Alegreya;
- the arena: turned so heroes are at the bottom, drawn on the floating island over the rift sky, with ground tiles, the crumbling tiles, ruins for rocks, and a ring under each unit;
- the route: the act map, one island per day;
- camp: each option's icon and the place's node; the Pedlar's and the Magpie's scenes as their shops;
- the item language: each kind's frame with a glyph, for items, relics, upgrades, vows, paths, and bonds, wherever they show.

Out:
- new figures: heroes and enemies keep today's figures (`art/figures/`);
- animation, sound, and the codex;
- the camp options and route nodes the upload has but the game doesn't (Bloodied Oath, Choose the Ground, Dare, Lay Traps, Meditate, Mentor, Spar, Study, Temper, Track the Elite, events). Their art stays in `art/ui/` for later.

## Decisions

1. **Heroes at the bottom** (the playtester, 2026-09-30). The board is no longer turned sideways. The plane's columns run across the screen and its rows run up it, row 0 (the heroes' back row) at the bottom, as in the arena look test. The sim's flat-top hexes are drawn flat-top. This overturns phase 3's "turned sideways (landscape)".
2. **Cinzel and Alegreya** (the playtester, 2026-09-30). Headings use Cinzel Bold (Cinzel Black for the title). Body text uses Alegreya Regular, and the few semibold and bold spots use Alegreya Bold. Marcellus and Source Sans 3 go. Work Sans stays as the fallback for characters the new fonts lack.
3. **Items get the closest icon** (the playtester, 2026-09-30). Each uploaded icon is its kind's frame with a glyph drawn on it. The glyphs are split out, and every item, relic, and so on takes its **kind's frame** with the **glyph that fits it best**, named in the data (`"icon"`). Glyphs are shared until more are drawn; the frame always says the kind.
4. **The route is the act map** (the playtester, 2026-09-30). The day screen's route step shows the whole act as the map's seven islands, with each day's fights on its island.
5. **Grafts get a rose octagon frame** (the playtester, 2026-09-30), generated in the upload's style by `tools/art/item_glyphs.py`, until one is drawn.

## 1. What's in `art/ui/` and where it goes

| Art | Where |
| --- | --- |
| `arena/backdrop.svg` | behind the arena screen, full bleed |
| `arena/island_frame.svg` | around the board: its inner square is fitted to the board |
| `arena/ground_tile.svg` | the board's ground, tiled under the hexes |
| `arena/collapse_tile.svg`, `collapse_warn_tile.svg` | Rift Collapse: crumbled ground, and the ring about to crumble |
| `arena/props/*.svg` (5 ruins) | rocks (the encounter's and Dig In's) |
| `map/act_map.svg` | the route (section 4) |
| `nodes/fight.svg`, `fight_harder.svg`, `elite.svg`, `boss.svg` | the map's fights, by tier |
| `nodes/camp_waystone.svg`, `camp_chapel.svg`, `camp_hunters_blind.svg`, `camp_rift_scar.svg` | a day's place, on the map and at camp |
| `nodes/magpie.svg` | the Magpie's day at camp |
| `camp/<option>.svg` | each camp option's card |
| `shops/pedlar_scene.svg`, `magpie_scene.svg` | the shop's backdrop at camp |
| `items/frames/*.svg` | each kind's frame (section 5) |
| `items/*.svg` | split into glyphs (section 5) |
| `fonts/Cinzel-*.ttf`, `Alegreya-*.ttf` | `UiStyle` |

`shops/pedlar.svg` and `magpie.svg` are the keepers alone, and the scenes already hold them, so they aren't used yet.

## 2. The fonts

`UiStyle`'s font constants point at the new files: `HEADING_FONT` Cinzel Bold, `TITLE_FONT` Cinzel Black, `BODY_FONT` Alegreya Regular, `SEMIBOLD_FONT` and `BOLD_FONT` Alegreya Bold. Sizes are checked by eye on the screenshots. Cinzel is capitals only and runs wider, so headings may need a smaller size. The Marcellus and Source Sans 3 files are removed.

## 3. The arena

**Turning it (`ArenaView`).** Only the mapping changes; everything draws through it.
- `to_pixel_f`: x across and y up (`_origin + Vector2(x - left, bottom - y) * scale_px`). `to_plane`, `rect_to_pixels`, and `hex_corners` follow.
- `_layout` fits the drawn rect (the board, widened by the hexes' corners at the columns' ends) with room over the top row for figures and bars.
- `_stack_tokens` still stacks by y on the screen, so a hero near the bottom stands in front.
- `faces_left` still turns toward the target's side of the screen. Heroes start facing right and enemies left, as now.
- `ArenaScreen`: the board takes the middle, the side column stays on the right, the log's gutter stays on the left, and the hero bar stays along the bottom. The square board is narrower than today's, which gives the side column more room. The column sits on a navy panel so it reads over the sky.

**Drawing it on the island.** Back to front:
1. The backdrop fills the screen behind the board, the side column, and the gutter; the arena screen draws it instead of the title's.
2. The island frame is scaled so its inner square (measured once from the svg and kept as a constant) covers the board's drawn rect.
3. The ground tile repeats across the board, clipped to the hexes.
4. Hex lines are thin and pale, as in the look test. Placement tints the zones: yours gold, the middle row plain, theirs red, each at low alpha.
5. Rift Collapse: crumbled hexes show the collapse tile, and the ring about to crumble shows the warning tile (`FightFx.draw_ground`'s bands become tiles).
6. Rocks are ruins. A rock's prop is picked by its hex, so the same rock always looks the same (a UI rule; the sim never sees it). Each is sized to the rock's circle and stands on its point like a figure, so a prop stacks with the units.
7. Each unit gets an ellipse under its feet: gold for heroes and red for enemies, as in the look test.

Everything else on the board (shots, areas, numbers, snares, walls, lines) is drawn through the mapping and turns with it. Its colors are checked against the sand and the sky on the screenshots.

## 4. The act map (the route)

`RunDayScreen`'s route step becomes a map view (`ActMap`, new, in `src/ui/widgets/`):
- `act_map.svg` scaled to fit the step's room. The seven island centers are a constant table in svg pixels, measured from the svg: days 1–6 on the six islands, the boss on the last.
- **Each day's island** shows that day's fights as nodes (from `ActDraw`, already known from the act's start), by tier: `fight` (easier), `fight_harder`, `elite`, `boss`. Above the fights sits the day's place node once the day is reached (today's place, or the place a past day camped at); future days show no place, since places are drawn each day.
- **Past days** dim, and the fight fought there is marked (won or lost). **Today's** island glows, and its two fight nodes can be clicked. **Scouted** days show their enemies' figures on hover.
- Clicking or hovering a node opens today's fight card (tier and pay, what it tests, the enemies and their threat lines, Scouted positions) beside the map, with **Fight this**. That's the same card and button as today, so the rules and tests keep one path.
- The Magpie's day shows the Magpie node as that day's place once it's reached.

`RunState` gains nothing. A day's place is the first draw of its camp stream (`Offers.camp`: the seed, act, day, and attempt), so a past day's place is drawn again from its last attempt by a small `Offers.place` that `Offers.camp` also uses. A future day's place isn't shown: a loss replays a day on a new attempt, which can draw a different place.

## 5. The item language

**Splitting the icons.** `tools/art/item_glyphs.py` (new) reads each `art/ui/items/*.svg`, drops the three frame paths, and writes the glyph alone, white on transparent, to `art/ui/items/glyphs/<name>.svg`. The UI tints it with the frame's glyph color. The uploaded icons stay as the source, and the script is re-run when more are added. The upload gives 16 distinct glyphs: braced (shield), casters_first (crosshair; fliers_first is the same), cheaper (asterisk), deep_mend (cross), echo (crescent), ember_heart (flame), fletched_for_wings (feather; light_feet is the same), hold_the_middle (arrow to a line), hollow_crown (crown), opener (vial), pilgrims_lantern (drop), purifying_light (sun), rift_glass_eye (eye), steady_hands (clock), the_tank_first (heart), unbroken_wall (bricks).

**The data.** `items.json` and `relics.json` entries gain `"icon"`: a glyph name. `camps.json`'s options and places gain `"icon"`: a file under `art/ui/`, since the Chapel's node isn't named for `ruined_chapel`. The validator checks each names a file that exists. The sim never reads them.

**The frames by kind.** Charm is a gold circle, tactic a bone shield, sigil a teal diamond, and relic a violet hexagon. Upgrade is a gold arch, path a teal arch, vow a teal arch with gold, and bond two rings. **Grafts have no frame in the upload.** Proposed: `tools/art/item_glyphs.py` also writes `frames/graft.svg` in the same style (a rose octagon), until the playtester draws one.

**Where they show** (`ItemIcon`, new widget: a frame, a glyph, a size):
- the hero bar's Charm, Tactic, and Sigil chips: the item's icon when filled, the bare frame when empty;
- the loadout's stash and slots, the Pedlar's and Magpie's wares, and a relic choice;
- the top bar's relics;
- the upgrade pick (upgrade frame, with a glyph by the upgrade's slot);
- the hero panel: vows (vow frame), paths (path frame), and bonds (bond frame).

**Proposed glyphs** (the playtester can change any; they're data):

| Kind | Item | Glyph |
| --- | --- | --- |
| charm | Frost-Tipped | cheaper (asterisk, as frost) |
| charm | Iron Skin | braced |
| charm | Vital Stone | the_tank_first |
| charm | Whetstone | casters_first |
| charm | Swift Boots | fletched_for_wings |
| charm | Serrated Edge | opener |
| charm | Ember Charm | ember_heart |
| charm | Mending Salve | deep_mend |
| charm | Deep Well | pilgrims_lantern |
| charm | Thorned Mail | unbroken_wall |
| tactic | Casters first | casters_first |
| tactic | Hold your ground | hold_the_middle |
| tactic | Wait to heal | the_tank_first |
| tactic | Plant your feet | braced |
| sigil | Sigil of Haste | cheaper |
| sigil | Sigil of Grief | hollow_crown |
| sigil | Sigil of the Last Breath | steady_hands |
| sigil | Sigil of Reach | purifying_light |
| sigil | Sigil of Echoes | echo |
| graft | Shake It Off | purifying_light |
| graft | Second Wind | deep_mend |
| graft | Sidestep | fletched_for_wings |
| relic | Ember Heart, Hollow Crown, Rift-Glass Eye, Pilgrim's Lantern | their own |
| relic | Bloodstone | ember_heart |
| relic | Warden's Chain | unbroken_wall |
| relic | Gravedigger's Coin | cheaper |
| relic | Hungry Blade | opener |

## 6. Camp and the shops

- Each option card shows its icon (`camps.json`'s `icon`) at its left.
- The camp's heading shows the place's node.
- The Magpie's day shows the Magpie node.
- **A shop** (the Pedlar, or the Magpie's day) shows its scene behind the step. The keeper stands at the left, and the wares are cards over the scene's right side with their icons and prices. Treating wounds and the reroll stay under the wares.

## 7. Clean-up

These leftovers from the old game are in `art/ui/`, and nothing in the rebuild names them:
- `characters/` for Hesk, Odo, Pell, Wren, and Ysolde;
- the old relics in `relics/`;
- the old stop icons in `icons/` (`stop_*`, `gold`, `key`).

Each is checked with a search before it's deleted. Anything still loaded stays.

## 8. Files

- New:
  - `src/ui/widgets/act_map.gd`;
  - `src/ui/widgets/item_icon.gd`;
  - `tools/art/item_glyphs.py`;
  - `art/ui/items/glyphs/`;
  - `art/ui/items/frames/graft.svg`.
- Changed:
  - `src/ui/ui_style.gd` (the fonts, and the icon and frame loaders);
  - `src/ui/arena/arena_view.gd`, `unit_token.gd`, `fight_fx.gd`;
  - `src/ui/screens/arena_screen.gd`, `run_day_screen.gd`;
  - `src/ui/widgets/hero_bar.gd`, `hero_panel.gd`, `glyph.gd`;
  - `src/run/` defs for items, relics, and camps (the `icon` field), and `offers.gd` (`Offers.place`);
  - `tools/validate_data.gd`, `tools/ui_screenshots.gd`;
  - `data/items.json`, `relics.json`, `camps.json`;
  - `CLAUDE.md` (How the UI works), this plan, and `rebuild-build-order.md`.

## 9. Tests

- `test_arena_view.gd`: the mapping turned. A hero's back row is lower on the screen than the enemies' rows, and column 0 is at the left. `to_plane(to_pixel(p)) == p` round-trips, and `hex_at` finds each hex's center. Rock props are the same for the same hex.
- The drag and placement tests go through `to_pixel`, so they should pass as they are. Any that assume sideways positions are fixed on purpose.
- `test_every_encounter_plays.gd` and the log-kind table: unchanged; every kind still has a form on the board.
- A new `test_art.gd`:
  - every `icon` in the data loads as a texture;
  - every kind has a frame;
  - every tier has a node;
  - every place and camp option has an icon;
  - every font file `UiStyle` names loads.
- `test_run_screens.gd`: the route test goes through the map. It clicks today's node, then **Fight this**. A test checks the map shows seven islands with a node for each day's fights, today's clickable and the rest not.
- `test_title.gd` and `test_practice_flow.gd`: whatever the font and layout change moves.
- Bench fingerprints and the run report: unchanged (nothing here reaches the sim or the run).

## 10. Order of work (each step: code, tests, green run, screenshots, commit)

1. Fonts.
2. The arena turned (mapping, layout, the side column), with no new art yet.
3. The arena's art: backdrop, island, ground, zones, collapse tiles, ruins, rings.
4. The item language: glyphs, the graft frame, `icon` in the data, `ItemIcon`, and where it shows.
5. Camp and the shops.
6. The act map.
7. Clean-up, docs (`CLAUDE.md`, this plan's "Built in step N" notes, the build order), HOW-TO-PLAY, the screenshots, and a playtest build.

## Answered

1. **The graft frame** (the playtester, 2026-09-30): a generated rose octagon in the upload's style, until one is drawn. Decision 5.
