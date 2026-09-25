# Plan: the first UI (Phase 3, step 7)

Status: **built** (Phase 3, step 7). Answers and built notes are at the end.

**Goal:** a playable Act 1 with placeholder art, where readability comes first. The design calls these readability tools required:
- fight playback at 0.5×/1×/2×/4×, with pause
- HP and shield bars, status icons, and items lighting up as they fire
- the combat log beside the fight
- a per-item damage meter after it
- item tooltips showing base and boosted numbers

**The rule from CLAUDE.md:** the UI (`src/ui/`) **reads** sim and run state and never changes it. Every change goes through `RunFlow` and `RunActions`.

## How the UI talks to the game

- **`RunSession`** (`src/ui/run_session.gd`, a plain script, not a node) holds the current `RunState`, `ContentDb`, and `RunContent`.
  - Screens call its methods. Each method calls the matching RunFlow/RunActions action, saves the run (`RunSave`), and emits a `changed` signal with the action's Result.
  - A refused action shows its `error` as a toast.
- **Fight playback:** `RunFlow.fight` also returns the `FightSetup` it used. The fight screen builds a **fresh `CombatSim` from that setup and steps it** in time with the chosen speed. Same setup means the same fight (rule 1), so the replay matches the recorded result exactly. The screen reads unit HP, shields, statuses, and cooldown progress each tick, and shows the log entries as they appear.
- **One scene per screen** (`src/ui/screens/`); `Main` swaps them by the run's `phase`.

## Screens

| Screen | Shows | The player can |
| --- | --- | --- |
| **Title** | New run, Continue (if a save exists) | Start or resume |
| **Run start** | 3 heroes (stats, basic attack, Backup effect), then 3 packages | Pick |
| **Day bar** (on every run screen) | Act, day, "Caravan → Stop → Fight", losses left, gold, keys, the day's fight (enemy team and the essence it yields), shards | — |
| **Guild panel** (Caravan, stop, and before the fight) | Every hero's row of items, the stash, the pouch, relics, active synergies, and formation | Drag items between rows and the stash; combine copies; infuse from the pouch; set rows, order, and backup; pick a specialization |
| **Caravan** | 5 items and 2 heroes with prices, reroll cost | Buy, sell (drag to the Caravan), reroll, leave |
| **Stop choice** | 3 stops | Pick |
| **Stop** | Loot or an event (take or pass), the Vault's chest, the Forge (reforge), Retrain, Upgrade | Do the stop, leave |
| **Fight** | Both sides' rows, HP and shield bars, statuses, items lighting up and filling as their cooldowns run, the combat log | Speed 0.5×/1×/2×/4×, pause, skip to the end |
| **After the fight** | Victory or defeat, the damage meter (per item: damage, healing, shielding), rewards | Take or pass each reward, relic choice, continue |
| **Run over / act cleared** | The run's summary: days, wins, losses, synergies found | Back to the title |

- **Tooltips everywhere:** hover an item for its tags, cooldown, and effects, with the **base → stat-scaled → final** breakdown (`ItemState.describe_values`). Infusion level, synergies, and specialization parts show here too.
- **Placeholder look:**
  - plain panels and text, using one Godot theme
  - items as tiles sized by slot count
  - colors by rarity (border) and essence (a dot per socket)
  - status icons as short colored tags (BRN 12, PSN 4)
  - cozy-grim palette: warm browns and ember orange against dark rift blues
- **Layout:** desktop landscape, 1920×1080, scaling to smaller windows.

## Code shape

- `src/ui/run_session.gd`: the bridge above.
- `src/ui/main.tscn` and `main.gd`: switch screens on `phase`; becomes the project's main scene.
- `src/ui/screens/`: `title`, `run_start`, `caravan`, `stop_choice`, `stop`, `fight`, `after_fight`, `run_end`.
- `src/ui/widgets/`: `item_tile`, `hero_row`, `stash_panel`, `pouch_panel`, `unit_card` (bars and statuses), `combat_log_view`, `damage_meter_view`, `tooltip`, `toast`, `day_bar`.
- `src/ui/fight_player.gd`: steps a `CombatSim` at a speed (a plain script, tested headless).
- `src/ui/theme/`: the theme resource and palette.
- **One sim change:** `RunFlow.fight` returns `[Result, FightResult, FightSetup]`.

