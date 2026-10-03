# Phase 8 part 3: Acts 2 and 3

Status: **the run's shape is agreed (Decisions 1–18); 8c-1 and 8c-2, the frame and the report by act, are built (2026-10-03).** Each act's enemies, elites, and boss are drafted with the playtester next, as the heroes were. The playtester chose Acts 2 and 3 as phase 8's next step (2026-10-03), ahead of enemy growth, the heroes' tuning, and more heroes. Numbers are placeholders.

## 1. What it builds

A run of three acts: Act 1 as built, then Act 2 and Act 3, each with its own days, enemies, encounters, elites, and boss, and endless after the Act 3 boss, where the design puts it (`endless.md`). The work splits in two:

- **The frame** (section 3): a run that moves from one act to the next. The plans settle most of it, and none of it needs new enemies to build and test (a test act can reuse Act 1's fights).
- **The content** (section 4): two new rosters, their encounters, elites, and bosses. The plans say almost nothing about it, so it waits on section 7.

## 2. What the plans already say

- **Enemies** (`rebuild-enemies.md`, section 2): "the same archetypes carry over to later acts with new faces" (Swarm, Flanker, Caster, Ranged, Anchor, Charger, Disruptor, Support). Harder means new problems, not more HP; stats grow only a little.
- **Enemy growth** (`enemy-growth.md`, section 1): about half of an Act 2 fight's enemies are specialized, most of an Act 3 fight's. New faces each need their own 2 specializations (its open question).
- **Apexes** (`apexes.md`; `rebuild-phase8-apexes.md`, Decisions 7 and 8): the apex vow opens **after the Act 1 boss**, and the apex lands **after the Act 2 boss** on an average run. Today it opens on Go deeper, with stand-in deed sizes landing it around floor 3–4.
- **Endless** (`endless.md`): after the Act 3 boss you choose to end the run or go deeper; it unlocks after beating Act 3 the first time. Today it comes after Act 1, on Act 1's fights.
- **Pacing** (`rebuild-run.md`, section 9): more upgrade picks in Acts 2 and 3.
- **Already built for more acts:** `RunState.act`; every offer's stream is keyed by the act (`RunRandom`); `ActDef.act`; `EncounterDef.act`; `tuning.json`'s `collapse_by_act` has Act 2's crumbled ground (base 20, growth 20, accel 4; Act 3 isn't set); the Magpie's "at most twice per act"; boss relics after every boss (then legendaries once all are held).

## 2a. The shape of a run (the playtester's skeleton, 2026-10-03; Decisions 1–10)

| | Act 1 (built) | Act 2: the Glassmere | Act 3: the Shattered Crown |
| --- | --- | --- | --- |
| **Days** | 7 | 7 | 7 |
| **Heroes** | Base, then the first transformations | The apex vow opens; at least one apex per team lands before the boss | Apexes all act |
| **Difficulty** | A base team wins about 50% | Early, a first-transform team wins about 50%; by the boss, near 20% | A first-transform team wins almost never; an apex team about 50% |
| **Enemy growth** | None | Specializations from day 3 | Most enemies specialized; upgrades on elites |
| **Its question** | Can you protect your back line and handle a swarm? | Can you handle the terrain? | Can you handle an enemy that answers you? |

