# Phase 8 part 3: building Act 2, the Glassmere

Status: **a build plan, approved (2026-10-04); section 9's questions answered (Decisions 1–3).** Being built from 8c-3a. It builds `act2-glassmere.md` (the design, with its Decisions 1–7) on the frame of `rebuild-phase8-acts.md` (8c-1 and 8c-2, built). Numbers are placeholders until the tuning part.

## 1. What it builds

Act 2 as content a run reaches after Act 1's boss shop:

- enemy specializations, drawn fresh and shown on the day's fight cards (`enemy-growth.md`, the parts Act 2 uses);
- shallow water and the other new pieces of the fight code;
- the eleven enemies, the eleven day fights and two Hunts, two elites, the Mournwater, and `act2.json`;
- the bots, the tuning, and a playtest build.

Upgrades and the rift learns wait for Act 3 (Decision 4 of `act2-glassmere.md`; Decision 10 of `rebuild-phase8-acts.md`). Every new piece is skipped by a fight that doesn't use it, so Act 1's fights and the bench's fingerprints stay as they are.

## 2. Specializations (8c-3a)

- **Data:** an enemy in `enemies.json` gets `"specializations"`: up to two, each `{id, name, text, mod}`. The `mod` is a `KitMod` on the enemy's kit, the shape upgrades and relics already use; `name` is the word put before the enemy's name ("Gnawing"). `ContentDb` reads and checks them (`EnemyDef.specializations`, `SpecializationDef`), and the validator checks every text the way it checks abilities' (`test_unit_info.gd`).
- **Which are built:** the ones Act 2 uses. That's two each for the Rift Pup, Ashling (Smoldering and Steaming), Cairn Guardian, Bog Lurker, Gloam Witch, the four new faces, and the two new archetypes: 22 in all. The Rift Hound's, Cinder Moth's, Hollow Archer's, and Sentinel's wait on question BT.
- **The draw** (Decision 6): `ActDef.specialized_from_day` (Act 2: 3) and `specialized_share_pct` (50). When a day starts (`RunFlow._start_day`, and so again on each replay after a loss), each of today's fights draws its specialized enemies on a new `RunRandom` stream (what, act, day, attempt, the option's index): exactly half of its enemies, rounded down: Decision 1. Each one gets one of its two specializations. A fight swapped in (Map the Rift) draws its own. `RunState.today_specs` (option index → enemy index → specialization id) holds the draw; save version 8 (a version 7 save loads with none).
- **The fight:** `RunFlow.fight_setup` passes the chosen fight's specializations to `Encounters.setup` as `enemy_mods` (enemy index → mods, applied after `scale_bp`, like heroes' extras). A specialized unit's name is the specialization's word and the enemy's ("Gnawing Rift Pup 2"; `FightNames`).
- **The screens:** the route's fight card names each specialization and how many carry it ("2 Gnawing Rift Pups"). `EnemyPanel` adds the specialization's sentence and numbers line (`UnitInfo`). The bots read them through the fight's setup, as they read everything else.
- **Hunts and endless** draw none for now (Decision 2; endless after Act 3 comes with Act 3).

## 3. Shallow water (8c-3b)

- **Data:** an encounter's `"water"`, hexes like `"rocks"` (`EncounterDef.water`, `FightSetup.water`).
- **The fight** (a new `Water` module in `src/sim/arena/`): the water is a hex set the fight holds and can change (section 4). A unit is **on water** when its center is on a water hex.
  - **Movement:** a unit on water steps half as far each tick (`Movement`), unless its kit `swims` (a trait, `UnitDef.swims`).
  - **The route:** for a walker that doesn't swim, a nav cell on water costs 2x in `NavGrid`, beside crumbled ground's 3x. A route that has to cross still crosses.
  - **Burn:** a Burn tick on a unit on water deals half (`Statuses`; STATUS_DAMAGE noted "in water"), and the Burn lasts as long as anywhere else (Decision 5 of the acts plan).
  - **Logging:** a walking leg slowed by water is noted "in water", so the log says why it was short.
