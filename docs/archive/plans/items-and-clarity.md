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

## 3. A shared pool, plus Epics that belong to heroes (the user's idea)

**Commons, Uncommons, and Rares are shared:** a fixed set of 28 any team can find. **Epics belong to heroes:** each hero has three, one built for each of their specializations (24 in all).
- **Only the drafted team's Epics show up in shops.** A run's shop pool is the 28 shared items plus the team's 9 Epics, about 37.
- **Off-team Epics can still turn up** from the Vault, events, elite and boss rewards, and Loot (rarely).
- **Anyone can equip a hero's Epic,** but on its own hero it gets an extra effect: "On Wren: ...". This replaces the signature synergy layer (the 8 signatures are removed; their ideas move into the Epics).
- **Shops show Epics a bit more often,** since only 9 of 24 are in a run's pool.
- **Legendaries stay as they are** (6, from the Vault and rare events only), each moved to the slot that fits it: Tallyman's Bow, Maw of the Hollow, and Riftbreaker's Brand become weapons; Hungering Censer, Kinstone Aegis, and Last Hearth Lantern become abilities with longer cooldowns and bigger numbers.

In all: 28 shared + 24 Epics = 52 items, down from 76. A run only ever sees about 37 of them (the shared 28 and its team's 9 Epics), close to the 40 asked for. Names stay where an item survives. Numbers are first passes, tuned with the balance sim.

**Shared weapons (8)**

| Item | Rarity | Keywords | What it does |
| --- | --- | --- | --- |
| Hatchet | Common | Blade | quick chops at the front enemy (1.2s) |
| Rusted Cleaver | Common | Blade | slow, heavy hits at the front enemy (2.0s) |
| Birch Shortbow | Common | Bow | fast shots at the back row (1.3s) |
| Thorn Darts | Common | Bow, Hex | darts at a random enemy that Poison (1.5s) |
| Twin Daggers | Uncommon | Blade | two light stabs, crits often (1.0s) |
| Grave Hook | Uncommon | Blade, Bleed | hits and Bleeds the front enemy (1.6s) |
| Crow Crossbow | Uncommon | Bow | slow, heavy bolts at the back row (2.0s) |
| Ashwood Staff | Uncommon | Spell, Burn | magic hits that Burn (1.5s) |

**Shared abilities (11)**

| Item | Rarity | Keywords | What it does |
| --- | --- | --- | --- |
| Longspear → **Sweeping Spear** | Common | Blade | hits the whole enemy front row (7s) |
| Flint Arrows → **Barrage** | Common | Bow | 4 quick shots at the back row (6s) |
| Mudbrick Wall → **Raise Wall** | Common | Ward | Shields the holder and its row (8s) |
| Hunter's Snare | Uncommon | Bow, Hex | hits the front enemy and Slows it 3 (8s) |
| Hearth Stew → **Hearth Feast** | Uncommon | Mend | heals every ally (10s) |
| Mender's Satchel → **Triage** | Uncommon | Mend | a big heal and a cleanse on the ally lowest on HP (8s) |
| Barbed Net | Uncommon | Bleed | 3 Bleed and 1 Slow on every enemy in the front row (9s) |
| Reaper's Sickle | Rare | Blade, Bleed | a heavy blow on the weakest enemy; a crit adds 3 Bleed (9s) |
| Greywood Warbow → **Volley** | Rare | Bow | an arrow at every enemy in the back row (7s) |
| Grimoire of Cinders → **Firebolt** | Rare | Spell, Burn | a big magic hit and 5 Burn (8s) |
| Venom Censer → **Plague Cloud** | Rare | Spell, Hex | 3 Poison on every enemy (10s) |

**Shared passives (9):** War Drum (Blade: crit), Stormglass Arrowheads (Bow: damage), Vesper Chime (Mend: healing), Thorn Vest (Ward: strikes back when hit), Leech Vial (Bleed, Mend: a kill heals), Hex Bag (Hex: every 3rd status Slows), and three conduits: Ember Censer, Bond Chain, and Rift Prism.

**Hero Epics (24)**, one per specialization. "On X" is the extra effect on its own hero.

| Hero | Specialization | Epic | Slot | Keywords | What it does | On its hero |
| --- | --- | --- | --- | --- | --- | --- |
| Brannoc | Hearthwall | Tower Shield (Bulwark) | Ability | Ward | a big Shield on every ally (14s) | the Shields are 30% bigger |
| Brannoc | Ironbrand | **Hearthbrand Mace** | Weapon | Blade, Ward | heavy blows that Shield him (1.8s) | each blow also Shields his row a little |
| Brannoc | Last Watch | **Watchman's Horn** | Ability | Ward, Mend | Shields and heals every ally (12s) | it also sounds by itself the first time an ally drops below 50% HP |
| Wren | Duelist | Twinfang Stilettos | Weapon | Blade | two fast stabs; crits Bleed (1.1s) | +15% crit |
| Wren | Windrunner | **Gale Blades** (Flurry) | Ability | Blade | 6 quick strikes in 1 second at the front enemy (8s) | it fires 25% faster |
| Wren | Nightstalker | **Hunter's Moon** | Ability | Blade, Bleed | a strike on the weakest enemy and 3 Bleed (8s) | 2 more Bleed |
| Vell | Lanternbearer | Night Lantern | Ability | Mend, Spell | a big heal on the ally lowest on HP, and a little for everyone (9s) | also cleanses |
| Vell | Wardweaver | Hearthkeeper's Kettle | Ability | Mend, Ward | heals and Shields the ally lowest on HP (9s) | also heals every ally a little |
| Vell | Vigil Keeper | **Vespers Bell** | Passive | Mend | every 3rd heal its holder gives also heals every ally a little | those heals are 50% stronger |
| Odo | Pyromancer | **Ember Grimoire** | Ability | Spell, Burn | a big hit and 3 Burn on the front enemy, and 1 Burn on two others (8s) | one more ember |
| Odo | Hexweaver | **Hexbinder's Rod** | Weapon | Spell, Hex | magic hits that Poison (1.5s) | every 4th hit Poisons every enemy |
| Odo | Stormcaller | Wyrdglass Orb | Ability | Spell | magic damage and 1 Slow on every enemy (10s) | a second, smaller storm |
| Maren | Deadeye | Rimewood Longbow | Weapon | Bow | heavy shots at the back row, crits often (1.5s) | +15% crit |
| Maren | Trapper | **Bramble Snares** | Ability | Bow, Bleed | 2 Slow and 2 Bleed on every enemy in the front row (9s) | the back row too |
| Maren | Volley | **Stormfeather Quiver** | Ability | Bow | an arrow at every enemy (7s) | two arrows each |
| Pell | Smoke and Mirrors | **Smokeglass Vial** | Ability | Hex | Blinds every enemy (10s) | also Slows |
| Pell | Clockwork | Clockwork Owl | Ability | Hex | charges his other abilities by 3s and Blinds a random enemy (10s) | charges by 5s |
| Pell | Cutpurse | **Cutpurse's Kris** | Weapon | Blade, Hex | quick picks at the weakest enemy that Slow; crits often (1.0s) | crits Blind |
| Hesk | Bulwark | **Gatekeeper's Pavise** | Ability | Ward | a big Shield on him and a smaller one on his row (10s) | the row's Shield matches his |
| Hesk | Thornhide | **Bramble Mail** | Passive | Ward, Bleed | when an enemy's hit lands, it strikes back; every 3rd also Bleeds | it strikes back twice as hard |
| Hesk | Old Guard | **Old Guard's Standard** | Passive | Ward | its holder's row gets +15% DEF, and Shields on it are 15% stronger | every ally gets +15% DEF too |
| Ysolde | Ashcaller | Ashen Censer | Ability | Spell, Mend, Burn | 3 Burn on every enemy, and a little healing for every ally (10s) | 4 Burn |
| Ysolde | Emberheart | **Heartfire Wand** | Weapon | Spell, Burn | magic bolts; crits Burn (1.3s) | +10% crit |
| Ysolde | Kindler | Open Channel | Passive | Spell | a conduit: the holder's spills reach every ability | her Spell items fire 10% faster |

Names in bold are new items; the rest are current items moved into place. Some bonuses differ from the first plan: a hero part can add effects, auras, and abilities, but can't change an item's number of strikes or its "every Nth" count, so those became other bonuses.

**What else changes with the roster:**
- **The cut items leave the game:** near-duplicates (several quick blades, bows, and shields that did the same thing), most of the items that only charge other items, the Blind trinkets, and the weakest commons.
- **Code:** an Epic names its hero (`"hero"` on the item) and its extra effect (`"hero_parts"`, the same parts as specializations and duo bonds), credited "Twinfang Stilettos (Wren's own)". The shop pool filters Epics by the team. The signature synergy layer is removed.
- **Synergies:** the 3 pairs and 2 transformations that name a cut item move to kept items.
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

## Part 1 balance (run bot, 200 runs)

- **The act:** the bot clears 66% of runs (58% before part 1). Difficulty gets its own pass in part 4, with a smarter bot.
- **Enemy items follow the slot split,** with their damage per second kept close to before: Rift Claw became the hounds' weapon, the Sentinel's Hollow Maw and the witches' Gloom Spit became 6s and 5s moves, the Lurker Fang a weapon, and the Cairn Stone an 8s ward.
- **The guild's shared defensive abilities were trimmed** (Raise Wall, Triage, Hearth Feast) after the first run showed them shielding and healing far more than before.
- **Fights lost:** normal 2% easier and 13% harder; elites 15% and 28%; the boss 18%. By encounter, the Witch Coven (5%) and the Sentinel's Vigil (10%) became easier and the Hound Alpha (24%) harder; part 4 retunes them.

## 7. Build order

Each part is its own PR:

1. **Slots and roster:** the two sim additions (multi-hit, row targets), hero Epics (`hero`, `hero_parts`, the shop filter), the 52 items, the cut items removed, synergies, kits, enemy items, sim parties, and tests. Rerun the balance sim.
2. **The look:** slot frames and labels everywhere.
3. **Popups:** the item and hero popups, then the unlock popup.
4. **Difficulty:** the good-player bot, then tuning Act 1 to its target.

## Decisions (from the user, 2026-09-27)

- **Roster:** about 40 items for now, then (the user's idea) a shared pool of Commons, Uncommons, and Rares, plus Epics that belong to heroes: 3 per hero, one per specialization. Only the team's Epics appear in shops; the Vault, events, elite and boss rewards, and Loot can give any hero's. Anyone can equip a hero's Epic, and on its own hero it does more (replacing signature synergies).
- **Slots:** weapons carry the steady damage (every 1–2s); abilities are real moves on 6–15s cooldowns with big, specific effects; passives are always on.
- **Difficulty:** a good player should clear Act 1 about half the time.
- **Clicking:** only items and heroes, as a big popup, and only while not in a fight.
- **Unlocks:** a deed unlock or specialization unlock shows a popup with its paths, covering the screen; during a fight, it waits until after the fight. The player must pick one to close it.
- **Build order:** slots and roster, then the look, then the popups, then difficulty.
