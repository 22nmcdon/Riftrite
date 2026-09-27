# Plan: Legendary items and their upgrade paths

Status: **approved; built.** The answers are at the end.

**The design** (`docs/tiers-backup-specialization.md`, Legendaries):
- Legendaries are the rarest and most powerful items.
- Each one has an active mode, a backup mode, and 2 sockets.
- A Legendary appears at most once per run and never combines. It tiers up through **its own upgrade path**.
- Its starting tier depends on the path.

Already in the code before this change:
- Legendaries are once per run (`legendaries_seen`).
- They never combine.
- The Upgrade stop refuses them.
- The 2% Legendary rarity weight had nothing to offer, because no Legendary items existed yet.

## The six paths

Each Legendary names its path in its data. A held Legendary remembers its progress toward the next tier, and that progress is saved with the run. The numbers are placeholders to tune with the run bot.

| Path | Data `path` | Starts | How it tiers up |
| --- | --- | --- | --- |
| Grows by use | `hits` | C | Counts the item's hits: each time it deals direct damage (not damage over time) in a fight, fielded or from backup. Counted from the combat log after the fight. |
| Essence-hungry | `essence` | B | You feed it essences from the pouch (a new action, any time between fights). Each step wants one specific essence, a set number of times, which steers your route. |
| Devourer | `devour` | C | You feed it another item (a new action, any time between fights; never a Legendary). A meal is worth the eaten item's tier + 1 (C = 1 ... S = 4). It **keeps a trace**: each eaten item adds a permanent % boost to the Devourer's numbers, by the eaten item's rarity. |
| Bonded | `bonded` | B | Tiers up when the hero holding it ranks up (the Legendary must be on that hero's row). |
| Martyr | `martyr` | B | Tiers up when its holder falls in a fight the guild still wins (a tie counts as a win). |
| Boss-forged | `boss` | A | Tiers up when the guild beats a boss while it's equipped (on any hero's row, fielded or in backup). |

**The data** (on the item in `data/items.json`):

```json
"legendary": {
  "path": "hits", "start_tier": "c", "goals": [60, 120, 200]
}
```

- `goals` holds one number per step from `start_tier` to S. A C-start path has three steps; an A-start path has one.
- `essence` also has `"wants": ["ember", "frost"]`, one essence per step.
- `devour` also has `"trace_bp": {"common": 300, ...}`. There's no Legendary entry, because Legendaries can't be eaten.

**How progress works:**
- Progress counts toward the next tier. Reaching the goal raises the tier by one and carries any extra progress over.
- At S, progress stops. A Devourer still eats for its trace.
- A Legendary always enters the guild at its path's start tier, whatever the offer says.

**Why the Devourer's trace needs code:** the trace is a percentage boost that multiplies the item's own numbers, the same way the tier multiplier does. It shows in the item's number breakdown as "x1.08 devoured". It's a new input to an item's numbers, not a new effect type. It flows from the run into the fight as `trace_bp` on the item's setup.

## Where Legendaries come from

- **Never the Caravan, Loot, or tier shops:** `rarity_weights` (the Caravan, Loot, and tier shops) must give Legendary 0, and the data check enforces it.
- **The Vault:** its item draws use a new `vault_rarity_weights` table: Rare, Epic, or Legendary. This replaces the Vault's hard-coded "no Common or Uncommon" rule.
- **Rare events:**
  - The item-by-rarity event uses a new `event_rarity_weights` table (Common most likely, Legendary least).
  - A new rare event kind, `legendary_item`, offers one Legendary not yet seen, free. The event is "A Barrow Hoard", weight 1, like the Ancient Reliquary.
- Only fight drops carry enemy items, and no enemy holds a Legendary.

## Code

- `src/sim/defs/legendary_def.gd`: reads and checks the path data. `ItemDef.legendary` is set only on Legendary items, and every Legendary must have one.
- `ItemSetup` / `ItemState` / `LoadoutEntry`: `trace_bp`, applied as a multiplier on the item's own effects.
- `RunItem`: `progress` and `eaten` (the eaten item ids, in order), saved only when set, so old saves still load.
- `src/run/run_legendary.gd`, the path engine:
  - `after_fight`: hits, martyr, and boss progress.
  - `on_rank_up`: bonded progress.
  - `feed_essence` and `devour`: two new actions. Like every run action, a refused one changes nothing.
  - Each tier-up returns a plain-words note for the UI, for example "The Tallyman's Bow grows to B (60 hits)".
- `RunState.check()` gains four checks:
  - a Legendary is never below its start tier
  - progress is never negative, and is 0 at S
  - only a Devourer has eaten anything
  - no Legendary is held twice
- `RunFlow`: the Legendary start tier on offers; the new weights; the new event kind.

## Content: six Legendaries

One per path, spread across the classes. Placeholder names:

