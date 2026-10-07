# The easy start (Act 1, days 1 and 2)

Status: **a build plan, for approval (2026-10-07).** The playtester's request after phase 8 part 4's bot runs: fix Act 1's opening before tuning anything else, because runs that end on day 1 spoil every other number (heroes, paths, deeds, synergy against bad teams). Questions are in section 6.

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

## 3. The proposal

1. **Day 1 has its own fights, smaller ones, with no flankers.** Fewer enemies at their usual strength, so a fight looks and plays the same:
   - **Pup Warren, day 1:** 4 Rift Pups (6 now).
   - **Ash Nest, day 1:** 2 Ashlings and 1 Rift Pup (3 and 2 now).
   - **A day-1 harder fight**, since Hounds and Archers has flankers: 2 Hollow Archers and 2 Rift Pups, say ("Archers' Rest"), sized the same way. With no harder fight on a day, ActDraw draws two easier ones, so this is optional.
   They're new encounters with `"days": [1]` (data, `encounters.json`), so the full fights stay on day 2 and later. Each is sized with the probe above until any team placed by the good bot wins about 95%.
2. **Days 2–3: one new threat at a time, sized to about 85%.** The Pack (the first flanker) and Hounds and Archers move to day 2 only, and day 2's fights are cut or scaled until the bot reaches about 85% with any team (Lurker and Ashlings, at 16% with a tank, needs the most). Day 3 stays the first elite.
3. **An out for tankless teams:** the first Pedlar of a run always shows at least one defensive item or relic (a ware or the relic slot), drawn from a list marked in the data (`"defensive": true`: Iron Filings, Warden's Chain, Hearthstone Shard, Tithe of Iron, Moth-Eaten Banner; Iron Skin, Warding Thread, Bulwark, Guard the Weakest). A small `Offers` rule and its test. The bots don't need to know: the good bot already judges buys by practice.
4. **Placement:** no bot change. Once the fights are sized, the bot wins 87–100% of them with a tank, so the remaining day-1 losses aren't its placement.
5. **Keep the difficulty, move it:** with the start fixed, rerun the good bot over all 20 teams, then raise the Act 1 boss (and if needed the day 4–6 fights and Act 2) until the overall win rate is back near today's 8%, random teams beat Old Mother Ash 50–60% of the time they reach her, and the old three's Act 1 doesn't get easier than its tuned 45–50%. The run report gets a **By team** line (runs, how far they got, won), so synergy and bad teams can be told apart.
6. **Then** Garrote and the other slow paths are looked at again on the new runs (`rebuild-phase8-heroes.md`, Question HI).

## 4. The sim runner's gate

The gate wants the best formation to win at least 30 points more often than the worst in every encounter. Day-1 fights sized to 95% for the bot may not split that far. Proposed: day-1 fights (`"days": [1]` only) report the split but don't fail the gate, since teaching how fights work is their job.

## 5. Parts

- **ES-1:** the day-1 fights and the gate's day-1 rule (data, `sim_report.gd`, tests).
- **ES-2:** days 2–3 resized (data), The Pack and Hounds and Archers to day 2.
- **ES-3:** the first Pedlar's defensive pick (`items.json`, `relics.json` flags, `Offers`, test).
- **ES-4:** the run report's By team; the good bot over all 20 teams; the Act 1 boss (and later fights) raised to keep the overall rate; the numbers recorded here.
- **ES-5:** Garrote and the slow paths read again; docs, HOW-TO-PLAY, playtest build.

## 6. Questions

- **EA. Day-1 fights:** new smaller encounters for day 1 (as proposed), or shrink Pup Warren and Ash Nest everywhere?
- **EB. A harder day-1 fight:** a new flanker-free one (2 Hollow Archers and 2 Rift Pups), or no harder option on day 1 (two easier fights)?
- **EC. The defensive pick:** the first Pedlar only, or every shop until the team holds one? And is the list in section 3 right?
- **ED. The gate:** day-1 fights exempt from the 30-point split, as proposed?

## Decisions

*(None yet.)*
