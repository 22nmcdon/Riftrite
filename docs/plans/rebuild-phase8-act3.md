# Phase 8 part 3: building Act 3, the Shattered Crown

Status: **a build plan, approved (2026-10-05); section 9's questions CJ–CL answered (Decisions 1–3), CM open.** 8c-5a (enemy growth), 8c-5b (islands), 8c-5c (the other pieces), and 8c-5d (the rift learns) built; 8c-6a next, after Question CM. It builds `act3-shattered-crown.md` (the design, with its Decisions 1–11) on the frame of `rebuild-phase8-acts.md` (8c-1 and 8c-2, built), the way `rebuild-phase8-act2.md` built Act 2. Numbers are placeholders until the tuning part. Questions are in section 9.

## 1. What it builds

Act 3 as content a run reaches after Act 2's boss shop, and endless after it:

- the rest of enemy growth: the four returning enemies' specializations, the 11 upgrades on elites, the higher share of specialized enemies, and the rift learns for the boss's adds;
- islands: the void, falling, and which island a unit stands on;
- the other new fight pieces: bridges that break and reform, the Mirrorwight's copy, the Unbinder, the Cliffmite's shove, the Gulf Angler's hook, and the Dazzling Moth's misses;
- the ten enemies, the eleven day fights and two Hunts, two elites, the Heart of the Rift, `act3.json`, and endless after Act 3;
- the bots, the tuning, and a playtest build.

Every new piece is skipped by a fight that doesn't use it, so Acts 1 and 2's fights and the bench's fingerprints stay as they are.

## 2. Enemy growth (8c-5a)

- **Specializations:** the Rift Hound's, Cinder Moth's, Hollow Archer's, and Rift-Worn Sentinel's, two each from `enemy-growth.md` section 2 (8 in all), and two for each of the six new enemies (12). They use `SpecializationDef` as built.
  - Most are built pieces: burning ground on landing, Engage reaching 2 hexes, Roots on hit, a burst on falling, and a drifting zone (the built `follows`).
  - New pieces:
    - the Gloam Hound's leap back out and second Pounce;
    - the Volley Archer's shot at every hero in a line (a line area from its basic attack);
    - the Dazzling Moth's misses (section 4).
- **The share:** `act3.json`'s `specialized_from_day` 1 and `specialized_share_pct` 75 (Decision 4). The draw is Act 2's, unchanged.
- **Upgrades** (`enemy-growth.md` section 3; Decision 5):
  - **Data:** `data/enemy_upgrades.json` (Decision 3). Each upgrade is `{id, name, text, mod}`, a `KitMod` like a specialization's.
  - **The draw:** each elite draws 1–2 when the day starts (`Offers.enemy_upgrades`, its own `RunRandom` stream: act, day, attempt, option), fresh on each attempt, like specializations. They're saved in `RunState` beside `today_specs`; save version 9.
  - **Who carries them:** only enemies in an elite fight (the leader and its company); the boss and normal enemies carry none.
  - **The screens:** the fight card shows them ("Upgraded:", like "Specialized:"), and so do `EnemyPanel` and the unit's name ("Frenzied Great Cragram").
  - **The upgrades themselves:**
    - Built pieces: Frenzied, Warded, Swift, Thick-Hided, Vengeful, and Anchored's unpushable.
    - New aura stats, each skipped where unused: Watchful (can pick a stealthed unit), Cinder-Skinned (Burn on it halved), Shieldbreaker (damage to Shields, `shield_damage_bp`, shared with the Unbinder), Mark-Shy (Marks on it last half as long), Rift-Touched (mana gained, if no built stat covers it), and Anchored's cap on Roots.
- **Casters first** counts the `mimic` archetype (Decision 7). Supports already count.

## 3. Islands (8c-5b)

