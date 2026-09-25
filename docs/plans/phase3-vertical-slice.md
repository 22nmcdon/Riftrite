# Plan: Phase 3, the vertical slice

Status: **proposed, awaiting answers and approval.** Nothing here is built yet.

Goal (roadmap in `docs/design.md`): **one full act, playable start to boss.** Content target: 8 heroes, 60 items, 6+ essences, 10 alloys, 20 synergies. Done when playtesters want a second run.

The combat sim (Phase 2) is done. The slice needs three more things: the **sim features the design names but we haven't built** (relics, synergies, bosses), the **run layer** (map, shops, forge, rewards, and so on), and a **first UI**. The run layer follows the same rules as the sim: pure logic, deterministic from a run seed, and tested headless.

## Part A: sim features the slice needs

1. **Relic board.** The guild shares one board: 3 slots at the start, growing to 6.
   - Relics have sizes, adjacency, and 1 socket.
   - A relic's infusion spills only to neighboring relics, never to hero items.
   - Relics are mostly auras and triggers, so they reuse the existing auras and effects. New triggers are needed for relic-style rules like "the first ally to drop below 30% HP gains a Shield" (for example `on_ally_below_hp`, `on_fight_start`, `at_time`).
   - Enemy teams can carry relics too, including enemy-only ones.
2. **Synergies**, in five layers (design doc, "Synergies"):
   - named pairs: two specific items on the same hero
   - essence transformations: a specific item + essence changes how the item works, and never spills
   - signature gear: a specific item on a specific hero
   - essence resonance: 3/5/7 of one essence team-wide
   - class traits: 2+ heroes of a class fielded

   The engine checks these at fight start and applies them as data (auras, effects, or item changes). It logs "Paper Cuts discovered!" the first time each fires, and the log names the synergy as the source (CLAUDE.md rule 4).
3. **Bosses:** an Act 1 boss with a unique mechanic. It should be built from existing blocks where possible (windows, auras, phases at HP thresholds). An HP-threshold trigger is probably the one new piece.

## Part B: the run layer (`src/run/`)

- **RunState** holds the whole run:
  - the roster (up to 6), each hero's rank and specialization
  - item loadouts, and a stash if there is one (question 3)
  - the relic board, gold, keys, and the essence pouch (cap 8)
  - the map, the current node, the codex discoveries made this run
  - the run seed
- **Actions:** the UI changes the run only through actions (buy, sell, reroll, equip, move, combine, infuse, reforge, recruit, rank up, pick node, and so on). Each action validates, applies, and returns what changed. The UI never edits state directly, the same rule as for the sim.
- **Map generation:** a branching act of about 10 nodes (Slay the Spire style), with node frequencies from the node table in the design doc. The biome decides which essences drop.
- **Nodes:**
  - **Fight:** gold, 1–2 essences, and one guaranteed drop from the enemy team.
  - **Elite:** a guaranteed Rare item or a rank-up.
  - **Merchant:** buy, sell, and reroll. Tier odds by act come from the table in `docs/tiers-backup-specialization.md`.
  - **Forge:** infuse, fuse, and reforge (which costs gold and resets XP).
  - **Tavern:** recruit 1 of 3, or rank a hero up.
  - **Vault:** spend a key on a chest.
  - **Event:** choices with trade-offs.
  - **Boss.**
- **Between fights:**
  - infusion XP from the fight result is kept
  - item combining (two copies at the same tier, with the choice about whose infusion stays)
  - the rule that items move freely between heroes
- **Run end:** the run ends when the guild is wiped. Rift Shards and codex entries are tracked but not spent; meta progression is Phase 4.
- **A headless run bot** plays whole runs with a simple strategy, so the balance runner can report run-level numbers: how far runs get, gold curves, and which items get bought.

## Part C: the first UI (`src/ui/`)

Placeholder art, readable first:
- **Map screen:** pick the next node.
- **Prep screen:** drag items between heroes and slots, set front/back rows and who's in backup, and manage the relic board and essence pouch.
- **Fight playback:**
  - plays back the sim's log at 0.5×/1×/2×/4×, with pause
  - HP and shield bars, status icons, items lighting up as they fire
  - the combat log alongside
  - the per-item damage meter after the fight

  (The readability tools the design calls required.)
- **Screens:** shop, forge, tavern, vault, event, and reward.
- **Run summary:** shown when a run ends.

## Part D: content to the slice targets

- **Heroes:** 8 (4 more), each with a Backup effect. Specializations at rank B depend on question 7.
- **Items:** 60, plus 10 alloys and 20 synergies.
- **Act 1:** one biome, regular encounters, 2–3 elites, and the boss.
- **Events:** a handful, including one that offers retraining.
- **Relics:** a starter set.

## Build order (each step reviewed as its own pull request)

1. Relics in the sim.
2. The synergy engine, plus a few named pairs, a transformation, resonance, and class traits.
3. RunState and actions: roster, loadouts, gold, pouch, combining, infusing and reforging. Tests throughout.
4. Map generation and node handlers; the run bot and run-level balance reports.
5. Boss mechanic(s).
6. UI: prep screen and fight playback first (the core loop), then the map and node screens.
7. Content to the slice targets, then playtesting.

## Questions (design answers needed)

1. **Starting a run:**
   - Which heroes? A fixed trio, pick 3 of a few, or random?
   - Starting items, gold, and relic?
2. **Economy numbers:** gold per fight, elite and boss rewards, item prices by rarity and tier, sell value, reroll cost, and forge costs (infusing, fusing, reforging). I can draft placeholders if you'd rather tune from the balance runner.
3. **Stash:** can unequipped items sit in a shared stash between fights, or must every item be on a hero (sell or discard otherwise)? If there's a stash, is it limited?
4. **HP between fights:** every fight starts at full HP? (Fallen heroes come back with no downside, so it seems so.)
5. **Losing:** does a single lost fight end the run ("guild wiped"), or is there some buffer, like lives?
6. **Map shape:** roughly how wide should Act 1 be (how many paths), and how often should paths cross? Fixed or random per run?
7. **Specializations at rank B:** each class picks 1 of 3. Should the slice include them (that's 3 per class for the slice's classes), or leave them for later?
8. **Relics and synergies in the slice:** the roadmap wants 20 synergies. Is the five-layer engine the right scope for the slice, or start with named pairs and resonance only?
9. **Act 1 identity:** biome name and its two essences, and a boss idea (or should I draft these?).
10. **Events:** any you already have in mind?
11. **Save and resume mid-run:** needed for the slice, or can a run be played in one sitting for now?
