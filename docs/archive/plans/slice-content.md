# Plan: content to the slice targets, ready for playtesting (Phase 3, step 8)

Status: **approved; being built**, one PR per step. The answers are at the end.

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

## Answers

1. **Second heroes:** a second Warden and a second Arcanist for now. Eventually every class will have several heroes.
2. **Act 1's essences:** not decided yet. For now Act 1 keeps its four (Wrath, Stone, Venom, Ember), and new enemies spread across them. This is an open question in `docs/design.md`.
3. **Items:** 60 items the guild can get from the Caravan and loot. Enemy-only items come on top.
4. **Legendary items:** they wait. Legendary items and their upgrade paths are the next piece of work after this step (now built: `docs/plans/legendary-items.md`).
5. (Playtest builds: not answered yet. Playtests run from the Godot editor until then.)
6. **Balance targets** (for now):
   - 25–35% of bot runs clear the act
   - about 90% of day-1 fights won
   - day 3's elite no longer the biggest wall

## Built: step 1, the four new heroes

All data, using existing effect types (no new code).

| Hero | Class | Role | Basic attack | Backup | Signature item |
| --- | --- | --- | --- | --- | --- |
| Maren Thistledown | Ranger | Back-row archer | Longshot: hits the enemy back row | Marking Shot: Bleed on a back-row enemy every 6s | Thistledown Longbow (Blackthorn Bow, +15% crit) |
| Pell Candlewick | Trickster | Blind, Slow, cooldowns | Sleight of Hand: a random enemy | Loaded Dice: blinds a random enemy every 6s | Pinch of Salt (Salt Ward also slows a random enemy) |
| Old Hesk of the Gate | Warden | A second wall | Gate Slam: scales from his HP | Gatekeeper's Toll: a small shield on every ally every 6s | The Gate Bell (Bell of Vigil, 15% faster) |
| Ysolde Ashwhisper | Arcanist | A burn caster | Cinder Dart: damage plus Burn | Smolder: Burn on the front row every 5s | Brazier Keeper (Ember Brazier burns 20% hotter) |

**Specializations** (3 each, locked potential at B/A/S):
- **Maren:**
  - **Deadeye:** ranged crits, follow-up shots, heavier arrows.
  - **Trapper:** a Snare ability that slows, then bleeds, then covers every enemy.
  - **Volley:** her auto-attack hits every enemy. It comes with an auto-attack part, an arcing shot at the back row.
- **Pell:**
  - **Smoke and Mirrors:** a Smoke Bomb that blinds, then slows; at S, a once-per-fight save.
  - **Clockwork Tricks:** faster tools that wind their neighbors; at S, a Spanner in the Works that freezes every enemy for 1s every 8s.
  - **Cutpurse:** a quick auto-attack on the weakest enemy that slows; at S, crits that blind.
- **Old Hesk:**
  - **Bulwark:** a Brace ability; at S it covers his row.
  - **Thornhide:** his defense items strike back, then leave Bleed.
  - **Old Guard:** a backup spec.
- **Ysolde:**
  - **Ashcaller:** Ash Rain.
  - **Emberheart:** her own magic and crits.
  - **Kindler:** support that quickens and winds her allies.

**Class traits:** Rangers (ranged items hit harder) and Tricksters (tools fire faster). With Hesk and Ysolde, the Warden and Arcanist traits can now trigger. The Ranger and Trickster traits wait for more heroes of those classes.

**Tests:**
- Every hero has a basic attack, a Backup effect, three specializations, and one signature.
- Every class has a trait, and all six classes are in the slice.
- Two Wardens set off the Wardens trait.
- Hesk's Gate Slam scales from his HP.
- Mutation checks (dropping a class trait, dropping a Backup) fail these tests.

**Balance findings:**
- **Sim parties** (`tools/sim_parties.json`: `newcomers_specialized`, `newcomers_with_vell`, `twin_classes`):
  - At rank A with specializations, the new heroes win every Act 1 fight, as the original four do.
  - Swapped one at a time into the starter party with the same items, Hesk plays like Brannoc and Ysolde like Odo.
  - Maren and Pell trail Wren in her front-row slot, partly because Maren spends her damage on the back row. Their stats were raised to Wren's level (HP 270, ATK 22/20, ATSP 10/15).