- **Data:** an encounter's `"void"`, hexes like `"water"` and `"rocks"` (`EncounterDef.void`, `FightSetup.void`). `ContentDb` and `FightSetup.validate` refuse void off the board, on a rock or water, or listed twice; they also refuse an encounter whose walkable hexes for heroes and enemies aren't joined (a fight that couldn't meet). Heroes and enemies can't be placed on the void.
- **The fight** (a new `Islands` module in `src/sim/arena/`, made only when an encounter has void):
  - **The route:** a nav cell whose center is on a void hex is blocked for walkers, like a rock's cells but without blocking shots or areas. Fliers ignore it. `CombatSim.on_void(point)` is the one read (per nav cell, as water's is).
  - **Landing:** spots picked to land on (leaps, hops, summons, a flier dropped clear) stay off the void: `CombatSim.fits` already refuses crumbled ground for them and refuses the void too.
  - **Falling:** after a push (`Displacement.push`), a pull, a charge's carry, or a hook ends, a unit that doesn't fly and whose center is over the void falls. It's logged as a new kind, **FELL**: who fell, where, and the source of the push, with an audit rule and a board form. It's removed as a death.
    - A hero who falls counts as fallen: down at the fight's end, so a wound (Decision 17 of the acts plan).
    - An enemy that falls is a kill for whoever's push, pull, or charge caused it: `on_kill` is raised for them, and the FELL entry carries the ability (Decision 1).
    - Nothing runs as it falls: no on-fall effects, no rise, no would-fall save (Decision 1).
  - **Islands:** at the start, and again whenever the void changes, the walkable hexes are grouped into islands (a flood fill). `UnitState.island` is marked as water's `on_water` is, at the tick's start and after the units act, for a `UnitCondition` key, `"same_island"` (with the condition's holder). The Spire Chanter's aura, the Wide Unbinder, and the Last-Note Chanter use it.
  - **The board's outer edge** stays as it is: a push stops there and stuns (Decision 2). Only void hexes drop.
- **The board:** the void is drawn as open sky between the islands, and bridges are the walkable hexes between them. A unit that falls shows a fall, then is gone. Placeholder art until phase 7.

## 4. The other new pieces (8c-5c)

| Piece | Who needs it | What it is |
| --- | --- | --- |
| **Sever** | the Heart of the Rift | A new effect type, since nothing turns ground into void: `sever` turns the named hexes (a bridge, marked in the encounter as `"bridges"`, each a list of hexes) into void after a warning, and back after a time. A unit on them when they break falls. It's logged as a new kind, VOID (the hexes, the source, "breaks" or "reforms"), with an audit rule and a board form. The islands are worked out again, and every walker plans its way again. |
| **Copy a signature** | the Mirrorwight, the Mirror Queen | A new passive kind, `copy`: it reads the log for the first hero signature cast anywhere (Decision 8) whose effects are only areas, damage, heals, Shields, statuses, and cleanses (Decision 18 of the acts plan). It keeps that ability as the unit's own signature, with its sides turned: heal and Shield targets read as its allies, damage and status targets as its enemies. The copy is cast with the unit's own stats and mana bar. It's logged (COPIED: what, from whom), and the board names what it copied. The Greedy and Twinned specializations are knobs on it (`replace`, `twice_bp`); the Queen's `share` gives each copy to her court. New code: nothing copies an ability today. |
| **Hook to solid ground** | the Gulf Angler | A pull's `"to"`: `"beside"`, which carries the target all the way to a free spot beside the puller, across the void, and never leaves it over the void (Decision 2). The free spot is the built `free_spot_near`. |
| **Shove from a crowd** | the Cliffmite | An event effect's `"when_attackers"`: N (the effect runs only when at least N units of its side are attacking the same target), and a push `"toward": "edge"` (the nearest void or the board's edge). |
| **Charge and knock back** | the Cragram | A charge's hit with a knockback on the first hero (built pieces: a charge, then an on-hit knockback), and Thundering's carry is the built `carries`. |
| **Shields first** | the Unbinder, Shieldbreaker | The aura stat `shield_damage_bp`: a hit's damage to a Shield is raised by it, before what's left reaches HP. The timed cleanse of allies is built (cleanse with `statuses`). |
| **Misses** | the Dazzling Moth | An aura stat on a zone's statuses, `miss_bp`: a unit's attacks miss that share of the time (rolled on the fight's seeded RNG), logged as MISSED (or the built DODGED, noted "missed"). |
| **Leap back out** | the Gloam Hound | A timed effect after its Pounce: it hops back to where it came from, and its Pounce's cooldown starts again (the built `hop` and `once` with a delay). |

Built pieces cover the rest: the Spire Chanter's aura (`damage_reduced_bp` with `"vs"` on the island key), the Last-Note Chanter's Shields (`on_fall`), the Cragherd's stampede (a timed signature on every Cragram), the Heart's Ward while its host stands (an aura while allies stand), its phases (`PhaseDef`, `start_collapse`), and the Unmaking's push (a circle around it with a knockback, its island wide enough that the push never reaches an edge: Decision 6).

## 5. The rift learns (8c-5d)

- **What it reads** (`enemy-growth.md` section 5; Decisions 9 and 10): after each fight, `RunFlow.record` adds a small summary of the fight to `RunState`, keeping the last 3. It counts:
  - keywords applied (Roots, Marks, Burn, Stealth);
  - healing and lifesteal, and Shields;
  - mana spent on signatures;
  - where the heroes stood (bunched, and how far forward).
  
  It's read from the fight's result and log the way the run's tallies are, so it never changes a fight.
- **What it does:** when the Heart of the Rift's day starts, it picks the run's top 1–2 habits from the summary. For the boss's adds, it swaps up to half of their drawn specializations and upgrades for the ones `enemy-growth.md`'s table names against those habits. It only swaps specializations and upgrades, never rift modifiers (Decision 9).
  - It's deterministic: the same seed, team, and fights give the same picks.
  - It's saved with the day's draw.
- **The screens:** the boss's fight card shows each learned pick and the habit it answers ("Learned: Anchored, against your Roots").
- **Endless:** the Heart on every 10th floor learns again, from that floor's last 3 fights.

## 6. The content (8c-6a and 8c-6b)

- **`enemies.json`:**
  - the Cliffmite, Cragram, Gulf Angler, Spire Chanter, Mirrorwight, and Unbinder;
  - the elites' leaders and companies (the Great Cragram, the Mirror Queen);
  - the Heart of the Rift and its host's kits.
  
  Every ability has its sentence naming each reach, and every enemy a threat line, an archetype, and a placeholder figure (`tools/art/enemy_kit.py`). The archetypes `mimic` and `warden_breaker` join the list.
- **`encounters.json`:** act 3's eleven day fights and two Hunts (section 8 of the design), the two elites, and the Heart of the Rift, each with its void, bridges, and rocks.
- **`act3.json`:** Act 1's shape and economy (Decision 13 of the acts plan), `specialized_from_day` 1, `specialized_share_pct` 75, and an `endless` block that isn't the testing one.
  - Endless after Act 3 draws floors from Act 3's fights from day 4, an elite every 5th floor, and the Heart every 10th (Decision 1 of the endless plan, moved up an act).
  - Act 1's testing endless stays as it is (Decision 15 of the acts plan).
- **`tuning.json`:** `collapse_by_act` gains Act 3: base 25, growth 30, accel 6 (Decision 14 of the acts plan).
- **The run:** Act 2's boss shop now leads on to Act 3, and Act 3's boss shop to the endless choice. The records keep Act 3's endless apart from Act 1's testing one (built).

## 7. The bots and the tuning (8c-6c)

- **The good bot** learns the void: two features, the heroes' distance to the nearest edge behind them, and how many enemies can push or pull (chargers, disruptors, the Cliffmite's crowd). A `void` context gets its own weight set, fitted on Act 3's fights alone, as water's was (`fit_placement.py --water` becomes a named context). The bots also read upgrades and the rift learns' picks from the fight's setup, as they read specializations.
- **The targets** (Decision 3 of the acts plan; section 2a): a team with only its first transformations wins Act 3's fights almost never, and a team with its apexes about half. They're measured as Act 2's were: the stepping gate on every encounter, a transformed and apex sweep (`--apexes --by-encounter --act=3`), and then the good bot over all three acts.
- **The run report** with `--bot=good` over three acts: By act, Apex vows, and the endless report after Act 3 (`--endless` now goes deeper after Act 3 without a testing run).

