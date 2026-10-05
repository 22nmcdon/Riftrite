# Phase 8 part 3: building Act 3, the Shattered Crown

Status: **a build plan for the playtester's approval (2026-10-05). Nothing is built.** It builds `act3-shattered-crown.md` (the design, with its Decisions 1–11) on the frame of `rebuild-phase8-acts.md` (8c-1 and 8c-2, built), the way `rebuild-phase8-act2.md` built Act 2. Numbers are placeholders until the tuning part. Questions are in section 9.

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
  - **Data:** `data/upgrades_enemy.json`, or an `"enemy_upgrades"` block in `camps.json` beside the rift modifiers. Each upgrade is `{id, name, text, mod}`, a `KitMod` like a specialization's.
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
    - What runs as it falls is question CJ.
  - **Islands:** at the start, and again whenever the void changes, the walkable hexes are grouped into islands (a flood fill). `UnitState.island` is marked as water's `on_water` is, at the tick's start and after the units act, for a `UnitCondition` key, `"same_island"` (with the condition's holder). The Spire Chanter's aura, the Wide Unbinder, and the Last-Note Chanter use it.
  - **The board's outer edge** stays as it is: a push stops there and stuns (question CK). Only void hexes drop.
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

- **CJ. What runs when a unit falls into the void:** falling is a death, but does a unit that falls set off its on-fall effects (the Shattered Sentinel's burst, the Last-Note Chanter's Shields, a splitter's halves, Second Dawn or a rise), and do would-fall saves (Last Watch's Undying) catch it? Proposed: no to all. The void swallows it whole, so pushing a splitter or a riser off an edge is a way past it, and no save catches a fall.
- **CK. The board's outer edge:** stays as it is (a push stops there and stuns), so only the void hexes inside the board drop a unit? Proposed: yes; the islands are drawn inside the board's frame.
- **CL. Upgrades' data home:** a file of their own (`data/enemy_upgrades.json`), or a block in `camps.json` beside the rift modifiers? Proposed: a file of their own.
