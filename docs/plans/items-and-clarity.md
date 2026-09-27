# Plan: fewer, clearer items; click for details; unlock popups; a harder Act 1 (redesign step 7)

After the redesign was built, the user played it (2026-09-27). What they found:

- **Too many items.** There are 76 the guild can get.
- **Abilities look and play like basic attacks.** 52 items are abilities, but most fire every 1.5–3.5s, the same rhythm as a weapon (1.3–2s). Only 7 items are weapons.
- **The game is far too easy.** The run bot clears 58% of runs, but it plays badly; a real player "can't imagine losing".
- **It's hard to tell what anything does.** Items, essences, and specializations are only explained by hover text.
- **Unlocks are easy to miss.** A deed's level-2 choice and the rank-B specialization pick deserve a moment of their own.

The user's answers are under **Decisions** at the end.

## 1. Each slot has one job

| Slot | Job | Rhythm | Examples |
| --- | --- | --- | --- |
| **Weapon** (basic attack) | The steady damage. Each weapon type feels different: a dagger is fast and crits, a cleaver is slow and heavy, a crossbow shoots the back row. | fires every 1–2s | Hatchet, Crow Crossbow, Ashwood Staff |
| **Ability** | A real move that does something big and specific | 6–15s cooldowns | Flurry (6 strikes in 1s), Sweeping Spear (hits the whole front row), Hearth Feast (heals everyone), Plague Cloud (Poison on every enemy) |
| **Passive** | Always on: auras, triggers, conduits | never fires on a cooldown | War Drum, Leech Vial, Bond Chain |

- **Weapons are items now, not only built-in attacks.** A hero's built-in basic attack stays as the fallback. It's weaker than a weapon, so the weapon slot is worth filling.
- **Abilities hit much harder per fire,** to make up for their long cooldowns. A hero with 2–4 abilities has a big move every few seconds, and each one reads clearly on the fight screen.
- **Two small code additions** (rule 3: no combination of existing effects can say these):
  - `"hits"` and `"hit_interval_ms"` on a damage effect: one fire lands several quick strikes, each a hit (it can crit and set off `on_hit`). This makes Flurry and Barrage possible.
  - targets `enemy_front_row` and `enemy_back_row`: every enemy standing in that row.

## 2. Each slot looks different

Everywhere items show up (the shop, loadouts, the stash, rewards, the fight screen):

| Slot | Frame | Also |
| --- | --- | --- |
| Weapon | a square steel frame with a blade mark in the corner | "Weapon" under the name |
| Ability | a round rune medallion; in fights, its cooldown ring runs around the rim | "Ability · 8s" |
| Passive | a shield-shaped frame, no cooldown ring | "Passive" |

The loadout's slot groups use the same shapes, so an empty ability slot looks like an empty medallion.

## 3. About 40 items (the user's pick)

The roster drops from 76 to **40**: 10 weapons, 18 abilities, and 12 passives. Every keyword stays covered. The six Legendaries stay, each moved to the slot that fits it. Enemy-only items follow the same split. Names are kept where the item survives; numbers are first passes, tuned with the balance sim.

**Weapons (10)**

| Item | Keywords | What it does |
| --- | --- | --- |
| Hatchet | Blade | quick chops at the front enemy (1.2s) |
| Rusted Cleaver | Blade | slow, heavy hits at the front enemy (2.0s) |
| Twin Daggers | Blade | two light stabs, crits often (1.0s) |
| Grave Hook | Blade, Bleed | hits and Bleeds the front enemy (1.6s) |
| Birch Shortbow | Bow | fast shots at the back row (1.3s) |
| Crow Crossbow | Bow | slow, heavy bolts at the back row (2.0s) |
| Thorn Darts | Bow, Hex | darts at a random enemy that Poison (1.5s) |
| Ashwood Staff | Spell, Burn | magic hits that Burn (1.5s) |
| Wyrdglass Orb | Spell | magic bolts at a random enemy, crits often (1.4s) |
| Spiked Pauldron | Blade, Ward | shoulder charges that also Shield the holder (1.8s) |

**Abilities (18)**

| Item | Keywords | What it does |
| --- | --- | --- |
| Twinfang Stilettos → **Flurry** | Blade | 6 quick strikes in 1 second at the front enemy (8s) |
| Longspear → **Sweeping Spear** | Blade | hits the whole enemy front row (7s) |
| Reaper's Sickle | Blade, Bleed | a heavy blow on the weakest enemy; a crit adds 3 Bleed (9s) |
| Greywood Warbow → **Volley** | Bow | an arrow at every enemy in the back row (7s) |
| Flint Arrows → **Barrage** | Bow | 4 quick shots at the back row (6s) |
| Hunter's Snare | Bow, Hex | 3 Slow on the front enemy (8s) |
| Grimoire of Cinders → **Firebolt** | Spell, Burn | a big magic hit and 3 Burn (8s) |
| Ember Brazier → **Wildfire** | Spell, Burn | 2 Burn on every enemy (9s) |
| Dusk Tome → **Dusk Wave** | Spell | magic damage to every enemy (10s) |
| Hearth Stew → **Hearth Feast** | Mend | heals every ally (10s) |
| Mender's Satchel → **Triage** | Mend | a big heal and a cleanse on the ally lowest on HP (8s) |
| Hearthkeeper's Kettle | Mend, Ward | heals and Shields the ally lowest on HP (9s) |
| Mudbrick Wall → **Raise Wall** | Ward | Shields the holder's row (8s) |
| Tower Shield → **Bulwark** | Ward | a big Shield on every ally (14s) |
| Venom Censer → **Plague Cloud** | Spell, Hex | 3 Poison on every enemy (10s) |
| Bone Flute → **Dirge** | Hex | 2 Slow on every enemy (9s) |
| Barbed Net | Bleed | 2 Bleed and 1 Slow on every enemy in the front row (9s) |
| Clockwork Owl | Hex | charges the holder's other abilities by 3s, and Blinds a random enemy (10s) |

