# Plan: Phase 3, the vertical slice

Status: **proposed; first answers are in, a few questions remain (end of file).** Nothing here is built yet.

Goal (roadmap in `docs/design.md`): **one full act, playable start to boss.** Content target: 8 heroes, 60 items, 6+ essences, 10 alloys, 20 synergies. Done when playtesters want a second run.

The combat sim (Phase 2) is done. The slice needs three more things: the **sim features the design names but we haven't built** (relics, synergies, bosses), the **run layer** (days, stops, shops, forge, rewards, and so on), and a **first UI**. The run layer follows the same rules as the sim: pure logic, deterministic from a run seed, and tested headless.

## Part A: sim features the slice needs

1. **Relic board.** The guild shares one board: 3 slots at the start, growing to 6.
   - Relics have sizes, adjacency, and 1 socket.
   - A relic's infusion spills only to neighboring relics, never to hero items.
   - Relics are mostly auras and triggers, so they reuse the existing auras and effects. New triggers are needed for relic-style rules like "the first ally to drop below 30% HP gains a Shield" (for example `on_ally_below_hp`, `on_fight_start`, `at_time`).
   - Enemy teams can carry relics too, including enemy-only ones.
   - Relic rarities (Common to Legendary) set their price and how often they drop.
2. **Synergies, all five layers** (design doc, "Synergies"):
   - named pairs: two specific items on the same hero
   - essence transformations: a specific item + essence changes how the item works, and never spills
   - signature gear: a specific item on a specific hero
   - essence resonance: 3/5/7 of one essence team-wide
   - class traits: 2+ heroes of a class fielded

   The engine checks these at fight start and applies them as data (auras, effects, or item changes). It logs "Paper Cuts discovered!" the first time each fires, and the log names the synergy as the source (CLAUDE.md rule 4).
3. **Bosses:** an Act 1 boss with a unique mechanic. It should be built from existing blocks where possible (windows, auras, phases at HP thresholds). An HP-threshold trigger is probably the one new piece.

## Part B: the run layer (`src/run/`)

### The shape of an act

No branching map. An act is a list of **days**, and the game only ever shows the next choice:

```
Day 1:  stop (pick 1 of 3)  →  stop (pick 1 of 3)  →  fight (pick 1 of 3)
Day 2:  stop  →  stop  →  fight
...
Day 6:  stop  →  stop  →  BOSS
```

- **Placeholders (in `data/acts.json`):** 6 days per act, 2 stops per day, each stop offering 3 choices, then a fight. That's 6 fights per act (the boss included) and 12 stop picks, close to the old "about 10 nodes" plus a few more choices.
- **Stops** are drawn by weight from: Merchant, Forge, Tavern, Loot, Vault (only when you hold a key), and Event. No duplicates within one offer.
- **Fights:** pick 1 of 3 encounters from the act's pool. Each option shows the enemy team, so it also shows which essences it drops. From day 2, one option may be an **Elite** (harder, better reward).
- **Offers don't depend on earlier picks.** Each offer comes from the run's RNG, seeded per day and per stop, so skipping a shop today never changes what shows up tomorrow. It also keeps a saved run reproducible.

### RunState

RunState holds the whole run:
- the roster (up to 6), each hero's rank and specialization, and who is fielded and in backup
- item loadouts, the **stash (6 spaces)**, the relic board, gold, keys, and the essence pouch (cap 8)
- the act, day, and step; the current offer; losses so far
- the codex discoveries made this run
- the run seed and the RNG state

### Actions

The UI changes the run only through **actions**: pick an offer, buy, sell, reroll, equip, unequip to the stash, move, combine, infuse, reforge, recruit, rank up, set rows and backup, start the fight. Each action validates, applies, and returns what changed. The UI never edits state directly, the same rule as for the sim.

### Starting a run

1. Pick 1 of 3 random heroes. You start with just this one hero.
2. Pick 1 of 3 starting packages. Placeholders: extra gold, a random Common relic, or a random Common item.
3. You also get a base amount of gold.

Because a run starts with one hero, the fielding rule becomes "at least 1, at most 5". Early encounters are tuned for a small guild (see the questions).

### Stops

- **Merchant:** buy, sell, and reroll. Tier odds by act come from the table in `docs/tiers-backup-specialization.md`.
- **Forge:** infuse, fuse, and reforge (reforging costs gold and resets XP).
- **Tavern:** recruit 1 of 3 or rank a hero up.
- **Loot:** a free random reward.
- **Vault:** spend a key on a chest.
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
- **Elite win:** a guaranteed Rare item or a rank-up, on top of that.
- **Loss:** counts toward the limit. The **second loss ends the run**.
- **HP:** every fight starts at full HP, with no carry-over.