- **Placement:** heroes may start on water (Decision 1). Crumbled ground over water hurts and slows (Decision 2): both rules apply.
- **`on_water`:** a `UnitCondition` key (`"vs"` on event effects and per-hit auras, an aura's `"while": "on_water"`, an event or timed effect's `"holder"`), and a target filter for effects that pick every enemy on water (Undertow).
- **The board:** water hexes are drawn under the units, in placement and the fight, from the fight's water each frame; a unit on water shows a ripple. Placeholder art until phase 7.

## 4. The other new pieces (8c-3c)

| Piece | Who needs it | What it is |
| --- | --- | --- |
| **Flood** | Tidecaller, Silted Warden, the Tide Choir, the Mournwater | A new effect type, since no effect changes the ground: `flood` with a shape: a circle at the target for a time, every pool one hex wider, the board drained to a ring around the caster, or the whole board but rocks. Logged as a new kind, WATER (the hexes and the source), with an audit rule in `test_arena_log.gd` and a board form in `test_every_encounter_plays.gd`. |
| **Summon at the water** | Drowned Bellringer, the Mournwater | A summon placement, `water`: each summon on the water hex nearest a hero, or nowhere if there's no water (logged as dropped). |
| **Rise on water** | the Glass Matron's shards | The built rise passive gains an `"if": "on_water"` and a delay: a unit that falls on water rises after it, as its kit says. |
| **Submerge** | Mire Eel | A trait: on water, it can't be picked as a target (as if Stealthed, the keyword too), except for 2s after each of its attacks. |
| **Pull toward a point** | Coiling Eel (toward the nearest water), Undertow Tidecaller (toward its flood's middle) | A pull's `"toward"`: `water` or `area`, beside the built pull toward the caster. |

Built pieces cover the rest: splitting (`on_fall` and a summon of two shards), the Slinger's lobbed stone (a warned circle) and stepping back (`hop_away`), Mud (a zone with Slow), Stilling (a zone with Silence, which stops mana), the Warden's regeneration (`on_interval` with a `"holder"` condition) and its armor (`damage_reduced_bp` while on water), and the boss's phases (`PhaseDef`, `start_collapse`).

## 5. The content (8c-4a and 8c-4b)

- **`enemies.json`:** the Mire Eel, Reedline Slinger, Tidecaller, Drowned Warden, Drowned Bellringer and Drowned Thrall, Glass Shambler and Glass Shard, the Matron's great Shambler and its rising shard, and the Mournwater. Every ability has its sentence naming each reach, and every enemy a threat line, an archetype, and a placeholder figure (`tools/art/enemy_kit.py`). The Summoner and Splitter archetypes join the archetype list, and Casters first counts Summoners (Decision 7).
- **`encounters.json`:** act 2's eleven day fights and two Hunts (section 8 of the design), the two elites, and the Mournwater, each with its water and rocks.
- **`act2.json`:** Act 1's shape and economy (Decision 13 of the acts plan), `specialized_from_day` 3, no endless.
- **`tuning.json`:** Act 2's crumbled ground is already there; Act 3's comes with Act 3.

## 6. The bots and the tuning (8c-4c)

- **The good bot** places by fitted weights, which know nothing of water: add a feature or two (a hero's slowness to its first target, water between the back line and the enemies), then refit the weights on Act 2's fights as well as Act 1's (`placement_data.gd`, `fit_placement.py`).
- **The targets** (Decision 3 of the acts plan): early in Act 2, a team with its first transformations wins about half its fights; by the boss, a team without an apex is near 20%. Measured with the sim runner (the gate of 30 points between best and worst formation, per encounter) and a transformed and apex sweep over Act 2's fights (`--apexes`, run on act 2's encounters).
- **The apex deeds** are resized for Decision 2 of the acts plan: at least one apex per team before the Act 2 boss (the stand-in sizes of 8b-4c go). Read from the run report's **By act**.
- **The run report** with `--bot=good` over both acts: runs reaching and winning each act, and apexes by act.

## 7. Tests

- Specializations: data read and checked; the draw (fresh per attempt, the same for the same seed and state, the share from day 3, none before), the save, the setup's mods and names, the fight card's text.
- Water: speed on and off water, swimmers, the route's cost, Burn halved and noted, crumbled and water together, a fight without water unchanged (the bench's fingerprints).
- Each piece of section 4 in a small fight (`tests/sim/`), and the WATER log kind's audit rule and board form.
- Every new enemy's text in a small fight (`test_enemy_kits.gd`), every encounter builds and plays (`test_encounters.gd`, `test_every_encounter_plays.gd`), and the chaos fight uses the new pieces (`chaos_fight.gd`).
- A run into Act 2 with the real data (no stand-in), on a seed the good bot wins Act 1.

