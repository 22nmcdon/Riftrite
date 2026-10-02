# Rebuild phase 8, part 1: endless after Act 1

Status: **proposed (2026-10-02), waiting on its questions.** Phase 8 comes before phase 7 (the playtester, 2026-10-02: `rebuild-build-order.md`), and starts with endless mode, so long runs can be tested before Acts 2 and 3 exist. The design is `endless.md` (agreed 2026-09-30); this plan builds it on Act 1, and says what waits for the pieces phase 8 builds later (apexes, enemy specializations, the rift learns, Acts 2 and 3). **Numbers are placeholders** until the bots measure them (part 8a-3).

## 1. What it builds

After the Act 1 boss shop, instead of the run ending, the player chooses: **end the run as a win**, or **go deeper**. Going deeper keeps the heroes, relics, loadout, and shards, and starts **floor 1**. A floor is a day of the campaign's loop (`days-and-nodes.md`): the fight, the after-fight pick, the Pedlar, a node. The rift grows each floor until a loss ends the run; **the score is the deepest floor reached.**

What changes from `endless.md`, and why:

| `endless.md` | Here | Why |
| --- | --- | --- |
| Unlocked after beating Act 3 | Offered after every won Act 1 boss, no unlock | Acts 2 and 3 don't exist; the playtester wants to test long runs now. The unlock comes with Act 3 |
| Every 10th floor: one of the three act bosses, fully specialized | Old Mother Ash, as she is | Only Act 1's boss exists; specializations come later in phase 8 |
| The rift learns, always on | Off | Not built yet (later in phase 8); endless turns it on when it is |
| Apex snowballs stay per fight | (nothing to do) | Apexes come later in phase 8 |
| The Codex records the best floor | A small records file (`user://records.json`): the best floor, and the run's seed and vows | No Codex yet; a record is no stat, so rule 5 holds |

Everything else is `endless.md`'s: ×1.15 enemy HP and ATK a floor, a rift modifier added every 3 floors for good, Rift Collapse 1s earlier each floor (down to 10s) with crumbled ground's damage growing, an elite every 5th floor and a boss every 10th (a boss win offers 1 of 3 boss relics, or 3 legendaries once every boss relic is owned), any shop able to show a legendary from floor 10, upgrade pools that never run dry (stacking cards), growing cards that keep counting, and no replays: the first loss ends the run.

## 2. The floors

