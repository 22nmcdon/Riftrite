# Plan: Phase 3, the vertical slice

Status: **all design answers are in. Step 1 (relics) has its own plan in `docs/plans/relics-in-sim.md`.** Nothing here is built yet.

Goal (roadmap in `docs/design.md`): **one full act, playable start to boss.** Content target: 8 heroes, 60 items, 6+ essences, 10 alloys, 20 synergies. Done when playtesters want a second run.

The combat sim (Phase 2) is done. The slice needs three more things: the **sim features the design names but we haven't built** (relics, synergies, bosses), the **run layer** (days, shops, stops, rewards, and so on), and a **first UI**. The run layer follows the same rules as the sim: pure logic, deterministic from a run seed, and tested headless.

## Part A: sim features the slice needs

1. **Relics** (the new model):
   - The guild holds any number of relics. There's no board, no slots, no adjacency, and no sockets.
   - A relic can be turned down when offered, but once taken it can't be removed.
   - Relics are auras and triggers, so they reuse the existing auras and effects, applied team-wide.
   - Relic-style rules need a few new triggers, for example `on_ally_below_hp` ("the first ally to drop below 30% HP gains a Shield"), `on_fight_start`, and `at_time`. Build-shaping relics ("Burn ticks faster", "Small items gain crit chance") also need aura targets by tag, size, or status. I'll list each new type in the PR.
   - Enemy teams can carry relics, including enemy-only ones.
   - Rarities set a relic's drop odds and price. Relics are much rarer than items, essences, and heroes, and Epic ones change a build the most.
2. **Synergies, all five layers** (design doc, "Synergies"):
   - named pairs: two specific items on the same hero
   - essence transformations: a specific item + essence changes how the item works, and never spills
   - signature gear: a specific item on a specific hero
   - essence resonance: 3/5/7 of one essence team-wide
   - class traits: 2+ heroes of a class fielded

   The engine checks these at fight start and applies them as data (auras, effects, or item changes). It logs "Paper Cuts discovered!" the first time each fires, and the log names the synergy as the source (CLAUDE.md rule 4).
3. **Rank-B specializations:** each hero has 3 of their own, with locked potential at A and S; a hero picks one on reaching B (a recruit at B or above comes with one preset). A specialization is data applied at fight start, like a synergy: stat changes, auras, or effects on the hero, and possibly changes to their basic attack. It shows in the log as the source. Retraining (changing it) is an event for later.
4. **Bosses:** an Act 1 boss with a unique mechanic. It should be built from existing blocks where possible (windows, auras, phases at HP thresholds). An HP-threshold trigger is probably the one new piece.

## Part B: the run layer (`src/run/`)

### The shape of an act

No branching map. An act is a list of **days**, and the game only ever shows what's next:

```
Day 1:  Caravan  →  stop (pick 1 of 3)  →  fight
Day 2:  Caravan  →  stop  →  fight
...
Day 6:  Caravan  →  stop  →  BOSS
```

- **Caravan (every day):** buy and sell items, recruit heroes, reroll. It's the shop and tavern in one. Buying a second copy of a hero you have (same rank) ranks them up, the same as items. Tier odds by act come from the table in `docs/tiers-backup-specialization.md`, for items and heroes alike.
- **Stop:** pick 1 of 3, drawn by weight from the stops that apply right now:
  - **Forge:** reforging; only offered when something is infused
  - **Vault:** only offered when you hold a key
  - **Loot**
  - **Events**
- **Fight (every day):** one encounter from the act's pool, shown ahead of time with its enemy team (so you know which essences it drops). Elites show up as some days' fight; the last day's fight is the boss.
- **The day's steps are data** (`data/acts.json`): 6 days per act as a placeholder, so 6 fights with the boss. Your "two rounds a day" idea (Caravan, stop, fight, Caravan, stop, elite or boss) would then be a data change, not a code change. I'd start with one round: more days make the loss replay cheaper to tune, and the run bot can compare both later.
- **Offers don't depend on earlier picks.** Each offer comes from the run's RNG, seeded per day, step, and attempt. What you pick today never changes tomorrow, and a saved run stays reproducible.

### RunState