### Economy (placeholders, all in `data/economy.json`)

Tuned with the run bot, not fixed yet:

| | C | B | A | S |
| --- | --- | --- | --- | --- |
| Item price | 4 | 9 | 20 | 42 |
| Hero recruit | 6 | 14 | 30 | 60 |

- **Items:** rarity adds nothing to the price for now (the field exists). B costs a bit more than two Cs, since two Cs combine into a B.
- **Rank-up at the Tavern:** the price difference between the hero's rank and the next one.
- **Relics by rarity:** Common 6, Uncommon 9, Rare 13, Epic 18, Legendary 25.
- **Selling** returns half the price, rounded down.
- **Rerolling** costs 1 the first time, then 1 more each time in the same shop.
- **Forge:** infusing is free (the essence is the cost); reforging costs 3.
- **Gold:** the base is 10 and each package adds +8. A fight win pays 5 + the day number, an Elite pays 1.5× that, and the boss pays 20.

### Between fights

- Combining: two copies at the same tier, with the choice about whose infusion stays.
- Items move freely between heroes and the stash.

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
- **Offer screen:** today's day and step, the losses left, and the 3 options for the next stop or fight.
- **Prep screen:** drag items between heroes, slots, and the stash; set front/back rows and who's in backup; manage the relic board and essence pouch.
- **Fight playback:**
  - plays back the sim's log at 0.5×/1×/2×/4×, with pause
  - HP and shield bars, status icons, items lighting up as they fire
  - the combat log alongside
  - the per-item damage meter after the fight

  (The readability tools the design calls required.)
- **Screens:** shop, forge, tavern, loot/vault, event, and reward.
- **Run summary:** shown when a run ends.
- **Continue:** a saved run can be resumed from the main menu.

## Part D: content to the slice targets

- **Heroes:** 8 (4 more), each with a Backup effect. Rank-B specializations depend on question 1.
- **Items:** 60, plus 10 alloys and 20 synergies across the five layers.
- **Act 1 (placeholders I'll draft):** a biome name, its two essences, a pool of regular encounters, 2–3 elites, and the boss.
- **Events:** the first four above.
- **Relics:** a starter set across the rarities.

## Build order (each step reviewed as its own pull request)

1. Relics in the sim.
2. The synergy engine and all five layers, with a few of each.
3. RunState and actions: roster, loadouts, stash, gold, pouch, combining, infusing and reforging. Save/load from the start, so every later step is tested for round-trips.
4. The act structure (days, offers, stops, fights, losses) and the economy data; the run bot and run-level balance reports.
5. Boss mechanic(s).
6. UI: prep screen and fight playback first (the core loop), then run start, offers, and stop screens.
7. Content to the slice targets, then playtesting.

## Answers so far

- **Map:** no branching map; days of stops, then a fight. Offers are random per run and don't depend on earlier picks.
- **Run start:** 1 of 3 random heroes (one hero only), then 1 of 3 packages, plus base gold.
- **Economy:** placeholders tuned with the runner. Higher tiers and ranks cost more, and rarer relics cost more; item rarity barely affects price.
- **Stash:** shared, 6 spaces.
- **HP:** full every fight, unless an item or relic changes it.
- **Losing:** the second loss ends the run.
- **Synergies:** all five layers.
- **Act 1 identity:** I'll draft placeholders.
- **Events:** gold, item by rarity, relic by rarity, and item by tier to start.
- **Save/resume:** yes.

## Questions (still open)

1. **Rank-B specializations:** in the slice (3 per class for the slice's classes), or later?
2. **Days per act:** is the placeholder (6 days, 2 stops a day, 3 choices each, then a fight) roughly the right size?
3. **Fight choice:** pick 1 of 3 fights (draft), or just one fight shown each day?
4. **A lost fight:** what do you still get? My draft: no drop and no essences, half the gold, and infusion XP still counts. And if the boss is the lost fight and you still have a loss to spare, do you fight it again right away, or after another day of stops?
5. **Starting with one hero:**
   - Fielding becomes 1–5 instead of 3–5. Is that right?
   - Should the first day guarantee a Tavern among the options, so a second hero comes early?
6. **Stash "spaces":** are they slots by size (a Large item takes 3 of the 6, like hero rows), or 6 items of any size? Can relics sit in the stash too?
