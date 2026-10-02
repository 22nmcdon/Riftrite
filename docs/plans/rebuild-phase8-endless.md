# Rebuild phase 8, part 1: endless after Act 1

Status: **agreed (2026-10-02, Decisions 1–5); part 1 built: 8a-1 (the rules), 8a-2 (the screens), 8a-3 (the bots and the report), and 8a-4 (docs and a playtest build).** Phase 8 comes before phase 7 (the playtester, 2026-10-02: `rebuild-build-order.md`), and starts with endless mode, so long runs can be tested before Acts 2 and 3 exist. The design is `endless.md` (agreed 2026-09-30); this plan builds it on Act 1, and says what waits for the pieces phase 8 builds later (apexes, enemy specializations, the rift learns, Acts 2 and 3). **Numbers are placeholders**; 8a-3's report says how far runs get, and nothing is tuned yet (Decision 5).

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
- **Its fight** (Decisions 1 and 2): one a floor, drawn as the floors come (two ahead, so Scout, Map the Rift, and a Bleeding Tear still see tomorrow), on the run's seed and the floor (a new `RunRandom.ENDLESS` stream), avoiding the floor before's, from Act 1's fights by kind: the easier and harder fights allowed from day 4 on, the elites, or the boss.
- **Its strength:** each enemy's HP and ATK are its encounter's `scale_bp` (as in the campaign) times **1.15^floor** (`growth_bp` 11500 a floor, compounded in basis points with the shared rounding helper; 64-bit ints hold it far past any floor a team reaches). Applied as an enemy kit mod in `RunFlow._modify_enemies`, beside the relics' and Rift Tear's.
- **Rift modifiers:** floor 3 adds one of the ten, floor 6 another, and so on, drawn without repeats on the endless stream until all ten are on, then none more. They are the built ones (`camps.json`, `CampsDef.Modifier`), so Early Collapse and Reinforcements work as at a Rift Tear. A Rift Tear node in endless still adds its depth's modifiers for its fight, on top.
- **Rift Collapse:** starts at 45s less 1s a floor, never before 10s (`FightSetup.collapse_start_ticks`, built for Early Collapse; the earlier of the two wins). **Crumbled ground's damage** grows with the floor (Question AS): a new `FightSetup.crumble_bp` multiplies `collapse_by_act`'s base and growth (the one sim change: integer, and a fight that doesn't set it is unchanged, so every built fingerprint holds).
- **Pay** (Decision 4): flat, the act's pay by tier.
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
  "from_day": 4,
  "legendary_from_floor": 10,
  "legendary_weight": 5
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
- **No tuning yet** (Decision 5): the report says how far runs get.

## 7. Tests

- `tests/run/test_endless.gd`: the choice (ending the run as a win; going deeper keeps heroes, relics, loadout, and shards); a floor's kind, fights (repeatable from the seed, avoiding the floor before), and growth (1.15^floor on HP and ATK, exact ints); a modifier every 3 floors, no repeats; the collapse step and its floor; legendary odds from floor 10; boss relics then legendaries; the first loss ends the run; the save round-trips (and a version-4 save loads).
- `tests/sim/`: `crumble_bp` scales the collapse damage, and a fight without it is unchanged (the bench's fingerprints).
- `tests/ui/`: the choice stage, the floor's top bar and route, the end with the record; `test_run_screens` drives a run past the boss into floor 2.
- `tests/tools/test_bots.gd`: every bot plays into endless and repeats; `--endless`'s report.

## 8. Parts

- **8a-1, the rules:** the data block, `RunState`, `day_kind()`, the choice, floors, growth, modifiers, collapse and crumble (the sim piece), pay, shops, boss relics, losing, records; their tests.
- **8a-2, the screens:** the choice, the floor's top bar and route, the modifiers, the end and the record, big numbers; their tests and screenshots.
- **8a-3, the bots and the report:** `--endless` and a first read (no tuning: Decision 5).
- **8a-4, docs and a playtest build.**

## 9. Questions

- **AQ. Which fights a floor draws:** Act 1's later fights (day 4 on, the harder fights, the elites, the boss), or all of Act 1's?
- **AR. A floor's route:** two fights to choose between, as a campaign day, or one?
- **AS. Crumbled ground's damage in endless:** ×1.15 a floor like the enemies, or slower?
- **AT. Pay in endless:** flat, so prices bite harder as the run goes on, or growing with the floor?
- **AU. Where should the good bot fall?** A median floor to tune to, or only report for now.

## Decisions

The playtester, 2026-10-02:

1. **A floor draws from Act 1's fights from day 4 on, for now** (Question AQ): the day 4–7 fights and the harder fights on normal floors, the elites on elite floors, and Old Mother Ash on boss floors, each at its own `scale_bp` times 1.15^floor.
2. **A floor offers one fight** (Question AR), not two: the fight, the pick, the Pedlar, and a node.
3. **Crumbled ground's damage grows ×1.15 a floor** (Question AS), like the enemies (`crumble_growth_bp` 11500).
4. **Pay stays flat** (Question AT): Act 1's pay by tier on every floor (`pay_growth_bp` 10000).
5. **Endless isn't tuned yet** (Question AU): the bots' report only says how far each run gets.

**Nothing is built until the playtester's further notes are in** (2026-10-02: "before building anything I have some markdown information I need to give you").

## Built in 8a-1: the rules (2026-10-02)

- **Data:** `act1.json`'s `endless` block (`ActDef.Endless`: section 3's numbers, `from_day` for Decision 1, no pay growth for Decision 4), read and checked with the act; `kind(floor)` and `compound(bp, floors)` (basis points compounded with the shared rounding helper: 11500, 13225, 15209, ...).
- **A floor is a day after the act's last** (day 8 is floor 1), so the day's loop, the nodes, and the save carry on unchanged. `RunContent.day_kind` answers what a day is (the act's days, then the floors') and replaced every direct read of the act's days (the boss's relic choice and shop, Map the Rift, Scout, a Bleeding Tear, the route's line, the simple bot's Rift Tear rule); `floor_of` and `floor_pool` (Decision 1) beside it.
- **The choice:** `Phase.CHOICE` after the act's boss shop; `RunFlow.end_run()` (won) and `go_deeper()` (floor 1, everything kept). An act without an `endless` block ends at its boss shop as before. An endless boss floor's shop leads on to the nodes.
- **Floors:** `_start_day` draws the fights two floors ahead (`Offers.endless_floor`) and gathers a rift modifier every 3rd floor (`Offers.endless_modifier`, `RunState.endless_mods`, no repeats, then none). A floor's fight takes the growth as an enemy kit mod (HP and ATK only), the gathered modifiers with a Rift Tear's (`_rift_modifiers`), and `_endless_rules`: Rift Collapse 1s earlier a floor, never before 10s (the earlier of it and Early Collapse), and `FightSetup.crumble_bp`.
- **The one sim change:** `FightSetup.crumble_bp` multiplies crumbled ground's damage (`Collapse.damage_at`, rounded once); a fight that doesn't set it is unchanged, and the bench's fingerprints are.
- **Shops and relics:** `Offers.shop_odds` adds a legendary from floor 10; a boss floor offers boss relics, or legendaries once every boss relic is held.
- **Losing:** the first loss ends an endless run, its outcome still **won** (the act was won; the floor it fell on is the score). A tie wins.
- **Save:** version 5 (`endless`, `endless_mods`); a version 4 save still loads, with endless off.
- **Records:** `RunRecords` (`user://records.json`: the deepest floor, its seed and vows); the screens write it (8a-2).
- **Bots:** the simple bot ends the run at the choice; `Bot.go_deeper` (the `deeper` flag) is the hook 8a-3's `--endless` sets.
- **Calls made while building** (small, flagged for the playtester): the Magpie's two visits an act count afresh when the run goes deeper and after each endless boss floor; a Hunt has no packs on a floor (Act 1's Hunts list days 1–6), so camp doesn't offer it there; Map the Rift on a floor swaps within the floor's pool.
- **Tests:** `tests/run/test_endless.gd` (11: the choice, floors' kinds and fights, growth, modifiers, the collapse and ground, legendary odds, boss relics then legendaries, the first loss, the save, the records), a crumble test in `test_collapse.gd`, and the boss tests in `test_new_day.gd` and `test_run_flow.gd` now take the choice.

## Built in 8a-2: the screens (2026-10-02)

- **The choice** (`RunDayScreen._fill_choice`): after the act's boss shop, "Old Mother Ash is beaten", what endless is, the deepest floor so far, and End the run or Go deeper. The boss shop's leave button says what follows.
- **A floor:** the top bar reads "Floor N · Endless" (here and in the arena's run mode); the route is the floor's one fight's card, without the act map, after a line on the floor and the rift's modifiers gathered so far (each with its sentence), and the card says the floor's numbers ("Floor 4: enemies ×1.74 HP and ATK, Rift Collapse from 41s, crumbled ground ×1.74").
- **The end:** "The rift takes them on floor N", and "A new deepest: floor N." or "Your deepest: floor M."; `RunSession` notes the run in the records once, when it's saved ended (`records_path`, set by `Main`).
- **Big numbers:** `UiStyle.short_number` (12.4k, 3.1M) on the fight's floating numbers; `RunDayScreen.times` for multipliers.
- **Tests:** `test_run_screens.gd`: the choice, Go deeper to floor 1, its route and numbers, falling there with the record kept; and the short numbers.


## Built in 8a-3: the bots and the report (2026-10-02)

- **The bots:** `Bot.deeper` and `go_deeper` answer the choice (`RunPlayer` handles `Phase.CHOICE`; `MAX_STEPS` is 8000 for long runs); the simple bot ends the run there. The good bot's practice set reaches the floors drawn ahead in endless (`Practice.practice_set`, through `day_kind`); its shards are worth nothing past the act, as before.
- **`run_runner.gd --endless`** (`Report.endless_summary`, passed to `--jobs`' processes): every bot goes deeper; the report gives the runs that went deeper, the floor reached (median, quartiles, deepest, shallowest), runs falling by 5 floors, the floor kind and fight each fell to, the rift modifiers gathered, and the median floor by vow. `RunLine` keeps `floor_reached`, `fell_to`, and `endless_mods`. A transformation on a floor no longer counts as "by the boss" in the paths line.
- **A bug the report found:** a Deep or Abyssal Rift Tear on a floor could draw a modifier the run had gathered, and the enemies took it twice (their kits refused: 4 runs in 54). A tear's draw now skips gathered modifiers, a floor's gathering skips one a tear brings for its fight, and the fight's list drops repeats. Act 1 is unchanged.
- **The first read** (the good bot, 54 runs, seeds 1–54; not tuned, Decision 5): Act 1 won 26 (48%), and all 26 went deeper.
  - Floor reached: **median 4**, quartiles 3–8, deepest 18, shallowest 1; by 5 floors: 1–5: 15, 6–10: 9, 11–15: 1, 16–20: 1.
  - Fell on a normal floor 23 times, on Old Mother Ash's (floor 10) 3, on an elite floor never (Act 1's elites are the good bot's surest fights, 75–94% won).
  - Fell to: Sentinel Under Moths 5, Witch's Brood 5, Witch Circle 4, Cairn Road 3, Old Mother Ash 3, Bog Crossing 2, The Warded Charge 2, Hollow Line 1, Sentinel Gate 1.
  - Rift modifiers on at the end: 1.6 a run (Early Collapse the most often, 7).
  - Median floor by vow: Volley and Hearthwall 7, every other path 4.
  - Read: with enemies ×1.15 a floor (×1.75 by floor 4, ×4.05 by floor 10) and flat pay, a team that just beat the act lasts about four floors; a few runs reach the teens. Whether that's the curve wanted is the playtester's call (Question AU stays open).
- **Tests:** `test_bots.gd`: a bot that goes deeper plays floors to its first loss and repeats, and one that doesn't ends at the choice; the endless report's text. `test_endless.gd`: a Rift Tear on a floor never doubles a modifier.

## Built in 8a-4: docs and a playtest build (2026-10-02)

- `CLAUDE.md` (the plan's row, where the rebuild is, `--endless`, the run's endless section, `Phase.CHOICE`), `rebuild-build-order.md`, `design.md`, `endless.md`'s status, and `HOW-TO-PLAY.txt` (an ENDLESS section and what we want to know about it).
