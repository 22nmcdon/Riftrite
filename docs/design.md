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
- **Each hero has three paths.** You **vow** each hero to one when the run starts; the vow gives a small **taste** of the path and its **cost** at once. The vowed path's **deed** (a goal counted from what the hero does in fights) fills, and the hero **transforms**: a new signature, reshaped stats, the full mechanic, and an upgrade pool. Late in a run the path splits into two **apexes**, earned the same way. **Upgrade picks** (1 of 3, each card naming its hero) come after every won fight, not from deeds.
- **You can switch a vow** between fights until the hero transforms. Transformations are permanent.
- **Every deed is hard to fill without its taste**, and every path changes where you'd place the hero.
- **No ranks, no buying heroes, no duplicates.** Heroes grow through deeds (transformations, apexes) and after-fight picks.
- **Loadout slots:** each hero has 3 slots for **charms** (small kit changes), **tactics** (behavior: "target casters first"), and **sigils** (how the signature fires), chosen before each fight. None are abilities, and all are written against the slot ("your signature"), so none goes useless when a hero transforms. **Any hero can hold any of them**; the Pedlar sells only what your team can use, and the rare **Magpie** sells other heroes' gear, one relic, and **grafts** (the one slotted thing that gives a hero something new to do, never a path's key mechanic).

## The arena

- **Placement:** a board of **flat-topped hexes, 8 wide and 7 tall**. Your zone is the 3 rows nearest you, the enemy's the 3 nearest them, and the middle row belongs to no one. You see the enemies' positions first, then place your heroes; your last formation is remembered. Encounters can add **rocks**.
- **The fight** happens on a **free-moving plane**: units start on their hex centers, then walk freely, never overlapping. Distances are still counted in hexes.
- **Movement and targeting:** units path around each other and rocks. By default a unit targets the **nearest** enemy by path length and sticks with it until it falls, a Taunt pulls it away, or it can't be reached. Some units use other rules (weakest back-liner, largest group, farthest, lowest-HP ally). Units stop to attack.
- **Attacks:** melee lands when the attack finishes. Ranged attacks fire **shots** that fly about 1 hex per tick and follow their target.
- **Tanks matter** through **blocking** (nobody walks through anyone), **Engage** (a unit next to Brannoc trying to reach someone else is held 1s), **Taunt**, and **knockback** (a push stopped by a unit, a rock, or the edge stuns).
- **Areas** (circle, line, cone, ring) are **marked before they land**; a unit is hit if its center is inside when it lands. Heroes never step out of marked areas: placement is the answer.
- **Statuses:** Root, Slow, Stun, Taunt, Engaged, Marked, Silence, Undying, Bleed, Burn, Poison, and Shield.
- **Rift Collapse:** from 45s the arena crumbles inward one ring every 10s (each warned first). Standing on crumbled ground deals flat damage every second, and nobody can walk onto it. A fight still running at 180s is a tie, and a tie counts as a win.

## Enemies

- **Every enemy type tests one thing**, and the heroes' paths hold the answers. Act 1's roster covers eight archetypes: swarm (Rift Pup, Ashling), flanker (Rift Hound), caster (Cinder Moth), ranged (Hollow Archer), anchor (Rift-Worn Sentinel), charger (Cairn Guardian), disruptor (Bog Lurker), and support (Gloam Witch).
- **Fair:** enemy positions and threats show before you place your heroes, and every enemy has a one-line threat and an archetype icon on the fight card.
- **Elites** are a named leader plus a pack built around one mechanic (The Hunt, Gloam Totem, Stone Ward). **The boss**, Old Mother Ash, has phases that test the back line, then a swarm, then spreading out while the arena shrinks early.
- **Harder means new problems, not more HP:** later days combine threats, and stats grow only a little.
- **Later:** each enemy type gets 2 specializations and a few upgrades; "the rift learns" is a difficulty modifier.

## The run