## 8. Parts

- **8c-3a, specializations:** the frame, the draw, the save, the screens, with the specializations that need no new piece.
- **8c-3b, water:** terrain, speed, the route, Burn, `on_water`, swimmers, the board.
- **8c-3c, the other pieces:** flood (and WATER), summons at water, rising on water, Submerge, pulls toward a point.
- **8c-4a, the enemies:** the eleven, their specializations, texts, and figures.
- **8c-4b, the fights:** the day fights, Hunts, elites, the Mournwater, and `act2.json`.
- **8c-4c, the bots and tuning:** placement features and the refit, the gate, the targets, the apex deeds.
- **8c-4d, docs, HOW-TO-PLAY, screenshots, a playtest build.**

## Built in 8c-3a: specializations (2026-10-04)

- **Data:** `SpecializationDef` (`src/sim/defs/specialization_def.gd`: id, the word, the sentence, a kit mod; `apply` puts the word before the kit's name and sets `UnitDef.specialization`), read from an enemy's `"specializations"` (at most two; `EnemyDef.specializations`); `ContentDb.specializations` (one space of ids), each checked to change something and to leave the kit sound.
- **The first six, as data** (those that need no new piece): Gnawing Pup (its bites add 2 Bleed), Smoldering Ashling (burning ground within 1 hex for 3s where it falls), Bulwark Guardian (a Shield of a fifth of its max HP after it charges), Deep Lurker (Drag pulls 3 hexes), Rot Lurker (a dragged hero takes 6 Poison), Hex Witch (Hush silences two heroes). Burrowing Pup, Avalanche Guardian, and Veil Witch needed pieces (built in 8c-3c); Steaming Ashling needed water (built in 8c-3b). **Flag for the playtester:** Bulwark Guardian's "engages" (from `enemy-growth.md`) isn't in it: a kit mod can't add a trait, and the Shield alone keeps it at the front; say if Engage should come too.
- **The draw:** `ActDef.specialized_from_day` (0: never; Act 1 has none) and `specialized_share_pct` (50). `RunFlow._start_day` draws today's (`Offers.specializations`, on the stream `RunRandom.SPECIALIZE` by act, day, attempt, and option): the share of a fight's enemies, rounded down, chosen among those with any (Decision 1), each given one of its own; none for a Hunt or an endless floor (Decision 2). `RunState.today_specs`; save version 8 (a version 7 save loads with none).
- **The fight:** `RunFlow.chosen_specs()` passes them to `Encounters.setup`'s new `enemy_specs` (enemy index → id), applied after the scaling; an unknown id or another enemy's is refused. The names follow from the kit's ("Gnawing Rift Pup 2", `FightNames`).
- **The screens:** today's fight card has a "Specialized:" line (`RunDayScreen.specs_line`: "2 Gnawing Rift Pups: Its bites make you Bleed, and the Bleed stacks."); `EnemyPanel.show_enemy` shows the kit a unit fights with, so a specialized enemy's name, the specialization's sentence, and its changed abilities.
- **Tests:** `tests/run/test_specializations.gd` (the data, a specialization that changes nothing refused, none before the act's day or in Act 1, half of each fight's enemies from day 3 and each its own enemy's, the same draw for the same seed and a fresh one on a replay, the fight's kits and names, an unknown id refused, the save, the card's line), and a screen test for the card. Mutation checks: drawing without the attempt, and specializing every eligible enemy, each fail a test.

## Built in 8c-3b: shallow water (2026-10-04)

- **Data:** an encounter's `"water"` (`EncounterDef.water`, hexes like rocks; `ContentDb` and `FightSetup.validate` refuse water off the board, on a rock, or listed twice), copied by `Encounters.setup` to `FightSetup.water`. Heroes may be placed on it (Decision 1).
- **The fight** (`Water`, `src/sim/arena/water.gd`; a fight without water never makes one): the water's hexes and, per nav cell, whether its center's hex is water (`HexGrid.hex_at`, a quick nearest-center lookup that agrees with `nearest_hex` everywhere), so "on water" is one read (`CombatSim.on_water`).
  - **Speed:** a walker on water steps half as far (`CombatSim.step_of`, used by every walk in `Movement`) unless it swims (the trait `swims`, `UnitState.swims`) or flies; the leg is noted "in water" (shown in the log line).
  - **The route:** a step onto a water cell costs 2x in `NavGrid` for a walker water slows (`NavGrid.water`, `wading`), beside crumbled ground's 3x, so crumbled water costs both (Decision 2). **A call made while building:** a walker with a clear straight line used to walk it without a route; now a walker water slows plans a route whenever water lies on its straight line (`Water.crosses`, checked as it plans), so it goes round a pool when that's shorter and wades a river it can't go round. Without that, the cost would only matter when something else blocked the way.
  - **Burn:** a tick of a status with the keyword `burning` on a unit on water deals half (`Statuses`; STATUS_DAMAGE noted "in water", shown in the log line), and lasts as long as anywhere else.
  - **`on_water`:** `UnitState.on_water`, marked as each tick starts and again once every unit has acted (`Water.mark`), so conditions read where a unit stood at the last mark. `UnitCondition`'s `"on_water": true` (or `false`) works wherever a condition does: an event's `"vs"`, an event or timed effect's `"holder"`, and an aura's `"while": "state"` (the plan's "while on water" is that form, not a new `while`). **A call made while building:** a flier is never on water.
  - **on_fall's `"holder"`:** an on_fall effect now checks its holder condition where the unit fell (no built kit had one).
- **The Steaming Ashling** (the specialization that waited on water): Cinder Burst only off water and a Steam Burst on water (heroes within 1 hex Slowed 30% for 3s). It needed one kit mod knob: an "on" entry's `"holder"` (`KitMod`), which sets the condition on the slot's event and timed effects ("only while it's not on water" on its numbers line).
- **Moved to 8c-3c:** the target filter that picks every enemy on water (Undertow), with the pull toward a point it goes with.
- **The board:** water hexes drawn on the ground (placeholder blue), from the setup while placing and from the fight's water each frame; a unit on water shows a ripple round its ring (`UnitToken.in_water`).
- **Tests:** `tests/sim/test_water.gd` (the hex lookup, half speed and its note, swimmers and fliers, round a pool but across a river and a swimmer straight through, Burn halved and noted, the condition, the Steaming Ashling both ways, the knob's words, the setup's checks, water from the encounter, a fight without water, crumbled water), a water fight that repeats exactly and replays from its log (`test_determinism.gd`, `test_arena_log.gd`), and the board's water (`test_arena_view.gd`). The bench's fingerprints are unchanged. Mutation checks: no half speed, no route cost, no Burn halving, and no on_fall holder each fail a test.

## Built in 8c-3c: the other pieces (2026-10-04)

In three commits, each skipped by a fight that doesn't use it (the bench's fingerprints are unchanged throughout):

- **8c-3c-1, flood and pulls.** A new effect type, `flood` (a code change: no effect changed the ground), with `"mode"`: `circle` (the hexes whose centers lie within `"radius"` of the ability's target, or of the unit with `"anchor": "self"`, and the hex under it; for `"duration_ms"`, or for good without it), `spread` (every pool a hex wider), `drain` (all the water gone but the hexes within `"radius"` of the unit), or `all` (every hex but the rocks). Floods never cover a rock. A fight without water gets a `Water` when it floods (`CombatSim.has_water` from then). The water is the lasting hexes plus each flood that lasts a while (`Water.Layer`, gone at its tick: `Water.tick`, before the mark). Each change is the new log kind **WATER** (note "floods 6 hexes for 2s", "spreads to 5 more hexes", "drains to 7 hexes", "floods the whole board", or "recedes"; amount: the water hexes now; the flood's source), with its audit rule (`test_arena_log.gd`) and board form (`test_every_encounter_plays.gd`: the board draws the sim's water each frame), and every walker plans again. A pull's `"toward"`: `water` (the nearest water hex's center, stopping on it; no water, no pull) or `area` (an area's own pull, toward its middle; `Displacement.pull_to`). `all_enemies` and `all_allies` take `"only"` (a `UnitCondition`): Undertow's "every hero on water" is `"target": "all_enemies", "only": {"on_water": true}`. The numbers lines say each ("floods a 2-hex circle at the target for 6s", "pulls 1 hex to all enemies on water").
- **8c-3c-2, rising, summons, Submerge.** The rise passive takes `"if"` (a condition the unit must fall under: `{"on_water": true}`) and `"as"` (an enemy's id: the fallen unit stays down and a fresh one of that kit stands where it fell, at `hp_pct` of its own max HP, logged as a SUMMON sourced to the rise; the kit joins the fight's summon kits, `UnitDef.rise_as_ids`). While it's due, the side isn't beaten. Summons take `"placement": "water"`: the free spot nearest the center of the water hex nearest any of the summoner's enemies, or dropped ("no water"). The trait `submerges`: on water a unit is under (`UnitState.submerged`, marked with `on_water`), as if Stealthed (`Statuses.is_stealthed`, the keyword `stealthed`): it can't be picked, and a unit targeting it picks again ("eel is submerged"); it surfaces for 2s after each basic attack (`Water.SURFACE_TICKS`).
- **8c-3c-3, the last three of Act 1's enemies' first specializations:** **Burrowing Pup** (a gambit's late arrival, now for any unit, enemies too, with a new `"arrive_at": "back_line"`: it comes up 3s in at the free spot nearest the heroes' hindmost standing unit, logged as ARRIVE, "Burrow"), **Avalanche Guardian** (a charge's `"carries"`: every enemy in its line, the target too, is knocked the charge's knockback along it, farthest first, before it runs; the kit mod knob `"carries"`), and **Veil Witch** (a kit mod's new `"drops_passives"`: Ward goes, and Veil comes in: every 8s its most hurt ally within 6 hexes is Stealthed for 2s).
- **Tests:** `tests/sim/test_water.gd` (each flood mode, a flood that recedes and one that stays, pulls toward water and an area's middle, `only`, the numbers lines, the new keys refused where they don't belong, rising on water as another kit and staying broken dry, a rise as a kit the fight lacks refused, summons at the water and dropped without it, Submerge until it surfaces to attack), `tests/run/test_specializations.gd` (the three specializations in fights), and a flood fight in the log's source audit. Mutation checks: no recede, no `only`, a spread onto rocks, a rise ignoring its `if`, an eel that never surfaces, a submerged unit still targetable, a charge that doesn't carry, a burrow that comes up where it was placed, and a Ward that isn't dropped each fail a test.
- **Small calls:** an "as" rise keeps no status of its own (refused with one); an enemy's late arrival keeps the gambit's ARRIVE line and its label as the source ("rift_pup · Burrow"); Veil picks the most hurt ally (the witch herself counts), within 6 hexes.

## 9. Questions

- **BV. How many enemies are specialized:** *(Answered: Decision 1.)* each one at a 50% chance (so a fight may come with none or all), or exactly half of them, rounded down, chosen by the draw? Proposed: exactly half, so a fight's difficulty doesn't swing on the draw.
- **BW. Specialized Hunts:** *(Answered: Decision 2.)* proposed none, so a Hunt stays the safe extra fight.
- **BX. Act 2's camp, events, relics, and items:** *(Answered: Decision 3.)* Act 1's, unchanged, for now?

## Decisions

The playtester, 2026-10-04 (approving the plan: "let's start"):

1. **Exactly half of a fight's enemies are specialized, rounded down** (Question BV), chosen by the draw, so a fight's difficulty doesn't swing on it.
2. **Hunts aren't specialized, for now** (Question BW).
3. **Act 2 uses Act 1's camp, events, relics, and items, unchanged, for now** (Question BX).