## 8. Parts

- **8c-5a, enemy growth:** the 20 specializations' data, the 11 upgrades, the draw on elites, the share, Casters first, save version 9, and the screens.
- **8c-5b, islands:** void, the route, landing, falling and FELL, kill credit, islands and `same_island`, and the board.
- **8c-5c, the other pieces:** sever and VOID, copy and COPIED, the hook, the shove, shields first, misses, and leaping back out.
- **8c-5d, the rift learns:** the summary, the picks, the save, and the fight card.
- **8c-6a, the enemies:** the ten and the bosses' kits, their specializations, texts, and figures.
- **8c-6b, the fights:** the day fights, Hunts, elites, the Heart, `act3.json`, endless after Act 3, and `tuning.json`.
- **8c-6c, the bots and the tuning.**
- **8c-6d, docs, HOW-TO-PLAY, screenshots, and a playtest build.**

Each part is tested as Act 2's were: every piece in a small fight (`tests/sim/`), each new log kind's audit rule and board form, every new enemy's text in a small fight and every encounter played on the screen, the chaos fight using the new pieces, the save across versions, and a run through all three acts with the real data. Mutation checks on each new rule.

## 9. Questions

- **CJ. What runs when a unit falls into the void:** *(Answered: Decision 1.)* falling is a death, but does a unit that falls set off its on-fall effects (the Shattered Sentinel's burst, the Last-Note Chanter's Shields, a splitter's halves, Second Dawn or a rise), and do would-fall saves (Last Watch's Undying) catch it? Proposed: no to all. The void swallows it whole, so pushing a splitter or a riser off an edge is a way past it, and no save catches a fall.
- **CK. The board's outer edge:** *(Answered: Decision 2.)* stays as it is (a push stops there and stuns), so only the void hexes inside the board drop a unit? Proposed: yes; the islands are drawn inside the board's frame.
- **CL. Upgrades' data home:** *(Answered: Decision 3.)* a file of their own (`data/enemy_upgrades.json`), or a block in `camps.json` beside the rift modifiers? Proposed: a file of their own.
- **CM. What answers healing in Act 3** (raised building 8c-5d): `enemy-growth.md` answers healing and lifesteal with Blight (a rift modifier, ruled out by Decision 9 of the design), the Rot Lurker, and the Gnawing Pup, and neither sits in Act 3's roster, so the Heart's adds can never answer a healing team: the rift passes over its top habit for the next. Proposed: a twelfth enemy upgrade, **Festering** (its hits cut the healing the hero it hits takes by 30% for 3s; a status with the built `healing_taken_bp`), named against healing, built with 8c-6a's enemies. Or leave healing unanswered in Act 3.