RunState holds the whole run:
- the roster (up to 6), each hero's rank and specialization, and who is fielded and in backup
- item loadouts, the **stash (6 slots, like a hero row)**, the relics, gold, keys, and the essence pouch (cap 8)
- the act, day, step, and attempt; the current offer; losses and wins so far
- the codex discoveries made this run
- the run seed and the RNG state

### Actions

The UI changes the run only through **actions**: pick an offer, take or decline a relic, buy, sell, reroll, equip, unequip to the stash, move, combine items, combine heroes, infuse (any time between fights), reforge, recruit, pick a specialization, set rows and backup, start the fight. Each action validates, applies, and returns what changed. The UI never edits state directly, the same rule as for the sim.

### Starting a run

1. Pick 1 of 3 random heroes. You start with just this one hero.
2. Pick 1 of 3 starting packages. Placeholders: extra gold, a random Common relic, or a random Common item.
3. You also get a base amount of gold.

Fielding is 1–5 heroes, so a one-hero start is legal. Early encounters are tuned for a small guild, and the Caravan is where the second hero comes from.

### Stops

- **Forge:** reforging, which costs gold and resets XP. Only offered when something is infused. Infusing itself can happen any time between fights.
- **Loot:** a free random reward.
- **Vault:** spend a key on a chest. Only offered when you hold a key.
- **Events:** the first four, as you described:
  - **Gold.**
  - **A random item by rarity.** Placeholder odds: Common 50%, Uncommon 28%, Rare 14%, Epic 6%, Legendary 2%. A Legendary already seen this run is rerolled.
  - **A random relic by rarity,** with the same odds.
  - **A random item by tier.** Placeholder odds: C 55%, B 30%, A 12%, S 3%.

  Events are data (`data/events.json`), using a small set of outcome types (gold, item by rarity, item by tier, relic by rarity, essence, key). Retraining and trade-off events come later, with the same format.

### Fights

- **Win or tie:**
  - gold
  - 1–2 essences
  - one guaranteed drop from the enemy team's items or relics
  - infusion XP is kept
- **Elite win:** on top of that, a guaranteed Rare item, or a free copy of one of your heroes (a rank-up).
- **Boss win:** an item or a relic from the boss team.
- **Loss:** the day restarts.
  - You keep everything you have.
  - You get bonus gold: 10, +5 per fight won so far.
  - You go through the Caravan and a new stop again, then rematch the same fight.
  - The replayed day draws fresh Caravan and stop offers (the attempt number is part of the seed), but the fight stays the same.
  - **The second loss ends the run.**
- **HP:** every fight starts at full HP, with no carry-over.

### Economy (placeholders, all in `data/economy.json`)

Tuned with the run bot, not fixed yet:

| | C | B | A | S |
| --- | --- | --- | --- | --- |
| Item price | 4 | 9 | 20 | 42 |
| Hero recruit | 6 | 14 | 30 | 60 |

- **Items:** rarity adds nothing to the price for now (the field exists). B costs a bit more than two Cs, since two Cs combine into a B.
- **Rank-up:** buy a second copy at the same rank (the recruit price), then combine.
- **Relics by rarity:** Common 6, Uncommon 9, Rare 13, Epic 18, Legendary 25.
- **Selling** returns half the price, rounded down.
- **Rerolling** costs 1 the first time, then 1 more each time in the same Caravan visit.
- **Forge:** infusing is free (the essence is the cost); reforging costs 3.
- **Gold:** the base is 10 and each package adds +8. A fight win pays 5 + the day number, an Elite pays 1.5× that, and the boss pays 20. A loss pays 10 + 5 per win (your answer).

### Between fights

- Combining: two copies at the same tier, with the choice about whose infusion stays.
- Items move freely between heroes and the stash. The stash is 6 slots that work like a hero row (a Large item takes 3); relics can't go there.

### Save and resume

- **What's saved:** RunState serializes to JSON (the seed, the RNG state, and every choice so far's results).
- **When:** it saves after every action between fights.
- **Loading:** resume puts you back at the same offer with the same options. Fights are re-simulated from their seed, so nothing mid-fight needs saving.
- **Tests:** the save round-trip is tested, along with "save, load, continue" matching "continue without saving".

### Run end and the run bot

- **Run end:** after the boss, or at the second loss. Rift Shards and codex entries are tracked but not spent; meta progression is Phase 4.
- **The run bot:** a headless bot plays whole runs with a simple strategy. The balance runner then reports:
  - how far runs get and win rate by day
  - gold curves
  - which items and stops get picked

