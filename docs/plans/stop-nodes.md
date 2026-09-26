# Plan: stops become one pool of nodes

Status: **approved; built.** The answers are at the end.

**Why** (playtest feedback): the stop choice kept showing the same options. You picked 1 of 3 stop *kinds*: Forge, Loot, Vault, Retrain, or Event. "Event" hid a random draw from all the events, so the same few kinds came back every day.

## What changed

- **One node pool.**
  - The non-event nodes are in `data/nodes.json`, each with an id, name, text, kind, and weight.
  - Every event in `data/events.json` is also its own node, using its own weight.
  - Node and event ids share one namespace, and the loader rejects duplicates.
- **2 nodes a day** (`node_choices` in `data/economy.json`), always different. They're drawn by weight from the nodes that apply right now:
  - Forge: needs something infused.
  - Vault: needs a key.
  - Retrain: needs a hero with a specialization.
  - Loot, events, and the skirmish always apply.
- **Each node shows its name, kind, and blurb** before you pick, for example "A Smith's Cart (Event)".
- **Loot is split into three nodes**, each with its own appearance rate:

  | Node | Gives | Weight |
  | --- | --- | --- |
  | A Fallen Cache | an item | 7 |
  | A Rift Seep | an essence | 5 |
  | Scattered Coin | gold | 3 |

  `loot_weights` is gone from the economy data.
- **The Skirmish node** (`kind: "fight"`) is an extra fight before the day's fight:
  - **Enemies:** another of the day's normal encounters. It's the day's own fight only when that's the only one.
  - **A win:** the same rewards as a normal win (gold, an essence shard, and the guaranteed drop), offered at the stop.
  - **A loss:** nothing, and it **doesn't count as a loss**.
  - **Either way:** it counts for infusion XP, discoveries, and Legendary paths, but not as a win either (the win count drives the bonus gold after a loss).
  - It can be fought once, or skipped by leaving the stop.
- **The Upgrade stop** is unchanged: it's always the stop before the boss.
- **Other weights:** Forge 6, Vault 5, Retrain 3, Skirmish 5. Events keep their weights (1–5 each).

## Code

- **Data:** `NodeDef` (`src/run/defs/node_def.gd`). `RunContent` gains `nodes`, `node_ids`, `node_pool()`, and `node_name`/`node_text`/`node_kind`/`node_weight`.
- **`RunFlow`:**
  - `leave_caravan` draws the nodes.
  - `_enter_stop` takes a node or event id.
  - New `skirmish()` returns `[Result, FightResult, FightSetup]`, like `fight()`.
  - `_grant_rewards` is shared by the day's fight and the skirmish.
- **`RunState`:** saves `stop_node` and `stop_encounter`. `stop_kind` is now what the stop does: forge, loot, vault, retrain, event, fight, or upgrade.
- **Fight results:** `RunFight.apply_result` takes the encounter fought and whether it counts toward wins and losses.
- **UI:**
  - The stop choice shows two cards, each with a name, kind, and blurb.
  - A skirmish still to fight shows the fight screen, with a "Skip" button.
  - Afterwards, the stop screen shows the spoils.
- **The run bot** prefers the skirmish, then Loot, events, the Vault, Retrain, and the Forge. The report shows skirmishes per run and the share won.

## Balance

- Prices were also lowered in this PR: items 2/4/8/16 and heroes 3/5/16/32.
- With the new prices and nodes, the run bot clears the act 65% of the time (400 runs; the old target was 25–35%). By your call, this stays as it is until playtesting.
- The bot fights about 0.7 skirmishes per run and wins all of them.
- Legendaries now turn up far more often, because each event is its own visible node: the bot ends 14% of runs holding one (was about 2%).

## Answers (from the user)

1. A lost skirmish doesn't count as a loss (for now).
2. A won skirmish gives the same rewards as a normal win (for now).
3. The skirmish fights a normal encounter (for now).
4. It counts for infusion XP, discoveries, and Legendary progress: yes.
5. Loot is split into three nodes (item, essence, gold), each with a different appearance rate.
6. Balance after the price cut: leave it for now; playtest first.