- **The run bot:** act clears fell from 17% to 7%, but every hero fell, not the new ones.

  | Starting hero | Act clears before | Act clears after |
  | --- | --- | --- |
  | Brannoc | 30% | 17% |
  | Old Hesk | – | 18% |
  | Wren | 15% | 5% |
  | Maren | – | 8% |
  | Pell | – | 9% |
  | Vell | 9% | 0% |
  | Odo | 1% | 0% |
  | Ysolde | – | 1% |

  With 8 heroes in the pool, the Caravan offers a copy of a held hero half as often, so guilds rank up less. The balance pass (step 4) retunes for the bigger pool against the targets above. Starts with a fragile hero (Odo, Vell, Ysolde) are the weakest either way.

## Built: step 2, items, alloys, synergies, and relics

All data. The six new alloys each bring a status type built from the existing status parts (no new code).

**Items:** 37 new ones, for 60 the guild can get plus 5 enemy-only.
- **Rarity:** 12 Common, 9 Uncommon, 9 Rare, and 7 Epic, for 20/18/14/8 overall.
- **Size:** 18 Small, 15 Medium, and 4 Large.
- **By role:**
  - **Ranged (for Maren):**
    - Birch Shortbow, a Crow-Feather Crossbow, and a Rimewood Longbow (Epic), all auto-attacks that reach the back row
    - Flint Arrows and Thorn Darts
    - a Greywood Warbow (Large)
    - Stormglass Arrowheads, which boost the ranged items beside them
    - a Hunter's Snare
  - **Tricks (for Pell):**
    - Soot Bomb and Mirror Shard (Blind)
    - Trick Coin (winds its neighbors)
    - Hexed Lockbox (Freeze)
    - Hobnail Boots (+8% ATSP)
    - a Clockwork Owl (Epic: winds the row and blinds)
  - **Defense:**
    - Iron Pot Lid and Spiked Pauldron (strikes back)
    - Mudbrick Wall (the row)
    - Quartered Shield
    - Gatekeeper's Tower Shield (Epic)
  - **Magic:**
    - Slate Tablet and an Ashwood Staff (an auto-attack for casters)
    - a Grimoire of Cinders
    - Venom Censer and Bone Flute (every enemy)
    - an Ashen Censer and a Wyrdglass Orb (Epics)
  - **Healing:**
    - Peat Poultice and Bitter Draught (scales from HP)
    - a Mender's Satchel (cleanses)
    - Pilgrim's Censer (the whole guild)
    - Hearthkeeper's Kettle (Epic)
  - **Melee:**
    - Hatchet and Longspear (grazes the back row)
    - a Reaper's Sickle (hunts the weakest; crits bleed)
    - Twinfang Stilettos (Epic)
- **Tuning:** numbers were tuned against the existing items of the same size and rarity:
  - shields against Oak Buckler (10 + 40% DEF every 2.5s)
  - damage against Hearth Knife, Rusted Cleaver, and Twin Daggers
  - heals against Old Lantern

  Epics may scale from CRIT and ATSP, as the design allows.

**Alloys:** 6 new ones, for 10 in total.

| Alloy | Recipe | Its status |
| --- | --- | --- |
| Deathcap | Venom + Venom | Poison that also lowers DEF |
| Deep Freeze | Frost + Frost | Rime: a stronger, longer Slow |
| Searfire | Ember + Wrath | Burn that's full strength against shields and lingers |
| Caustic | Ember + Venom | Poison that ticks twice as fast but fades |
| Nightshade | Venom + Umbral | Bleed that ignores shields and lowers DEF by 2 |
| Hemorrhage | Umbral + Umbral | Bleed with twice the damage per stack |