## Part C: the first UI (`src/ui/`)

Placeholder art, readable first:
- **Run start:** pick a hero, then a package.
- **Day screen:** the day, where you are in it (Caravan, stop, fight), the losses left, and the upcoming fight's enemy team.
- **Stop choice:** the 3 options.
- **Prep screen:** drag items between heroes, slots, and the stash; set front/back rows and who's in backup; see the relics and manage the essence pouch; infuse items.
- **Fight playback:**
  - plays back the sim's log at 0.5×/1×/2×/4×, with pause
  - HP and shield bars, status icons, items lighting up as they fire
  - the combat log alongside
  - the per-item damage meter after the fight

  (The readability tools the design calls required.)
- **Screens:** the Caravan (items and heroes), forge, loot/vault, event, reward (including taking or declining a relic), and the rank-B specialization pick.
- **Run summary:** shown when a run ends.
- **Continue:** a saved run can be resumed from the main menu.

## Part D: content to the slice targets

- **Heroes:** 8 (4 more), each with a Backup effect.
- **Specializations:** 3 per class, for every class the slice's heroes use.
- **Items:** 60, plus 10 alloys and 20 synergies across the five layers.
- **Act 1 (placeholders I'll draft):** a biome name, its two essences, a pool of regular encounters, 2–3 elites, and the boss.
- **Events:** the first four above.
- **Relics:** a starter set across the rarities, mostly build-shaping.

## Build order (each step reviewed as its own pull request)

1. Relics in the sim (built; `docs/plans/relics-in-sim.md`).
2. The synergy engine and all five layers, with a few of each (built; `docs/plans/synergies-in-sim.md`).
3. Rank-B specializations in the sim (built; `docs/plans/specializations-in-sim.md`).
4. RunState and actions: roster, loadouts, stash, gold, pouch, combining, infusing and reforging. Save/load from the start, so every later step is tested for round-trips. (built; `docs/plans/run-state.md`)
5. The day structure (Caravan, stop, fight, losses and replays) and the economy data; the run bot and run-level balance reports. (built; `docs/plans/day-structure.md`)
6. Boss mechanic(s) (built; `docs/plans/act1-boss.md`).
7. UI: prep screen and fight playback first (the core loop), then run start, the day screen, the Caravan, and the stop screens. (plan: `docs/plans/first-ui.md`)
8. Content to the slice targets, then playtesting.

## Answers so far

- **Days:** no branching map. Each day is the Caravan, then a stop picked from 1 of 3 (the Forge only if something is infused, the Vault only with a key, Loot, Events), then one fight shown ahead. Offers are random per run and don't depend on earlier picks. Two rounds per day is a possible later change.
- **Caravan:** the shop and tavern in one; sells items and heroes. Heroes rank up by combining two copies, like items.
- **Run start:** 1 of 3 random heroes (one hero only), then 1 of 3 packages, plus base gold.
- **Fielding:** 1–5 heroes.
- **Infusing:** any time between fights, for now. The Forge is for reforging.
- **Economy:** placeholders, tuned with the runner. Higher tiers and ranks cost more, and rarer relics cost more; item rarity barely affects price.
- **Stash:** shared, 6 slots that work like a hero row. No relics.
- **HP:** full every fight, unless an item or relic changes it.
- **Losing:** a loss restarts the day with everything kept, plus bonus gold (10, +5 per win), and a rematch against the same fight. The second loss ends the run.
- **Relics:**
  - hold any number; no board and no sockets
  - can be declined, but never removed once taken
  - change how a build works, and Epic ones change it the most
  - much rarer than items, essences, or heroes
  - bosses drop an item or a relic
- **Synergies:** all five layers.
- **Specializations:** 3 per class, in the slice.
- **Act 1 identity:** I'll draft placeholders.
- **Events:** gold, item by rarity, relic by rarity, and item by tier to start.
- **Save/resume:** yes.

- **Combining heroes:** the hero you already have keeps their specialization (and items). Heroes in the Caravan come with no items. The Caravan never offers an item or hero at a different tier than a copy you already hold, so every copy it offers can combine. Different-tier copies of an item can still be held when they come from elsewhere (Vault, loot, fights, events).
