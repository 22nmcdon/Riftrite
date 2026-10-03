# Phase 8 part 3: Acts 2 and 3

Status: **a draft build plan (2026-10-03), waiting on the playtester's answers to section 7.** Nothing is built. The playtester chose Acts 2 and 3 as phase 8's next step (2026-10-03), ahead of enemy growth, the heroes' tuning, and more heroes. Numbers are placeholders.

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

## 3. The frame

- **Data:** `act2.json` and `act3.json` beside `act1.json` (`ActDef`, unchanged in shape: days, pay, prices, slots, odds). `RunContent.acts` (by number) in place of `RunContent.act`; `RunContent.act_of(state)` everywhere `run.act` is read today (about 60 reads across the run, the screens, and the bots). The endless block moves to `act3.json`.
- **Moving on:** leaving an act's boss shop starts the next act at its day 1 route (`RunFlow._next_act`): the act's fights drawn (`ActDraw`), `state.act` up, `state.day` back to 1. After Act 3's boss shop, the endless choice (as today after Act 1's).
- **What carries:** heroes (paths, stages, deeds, upgrades, locked amounts, growth, wounds), items and their ranks, relics, and shards. **What resets** is section 7's question BD.
- **Apexes:** the apex vow opens when Act 1 ends, not on Go deeper; the stand-in deed sizes (8b-4c) are retuned so the apex lands after the Act 2 boss (Decision 8).
- **Endless:** floors draw from Act 3's fights (Decision 1 of part 1, moved up an act); its numbers unchanged.
- **Save:** version 7 (the act, already saved, now read; a version 6 save still loads, in Act 1). Records keep the deepest floor, and now the furthest act.
- **Screens:** the top bar's "Act 2 · Day 3"; the act map per act; a stage between acts (the act won, what's next); the end screen names the act a run fell in.
- **Bots and reports:** the bots play on; `run_runner.gd` reports each act (runs reaching it, won, where they end, each encounter's wins) and when apexes land by act.
- **Tests:** a run through three acts (with a test content set reusing Act 1's fights), the save across acts, apex timing, endless after Act 3, and every act's data validated.

## 4. The content (waits on section 7)

Per act, by Act 1's shape: about 9 enemies (one or two per archetype, new faces), their kits and texts, the day fights (2 a day for about 7 days, easier and harder), 3 elites each built around one mechanic, a boss with phases, Hunts, rocks, placeholder figures, and `scale_bp`. Each new enemy is a positioning problem with an answer in the heroes' paths (`rebuild-enemies.md`'s goals), and any sim piece it needs is skipped by fights that don't use it, so Act 1's fingerprints hold. If specializations come with Act 2 (question BB), `enemy-growth.md` sections 2–3 are built first: the 18 for Act 1's enemies, the 11 upgrades, and 2 for each new face.

## 5. Tuning

The good bot plays the whole run; each act is tuned to a target (question BF) with the sim runner's gate on every encounter (placement matters by 30 points). Act 1 stays as tuned.

## 6. Parts

- **8c-1, the frame:** acts as data, moving on, the apex vow after Act 1, endless after Act 3, the save, a test content set, tests.
- **8c-2, the screens, the bots, the report.**
- **8c-3 and 8c-4, Act 2's and Act 3's content** (with enemy growth first, if question BB says so), each tuned, with a playtest build.
- **8c-5, apex timing and endless retuned on three acts; docs, a playtest build.**

## 7. Questions

- **BA. Who designs Act 2 and Act 3's enemies, elites, and bosses?** The plans have none of them. Options: the playtester sends design notes (as for apexes and endless), or a draft of both rosters is written for approval before any is built.
- **BB. Specializations with Act 2?** The plans put them in Act 2 (half the enemies) and Act 3 (most). Build enemy growth (`enemy-growth.md` sections 2–3) before Act 2's content, or ship Acts 2 and 3 without them first and add them later?
- **BC. An act's length:** 7 days and the boss, like Act 1?
- **BD. What resets between acts:** losses (the second loss ends the run: per act, or per run?), wounds, the Magpie's two visits (per act, already), anything else?
- **BE. Between acts:** anything special (a full rest, a choice of reward), or straight to the next act's route after the boss shop?
- **BF. Targets:** the good bot wins Act 1 about half the time. What should it be for Act 2 and Act 3 (given it reached them), or for the whole run?
- **BG. Pay and prices in later acts:** the same as Act 1, or growing? (`economy.md` covers Act 1 only.)
- **BH. Act 3's crumbled ground:** `collapse_by_act` has no Act 3. A placeholder of base 25, growth 30, accel 6?
- **BI. Endless while Acts 2 and 3 are built:** keep it after Act 1 until Act 3 exists, or move it once the frame is in?

## Decisions

None yet.