**Synergies** (33 in total):
- **Pairs:**
  - Fletcher's Rhythm (Birch Shortbow + Flint Arrows)
  - Hunter's Kit (Hunter's Snare + Barbed Net)
  - Smoke and Coin (Soot Bomb + Trick Coin)
  - A Full Kettle (Hearthkeeper's Kettle + Hearth Stew)
- **Transformations:**
  - Frostfletch: Flint Arrows + Frost slow the back row
  - Venomous Snare: Hunter's Snare + Venom also poisons

**Relics** (20 in total), all build-shaping:
- **Common:** Fletcher's Quiver (ranged crit), Rootbound Charm (back-row DEF)
- **Uncommon:** Tinker's Mainspring (tools faster), Adder's Vial (poison items)
- **Rare:** Mourning Bell (a shield on every ally at 30s), Thief's Glove (weapon crits blind)

**UI:** a color and a shape for each new status.

**Tests:**
- Each new alloy turns the item's own status into its own status type, and plain statuses are untouched.
- Recipes work in either order.
- Hemorrhage deals twice Bleed's damage per stack.
- The slice item roster holds: 60 guild items; more Small than Medium than Large; Epics with 2 sockets; at least 3 items per tag.
- Mutation checks (Hemorrhage at 1 damage per stack, Searfire turning Burn into the wrong status) fail these tests.

**Balance findings:**
- **Sim parties** `slice_commons` (the starter heroes with only the new Commons) and `slice_kit` (the new heroes with new items and Epics):
  - The Commons party beats the sentinel vigil but mostly loses to the hound pack. It carries no Uncommon or Rare items, so this is expected.
  - The Epic kit beats the hound pack, the sentinel, and the witch-coven elite (93%).
- **The run bot:** act clears fell again, from 7% to 3%.
  - It's the same effect as the new heroes: with 60 items, the Caravan offers a copy of an item you hold far less often, so fewer items combine to a higher tier.
  - 97 of 200 runs end on day 3's elite.
  - Steps 3 (encounters) and 4 (the balance pass) retune for this against the targets.

## Built: step 3, Act 1's enemies, encounters, and events

**New code:** one event kind, `tier_shop` (`EventDef`, `RunFlow._add_tier_shop`).
- It offers `count` different items (never enemy-only), all at the event's `tier`, each priced like the Caravan's wares of that tier.
- The player buys any they can afford, or leaves.
- This is the design's "event that opens a tier-specific shop", the way higher tiers appear before the Caravan sells them.

**Enemies:** 5 new ones, across the four current essences (question 2 is still open).

| Enemy | Essence | Role | Carries |
| --- | --- | --- | --- |
| Ashling | Ember | Early fodder | Hatchet |
| Cinder Moth | Ember | Fragile back-row burner | Cinder Dust (enemy-only: Burn on a random foe) |
| Bog Lurker | Venom | Mid-act bruiser | Lurker Fang (enemy-only: poisons on hit) |
| Hollow Archer | Wrath | Shoots the guild's **back row** | Flint Arrows |
| Cairn Guardian | Stone | Elite wall | Cairn Stone (enemy-only: shields every ally) |

**Encounters:**
- **Normal pool** (4 → 8):
  - days 1–2: A Litter of Pups or **An Ash Swarm**
  - days 2–4: A Hound and Its Pup or **A Cloud of Moths**
  - days 4–5: Hound Pack, Sentinel's Vigil, **A Bog Ambush**, or **An Archers' Nest**
- **Elites** (2 → 3): **The Cairn Watch** (a Cairn Guardian shielding two archers) can come on day 3 or day 5, so both elite days now vary.

**Events** (8 → 10):
- **A Smith's Cart** (weight 4): 3 B-tier items at B prices.
- **The Ashen Market** (weight 1, rare): 2 A-tier items at A prices.

**Tests:**
- The tier shop offers different items (checked across 59 seeds), at its tier and price, never enemy-only; any can be bought until the gold runs out.
- Bad tier-shop data is refused (no tier, unknown tier, too many items).
- Updated for the new pools: day 1 now draws from two encounters, and the tests that needed the pup litter now set it.
- Mutation checks (free wares, the wrong tier, repeated items) all fail a test. The repeated-items check needed the many-seeds version.

**Balance findings:** the bot's losses per encounter (300 runs), after tuning the new enemies up from "never loses":

| Encounter | Days | Losses |
| --- | --- | --- |
| A Litter of Pups | 1–2 | 0% |
| An Ash Swarm | 1–2 | 1% |
| A Cloud of Moths | 2–4 | 3% |
| A Hound and Its Pup | 2–4 | 15% |
| An Archers' Nest | 4–5 | 0% |
| A Bog Ambush | 4–5 | 12% |
| Hound Pack | 4–5 | 33% |
| Sentinel's Vigil | 4–5 | 65% |
| The Cairn Watch (elite) | 3 or 5 | 62% |
| Witch Coven (elite) | 5 | 61% |
| The Hound Alpha (elite) | 3 | 72% |
| The Ash Mother (boss) | 6 | 90% |

- The new normal fights sit at the gentler end.
- The legacy Hound Pack is harder than the Hound Alpha elite (in the sim too); step 4 evens this out.
- **The run bot:** 2% of runs clear the act, but 50 of 200 reach the boss, up from 26, because the new day-4–5 fights are gentler. 110 of 200 runs still end on day 3's elite.
- **Step 4 targets:** 25–35% of runs clearing the act, day 3 no longer the wall, and a boss that about half the guilds that reach her can beat.

## Built: step 4, the playtest pass

**The run bot** (`RunBot`) now plays more like a person would:
- Sturdy classes (Warden, Striker, Trickster) stand in the front row and the rest in the back. Before, only the first hero stood in front, and new heroes joined the back row, so a second Warden sat behind the casters.
- It recruits up to 4 heroes, not 3.
- At the Caravan it buys upgrades for held copies first, then the rarest wares (so Epics get bought for alloys), cheapest first within a rarity.

That alone took act clears from 3% to 22%. Much of the earlier drop was the bot standing its casters in front, not only the bigger pool.

**Balance** (placeholders, tuned with the bot):
- The Cairn Guardian: 1800 → 1500 HP, 30 → 25 DEF. The Cairn Watch had become the new wall.
- Old Mother Ash: 11000 → 10000 HP.
- Vell, Odo, and Ysolde: +40 HP each. A fragile first hero has to stand in front alone early on.

| Target | Result |
| --- | --- |
| 25–35% of bot runs clear the act | 33% (seeds 1–200), 29% (seeds 1001–1200) |
| About 90% of day-1 fights won | about 99% (Pups and the Ash Swarm lose 0–1%) |
| Day 3's elite no longer the wall | Runs now end most often at the boss (84 of 200) rather than on day 3 (36 of 200) |
| The boss about 50% for guilds that reach her | 40–44% |

- **By starting hero:**
  - Wren, Brannoc, Hesk, and Maren clear 42–50% of runs.
  - Pell clears about 30%.
  - Ysolde, Odo, and Vell clear 18–25%. Fragile casters still start harder.

**Synergies in the UI:**
- **In the guild panel:** a "Synergies found" line shows the synergies this run has discovered.
  - Undiscovered ones stay hidden, as the design wants.
  - The ones active for today's fight, with the guild as it stands, are lit and starred.
  - Hovering one shows what sets it off and what it does (`ItemInfo.synergy_text`).
  - "Active" comes from a throwaway fight setup (`RunSession.active_synergies`); the run never changes.
- **In the fight:** a fight that discovers a synergy for the first time opens with a "Synergy discovered: …" banner.

**The playtest journal** (`PlaytestJournal`): every run writes `user://playtests/run_<seed>.json`.
- **What it holds:**
  - the seed
  - each play session
  - every action the player took, with the day, step, and gold
  - each fight: the encounter, the result, its length, and the whole guild (heroes, ranks, specializations, rows, items with tiers, essences, and XP)
  - how the run ended
- **When it's saved:** after every change, so a crash loses nothing.
- **Continuing:** a continued run picks up its journal.
- **Where to find `user://`:** on Windows it's `%APPDATA%\Godot\app_userdata\Riftrite\`, on macOS `~/Library/Application Support/Godot/app_userdata/Riftrite/`, and on Linux `~/.local/share/godot/app_userdata/Riftrite/`.

**Tests:**
- the journal: a run writes it, fights record the guild, continuing picks it up and records the end, and sessions without a journal write nothing
- the guild panel's discovered and active synergies (undiscovered stay hidden)
- the discovery banner, only the first time
- the synergy text
