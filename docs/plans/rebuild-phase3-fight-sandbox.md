# Rebuild phase 3: the fight sandbox (build plan)

Status: **built (2026-09-28); waiting on playtest gate 1** (playtest build 4). Approved with the answers under Decisions; each section's "Built in step N" notes say what was built. What the playtest finds goes under "Playtest gate 1" at the end. Phase 3 of `docs/plans/rebuild-build-order.md`. Design sources: `rebuild-arena.md` (placement, the free-moving fight, areas, the shrinking arena), `rebuild-enemies.md` (fair fights: threats shown before placing), and `rebuild-run.md` (the fight card). It builds on the arena sim (phase 1, `rebuild-phase1-arena-sim.md`) and the content and sim runner (phase 2, `rebuild-phase2-heroes-enemies.md`).

**Goal:** a **Practice** mode on the title screen where you pick an Act 1 encounter, place Brannoc, Maren, and Vell on the hex board, and watch the fight play out on the free-moving plane, readable enough to tell who is attacking whom and why. All art is placeholder (decided: the art rehaul is phase 7).

**Done when** (the build order's gate): **Playtest gate 1** — a single arena fight with the base heroes is fun and readable. That's judged by you in a playtest build. This plan's own bar, before the playtest: every log kind the Act 1 content produces has a visible form on the board or in the log panel, and a full fight of every encounter plays to its end in the UI headless with no errors.

## Scope

**In phase 3:**

- Practice mode: pick an encounter, place, fight, see the result, place again.
- The hex board for placement, and the arena view for the fight (the same view, two modes).
- Fight playback: movement, attacks and shots in flight, area warnings, pushes and leaps, Rift Collapse, deaths, summons, statuses, HP, Shield, and mana bars, signatures.
- Controls: pause, speed, and restart.
- Unit info: hover a unit (placement or fight) for its threat line or role, stats, and what its abilities do.
- The fight log panel (readable lines, filtered) and the per-hero fight chart.
- The screenshot tool and tests for all of it.

**Not in phase 3:**

- Paths, vows, and transformations (phase 4; the sandbox gains a path picker then).
- The run, camp, fight choice, relics, and saves (phase 5). Practice keeps nothing between sessions: the formation and the speed are remembered only while the game is open (Decisions).
- Real art, animation beyond moving and tweening shapes, sound (phase 7).
- Changes to the sim's rules or content numbers. A playtest finding that needs one goes back to the plans.

## Decisions this plan builds on

- **The sandbox stays in the game as Practice** on the title screen, and can stay rough until the art rehaul (build order, Decisions).
- **The sim is separate from presentation** (CLAUDE.md rule 2): the UI reads sim state and the log; it never changes the fight.
- **Every change in a fight is in the log with its source** (rule 4), and the log alone replays every position (phase 1, section 11). So anything the player sees can be traced to a log line.
- **Enemy positions and threats show before you place** (enemies plan: fair fights).
- **Your last formation is remembered** (design: the arena).
- **A unit without a mana signature shows no mana bar** (heroes plan).
- **Leaps and pushes are instant in the sim; only the UI animates them** (arena plan).

## What comes back from the old UI

The old fight screen (in git history, the commit before phase 0's gut) was a row-based card view, but its playback and panels didn't depend on items or rows. The build order marked several of them **Keep (adapt)**; phase 0 removed them because nothing could run them. They come back from git history, adapted:

| Old piece | What it did | In phase 3 |
| --- | --- | --- |
| `FightPlayer` | Re-ran a fresh `CombatSim` from the setup and stepped it live: `advance(seconds)` returns the new log entries; speeds 0.5×, 1×, 2×, 4×; pause; skip to the end. Tested at every speed to replay the recorded log exactly | Back nearly as it was, plus rewind (section 4) |
| `FightTally` | The chart's totals, built only from log entries as they're shown, so the chart and the log always agree: damage by type, support (healing, Shield), taken (to HP, absorbed) | Back, minus items and relics, moved to `src/sim/` so the sim runner uses it too |
| `FightChart` | Tabs (damage, support, taken) of stacked bars per hero, with a breakdown on hover | Back as it was |
| `FightBanners` | A queue of short banners (phases, discoveries), each shown a moment scaled by speed | Back, for phases, the collapse, and the fight's end |
| `FightNames` | Unit ids to display names ("Rift Pup 2") and colored log lines | Back, for the new ids (`rift_pup#2`) |
| Fight screen keys | Space pauses, 1–4 set the speed, S skips to the end, L toggles the log | Kept |
| `FightFx` | Tweens on character figures: swings, projectiles, hit flashes, floating numbers, falls | Rewritten for tokens on the plane (section 5); its speed scaling and "kill the old tween" rules kept |
| The UI test kit | Headless helpers to find and press buttons and read labels on a real `Main` | Back, extended for the board (clicking hexes, dragging tokens) |

What doesn't come back: the row layout, unit cards, item panels, and the old figures and character art (phase 7 replaces those).

## 1. The flow

```
Title ──Practice──> Encounter list ──pick──> Placement ──Fight──> Fight ──end──> Result
                        ^                        ^                                 │
                        └──────── Back ──────────┴──── Place again / Rematch ──────┘
```

- **Encounter list:** the nine Act 1 encounters in `encounters.json`'s order. Each card shows the name, what it tests, its days, and its enemies (name, archetype, threat line).
- **Placement:** the board with the encounter's enemies and rocks already on it; the three heroes start on the last formation used (or the runner's "guarded" formation the first time). You move heroes between hexes of your zone; **Fight** is enabled when all three stand on legal hexes.
- **Fight:** the same board, now the free-moving plane, playing the fight live. Controls: pause, speed (0.5×, 1×, 2×), skip to the end, and restart.
- **Result:** victory, defeat, or tie (a tie counts as a win), the fight's length, and the fight chart. **Place again** returns to placement with this formation; **Rematch** replays the same placement with the next seed (seeds only change crits); **Back** returns to the list.

**Built in step 8** (`src/ui/screens/encounter_list_screen.gd`, `Main`'s navigation, the title's Practice button, the result on `ArenaScreen`, `tests/ui/test_practice_flow.gd`):

- **The title** has Practice (the primary button) above Quit.
- **The encounter list:** nine cards in `encounters.json`'s order, three to a row, over the title backdrop.
  - Each card has the name, "Tests … · Days 1-3", one line per kind of enemy ("3 × Cinder Moth (caster): Burns whoever stands together"), and "Place your heroes".
  - Back returns to the title.
- **`Main`** moves between the screens on their signals: title, then list, then arena. The arena's Back returns to the list.
  - Practice's session is made, and the content loaded, the first time Practice opens. It then lasts while the game is open: the formation, the speed, the log's state, and the seed.
- **The result is on the arena screen, not a screen of its own** (section 9 put it there). When the fight ends it takes the controls' place in the side column:
  - the outcome and length ("Victory in 39.1s");
  - the seed ("it only changes crits");
  - how each hero came out ("Brannoc 120/420 HP · Maren fell · Vell 300/300 HP");
  - the fight chart, in full;
  - **Rematch** (the same placement, the next seed, which the session keeps) and **Watch again** (the same fight from the start).
  Place again, Log, and Back stay under it. The result is filled in once when the fight ends, and cleared by a restart or rematch.
- **The chart fits the side column:** its tabs are 14px and its legend is tighter, so the board keeps its size at the end (a test checks the width).
- **Mutation checks:** all 24 changes to the list, the navigation, the seed, and the result are caught. 3 survived at first: 2 got tighter tests, and 1 redundant guard was removed.

## 2. The board

- **One view, `ArenaView`, for both modes.** It maps the plane to pixels: 1 hex (1000 units) = `hex_px` pixels, sized to fit the screen (about 120 px at 1920 × 1080 for the 8 × 7 board). Heroes' rows at the bottom of the screen, enemies' at the top (the sim's row 0 is the heroes' back row).
- **Placement mode** draws the flat-top hexes (`HexGrid` gives every center), shaded by zone: yours, the neutral row, theirs. Rocks are drawn as their circles.
- **Fight mode** keeps the hex outlines faint (distances are still counted in hexes) and draws the plane: rocks, units, and crumbling ground.
- **Units are placeholder tokens:** a circle of the unit's radius (400, so they read as big as they are), colored by side, with a short label (the hero's initial, or the enemy's short name) and a small role or archetype glyph. Fliers get a shadow offset. Summons are drawn smaller-labelled but the same size, since they are.
- **Everything is drawn with `_draw()`** on a few layers (ground, areas, units, shots and effects, overlays), not one node per hex. Units are nodes (for hover and tweening); shots and floating numbers are pooled.

**Built in step 2** (`src/ui/arena/arena_view.gd`, `unit_token.gd`, `tests/ui/test_arena_view.gd`):

- **`ArenaView.show_setup(setup, content)`** draws a fight's board, rocks, and a `UnitToken` per unit on its hex. `set_mode` switches between placement (hexes shaded by zone) and fight (faint hex lines).
- **The mapping:**
  - `to_pixel`, `to_plane`, and `hex_at` (which uses `HexGrid.nearest_hex`, so the hex under a pixel is exactly the sim's).
  - `hex_px` is the size of a hex on screen; about 117 px at 1920 × 1080.
  - A flat-top hex's corners reach 77 units past the plane's sides, so the drawn area (`drawn_rect`) is that much wider than the board, and nothing is clipped.
- **Token labels:** a hero's id ("Vell", not "Sister"), or the last word of an enemy's name ("Pup", "Sentinel"). Heroes are brass, enemies violet. Fliers sit lifted over a shadow.
- **Screenshots:** `tools/ui_screenshots.gd` now also renders the board: Sentinel Gate in placement mode and Moth Cloud in fight mode, with Brannoc guarding.
- **Mutation checks:** all 13 changes to the mapping, fitting, and tokens are caught.

## 3. Placement

- **Moving a hero:** drag a hero token to a hex. A hero dropped on another hero swaps them. Illegal hexes (outside your zone, on a rock) refuse the drop and flash. (Clicking a hero opens their details instead, Decision 3, so there's no click-to-move.)
- **Legality comes from the sim:** the screen builds the formation, then `Encounters.setup` and `FightSetup.validate`; the Fight button shows the first error if there is one. The UI never keeps its own copy of the rules.
- **Enemies are shown where they'll stand.** Hovering one opens its panel at the side of the screen (section 7). Nothing is drawn on the board for its reach: the panel says it ("Pounces on your weakest back-liner within 4 hexes"), and reading it is the player's job (Decisions).
- **Remembered formation:** one formation for all encounters, for this session only. The last formation you fought with is used again when you open any encounter; if a hex is now illegal (a rock), that hero goes to the nearest free legal hex (Decisions).

**Built in step 3** (`src/ui/practice/practice_session.gd`, `src/ui/screens/arena_screen.gd`, `src/ui/widgets/enemy_panel.gd`, `tests/ui/test_placement.gd`):

- **`PracticeSession`** holds the remembered formation, and asks the sim whether a formation is legal (`errors()`: `Encounters.setup`, then `FightSetup.validate`). `formation_for` places each hero, in heroes.json's order, on its remembered hex or the nearest legal free one. Ties go to the lower hex index, which counts column by column. The first formation is the runner's "guarded".
- **`ArenaScreen`** shows the board with a side column: the enemy panel, any error, Fight, and Back.
  - **A drop** is tried on a copy of the formation and kept only if the sim finds it legal; otherwise the hex flashes for half a second.
  - **Dragging:** only heroes can be dragged, and only while placing. A drop on a token counts for the hex under it, and a drop off the board does nothing.
  - **Fight** remembers the formation and hands the `FightSetup` on (`fight_requested`; step 4 plays it).
- **`EnemyPanel`** (hover an enemy): name, archetype, threat line, and stats. The abilities' text comes in step 7.
- **Screens can hide the title backdrop** (`UiScreen.shows_backdrop`); the arena does, so the board reads cleanly.
- **Mutation checks:** all 23 changes to placement's logic are caught, bar one that can't change anything: a token forwarding the drop's position to the view's "can drop" check, which ignores the position.

## 4. Fight playback

**Step the sim live (decided).** A `FightPlayer` owns the `CombatSim`, built from the placement's `FightSetup`, and advances it tick by tick as real time passes (20 ticks a second at 1×). Each frame the view reads the sim's state for where things are, and reads the log entries added since the last frame for what happened.

- **Why live and not "run the fight, then replay the log":**
  - The sim is fast enough: the phase 2 swarm is the worst case at about 23 ms of sim per second of fight, so 4× costs under a tenth of each second.
  - Reading `UnitState` for positions, HP, Shield, mana, and statuses is exact and needs no second model of the fight in the UI. The log is only used for what's momentary (a shot fired, an area warned or landed, a push, a number to float).
  - Rewind still works: the sim is deterministic, so "back to 10s" is a fresh sim from the same setup run to tick 200 (a few milliseconds).
- **Smooth motion:** units are drawn between their positions at the last two ticks (interpolated by how far into the next tick real time is), so 20 ticks a second looks like 60 frames. Pushes, pulls, leaps, charges, and hops are tweened over a few frames from the log's from and to points instead, since the sim moves them instantly.
- **Time is only ever given to the player by `FightPlayer.advance(real_seconds)`** (as in the old player), so tests drive a fight with fake time and no frame timing.
- **Speeds:** 0.5×, 1×, and 2×, and pause. A fight starts playing at once, at the chosen speed, and the speed is remembered (Decisions). Keys: Space pauses, 1–3 set the speed, S skips to the end, L toggles the log.
- **Skip to the end** runs the rest of the fight at once and shows the end state without animating the entries it skipped (the old screen skipped animation for large batches the same way).
- **The UI never writes to the sim.** `FightPlayer` is the only thing that calls `step()`.

**Built in step 4** (`src/ui/arena/fight_player.gd`, `ArenaScreen`'s fight, `tests/ui/test_fight_player.gd`):

- **`FightPlayer`:** the old player, adapted.
  - `advance(seconds)` steps whole ticks and returns the new log entries, at 0.5×, 1×, or 2×; pause; `skip_to_end`.
  - `seek(tick)` and `restart()` build a fresh sim and run it there.
  - `drawn_position(unit)` draws each unit between where it stood before the last step and where it stands now.
  - A test plays a fight at every speed, 60 frames a second, and gets the recorded log line for line. Seeking gives the same units and log as playing straight there.
- **On `ArenaScreen`:** Fight switches the board to fight mode and starts playing at the session's speed.
  - **The side column:** a clock; Pause/Play and the three speeds (the chosen one is remembered in the session); Skip to end; Restart; the outcome line at the end; and Place again, back to placement with the same formation.
  - **Keys:** Space, 1–3, and S. The hint under the heading switches to them during the fight.
- **The view** (`sync_fight`) moves each token to where the player draws it, gives each summon a token as it joins, and hides the fallen (step 5 fades them).
- **Not yet:** bars, shots, areas, and the rest of section 5 come in step 5; tokens simply move for now. Displaced units jump to their new spot, since the smoothing only covers one tick; step 5 tweens them. The full result screen comes in step 8.
- **Mutation checks:** all 23 changes to the player, the controls, and the view's syncing are caught. Two survived at first and got tighter tests, and one redundant check was removed.

## 5. What the fight shows

Each item names the sim state or log entries it comes from. Anything a player could ask "why?" about has a log line behind it.

| On the board | From |
| --- | --- |
| Unit tokens moving, facing their target | `UnitState.pos`, `target` |
| **Target lines** (thin, faint; brighter for Taunt): on hover, and for all units with a toggle; for testing, and may go later (Decisions) | `UnitState.target`, Taunt status |
| HP bar and Shield overlay above each unit | `hp`, `max_hp`, `shield` |
| **Mana bar** under the HP bar, only for units with a mana signature | `mana`, `mana_cap` |
| Cast bar while a signature is being cast | `CAST`, `CAST_CANCELLED` |
| Signature name popping over the unit as it fires | `FIRE` of a signature |
| Status icons under the bars (Root, Stun, Slow, Taunt, Silence, Marked, Engaged, Undying, Burn, Poison, Bleed with stacks) | `UnitState.statuses` |
| Melee hits: a short swipe from attacker to target | `DAMAGE` from a basic attack in reach |
| **Shots in flight:** a dot or streak travelling to the target, landing at the logged tick | `SHOT`, `SHOT_FIZZLED` |
| **Area warnings:** the shape outlined and filling up until it lands, then a flash | `AREA_WARNING`, `AREA_LANDED` |
| Floating numbers: damage (crits bigger), heals, Shields | `DAMAGE`, `HEAL`, `SHIELD`, `STATUS_DAMAGE` |
| Pushes, pulls, leaps, charges, hops: tweened moves, with a stun star when a push is stopped | `PUSH`, `LEAP`, `CHARGE`, `HOP` |
| Engage: a small link between an engager and the unit it holds | Engaged status and its source |
| Auras: a faint ring on the holder while it's active | `AURA` |
| **Rift Collapse:** the next ring striped when warned, darkened when crumbled | `COLLAPSE_RING`, `sim.safe` |
| Summons appearing, deaths fading out | `SUMMON`, `DEATH` |
| Phases: the unit's name changes and a banner shows the phase | `PHASE` |
| The fight clock, and a banner at 45s ("The rift collapses") | `sim.tick`, `COLLAPSE_RING` |

- **Unit details** follow section 7: hover an enemy for its side panel at any time; click a hero while the fight isn't playing (placement, paused, or over) for its popup.

**Built in step 5** (`src/ui/arena/fight_fx.gd`, `UnitToken.show_state`, `tests/ui/test_fight_view.gd`):

- **Tokens read the unit's state every frame:**
  - an HP bar (green for heroes, red for enemies) with any Shield after it;
  - a mana bar only for a unit with a mana signature;
  - a cast bar while a signature is cast;
  - a tag per status ("STUN", "BRN 4").
  The board keeps a third of a hex of room above it for the top row's bars.
- **`FightFx`** turns the log into what the table above lists. Everything runs on the fight's own clock (`FightPlayer.drawn_time`), so it pauses and changes speed with the fight.
  - **Over the tokens:** shots in flight (a fizzle removes its own), melee swipes (only when attacker and target are within reach; a shot or area shows its own), floating numbers, signature names and phase names, a ghost where a unit fell, a pulse where a summon appears, and aura rings.
  - **On the ground, under the tokens:** area warnings filling until they land and then a flash, colored by the caster's side (so Vell's Hearthlight is brass, not hostile); crumbled ground dark and the next ring striped; target lines; Taunt lines; and Engage links.
  - **Pushes, leaps, charges, and hops** slide over 5 ticks from where the unit was.
  - **A skip or seek** (more than 60 entries at once) clears the board's effects instead of animating them.
- **Target lines:** a "Target lines (for testing)" toggle and the T key show every unit's; hovering a unit shows its own.
- **Not in this step:**
  - the banners (a phase, the collapse at 45s, the end) come with the log panel in step 6;
  - the enemy panel's and heroes' details are step 7.
- **Tests:** a test plays the whole chaos fight with every frame drawn, and checks it shows every kind of effect and a slide. Mutation checks: all 33 changes to the effects, bars, and toggles are caught (four needed an added test).

## 6. The log panel and the fight chart

- **The log panel** is a side panel that can be hidden, showing `LogEntry.to_text()` lines as they happen. By default it hides the chatter (`MOVE`, `STOP`, `TARGET`) and shows everything else; a toggle shows all. Clicking a unit filters the panel to lines about it. Lines are colored by side.
- **The fight chart** shows, per hero, damage dealt, healing and Shield given, and damage taken, live during the fight and in full on the result screen.
- **Its numbers come from one place:** a small pure `FightTally` in `src/sim/` that reads a log (the same counting `tools/sim_report.gd` does now). The sim runner switches to it, so the chart and the runner can't disagree.

**Built in step 1** (`src/sim/fight_tally.gd`, `tests/sim/test_fight_tally.gd`):

- **The old tally, adapted:** no items; no relics' bar until relics return in phase 5. It's made from a `FightSetup` (`make`, or `of_fight` for a whole log), so the runner can use it without a live sim.
- **Basic attacks** are the hero's own basic attack (its kit's, or a phase's), not fired by an event. Everything else, signatures and passives included, is "Abilities".
- **A damage-over-time status outside Burn, Poison, and Bleed** counts as "Abilities" rather than being dropped, and a test checks every such status in the data has a family.
- **The sim runner** now takes damage dealt and taken from the tally. Its output on three encounters is identical to before the switch.
- **Mutation checks:** every change to the counting is caught. Two can't be: dropping the tie order in `sorted` and in `breakdown`, since Godot sorts arrays this small with a stable insertion sort.

**Built in step 6** (`src/ui/fight_names.gd`, `src/ui/widgets/log_panel.gd`, `fight_chart.gd`, and `fight_banners.gd`, `tests/ui/test_fight_log.gd`):

- **`FightNames`** (the old one, adapted) turns ids into names in every line:
  - heroes go by their token's name ("Brannoc");
  - copies are numbered from their id (`rift_hound#2` is "Rift Hound 2"), and the first copy is "Rift Hound 1" when the fight starts with several;
  - summons are named as they join, and never rename anyone already written.
  The chart's tally reads the same names, so a summon's hits on a hero name it too.
- **The log panel** is a column beside the controls, with the chart on top and the log under it.
  - Open by default in a fight; its Log button or L hides it, and the session remembers that (like the speed).
  - Lines are colored by the side that did it. Deaths are red, heals green, Shields frost, the collapse ember; "fires" lines and auras are dimmer; the fight's start, end, and phases are bold.
  - "Show movement and targeting" shows the chatter (`MOVE`, `STOP`, `TARGET`), hidden by default.
  - **Clicking a unit** (let go of the left button on its token) filters the log to lines by it or aimed at it; clicking it again, or "Show everyone", lifts the filter. It works at any point in the fight; placement's clicks are step 7's.
  - The log keeps every entry, hidden or not, so a skip fills it in and changing a filter rewrites it from the start.
- **The chart** is the old `FightChart` without the relics' bar: three tabs, a legend, a bar per hero split by type, and the breakdown on hover. It refreshes as entries come in while the column is open, and catches up when it opens.
- **Banners** over the board, one at a time, 1.5s each (0.75s at 2x), waiting while the fight is paused: a phase ("Name: phase"), "The rift collapses" when the first ring crumbles, and the end ("Victory", "Defeat", or the tie's line). After a skip, only the end's banner shows. A restart starts the log, chart, and banners over.
- **Tests:** the log's lines match `FightNames.text` for every shown entry, live and after a skip; the chart's tally equals `FightTally.of_fight` on the same log; the collapse banner shows at 45s in Witch Circle.
- **Mutation checks:** 66 changes to names, the log, the chart, the banners, and the screen's wiring are caught (16 survived at first: 9 got tighter tests, and 3 redundant checks were removed). Two can't change what's shown, since they only save work each frame: `learn` skipping when nobody joined, and the screen skipping an empty batch.

## 7. Unit info

**How you see it (decided):**

- **Enemies:** hovering an enemy, in placement or during the fight, opens its panel at the side of the screen: name, archetype, threat line, stats, and its abilities. It closes when the pointer leaves.
- **Heroes:** clicking a hero while a fight isn't actively playing (placement, paused, or over) opens a popup with their details: role, stats, and abilities, plus live HP, Shield, mana, and statuses when there's a fight. Clicking elsewhere closes it. While the fight plays, clicking a hero does nothing.
- **What's in a unit's details:** its name, role or archetype, its threat line (enemies), its stats, and one line per ability: basic attack, signature (with its trigger: "at 80 mana", "at fight start"), passives, and traits. During a fight, also its live numbers, statuses, and last few log lines.

**Where the ability text comes from (decided: (a) plus a numbers line).** Kits have names but no player-facing text today. The two options were:

- **(a) Hand-written text in the data:** an optional `"text"` on each ability and passive in `heroes.json` and `enemies.json` ("Taunts enemies within 2 hexes for 3s; he has x1.5 DEF while any is taunted"). Reads best, and it's content, so it stays data (rule 3). It can drift from the numbers after tuning; a test can check that every kit has text, but not that it's right.
- **(b) Generated from the effect data:** a describer in `src/sim/` that writes "Deals 100% ATK" or "Taunts enemies in a 2-hex circle around him for 3s". Always true to the numbers, but stiffer, and it needs a describe function for every effect, trigger, and area shape.

So: **(a) for the sentence, plus a generated numbers line** under it from what's easy and exact (damage per hit with `ValueBreakdown`, the cooldown or mana cost, ranges). The sentence says what it's for; the numbers stay true. Since the board never draws reach, **every ability with a reach says it in its sentence** ("within 4 hexes"), and a test checks those sentences name the kit's reach.

**Built in step 7** (`src/ui/unit_info.gd`, `src/ui/widgets/hero_popup.gd`, `EnemyPanel`, the `"text"` in `heroes.json` and `enemies.json`, `tests/ui/test_unit_info.gd`):

- **The data:** every basic attack, signature, and passive of the three heroes and nine enemies has a `"text"` (`AbilityDef.text`, `PartDef.text`; the sim never reads it). The sentences say what it's for and name every reach. The numbers stay out of them, so tuning can't make them wrong.
- **`UnitInfo`** builds a unit's details: a line per basic attack, signature, passive, trait, and phase, each with its sentence and a numbers line generated from the kit.
  - The numbers line covers when it fires (cooldown, mana, trigger), its cast time, its reach, and what it does. Amounts are worked out from the kit's stats: "14 damage (100% ATK)", "heals 40 (20 + 100% MGK)", "2-hex circle around it", "Taunt 3s", "4 Burn".
  - **Traits** are rules, not content, so their sentences are fixed in `UnitInfo`, with the unit's name ("When a foe comes within 1 hex, Maren hops a hex away from it."). A phase gets a numbers line only ("Below 80% HP · new signature: …").
  - **The reach test:** `reaches()` lists a ranged basic attack's range, a signature's reach (unless it's on the unit itself), every area's size, and a damage bonus's "within". Every sentence has to name each of them as "N hex". All 18 in the Act 1 kits do.
- **The enemy panel** adds a line per ability under the stats, and during a fight the unit's numbers now: HP, Shield, mana, and its statuses. These refresh every frame while it's hovered; summons count too.
- **The hero popup:** clicking a hero while the fight isn't playing (placement, paused, or over) opens it beside the hero, or to its left near the board's right edge, kept on the board.
  - It shows the name and title, role, stats, and the lines; in a fight, also the numbers now and the last three log lines about them.
  - A click on the bare board or on an enemy closes it, and so do the fight playing on and Place again. While the fight plays, a click on a hero only filters the log.
- **Clicks are the view's now:** it finds the token under the pointer (the top one) and reports it, or the bare board.
- **Checks:** the bench's log fingerprints are unchanged. Mutation checks: all 79 changes to the details, the panels, the popup, and the clicks are caught. 13 survived at first: 9 got tighter tests, and 4 bits of redundant code were removed.

## 8. Placeholder look

- Uses the existing `UiStyle` palette and theme, `HoverCard`, and `Toast`. No new art files; everything on the board is drawn shapes and text.
- Heroes in warm colors, enemies in cold ones; a unit's side is always readable from its color alone.
- The old `Figure` and `CharacterArt` are left alone (they belong to the old art and go in phase 7).

## 9. Files

**New:**

| File | What it holds |
| --- | --- |
| `src/sim/fight_tally.gd` | per-unit damage dealt, healing and Shield given, damage taken, from a log (the old `FightTally`, shared with the sim runner) |
| `src/ui/practice/practice_session.gd` | Practice's state: the chosen encounter, the formation, the seed, the remembered formation |
| `src/ui/screens/encounter_list_screen.gd` | the list of encounters |
| `src/ui/screens/arena_screen.gd` | placement and fight on one screen: the board, controls, side panels, result |
| `src/ui/arena/arena_view.gd` | the board: plane-to-pixels mapping, hexes, zones, rocks, ground |
| `src/ui/arena/unit_token.gd` | one unit's token, bars, and status icons |
| `src/ui/arena/fight_player.gd` | owns the sim, advances time, hands new log entries to the view (the old `FightPlayer`, plus rewind) |
| `src/ui/fight_names.gd` | display names and colored log lines (the old `FightNames`) |
| `src/ui/widgets/fight_banners.gd` | the banner queue (the old `FightBanners`) |
| `src/ui/arena/fight_fx.gd` | the momentary things: shots, swipes, area warnings, floating numbers, tweened pushes |
| `src/ui/widgets/log_panel.gd`, `src/ui/widgets/fight_chart.gd` | the side panels (the chart is the old `FightChart`) |
| `tests/ui/ui_test_kit.gd` | the old headless UI helpers, plus board clicks and drags |
| `src/ui/unit_info.gd` | builds a unit's details text |
| `src/ui/widgets/enemy_panel.gd`, `src/ui/widgets/hero_popup.gd` | the enemy side panel on hover, the hero popup on click |

**Changed:** `title_screen.gd` (a Practice button), `main.gd` (the new screens), `tools/sim_report.gd` (uses `FightTally`), `tools/ui_screenshots.gd` (the new screens), `heroes.json` and `enemies.json` (ability text), and their defs (reading `"text"`).

## 10. Tests

UI tests run headless and drive time by hand, so they're deterministic.

| Test file | Covers |
| --- | --- |
| `test_fight_tally.gd` | the tally's sums match the log on the chaos fight and a content fight; the runner's numbers are unchanged |
| `test_practice_flow.gd` | title → list → placement → fight → result → place again / rematch / back, driven headless |
| `test_placement.gd` | legal and illegal drops, swaps, the Fight button's state and error text, the remembered formation (and a now-illegal hex); nothing on the board shows an enemy's reach |
| `test_arena_view.gd` | plane-to-pixel mapping both ways; hex centers land where `HexGrid` says; heroes at the bottom |
| `test_fight_player.gd` | fake time advances the right number of ticks at 0.5×, 1×, and 2×; pause; skip; restart; rewinding gives the same state as running straight there; the chosen speed is remembered; a fight starts playing |
| `test_fight_view.gd` | in a small scripted fight: tokens sit where the sim says (scaled); bars match HP, Shield, mana; no mana bar without a mana signature; a shot, an area warning, a push, a summon, and a death each get their visual and lose it on time |
| `test_every_encounter_plays.gd` | each Act 1 encounter played to the end through `ArenaScreen` with fake time, no errors, and every log kind it produced was handed to a visual or the log panel |
| `test_unit_info.gd` | every hero and enemy kit gets details with every ability; every ability has text, and one with a reach names it; hovering an enemy opens the side panel; clicking a hero opens the popup only while the fight isn't playing |
| screenshots | `tools/ui_screenshots.gd` gains the list, placement, a fight mid-way (with an area warning up), and the result |

**Built in step 9** (`tests/ui/test_every_encounter_plays.gd`, `tools/ci/HOW-TO-PLAY.txt`):

- **Every encounter plays to its end on `ArenaScreen`** with fake time, at 2x in 1/30s frames. Each has to:
  - finish with no errors;
  - have played exactly the fight `CombatSim.run` gives for the same setup (the screen never changes the fight);
  - have every entry in the log panel, a line each with the chatter shown;
  - show the result, with a chart that counts the whole log.
  All nine take about 8 seconds.
- **Every kind of log entry has a form:** a table in the test says how each of the 34 kinds shows besides its log line. A new kind can't be added without one; `SYNERGY` and `DEED_LEVEL` are marked as not in the rebuild yet.
  - For each kind a fight produced, the board must have shown its evidence at some frame: a shot, a number, a signature's name, an area filling, its flash, a ghost, a pulse, a slide, an aura ring, the warned ring, a status tag, or the end's banner.
  - Act 1 produces 25 of the 34 kinds. None of it summons, casts, drains mana, has phases, or saves a unit, so the chaos fight's tests in `test_fight_view.gd` cover those.
  - Breaking any one form (the ghost, slides, auras, the warned ring, signature names, landing flashes, the collapse banner, the log panel, the chart's tally) fails the test.
- **The real game** boots from `main.tscn` in a window and plays Witch Circle to its end at 2x (813 frames, a victory at 52.8s).
- **Tester notes:** `HOW-TO-PLAY.txt` (in each zip) says how to play Practice, the keys, and what gate 1 asks.
- **The playtest build for gate 1** is "Playtest build 4 (0865f6b)", a pre-release made by the workflow on this branch: https://github.com/22nmcdon/Riftrite/releases/tag/playtest-4 (Windows and macOS zips; the tests passed first).

## 11. Order of work (each step: code, tests, green run, commit)

1. **`FightTally`** in the sim, and the runner switched to it (fingerprints and runner numbers unchanged). **Done.**
2. **`ArenaView` and tokens:** the board and units drawn from a `FightSetup`, static. Screenshot. **Done.**
3. **Placement:** moving heroes, legality from the sim, enemy hover with reach, the remembered formation. **Done** (no reach drawn: Decision 5).
4. **`FightPlayer`:** live stepping, speeds, pause, restart, rewind, interpolation. **Done.**
5. **What the fight shows (section 5)**, in two passes: bars, statuses, shots, swipes, and numbers first; then areas, displacement tweens, collapse, summons, deaths, phases, target lines, and Engage links. **Done.**
6. **Log panel and fight chart.** **Done.**
7. **Unit details:** the ability text in the data, the enemy side panel, and the hero popup. **Done.**
8. **Practice flow:** the title button, encounter list, result screen, place again, rematch. **Done** (the result is on the arena screen).
9. **Every encounter plays headless;** screenshots; a playtest build (the "Playtest build" workflow) for gate 1. **Done.**
10. **Docs:** CLAUDE.md gains "How the UI works"; the plans are updated with what the playtest says. **Done** (the playtest's findings are still to come).

## Decisions

Answers to the proposal's questions (2026-09-28):

1. **Playback: step the sim live** while you watch (recommended and accepted). The board reads the sim's state, so there's no second model of the fight to keep in step; it's cheap (the worst swarm is about 23 ms of sim per second of fight); and rewind is a fresh sim run to that tick, since the sim is deterministic. The old player worked this way and was tested to match the recorded log at every speed.
2. **Speeds go up to 2×:** 0.5×, 1×, and 2×, plus pause. A fight **doesn't start paused**, and **the chosen speed is remembered** (while the game is open, like the formation, since Practice saves nothing to disk). Skip to the end stays; there's no single-tick stepping.
3. **Unit details:** **clicking a hero** while a fight isn't actively playing (placement, paused, or over) opens a popup with their details; **hovering an enemy** opens a panel at the side of the screen. The ability text is hand-written in the data plus a generated numbers line (the recommendation, taken since the answer left the source of the text open).
4. **The remembered formation** lasts **only for the session**, and it's **one formation for all encounters**.
5. **No reach drawn on the board** when hovering an enemy: that's too much help. The player learns it by reading the enemy's panel (so the Hound's text says "within 4 hexes").
6. **Target lines:** a toggle, and on hover. They're for testing for now.
7. **Only the nine hand-placed encounters** for now; no free sandbox.

## Playtest gate 1

Build: playtest build 4 (0865f6b), https://github.com/22nmcdon/Riftrite/releases/tag/playtest-4. The question: is a single arena fight with the base heroes fun and readable?

**Findings (2026-09-28, first play):**

1. **Enemies didn't all stay on the hero they went for.** With Brannoc in front and nearest to every enemy, every melee enemy should go for him (others by their own rules, like the Hound's Pounce). They did pick him first, but units were too big for more than about four to reach him; the rest waited 1s with no way in, gave up on him, and walked round to Maren and Vell (in Pup Warren, two pups at 2.55s).
2. **Units were too big:** 0.8 hex wide. Six enemies should be able to attack Brannoc together.

**Decisions (the playtester's answers):**

- **Units are 0.2 hex wide** (`unit_radius` 400 to 100), and **melee reaches half a hex** (new tuning, `melee_reach`: 500, center to center; it was a whole hex). A signature with no `max_range` reaches as far as its unit.
- **A unit blocked only by other units keeps its target** and waits for an opening. It gives up only when the target is walled off (no way even with every unit aside: rocks or crumbled ground). That should be rare outside big swarms, which no Act 1 fight has.

**What changed** (the phase 1 plan's Space, Movement, and Range sections say so where the rules live):

- **The sim:**
  - `TuningDef.melee_reach`; `UnitState.reach()` and `reach_of(signature)`.
  - `Movement.walled_off`, checked on `CombatSim.ground_nav_for`: the nav grid with only the rocks.
  - **A rule-4 fix the new geometry turned up:** a heal that strips damage-over-time stacks now credits the healer ("Poison on brand loses 1 stacks (healed by mender · Mend)"). Before, that line had no source; the log audit caught it once the chaos fight's heals started landing on poisoned units.
- **Balance** (the sim runner, `--seeds=5`, 44 formations each):
  - At the new size, Pup Warren failed the gate: six pups could all bite Brannoc at once, each at Pack Bite's full bonus, and 0 of 44 formations won.
  - Retuned: Rift Pup ATK 10 to 8, Pack Bite's bonus 25% to 20%. Weaker pups made Ash Nest and Bog Crossing easy (36 and 40 of 44), so Ashling ATK 18 to 22, and Bog Lurker HP 640 to 760 and ATK 24 to 32.
  - All nine pass the gate, with 18 to 32 of 44 formations winning (Pup Warren 18, Ash Nest 24, The Pack 30, Moth Cloud 26, Hollow Line 26, Bog Crossing 25, Sentinel Gate 27, Cairn Road 29, Witch Circle 32).
  - The bench is faster (220 ms per 60s of fight overall on the cloud machine, from 387): small units leave the nav grid more open.
- **The board:**
  - Tokens draw the unit's true circle (at least 8px), with the name under it and fixed-width bars.
  - What hovers, clicks, and drags is at least 16px from the center.
  - A swipe means a hit from within the attacker's melee reach.
  - **A bug the new sizes showed:** a slide (leap, push) that ended inside a long frame left the token at the landing spot for that frame. A finished slide no longer counts.
  - The screenshots gain six pups crowding Brannoc in Pup Warren.
- **Tests:**
  - Sim tests updated to the new geometry.
  - Tests whose scenario needs bulky units (a hopper boxed in, a way back walled by units, hand-worked summon spots) use `K.sim(setup, true)`, with phase 1's size.
  - The chaos fight moved to seed 18, which again uses every piece.
  - New tests for melee reach, for keeping a target when blocked only by units, and for a heal's cleanse naming the healer.

Playtest build 5 carried these.

**Findings (2026-09-28, second play, build 5):**

3. **Pups were too fast** (speed 3, 3 hexes a second).
4. **Maren's evade didn't shake anyone off:** after she hopped away, every enemy still targeted her, even with another hero closer.

**Decisions:**

- **Rift Pups move at speed 2**, like the heroes and most enemies. Rift Hounds stay at 3: flanking fast is their job.
- **Maren gains Slip Away:** each hop hides her for **1s** with a new status kind, **Stealth**. No enemy can pick a stealthed unit, and one targeting it picks again at once (the log says "…is stealthed"). It's **untargetable only**: shots already flying and areas still hit her, and she keeps attacking. Only Maren has it; the Hollow Archer's hop doesn't hide it.
- Maren is she/her (confirmed).

**What changed:**

- **Two code additions** (rule 3: no existing kind could hide a unit or react to a hop):
  - the `stealth` status kind (`Statuses.is_stealthed`, `CombatSim.targetable_enemies_of`, `Targeting.lose`);
  - the `on_hop` event trigger, raised from the log's HOP entries.
  Maren's Slip Away is data: an ability passive, `on_hop`, applying `stealth` to herself. Allies still see a stealthed unit (heals, `lowest_hp_ally`).
- **The board** draws a stealthed unit see-through, with a "HID" tag.
- **Balance** (the sim runner, `--seeds=5`, 44 formations each): stealth made Maren much harder to kill, so Witch Circle (42 of 44 won), Cairn Road (39), Ash Nest (34), and The Pack (33) got easy.
  - Retuned: Rift Hound ATK 16 to 18, Gloam Witch HP 300 to 360 and ATK 18 to 22, Ashling ATK 22 to 25.
  - All nine pass the gate, with 15 to 31 of 44 winning (Pup Warren 21, Ash Nest 25, The Pack 15, Moth Cloud 30, Hollow Line 26, Bog Crossing 21, Sentinel Gate 31, Cairn Road 24, Witch Circle 24).
- **Tests:**
  - Stealth's rules: it can't be picked, a targeting enemy picks again, allies keep it, and a shot already flying lands.
  - Slip Away: stealth on the hop for 1s, and the enemy turning on the other hero.
  - The token's fading and tag.
  - The chaos fight's hook got the same on-hop stealth (every status must be applied there), and the fight moved to seed 21, which also has an enemy losing its target to Stealth.

The next playtest build carries these; gate 1 is judged again on it.
