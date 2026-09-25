# Plan: the day structure, economy, and run bot (Phase 3, step 5)

Status: **built** (Phase 3, step 5). Answers, notes, and first balance findings are at the end.

This step turns the run state (step 4) into a playable run:
- the run start
- days of **Caravan → stop → fight**
- rewards
- losing and replaying a day
- the end of an act
- the economy data
- a headless **run bot** that plays whole runs for run-level balance reports

The boss's unique mechanic is step 6; until then, day 6's fight is the act's strongest encounter.

Everything stays deterministic from the run seed and saved after every action (step 4's `RunSave`).

## The flow

`src/run/run_flow.gd`, with `RunFlow`, drives the run. The run is always at one **step**, and each step has its own actions:

```
START_HERO ─► START_PACKAGE ─► [ CARAVAN ─► STOP_CHOICE ─► STOP ─► FIGHT ─► REWARDS ] x days ─► ACT_END
                                                                       │
                                                  lost (first time) ───┴─► back to CARAVAN, same day
                                                  lost (second time) ──► RUN_OVER
```

| Step | What the player does | Actions |
| --- | --- | --- |
| `START_HERO` | Picks 1 of 3 random heroes (rank C) | `pick_start_hero(i)` |
| `START_PACKAGE` | Picks 1 of 3 packages (extra gold, a random Common relic, a random Common item), plus base gold | `pick_package(i)` |
| `CARAVAN` | Buys, sells, rerolls, then leaves | `buy(i)`, `sell(uid)`, `reroll()`, `leave()` |
| `STOP_CHOICE` | Picks 1 of 3 stops | `pick_stop(i)` |
| `STOP` | Does the stop (see Stops), then leaves | per stop, then `leave()` |
| `FIGHT` | Sees the enemy team, arranges the guild, fights | `fight()` (runs the sim, returns the `FightResult` for playback) |
| `REWARDS` | Takes or passes on each reward | `take(i)`, `pass(i)`, `done()` |

- **Between fights:** step 4's actions (moving items, infusing, formation, discarding) work at every step except `RUN_OVER`.
- **Reforging** works only at a Forge stop.

## Days and fights

- **Acts are data:** `data/acts.json`. Placeholders:
  - 6 days
  - a pool of normal encounters, elite encounters on days 3 and 5, and a boss encounter on day 6
- **Encounters get a `kind`:** normal, elite, or boss.
- **Each day's fight is fixed:** it's picked from the pool when the day starts, and shown during the Caravan and the stop, so the player knows which essences it drops. A replayed day keeps the same fight.
- **Offers don't depend on earlier picks:** each offer's randomness comes from its own stream, seeded by run seed, act, day, step, attempt, and reroll count. Skipping a shop never changes tomorrow. The filters below (tiers you hold, Legendaries seen, room) still apply.

## The Caravan

- **Offers:** 5 items and 2 heroes (placeholders).
  - **Tiers** follow the act's odds from `docs/tiers-backup-specialization.md` (Act 1: C 80%, B 20%).
  - **Rarity** follows rarity weights; every item of a rarity is equally likely, whatever its size.
- **Never offered:**
  - relics (they come from elite and boss choices, the relic merchant event, Loot, the Vault, and drops)
  - enemy-only items
  - Legendaries already seen
  - an item or hero at a different tier than a copy you hold
  - a hero already at S
  - a new hero when the roster is full (a copy of one you have is fine: it combines)
- **Buying** needs gold and room. Heroes combine or join (step 4's `add_hero`). A hero offered at B or above comes with a preset specialization, picked at random from their three.
- **Selling:** half the price, rounded down.
- **Rerolling:** 1 gold, then +1 each time in the same visit.

## Stops

Pick 1 of 3, drawn by weight from the stops that apply right now:

| Stop | What happens | Offered when |
| --- | --- | --- |
| **Forge** | Reforge items (step 4's `reforge`, gold per item) | Something is infused |
| **Loot** | A free random reward: an item (random rarity *and* tier, **enemy-only items included**), an essence, or gold. Take or pass | Always |
| **Vault** | Spend a key on a chest: a better item or a relic | You hold a key |
| **Retrain** | Switch one hero to another of their three specializations, keeping their rank (free) | A hero has a specialization |
| **Event** | One of the events | Always |

**The Upgrade stop** isn't in the pick: it's **always the stop right before the boss**, and nowhere else. It's free: one item goes up one tier, enemy-only items included (not S, not Legendaries). It's the other way to raise enemy-only items, besides a second copy from random loot.

**Events** (`data/events.json`, outcome types: gold, item by rarity, item by tier, relic by rarity, essence, key):
- **Gold.**
- **A random item by rarity:** Common 50%, Uncommon 28%, Rare 14%, Epic 6%, Legendary 2% (a Legendary already seen is rerolled).
- **A random relic by rarity,** with the same odds.
- **A random item by tier:** C 55%, B 30%, A 12%, S 3%.
- **Relic merchant:** pick one of 3 relics and pay its price (by rarity), or leave. This is the only way to buy a relic; the Caravan never sells them.

## Rewards and losing

- **A win (a tie counts):**
  - gold: 5 + the day number
  - essences: 1 shard of the team's essence (3 shards make an essence)
  - **one guaranteed drop** from the enemy team's items and relics (enemy-only included), at the enemy's tier
- **An elite:** also a **relic choice**: pick 1 of 3 relics (or none), with elite rarity odds.
- **The boss:** the drop is an item or a relic from the boss team, **plus a relic choice** from a stronger, game-altering pool (Epic-leaning, and boss-only relics later).
- **Keys:** an elite has a 50% chance to drop one; some events give one.
- **Every reward can be taken or passed on.** Taking one without room means throwing something away first.
- **A loss:** the day restarts at the Caravan with everything kept, plus bonus gold (10 + 5 per fight won). Then comes a fresh Caravan and stop (the attempt number changes their seeds) and a rematch against the same fight. **The second loss ends the run.**
- **The act's end:** after the boss, the run reports its result. Acts 2 and 3 come later.
- **Infusion XP and discoveries** come from step 4's `apply_result`.

## Economy data (`data/economy.json`, placeholders to tune with the bot)

| | |
| --- | --- |
| Base gold / packages | 10 / +8 gold, a random Common relic, or a random Common item |
| Item price by tier | C 4, B 9, A 20, S 42 (rarity adds nothing for now) |
| Hero price by rank | C 6, B 14, A 30, S 60 |
| Relic price by rarity | 6, 9, 13, 18, 25 (the relic merchant event) |
| Sell | half, rounded down |
| Reroll | 1, +1 per reroll in a visit |
| Reforge | 3 per item (moves here from tuning) |
| Fight gold | win: 5 + day; elite ×1.5; boss 20; loss bonus 10 + 5 per win |
| Odds | Caravan tier odds by act, and rarity weights for the Caravan, loot, and events |

## The run bot and run-level reports

- **The bot:** `src/run/run_bot.gd` plays whole runs through `RunFlow`, with a simple, seeded strategy:
  - buy what fits and what combines
  - infuse into free sockets
  - field the strongest five
  - prefer Loot, then Events, then the Forge
  - take rewards when there's room
- **The runner:** `tools/run_runner.gd -- --runs=200 --seed=1` reports:
  - the share of runs that beat the act
  - the day runs end on
  - losses per run
  - average gold by day
  - the most bought and taken items
  - the synergies found

## Tests (`tests/run/`)

- **Flow:** the run start (1 of 3 heroes, 1 of 3 packages); the step order; actions refused at the wrong step.
- **Caravan:**
  - offers follow the filters: tiers you hold, no enemy-only items, Legendaries once, a full roster
  - buying needs gold and room
  - selling for half
  - reroll costs rising
  - preset specializations for B+ heroes
- **Stops:** each stop is offered only when it applies, and each one works (Forge, Loot, Vault, Events, Upgrade).
- **Rewards:** gold, essences, the guaranteed drop, elite and boss extras, and take or pass.
- **Losing:** the first loss restarts the day (everything kept, bonus gold, same fight, new offers); the second loss ends the run.
- **Determinism:**
  - the same seed and choices give the same run
  - offers don't change when an earlier stop is skipped
  - save/load at any step continues the same run
- **The bot:** it finishes runs without errors, and the runner's report lines.

## Answers

1. **Upgrade stop:** always the stop right before the boss, never anywhere else, and free (one item, one tier).
2. **Relics:** a relic choice after every elite and boss (the boss's is more powerful and game-altering), plus an event that sells one. The Caravan doesn't sell relics.
3. **Essences:** 1–2 per win is too many. See the question below.
4. **Keys:** elites 50%, plus some events.
5. **New stop, Retrain:** switch a hero to another of their specializations.

6. **Essences: shards, plus whole essences from big fights** (A + D):
   - a **normal win** gives 1 **shard** of the enemy team's essence, and 3 shards of one kind become an essence in the pouch (they wait if the pouch is full)
   - an **elite or boss win** gives one whole essence of the team's kind (take or pass)
   - **Loot and Events** give essences too
   - each enemy type has an `essence`; a team's essence is its most common one (ties go to the first in the encounter)

## Built notes

- **Code:** `src/run/`: `RunFlow` (phases and actions), `RunRandom` (seeded streams), `RunContent` with `defs/` (economy, acts, events), `RunBot`, `RunReport`. The runner is `tools/run_runner.gd`.
- **Data:** `data/economy.json`, `data/acts.json`, `data/events.json`. Enemies gained `essence` and encounters gained `kind`.
- **Encounter pools have day ranges.** A run starts with one hero, so Act 1's first days needed weaker fights. There's a new placeholder enemy, the **Rift Pup**, and new encounters: A Litter of Pups (days 1–2), A Hound and Its Pup (days 2–4), and the elite Hound Alpha (day 3). The Witch Coven is day 5's elite, and **The Rift Throne** is a placeholder boss until step 6.
- **Offers are saved with the run** (as plain dictionaries), so loading mid-Caravan shows the same wares.
- **The fight seed** still comes from the run's RNG (step 4). Only the fight's *encounter* is fixed per day, so a rematch plays out differently.
- **The Vault** spends its key when you enter; the chest is a relic or an item of Rare rarity or better.
- **An offered Legendary counts as seen,** so it won't be offered again that run.

## Balance findings (placeholders; the first run-bot pass)

`tools/run_runner.gd -- --runs=200 --seed=1` (the bot's simple strategy):
- **The act is cleared in 8% of runs,** with 1.9 losses per run.
- **Where runs end:** day 2: 6, **day 3: 80**, day 4: 19, day 5: 41, day 6: 39.
- **Day 3's elite (the Hound Alpha) is a wall** for one or two heroes, and so is the day-5 Witch Coven.
- **Gold is tight early:** about 8 at days 2–3, after the start's 18.
- **Rift Claws are the most taken item** (3 per run): the pups and hounds drop them, and they're enemy-only.

These numbers are all placeholders. The content step tunes encounters, prices, and the bot's strategy together.