## Tests

UI tests stay headless, with no pixel checks:
- **`RunSession`:** each action saves, emits `changed`, and passes errors through.
- **`FightPlayer`:**
  - stepping at each speed reaches the same end as `CombatSim.run`
  - pause stops it
  - skip jumps to the end
- **Screens:** each screen instantiates for its phase and shows the right offers. Actions happen through button presses (pressed signals) and change the run as expected.
- **Main:** screens switch with the phase.
- **Smoke test:** a whole run clicked through by a scripted "player" (the run bot's choices, pressed through the UI).
- **Screenshots:** I'll also render each screen headless under Xvfb to check the layout myself.

## Answers

1. **Desktop** (landscape, mouse and keyboard) first.
2. **Moving items:** drag and drop.
   - **In the Caravan, clicking an item buys it** into the stash.
   - **Upgrades light up:** if a ware would combine with a copy you hold (same item and tier), its tile lights up, and clicking it buys and **combines it straight into your copy**, even with a full stash.
3. **Fight view:** heroes in the foreground (the bottom of the screen) and enemies in the background (the top), with both front rows facing each other in the middle.
4. **Placeholder art** for now.

## Built notes

- **The bridge:**
  - `RunSession` (`src/ui/run_session.gd`) wraps every RunFlow/RunActions action. Each one saves the run (`user://run.json`) when it succeeds and emits `changed` with its Result; `Main` toasts a refused action's error.
  - `RunFlow.buy` combines a lit ware straight into the held copy (`RunFlow.upgrade_target`), needing no stash room. `RunFlow.fight` returns `[Result, FightResult, FightSetup]`.
  - `RunSession.fixed_seed` makes "New run" repeatable (tests, screenshots); otherwise each run gets a fresh seed.
- **Main** (`src/ui/main.tscn`, `main.gd`, the project's main scene) picks the screen from the run's phase and rebuilds it after every change. While a fight plays back, its screen stays until Continue.
- **Screens** (`src/ui/screens/`): title, run start (heroes, then packages), Caravan, stop choice, stop (Loot, the Vault, events, Forge, Retrain, Upgrade), fight, rewards (the "after the fight" screen), and run end.
- **Widgets** (`src/ui/widgets/`):
  - `ItemTile`: sized by slots, rarity border, a dot per socketed essence, a tooltip with the full breakdown. Owned tiles drag; dropping a copy onto a tile at the same tier combines, dropping an essence infuses, and anything else moves to that spot.
  - `GuildPanel` holds the hero rows (row, fielded/backup, order, specialization pick), the stash, the pouch and shards, relics, and a throw-away zone.
  - `DropZone` (stash, free slots, sell, throw away), `EssenceChip`, `OfferView`, `DayBar`, `UnitCard` (HP/shield bars, status tags, item cooldown fill and flash), `DamageMeterView`, `Toast`.
  - The hero rows and the stash are built into `GuildPanel` rather than separate `hero_row`/`stash_panel` widgets, and tooltips are Godot's own.
- **Fight playback:** `FightPlayer` steps a fresh `CombatSim` from the fight's setup at 0.5×/1×/2×/4×, with pause and skip. The fight screen shows enemies at the top (back row furthest) and heroes at the bottom (the bench below them), with the log beside it, then the result, the damage meter, and Continue.
- **The look:** one theme from `UiStyle` (placeholder panels and text, cozy-grim palette), at 1920×1080 with `canvas_items` stretch.
- **Tests** (`tests/ui/`, headless):
  - `RunSession` saves, emits, passes errors through, continues, and abandons.
  - `FightPlayer` replays the recorded fight at every speed; ticks per second, pause, and skip are checked.
  - Screens follow the phase; clicks, button presses, and drops (buy, the lit upgrade, reroll, sell, move, combine, infuse, throw away, formation) change the run through the session.
  - A whole run is clicked through by a scripted player until the run ends and the title returns.
- **Screenshots:** `tools/ui_screenshots.gd` renders each screen of a scripted day to PNGs under Xvfb.

### Left for later

- Log lines name units by id (`rift_pup_1`); friendlier names and colored log lines can come with real art.
- Dropping an item onto a later tile in the same row puts it after that tile (it's removed first). This is fine for now.
- There's no in-run menu yet (abandoning a run, settings). The title's Continue resumes the saved run.