- **3 acts, each ending in a boss.** The slice is Act 1: about 7 days, elites on 2 of them, the boss on the last.
- **The start:** choose your three heroes, then vow each one.
- **A day:** **camp** (pick 1 option from the place's menu: hero growth, information, the arena, risk and reward, safety, spending, relics, or a rift event; Train gives a pick, Hunt currency, the Pedlar sells, Rest clears wounds), **choose the fight** from 2 options known from the start of the act, set the **loadout**, **place** and fight, then take the **after-fight pick** (on a win or a tie) and any deed rewards (transformations, apex vows).
- **Choosing fights feeds deeds:** which enemies you fight decides which deeds fill. The fight card shows the enemies, never which paths they suit.
- **No items or shops.** Camp options are free. A **currency** (placeholder: shards) comes from fights and Hunts, and buys only loadout things (at the Pedlar), wound treatment, and rerolls. Nothing sells back.
- **Wounds:** a hero who falls gets one (–15% max HP, up to 3), won or lost; Undying and would-fall saves don't count. Rest clears them all; currency clears one.
- **Relics** are team-wide, about **6–9 a run in three tiers** (part 7): **common** and **rare** ones each have a cost (a rare's cost is one some builds can dodge), and **every boss offers a choice of 3 build-defining boss relics**, which may be pure upside. A relic can be turned down, but once taken it stays. Now and then the Pedlar sells one, for about two days of income.
- **Duo bonds** link two paths of two different heroes; the vow shows a bonded pair as "?" until it's found.
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
- **Pacing:** how many fights a transformation takes, and how many upgrade picks come before the apex vow. (heroes plan)
- **Deed thresholds after the transformation:** does the same deed keep counting? (heroes plan)
- **Mana numbers** are a first pass for the sim to tune. Phase 2's first tuning pass left the heroes' numbers as designed. (heroes plan)
- **Last Watch after Last Rites:** is having no big move left the right feel? (heroes plan)
- **When enemy specializations arrive:** late Act 1 or from Act 2. (enemies plan)
- **When a duo bond switches on:** once both heroes transform, or weakly once both are vowed. (run plan)
- **Camp menus:** which places offer which options, and 2 or 3 options per camp. (run plan)
- **Art direction** for the rehaul. (run plan)
- **Grow enemies or shrink heroes?** Phase 2's tuning grew enemies (a Rift Pup has 210 HP, most of Maren's 270) and kept heroes as designed. Lowering heroes' damage instead would keep enemies nearer the roster's first numbers. (phase 2 plan, section 7)
- **Hollow Line's answer:** it's won by standing back out of the Archers' reach, not by closing distance as intended. (phase 2 plan, section 7)
- **Brannoc falls in almost every fight,** wins included. Is the tank dying last fine, or should he usually live? (phase 2 plan, section 7)
- **Ember Dust's size:** a radius-2 circle (the reach `largest_group` counts by) covers a lot of the board; radius 1 would be a much smaller zone. (phase 2 plan, section 5)
- **Maren's hop** shows in the log as the trait's "Hop Away", not her passive's name, "Keep Your Distance". (phase 2 plan, section 3)
- **Loadouts:** 3 slots each, or 2 then 3? How many tactics per hero, and which are shared by role? (part 6)
- **The currency:** its name, prices, and income; whether the Pedlar's relic turns up about 1 visit in 3 or only at certain places. (part 6)
- **Grafts and the Magpie:** the graft list and its frame; how often the Magpie comes, and whether his gear helps unlock a hero. (part 6)
- **Rest:** does it also keep "the next loss doesn't count"? (part 6)
- **Wounds:** is –15% up to 3 right, and should a lost fight's falls wound? (part 6)
- **Sigils on signatures without mana:** written by what they do, or marked with the triggers they fit? (part 6)
- **How fast heroes grow** with a pick after every win. (part 6)
- **Relics per run:** is 6–9 right, and how many rares against commons? (part 7)
- **Boss relics:** the pool's size, and whether one can have a cost at all. (part 7)
- **The trigger chain's depth limit** (8 is a guess). (part 7)
- **Endless:** its scaling rate, how often floors offer relics, and whether it's its own mode or the end of a run. (part 7)
- **Which statuses become keywords next** (Slow, Bleed, Stun). (part 7)
- **Where part 7 lands in the build order.** (part 7)
