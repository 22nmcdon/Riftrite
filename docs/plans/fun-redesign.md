# Plan: the fun redesign

Status: **approved in direction (2026-09-26); being built in steps.** The decisions are in **Decisions** at the end, and they win where they differ from the proposal text. Heroes are covered in more detail by `docs/plans/heroes-and-deeds.md`, which replaces section 1. As each step is built, its rules move into `docs/design.md` and `CLAUDE.md`; until then, those describe the game as it is now.

**Why:** playtesting says the game isn't fun yet. The run bot and the combat sim show why: choices before the boss barely matter, and the systems the game is built around (infusions, synergies) almost never show up in a run.

## What the numbers say (2026-09-26)

These come from the run bot (`tools/run_runner.gd`, 200 runs), the combat sim (`tools/sim_runner.gd`), and a one-off probe over 100 runs.

| Finding | Number |
| --- | --- |
| Loss rate by fight type | normal 1%, elite 5%, **boss 57%** |
| The run bot, which buys the rarest item it can afford and places it anywhere | clears **65%** of runs |
| First essence socketed | day 3 |
| Infused items at the end of a run | about 2 |
| Resonant infusions per run | about 0.13 |
| Synergies discovered per run | about 0.2, mostly class traits |
| Average fight length | normal 11.5s, elite 24s, boss 52s |
| Most-taken item | Rift Claw (2.2 per run), an enemy drop with the same numbers as Hatchet |
| Item prices | every C item costs 2 gold, whatever its rarity; you start day 1 with 18 gold |

What this means:

- **Days 1–5 have no tension.** All the difficulty sits in the boss.
- **Infusions, the main system, barely exist in a run.** Spill, alloys, and pure doubles go almost unseen.
- **Discovery, the Gungeon half of the pitch, is missing.**
- **Rush, Stall, and Rift Collapse don't matter** outside the boss: fights end before Stall wakes up (15s) or Collapse starts (45s).
- **The shop has no real choices.** Buying everything is the best move.
- **The fight screen is mostly a wall of log text.** Item tiles don't show when they fire.

---

## 1. Heroes: recruit by draft, not by buying

**Change:** the Caravan stops selling heroes.

- **Start:** pick 1–2 heroes at the start of the run (from 3 random, as now).
- **Recruit as a reward:** after each elite (and from some rare events), pick **1 of 3** heroes to join. The guild grows at set points, and each one is a draft decision.
- **Rank-ups happen at set points** instead of from duplicate copies: for example, after each elite and boss, or from fight XP. You control the pace directly, which also fixes "the act is too short for C → S."
- **Specializations still come at rank B.**
- **Backup is shelved for Act 1.** With fewer heroes, the bench is mostly empty. Bring Backup back in a later act, once the guild is bigger.

## 2. Hero loadout: basic attack, abilities, passives

**Change:** item size and item position are gone. A hero no longer has a row of slots. Each hero has three kinds of slots:

| Slot | How many | What goes there |
| --- | --- | --- |
| **Basic attack** | exactly 1 | The hero's weapon. It defines how they fight. An empty slot means the hero's built-in basic attack (as now) |
| **Abilities** | grows with rank | Items that fire on their own cooldown |
| **Passives** | grows with rank | Items that give auras or react to events. They don't fire on a cooldown |

- **Slot growth is the rank-up reward.** Starting values to tune: C = 2 abilities + 1 passive, rising to 4 abilities + 3 passives at S. Each rank-up gives an obvious "what do I add?" moment.
- **Basic-attack items should be the most distinct items in the game**: dual daggers (fast, weak hits), a greatbow (reaches the back row), a staff (scales from MGK). An essence socketed here effectively becomes the hero's on-hit effect.
- **Fewer, stronger items.** At 5–7 items per hero instead of a full row, each item can do more, and each infusion matters more.
- **Passives vs. relics:** passives belong to one hero and can be swapped between fights. Relics apply to the whole guild and are permanent. Keep that line sharp so the two don't overlap.
- **Hero positioning stays.** Heroes still stand in the front and back rows (hex arena later). Position now lives at the team level, where it's much easier to read.

