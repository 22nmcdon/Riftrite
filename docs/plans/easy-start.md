# The easy start (Act 1, days 1 and 2)

Status: **a build plan, approved (2026-10-07; Decisions 1–16); ES-1 to ES-4 built (ES-3's fight changes tried and not shipped; ES-4 added day 3's own elites and the days 4–6 ramp).** The playtester's request after phase 8 part 4's bot runs: fix Act 1's opening before tuning anything else, because runs that end on day 1 spoil every other number (heroes, paths, deeds, synergy against bad teams). Questions are in section 8.

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

### Built in ES-3 (what each fight tests)

Measured for every Act 1 fight from day 3 on: each team's **breaking point**, the highest enemy strength on a ladder (x0.3 to x2.5) at which it still wins 2 of 3 fight seeds, the good bot placing, every hero transformed (Decision 4: a plan judged once its build comes together), no items or relics. Four teams: the old three (Hearthwall, Deadeye, Lanternbearer) for a tank, and section 5's burst, sustain, and control.

| Fight (what it asks) | Tank | Burst | Sustain | Control | Relatively best |
| --- | --- | --- | --- | --- | --- |
| Hollow Line (3 archers: closing distance) | x1.30 | x1.15 | x1.15 | x0.80 | sustain |
| Bog Crossing (a Lurker drags, a swarm: back-line safety) | x1.00 | x0.80 | x0.80 | x0.80 | control |
| Sentinel Gate (a Sentinel, 2 archers: going around a wall) | x1.30 | x0.80 | x0.80 | x0.70 | **tank** |
| Cairn Road (a charger, 2 hounds) | x1.00 | x0.80 | x0.90 | x0.70 | sustain |
| Witch Circle (a Sentinel, a witch, a moth: target priority) | x0.80 | x0.70 | x0.50 | x0.70 | control |
| Lurker's Kindling (dragged into a crowd that burns) | x1.15 | x1.00 | x0.80 | x0.90 | burst |
| Sentinel and Moths (round the wall without bunching) | x0.80 | x0.70 | x0.60 | x0.60 | burst |
| Witch and Pups (reach the witch through a swarm) | x0.90 | x0.70 | x0.70 | x0.60 | sustain |
| Guardian and Witch (a charger the witch Shields) | x0.70 | x0.60 | x0.50 | x0.60 | control |
| The Hunt, elite (the pack pounces on one hero) | x1.30 | x1.00 | x0.80 | x0.90 | **tank** |
| Witch Coven, elite (break the Totem past the Sentinel) | x1.75 | x1.00 | x1.15 | x0.90 | **tank** |
| Cairn Watch, elite (a charger, archers behind rocks) | x1.00 | x0.90 | x1.00 | x0.90 | sustain |
| Old Mother Ash, boss | x0.60 | x0.50 | x0.50 | x0.60 | control |

"Relatively best" compares each team's breaking point with its own average over the 13 fights (geometric means: tank x1.01, burst x0.80, sustain x0.75, control x0.74).

