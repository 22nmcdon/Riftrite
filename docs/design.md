# Riftrite: design

Working title: **Riftrite** (a placeholder). This document was rewritten on 2026-09-27 from the rebuild plans, which replace the earlier design (kept in `docs/archive/design-before-rebuild.md`). Each part of the design has a plan with the details:

| Part | Plan |
| --- | --- |
| Heroes, paths, vows, deeds, mana | `docs/plans/rebuild-heroes.md` |
| The arena: placement, movement, tanks, areas, the collapse | `docs/plans/rebuild-arena.md` |
| Enemies, elites, the boss | `docs/plans/rebuild-enemies.md` |
| The run: days, camp, fights, relics, duo bonds | `docs/plans/rebuild-run.md` |
| Decisions between fights: after-fight picks, loadout slots and the currency, wounds, the Magpie, and the screens' item language | `docs/plans/rebuild-between-fights.md` |
| Combos, scaling, and breaking the game: keywords, triggers, the damage rule, permanent scaling, relic tiers, the endless mode | `docs/plans/rebuild-combos.md` |
| Enemy specializations and upgrades, rift modifiers, and the rift learns | `docs/plans/enemy-growth.md` |
| Endless mode: floors, how the rift scales, the score | `docs/plans/endless.md` |
| Every shard source and price, and the Act 1 spending target | `docs/plans/economy.md` |
| The first content pool (part 7b): keyword sources, growing upgrades, and the combos the pool is built for | `docs/plans/rebuild-content-pool.md` |
| The relic pool: its rules, shops and rerolls, income, and every relic by tier | `docs/plans/relics/README.md` (and one file per tier) |
| The loadout pool: its rules, ranks, prices, and every tactic, gambit, sigil, and charm | `docs/plans/loadout/README.md` (and one file per kind) |
| The Magpie node, selling relics and items, and why grafts were cut | `docs/plans/magpie.md` |
| The after-fight pick's pools: each hero's, taste and path upgrades, stacking | `docs/plans/upgrade-pools.md` |
| A day's loop and its nodes, Rift Tear's depths, the Shrine | `docs/plans/days-and-nodes.md` |
| Events and the Bloodied Oath | `docs/plans/events.md` |
| Duo bonds and their bond relics | `docs/plans/duo-bonds.md` |
| The 18 apexes, their snowballs and upgrades | `docs/plans/apexes.md` |
| Build order, and what the rebuild removed | `docs/plans/rebuild-build-order.md` |
| Phase 1, the arena sim (build plan) | `docs/plans/rebuild-phase1-arena-sim.md` |
| Phase 2, base heroes, the Act 1 enemies, encounters, and the sim runner (build plan) | `docs/plans/rebuild-phase2-heroes-enemies.md` |
| Phase 3, the fight sandbox (build plan) | `docs/plans/rebuild-phase3-fight-sandbox.md` |
| Phase 3b, tactics in Practice (build plan) | `docs/plans/rebuild-phase3b-tactics.md` |
| Phase 4, paths (build plan) | `docs/plans/rebuild-phase4-paths.md` |

Where this summary and a plan disagree, the plan wins; fix this document.

## High concept

A PvE roguelite auto-battler. You lead three heroes down into the rift, one day at a time. Before each fight you see the enemies and place your heroes on the field; then the fight plays out on its own. Each hero is vowed to one of three paths and **transforms** into it by doing what the path asks in fights, then keeps growing through upgrade picks.

**Tone:** the rift, dark and dangerous. There is no warm hub to come home to (decided in the run plan). The art gets a complete rehaul once the game is known to be fun; until then everything is placeholder.

**Pillars**

1. **Placement is the skill.** Fights are watched, not played. The decisions are where your heroes stand, which fight you take, what you do at camp, and how your heroes grow.
2. **Heroes are the build.** No items, no essences, no shops. A hero changes over a run through a path you choose and then earn.
3. **Hard in fair, readable ways.** Every enemy asks one positioning question, big attacks are marked before they land, and you can always tell who's attacking whom and why.
4. **Fewer, deeper systems.** Nothing recreates the old item treadmill.