## 3. Shop types

**Change:** you choose which kind of shop to visit, instead of seeing any item at any time.

Shop types, as a starting list:

- **By tag:** Smith (Weapon), Apothecary (Food, Healing), Arcanist's Stall (Tome, Magic)
- **By slot:** an ability shop, a passive shop, a basic-attack shop
- **By essence:** an Ember merchant, a Frost merchant (items that like that essence, plus the essence itself)
- **Special:** a tier shop (as the events do now), and a **Synergy Peddler** that offers partners for items you already hold

This is also the fix for discovery: when you can steer what you see, completing a synergy is a plan instead of luck.

## 4. Synergies everywhere, several per item

**Change:** synergies link items, passives, abilities, and heroes, and every item has several possible synergies. This works in two layers.

**Keyword synergies (systemic, always shown)**

- Every item carries keywords: Burn, Bleed, Blade, Shield, Echo, and so on.
- Passives, abilities, and heroes react to keywords: "your Burn spreads when a target dies", "Blade abilities gain a charge".
- This gives every item several synergies without writing each pair by hand, and new items plug into existing synergies automatically.
- Keywords are always visible on items, so players can plan.

**Named synergies (hand-made, hidden until found)**

- A smaller set of flashy specific combinations, for the "whoa" discoveries.
- They stay hidden until they trigger, and are then saved in the Codex (as now).
- Don't hide everything: if every synergy is hidden, players can't plan.

**Hero affinities**

- Each hero has **2 keywords** (for example, Wren: Blade, Bleed).
- Matching items get a bonus or an extra effect.
- This covers the hero side of synergies, and tells players at a glance which shop types suit which hero.

**Passives that fire on events**

- Without adjacency, items need another way to feed each other. Passives react to triggers: "when an ability fires", "on crit", "when this hero gets Shield", "every 3rd basic attack".
- Chains of triggers become the new combo engine, and players can see each step happen.

## 5. Spill is replaced: keyword spill, Awakening, and conduits

"Spill to neighbors" no longer has anything to point at. The replacement has three parts, which together keep what spill was doing: Resonant feels like a real payoff, one great infusion shapes the rest of the build, and singles vs. alloys stays a real choice.

**A. Keyword spill (singles).** A Resonant **single** essence spreads a partial copy of its effect (about 30%, a tuning value) to the holder's other items that **share a keyword** with it.

- Example: a Resonant Ember on a Blade ability puts a little Burn on every other Blade item that hero holds.
- Stacking one keyword becomes a build direction, the way stacking a row used to be.
- Spill stays inside the holder's loadout unless a conduit says otherwise (see E).

**D. Awakening (pure doubles and alloys).** Instead of spilling, a Resonant pure double or alloy **awakens**: it unlocks a third effect.

