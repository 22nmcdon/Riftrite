# Rebuild phase 6: the good bot and tuning Act 1

Status: **agreed (2026-10-01), Decisions 1–4 in section 10; being built in six parts (section 5).** Phase 6 of `rebuild-build-order.md`: "A good-player bot (placement heuristics, vows, fight and camp picks); tune Act 1. **The good bot clears about 45–50%; a random bot clears far less.**" The old design's reason for the number still holds: a person usually beats a bot, so a good person should land a little above half (`docs/archive/plans/items-and-clarity.md`).

## 1. Where things stand

- **The simple bot** (`tools/run_bot.gd`, phase 5, Decision 14 there) plays by fixed orders: today's first fight, the first card for the hero with the fewest upgrades, the first relic of a choice, the first ware that changes a kit, no rerolls, no selling, no oaths, Shallow Rift Tears.
- **The run report peeks.** For each fight it tries the four named formations in the real fight and keeps the first that doesn't lose (`Bot.formation_for`). That's how it wins **75% of runs**: it knows each fight's outcome before placing. A player never does.
- **So 75% says little about difficulty.** Without the peek, the same bot places "guarded" every fight; nobody has measured that.
- **Left for this phase** (phase 5c's built notes and `design.md`'s open questions):
  - vowed Volley is +10 over base, from her vow's cost (Question 1 of phase 5c's report);
  - Wardweaver's deed is all or nothing;
  - Hearthwall transforms on day 2;
  - most transformations are +5 to +13 over base, under phase 4's 15–25 band, and vowed Vigil Keeper is −7;
  - bought engines rarely chain, and 40 held passives never fired (the bot or the pool?);
  - the economy's sim pass (`economy.md`: "a sim pass on the whole curve, once the run exists").

## 2. The bots

Four players, all in `tools/bots/`, all driving `RunFlow` through one loop, so the run report can play any of them:

| Bot | Places | Chooses | What it's for |
| --- | --- | --- | --- |
| **Random** | a random legal formation | a random legal action at every step | the floor: "a random bot clears far less" |
| **Simple** | "guarded" | the fixed orders above | kept as it is, for the tests that use it |
| **Good** | by reading the fight (2.2), never seeing its outcome | by practice fights (2.3) | **the target: 45–50%** |
| **Expert** | the good bot's candidates, tried in the real fight, best kept | as the good bot | the ceiling: how much better perfect placement would do |

### 2.1 The frame

- `tools/bots/run_player.gd` plays a run with a bot to its end: the loop `run_bot.gd` has now (`step_once`), with each decision asked of the bot. A bot answers: vows, the route's fight, the loadout (equip, unequip, tactics, gambits), the formation and markers (snares, the lantern, Dig In's rock), the pick, a relic choice, the shop (buy, sell, reroll, treat a wound, leave), the node, a camp option, a Rift Tear's depth, an event's choice and target, an oath, and the Shrine.
- **Determinism:** every bot is a pure function of the run's state and seed. The random bot draws from a `SimRng` seeded by the run seed, never `randi()`.
- **Vows:** the report keeps cycling each run's vows through the 27 combinations, so the gate is every team's and every path is measured. A `--vows=choose` line lets the good bot pick its own (2.3), reported beside it, not gated.
- **Speed:** the good bot fights many practice fights, so `tools/run_runner.gd` gets `--jobs=N`: it starts N Godot processes on slices of the seeds and merges their runs (each run written as JSON). The machine here has 4 cores.

### 2.2 The good bot's placement (no peeking)

It reads what the route card shows a player: the enemies, their hexes, their archetypes and kits. Then it builds a few candidate formations by rules and scores them **without fighting them**:

- **The front:** the hero that holds the line (Brannoc; whoever has Taunt, Guard, Engage, or the most HP and DEF) stands on the front row, across from the enemies' weight (the side with most enemy HP).
- **The back:** ranged heroes and healers stand in the back row, behind the front hero, out of the reach of the enemies' first move.
- **Flankers and chargers:** with them, the back line huddles toward the middle, near the front hero, away from the flank they come from.
- **Casters and areas:** with them (Cinder Moths, Old Mother Ash, area signatures), heroes keep 2 hexes apart.
- **Swarms:** against many small enemies, heroes with areas stand where the enemies will bunch up.
- **Ranged enemies and supports:** heroes who dive or target casters (Casters first) take the side nearest them.
- **Paths:** a transformed Trapper's snares go on the enemies' shortest way in; the lantern goes between the back line and the front; Dig In's rock covers the back line from the enemies' ranged units; a gambit's start rule is followed.
- **The score** weighs each rule above. Its weights are tuned once, in step 6b, against the expert (2.4) on the act's encounters, then frozen.

