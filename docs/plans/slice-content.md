# Plan: content to the slice targets, ready for playtesting (Phase 3, step 8)

Status: **proposed**, waiting on the questions at the end.

**The goal** (`docs/plans/phase3-vertical-slice.md`, Part D): one full act, playable start to boss, with enough variety that playtesters want a second run. The targets are 8 heroes, 60 items, 6+ essences, 10 alloys, and 20 synergies, plus the Act 1 encounters, events, and relics.

## Where the content stands

| Content | Now | Target | Gap |
| --- | --- | --- | --- |
| Heroes | 4 (Warden, Striker, Mender, Arcanist; one each) | 8 | +4 |
| Specializations | 12 (3 per hero) | 3 per hero | +12 |
| Items | 28 (23 the guild can buy, 5 enemy-only) | 60 | +32 to +37 (question 3) |
| Epic items (2 sockets) | 1 | enough that alloys show up | +4 to 5 |
| Legendary items | 0 | ? | question 4 |
| Essences | 8 | 6+ | done |
| Alloys | 4 | 10 | +6 |
| Synergies | 21 (8 resonance, 4 class traits, 4 signatures, 3 pairs, 2 transformations) | 20 | done on count, but the new heroes and items need their own |
| Relics | 14 (4 Legendary) | a starter set, mostly build-shaping | about +6 |
| Enemies | 6 | an Act 1 roster | about +5 |
| Encounters | 7 (4 normal, 2 elite, the boss) | a normal pool, 2–3 elites, the boss | about +5 |
| Events | 8 | 4 | done; maybe +2 |

**Two gaps matter more than the counts:**
- **Class traits can't happen yet.** Each class has one hero, and copies of a hero combine, so no guild can field 2 of a class.
- **Alloys almost never happen.** Only Epic and Legendary items have 2 sockets, and there's one Epic item.

## What I'd build

The content is data only (rule 3). Anything that needs code is flagged below and listed in the PR.

### 1. Four new heroes, with 12 specializations
- **Classes:** a **Ranger** and a **Trickster** (the design's other two classes), plus a **second hero for two existing classes**, so class traits become reachable (question 1).
- **Each hero gets:**
  - their own basic attack
  - a Backup effect
  - 3 specializations (locked potential at B/A/S, each unlike the other two)
  - a signature item synergy
- **The two new classes** each get a class trait.
- **Draft ideas** (placeholder names in the cozy-grim tone):
  - Ranger **Maren Thistledown** reaches the back row.
  - Trickster **Pell Candlewick** plays with Blind and Slow, and with cooldowns.
  - Warden **Old Hesk** is a second shield wall.
  - Arcanist **Ysolde Ashwhisper** is a burn caster.

### 2. Items to 60
- **What they cover:**
  - every class and every essence
  - more Small items than Medium and Large (size never changes rarity)
  - a few more auto-attack items (bows, a staff)
  - backup modes on some Uncommon and higher items
  - items built for the Ranger and Trickster
- **Epics:** 4–5 new Epic items with 2 sockets, so alloys become real choices.
- **Where item ideas come from:** the Act 1 essences and the existing tag pairs (Weapon, Tool, Charm, Tome, Food × Melee, Ranged, Magic, Healing, Defense).

### 3. Alloys to 10
- **What:** 6 new alloys, weighted toward the Act 1 essences, each with its own status type where it changes a status (the Inferno → Golden Flame rule).
- **Code:** today an alloy's special can only swap a status or echo heals. Most of the new ones can be new status types built from the existing status parts. If one needs a new kind of special, I'll flag it and list it in the PR.

### 4. Synergies for the new content
- 4 signatures (one per new hero) and 2 class traits (Ranger, Trickster).
- About 4 new pairs and 2 new transformations, built on the new items.
- That's about 33 in total.

### 5. Relics
- About 6 new build-shaping relics (Common to Rare) that lean on the new tags, classes, and statuses.
- No new Legendary relics; the boss already has 4.

### 6. Act 1: The Ashen Hollow
- **Enemies:** about 5 new enemy types, each with a hand-made layout, some carrying enemy-only items. The biome decides which essences they drop (question 2).
- **Encounters:**
  - the normal pool grows from 4 to about 8, spread over days 1–5
  - 3 elites instead of 2, so day 3 and day 5 vary between runs
  - Old Mother Ash stays the boss
- **Events:**
  - The design mentions **a tier-specific shop event** (an Act 1 event offering B-tier wares). It needs a small new event kind in code (a shop in an event), which I'd flag.
  - 1–2 more events to go with it.

### 7. Ready for playtesting
- **Balance with the run bot:**
  - The bot learns to use the new content: recruiting for class traits, and buying Epics for alloys.
  - I then tune encounter HP and damage until the bot's numbers hit the targets (question 6).
  - Every changed number gets a balance-sim run, as `CLAUDE.md` asks.
- **Show discovered synergies:** a synergy is found at a fight's start but only listed at the end of the run. I'd add:
  - a "Synergy discovered!" callout in the fight
  - a list of the run's discovered synergies in the guild panel
  - the active ones marked
- **A playtest journal:** each run writes a small JSON file to `user://playtests/`. It holds:
  - the seed
  - each day's picks, buys, and sells
  - each fight's result and length
  - how the run ended

  After you or your testers play, I can read these and report what happened (where runs die, what gets bought, what's never picked).
- **Builds for playtesters:** question 5.

### Pull requests (one per step, like the earlier steps)
1. Heroes and specializations (with their signatures and class traits).
2. Items, Epics, and alloys, plus pairs and transformations, and relics.
3. Act 1 enemies, encounters, and events.
4. The playtest pass: the bot, balance, synergy discovery in the UI, and the journal.

**Tests:**
- Data validation runs on every PR.
- Each new mechanic flagged above gets sim tests.
- New heroes and specializations get the same checks the first four have.
- The determinism tests keep passing.
- Balance reports go in each PR.

## Questions

1. **Which classes get a second hero?** My suggestion is a second Warden and a second Arcanist: a front-liner and a damage dealer, which suit multi-hero guilds best. The alternative is a second Striker or Mender.
2. **Act 1's essences:** the design says each biome favors **two** essences. Act 1 drops four today: Wrath (pups and hounds), Stone (sentinel), Venom (witches), and Ember (the boss). Which way?
   - a) **Two favored essences**, e.g. Ember and Wrath for the Ashen Hollow, with most fights dropping those and 1–2 elites off-biome for variety.
   - b) **Keep four** while the slice has only one act, so playtesters see more essences.
   - (Loot and Events give random essences either way.)
3. **Does 60 items count enemy-only items?** My suggestion is 60 items the guild can get from the Caravan and loot, with enemy-only items on top.
4. **Legendary items:** none exist, and each needs its own upgrade path (a system not designed yet). My suggestion is to leave Legendary items out of the slice; the boss's Legendary relics fill that role for now. Or should I add 1–2 without an upgrade path yet?
5. **How will playtesters run the game?** Options:
   - from the Godot editor (works today)
   - exported builds: which operating systems? The export templates are a large download, and I'd need to check this environment can fetch them.
6. **Balance targets for the bot:** now, 17% of bot runs clear the act and 58% of runs that reach the boss beat her. I'd aim for:
   - 25–35% of bot runs clearing the act (people should do better than the bot)
   - about 90% of day-1 fights won
   - day 3's elite no longer the biggest wall
