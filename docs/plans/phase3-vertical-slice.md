# Plan: Phase 3, the vertical slice

Status: **proposed; most answers are in, a few questions remain (end of file).** Nothing here is built yet.

Goal (roadmap in `docs/design.md`): **one full act, playable start to boss.** Content target: 8 heroes, 60 items, 6+ essences, 10 alloys, 20 synergies. Done when playtesters want a second run.

The combat sim (Phase 2) is done. The slice needs three more things: the **sim features the design names but we haven't built** (relics, synergies, bosses), the **run layer** (days, shops, stops, rewards, and so on), and a **first UI**. The run layer follows the same rules as the sim: pure logic, deterministic from a run seed, and tested headless.

## Part A: sim features the slice needs

1. **Relics.** This depends on the relic change you proposed (see "Relics: the proposed change" below).
   - **As designed now:** a shared board of 3–6 slots, with sizes, adjacency, and 1 socket that spills only to neighboring relics.
   - **As proposed:** no board limit, no sockets, and no adjacency.
   - **Either way:**
     - Relics are mostly auras and triggers, so they reuse the existing auras and effects.
     - Relic-style rules need a few new triggers, for example `on_ally_below_hp` ("the first ally to drop below 30% HP gains a Shield"), `on_fight_start`, and `at_time`.
     - Enemy teams can carry relics, including enemy-only ones.
     - Rarities set a relic's price and drop odds.
2. **Synergies, all five layers** (design doc, "Synergies"):
   - named pairs: two specific items on the same hero
   - essence transformations: a specific item + essence changes how the item works, and never spills
   - signature gear: a specific item on a specific hero
   - essence resonance: 3/5/7 of one essence team-wide
   - class traits: 2+ heroes of a class fielded

   The engine checks these at fight start and applies them as data (auras, effects, or item changes). It logs "Paper Cuts discovered!" the first time each fires, and the log names the synergy as the source (CLAUDE.md rule 4).
3. **Rank-B specializations:** each class has 3; a hero picks one on reaching B (a recruit at B or above comes with one preset). A specialization is data applied at fight start, like a synergy: stat changes, auras, or effects on the hero, and possibly changes to their basic attack. It shows in the log as the source. Retraining (changing it) is an event for later.
4. **Bosses:** an Act 1 boss with a unique mechanic. It should be built from existing blocks where possible (windows, auras, phases at HP thresholds). An HP-threshold trigger is probably the one new piece.

## Part B: the run layer (`src/run/`)

### The shape of an act

No branching map. An act is a list of **days**, and the game only ever shows what's next:

```
Day 1:  shop  →  fight  →  stop (pick 1 of 3)
Day 2:  shop  →  fight  →  stop
...
Day 6:  shop  →  BOSS
```

- **Shop (every day):** buy and sell items, recruit heroes, reroll. It's the old Merchant and Tavern in one. Tier odds by act come from the table in `docs/tiers-backup-specialization.md`, for items and heroes alike.
- **Fight (every day):** one encounter from the act's pool, shown ahead of time with its enemy team (so you know which essences it drops). Elites show up as some days' fight; the last day's fight is the boss.
- **Stop:** pick 1 of 3, drawn by weight from the stops that apply right now:
  - **Forge:** reforging; only offered when something is infused
  - **Vault:** only offered when you hold a key
  - **Loot**
  - **Events**
- **Placeholders (in `data/acts.json`):** 6 days per act, so 6 fights with the boss.
- **Offers don't depend on earlier picks.** Each offer comes from the run's RNG, seeded per day, step, and attempt. What you pick today never changes tomorrow, and a saved run stays reproducible.

### RunState

RunState holds the whole run:
- the roster (up to 6), each hero's rank and specialization, and who is fielded and in backup
- item loadouts, the **stash (6 spaces)**, the relic board, gold, keys, and the essence pouch (cap 8)
- the act, day, step, and attempt; the current offer; losses and wins so far
- the codex discoveries made this run
- the run seed and the RNG state

### Actions

The UI changes the run only through **actions**: pick an offer, buy, sell, reroll, equip, unequip to the stash, move, combine, infuse, reforge, recruit, rank up, pick a specialization, set rows and backup, start the fight. Each action validates, applies, and returns what changed. The UI never edits state directly, the same rule as for the sim.

### Starting a run

1. Pick 1 of 3 random heroes. You start with just this one hero.
2. Pick 1 of 3 starting packages. Placeholders: extra gold, a random Common relic, or a random Common item.
3. You also get a base amount of gold.

Fielding is 1–5 heroes, so a one-hero start is legal. Early encounters are tuned for a small guild, and the shop is where the second hero comes from.

### Stops

- **Forge:** reforging, which costs gold and resets XP. Only offered when something is infused. (Where infusing itself happens is a question below.)
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
- **Elite win:** a guaranteed Rare item or a rank-up, on top of that.
- **Loss:** the day restarts.
  - You keep everything you have.
  - You get bonus gold: 10, +5 per fight won so far.
  - You go through the shop and a new stop again, then rematch the fight.
  - The replayed day draws fresh offers (the attempt number is part of the seed).
  - **The second loss ends the run.**
- **HP:** every fight starts at full HP, with no carry-over.

### Economy (placeholders, all in `data/economy.json`)

Tuned with the run bot, not fixed yet:

| | C | B | A | S |
| --- | --- | --- | --- | --- |
| Item price | 4 | 9 | 20 | 42 |
| Hero recruit | 6 | 14 | 30 | 60 |

