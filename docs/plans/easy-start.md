# The easy start (Act 1, days 1 and 2)

Status: **a build plan, approved (2026-10-07; Decisions 1–13); ES-1 and ES-2 built.** The playtester's request after phase 8 part 4's bot runs: fix Act 1's opening before tuning anything else, because runs that end on day 1 spoil every other number (heroes, paths, deeds, synergy against bad teams). Questions are in section 8.

## 1. Why

The good bot's 120 runs over all 20 teams (`rebuild-phase8-heroes.md`, "Built in 8d-5d"): 53 end on day 1, before a shop, a pick, or a deed tick. So the hero and path numbers mostly measure whether the team had a tank on day 1. Tamsin and Vell at 1% of runs won are probably heroes who often landed on tankless teams, and Garrote's 5% is partly runs too short for any deed.

The targets (the playtester's), for any team placed sensibly:

| Point in Act 1 | Target | What it teaches |
| --- | --- | --- |
| Day 1 | about 95% | How fights work. No flankers. |
| Days 2–3 | about 85% | One new threat at a time (the first flanker, the first archer) |
| Act 1 boss | random teams about 50–60%; synergy higher, bad teams lower | The first real test |

Bad teams should still lose, just later: at the Act 1 boss or in Act 2, after the run has given them chances to patch the hole. The overall win rate shouldn't jump: what comes out of days 1–2 moves to the Act 1 boss and Act 2.

## 2. What was measured (2026-10-07)

Every team the draft offers (20), vowed with 3 of its vow sets each (the run report's stride), in each fight days 1 and 2 can draw, at fight seed 7001.

**Placement against the fights:** the good bot's placement, and a search of 64 formations (the 4 named and 60 drawn).

| Fight (days) | Bot, with a tank | Some formation wins, with a tank | Bot, no tank | Some formation wins, no tank |
| --- | --- | --- | --- | --- |
| Pup Warren (1–2) | 45% | 100% | 0% | 0% |
| Ash Nest (1–2) | 39% | 93% | 0% | 0% |
| The Pack (1–2) | 89% | 100% | 0% | 0% |
| Hounds and Archers (1–2, harder) | 64% | 100% | 0% | 0% |
| Moth Cloud (2) | 87% | 97% | 0% | 41% |
| Hollow Line (2) | 64% | 95% | 0% | 0% |
| Lurker and Ashlings (2, harder) | 16% | 31% | 0% | 0% |

So:
- **Tankless teams lose every early fight however they're placed**, not just the flanker fights. The Pack, the flanker fight, is the good bot's best day-1 fight for teams with a tank. The early fights are sized for a tank's HP, not built around flankers.
- **The bot's placement is a real part of the losses for teams with a tank:** in Pup Warren and Ash Nest it wins about 40% where a searched formation wins almost every time. Once the fights are sized (below), it wins 87–100%, so placement stops deciding day 1.
- Within teams with a tank, weak ones (Brannoc or Garrow with two of Vell, Tamsin, Aldous) win 1 to 4 of 12 day-1 fights.

**Sizing:** the bot's placement with the enemies' HP and ATK scaled, or with each kind of enemy cut to two thirds (rounded up), or both.

| Fight | Team | As now | ×85% | ×70% | ×55% | ⅔ enemies | ⅔ and ×85% |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Pup Warren | tank | 45% | 89% | 100% | 100% | 100% | 100% |
|  | none | 0% | 0% | 91% | 100% | 100% | 100% |
| Ash Nest | tank | 39% | 89% | 100% | 100% | 87% | 93% |
|  | none | 0% | 0% | 66% | 100% | 16% | 83% |
| The Pack | tank | 89% | 100% | 100% | 100% | 100% | 100% |
|  | none | 0% | 0% | 91% | 100% | 91% | 100% |
| Hounds and Archers | tank | 64% | 100% | 100% | 100% | 64% | 100% |
|  | none | 0% | 0% | 75% | 100% | 0%* | 0%* |
| Moth Cloud | tank | 87% | 95% | 100% | 100% | 100% | 100% |
|  | none | 0% | 75% | 100% | 100% | 100% | 100% |
| Hollow Line | tank | 64% | 100% | 100% | 100% | 100% | 100% |
|  | none | 0% | 0% | 83% | 100% | 100% | 100% |
| Lurker and Ashlings | tank | 16% | 56% | 97% | 100% | 75% | 95% |
|  | none | 0% | 0% | 41% | 100% | 0% | 16% |

\* Two thirds of 2, rounded up, is 2: those cuts didn't shrink the fight.

The step is sharp: tankless teams go from 0% to about 90% between ×85 and ×70 strength, or with about a third fewer enemies at full strength.

## 3. Day-1 candidates, sized for the worst team

Decision 1 sizes day 1 for the worst team, and Decision 2 puts it a step past the cliff. The Glass stand-in (`test-teams.md`'s B1 is Ilse, Ottilie, and Lucan, none built yet) is **Maren, Vell, and Aldous**: three back-liners, no melee. Measured on every one of its 27 vow sets, 3 fight seeds each, the good bot placing, at the candidate's strength and at ×120 (the margin). Beside it, the three tankless plan teams (Decision 4; section 5) and the old three.

| Candidate (full strength) | Glass | Burst, sustain, control | Glass at ×120 |
| --- | --- | --- | --- |
| Pup Warren, 6 Rift Pups (now) | 0% | 0, 0, 0 of 3 | 0% |
| 4 Rift Pups | 100% | 3, 3, 3 | 44% (at the cliff) |
| **3 Rift Pups** | **100%** | **3, 3, 3** | **100%** |
| Ash Nest, 3 Ashlings and 2 Rift Pups (now) | 0% | 0, 0, 0 | 0% |
| 2 Ashlings and 1 Rift Pup | 100% | 3, 3, 3 | 0% (at the cliff) |
| **1 Ashling and 2 Rift Pups** | **100%** | **3, 3, 3** | **100%** |
| 2 Hollow Archers and 2 Rift Pups | 43% | 0, 0, 0 | 0% |
| **1 Hollow Archer and 2 Rift Pups** | **100%** | **3, 3, 3** | **100%** |
| The Pack, 3 Rift Hounds (now) | 0% | 0, 0, 0 | 0% |
| The Pack, 2 Rift Hounds | 100% | 3, 3, 3 | 0% (at the cliff) |

So day 1 is **3 Rift Pups and 1 Ashling with 2 Rift Pups** (Decisions 9 and 10; the archer fight was a candidate for a harder option, not built): Glass wins every vow set with the enemies 20% stronger. The fewer-enemies versions at the cliff (4 pups, 2 Ashlings) would come back to 0% with a small change elsewhere, which is what Decision 2 guards against. The Pack with 2 hounds is a day-2 candidate (day 2's target is 85%, not 95%), but it sits at its cliff too.

## 4. The proposal

1. **Day 1:** the two fights above, no flankers, at their usual strength (fewer enemies, not weaker ones). A day-1 fight is easier to read for having fewer enemies, and the enemies hit as hard as they always will.
2. **The Glass check (Decision 2):** a test fights the Glass stand-in in every day-1 fight on every vow set with the good bot placing, and fails if it wins less than 90% of any one. When Ilse, Ottilie, and Lucan are built, the real Glass replaces the stand-in.
3. **Day 2: one new threat at a time, at least 85% for the worst team, with a margin** (Decision 13; built in ES-2). The first flanker (The Pack) and the first archer line come on day 2, cut to sizes Glass holds even with the enemies 10% stronger. Lurker and Ashlings is cut too (Decision 6: searched formations also lose it). Day 3 stays the first elite, judged in the runs (ES-4).
4. **No shop guarantee for now** (Decision 3). If the plan teams can't hold days 2–3 at their sizes, a build-lean slot (an item tagged with a build one of the heroes belongs to) comes back as its own proposal; items and relics don't carry build tags yet.
5. **Tankless teams measured by their plan** (Decision 4): burst, sustain, and control teams (section 5), each with its key items leaned in the shop, should clear the Act 1 boss at about the random-team rate when the build comes together. A plan that can't is what needs work.
6. **What each fight tests** (Decision 5): every Act 1 fight from day 2 on is listed by what it asks (archers in the back, a swarm, one big hitter, damage over time, a drag or a dive), with how each plan does in it, so each plan has fights it's good at and fights it isn't. Fights that only test HP get a second question.
7. **The end-of-run target by group** (Decision 7): random teams around the old three's tuned rate, synergy teams above it, bad teams below. The difficulty taken out of days 1–2 moves to the Act 1 boss and Act 2 only as far as that needs; today's 8% isn't held.
8. **Placement help for players** (a simple default formation, tanks in front and the ranged behind) comes later (Decision 8), not in this plan.

## 5. The tankless plan teams (stand-ins from the six built heroes)

| Plan | Team (vows) | Its answer |
| --- | --- | --- |
| Burst | Tamsin (Nightblade), Maren (Deadeye), Aldous (Windcaller) | Kill them before the damage lands |
| Sustain | Vell (Lanternbearer), Aldous (Chorister), Maren (Volley) | Spread the damage and undo it |
| Control | Maren (Trapper), Tamsin (Garrote), Vell (Wardweaver) | The damage never gets thrown |

Sustain is the weakest stand-in: its real makers (Edric, Severine) aren't built. When they are, the real teams from `test-teams.md` replace these.

## 6. The sim runner's gate

The gate wants the best formation to win at least 30 points more often than the worst in every encounter. Day-1 fights sized so the worst team wins every vow set won't split that far. Proposed: day-1 fights report the split but don't fail the gate; the Glass check is their gate.

## 7. Parts

- **ES-1:** the day-1 fights, the Glass check, and the gate's day-1 rule (data, `sim_report.gd`, tests).
- **ES-2:** days 2–3 resized for about 85% with the margin (data), The Pack and the archers on day 2, Lurker and Ashlings cut.
- **ES-3:** what each fight tests (section 4, item 6), with the plan teams' results in each.
- **ES-4:** the run report's By team (runs, how far they got, won), the plan teams and the bad teams played with the shop lean, the good bot over all 20 teams; the Act 1 boss (and later fights) raised only to the group targets; the numbers recorded here.
- **ES-5:** Garrote and the slow paths read again on the new runs; docs, HOW-TO-PLAY, playtest build.

### Built in ES-1 (the day-1 fights, the Glass check, the gate)

- **The day-1 fights** (`data/encounters.json`, Decisions 9 and 10): **Warren Mouth**, 3 Rift Pups (Pup Warren's rocks, its strength), and **Smouldering Den**, 1 Ashling and 2 Rift Pups (Ash Nest's strength), both `"days": [1]`. Pup Warren and Ash Nest move to day 2 only, The Pack to days 2–3, and Hounds and Archers to day 2, so day 1 offers the two new fights (ActDraw draws two easier ones when a day has no harder fight) and has no flankers.
- **The Glass check** (`tests/tools/test_easy_start.gd`, Decision 2): Maren, Vell, and Aldous on all 27 vow sets, the good bot placing, at fight seed 7001, must win at least 90% of every day-1 fight; both win all 27. The test also checks day 1 has only those fights, no harder one, and no flanker.
- **The gate** (Decision 11): `SimReport.Report.exempt()` (an encounter whose only day is 1) passes whatever the split; the report says "exempt (day 1)" and the runner's summary "day 1". Both new fights: 24 of 24 formations win.
- **Not changed:** no fight (the bench's fingerprints are the same); the full fights stay as they were.

### Built in ES-2 (day 2 resized)

- **What was measured** (the good bot placing, the Glass stand-in on all 27 vow sets and the three plan teams, at each fight's strength and stronger): every day-2 fight lost almost everything for Glass at its old size (Pup Warren, Ash Nest, The Pack, Hollow Line, Hounds and Archers, and Lurker's Kindling 0%, Moth Cloud 1%), and each one goes from all to nothing between one composition and the next, like day 1.
- **The rule** (Decision 13): Glass wins at least 85% at the fight's strength and at least 50% with the enemies 10% stronger. Each fight's largest composition that holds it:
  - **Pup Warren:** 4 Rift Pups (6), full strength.
  - **Ash Nest:** 2 Ashlings and 2 Rift Pups (3 and 2), at x0.8 (scale 9200).
  - **The Pack:** 2 Rift Hounds (3), at x0.9 (10125).
  - **Moth Cloud:** 2 Cinder Moths and 2 Rift Pups (3 and 2), full strength.
  - **Hollow Watch** (new, day 2): 2 Hollow Archers behind Hollow Line's rocks, full strength; Hollow Line keeps its 3 for day 4.
  - **Hounds and Archers** (harder): 2 Rift Hounds and 1 Hollow Archer (2 and 2), at x0.8 (7560).
  - **Lurker's Spark** (new, harder, day 2; Decision 6): 1 Bog Lurker and 1 Ashling at x0.8 (9360); Lurker's Kindling keeps its 3 Ashlings for day 4.
  The Pack's and Moth Cloud's day 3 is gone from their days (day 3 is an elite day, so a normal fight was never drawn there).
- **The check** (`tests/tools/test_easy_start.gd`): every Act 1 fight whose first day is 2 holds Glass at 85%, and at 50% with the enemies x1.1; all seven do.
- **The gate** (Decision 13): at these sizes every formation wins, for Glass as for the old three, so an Act 1 fight that comes only on days 1 and 2 is exempt from the 30-point split (`SimReport.Report.exempt()`, "exempt (days 1-2)").
- **A placement band, not taken:** a little stronger (x1.10 to x1.20 of these sizes) the good bot still wins with Glass while careless formations lose (The Pack x1.15: bot 3 of 3, 93% of formations; Hollow Watch x1.15: bot 3 of 3, 37%; Pup Warren x1.15: 79%; Ash Nest x1.20: 80%), so day 2 could teach placement at the cost of its margin. The playtester chose the margin (Decision 13); the placement lessons start on day 4.

## 8. Questions

- **EA. Day-1 fights:** *(Answered: Decision 9.)* new smaller encounters for day 1 only, or shrink them everywhere?
- **EB. The harder day-1 fight:** *(Answered: Decision 10.)* a new 1 Hollow Archer and 2 Rift Pups, or no harder option on day 1?
- **ED. The gate:** *(Answered: Decision 11.)* day-1 fights exempt from the 30-point split, with the Glass check as their gate?
- **EE. The plan teams:** *(Answered: Decision 12.)* the three stand-ins in section 5?

## Decisions

The playtester, 2026-10-07:

1. **Day 1 is sized for the worst team, not the average:** "any team wins about 95%" means Glass (three fragile back-liners) wins about 95%.
2. **A margin above the cliff, and a check:** day 1 sits a step past the strength where tankless teams fall to 0%, and a check fails if Glass drops below about 90% in any day-1 fight, so the cliff can't come back unnoticed.
3. **No defensive guarantee in the first shop.** A team without a tank isn't broken; it has a different answer to the enemy's damage (a tank soaks it, burst kills first, sustain undoes it, control stops it). If the first shop helps at all, it helps the team's own plan (a slot from a build one of its heroes belongs to); no guarantee at all is also fine, with days 1–2's sizing doing the work.
4. **Tankless teams are measured by their plan:** a burst, a sustain, and a control team, each able to clear the Act 1 boss at about the random-team rate when its build comes together. A plan that can't is what needs work.
5. **Later fights test different things**, so each plan has fights it's good at: archers in the back (burst wins, tanks struggle), a swarm (control and area damage), one big hitter (a tank or control), damage over time (sustain).
6. **Lurker and Ashlings is cut, not left as a placement puzzle:** searched formations lose it too (31% of teams with a tank have any winning formation, none without).
7. **Today's 8% isn't held:** the end-of-run target is by group (random teams around the old three's tuned rate, synergy above, bad below), and only as much difficulty moves to the Act 1 boss and Act 2 as that needs.
8. **Placement help for players** (a simple default formation) comes later, not in this step.
9. **Day 1 has its own fights** (Question EA): new day-1-only encounters, 3 Rift Pups and 1 Ashling with 2 Rift Pups; Pup Warren and Ash Nest keep their full size from day 2 on.
10. **No harder option on day 1** (Question EB): day 1 offers two easier fights (ActDraw's rule when a day has no harder fight); the harder fights start on day 2. The 1 Hollow Archer and 2 Rift Pups candidate isn't built.
11. **Day-1 fights are exempt from the gate's 30-point split** (Question ED): the sim runner reports their split, and the Glass check is their gate.
12. **The plan teams are section 5's stand-ins** (Question EE), replaced by `test-teams.md`'s real teams as their heroes are built.
13. **Day 2 keeps the full margin and is exempt from the gate** (asked while building ES-2): sized so Glass wins at least 85%, and at least half with the enemies 10% stronger; at those sizes nearly every formation wins, so days 1 and 2 are both exempt from the 30-point split, and the placement lessons start on day 4. (The other choice was a narrow band where careless formations lose, with only 5–15% margin.)