Each act moves the difficulty up one step (Decision 9 of `rebuild-phase8-apexes.md`'s tier shift), and the apexes are what let a team climb the last one. Region names are placeholders; each act gets its own palette once the art style guide exists.

**Act 2, the Glassmere** (the rift's drowned middle: flooded ruins, glassy water, cold light):

- **Board rule, shallow water:** some hexes are water. A unit on water moves at half speed, and Burn on a unit standing in water burns at half rate. It tests placement and the Burn and clump builds. The arena's rocks and Rift Collapse stay.
- **Enemies:** new faces for about half of Act 1's 8 archetypes, Act 1's own enemies back in specialized form for the rest (Decision 7), and 2 new archetypes: the **Summoner** (target priority; later, something for summoning builds to face) and the **Splitter** (splits in two when killed: burst against area damage; Splitting Ashling is cut for it, Decision 16).
- **Elites:** 2, each built around one mechanic. **Boss:** 2–3 phases, fought by a team with at least one apex.

**Act 3, the Shattered Crown** (the rift's heart: broken islands of floating stone over nothing):

- **Board rule, islands:** the board is 2–3 islands joined by narrow walkable bridges (Decision 6), with gaps between them that can't be walked. Leaps, pulls, and knockbacks cross gaps, and a unit pushed into one falls and is gone (enemies too). Knockbacks and pulls (Ironbrand, the Cairn Guardian, the Bog Lurker) matter a lot, and placement decides which island a fight happens on.
- **Enemies:** new faces again, and 2 new archetypes: the **Mimic** (copies one hero signature it saw, from a list of those that can be copied: Decision 8) and the **Warden-breaker** (strips Shields and cleanses its allies' statuses: it answers the keyword builds).
- **The rift learns** turns on here, on normal difficulty, for the boss's adds only (Decision 10). **The final boss, the heart of the rift,** is the rift that has learned you: it counters the run's habits rather than copying its tricks (Decision 8).

## 3. The frame

- **Data:** `act2.json` and `act3.json` beside `act1.json` (`ActDef`, unchanged in shape: days, pay, prices, slots, odds; Act 1's pay and prices copied for now, Decision 13). `RunContent.acts` (by number) in place of `RunContent.act`; `RunContent.act_of(state)` everywhere `run.act` is read today (about 60 reads across the run, the screens, and the bots). `act3.json` gets its own endless block; `act1.json` keeps one for the testing option (Decision 15). `tuning.json`'s `collapse_by_act` gets Act 3: base 25, growth 30, accel 6 (Decision 14).
- **Moving on:** leaving an act's boss shop starts the next act at its day 1 route (`RunFlow._next_act`): the act's fights drawn (`ActDraw`), `state.act` up, `state.day` back to 1. After Act 3's boss shop, the endless choice (as today after Act 1's).
- **What carries:** everything: heroes (paths, stages, deeds, upgrades, locked amounts, growth, wounds), items and their ranks, relics, shards, and the run's losses (any two losses end the run: Decision 11). The Magpie's visits count afresh each act (built). Nothing happens between acts but the boss shop (Decision 12).
- **Apexes:** the apex vow opens when Act 1 ends, not on Go deeper; the stand-in deed sizes (8b-4c) are retuned so every team has at least one apex before the Act 2 boss (Decision 2).
- **Endless:** after Act 3's boss shop, floors draw from Act 3's fights (Decision 1 of part 1, moved up an act); its numbers unchanged. **The testing option** (Decision 15): after Act 1's boss shop, "Go deeper (testing)" beside "On to Act 2", drawing from Act 1's fights as today. It sits behind a testing toggle on the title, like the fight's readouts, off by default; its runs keep their own records, apart from real endless; and the bots' `--endless` report can use it until Act 3 exists.
- **Save:** version 7 (the act, already saved, now read; a version 6 save still loads, in Act 1). Records keep the deepest floor, and now the furthest act.
- **Screens:** the top bar's "Act 2 · Day 3"; the act map per act; a stage between acts (the act won, what's next); the end screen names the act a run fell in.
- **Bots and reports:** the bots play on; `run_runner.gd` reports each act (runs reaching it, won, where they end, each encounter's wins) and when apexes land by act.
- **Tests:** a run through three acts (with a test content set reusing Act 1's fights), the save across acts, apex timing, endless after Act 3, and every act's data validated.

## 4. The content (waits on section 7)

Per act, by section 2a: new faces for about half the archetypes, Act 1's enemies specialized for the rest, 2 new archetypes, their kits and texts, the day fights (2 a day for 7 days, easier and harder), 2 elites each built around one mechanic, a boss with phases, the act's board rule, Hunts, rocks, placeholder figures, and `scale_bp`. Each new enemy is a positioning problem with an answer in the heroes' paths (`rebuild-enemies.md`'s goals), and any sim piece it needs is skipped by fights that don't use it, so Act 1's fingerprints hold. Specializations come with Act 2 (Decision 4), so `enemy-growth.md` sections 2–3 are built first: the 18 for Act 1's enemies, the 11 upgrades, and 2 for each new face. The board rules are new sim pieces: water (a terrain layer: half speed, Burn at half rate), and islands (gaps that can't be walked, bridges, falling).

## 5. Tuning

The good bot plays the whole run; each act is tuned to section 2a's targets (Decision 3) with the sim runner's gate on every encounter (placement matters by 30 points). Act 1 stays as tuned.

## 6. Parts

- **8c-1, the frame:** acts as data, moving on, the apex vow after Act 1, endless after Act 3, the save, a test content set, tests.
- **8c-2, the screens, the bots, the report.**
- **8c-3, enemy growth:** the specializations and upgrades of `enemy-growth.md` (Decision 4).
- **8c-4 and 8c-5, Act 2's and Act 3's content**, each with its board rule, tuned, with a playtest build.
- **8c-6, apex timing and endless retuned on three acts; docs, a playtest build.**

## Built in 8c-1: the frame (2026-10-03)

- **Acts as data:** `RunContent.acts` (act1.json, then act2.json and act3.json where they exist; each must say its number), `act_of(state)` and `next_act(state)`, and `RunFlow.act` (the run's act). Every read of the one act (the run, the offers, the screens, the bots, the report) now reads the run's; `encounters_for`, `floor_pool`, `normal_encounters`, and `ActDraw.draw` take the act. `ActDef.fights_act` lets a stand-in act draw another act's fights (the tests' stand-ins; the game has only Act 1, so nothing in it changes).
- **Moving on** (`RunFlow._end_of_act`, after the boss shop is left): the apex vow opens (Decision 2; it was on Go deeper), then the choice if the run may go deeper (`can_go_deeper`), else the next act (`_next_act`: day 1's route, its fights drawn by `ActDraw` on the act's stream, and each day's node, Scout, the Magpie's visits, and The Old Well's cut begun afresh; losses, wounds, and the rest carry: Decisions 11 and 12), else the run's end. At the choice, `next_act()` beside `end_run()` and `go_deeper()`.
- **The testing option** (Decision 15): `act1.json`'s endless is `"testing": true`, offered only in a testing run (`RunState.testing`, from `RunFlow.start(..., testing)`; the start screen's "Endless after Act 1 (for testing)", off by default). The bots' `--endless` runs are testing runs. Endless after the last act needs no testing run.
- **Records by act:** `RunRecords` files each best under the act its endless follows; an older file's one record reads as Act 1's.
- **Save:** version 7 (`testing`, and each fight's `act`, since days start again each act); an older save that went deeper, or waits at the choice, loads as a testing run.
- **Screens:** the choice names the act's boss and offers "On to Act N" and "Go deeper (testing)"; the boss shop's leave button says where it leads; the act map shows only this act's fights; the end names the act.
- **Tests:** `tests/run/test_acts.gd` (on stand-in Acts 2 and 3 drawing Act 1's fights: loading, moving on, what carries, two losses across acts, the testing option, endless after Act 3, the save, the records, and the simple bot through all three acts on seed 38) and a screen test for the testing option and On to Act 2. Mutation checks: resetting losses at a new act, or not opening the apex vow at the act's end, each fail a test.

## Built in 8c-2: the report by act and the furthest act (2026-10-03)

- **The run report** (`run_runner.gd`): each run's line keeps the act it ended in and the act each first transformation and apex came in. With more than one act, the report adds **By act**: each act's runs reaching it, winning it, losing in it by day, and the apexes earned in it (median day); "Lost runs end on" and `--compare` count Act 1's days and the later acts apart; the endless report reads each run's own act's floors. With Act 1 only, the report reads as before.
- **The furthest act:** `RunRecords.furthest` and `note_furthest` keep the furthest act and day any run has reached, beside the floors (`"furthest"` in the records file); every finished run notes it (`RunSession.new_furthest`), and the end screen shows it once there's more than one act.
- **Tests:** `test_acts.gd` adds the furthest record and the by-act summary.

## 7. Questions

- **BA. Who designs Act 2 and Act 3's enemies, elites, and bosses?** *(Answered: Decision 1.)* The plans have none of them. Options: the playtester sends design notes (as for apexes and endless), or a draft of both rosters is written for approval before any is built.
- **BB. Specializations with Act 2?** *(Answered: Decision 4.)* The plans put them in Act 2 (half the enemies) and Act 3 (most). Build enemy growth (`enemy-growth.md` sections 2–3) before Act 2's content, or ship Acts 2 and 3 without them first and add them later?
- **BC. An act's length:** *(Answered: Decision 1.)* 7 days and the boss, like Act 1?
- **BD. What resets between acts:** *(Answered: Decision 11.)* losses (the second loss ends the run: per act, or per run?), wounds, the Magpie's two visits (per act, already), anything else?
- **BE. Between acts:** *(Answered: Decision 12.)* anything special (a full rest, a choice of reward), or straight to the next act's route after the boss shop?
- **BF. Targets:** *(Answered: Decision 3.)* the good bot wins Act 1 about half the time. What should it be for Act 2 and Act 3 (given it reached them), or for the whole run?
- **BG. Pay and prices in later acts:** *(Answered: Decision 13.)* the same as Act 1, or growing? (`economy.md` covers Act 1 only.)
- **BH. Act 3's crumbled ground:** *(Answered: Decision 14.)* `collapse_by_act` has no Act 3. A placeholder of base 25, growth 30, accel 6?
- **BI. Endless while Acts 2 and 3 are built:** *(Answered: Decision 15.)* keep it after Act 1 until Act 3 exists, or move it once the frame is in?
- **BJ. The Splitter and Splitting Ashling** *(Answered: Decision 16.)* (an Ashling specialization in `enemy-growth.md`) do the same thing. Cut one, or tell them apart (the Splitter's halves are full enemies; the Ashling's embers are small and burst)?
- **BK. A hero pushed into a gap:** *(Answered: Decision 17.)* does it count as a fall (a wound, as being downed does), and is the fight then fought without it? The log names it (rule 4) and the board must show every gap clearly.
- **BL. Which hero signatures the Mimic can copy:** *(Answered: Decision 18.)* ones built from areas, damage, heals, Shields, and statuses copy cleanly; snares, walls, Guard, lanterns, and links are tied to their hero. Copy only the first kind?

## Decisions

The playtester, 2026-10-03 (on the skeleton in section 2a and the review of it):

1. **Three acts of 7 days each** (Questions BA, BC). The shape in section 2a is agreed; each act's enemies, elites, and boss are drafted with the playtester, one act at a time, "the way we did with heroes".
2. **At least one apex per team before the Act 2 boss** (changes `rebuild-phase8-apexes.md` Decision 7, which had it land after): it gives the player time to use an apex at full strength. The vow still opens after the Act 1 boss; the apex deeds are sized to it.
3. **The difficulty targets are section 2a's, for now** (Question BF). Each is a team's chance at that point; whole-run odds compound (about 1 good-bot run in 8 would clear Act 3), accepted for now.
4. **Specializations start in Act 2, from day 3** (Question BB; moved from Act 1's day 5, which never had them built), and most of Act 3's enemies are specialized, with upgrades on its elites. Enemy growth is built before Act 2's content.
5. **Shallow water** (Act 2): half speed on water, and Burn burns at half rate on a unit standing in water: half of each Burn tick while it stands there; the Burn lasts as long as anywhere else.
6. **Islands are joined by narrow walkable bridges** (Act 3): with true gaps only, melee on different islands could never meet, and the fight would run to 180s, a tie and a guild win.
7. **New faces for about half the archetypes in each act;** the rest are Act 1's enemies back in specialized form (the enemy you learned, changed). It about halves the content.
8. **One copying idea per piece:** the Mimic copies one hero signature mid-fight; the final boss is the rift that has learned you, countering the run's habits, not copying its tricks.
9. **One board rule per act** (water, then islands), and **2 new archetypes per act** (Summoner and Splitter; Mimic and Warden-breaker).
10. **The rift learns is on in Act 3 on normal difficulty, for the boss's adds only** (changes `rebuild-enemies.md` section 8 and `enemy-growth.md` section 5, where it was only a difficulty modifier). Higher difficulties still widen it.

The playtester, 2026-10-03 (the rest of section 7):

11. **Any two losses end the run, across all three acts** (Question BD): losses don't reset between acts, as the run counts them today. Wounds carry over too.
12. **The boss shop is the break between acts** (Question BE): nothing else; leaving it goes to the next act's day 1 route.
13. **Act 2 and Act 3 pay and price as Act 1 does, for now** (Question BG), retuned once they play.
14. **Act 3's crumbled ground: base 25, growth 30, accel 6** (Question BH), a placeholder.
15. **Endless after Act 1 stays as a testing option** (Question BI): real endless comes after Act 3; the Act 1 version is offered only with the testing toggle on, and keeps its records apart, so floors from the two never compare.
16. **Splitting Ashling is cut; the Splitter stays** (Question BJ), so Act 2 keeps its 2 new archetypes (Decision 9). The Ashling gets a new second specialization when Act 2's roster is drafted.
17. **A hero pushed into a gap counts as a fall, for now** (Question BK): it takes a wound and is out of the fight, as a downed hero is. The log names the fall (rule 4).
18. **The Mimic copies only signatures built from areas, damage, heals, Shields, and statuses, for now** (Question BL): snares, walls, Guard, lanterns, and links stay with their hero.