## Decisions

The playtester, 2026-10-05 (approving the plan: "agreed on all three, let's start 8c-5a"):

1. **Nothing runs when a unit falls into the void** (Question CJ): no on-fall effects (bursts, Shields, a splitter's halves), no rise (Second Dawn, a rise passive), and no would-fall save (Undying) catches it. Pushing a splitter or a riser off an edge is a way past it.
2. **The board's outer edge stays a wall** (Question CK): a push stops there and stuns; only void hexes inside the board drop a unit.
3. **Enemy upgrades have their own file, `data/enemy_upgrades.json`** (Question CL).


## Built in 8c-5a: enemy growth (2026-10-05)

- **Five aura stats** (`AuraDef`, all adding from 0, each skipped by a unit without it, so no built fight changed and the bench's fingerprints are the same):
  - `shield_damage_bp` (Shieldbreaker, and the Unbinder later): the holder's hits cost a Shield that much more (5000: +50%), and whatever the Shield doesn't soak hits HP at full strength (`EffectRunner.deal_hit`, through the built `apply_damage_vs_shield`).
  - `sees_stealth` (Watchful): above 0, the holder can pick a Stealthed or Submerged unit and doesn't drop one it has (`CombatSim.targetable_enemies_of`, `_act`).
  - `burn_taken_bp` (Cinder-Skinned): a `burning` tick on the holder changes by it (-5000: half), noted "cinder-skinned" beside "in water" (`Statuses`).
  - `marked_time_bp` (Mark-Shy): a timed Mark on the holder lasts that much longer or shorter (-5000: half); `root_cap_ms` (Anchored): a Root on it lasts at most that long (`Statuses.apply`, `_taken_duration`; at least a tick).
- **Engage reaching farther** (the Warden Sentinel): a kit mod's `"engage": {"reach_add": N}` (hexes, up to 3; `UnitDef.engage_reach_add`), read by `Engage` for that engager only; the numbers line says "holds foes within N hexes".
- **The returning enemies' specializations** (five of eight, as data): Ashback Hound (burning ground within 1 hex for 3s where its Pounce lands), Pinning Archer (its shots Root for 0.5s), Volley Archer (a line of 5 hexes toward its target from each shot: every hero in it takes half its ATK), Warden Sentinel (Engage within 2 hexes), Shattered Sentinel (heroes within 2 hexes Slowed for 3s as it falls). **Moved to 8c-5c**, each waiting on a piece: Gloam Hound (leaping back out), Drifting Moth (Ember Dust drifting toward the nearest hero: the built `follows` follows the biggest group, so it needs a small knob), and Dazzling Moth (misses). The six new enemies' twelve come with them in 8c-6a.
- **Upgrades** (`EnemyUpgradeDef`, `src/sim/defs/enemy_upgrade_def.gd`; `data/enemy_upgrades.json`, Decision 3; `ContentDb.enemy_upgrades`): id, the word, the sentence, a kit mod; `apply` puts the word before the name and adds the id to `UnitDef.upgrades`; `changes(kit)` is the mod's `affects`. `ContentDb` checks each changes something and leaves every enemy kit it changes sound. The eleven: Frenzied (+30 ATSP below half HP), Warded (a Shield of 15% of max HP as the fight starts), Swift (+1 speed), Rift-Touched (a mana bar a fifth smaller, so 25% faster), Thick-Hided (+20% DEF), Vengeful (as it falls, allies within 2 hexes gain Vengeance: +20% ATK for 4s, a new boost status), Anchored (unpushable, Roots at most 1s), Watchful, Cinder-Skinned, Shieldbreaker, Mark-Shy.
- **The draw:** an act's `"elite_upgrades": [fewest, most]` (`ActDef.elite_upgrades_min`, `_max`; none in Acts 1 and 2, so their runs are unchanged; `act3.json` gets `[1, 2]` in 8c-6b). As the day starts, each elite option draws that many different upgrades among those that change at least one of its enemies (`Offers.enemy_upgrades`, on the stream `RunRandom.UPGRADE` by act, day, attempt, and option), fresh on each attempt; `RunState.today_upgrades`, save version 9 (a version 8 save loads with none). **Calls made while building:** the drawn upgrades are the fight's, and every enemy in it carries those that change it (`RunFlow.chosen_upgrades`), so a Gloam Totem with no mana bar isn't Rift-Touched; none on endless floors, as specializations; summons carry none.
- **The fight:** `Encounters.setup`'s new `enemy_upgrades` (enemy index → up to two ids), applied after the specialization ("Warded Frenzied Gloam Witch"); an unknown id, the same one twice, or three are refused.
- **The screens:** an elite's fight card has an "Upgraded:" line (`RunDayScreen.upgrades_line`: "Frenzied: It attacks faster once it's below half its HP."); `EnemyPanel` shows the upgraded kit, its name, and each upgrade's sentence.
- **Casters first** counts the `mimic` archetype (Decision 7 of the design); the archetypes `mimic` and `warden_breaker` join `EnemyDef`'s list for 8c-6a.
- **Tests:** `tests/sim/test_enemy_growth_pieces.gd` (the eleven as data, Shieldbreaker on a Shield and past it, Watchful, Cinder-Skinned, Mark-Shy and Anchored with its unpushable, Frenzied, Warded, and Vengeful, Engage from 2 hexes, and the five specializations in small fights), `tests/run/test_enemy_upgrades.gd` (none in the built acts, only elites with 1–2 different ones that change an enemy, the same draw for a seed and a fresh one on a replay, the fight's kits and names, each enemy only those that change it, setup's refusals, the save, the act's field, the card's line), and a screen test for the card and the panel. Mutation checks: no Shield bonus, Watchful blind, no Burn halving, no Mark or Root change, no farther Engage, upgrades on every fight, every enemy carrying every upgrade, no draw, and a duplicate allowed each fail a test.

## Built in 8c-5b: islands (2026-10-05)

- **Data:** an encounter's `"void"` (`EncounterDef.void_hexes`, hexes like water's; `void` is a GDScript word, so the field isn't), copied by `Encounters.setup` to `FightSetup.void_hexes`. `ContentDb` and `FightSetup.validate` refuse void off the board, on a rock or water, or listed twice, a hero placed on it, an enemy on it, and an enemy on an island no hex of the heroes' rows is on (`Islands.problems`: a fight that couldn't meet). **A call made while building:** islands are joined round rocks, never through them (a rock's hex takes the island of a neighbor), since a walker can't cross a rock either; an Act 1 encounter with rocks on its middle row showed it.
- **The fight** (`Islands`, `src/sim/arena/islands.gd`; a fight without void never makes one, and the bench's fingerprints are unchanged):
  - **Over the void:** a point is over it when its nav cell's center is on a void hex (`CombatSim.on_void`, one read).
  - **Walkers:** a void cell is blocked in a walker's route (`NavGrid.void_cells`, `void_blocks`, set by `nav_for` for a unit that doesn't fly), a step onto it doesn't fit (`fits_ground`), and a walker whose straight line crosses it plans a route (`Islands.crosses`, in `Movement._plan` and `_plan_escape`). A target across a gap with no bridge is walled off (the built `walled_off`), so a walker picks again. Fliers ignore all of it.
  - **Landing:** `CombatSim.fits` refuses the void, so leaps, summons, rises, a flier dropped clear, and every free spot stay off it. **Calls made while building:** a charge's runner stops at the void's edge (CHARGE noted "stopped at the void's edge", and it reaches no one), and a hop lands short of it (HOP noted "cut short"), using `Islands.solid_until` along the line; a charger never falls by its own run.
  - **Falling:** at the end of a push (`Displacement.push`: knockbacks, pulls, a charge's carry and knockback), a unit that doesn't fly with its center over the void falls (`Islands.check_fall`): a new log kind, **FELL** (target, where, the push's source; "X falls into the void at (x, y) (moved by Y)"), with its audit rule and board form ("Falls" where it went over, then its ghost). It isn't Stunned, acts no more that tick (`UnitState.fell`), and goes in the deaths step with nothing catching it or following (Decision 1): no Undying, no would-fall save, no on_fall effects, no rise (its DEATH is noted "fell into the void"). Others still hear it fall (an ally falling, an enemy falling), and it's a kill for whoever moved it: the push's unit becomes its last attacker, with the ability (on_kill, kill deeds; Decision 1 of the design). A hero who falls is down at the fight's end, so a wound.
  - **Islands:** the hexes that aren't void, joined into groups by a flood fill (`Islands.groups`). `UnitState.island` is marked as the tick starts and again once every unit has acted (`Islands.mark`), like water's `on_water`. The start-of-tick mark matters once the void can change in a fight (8c-5c's sever); until then the second mark covers it.
- **The condition:** `UnitCondition`'s `"same_island": true` holds for a unit on the island its holder stands on ("on its island"). `holds` takes the holder (the aura's or event effect's unit, the attacker for a per-hit `vs`, the caster for `only`, the unit for targeting); without one it never holds, and in a fight without void every unit is on one island.
- **The board:** void hexes are drawn as the rift's sky (placeholder), with a lip round them and no ground, zone, or hex line, from the setup while placing and from the fight's islands each frame (`ArenaView.void_hexes`).
- **Tests:** `tests/sim/test_islands.gd` (the islands with and without a bridge and round rocks, the setup's checks and the content's, a walker going over the bridge and never over the void, a flier crossing, spots to land on, a fall sourced to its push and a kill with nothing else run, a fallen unit acting no more, a hero who falls down at the end, a flier never pushed off, a charge and a hop stopping short, the islands and the condition, a fight without void making none), a void fight in the log's audit and replay (`test_arena_log.gd`) and repeating exactly (`test_determinism.gd`), FELL's board form (`test_every_encounter_plays.gd`), and the board's void (`test_arena_view.gd`). Mutation checks: landing on the void, walking onto it, routes through it, a straight line across it, no fall, a fall caught or followed by a rise, no kill credit, a charge or hop over the edge, the condition ignoring the island, enemies on an island the heroes can't reach, and a fallen unit still acting each fail a test.

## Built in 8c-5c: the other pieces (2026-10-05)

In three commits, each skipped by a fight that doesn't use it (the bench's fingerprints are unchanged throughout):

- **8c-5c-1, sever, the hook, the shove.**
  - **Bridges:** an encounter's `"bridges"` (`EncounterDef.bridges`, `FightSetup.bridges`: a list of `{"hexes": [...]}`), checked by `Islands.problems`: on the board, never on a rock, water, or the void, and each hex in one bridge.
  - **Sever** (a new effect type, a code change: nothing turned ground into void; `{"type": "sever", "warning_ms": 3000, "duration_ms": 10000}`, no target): it takes the fight's next bridge in turn that isn't breaking (`Islands.next_bridge`; **a call made while building:** in turn rather than at random, so a player can read which comes next), warns it (the new log kind **VOID**, "warns bridge 2", its end_tick when it breaks), breaks it at the warning's end ("breaks bridge 2": its hexes join the void, the islands are worked out again, every walker plans again, and every unit over it that doesn't fly falls, sourced to the sever), and brings it back after its time ("reforms bridge 2"). With every bridge breaking, or none, it says so ("finds every bridge already breaking", "finds no bridge to break"). A fight with bridges and no void gets its Islands at the first sever. `Islands.tick` runs at the tick's start, before the mark. VOID has its audit rule and board form: a warned bridge is tinted red until it breaks (`ArenaView.warned_bridges`, from `Islands.warned_hexes`), then drawn as sky, then ground again.
  - **The hook:** a pull's `"to": "beside"` (no `"hexes"`): the target is carried to the free spot nearest the side of the unit it comes from (`Displacement.hook`, the built `free_spot_near`, so never over the void), over the void and anything else; logged as PUSH "hooked" (or "hooked, no room"). The unpushable charm resists it (`Displacement._resisted`, shared with pushes).
  - **The shove:** a knockback's `"toward": "edge"` (straight toward the nearest point of the board's edge or the nearest void hex's center, from the target; `Displacement.nearest_edge`, `shove_to_edge`; PUSH noted "knocked back toward the edge", so on_knockback still hears it) and `"distance_bp"` (a share of its hexes: the Cliffmite's half a hex); and any effect's `"when_attackers"`: it lands only while at least that many standing units of its side (itself among them) have its target as theirs (`EffectRunner.attackers_on`, checked in `land`).
  - **The numbers lines:** "shoves 50% of 1 hex toward the nearest edge (with 3 of its side on the target)", "hooks the target all the way to beside it", "the next bridge breaks after 3s, for 10s".
  - **Tests** (`tests/sim/test_islands.gd`): a bridge warned, broken with the hero on it falling, and part of the void; bridges in turn, a third sever finding both breaking, and reforming; a sever with no bridges, and one that makes the islands; the bridges' checks; the hook across the void (and resisted); a crowd of three shoving toward the void behind the hero, half a hex, and two not; the new keys refused where they don't belong; a sever fight in the log's audit. Mutation checks: no fall when a bridge breaks, the first bridge every time, two severs on one bridge, no reform, no sever tick, no crowd check, a shove away from the unit, the full distance, an unpushable unit hooked, a hook as a plain pull, and unchecked bridges each fail a test.
- **8c-5c-2, misses, drifting dust, leaping back out, and the three specializations held back in 8c-5a.**
  - **Misses:** the aura stat `miss_bp` (adding from 0): its holder's basic attack hits miss that share of the time, rolled on the fight's seeded RNG only when it's above 0 (`EffectRunner.deal_hit`), logged as the built DODGED noted "missed" ("... misses the hero (dazzled)"; the board's "Miss"). A signature's hits never miss. The status `ember_blind` ("Ember-Blind": 30% for 3s) carries it.
  - **Drifting:** an area's `"follows": "nearest"`: a zone moves toward its caster's enemy nearest its middle before each pulse (`Areas._nearest_enemy`), as `"largest_group"` moves toward the biggest group.
  - **Leaping back out:** an event effect's `"delay_ms"` (it runs that long after its event, if its unit still stands: `Passives.Delayed`, `CombatSim.delayed`, `Passives.run_delayed`, before the timed passives); a leap's `"to": "start"` (on "self", no `max_hexes`; to the free spot nearest where the unit joined the fight, `UnitState.start_pos`, logged as LEAP noted "back to where it started"; a passive may have it, unlike other leaps); and an extra signature trigger `{"kind": "every", "every_ms": N}` (`also_fires`; a fire every N from the fight's start but not at it, noted "again"; `AbilityState.every_ticks`).
  - **The specializations:** the **Gloam Hound** (Pounce again every 8s; 3s after each Pounce it leaps back to where it started), the **Drifting Moth** (its Ember Dust adds a 2s zone of 1 hex that drifts toward the nearest hero, a stack of Burn each half second; **a call made while building:** the dust that lands stays as it was, and the drift is a second, smaller cloud, since a warned area can't move), and the **Dazzling Moth** (heroes caught in its Ember Dust are Ember-Blind). With these the returning four have all eight.
  - **Words:** "Every 8s" (a trigger), ", 3s later" on a passive's trigger, "leaps back to where it started", "+30% of its attacks missing".
  - **Tests** (`tests/sim/test_enemy_growth_pieces.gd`): misses about 30% of the time, only on basic attacks, and none once Ember-Blind is gone; the moths' dust drifting and dazzling; a zone following the hero nearest it rather than the biggest group; the Gloam Hound's Pounces at 0 and 8s and its leaps back 3s after each; a delayed effect that waits and doesn't run for a fallen unit; the new words and the keys refused where they don't belong. Mutation checks: no misses, misses on every hit, no drift or the biggest group instead, no "every", no delay, no delayed run, and a leap back to where it stands each fail a test (a delayed effect for a fallen unit is caught twice, so dropping one check is not).
- **8c-5c-3, copying a signature.**
  - **The copy passive** (a new passive kind, `copy`, a code change: nothing copied an ability; `Copies`): Events hands each hero's signature fire (its kit's signature, not an echo or a copy) to `Copies.saw`. A standing copier of the other side that has no copy yet takes it if it's copyable: its effects, and those of its areas, are only damage, heals, Shields, statuses, and cleanses (so a leap, a knockback, or a summon can't be copied, and a copier waits for one that can). The copy becomes its signature, "Blast (copied from maren)", on the copier's own trigger and mana bar (its mana left as it was) and cast with its stats; targeting and areas count sides from the copier, so a copied heal mends its allies and a copied blast hits the heroes. A copier needs a mana signature of its own (`UnitDef.problems`), cast until it copies. A fight without a copier never reaches it (`CombatSim.copiers`).
  - **The knobs:** `"replace": true` takes each new signature it sees (Greedy; never the same one again), `"twice_pct"` casts the copy twice, each at that share, the second half a second later (Twinned; an echo, `Copies.TWIN_TICKS`), and `"share": true` gives each copy the Queen takes to every other standing copier of her side, whatever they held (her court).
  - **The log:** the new kind **COPIED** (source: the copier and its passive; target: the hero; note: the signature's name; "shared" for the court's): "... copies maren's Blast (shared)". Its audit rule and board form ("Copies Blast" over the copier) are in, and the log's audit fights a Queen and her court. The numbers line: "Copies each new hero signature it sees; casts it twice, each at 60%; its court gets each copy too".
  - **Tests** (`tests/sim/test_copies.gd`): the first copyable signature copied (a Pounce passed over), named, on the copier's bar, and cast back at the heroes; a copied heal going to the copier's ally; Greedy against not; Twinned's two hits at 60%, half a second apart; the Queen's court; a copier with no mana signature refused and a fight without one copying nothing; the words, and an area that knocks back not copyable; the audit fight. Mutation checks: no copy, the sides not turned, the hero's trigger kept, Greedy ignored, every copier replacing, a second cast of the same, no twin or a full-strength twin, no court, the court taking from the Queen's side, and an area's nested effects unchecked each fail a test. Events' check that the fire is a hero's is caught by `Copies.saw`'s side check, so dropping one of the two is not.

## Built in 8c-5d: the rift learns (2026-10-05)

A run piece (`src/run/`): it reads fights after they're fought and changes no fight but the boss's, through the specializations and upgrades it picks. No sim file changed.

- **The data** (`data/rift_learns.json`, `RiftLearnsDef`, `RunContent.learns`): the fights it reads (3), `second_at_pct` (100), and `enemy-growth.md`'s ten habits, each with a measure, `per_fight` (how much of the measure a fight must hold to be a habit; placeholders until 8c-6c), the phrase the card uses ("your Roots"), and the upgrades and specializations that answer it (the table's, without the rift modifiers Blight and Thornskin: Decision 9 of the design). The ids are checked against `enemy_upgrades.json` and the enemies' specializations, and an act with `"rift_learns": true` (`ActDef.rift_learns`) needs the file.
- **What a fight counts** (`RiftLearns.summary`, kept on its `RunState.Fought` as `habits` by `RunFlow.record`, won or lost, Hunts too): the heroes' (and their relics') applications of a Rooted, Marked, Burning, or Stealthed status, one each; HP they healed, lifesteal too; Shield they gave; their signature fires; and from the formation, heroes on their back row, heroes on their front row or past it, and pairs of heroes side by side.
- **The habits** (`RiftLearns.scores`, `habits`): each habit's measure over the last 3 fights against `per_fight` that many times (100% at exactly per_fight a fight). **A call made while building:** the rift answers the top-scoring habit that something among the adds can answer (a habit with no answer there is passed over for the next), and the next such only at 100% or more; ties go to the data's order.
- **The picks** (`RiftLearns.picks`, on the new LEARN stream, fresh on each attempt; `RunState.today_learned`): on a boss day of an act with rift_learns, and its endless boss floors. **Calls made while building:**
  - **The adds are every enemy of the boss fight but the first** (the boss, which carries nothing: Decision 5 of the design).
  - **Up to half of them, rounded down, each learn one answer**, the habits taking turns (one habit takes every turn): an upgrade on any add it changes, or a specialization only on its own enemy. A turn leaves the adds a later habit's turn needs while it has others, so a bunched team's Drifting Moth isn't lost to an Anchored on the only moth.
  - **A learned add carries that alone:** it replaces the specialization the add drew (the "swap" of `enemy-growth.md`), so `today_specs` holds a learned specialization in its place and "" for an add that learned an upgrade; `RunFlow.chosen_upgrades` adds the learned upgrade to that add.