### 2.3 The good bot's choices (practice fights)

A good player knows Act 1's fights: they've played them, and Practice is open. The good bot stands in for that knowledge with **practice fights**: it fights the coming fights it can see on the act map (the route is known from the act's start) with its own placement (2.2), on practice seeds, never the real fight's seed. A practice fight's **worth** is a win, plus the heroes' HP left, plus speed.

- **The pick, a relic choice, the Shrine:** each option against nothing, in the next 2 days' fights; the best gain wins (shards when nothing gains).
- **The shop:** each affordable ware and relic, worth per shard; buys the best until nothing is worth its price. Rerolls when its shards are high and nothing on offer is worth buying. Sells an item that's worth nothing on anyone. Treats a wound before an elite or the boss.
- **The loadout:** each held item on each hero (tactics and gambits too), the best fit kept.
- **The route:** the harder fight when its practice is a sure win (the extra 3 shards), else the easier.
- **The node:** Rest when someone has 2 wounds; else the Magpie when he sells something worth it; else a Rift Tear at the deepest depth whose practice fight is a sure win; else an Event's best choice by practice, or walking away; else Camp's best option.
- **An oath:** sworn when its burden's practice fights are sure wins.
- **The budget:** each decision tries at most a few candidates (a cheap filter first: affordable, changes a kit), so a run stays under about 60 seconds.

### 2.4 The expert (the ceiling)

The good bot, except that at the real fight it tries its candidate formations and keeps the best result. It replaces the simple bot's peek in the run report.

## 3. The reports

- **The run report** gets `--bot=random|simple|good|expert` (default `good`) and `--compare`, which runs random, good, and expert on the same seeds side by side: runs won, the day each loss came, and the encounters that end runs.
- **A choices report** (`--choices`): each card, item, and relic: how often it was offered, how often the good bot took it, and the runs won with it against without it. It finds content nobody takes and content that wins on its own.
- The existing paths report and engine report run with the good bot.

## 4. The tuning

**Targets:**
1. **The good bot wins 45–50% of runs** (cycled vows; at least 108 runs), with no single encounter ending more than a third of the lost runs.
2. **The random bot wins far less** (under 15%), and the expert more (the gap shows placement matters across a run, not just in one fight).
3. **Pacing holds:** each path's median first transformation on days 3–4, at least 80% by the boss (phase 5c's Decision 46).
4. **The economy:** the good bot's spending matches `economy.md`'s shape (a modest spend over the act, enough for a legendary in the boss shop if it saved for one).
5. **The choices report has no outliers:** no card, item, or relic the good bot never takes when offered, or that wins more than 15 points above its kind's average (each looked at and fixed or noted).

**Levers** (all four, Decision 2; every change is reported with what it was and why):
- the enemies' numbers: each encounter's `scale_bp`, the elites' and the boss's kits;
- the economy and prices (`act1.json`);
- content numbers: cards, items, and relics the choices report flags;
- Rift Collapse's timing (`tuning.json`).

**The paths flagged in phase 5c** (Decision 3): measured again with the good bot and fixed in step 6e as the numbers say (vows' costs, deeds, transformations), each change reported with what it was and why.

## 5. Steps

| Step | What it builds |
| --- | --- |
| **6a** | The bot frame (`run_player.gd`), the random bot, the simple bot moved onto it, `--bot`, `--jobs` |
| **6b** | The good bot's placement (2.2), its weights tuned against the expert, and the expert |
| **6c** | The good bot's choices (2.3) |
| **6d** | The reports: `--compare`, `--choices`, and the first read of all four bots, before any tuning |
| **6e** | The tuning (section 4), to its targets |
| **6f** | Docs and a playtest build |

Each step: its commit, the full suite, the bench's fingerprints unchanged (no step changes a fight's rules), the run report, and its built note here.

### 5.1 Built in step 6a (2026-10-01)

