# Days and nodes

Status: **agreed in discussion (2026-09-30); the day's loop and the nodes built in phase 5c step 8a** (`rebuild-phase5c-combos.md`, section 16: the fight, the pick, the Pedlar after every fight, then Camp, Rift Tear as built, or the Magpie; Decisions 40–43). Rift Tear's depths, the rift modifiers, and the Shrine's offerings built in 8b (section 16.13); the Event node in 8c (16.14). How a day runs, and the nodes you choose between. Changes part 4 (`rebuild-run.md`) and part 6 (`rebuild-between-fights.md`); where this file and those disagree, this file wins. Events are in `events.md`; the Magpie in `magpie.md`; relics in `relics/`; the loadout in `loadout/`. **Numbers are placeholders.**

## 1. A day

```
Day N
  Choose the day's fight (1 of 2, known from the act's start)
    ↓
  Place your heroes, and fight
    ↓
  After-fight pick (1 of 3 upgrades)
    ↓
  Shop: 1 relic and the wares; reroll to see more
    ↓
  Choose 1 of 2–3 nodes: Event, Camp, Rift Tear, or the Magpie
    ↓
Day N+1
```

- **The fight choice stays:** each day offers 2 fights, known from the act's start; the harder one pays more.
- **A shop comes every day,** right after the after-fight pick. The Pedlar is that shop, no longer a camp option.
- **Then a node:** 2–3 are shown, and you take one. Its effect happens now, or applies to the next day's fight (Rift Tear).
- **Losing a fight replays the day** (you fight it again); a second loss ends the run.
- **The boss day:** after the boss, choose 1 of 3 boss relics, then the special shop (1 legendary plus 1 relic of another tier; rerolls start at 5 shards). **Changed (2026-10-01, `rebuild-phase5c-combos.md` Decision 48):** that shop was the day before the boss's; it is now after the boss, and the day before the boss's has a plain Pedlar.

## 2. The shop

- **1 relic at a time**, plus the loadout wares (charms, tactics, sigils, gambits) and treating wounds. Rerolling replaces the relic with a new one: the first reroll costs 1 shard, each after it costs 1 more. See `relics/README.md` for which tiers show.

## 3. The nodes

| Node | What it is |
| --- | --- |
| **Event** | A short scene with a choice (`events.md`), or a Bloodied Oath offer |
| **Camp** | Pick one camp option from the camp's menu |
| **Rift Tear** | Pick a depth; tomorrow's fight is harder, and winning it pays a relic choice |
| **The Magpie** | A rare stall: 2 charms at rank II, 1 epic or legendary relic at 25% off, buys your relics, and one free relic swap (`magpie.md`) |

### Camp options

Unchanged from part 4 except: the **Pedlar** leaves the menu (it's the shop, which comes every day), and **Rift Tear** is its own node. Camp keeps **Rest, Train, Scout, Map the Rift, Fortify, Dig In, Hunt,** and the **Shrine**.

- **Scout** and **Map the Rift** keep their jobs, since the fight choice stays: Scout reveals the next days' enemies, Map the Rift swaps one of tomorrow's fights.

### Rift Tear: choose how deep

| Depth | Tomorrow's fight | Win it for |
| --- | --- | --- |
| **Shallow** | Enemies start with a Shield of 10% of their max HP | A choice of 2 rare relics |
| **Deep** | That, plus one rift modifier (e.g. Hastened: enemies get +20% attack speed; enemy-growth.md) | A choice of 2 epics |
| **Abyssal** | That, plus a second rift modifier | A choice of 1 legendary and 1 epic |

Losing it is like losing any fight: you replay the day.

### The Shrine (a camp option): an offering for a relic

Relics have no costs, so the Shrine takes an offering instead:

| Offering | Receive |
| --- | --- |
| A wound on a hero of your choice | A rare relic |
| 15 shards | A rare relic |
| A relic you own | A relic one tier higher, never boss |

## 4. What this changes

| Plan | Rule | Now |
| --- | --- | --- |
| `rebuild-run.md` | A day is camp, a pick of 2 fights, placement, the fight, then rewards | A day is the fight choice, the fight, the after-fight pick, the shop, then a node |
| `rebuild-run.md` | Rift Tear and the Shrine are camp options; the Shrine offers relics with costs | Rift Tear is a node with three depths; the Shrine takes an offering |
| `rebuild-between-fights.md` | The Pedlar is a camp option | A shop comes every day |
| `rebuild-run.md` | Bloodied Oath is a camp option | It's an event (`events.md`) |

## Where this meets what's built

Phase 5 built the older day (`rebuild-phase5-run.md`): camp first (a place's menu of options, one taken), then the route (today's two fights), the loadout, the fight, and after it the pick and any relic choice. The Pedlar, the Magpie, Rift Tear, and the Shrine are camp options there (`data/camps.json`), Rift Tear gives the next fight one enemy mod, the Shrine sells relics with costs, and there is no Event node or Bloodied Oath. Building this file reorders the day (fight, pick, shop, node), turns camp into one of the nodes, makes Rift Tear a node with depths, gives the Shrine its offerings, and adds events (`events.md`). The run bot and the run report follow the new day.

## Open questions

- **How many nodes to show:** 2 or 3, and how often each kind appears.
- **Income:** set in `economy.md`; it still needs a sim pass.
