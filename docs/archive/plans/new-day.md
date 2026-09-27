# Plan: the new day, the economy, and pacing (redesign step 4)

Step 4 of `docs/plans/fun-redesign.md` (sections 3 and 6). It replaces the day of `docs/plans/day-structure.md` and the stop pool of `docs/plans/stop-nodes.md`, where they differ.

## The day

```
start_hero (x3) ─► start_package ─► [ stop_choice ─► stop ─► stop_choice ─► stop ─► fight_choice ─► fight ─► rewards ] x 8 days ─► act_end
```

- **No daily Caravan.** Shops are stops like any other.
- **Two stop visits a day.** Each visit offers **2 stops**: one is always a shop, and the other is any stop that isn't a shop.
  - The other stop is one of: the Forge, Loot, the Vault, Retrain, or an event.
  - Both are drawn by weight from the stops that apply right now.
- **The fight: pick 1 of 2.** The day's two fights are known from the start of the day, and the day bar shows them. You pick one after your second stop.
  - Each card shows the enemies, their essence, and whether the fight is **easier** or **harder**.
  - The harder fight pays more gold, and its reward pick has better rarity odds.
  - On elite days, both fights are elites.
  - On the boss day, the boss is the only fight, so there's no pick.
- **Rewards: pick 1 of 3.** Every win offers a pick of 3 items:
  - **One enemy drop.** It comes from the enemy team's items and relics, and can be an enemy-only item.
  - **Two items from the pool,** by the reward rarity odds (better after a harder fight), at the act's shop tier odds.

  Every win also gives, on top of the pick:
  - gold
  - **a whole essence** of the enemy team's essence, to take or pass on
  - after an elite: the rank-up, the relic choice, and the key chance, as before
  - after the boss: the relic choice
- **The boss day:** the first visit is a normal pick. The second visit is always the Upgrade stop.
- **A loss** replays the day from its first visit:
  - with fresh stops (the attempt number changes their seeds)
  - with the same two fights on offer
  - with bonus gold, as before
- The second loss still ends the run.
- **The Skirmish is removed.** So are essence shards: every win now gives a whole essence.

## Shops

A shop is a node with `"kind": "shop"` in `data/nodes.json`. It sells `shop_items` items (5), with buying, selling, and rerolling as the Caravan did.

| Shop | `"shop"` | Sells |
| --- | --- | --- |
| **The Caravan** | `{}` | Any item |
| **Keyword shops** (Blade, Bow, Spell, Mend, Ward, Burn, Bleed, Hex) | `{"keyword": "blade"}` | Items with that keyword |
| **Slot shops** (abilities, passives, basic attacks) | `{"slot": "passive"}` | Items for that slot |
| **Essence merchants** | `{"essence": "ember", "keywords": ["burn", "spell"]}` | Their essence (for `essence_price` gold), plus items with those keywords |
| **Tier shops** (the Smith's Cart and the Ashen Market) | `{"tier": "b", "count": 3}` | Items at a fixed tier. These were events and are now shops |
| **Synergy Peddler** | `{"partners": true}` | Items that pair with an item you hold, signature items for your heroes, and items that transform with an essence you hold. It never names the synergy. It tops up with any item when there aren't enough |

- Shop rules are unchanged:
  - no relics, no enemy-only items, no Legendaries
  - a shop never offers an item at a different tier than a copy you hold (tier shops excepted, as before)
- A shop with a filter that finds too few items tops up with any item.

## Economy and pacing

| | Before | Now |
| --- | --- | --- |
| Act 1 | 6 days: elites on days 3 and 5, boss on day 6 | **8 days: elites on days 3 and 6, boss on day 8** |
| Item price | By tier: 2/4/8/16 | **By rarity** at C: Common 2, Uncommon 3, Rare 5, Epic 7 (Legendary 10, but never sold). **×2 per tier** above C |
| Starting gold | 10 base, +8 from the gold package | Less (tuned with the run bot) |
| Essence per win | 1 shard (a whole one after elites and the boss) | **A whole essence after every win** |
| `xp_to_resonant` | 300 | **150** (`xp_to_attuned` 100 → 60) |
| Normal fight length | About 11s | **About 25–35s**, from more enemy HP |

Targets for the run bot:
- about **10–20%** of normal fights lost
- about **30%** of elites lost
- the boss somewhat easier than now

## Balance (run bot, 200 runs)

The act's HP scaling per fight (`hp_bp` on each pool entry in `data/acts.json`) was tuned toward the targets. It runs from 1.1x to 2.8x on normal fights, and from 0.7x to 1.5x on elites.

| | Lost | Length |
| --- | --- | --- |
| Normal fights, easier | 4% | 24s |
| Normal fights, harder | 17% | 26s |
| Elites, easier | 21% | 26s |
| Elites, harder | 36% | 34s |
| The boss | 32% (was 57%) | 45s |

- **The act:** 47% of runs clear it.
- **Where runs end:** most runs that end do so on day 3 (the first elite) or day 4.
- **Infusions:** runs end with about 8 infused items, 3.1 of them Resonant (was 0.13).
- **Bot strategy:** the bot clears 54% of runs when it always takes the easier fight, and 39% when it always takes the harder one. The harder fight's rewards don't make up for its risk for this bot, which doesn't plan its buys. It's worth watching in playtests.

## Code

- **Data**
  - `data/nodes.json`: the shop nodes. The skirmish node goes, and the tier-shop events move here.
  - `data/acts.json`: 8 days, and `"hard": true` on the harder encounters.
  - `data/economy.json`:
    - adds prices by rarity, `tier_price_bp`, `essence_price`, `shop_items`, `stops_per_day`, `hard_gold_bp`, and the reward rarity weights
    - drops shards, `caravan_items`, and the old item prices
- **`ShopDef`** (`src/run/defs/shop_def.gd`): a shop node's filter.
- **`RunFlow`**
  - The phases are start_hero, start_package, stop_choice, stop, fight_choice, fight, rewards, act_end, and run_over.
  - `pick_fight(i)` is new.
  - `buy`, `sell`, and `reroll` work at a shop stop.
  - `skirmish()` is removed.
- **`RunState`**
  - `visit` (0 or 1: which stop visit of the day) replaces the unused `step`.
  - `fight_options` holds the day's two encounter ids.
  - Shards and `stop_encounter` go.
  - The save version is 4.
- **The run bot**
  - Visits a shop on the first visit and anything else on the second.
  - Takes the harder fight in about half its runs, so both kinds get measured.
  - Takes the rarest reward.
  - Its report gains loss rates and fight lengths by fight kind, and for easier versus harder fights.
- **UI**
  - The shop screen (the old Caravan screen) opens for shop stops.
  - A new fight-choice screen.
  - The rewards screen shows the pick of 3.
  - The day bar shows the visit and the day's fights.

## Decisions (from the user, 2026-09-27)

- **Two stop visits a day,** each a pick of 2, one of them always a shop (for now).
- **Rewards:** one enemy drop and two pool items; gold and the essence come on top.
- **Fights:** the harder one pays better, elite days offer 2 elites, and a replayed day keeps the same two fights.
- **Shops:** the keyword-led set.
- **Snowball rules:** still open. The user is thinking about them.