- **Pure doubles** awaken into an essence-specific effect. Examples: Ember + Ember: Burn explodes when its target dies. Stone + Stone: a Shield reflects damage when it breaks. The existing pure-double bonus effects (Inferno's Golden Flame, and so on) can become the Awakened effect, which saves design work: 8 pure doubles means 8 Awakenings.
- **Alloys** awaken by strengthening or extending their special (for example, Plasma jumps twice).
- **Neither one spills.** The choice becomes clean: spread one essence wide (single) or build one powerful item (pure double or alloy).

**E. Conduit passives (content, not rules).** Passive items that change where spill goes, or that let things spill that normally don't:

- *Ember Censer*: your Resonant infusions also coat your basic attack.
- *Bond Chain*: your spill also reaches the hero standing beside you.
- *Open Channel*: your spill reaches every ability, keyword or not.
- *Prism* (rare): your Awakened infusions also spill.

Conduits make spill something you draft for, and they give passive slots a clear job.

**Essence transformations** still never spill and never awaken. Their changed behavior is the payoff.

## 6. The day, the economy, and pacing

**The day becomes: choose a shop → choose a fight.**

- Stops (loot, forge, events, vault) fold into the shop choice as one pool of nodes, so the player isn't making three choices a day.
- **Offer 2 fights a day**, showing each one's essences, difficulty, and reward. For example: "Hound Pack: Wrath, easier" next to "Witch Coven: Venom, harder, better loot." This lets the essence system drive decisions while keeping the "no map" rule: it's a choice, not branching paths.

**Rewards: pick 1 of 3 after a fight**, instead of a guaranteed random drop. Drafting is where auto-battler decisions come from, and it fixes the bland-drop problem (Rift Claw).

**Essences come faster:**

- Every win gives a whole essence (or 2 shards).
- The starting hero comes with one infused item, or a starting package gives one.
- Lower `xp_to_resonant` from 300 to about 150, so Resonant (and so spill and Awakening) shows up in the middle of a run.

**Prices by rarity:** for example Common 2, Uncommon 3, Rare 5, Epic 7. Trim starting gold so buying one thing means skipping another.

**Difficulty curve:** tune normal fights to about a 10–20% loss rate and elites to about 30%, then make the boss a bit easier. Losing a normal fight should make you rethink your board, not only the boss.

**Fight length:** either give enemies more HP so normal fights run 25–40s, or scale the Rush (8s), Stall (15s), and Collapse (45s) timings down to fit the fights we actually have.

**Act length:** 6 days is too short for everything that grows (ranks, tiers, Legendary paths). Either make the act 10–12 days, or make growth come faster (set-point rank-ups in section 1 help here).

## 7. Fights ask questions

- **Elites and the boss each have a readable mechanic that needs a counter**: a boss with heavy Shield needs Bleed or Poison; a burst-damage elite needs Shield.
- **Show them a few days ahead**, so the player shops toward the answer.
- **Give each start a direction on day 1.** A starting hero with a signature item plus a matching essence, or starting packages like "Frost kit" or "Burn kit", gives the first shop a purpose.

## 8. Readability and feel

- **Hide the combat log by default.** It's still one click away (the log rule in `CLAUDE.md` stays).
- **Item tiles flash and show a cooldown sweep** when they fire.
- **A banner pops** when a synergy, Awakening, or spill triggers.
- **Default the fight speed to 2x** for normal fights.

---

## What this removes or changes in the code

This is a large change. It should be built as its own planned steps, with tests rewritten as it goes.

- **Removed:** item `size`; Linked and adjacency auras; left/right alloy spill; row drag-and-drop in the UI; buying heroes and ranking them up from duplicates.
- **Changed:**
  - the stash becomes plain slots instead of a 6-slot row
  - spill logic (`src/sim/infusions.gd`) moves to keyword spill plus Awakening
  - `data/items.json` gains a slot type (basic attack, ability, passive) and keywords
  - `data/heroes.json` gains affinities and slot counts per rank
  - `RunFlow` gets the new day (shop choice, 2 fights, 1-of-3 rewards) and recruitment by draft
- **Unchanged:** the deterministic, integer-only sim; content as data; the combat log rule; tiers C → S and combining item copies; relics; Legendary paths; specializations.

## Build order

Almost everything depends on the loadout change, so it goes first. Rerun the run bot after each step to check the numbers moved.

1. **Loadout** (section 2) and **hero recruitment** (section 1). Update the run bot to match.
2. **Essence pacing, prices, and difficulty curve** (section 6, data changes). Cheap, and makes infusions visible sooner.
3. **Keyword spill and Awakening** (section 5, A and D).
4. **Shop types and the new day** (sections 3 and 6).
5. **Keyword synergies, hero affinities, and event-triggered passives** (section 4), then **conduit passives** (section 5, E).
6. **Fight questions and readability** (sections 7 and 8).

## Open questions

- **Heroes:** start with 1 or 2? How many can join in Act 1, and what's the roster cap now?
- **Rank-ups:** at set points (after elites and bosses), or from fight XP?
- **Slot counts per rank:** are 2 + 1 at C and 4 + 3 at S right?
- **Awakening for singles:** should a single essence ever awaken (for example through a rare conduit), or is Awakening only for two-socket items? Two sockets are Epic and Legendary only, so Awakening is rare unless that changes.
- **Keyword spill strength:** is 30% right when a hero might hold several matching items?
- **The day:** do all stops fold into the shop choice, or do some (the Forge, the Vault) stay separate?
- **Fight length:** longer fights, or shorter Rush, Stall, and Collapse timings?
- **Act length:** 10–12 days, or faster growth inside 6?
- **Backup:** which act brings it back?

---

## Decisions (from the user, 2026-09-26)

**Order.** The big rewrite comes first. There's no playtesting between steps; playtesting happens once the rewrite is in.

**Heroes.** Section 1 is replaced by `docs/plans/heroes-and-deeds.md`: three drafted heroes kept for the whole run, no bench, ranks as a resource, and deeds.

**Loadout (section 2).** Approved as written. Slots per rank (basic attack / abilities / passives): C 1/2/1, B 1/3/1, A 1/3/2, S 1/4/3.

**Infusions (section 5, changed):**
- **Essences fuse on the item.** Every item has one infusion. Putting a second essence on an infused item fuses the two into that pair's alloy, or into a pure double if both are the same essence. This replaces "2 sockets for Epic and Legendary": every item can hold an alloy. The order doesn't matter, and there's no third essence.
- **Singles spill by keyword:** a Resonant single spreads about 30% of its effect (a tuning value) to the holder's other items that share a keyword. Each item gets at most one spill per essence.
- **Alloys and pure doubles Awaken** at Resonant (section 5, part D) and never spill.
- **Transformations** never spill and never awaken.
- **Conduit passives** (part E) come with the keyword step.
- Fusing still resets XP, and reforging removes the whole infusion.

**Synergies (section 4).** Keywords (about 6–8), 2 affinities per hero, and hidden named synergies. **Class traits are replaced** by shared affinities and duo bonds.

**The day (sections 3 and 6).**
- Shops (by tag, slot, or essence) become nodes in the node pool, alongside the Forge, the Vault, and events.
- Then you pick **1 of 2 fights**, then **1 of 3 rewards**.
- The Skirmish node is removed.

**Pacing (section 6):**
- normal fights run about 25–35s, from more enemy HP
- the act is **8 days**: elites on days 3 and 6, the boss on day 8
- an essence after every win
- `xp_to_resonant` is about 150
- prices by rarity: Common 2, Uncommon 3, Rare 5, Epic 7, with less starting gold

**Build order (revised):**
1. **Loadout:** slot types and keywords on items; item size, rows, and adjacency removed. Also the fixed trio and Backup removal, since they rewrite the same code. **Built** (keywords come with step 2, whose spill needs them): every item has a slot type; Linked and adjacency targets became `row_allies` and `holder_items`; neighbor spill is off until step 2; the stash holds 6 items; the team is drafted (3 picks) and ranks up once per elite; innates replace Backup effects; the save version is 2. The run bot clears Act 1 in about 2% of runs, down from before: the day-3 elite now meets three rank-C heroes. Step 4 retunes the pacing.
2. **The infusion rework:** fusing, keyword spill, and Awakening. **Built** (`docs/plans/infusion-rework.md`): any item holds two essences, which fuse; 8 keywords on every item; a Resonant single spills by keyword; an alloy's special switches on when it awakens at Resonant; passives can be infused; spill arrows became marks.
3. **Ranks and deeds** (`docs/plans/heroes-and-deeds.md`).
4. **The new day, the economy, and pacing.**
5. **Keywords:** hero affinities, passives that fire on events, duo bonds, and conduits.
6. **Fight questions and readability.**

Each step is its own PR. Each rewrites its tests, reruns the run bot, and updates the rules in `docs/design.md` and `CLAUDE.md`.