- **A floor's kind:** every 10th a boss, every other 5th an elite, the rest normal.
- **Its fights** (Question AQ): drawn when the floor starts (not at the act's start, since there's no end), on the run's seed and the floor (a new `RunRandom.ENDLESS` stream), avoiding the floor before's, from Act 1's encounters by kind.
- **Its route** (Question AR): the campaign's two fights to choose between, or one.
- **Its strength:** each enemy's HP and ATK are its encounter's `scale_bp` (as in the campaign) times **1.15^floor** (`growth_bp` 11500 a floor, compounded in basis points with the shared rounding helper; 64-bit ints hold it far past any floor a team reaches). Applied as an enemy kit mod in `RunFlow._modify_enemies`, beside the relics' and Rift Tear's.
- **Rift modifiers:** floor 3 adds one of the ten, floor 6 another, and so on, drawn without repeats on the endless stream until all ten are on, then none more. They are the built ones (`camps.json`, `CampsDef.Modifier`), so Early Collapse and Reinforcements work as at a Rift Tear. A Rift Tear node in endless still adds its depth's modifiers for its fight, on top.
- **Rift Collapse:** starts at 45s less 1s a floor, never before 10s (`FightSetup.collapse_start_ticks`, built for Early Collapse; the earlier of the two wins). **Crumbled ground's damage** grows with the floor (Question AS): a new `FightSetup.crumble_bp` multiplies `collapse_by_act`'s base and growth (the one sim change: integer, and a fight that doesn't set it is unchanged, so every built fingerprint holds).
- **Pay** (Question AT): flat (the act's pay by tier), or growing with the floor.
- **Shops:** the Pedlar's relic odds gain a legendary weight from floor 10 (`endless.legendary_from_floor`, `endless.legendary_weight` in `act1.json`); the boss shop comes after every 10th floor's boss, as after the act's.
- **Losing:** the first loss ends the run (`losses_to_end` is ignored in endless). A tie still wins, as in the campaign; the faster collapse is what keeps a defensive team from stalling forever.

## 3. Data

`act1.json` gains an `endless` block (`ActDef.Endless`), read and validated with the act:

```json
"endless": {
  "growth_bp": 11500,
  "modifier_every": 3,
  "collapse_step_ms": 1000,
  "collapse_floor_ms": 10000,
  "crumble_growth_bp": 11500,
  "elite_every": 5,
  "boss_every": 10,
  "legendary_from_floor": 10,
  "legendary_weight": 5,
  "pay_growth_bp": 10000
}
```

## 4. The run

- **`RunState`** (save version 5; a version-4 save loads with endless off): `endless` (bool), `floor` (0 in the campaign), `floor_options` (today's fights, since there's no act draw to read them from), `endless_mods` (the stacked rift modifiers, in order). `today()` reads `floor_options` in endless.
- **`RunFlow`:** one place answers what kind of day it is (`day_kind()`: the act's days in the campaign, the floor's kind in endless), replacing the direct `run.act.days[state.day - 1]` reads, so the boss's relic choice, the boss shop, elites' relics, and the nodes all work on floors unchanged. After the act's boss shop: a new `Phase.CHOICE` with `end_run()` and `go_deeper()`; `go_deeper()` starts floor 1. `_start_day()` in endless draws the floor's fights and adds a modifier on every 3rd floor. `record()`: a loss ends an endless run; a win pays (flat or growing). `fight_setup()` adds the floor's enemy growth, the stacked modifiers, and the collapse and crumble numbers.
- **`Offers`:** `endless_floor(run, state)` (the floor's fights), `endless_modifier(run, state)`; `relics` uses the floor's odds; the boss relic choice offers legendaries once every boss relic is owned.
- **Records:** `RunRecords` (`src/run/run_records.gd`, beside `RunSave`): reads and writes `user://records.json` (best floor, its seed and vows), written when an endless run ends.

## 5. The UI

- **The choice** after the act's boss shop: a stage on `RunDayScreen` with the run's result and two buttons, "End the run" and "Go deeper", and a line on what endless is (the rift grows each floor; the first loss ends it).
- **The floor:** the top bar shows "Floor N" in place of the day; the route shows the floor's fights as cards (the act map stays for Act 1's days); the stacked modifiers are listed (each with its sentence) above the fight cards; the fight card shows the floor's strength ("Enemies ×4.05").
- **The end:** the deepest floor, and "Best: floor M" from the records file; a new best is said so.
- **Big numbers:** HP bars and the log shorten numbers past 9,999 (12.4k, 3.1M), in one helper (`UiStyle.short_number`).

## 6. The bots and the report

- The bots answer the new choice (a `go_deeper` hook: the simple and random bots end the run unless told to go on; `--endless` makes every bot go deeper).
- **`run_runner.gd --endless`:** plays each run on into endless and reports the floors reached (median, quartiles, the deepest), the floor kinds and encounters that end runs, the modifiers on at the end, and how far growing cards grew. A report, not a gate.
- **Tuning** (Question AU): where the good bot should fall.

## 7. Tests

- `tests/run/test_endless.gd`: the choice (ending the run as a win; going deeper keeps heroes, relics, loadout, and shards); a floor's kind, fights (repeatable from the seed, avoiding the floor before), and growth (1.15^floor on HP and ATK, exact ints); a modifier every 3 floors, no repeats; the collapse step and its floor; legendary odds from floor 10; boss relics then legendaries; the first loss ends the run; the save round-trips (and a version-4 save loads).
- `tests/sim/`: `crumble_bp` scales the collapse damage, and a fight without it is unchanged (the bench's fingerprints).
- `tests/ui/`: the choice stage, the floor's top bar and route, the end with the record; `test_run_screens` drives a run past the boss into floor 2.
- `tests/tools/test_bots.gd`: every bot plays into endless and repeats; `--endless`'s report.

## 8. Parts

- **8a-1, the rules:** the data block, `RunState`, `day_kind()`, the choice, floors, growth, modifiers, collapse and crumble (the sim piece), pay, shops, boss relics, losing, records; their tests.
- **8a-2, the screens:** the choice, the floor's top bar and route, the modifiers, the end and the record, big numbers; their tests and screenshots.
- **8a-3, the bots and the report:** `--endless`, a first read, and tuning to Question AU's target; every change reported.
- **8a-4, docs and a playtest build.**

## 9. Questions

- **AQ. Which fights a floor draws:** Act 1's later fights (day 4 on, the harder fights, the elites, the boss), or all of Act 1's?
- **AR. A floor's route:** two fights to choose between, as a campaign day, or one?
- **AS. Crumbled ground's damage in endless:** ×1.15 a floor like the enemies, or slower?
- **AT. Pay in endless:** flat, so prices bite harder as the run goes on, or growing with the floor?
- **AU. Where should the good bot fall?** A median floor to tune to, or only report for now.

## Decisions

(none yet)