What it says:
- **The tank team breaks latest in every fight in absolute terms** (tied by control at Old Mother Ash and sustain at Cairn Watch): the tankless plans are about a fifth to a quarter weaker overall here. Part of that is the stand-ins (sustain has no real makers until Edric and Severine; none carry their build's items or relics), so Decision 4's real measure is the runs with the shop lean (ES-4). If they're still a quarter behind there, the gap is in the heroes (the tuning phase), not in the fights.
- **Relatively, each plan has fights it's best at:** sustain in Hollow Line, Cairn Road, Witch and Pups, and Cairn Watch; control in Bog Crossing, Witch Circle, Guardian and Witch, and Old Mother Ash; burst in Lurker's Kindling and Sentinel and Moths.
- **Three fights only test the tank:** Sentinel Gate, The Hunt, and Witch Coven, where the tank team leads both absolutely and relatively (Witch Coven by the most: x1.75 against x0.90 to x1.15). These are Decision 5's fights that need a second question (Question EF).
- **Some fights answer differently than Decision 5 expects:** archers in the back favour sustain, not burst (Hollow Line, Cairn Watch), and the burning crowd (Lurker's Kindling) favours burst, not sustain.

- **The second questions, tried** (Decision 14, Question EF): each proposed change, measured the same way, from copies of the data:

  | Variant | Tank | Burst | Sustain | Control |
  | --- | --- | --- | --- | --- |
  | Sentinel Gate as built | x1.30 | x0.80 | x0.80 | x0.70 |
  | an archer out of the Sentinel's shadow (either side) | x1.30 | x0.80 | x0.80 | x0.70 |
  | The Hunt as built | x1.30 | x1.00 | x0.80 | x0.90 |
  | Hunt Hounds 300 HP / 24 ATK, or 250 / 26 (420 / 18) | x1.15 | x0.90 | x0.70 | x0.80–0.90 |
  | Witch Coven as built | x1.75 | x1.00 | x1.15 | x0.90 |
  | Gloam Totem 300 HP / Shield 25, or 260 / 30 (520 / 15) | x1.75 | x0.90–1.00 | x1.15 | x0.80 |

  None narrows the gap: the tankless plans fall as far behind the tank, or farther. These fights don't fail them on a detail; the stand-in plans don't kill or control fast enough to use an exposed archer, a lighter pack, or a weaker Totem. **So nothing was changed** (the data is as before). The question goes back to the runs: if ES-4's plan teams, with their items and relics, still can't answer these three, the fix is in the heroes' burst and control (the tuning phase), or a bigger change to the fights, asked then.

### Built in ES-4 (the runs, by team and by group)

- **The tools** (all testing only): `tools/test_teams.json` holds the plan teams (section 5's burst, sustain, and control, and the old three as the tank plan), each with fixed vows and the items and relics it leans toward, and four bad stand-ins from the six built heroes (Glass, no makers, all melee, all tanks; no lean). `run_runner.gd --test-teams=all|plan|bad|names` plays them, seed n the nth in turn, and `--no-lean` turns the lean off. **The lean** is `RunContent.test_lean`: the shops' wares and every relic draw take a leaned id 3 times as often, and the good bot tries leaned buys first and counts them 0.05 higher. Only the tools set it; the run report clears it after each run, it's never saved, and `tests/run/test_offers_lean.gd` fails if anything in `src/` writes it. With no lean every draw rolls exactly as before. The run report adds **By team** (runs; ended on day 1, reached Act 1's boss, won Act 1, won Act 2; won) and **By group**.
- **First runs** (the good bot over all 20 teams, 120 runs, after ES-1 and ES-2): no run ended on day 1 and 2 on day 2, but **56 of 120 ended on day 3**, the first elite (The Hunt 40% of its fights, Witch Coven 48%, Cairn Watch 52%). A sweep with the good bot placing: every tankless team and every plan team lost all three at full strength. One run also stuck on Dig In's rock placed on the chosen fight's water (below).
- **Day 3's own elites** (Decision 15), sized like day 2 (Glass at least 85%, at least half with the enemies 10% stronger; the second enemy of a kind was what broke Glass each time):
  - **Alpha's Trail:** the Hound Alpha and one Hunt Hound, at x0.7 (scale 7770): Glass 100%, 100% at x1.1.
  - **Witch's Ward:** the Gloam Totem, one witch, and the Sentinel, full strength (8200): 100%, 100%.
  - **Cairn Sentry:** the Cairn Guardian and one archer behind the rocks, at x0.9 (12285): 100%, 81%.
  The full elites come on day 5 only. Like days 1–2 they're exempt from the gate's split (`SimReport.Report.exempt()`: an Act 1 fight whose days are all 1 to 3; "exempt (days 1-3)"), and `test_easy_start.gd` holds them to the day-2 rule.
- **The second runs:** day 3 ended 1 run of 120, and **day 4 became the wall: 46 of 120** (Sentinel Gate and Cairn Road 32% of their fights, Bog Crossing 52%, Hollow Line 90%); Act 1 won 33%, Old Mother Ash 56% of her fights.
- **Days 4–6 ramp to about 70%** (Decision 16), sized from a probe of all 20 teams vowed and transformed at strengths x1.0 to x0.6 (the runs win about a third more than the probe's middle): **Sentinel Gate x0.82** (scale 16150 to 13240), **Cairn Road x0.78** (16500 to 12870), **Bog Crossing x0.9** (14400 to 12960). Hollow Line (90%) and Witch Circle (66%, nearly all day 6) stay. All three still pass the gate.
- **The third runs (the numbers ES-4 leaves):** the good bot over all 20 teams, 120 runs:

  | Point | Target | Now |
  | --- | --- | --- |
  | Day 1 | about 95% | 100% (Warren Mouth 65 of 65, Smouldering Den 55 of 55) |
  | Days 2–3 | about 85% | 89–100% a fight; 2 runs of 120 end there |
  | Days 4–6 (Decision 16) | about 70% | Bog Crossing 67%, Sentinel Gate 67%, Cairn Road 72%, Witch Circle 50% (16 fights); 23 runs end on day 4 |
  | Act 1 boss | 50–60% for random teams | 87 of 120 runs reach Old Mother Ash and 56% of them win; she wins 61% of her fights |
  | Act 1 | the old three's tuned rate (49%) for random teams | 40% |
  | The run | | 8% (Act 2 won by 40% of those reaching it, Act 3 by 50%) |

  Act 1 is below 49%, so the boss isn't raised (Decision 16).
- **The test teams** (the good bot, 12 runs each; with the lean, then the plan teams without it):

  | Team | Group | Reach Act 1's boss | Win Act 1 | Win Act 2 | Won | Without the lean (Act 1, won) |
  | --- | --- | --- | --- | --- | --- | --- |
  | Tank (the old three) | plan | 100% | 58% | 33% | 25% | 41%, 16% |
  | Burst | plan | 91% | 58% | 0% | 0% | 66%, 0% |
  | Sustain | plan | 33% | 0% | 0% | 0% | 0%, 0% |
  | Control | plan | 0% | 0% | 0% | 0% | 0%, 0% |
  | Glass | bad | 25% | 8% | 0% | 0% | |
  | No makers | bad | 66% | 58% | 8% | 0% | |
  | All melee | bad | 100% | 83% | 50% | 33% | |
  | All tanks | bad | 75% | 33% | 8% | 8% | |
  | **Plan group** | | 56% | 29% | 8% | 6% | 27%, 4% |
  | **Bad group** | | 66% | 45% | 16% | 10% | |
  | All 20 teams (random) | | 73% | 40% | 17% | 8% | |

- **What it says** (for the tuning phase):
  - **Decision 4 holds for burst only.** Burst clears Act 1 above the random rate (58–66% against 40%) but wins nothing in Act 2. **Sustain and control never reach the boss:** they lose on day 4, where their ES-3 breaking points (Bog Crossing x0.8, Sentinel Gate x0.7–0.8, Cairn Road x0.7–0.9, transformed) are still below the fights' new strengths. As ES-3 concluded, the gap is in the heroes (sustain has no real makers until Edric and Severine; control's Garrote rarely transforms, Question HI), so it goes to the tuning phase rather than into the fights.
  - **The lean barely moves wins:** with it the plan group won Act 1 29% against 27% without; it doubled what the bot spent (68 shards a run against 35) and the relics it held (3.6 against 1.6). The good bot still spends under half of what it earns and takes few picks (as in phase 6), so items and relics reach its teams slowly; a run with the lean measures the bot's shopping as much as the build.
  - **Two of the four bad stand-ins aren't bad:** all melee (Aegisfang, Nightblade, Last Watch) wins Act 1 83% and the run 33%, and no makers wins Act 1 58%; only Glass is clearly bad. With six heroes, three melee fighters is a strong team, not a broken one. The bad group needs the real B-teams (their heroes aren't built) before it can say whether synergy matters.
  - **What came out of days 1–3 moved to day 4 and the boss**, not only to the boss and Act 2: 23 runs still end on day 4.
- **Dig In's rock** (a bug found in the first runs): a rock placed at the node, before the fight was chosen, could sit on the chosen fight's water, and the fight then refused its setup. `RunFlow.place_rock` now refuses water and the void once the fight is chosen (`rock_on_ground`), and the bots place the rock again; the player clicks another hex, as before.
- **Not changed:** no hero, path, item, or relic; the bench's fingerprints are the same.

## 8. Questions

- **EA. Day-1 fights:** *(Answered: Decision 9.)* new smaller encounters for day 1 only, or shrink them everywhere?
- **EB. The harder day-1 fight:** *(Answered: Decision 10.)* a new 1 Hollow Archer and 2 Rift Pups, or no harder option on day 1?
- **ED. The gate:** *(Answered: Decision 11.)* day-1 fights exempt from the 30-point split, with the Glass check as their gate?
- **EF. The three tank-only fights** (ES-3): *(Answered: Decision 14; the changes were tried and didn't help, so none shipped.)* give each a second question so a tankless plan has an answer? Proposed, each sized again so the tank team's breaking point stays where it is:
  - **Sentinel Gate:** one archer out of the Sentinel's shadow, so burst can reach and kill it first (Decision 5's "archers in the back: burst wins").
  - **The Hunt:** the Hunt Hounds lighter (less HP, more damage), so burst or control can thin the pack before it lands; the Alpha's pounce stays the tank's question.
  - **Witch Coven:** the Gloam Totem with less HP and a stronger Shield, so a burst that breaks it fast is an answer as well as a tank that walks past the Sentinel.
  Or leave them as the tank's fights, since every plan already has some.
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
14. **The three tank-only fights get a second question** (Question EF): Sentinel Gate an archer out of the wall's shadow, The Hunt lighter hounds, Witch Coven a lighter Totem with a stronger Shield. Measured in ES-3, none narrowed the gap, so the fights stay as built until ES-4's runs show whether the plans with their items can answer them.
15. **Day 3 has its own elites** (asked in ES-4, when the runs showed day 3 ending 56 of 120 good-bot runs): smaller day-3-only versions of The Hunt, Witch Coven, and Cairn Watch, each keeping its mechanic, sized like day 2 (Glass at least 85%, and at least half with the enemies 10% stronger); the full elites stay on day 5. Like days 1 and 2, they're exempt from the gate's 30-point split (every formation wins at these sizes). The other choices were the same elites weaker on day 3, the first elite on day 4, or day 3 as it was.
16. **Days 4 to 6 ramp to about 70%** (asked in ES-4, when day 3's own elites moved the wall to day 4: 46 of 120 good-bot runs ended there, Sentinel Gate and Cairn Road winning 32% of their fights): the normal fights of days 4 to 6 are sized for about 70% a fight for random teams in the good bot's runs, by their scale on every day they come (no day-4 copies). The ramp is day 1 about 95%, days 2-3 about 85%, days 4-6 about 70%, the boss 50-60%; the boss is raised only if Act 1 then lands above the old three's tuned 49%. The other choices were day-4 copies like days 1-3, waiting for the plan teams' runs, or leaving day 4 as it was.