| Legendary | Path | For | What it does |
| --- | --- | --- | --- |
| The Tallyman's Bow | hits, C | Rangers, Tricksters (ATSP) | Auto-attack longbow that scales from ATK and ATSP. From backup: a volley at a random enemy. |
| The Hungering Censer | essence, B | Arcanists | Magic damage to all enemies. From backup: a small blast. Wants 1 Ember (to A), then 2 Venom (to S): Act 1 essences. |
| Maw of the Hollow | devour, C | Strikers, Wardens | A heavy bite on the front enemy. From backup: a bite at a random enemy. Grows with every meal. |
| The Kinstone Aegis | bonded, B | Wardens | Shields the row. From backup: DEF for all allies. |
| The Last Hearth-Lantern | martyr, B | Menders, front-liners | Heals the lowest-HP ally and shields its holder. From backup: a heal. |
| The Riftbreaker's Brand | boss, A | Strikers, Tricksters | Damage plus Bleed on the lowest-HP enemy. From backup: Bleed on a random enemy. |

## UI

- **The inspector:**
  - shows the path in plain words, with progress, e.g. "Grows by use: 23/60 hits to B"
  - an Essence-hungry Legendary shows the essence it wants, and a **Feed** button when the pouch has it
  - selecting any other item while a Devourer is held adds a **Feed to Maw of the Hollow** button
  - the Devourer lists what it has eaten and its trace
- **The item tile:** a thin progress bar along the bottom of a Legendary's tile.
- **After a fight:** tier-ups show as a message, like discovered synergies.

## The bot

- Feeds Essence-hungry Legendaries before infusing.
- Feeds stash leftovers it couldn't equip to a Devourer.
- Otherwise handles Legendaries like any other item.

## Tests

- Each path's progress and tier-ups, including carrying over extra progress and stopping at S.
- Start tiers on every source.
- Sources: never the Caravan, Loot, or tier shops; the Vault and events can give one; the new event.
- Once per run; never combines.
- Progress and the eaten list survive save and load; old saves without them load.
- The new actions refuse cleanly and change nothing.
- The trace multiplies the item's numbers.
- The data checks.
- The inspector's buttons.
- Mutation checks on the path engine.

## Left for later

- Legendary Oathbindings: Oathbinding isn't built yet.
- A kills-counting Legendary (**grows by kills**): wanted later, as a second grows-by-use item.
- Boss-forged can tier up only once in the slice, because Act 1 has one boss.

## Built: numbers and balance

All numbers are placeholders in `data/items.json`, `data/economy.json` and `data/events.json`.

**Goals:**

| Legendary | Goals |
| --- | --- |
| The Tallyman's Bow | 60 / 120 / 200 hits |
| The Hungering Censer | 1 Ember, then 2 Venom |
| Maw of the Hollow | 3 / 4 / 5 meals |
| The Kinstone Aegis | 1 rank-up per tier |
| The Last Hearth-Lantern | 1 fall per tier |
| The Riftbreaker's Brand | 1 boss |

The Maw's trace is +3% for a Common meal, +5% Uncommon, +8% Rare and +12% Epic.

**Odds:**
- The Vault's items are Rare 14, Epic 6, Legendary 6.
- The Barrow Hoard has event weight 3.
- The item-by-rarity event is Common 50, Uncommon 28, Rare 14, Epic 6, Legendary 2.

**Balance:**

- **Output per fight** against a comparable Epic at the same tier, with the same hero and party (a scratch sim, 180 fights):
  - Most Legendaries now match or beat their Epic: the Bow, Censer, Aegis, and Lantern by 10–60%, and the Maw by 5% (at C).
  - The Brand is about 7% below the Twinfang Stilettos. Those are an unusually strong Small Epic.
- **The run bot** (400 runs): the act clear rate is unchanged at 30% (target 25–35%), because the bot holds a Legendary at the end of only about 2% of runs. The bot rarely picks Vault or event stops.
- **Handed one on day 1** (200 bot runs each; no Legendary: 33%):

  | Legendary | Act clears |
  | --- | --- |
  | Bow | 44% |
  | Censer | 38% |
  | Maw | 63% |
  | Aegis | 34% |
  | Lantern | 68% |
  | Brand | 85% |

  For comparison, the same test with Epics:

  | Epic | Act clears |
  | --- | --- |
  | Rimewood Longbow (C) | 40% |
  | Wyrdglass Orb (B) | 48% |
  | Twinfang Stilettos (C) | 58% |
  | Tower Shield (B) | 31% |
  | Hearthkeeper's Kettle (B) | 55% |
  | Twinfang Stilettos (A) | 78% |

  A day-1 Legendary is a big boost, as a day-1 Epic is. Real finds come later and far more rarely.

## Answers (from the user)

1. Build all six paths: **yes**.
2. Boss-forged now, starting at A: **yes**.
3. Sources: **the Vault, rare events, and a new rare Legendary item event; not the Caravan**.
4. Starting tiers as suggested: **yes** (hits C, essence B, devour C, bonded B, martyr B, boss A).
5. Grows by use counts **hits** (a bow for an ATSP build). A kills-counting Legendary comes later.