- **The frame:** `tools/bots/bot.gd` is a bot: one function per decision (vows come from the report), answering as the simple bot does; `tools/bots/run_player.gd` plays a run, one `RunFlow` action at a time, each the bot's answer (`RunPlayer.play`, `step`). The simple bot stays in `tools/run_bot.gd` (its static rules are what `bot.gd` answers with, and 15 run test files use them), instead of moving to `tools/bots/simple_bot.gd` as section 6 planned. A bot now places markers too (snares, a lantern: Practice's starting hexes, moved to the nearest legal ones), which `run_bot.gd`'s own `play` never did.
- **The random bot** (`tools/bots/random_bot.gd`): a random legal answer to everything from its own `SimRng` (seeded by the run's seed): today's fight, the formation (any legal hexes in the heroes' zone), markers, the loadout, the pick or the shards, a relic or none, up to 6 shop actions (a buy, a relic, a wound, a reroll; it never sells), the node, camp's option, a Rift Tear's depth, an event's choice and target or walking away, an oath, the Shrine's offering, Map the Rift's swap, and Dig In's rock.
- **The report:** `--bot=simple|simple-peek|random` (default `simple-peek`, the report's bot until now, until the good bot lands), and `--jobs=N`: N Godot processes each play every Nth seed and write their run lines (`RunLine.to_dict`, `FileAccess.store_var`), and the parent merges them; 12 runs in 4 processes give the same report, engines included, as one.
- **Tests:** `tests/tools/test_bots.gd` (3: each bot plays runs to their end and repeats, the random bot's answers aren't the simple bot's, a run line read back gives the same report).
- **The first read** (108 runs each, cycled vows): **the simple bot without its peek wins 16%** (35 runs lost on day 1), **the random bot 24%**, and **the simple bot with its peek 70%**. A fixed formation does worse than a random one, and trying four formations in the real fight lifts the same bot by 54 points: where the good bot places (6b) decides most of what it wins.

### 5.2 Built in step 6b (2026-10-01)

- **What the data said first:** the rules section 2.2 planned (the tank in front, the back line behind it) aren't what wins here. With base heroes the "guarded" formation loses five encounters that "exposed" (the tank behind) wins. So the weights weren't set by hand: they were fitted on practice fights, as 2.2's last bullet allowed, and the rules became the features they weigh.
- **The reading** (`tools/bots/placement.gd`): 22 features of a formation, worked out from the setup alone: the heroes' roles from their kits (the tank has the most HP times DEF, then the longer reach and the middle), each one's row, reach to the nearest enemy, and place across from the enemies' weight; how far apart they stand; whether the tank is in the flankers' and chargers' way; bunching against area throwers; spreading against swarms; rocks beside the back line; the far hero's edge. Each feature's weight moves with what the fight holds (7 contexts: flankers, area throwers, swarm units, ranged units, rocks, enemies, and one), so the score is 154 terms.
- **The fit** (`tools/bots/placement_data.gd`, `fit_placement.py`, `placement_weights.json`): 10,800 practice fights (600 per encounter, Hunts aside), each a random formation of a random team (every hero vowed to a random path, transformed half the time, no items), fitted by ridge regression to the heroes' HP left (a loss counts −0.5). Left out one encounter at a time, the best-scored tenth of an encounter's formations won 87% against 80% for its random ones (weights fitted per encounter would reach 90%, generic ones without the contexts 85%).
- **The search:** every way to place the three heroes in the heroes' zone, off the rocks. Each role tries only its best 12 hexes by its own terms, then all combinations (about 2 ms a fight). `tools/bots/placement_check.gd` checks the picks on fresh teams: **94% of practice fights won, against 80% placed at random** (worse than random only in Bog Crossing, the Witch Coven, and Cairn Watch).
- **The good bot** (`tools/bots/good_bot.gd`, choices still the simple bot's until 6c) places the best-scored legal formation; markers go where Practice starts them. **The expert** (`expert_bot.gd`) tries the good bot's 6 best in the real fight and keeps the one worth most (`tools/bots/practice.gd`: a win plus the heroes' HP left).
- **Tests:** `test_bots.gd` (7 now: the quick score equals the features' score and the setup is put back; roles come from the kits; the good bot's placement is legal, repeats, and changes and fights nothing; the expert never does worse than the good bot in the same fight).
- **The read** (108 runs each): **the good bot wins 57%** (losses on days 2–5; Hollow Line 56% of its fights, Cairn Watch 59%, the Witch Coven 72%, Sentinel Gate 75%), **the expert 83%**, against the random bot's 24%.

### 5.3 Built in step 6c (2026-10-02)

- **Practice** (`tools/bots/practice.gd`): a choice is tried on a copy of the run (`RunFlow.resume` over the state read back from its dict) and is worth the mean worth of practice fights after it (a win plus the heroes' HP left, a loss below any win), placed by the good bot's reading on practice seeds, plus the shards it gained or spent at `shard_worth` (0.004 a shard on day 1, falling to 0 as the act runs out). Worths are cached by state and fights, so repeated questions cost nothing.
- **What it practices** (Decision 5): never the next day fight. The first fights of the two days after it, and the next elite's or the boss's after those; topped up with fights already fought when that's fewer than two. Nothing after the boss.
- **The choices** (`good_bot.gd`): the pick (each card against the shards), a relic choice (each against declining; its price shows as shards), the shop (up to 8 tries: an item on each hero it changes, a relic, a wound treated; the best if it beats doing nothing; else one reroll when 20 shards would be left; else selling an item that changes no hero; nothing after the boss), equipping what waits in the stash, the node (each one's worth: Camp's best option, a Rift Tear's relics at its depth, the Magpie with 15 shards, an event's best choice by practice, an oath whose burden still wins surely), camp's option (Rest, Fortify, and Dig In by practice; Train, a Hunt, and the Shrine at fixed worths), events (each choice and target by practice, or walking away), oaths, and the Shrine (shards, else a wound, else its lowest relic; the relic shown is then judged like any). Today's fight, a Rift Tear's depth, and a Hunt go by the team's strength in practice (the harder fight and Shallow at 1.45, Deep at 1.65, Abyssal at 1.85); Map the Rift swaps the fight its encounter scales most.
- **The first version practiced the coming fights themselves** and won 108 of 108 runs, every encounter at 100%: a fight's seed only changes crits, so practicing it was seeing its outcome. Decision 5 took that out.
- **Tests:** `test_bots.gd` (12 now: the good bot and the expert play to day 3 and repeat; the practice set never holds the next fight; practice tries a copy, counts the shards, and changes and fights nothing real; shards are worth less as the act runs out; and 6d's reports).
- **The read** (54 runs): **the good bot wins 79%** (losses on days 2–7; Sentinel Gate 1 of 5 fights, the Witch Coven 77%, Hollow Line 84%), spending 47 of 134 shards a run: its practice fights are mostly won with most HP to spare, so few buys show a gain beyond their price. Act 1 is too easy for it; 6e's tuning is what makes its buys matter. About a minute a run.

## 6. Files

- `tools/bots/bot.gd`, `run_player.gd`, `random_bot.gd`, `good_bot.gd`, `placement.gd` (2.2) with `placement_data.gd`, `fit_placement.py`, `placement_weights.json`, and `placement_check.gd`, `practice.gd` (2.3), `expert_bot.gd`. The simple bot stays in `tools/run_bot.gd` (6a).
- `tools/run_report.gd` and `tools/run_runner.gd`: `--bot`, `--compare`, `--choices`, `--jobs`, and a run line's JSON for `--jobs`.
- Step 6e changes data only (`encounters.json`, `act1.json`, `enemies.json`, `upgrades.json`, `items.json`, `relics.json`, `tuning.json`), with the tests that pin numbers changed on purpose.

## 7. Tests

- `tests/tools/test_bots.gd`: each bot plays a run to its end without a refused action, and twice gives the same run; the random bot's formations are legal; the good bot's placement puts the front hero on the front row and the back line behind it in each encounter, and never fights a real fight before placing (it fights only on practice seeds); the expert never does worse than the good bot on the same seeds.
- `tests/tools/test_run_report.gd`: `--bot`, `--compare`, `--choices`, and `--jobs` merging to the same report as one process.

## 8. What phase 6 doesn't do

New content, new rules, Acts 2–3, enemy specializations (phase 8), and the art (phase 7). A tuning need that only a new rule could meet goes to the playtester as a question.

## 9. Questions (answered in section 10)

- **AK. What the good bot may know** (2.2–2.4): it places without seeing the fight's outcome, judges choices by practice fights against the act's known fights, and the peeking expert is reported as the ceiling; the 45–50% target is the good bot's?
- **AL. The levers** (section 4): which may tuning move?
- **AM. The paths flagged in phase 5c:** measure them with the good bot and bring each change to the playtester?
- **AN. The plan:** six parts as in section 5, ending in a playtest build?

## 10. Decisions (the playtester, 2026-10-01)

1. **The good bot plays honestly** (Question AK): it places by reading the fight and never sees the real fight's outcome first; it judges choices by practice fights against the act's known fights, on practice seeds; the peeking expert is reported as the ceiling. The 45–50% target is the good bot's.
2. **Tuning may move all four levers** (Question AL): the enemies' numbers, the economy and prices, content outliers, and Rift Collapse's timing. **Every change is reported after: exactly what changed, from what to what, and why.**
3. **The paths flagged in phase 5c are fixed as the numbers say** (Question AM): vowed Volley's cost, Wardweaver's deed, Hearthwall's lumps, and transformations under the 15–25 band, changed in step 6e and reported like any other change.
4. **Six parts as in section 5, ending in a playtest build** (Question AN).
5. **Practice never includes the next day fight** (the playtester, 2026-10-02, after step 6c's first read): practicing the coming fights showed the good bot their outcome (a fight's seed only changes crits), and it won 108 of 108 runs. Its choices are judged against the act's fights more than a day away, then fights already fought; today's fight, a Rift Tear's depth, and a Hunt are chosen by the team's strength in that practice, not by practicing them; the elites and the boss are practiced only while they're more than a day away.