**Passives (12):** War Drum (Blade), Bell of Vigil (Ward), Stormglass Arrowheads (Bow), Vesper Chime (Mend), the four conduits (Ember Censer, Open Channel, Bond Chain, Rift Prism), Tinder Charm (Burn), Thorn Vest (Ward), Leech Vial (Bleed), and Hex Bag (Hex).

**Legendaries (6, kept):** Tallyman's Bow, Maw of the Hollow, and Riftbreaker's Brand become weapons. Hungering Censer, Kinstone Aegis, and Last Hearth Lantern become abilities, with longer cooldowns and bigger numbers.

**What else changes with the roster:**
- **The 36 cut items leave the game:** near-duplicates (several quick blades, bows, and shields that did the same thing), most of the items that only charge other items, the Blind trinkets, and the weakest commons.
- **Synergies:** the 11 that name a cut item (4 pairs, 2 transformations, 5 signatures) are moved to kept items, so every hero keeps a signature.
- **Kits, shops, and sim parties** are updated to match.
- **Enemies:** enemy items follow the same split. Rift Claw becomes a weapon, and some enemies get an ability as their "move".

## 4. Click an item or a hero for a big popup (the user's pick)

- **What you can click:** only items and heroes, and only outside fights. Hover stays as the quick preview.
- **What opens:** a large popup over the screen, closed with a button, Escape, or a click outside it.

**An item's popup:**
- its name, slot, rarity, and tier, and each keyword with what that keyword means
- what it does, in full sentences, with its real numbers for the hero holding it: base, what it scales from, and the tier boost
- for an ability, the cooldown; for a weapon, how often it fires
- **its infusion:**
  - each essence and what it does on this item at Base, Attuned, and Resonant, with the current level marked and XP to the next
  - for an alloy or pure double, what its special does once it awakens
  - what it spills or spreads, and to which items
- the synergies it's part of that you've found, and "?" for ones you haven't
- the actions you can take (equip, move, infuse, combine, sell at a shop), as before

**A hero's popup:**
- stats, rank, and slots
- their innate and their two affinities (with each perk)
- **their calling:** the goal, progress, and all three levels, with both level-2 options
- **their specialization:** if chosen, the same as the calling; if not, a preview of the three to choose from at rank B
- duo bonds found, and "?" for ones not found yet
- their loadout, each item clickable

## 5. Unlock popups (the user's pick)

- **When a choice waits,** a popup covers the screen: a deed reaching level 2 (its two options), or a hero reaching rank B (their three specializations).
- **Each path is shown in full,** side by side: its name, what it does in plain words with the hero's numbers, and for a specialization, its deed and all three levels.
- **You pick one to close it.** There's no "later", so it can't be missed.
- **If it happens during a fight** (a deed level reached mid-fight), the popup waits until the fight's end screen is done. Several waiting choices come one after another.
- **The rules don't change:** the level-2 choice is still made between fights (`RunActions.choose_deed_unlock`) and the specialization at rank B (`RunActions.choose_specialization`). The popup is just where you make them now.

## 6. A harder Act 1 (the user's target: a good player clears about half the time)

**The run bot can't measure this as it is.** It buys the rarest item it sees, spreads items with no plan, and infuses at random.

**A smarter bot first** (`RunBot`, a "good player" strategy next to the current one):
- it plans a build per hero from the hero's affinities and keywords
- it buys items that fit the plan, and weapons for empty weapon slots
- it infuses to match (the same essence on items that share a keyword, so they spill)
- it takes kits that match, and picks deed options and specializations by a simple score
- it takes the harder fight when its team is ahead

**Then tune Act 1 until the good bot clears about 45–50%** (a person usually beats a bot, so a good person should land near half). The levers, all data:
- enemy HP and damage per day (`hp_bp` in `data/acts.json`, plus a new `damage_bp` next to it)
- elite and boss stats
- gold and prices
- Rift Collapse timing

The run report shows both bots side by side, so the gap between a random player and a planned one stays visible.

## 7. Build order

Each part is its own PR:

1. **Slots and roster:** the two sim additions (multi-hit, row targets), the 40 items, the cut items removed, synergies, kits, enemy items, sim parties, and tests. Rerun the balance sim.
2. **The look:** slot frames and labels everywhere.
3. **Popups:** the item and hero popups, then the unlock popup.
4. **Difficulty:** the good-player bot, then tuning Act 1 to its target.

## Decisions (from the user, 2026-09-27)

- **Roster:** about 40 items for now.
- **Slots:** weapons carry the steady damage (every 1–2s); abilities are real moves on 6–15s cooldowns with big, specific effects; passives are always on.
- **Difficulty:** a good player should clear Act 1 about half the time.
- **Clicking:** only items and heroes, as a big popup, and only while not in a fight.
- **Unlocks:** a deed unlock or specialization unlock shows a popup with its paths, covering the screen; during a fight, it waits until after the fight.