- **The fight card** (`RunDayScreen.learned_line`): "Learned: Anchored Rift Hound, against your Roots: It can't be knocked back or pulled, ..." one line each, in the rift's color; a learned specialization isn't named again under "Specialized:". The enemy panel names them like any upgrade or specialization.
- **Save version 10:** each fight's `habits` and `today_learned`; a version 9 save loads with none.
- **No built act learns yet;** Act 3 (8c-6b) turns it on. With Act 3's roster as drafted, nothing among the adds answers **healing** (its answers, Rot Lurker and Gnawing Pup, sit Act 3 out), so a healing team's top habit is passed over: Question CM.
- **Tests** (`tests/run/test_rift_learns.gd`, on stand-in acts whose Act 2 learns, with a stand-in boss fight of four adds that have specializations): a fight's summary (the heroes' doing only, a relic's too, each application once, the rows and pairs) and each fight keeping it; scores from only the last 3 fights; the top habit and a strong second, a tie, a habit passed over, none; two adds learning in turn, a specialization replacing what was drawn, an upgrade alone; one habit taking both turns on two adds; a turn leaving the add a later one needs; the fight's kits; no learning on other days, before any habit, or in an act without it; repeating and fresh on a replay; an endless boss floor; the save across versions; the data's checks; and the card's line. `test_run_screens.gd` shows it on the card. Mutation checks: counting enemies' doing, an enemy relic's, stacks for applications, no lifesteal, every fire, the wrong rows, every pair, every fight read, any second, unanswerable habits, the tie the other way, the boss as an add, an upgrade or a specialization on any add, no act or tier check, every add learning, one habit every turn, no add left for a later habit, an add learning twice, the same picks on a replay, no swap, no summary kept, no learned upgrade carried, the save dropping habits, and the data's checks each fail a test.