- **Items:** rarity adds nothing to the price for now (the field exists). B costs a bit more than two Cs, since two Cs combine into a B.
- **Rank-up:** how heroes rank up is a question below. If it's paid in gold, the price is the difference between the hero's rank and the next one.
- **Relics by rarity:** Common 6, Uncommon 9, Rare 13, Epic 18, Legendary 25.
- **Selling** returns half the price, rounded down.
- **Rerolling** costs 1 the first time, then 1 more each time in the same shop.
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
- **Day screen:** the day, where you are in it (shop, fight, stop), the losses left, and the upcoming fight's enemy team.
- **Stop choice:** the 3 options.
- **Prep screen:** drag items between heroes, slots, and the stash; set front/back rows and who's in backup; manage the relic board and essence pouch.
- **Fight playback:**
  - plays back the sim's log at 0.5×/1×/2×/4×, with pause
  - HP and shield bars, status icons, items lighting up as they fire
  - the combat log alongside
  - the per-item damage meter after the fight

  (The readability tools the design calls required.)
- **Screens:** shop (items and heroes), forge, loot/vault, event, reward, and the rank-B specialization pick.
- **Run summary:** shown when a run ends.
- **Continue:** a saved run can be resumed from the main menu.

## Part D: content to the slice targets

- **Heroes:** 8 (4 more), each with a Backup effect.
- **Specializations:** 3 per class, for every class the slice's heroes use.
- **Items:** 60, plus 10 alloys and 20 synergies across the five layers.
- **Act 1 (placeholders I'll draft):** a biome name, its two essences, a pool of regular encounters, 2–3 elites, and the boss.
- **Events:** the first four above.
- **Relics:** a starter set across the rarities.
- **Name for the shop:** some drafts in the questions.

## Build order (each step reviewed as its own pull request)

1. Relics in the sim (after the relic question is settled).
2. The synergy engine and all five layers, with a few of each.
3. Rank-B specializations in the sim.
4. RunState and actions: roster, loadouts, stash, gold, pouch, combining, infusing and reforging. Save/load from the start, so every later step is tested for round-trips.
5. The day structure (shop, fight, stop, losses and replays) and the economy data; the run bot and run-level balance reports.
6. Boss mechanic(s).
7. UI: prep screen and fight playback first (the core loop), then run start, the day screen, and the shop and stop screens.
8. Content to the slice targets, then playtesting.

## Relics: the proposed change

The proposal: no relic board limit (hold as many as you find), and no essences on relics.

**What it simplifies:**
- No relic board, relic adjacency, or relic spill to build. That's a good part of Part A step 1.
- Essences stay on hero items, where positioning and spill matter.
- Relics read as run-long rules ("Burn ticks faster", "the first ally below 30% gets a Shield"), which fits them not being items.
- It matches relics not going in the stash.

**What it costs, and how to handle it:**
- **It moves toward Guildrun's relic pile,** which `docs/design.md` lists under what we leave behind. The risk is relics becoming the main source of power, with items and infusions mattering less. The fix is to keep relics **scarce** (the design's 2–3 per act, plus enemy drops) and **build-shaping rather than flat stats**: conditional triggers and boosts to a tag, essence, or status, not "+10% ATK".
- **It removes a decision:** there's no longer a choice about which relics to keep. That's fine if relics are scarce.
- **Boss kills and events lose a reward** (growing the board). Bosses can give a relic choice instead.
- **Relics drop out of essence rules:** essence resonance counts only items, and essence transformations are "item + essence" only.

**My recommendation:** do it, with relics kept scarce and build-shaping. If it's approved, I'll update the design doc and CLAUDE.md (the relic board, relic sockets, relic spill, and resonance rules).

## Answers so far

- **Days:** no branching map. Each day is a shop, one fight shown ahead, and a stop picked from 1 of 3 (the Forge only if something is infused, the Vault only with a key, Loot, Events). Offers are random per run and don't depend on earlier picks.
- **Shop:** sells items and heroes (Merchant and Tavern are one).
- **Run start:** 1 of 3 random heroes (one hero only), then 1 of 3 packages, plus base gold.
- **Fielding:** 1–5 heroes.
- **Economy:** placeholders, tuned with the runner. Higher tiers and ranks cost more, and rarer relics cost more; item rarity barely affects price.
- **Stash:** shared, 6 slots that work like a hero row. No relics.
- **HP:** full every fight, unless an item or relic changes it.
- **Losing:** a loss restarts the day with everything kept, plus bonus gold (10, +5 per win). The second loss ends the run.
- **Synergies:** all five layers.
- **Specializations:** 3 per class, in the slice.
- **Act 1 identity:** I'll draft placeholders.
- **Events:** gold, item by rarity, relic by rarity, and item by tier to start.
- **Save/resume:** yes.

## Questions (still open)

1. **Order within a day:** shop → fight → stop, as written? Or shop → stop → fight, so a replayed day gets its new stop before the rematch?
2. **Infusing:** can you socket essences from the pouch anytime between fights, with the Forge (only offered when something is infused) just for reforging? Or does infusing also need a Forge, and if so, should the Forge also show up when you have an essence in the pouch?
3. **Ranking heroes up:** now that the Tavern is gone, how does a hero rank up? Pay gold at the shop, buy a second copy of the same hero (like items), or something else?
4. **A replayed day:** same fight, or a new one?
5. **Relics:** go with the change above?
6. **Name for the shop** (optional; placeholder "Shop" is fine): Waystation, Caravan, Crossroads, Hiring Hall, or Lantern Market.