## Heroes

- **A team is 3 heroes, kept for the whole run.** All three fight. The slice starts with **Brannoc** (tank), **Maren** (ranged damage), and **Vell** (support); with a roster of 3 there's no team draft until hero 4.
- **A hero is** their stats (HP, ATK, MGK, DEF, CRIT, ATSP, plus **speed** and **range**), a **basic attack**, a **signature** (their big move), a **passive**, and sometimes a **trait** (Brannoc's Engage).
- **Signatures fire on a trigger:** usually a full mana bar, sometimes an HP threshold, a count of events, a set moment, or the hero about to fall. A hero without a mana signature has no mana bar. Only signatures use mana.
- **Mana** comes from basic attacks (mainly), damage taken (mainly tanks), a slow regen, and starting mana. Silence stops mana gain; Stun doesn't, but a stunned hero can't fire a mana signature.
- **Each hero has three paths.** You **vow** each hero to one when the run starts; the vow gives a small **taste** of the path and its **cost** at once. The vowed path's **deed** (a goal counted from what the hero does in fights) fills, and the hero **transforms**: a new signature, reshaped stats, the full mechanic, and an upgrade pool. After the Act 1 boss the path splits into two **apexes** (`apexes.md`), earned the same way; each has a built-in **snowball** that grows during a fight, and 2 upgrades that join the path pool. **Upgrade picks** (1 of 3, each card naming its hero) come after every won fight, not from deeds: from the hero's own pool (12), their vowed path's taste upgrades until they transform, and then the path's upgrades (`upgrade-pools.md`). Plain stat upgrades stack, each locked in as a flat amount of the stat when picked.
- **You can switch a vow** between fights until the hero transforms. Transformations are permanent.
- **Every deed is hard to fill without its taste**, and every path changes where you'd place the hero.
- **Heroes have no ranks, and there's no buying heroes and no duplicates.** Heroes grow through deeds (transformations, apexes) and after-fight picks. (Loadout items do have ranks, below.)
- **Loadout slots** (`loadout/README.md`): each hero has 3 slots for **tactics** (behavior plus a small payoff while following it, 4 shards), **gambits** (a placement or fight-start rule, one per hero, 12), **sigils** (how the signature fires, 8), and **charms** (a change to the hero's own kit, 6), chosen before each fight. None are abilities, and all are written against the slot ("your signature"), so none goes useless when a hero transforms. **Any hero can hold any of them**, with no warning when one does nothing, and no item has a downside or grants a path's key mechanic. **Every item has three ranks:** each kind ranks up by its own count (time following the order, fights used, casts, won fights), and buying a copy skips a rank. Shops don't filter by what the team can use, and any shop buys items back for half their price. Grafts are cut, the best of them now charms. The **Magpie** (`magpie.md`) is a rare node from day 3 (at most twice an act): two charms at rank II, one epic or legendary relic at 25% off, and the only place to sell a relic or swap one for another of its tier. (The rest of the shops' setup is being redone.)

## The arena

- **Placement:** a board of **flat-topped hexes, 8 wide and 7 tall**. Your zone is the 3 rows nearest you, the enemy's the 3 nearest them, and the middle row belongs to no one. You see the enemies' positions first, then place your heroes; your last formation is remembered. Encounters can add **rocks**.
- **The fight** happens on a **free-moving plane**: units start on their hex centers, then walk freely, never overlapping. Distances are still counted in hexes.
- **Movement and targeting:** units path around each other and rocks. By default a unit targets the **nearest** enemy by path length and sticks with it until it falls, a Taunt pulls it away, or it can't be reached. Some units use other rules (weakest back-liner, largest group, farthest, lowest-HP ally). Units stop to attack.
- **Attacks:** melee lands when the attack finishes. Ranged attacks fire **shots** that fly about 1 hex per tick and follow their target.
- **Tanks matter** through **blocking** (nobody walks through anyone), **Engage** (a unit next to Brannoc trying to reach someone else is held 1s), **Taunt**, and **knockback** (a push stopped by a unit, a rock, or the edge stuns).
- **Areas** (circle, line, cone, ring) are **marked before they land**; a unit is hit if its center is inside when it lands. Heroes never step out of marked areas: placement is the answer.
- **Statuses:** Root, Slow, Stun, Taunt, Engaged, Marked, Silence, Undying, Bleed, Burn, Poison, and Shield.
- **Rift Collapse:** from 45s the arena crumbles inward one ring every 10s (each warned first). Crumbled ground is walkable (decided 2026-09-30; not built yet), and standing on it deals flat damage every second to heroes and enemies alike. A fight still running at 180s is a tie, and a tie counts as a win.

## Enemies

- **Every enemy type tests one thing**, and the heroes' paths hold the answers. Act 1's roster covers eight archetypes: swarm (Rift Pup, Ashling), flanker (Rift Hound), caster (Cinder Moth), ranged (Hollow Archer), anchor (Rift-Worn Sentinel), charger (Cairn Guardian), disruptor (Bog Lurker), and support (Gloam Witch).
- **Fair:** enemy positions and threats show before you place your heroes, and every enemy has a one-line threat and an archetype icon on the fight card.
- **Elites** are a named leader plus a pack built around one mechanic (The Hunt, Gloam Totem, Stone Ward). **The boss**, Old Mother Ash, has phases that test the back line, then a swarm, then spreading out while the arena shrinks early.
- **Harder means new problems, not more HP:** later days combine threats, and stats grow only a little.
- **Enemy growth** (`enemy-growth.md`): each enemy type has 2 **specializations** that change how it plays (from day 5 of Act 1, only in the harder fight; about half of a fight's enemies in Act 2, most in Act 3), and elites and the boss carry 1–2 **upgrades** (Frenzied, Warded, Anchored, and so on). **Rift modifiers** are rules for the whole enemy side in one fight (Rift Tear's Deep and Abyssal depths add them). **The rift learns** is a difficulty modifier: it reads your last 3 fights and swaps up to half of a fight's specializations and upgrades for ones that blunt your top 1–2 habits, always shown on the fight card.

## The run

- **3 acts, each ending in a boss.** The slice is Act 1: about 7 days, elites on 2 of them, the boss on the last.
- **The start:** choose your three heroes, then vow each one.
- **A day** (`days-and-nodes.md`): **choose the fight** from 2 options known from the start of the act, set the **loadout**, **place** and fight, take the **after-fight pick** (on a win or a tie) and any deed rewards (transformations, apex vows), visit the **shop** (the Pedlar, every day: 1 relic at a time, the loadout wares, treating wounds), then choose **1 of 2–3 nodes**: an **Event** (a scene with a choice, or a Bloodied Oath; `events.md`), **Camp** (one option: Rest, Train, Scout, Map the Rift, Fortify, Dig In, Hunt, or the Shrine, which takes an offering for a relic), **Rift Tear** (pick a depth: tomorrow's fight is harder, and winning it pays a relic choice), or the **Magpie**.
- **Choosing fights feeds deeds:** which enemies you fight decides which deeds fill. The fight card shows the enemies, never which paths they suit.
- **No items or shops.** Camp options are free. A **currency** (placeholder: shards) comes from fights (`economy.md`: start 10; a normal win 10, the harder fight 13, an elite 15, the boss 25; placeholders) and Hunts, and buys loadout things, relics, wound treatment, and rerolls. Nothing sells back.
- **Wounds:** a hero who falls gets one (–15% max HP, up to 3), won or lost; Undying and would-fall saves don't count. Rest clears them all; currency clears one.
- **Relics** (`relics/README.md`): team-wide, **no downsides**, about **8–14 a run** in five tiers: **common** (5 shards), **rare** (12), **epic** (20), **legendary** (30, sold in the shop before each boss), and **boss** (after each boss, choose 1 of 3, free; each rewrites a rule of the game). **Every shop shows 1 relic at a time**, and rerolling replaces it (the first reroll 1 shard, each after it 1 more), so with enough shards a shop never runs dry. Once taken, a relic stays.
- **Duo bonds** (`duo-bonds.md`) link two paths of two different heroes; the vow shows a bonded pair as "?" until it's found. A bond has no boost of its own: once both heroes have transformed, its **bond relic** (free, team-wide) joins the shop pool for the rest of the run, more likely than an epic. Bonds are rare: 1–2 per path across the roster (3 in the Act 1 slice).
- **Losing:** a lost fight replays the day, and the second loss ends the run. Deed progress from a lost fight still counts. A tie pays like a win.
- **Random streams:** shop stock, picks, camp, and fight seeds each have their own stream from the run seed.
- **Pacing targets:** the first transformation around days 3–4, all three heroes transformed by the boss, and apexes in Acts 2–3. Upgrade picks come after every win (about 8 in Act 1), so each is small.
- **Difficulty target:** a good player clears Act 1 about half the time.

## Combos and scaling (part 7)

- **Keywords:** Marked, Rooted, Burning, Shielded, and Stealthed are statuses any hero can apply and any hero's charms, relics, and upgrades can pay off. They're team-wide: Maren's Mark counts for Vell's charm.
- **Triggers** for charms, relics, and upgrades to hang on: on crit, on kill, on applying or hitting a keyword, on a Shield breaking, on a signature (the unit's or an ally's), on a heal, on a hop. A chain of triggers stops after a set depth each tick.
- **One damage rule:** bonuses of the same kind (crit, vulnerability, power, relic) add; different kinds multiply. DEF, Shield, and healing work the same way.
- **Permanent scaling:** some upgrades and relics count what a hero does and grow all run (their card shows "Now: +X"); they reset with the run, so meta progression still adds no stats.
- **Every stat change says its amount** ("+10% attack speed"); ability text still leaves numbers to the numbers line.
- **No combo readouts for players:** working a combo out is part of the fun. The combat log stays complete, and a readout exists only behind the testing toggle and in the sim runner.
- **Endless mode** (after Act 3): a run goes on into floors where the rift scales exponentially; you always lose eventually, and the score is how deep you got. The campaign keeps "new problems, not more HP".

## Between runs

- **Difficulty tiers**, each unlocked by beating the one before, stack modifiers (the rift learns, specialized enemies sooner, longer deeds, and more).
- **Unlocks** add variety: new heroes (once hero 4 exists), camp options, places, and relics.
- **A Codex** records paths and apexes seen, duo bonds found, enemy specializations met, and relics found.
- **Meta progression never adds stats.**

## Technical notes

- **Engine:** Godot 4 with GDScript; the exact Godot and GUT versions are pinned in `CLAUDE.md`.
- **The combat sim is deterministic:** a seeded RNG, a fixed 20 ticks per second, and integer math only (percentages in basis points, positions in thousandths of a hex). Same seed, same inputs, same fight.
- **Every change in a fight is logged with its source**, so the fight screen can always answer why something happened, and replays, bug reports, and balance runs are possible.
- **Content is data:** heroes, enemies, encounters, paths, and relics are JSON in `data/`, validated at load.
- **A headless sim runner and a run bot** measure balance; the good-player bot is the tuning target. The sim runner (phase 2) fights every encounter from many formations and checks that placement matters; the run bot comes in phase 6.

## Decisions

The decisions from the rebuild discussions (2026-09-27) are listed in each plan's **Decisions** section. The ones that shape everything:

- Items, essences, shops, gold, the Guildhall, ranks, and the cozy tone are gone.
- Three heroes (Brannoc, Maren, Vell) first; the team draft returns with hero 4.
- Vows at the start; transformations are permanent.
- Placement on flat-topped hexes; fights on a free-moving plane.
- Heroes first in the fight's order; Engage holds a unit 1s; back-liners are set by where units start.
- Shots travel and can't miss; melee lands when the attack finishes; areas hit by center.
- Stun holds back only mana signatures; a would-fall trigger and an Undying status make last stands work.
- Up to 30 standing units per side.
- The fight sandbox stays in the game as a **Practice** mode.
- Old saves are dropped quietly.

## Open questions

- **Grid size:** is 8 × 7 right for 3 heroes against 3–6 enemies? (arena plan)
- **Large units:** should bosses ever take more than one hex? (arena plan)
- **Pacing:** how many fights a transformation takes. (heroes plan)
- **Apexes:** the apex deed's size (snowballs stay per fight, even in endless); whether a hero who transforms late gets a faster apex deed. (apexes)
- **Deed thresholds after the transformation:** does the same deed keep counting? (heroes plan)
- **Mana numbers** are a first pass for the sim to tune. Phase 2's first tuning pass left the heroes' numbers as designed. (heroes plan)
- **Last Watch after Last Rites:** is having no big move left the right feel? (heroes plan)
- **Enemy growth:** can the rift learns add a rift modifier (Blight, Thornskin) or only swap specializations and upgrades? Upgrades on normal enemies in Acts 2–3? (enemy growth)
- **Bond relics:** how much likelier than an epic; both relics at once when two bonds switch on; all three Act 1 bonds include Brannoc. (duo bonds)
- **Camp menus:** which places offer which options, and 2 or 3 options per camp. (run plan)
- **Art direction** for the rehaul. (run plan)
- **Grow enemies or shrink heroes?** Phase 2's tuning grew enemies (a Rift Pup has 210 HP, most of Maren's 270) and kept heroes as designed. Lowering heroes' damage instead would keep enemies nearer the roster's first numbers. (phase 2 plan, section 7)
- **Hollow Line's answer:** it's won by standing back out of the Archers' reach, not by closing distance as intended. (phase 2 plan, section 7)
- **Brannoc falls in almost every fight,** wins included. Is the tank dying last fine, or should he usually live? (phase 2 plan, section 7)
- **Ember Dust's size:** a radius-2 circle (the reach `largest_group` counts by) covers a lot of the board; radius 1 would be a much smaller zone. (phase 2 plan, section 5)
- **Maren's hop** shows in the log as the trait's "Hop Away", not her passive's name, "Keep Your Distance". (phase 2 plan, section 3)
- **Loadouts:** 3 slots each, or 2 then 3? (part 6)
- **Loadout ranks:** the rank-up counts are guesses; can charms stack with relics in the same lane (Leech Fang with Leech Tooth)? How often does a shop show a gambit? Gambits' frame. (loadout pool)
- **The currency:** its name, prices, and income; whether the Pedlar's relic turns up about 1 visit in 3 or only at certain places. (part 6)
- **The Magpie:** how often he's offered beyond "from day 3, at most twice an act"; is 12 shards right for a rank II charm, and half right for selling relics and items? (Magpie)
- **Rest:** does it also keep "the next loss doesn't count"? (part 6)
- **Wounds:** is –15% up to 3 right, and should a lost fight's falls wound? (part 6)
- **How fast heroes grow** with a pick after every win. (part 6)
- **Relics:** can the same common be bought twice? Are boss offers random or picked to fit the team? Is 8–14 a run right? (relic pool)
- **The economy:** the whole shard curve needs a sim pass; a Hunt's pay. (economy)
- **Chain limits:** Crown of Stars' 10 links and Shared Pain's 3 steps are guesses. (relic pool)
- **Upgrade pools:** how hero, taste, and path cards are weighted; one pick a day for the team, or a card per hero; a cap on stacking upgrades; and six upgrades whose "not X" numbers are the design's, not the built kits'. (upgrade pools)
- **Nodes:** show 2 or 3, and how often each kind; income with a shop every day. (days and nodes)
- **Events:** how often an Event is a Bloodied Oath; Whispering Stones' deed progress; can the Mirror Pool swap a transformed hero? (events)
- **The trigger chain's depth limit** (8 is a guess). (part 7)
- **Endless:** is ×1.15 a floor and a rift modifier every 3 floors right? Does income grow with the floor? (endless)
- **Which statuses become keywords next** (Slow, Bleed, Stun). (part 7)
