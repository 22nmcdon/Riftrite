# Rebuild phase 5: the run, Act 1 (build plan)

Status: **built (2026-09-29); waiting on playtest gate 3.** (Go-ahead 2026-09-29.) Four questions are answered (Decisions 1–4); the playtester accepted the proposed defaults (Decisions 5–14, still marked *proposed* since they're first guesses to tune) and asked to start before playtest gate 2's findings are in. Phase 5 of `docs/plans/rebuild-build-order.md`. Design sources: part 4, `rebuild-run.md` (days, camp, fight choice, relics, duo bonds, losing, pacing); part 6, `rebuild-between-fights.md` (after-fight picks, loadout slots and the currency, wounds, the Magpie, and the screens from the playtester's mock); part 3, `rebuild-enemies.md` (elites and Old Mother Ash); part 1, `rebuild-heroes.md` (vows, transformations, upgrade pools). Part 6 wins where it and part 4 disagree. It builds on phases 1–4. What playtest gate 2 finds goes into this plan before its code starts.

**Goal:** a full Act 1 run, playable from New run to the run's end: choose and vow the heroes, seven days of camp, fight choice, loadout, placement, and the fight, then the after-fight pick; deeds filling into transformations; currency, the Pedlar, and wounds; relics, elites, Old Mother Ash, and duo bonds; save and resume.

**Done when:** **playtest gate 3: a full Act 1 run is playable start to finish.** This plan's own bar, before the playtest:
- a run is deterministic from its seed: the same seed and the same choices give the same run, offers and fights alike (the run's random streams, section 1);
- saving at any step between fights and loading gives exactly the same run;
- a simple run bot (section 12) plays hundreds of runs to the end without an error, and the run report measures pacing: when each hero first transforms (the design's target: the first around days 3–4, all three by the boss), how many picks each hero gets, and how often a run is won;
- fights in a run are exactly the fights `CombatSim.run` gives for their setups (as in Practice);
- every new sim piece logs with its source and has a form on the board (rules 2 and 4); Practice's fights are unchanged (the bench's fingerprints).

## Scope

**In phase 5:**
- **The run layer** (`src/run/`): run state, the act's days and fight options, the flow of a day, losing, save and resume, and the run's random streams.
- **Growth:** deed thresholds, transformations, Switch vow, the after-fight pick, and upgrade pools (the hero and path layers; lean, Decision 2).
- **The economy:** the currency (placeholder: shards), loadout slots (charms, tactics, sigils), the Pedlar, the Magpie (with grafts), and wounds.
- **Camp:** four places with their menus and a first set of options (Decision 8).
- **Relics** with costs, **duo bonds** (switching on when both heroes have transformed, Decision 4), **the three elites** and **Old Mother Ash**, and about **five new harder encounters** (Decision 3).
- **The screens** between fights, in the item language of the playtester's mock (part 6, section 9), with the hero bar on every one of them.
- **A simple run bot** and a run report, for tests and pacing. (The good bot is phase 6.)

**Not in phase 5:**
- The **role layer** of upgrades, apexes, Acts 2 and 3, enemy specializations and upgrades (beyond the one Rift Tear uses), difficulty tiers, the Codex beyond a list of found bonds, hero 4 and the team draft (all phase 8).
- The camp options that need more than this phase builds (Spar, Mentor, Meditate, Study, Bloodied Oath, Track the Elite, Lay Traps, Choose the Ground, Dare, Temper, rift events): phase 8, "more camp options".
- The good bot and tuning Act 1 to a win rate (phase 6); final art (phase 7).

## Decisions (2026-09-29)

1. **All at once** (the playtester's choice): every part is built, then one playtest build for gate 3. The order of work (section 14) still commits step by step, each green.
2. **Lean content first:** 3 upgrades per path and 3 per hero (36), about 10 charms, 5 sigils, the 4 tactics (Plant your feet joins them), about 8 relics, 3 duo bonds, and a few grafts. More comes with tuning.
3. **New harder fights:** keep the 9 encounters and add about 5 hand-placed ones that combine two threats. Each day offers one easier and one harder fight; the harder pays more.
4. **Duo bonds switch on when both heroes have transformed.** Vowing two bonded paths shows the bond as "?" (the mock's "a bond stirs").

The rest are *proposed* defaults, from the design and its open questions, for the playtester to confirm:

5. *Proposed:* **the act's days.** 7 days. Days 1–6 each offer 2 fights, drawn at the act's start from the encounters allowed that day (their `days`), one easier and one harder; **days 3 and 5 are elite days** (both options are elites; 3 elites, so 2 of them appear); **day 7 is Old Mother Ash**. You see every day's options from the start (part 4).
6. *Proposed:* **deed thresholds** come from the deeds report: about **3 fights' worth** of what a vowed hero puts into its deed on average (so a hero you push transforms around day 3–4, and one you don't by day 6–7). Thresholds are data per path (`deed_threshold`), tuned with the run report. After the transformation the deed keeps counting, toward the apex later.
7. *Proposed:* **a transformation happens as soon as the deed fills**, after the fight, with a screen that shows it. It's permanent. **Switch vow** is free between fights until the hero transforms; the new path's deed keeps what it had.
8. *Proposed:* **camp options in this phase:** Train (a pick), Hunt (an optional small fight for shards), Pedlar, Rest (clears all wounds), Scout (see the next 2 days' fights placed), Map the Rift (swap one of tomorrow's options), Fortify (a small Shield at the next fight's start), Dig In (place a rock in your zone for the next fight), Rift Tear (the next fight's enemies are upgraded; winning gives a relic choice), and Shrine (a relic choice). **Places:** Waystone, Ruined Chapel, Hunter's Blind, Rift Scar, each offering 3 options drawn from its own menu. The Pedlar appears at some places only.
9. *Proposed:* **Rest** only clears wounds (part 6: each option has one job); "the next loss doesn't count" goes away.
10. *Proposed:* **wounds from a lost fight** count like any others (the design: won or lost). The replayed day starts with them; Rest or paying clears them. The run report watches for a death spiral.
11. *Proposed:* **3 loadout slots** each (a relic can add a fourth). **Starting shards: 3.** Pay: a win 3, the harder fight 5, an elite 6, a Hunt 2; prices: a charm or tactic 2–3, a sigil 4, a wound 2, a reroll 1, the Pedlar's relic about 9, the Magpie about 1.5 times the Pedlar's. "Take 3 shards instead" on the pick is a fixed 3. All tuning values.
12. *Proposed:* **sigils are written by what they do,** and tagged with what they need ("needs: mana"). One that does nothing on a hero shows "no effect on this hero" in its slot (part 6, section 8).
13. *Proposed:* **the Magpie** comes once in Act 1, on a random day from 3 to 6, as the camp's only option that day.
14. *Proposed:* **the run bot is simple:** it places from the sim runner's named formations, picks fights, camp options, picks, and purchases by simple rules. It's for tests and pacing, not a win rate.

## 1. The run's state and randomness

- **`RunState`** (`src/run/run_state.gd`): the seed; the act and day; the attempt (a lost fight replays the day); losses; the phase of the day (camp, route, loadout, placement, after the fight); each hero's path, stage, deed totals for all three paths, upgrades taken, wounds, and equipped slots; shards; owned charms, tactics, sigils, and grafts; relics; found bonds; every day's two fight options; the next fight's modifiers (Fortify, Dig In, Rift Tear, Scout); and what's waiting to be chosen (a pick, a relic choice, a transformation).
- **`RunFlow`** (`src/run/run_flow.gd`): the only thing that changes a `RunState`, one action at a time (`choose_camp`, `choose_fight`, `equip`, `buy`, `fight_result`, `take_pick`, ...), each checked and refused with a reason if it isn't legal now. The UI and the bot both drive it.
- **Random streams** (`RunRandom`, kept): every offer draws from a stream seeded by the run seed and where it happens (what, act, day, attempt, visit, reroll), so buying or rerolling never changes a later offer or fight. A fight's seed comes from its own stream.
- **Save** (`src/run/run_save.gd`): the state as versioned JSON in `user://run.json` after every action; the title's Continue loads it. Offers are pure functions of the seed and the state, so a save holds only the state.

## 2. The act and the fight options

- **`data/act1.json`:** the days (7), which are normal, elite, or boss, the places each day's camp can be, and the pay table. The encounters stay in `encounters.json`, each with its `days` and a new `tier` (`easier`, `harder`, `elite`, `boss`) and `pay`.
- **Drawing the options** at the act's start: for each normal day, one easier and one harder encounter allowed that day, never the same encounter twice in a row; elite days draw two elites; day 7 is the boss.
- **The fight card** (route screen): the encounter's name, its enemies with their archetype and threat line, its tier and pay, and (after Scout) the enemies placed on a mini board. It never says which paths a fight suits (part 4).
- **About 5 new harder encounters**, each combining two threats (Decision 3), for example: Sentinel and moths (a wall and bunching), hounds and archers (the back line from two sides), a lurker with ashlings (pulled into a crowd), pups around a witch (a swarm and priority), and a guardian with hounds (the tank knocked away, then flankers). Placed by hand and checked with the sim runner's placement gate.

## 3. The day

1. **Camp:** 3 options from the place's menu (section 9); pick one.
2. **Route:** pick one of today's two fights.
3. **Loadout:** fill each hero's slots from what you own (free to swap).
4. **Placement and the fight:** the arena screen, as in Practice, with the run's heroes (their paths, stages, upgrades, loadout, and wounds) and the fight's modifiers.
5. **After the fight:** deed totals add what the fight put in; a hero who fell gets a wound; a win or a tie pays shards and offers the pick; a filled deed transforms its hero; a Rift Tear win or an elite or the boss offers a relic choice.
6. **A loss** replays the day (camp again, same fight options); the second loss ends the run. Deeds and wounds from the lost fight stay.

**Built in step 2 (2026-09-29):** `data/act1.json` (`ActDef`: the days, the pay by tier, starting shards, `losses_to_end`, slots per hero), loaded by `RunContent` (`src/run/run_content.gd`, beside `ContentDb`; the validator checks it too). Encounters have a `tier` (`easier` by default). `ActDraw` draws every day's options from the run's seed at the start (a normal day: one easier and one harder, or two easier while there are no harder ones yet; never the previous day's; elite and boss days fall back to normal fights until step 7 adds them). `RunState` (with `to_dict`/`from_dict`, version 1), `RunFlow` (`start`, `resume`, `leave_camp`, `choose_fight`, `fight_setup`, `fight`, `record`, `finish_day`; each refused with a reason when it isn't legal now), and `RunSave`. The save is `user://rift_run.json`, not `run.json`: `Main` still deletes the old game's `user://run.json` at start. A fight's seed is its own stream (fight, act, day, attempt), so a replay is a different fight. Wounds come from the fight's DEATH entries; deeds from `FightResult.deeds`. `tools/run_bot.gd` plays a run to its end (camp: leave; route: the first fight; one fixed formation). Tests: `tests/run/test_run_flow.gd`; the bench's fingerprints are unchanged.

## 4. Deeds and transformations

- Each path gets a `deed_threshold` in `paths.json` (Decision 6).
- After each fight, every hero's three deed totals grow by what the fight put in (all three always count, part 1). When the vowed path's total reaches its threshold, the hero transforms (Decision 7): a screen shows the new form, and the hero's kit is the transformed one from the next fight on.
- **Switch vow** (the hero panel's Path tab, between fights): free until the hero has transformed.
- The hero bar and the panel show deed progress as a bar toward the threshold ("1,240 / 2,000", "62%"), as in the mock.

## 5. The after-fight pick and upgrade pools

- **`data/upgrades.json`** (`UpgradeDef`): its layer (`hero` or `path`), who or which path it's for, its name and sentence, and what it changes: a **kit modifier** (section 7). Lean content (Decision 2): 3 per hero and 3 per path, drawn from the design's "upgrade pool examples" (`rebuild-heroes.md`) and the mock (Deep Mend, Steady Hands, Unbroken Wall).
- **The offer:** three cards, one per hero by default (sometimes one is a wild card for any hero; part 6). Before a hero transforms, from its hero layer plus upgrades that lean toward its vowed path (the "vow" picks: a path upgrade that only needs the taste's piece); after it, the path's pool joins. No duplicates of what's taken.
- **"Take 3 shards instead"** (the mock).
- Upgrades are permanent, listed on the Path tab ("Upgrades taken").

**Built in step 3 (2026-09-29):** each path's deed has a `threshold` in `paths.json` (three times the vowed per-fight average in phase 4's table, section 7: Deadeye 900, Trapper 5,400 ms, Volley 6, Hearthwall 10, Ironbrand 20, Last Watch 35, Lanternbearer 25, Wardweaver 6, Vigil Keeper 100; the run report tunes them). `RunFlow.record` transforms a hero whose vowed deed reaches it, after any fight (won or lost), and lists it in `RunState.just_transformed` for the screen. `switch_vow` works between fights until the hero transforms. `data/upgrades.json` (`UpgradeDef`, loaded and checked by `RunContent`): 3 per hero and 3 per path, one of each path's a vow pick. A win draws the pick (`Offers.pick`, stream PICK/act/day/attempt/visit): one card per hero, and with the act's `wild_card_pct` (25) one card from anyone's pool. `take_pick` or `take_shards` (the act's `pick_shards`, 3); `finish_day` waits for it. `fight_setup` passes the upgrades' mods through `HeroExtras`. Tests: `tests/run/test_growth.gd`.

Decisions made while building it (step 3):
- **A vow pick can carry two mods:** `mod` for the vowed kit and `transformed_mod` for the transformed one, since the taste's piece and the transformation's are different parts (Deadeye's Steady becomes Planted). `RunContent` checks every mod against every kit it can meet: it must apply soundly and change something.
- **A path's upgrade counts only while the hero is on that path.** A vow pick taken before a Switch vow waits, and comes back if the hero switches back.
- **Switching into a path whose deed is already full** transforms the hero after the next fight, not at once (transformations happen after fights).
- **A pick with nothing left to offer** has fewer cards, or none; a hero with an empty pool gives its card to anyone's.

## 6. The loadout, the currency, and wounds

- **`data/items.json`** (`ItemDef`): kind (`charm`, `tactic`, `sigil`, `graft`), name, sentence, the fight it answers (the mock's "Answers flankers (Rift Hound)": written by hand), what it needs (`mana`, `heals`, `hops`, `ranged`, `melee`), its price, and what it changes (a kit modifier, or for a tactic the existing `TacticDef`). Tactics move from `tactics.json` into items as their own kind. Lean content: about 10 charms, 5 sigils, the 4 tactics, and 3 grafts.
- **Slots:** 3 per hero (Decision 11). Anyone can equip anything; one that does nothing shows "no effect on this hero" (checked from its needs against the hero's kit).
- **The Pedlar:** about 4 wares drawn for what the team can use, now and then a relic, treating a wound, and a reroll (the mock's page 5). **The Magpie** (Decision 13): other roles' gear, grafts, and a relic, dearer, no rerolls.
- **Wounds:** a hero who falls (and wasn't saved by Undying or would-fall) gets one: –15% max HP, up to 3 (a hero's max HP in a fight is its kit's times 1 – 0.15 per wound). Shown as a greyed, striped chunk of the HP bar. Rest clears all; 2 shards clear one.

**Built in step 4 (2026-09-29):** `data/items.json` (`ItemDef`, loaded and checked by `RunContent`): 10 charms, 4 tactics, 5 sigils, 3 grafts. `ItemDef.works_on` gives "no effect on this hero" (needs, then the mod's `affects`, or whether the hero can take the tactic). `RunState.stash` holds what's owned and not slotted; `RunFlow.equip`/`unequip` between fights. A shop opens at camp (`open_shop`: the Pedlar or the Magpie; camp's options open it in step 5): `buy`, `reroll` (the Pedlar), `treat_wound`; leaving camp closes it. `act1.json` has the prices (wound 2, reroll 1), the shops' sizes (4 each), and the Magpie's markup (150%). A fight's kit is the path's, then its upgrades, then its loadout in slot order; a tactic item passes its tactic. The sim pieces (each code, rule 3): a signature's extra triggers (`TriggerDef` `ally_falls`, and `hp_below` as an extra; `AbilityDef.also`, the FIRE entry's note says why), **Echo** (`AbilityDef.echo`: a weaker copy that fires a set time after each fire, its own source "Mend (Echo)"), and the tactic kind `stop_near` (Plant your feet, in `tactics.json`), all through `KitMod` (`also_fires`, `echo`). Tests: `tests/run/test_economy.gd`, `tests/sim/test_sigil_pieces.gd`; the bench's fingerprints are unchanged.

Decisions made while building it (step 4):
- **A hero holds one tactic** (as in Practice): equipping a second is refused; one can swap for another.
- **Tactics stay in `tactics.json`** (the sim's, shared with Practice); a tactic item names its tactic.
- **The Magpie** lays out 4 wares: 2 grafts and 2 other items of any kind (standing in for other heroes' gear until a fourth hero), at 150% of the price, rounded up, with no rerolls. Its relic comes with step 6.
- **Treating a wound** needs an open shop (the Pedlar or the Magpie).
- **Echo:** its numbers and timed durations at its share (50%: half as much, half as long), at a fresh target by the signature's rule; a new fire while one waits moves it later; with no target, it's lost.
- **Plant your feet** has no payoff yet (the round 2 payoffs came from playtesting; this one waits for it).
- **Item texts may carry numbers** ("below 40% HP", "2s later"), as part 6's examples do; the generated numbers line comes with the screens.

## 7. New sim pieces (each is code; rule 3)

- **Kit modifiers** (`KitMod`, `src/sim/defs/kit_mod.gd`): the one shape for upgrades, charms, sigils, grafts, relics that change a kit, and enemy upgrades (part 6's "one modifier shape"). A modifier is written against a slot, not an ability's name: `stats` (bp or add), `basic_attack`, `signature`, `passives`, or `trait`. Operations: scale a field (`amount_bp`, `duration_bp`, `radius_add`, `cooldown_bp`, `mana_max_add`), add an effect to an ability, add a passive, add a trigger to the signature ("also fires when an ally falls"), or set a flag. Applied at setup, after the path's patch, in a fixed order (upgrades, then loadout, then relics), so a fight is still a pure function of its setup. Its numbers line comes from `UnitInfo`, like everything else.
- **Wounds:** `UnitSetup.max_hp_bp`.
- **Sigils that need new sim rules:** an extra signature trigger (an ally falls; below an HP share), and **Echo** (the signature fires again at a share of its strength a set time later).
- **Relics in the sim:** team-wide modifiers (Ember Heart's doubled Burn and weaker healing), applied to every hero; relics that change the run (Hollow Crown's fourth slot, Rift-Glass Eye's scouting) live in `RunFlow`.
- **Duo bonds:** two modifiers, one per hero, active when both have transformed into the bond's paths.
- **The elites and the boss** (what phase 2 listed as needed): an "ally fires X" trigger (The Hunt: every hound Pounces on the same hero), a totem unit (Gloam Totem: no attack, an area that Shields enemies within 2 hexes), an aura that checks whether allies of a kind stand (Pack Bond), walking to a spot rather than a unit (Molt: she stalks into the middle), and summons that arrive from the arena's edges (Molt's pups). Ember Breath (a warned cone) and the rift closing early (`start_collapse`) already exist.
- **Camp effects on the next fight:** Fortify (a Shield at the start), Dig In (a rock in your zone, placed during placement), and Rift Tear (one enemy upgrade on every enemy, e.g. Warded: a Shield at the start).

**Built in step 1 (2026-09-29):** `KitMod` (`src/sim/defs/kit_mod.gd`) with stats, added passives, per-slot changes (`basic_attack`, `signature`, `abilities`, or `passive:<id>`; amount, durations, radius, cooldown, added effects, a passive aura's delay; an optional effect-type filter that reaches into areas and snares), and mana changes; `affects(kit)` for "no effect on this hero". It copies what it changes (`DefCopy`), so content is never touched. `Encounters.setup` takes `extras` (hero id -> `HeroExtras`: mods and wounds), applies the mods after the path's patch, and sets `UnitSetup.max_hp_bp` from wounds (`tuning.json`: `wound_bp` 1500, `max_wounds` 3); `FightSetup.validate` bounds it. The sigil pieces (an extra trigger, Echo) come with the economy (step 4). Tests: `tests/sim/test_kit_mods.gd`; the bench's fingerprints are unchanged.

## 8. Relics and duo bonds

- **`data/relics.json`** (`RelicDef`): name, a line of flavor, its boon and its cost, each a kit modifier or a run rule. About 8 (Decision 2), including the mock's Ember Heart, Hollow Crown, Rift-Glass Eye, and Pilgrim's Lantern. Sources: elites and the boss (a choice of 2, or none), the Shrine, a Rift Tear win, the Pedlar now and then, and the Magpie. About 3–5 a run.
- **`data/bonds.json`** (`BondDef`): its two paths and what each hero gets. Three, from part 4's examples: Sentry and Sniper (Hearthwall + Deadeye), Snare and Cleave (Ironbrand + Trapper), and Light and Iron (Wardweaver + Hearthwall). A found bond is kept in the save's list (the Codex comes later).

## 9. Camp

- **`data/camps.json`:** the options (Decision 8) and the four places with their menus and weights. A camp shows 3 options drawn from its place's menu (a tuning value).
- **Hunt** is a fight right away (a small pack drawn for the day), paying shards; losing it doesn't count as a loss.
- Scout and the next fight's modifiers show on the route and placement screens.

**Built in steps 5 and 6 (2026-09-29):** `data/camps.json` (`CampsDef`): the options' names and lines, the four places and their menus (6 options each; a camp shows 3), the Magpie's days (3–6), the Pedlar's relic chance (33%), and Fortify's and Rift Tear's mods. What each option does is `RunFlow.choose_camp`'s (one job each; `CampsDef.OPTIONS` lists them). A camp is drawn on arriving (`Offers.camp`, the CAMP stream by day and attempt); on the Magpie's day (its first try) he's the only option. The next fight's modifiers (Fortify, Dig In's rock, Rift Tear, a steadying Rest) are spent by the day's fight, won or lost. A Hunt draws one of two new small packs (`stray_pups`, `lone_hounds`: tier `hunt`, left out of the sim runner's gate), fights at camp with its own seed stream, pays 2 shards on a win, and a loss isn't a loss. `data/relics.json` (`RelicDef`: a team mod, an enemy mod, a Rest mod, and run rules: slots, what a wound takes, always Scouted, prices, pay, pick cards); a choice of 2 or neither after a won elite or Rift Tear fight and at the Shrine; one for sale at the Pedlar now and then (9 shards) and at the Magpie always (14). `data/bonds.json` (`BondDef`): three bonds, on once both heroes have transformed (found then), stirring while both are vowed. A fight's kit order: path, upgrades, loadout, relics, camp modifiers, bonds. The run bot takes camp options by a fixed order (Rest when someone has 2 wounds), shops, hunts, and takes the first relic. Tests: `tests/run/test_camp.gd`.

Decisions made while building them (steps 5 and 6):
- **Leaving camp without taking an option** is allowed; anything an option opened (a pick, a relic choice, a Hunt, Map the Rift's swap) must be settled first.
- **Map the Rift:** the player picks which of tomorrow's two fights to swap; the new one is of the same tier and allowed that day. Not before the boss.
- **Dig In:** the rock can be placed any time before the fight, on a hex of the heroes' zone; one under a hero is refused at the fight.
- **Fortify and Rift Tear** are kit mods (a Shield at the fight's first tick, 40 on each hero and 30 on each enemy), so they need no new code.
- **A Hunt** takes no camp modifiers and counts deeds and wounds like any fight; it gives no pick.
- **Relics, first versions within kit mods:** Ember Heart's "Burn doubled" became "every basic attack Burns" (a mod can't double a status); Pilgrim's Lantern's Rest bonus lasts the next fight.
- **Bonds, first versions within kit mods:** Sentry and Sniper gives Brannoc mana per attack (not mana on Maren's far hits) and Maren +1 range while planted; Light and Iron gives Brannoc DEF (not mana for Vell from guarded damage). Richer versions need their own sim pieces; the run report decides whether they're worth it.

## 10. Elites and Old Mother Ash

- **The Hound Alpha, "The Hunt"**, **the Witch Coven, "Gloam Totem"**, and **the Cairn Watch, "Stone Ward"** (`rebuild-enemies.md`, section 3), each an encounter of tier `elite` with its leader and pack, previewed from the act's start. Each says what it does and what answers it on its card.
- **Old Mother Ash** with two Ash Hounds: Pack Bond; Molt below 60% (she stalks into the middle, pups every 10s from the edges); Last Ember below 25% (Ember Breath, and the rift closes early). New enemies: the Hound Alpha, the Ash Hound, the Gloam Totem, and Old Mother Ash (the witch and guardian elites use existing enemies).
- Their HP comes from the sim runner, like phase 2's: each must pass the placement gate.

**Built in step 7 (2026-09-29):** five harder fights (tier `harder`: Hounds and Archers, Lurker's Kindling, Sentinel Under Moths, Witch's Brood, The Warded Charge), the three elites (The Hunt, Witch Coven, Cairn Watch; tier `elite`, days 3 and 5), and Old Mother Ash (tier `boss`, day 7), with five new enemies: the Hound Alpha, the Hunting Hound, the Gloam Totem, the Ash Hound, and Old Mother Ash. Each encounter's `tests` line says what it asks and (elites and the boss) what answers it. The sim pieces (each code, rule 3): an aura on while an ally of a kit stands (`"while": "ally_standing"`, Pack Bond); a signature that fires once when an ally's ability fires, at that fire's target (`ally_fires`, The Hunt; its FIRE entry notes "with <ally>"); and the `inert` trait (the Totem never targets, attacks, or walks; its passives work). Molt's walk into the middle is a range aura in the phase (she reaches 1 hex, so she walks in); her pups come from the edges and Last Ember closes the rift with pieces already there. `CombatSim.result_of` gives a fight's result from a sim played tick by tick (the screens). Tuned with the sim runner (1 seed, 4 named + 20 drawn formations, base heroes), by `scale_bp`, until each passes the placement gate:

| Encounter | scale_bp | Formations that win |
| --- | --- | --- |
| Hounds and Archers | 8000 | 17 of 24 |
| Lurker's Kindling | 8000 | 9 of 24 |
| Sentinel Under Moths | 15500 | 14 of 24 |
| Witch's Brood | 8000 | 8 of 24 |
| The Warded Charge | 12500 | 7 of 24 |
| The Hunt | 7500 | 19 of 24 |
| Witch Coven | 5500 (and the Totem's Shield 25 to 15) | 4 of 24 |
| Cairn Watch | 11000 (step 9: 10000 won 21 of 24, and every run-report team beat it) | 11 of 24 |
| Old Mother Ash | 6500 | 13 of 24 |

These are against base heroes; in a run the heroes are vowed or transformed and upgraded by then, so the run report (step 9) tunes them again. Tests: `tests/sim/test_elite_pieces.gd`, and the encounter tests list the new rosters.

Decisions made while building it (step 7):
- **Molt's "stalks into the middle"** is a phase aura that cuts her reach to 1 hex, so she walks in toward the heroes; no "walk to a spot" piece.
- **The Hunt:** the Alpha pounces at the start; its Hunting Hounds pounce once, when it does, on its target wherever that hero is (not their own pick).
- **The Gloam Totem** is a support (Casters first goes for it) with the `inert` trait.

## 11. The screens

All in the mock's style (`docs/mockups/hero-panel-layout.pdf`), with the top bar (day, act and place, shards, relics) and the hero bar along the bottom of every screen between fights:
- **Title:** New run, Continue (if there's a save), Practice.
- **New run:** the three heroes and a vow for each (the path cards from the hero panel), then Begin.
- **Day:** camp (the place and its 3 options), then the route (today's two fight cards, and the days ahead), then the loadout (each hero's slots and what you own, drag or click to equip).
- **Placement and the fight:** the arena screen in run mode (the fight's modifiers shown; Dig In's rock placed like a snare).
- **After the fight:** the pick screen (page 4 of the mock), a transformation screen when a deed fills, and a relic choice (page 6) when one is due.
- **The Pedlar** (page 5) and **the Magpie**.
- **The run's end:** won or lost, the days, each hero's path and stage, upgrades, relics, and bonds found.
- **The item language** (page 2): one frame shape per kind (arch, medallion, banner, diamond, hexagon, linked rings), drawn as placeholder vector shapes, at three sizes (card, slot, chip), with a hover card for every chip.

**Built in step 8 (2026-09-29):** `RunSession` (`src/ui/run/run_session.gd`) is Practice's session over a `RunFlow`, so `ArenaScreen`, `HeroBar`, and `HeroPanel` show the run's heroes as they are (paths, stages, upgrades, loadouts, relics, bonds, wounds); every action goes through it and is saved at once. The title has Continue (when a run is saved), New run, and Practice. `RunStartScreen` vows each hero (each path's taste, cost, and deed; "a bond stirs" when two vowed paths are bonded), with a seed drawn from the clock and shown. `RunDayScreen` has the top bar (the day, the act and place, relics as chips with their boon and cost on hover, shards), what's waiting (a transformation, the pick's cards with "HERO · VELL" / "VOW · DEADEYE" / "PATH · HEARTHWALL" and "Take 3 shards instead", a relic choice or neither), then the day's step: camp (the place's options, then the Pedlar or Magpie, Map the Rift's swap, the Hunt), the route (each fight's tier and pay, what it tests, its enemies' threat lines, where they stand once Scouted), the loadout (each hero's slots, the stash with an equip button per hero and "no effect on" lines), after the fight (how it went, Next day), and the run's end (every fight fought). The arena in a run shows the run's top bar, places Dig In's rock with a click on a hex of the heroes' zone, and ends with Continue (the fight is recorded as `CombatSim.result_of` its sim, exactly RunFlow's fight) instead of Rematch and Place again. The hero bar shows wounds (a greyed, striped chunk of the HP bar), the vowed deed toward its threshold ("Deadeye deed 300 / 900"), and each slot's item; the hero panel shows the deed's progress, Switch vow on the other paths (until the hero transforms), the upgrades taken, the duo bond (on, stirring, or none), and the loadout's items. `tools/ui_screenshots.gd` renders the run's screens too. Tests: `tests/ui/test_run_screens.gd` (a day from camp to the next, a Hunt, the Pedlar and the loadout, the hero bar and panel, Continue, and the run's end, through a real `Main`).

Not yet (the item language): items are drawn as cards with their kind's color, not page 2's frame shapes; slots and chips are text. Placeholder art until phase 7.

## 12. The run bot and the run report

- **`tools/run_bot.gd`** (Decision 14) plays whole runs through `RunFlow`: placement from the named formations, the easier fight unless its deed wants the harder, camp by a simple priority (Rest when wounded, Pedlar with shards, else Train), the first pick that suits the vowed path, and cheap purchases.
- **`tools/run_runner.gd`** reports over many seeds: runs won, where they end, each hero's first transformation day, picks per hero, shards earned and spent, wounds taken, and relics found. Not a gate; it tunes thresholds and pay.

**Built in step 9 (2026-09-29):** `tools/run_runner.gd` (its work in `tools/run_report.gd`) plays runs with the bot, each run's vows cycling through the 27 combinations, and reports runs won and where they end, the first transformation (each path's: how often, the median day, by the boss, and its deed per fight while vowed against its threshold), picks per hero, shards, wounds, relics, and each encounter's wins. For the report the bot looks ahead: it tries the sim runner's four named formations and keeps the first that doesn't lose (a stand-in for a player who places well; the tests' bot places "guarded" only). The bot takes the pick's card for the hero with the fewest upgrades. Camp offers only options with something to do today (no Hunt without a pack, no Map the Rift before the boss, no Scout on the last day): the report found the bot stuck on a day 7 Hunt.

Tuned (54 runs, seeds 1–54): deed thresholds to about 3.5 fights of each path's deed per fight while vowed (Deadeye 900, Trapper 8.0s, Volley 10, Hearthwall 7, Ironbrand 36, Last Watch 52, Lanternbearer 25, Wardweaver 9, Vigil Keeper 140), and Cairn Watch's scale to 11000 (every run's team beat it at 10000). The read:

| Measure | Result | The aim |
| --- | --- | --- |
| Runs won | 25 of 54 (46%) | about half, for a good player (part 3) |
| First transformation | 46 of 54 runs; median day 3 | days 3–4 |
| Paths transformed at all | 50–83% of runs vowed to each (Wardweaver 55%, Hearthwall 50%) | all three by the boss |
| Picks per run | Brannoc 2.3, Maren 1.9, Vell 1.4 | small, steady (part 6's open question) |
| Per run | 16.5 shards earned, 11.8 spent, 8.0 wounds, 1.6 relics | 3–5 relics |

Flagged for the playtest (not changed): Old Mother Ash falls to 25 of the 26 teams that reach her (her scale is held down by the placement gate, which fights base heroes); Hollow Line is the hardest easier fight (29%); relics come less often than 3–5 a run; runs lost mostly end on days 2–3. Tests: `tests/tools/test_run_report.gd`.

## 13. Files

| File | Change |
| --- | --- |
| `data/act1.json`, `upgrades.json`, `items.json`, `relics.json`, `bonds.json`, `camps.json` | New |
| `data/encounters.json`, `enemies.json`, `paths.json`, `tactics.json` | New encounters, elites, and the boss; tiers and pay; deed thresholds; tactics become items |
| `src/run/run_state.gd`, `run_flow.gd`, `run_save.gd`, `act_draw.gd`, `offers.gd` | New: the run |
| `src/sim/defs/kit_mod.gd`, `upgrade_def.gd`, `item_def.gd`, `relic_def.gd`, `bond_def.gd` | New definitions |
| `src/sim/setup/encounters.gd`, `unit_setup.gd`, `src/sim/content_db.gd` | Modifiers, wounds, and the new files |
| `src/sim/...` | The pieces in section 7, each in its own step |
| `src/ui/screens/` new run, day (camp, route, loadout), pick, transformation, relic choice, Pedlar, Magpie, run end; `src/ui/widgets/` item frames and cards, the top bar | New |
| `src/ui/screens/arena_screen.gd`, `hero_bar.gd`, `hero_panel.gd`, `main.gd`, `title_screen.gd` | Run mode, deed bars, Switch vow, Continue |
| `tools/run_bot.gd`, `tools/run_runner.gd` | New |

## 14. Order of work (each step: code, tests, green run, commit)

1. **Kit modifiers and wounds** in the sim, with tests (Practice unchanged).
2. **The run layer:** `RunState`, `RunFlow`, the act draw, losing, save and resume, with tests; the run bot plays a bare run headless.
3. **Growth:** deed thresholds, transformations, Switch vow, upgrades as data, the pick.
4. **The economy:** items as data (charms, sigils, tactics, grafts), slots, shards, the Pedlar, the Magpie, wounds in the run; the sigil pieces.
5. **Camp:** places, options, and their effects on the next fight.
6. **Relics and duo bonds.**
7. **The new harder encounters, the elites, and Old Mother Ash**, with their sim pieces; the placement gate on each.
8. **The screens**, one by one, with the item language and the hero bar; the run playable end to end in the UI.
9. **The run report and tuning:** thresholds, pay, prices, and elite and boss numbers.
10. **Docs, screenshots, HOW-TO-PLAY, and the gate 3 playtest build.**

## 15. Tests

- **The run:** determinism (the same seed and choices give the same states and fights); save and load at every step; every `RunFlow` action refused when illegal, with its reason; the act draw; losing and replays; the run bot finishing many seeds.
- **Kit modifiers:** each operation on each slot, the order they apply in, and that a modifier written against a slot survives a transformation.
- **Each new sim piece:** its rules in small fights, its log lines, its audit rule, and its form on the board.
- **Content:** every upgrade, item, relic, and bond names its reaches and has a numbers line (as abilities do); every encounter passes the placement gate.
- **The screens:** each screen driven by a test through `RunFlow`, and a run played from the title to its end in the UI with fake time.

## 16. Playtest gate 3, first findings (2026-09-30)

The playtester's first read of the run: **wounds were much too hard to deal with; basic fights were too hard, sometimes harder than the elites; and Brannoc fell in every fight however he was placed.** Measured before changing anything (each encounter from the 4 named and 40 drawn formations, base heroes, `tools/sim_report.gd`): the nine basic fights were at full strength (scale 10000, phase 2's puzzle tuning, where a third to two thirds of formations win), while phase 5 had scaled the harder fights to 8000 and the elites to 5500–7500. So a basic fight could be harder than a harder one or an elite. Brannoc fell in 80–100% of the formations that won most basic fights, and in no winning formation at all in Ash Nest, The Pack, and Cairn Road.

**Decisions** (the playtester, 2026-09-30):
17. **A won fight heals a wound.** A win (a tie, or a Hunt won, too) first heals one wound on each hero; then each hero who fell takes one. Wounds hurt a bad streak, not a run of wins. Rest and a shop's treatment still clear them.
18. **A tougher Brannoc:** HP 420 → 630, DEF 30 → 50 (he takes 67% of a hit, not 77%). The other heroes are unchanged. (560/80 and 700/60 were tried too: once the fights are retuned, how often he stands barely moves, so the smallest change that got there was kept.)
19. **Difficulty climbs by tier.** Every fight's `scale_bp` was retuned so the share of formations that win is about: basic 70–80%, harder 55–65%, elites 40–50%, Old Mother Ash 35–45%. The fights are races that flip at sharp steps (Guardian and Witch goes from 81% to 40% between 14750 and 14800), so where a target falls between steps the harder step is taken, keeping harder above basic. Paths' thresholds that the new Brannoc slowed are reset by phase 5's rule (about 3.5 fights of the vowed deed): Hearthwall 7 → 6, Last Watch 52 → 25 (a tougher Brannoc spends less time low).

**The result** (the sim runner, `--seeds=5`; the gate passes on all 18):

| Tier | Fight: scale, formations that win of 44 |
| --- | --- |
| basic | Pup Warren 10750, 30; Ash Nest 11250, 34; The Pack 10750, 33; Moth Cloud 11250, 34; Hollow Line 11250, 32; Bog Crossing 11250, 32; Sentinel Gate 11750, 35; Cairn Road 11500, 34; Witch Circle 11250, 33 |
| harder | Hounds and Archers 9250, 31; Lurker and Ashlings 9000, 27; Sentinel and Moths 18150, 17; Witch and Pups 8750, 32; Guardian and Witch 14800, 22 |
| elite | The Hunt 9750, 20; Witch Coven 5750, 19; Cairn Watch 12750, 21 |
| boss | Old Mother Ash 7500, 14 |

The run report (54 runs, the simple bot): 83% of runs won (was 46%), the first transformation at a median of day 2, every path transforming in 72–100% of the runs vowed to it (Last Watch was 33%), 4.2 wounds a run, most healed by the next win. **Still to watch:** at 70–80% of formations winning, Brannoc stands in about four in ten of the won basic fights on average (from three in four in Bog Crossing to about one in ten in Ash Nest and Witch Circle; before, none to one in five), and in Guardian and Witch and Cairn Watch hardly ever: those fights are built to reach him. Whether that still feels bad is for the playtest; the next lever would be his kit (more of Hold the Line's DEF, or Hearthguard shielding himself), not his stats.

## Open questions

- Everything marked *proposed* above (Decisions 5–14).
- **Encounter rocks:** hand-placed per encounter (as now), or drawn from a few layouts? (Part 3.)
- **The currency's name** (shards for now).
