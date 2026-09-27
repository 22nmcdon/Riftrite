# Plan: heroes, ranks, and deeds

Status: **approved in direction (2026-09-26); some numbers still open (see Decisions at the end).** Part of the fun redesign (`docs/plans/fun-redesign.md`, section 1). This file goes into more detail on heroes, with a full section on snowballing. When it's approved, move the rules into `docs/design.md` and `CLAUDE.md`, and give each part its own build plan.

## The short version

- A run starts with **three heroes, and you keep them for the whole run.** No buying or recruiting heroes.
- **All three always fight.** Backup and the bench are removed.
- Heroes grow in two ways:
  - **Ranks (C → S) control slots.** You get a limited number of rank-ups and decide who gets them.
  - **Deeds control what a hero can do.** Heroes level up during fights by doing what their character and specialization want, and each level unlocks a locked feature.

| Growth | How you get it | What it gives |
| --- | --- | --- |
| **Ranks** (C → B → A → S) | Rank-ups you hand out after elites and bosses | Slots, and the specialization choice at B |
| **Deeds** (hero levels) | Doing what the hero and their specialization want, in fights | The hero's locked features |

---

## 1. The team draft

- Pick heroes one at a time: **1 of 3, three times.**
- Each later offer shows how that hero fits the ones already picked, for example "shares Burn with Ysolde".
- Duo bonds (section 6) show as "?" once one half of the pair is picked.
- This teaches players the affinity keywords before the first shop, and makes the start of a run a small puzzle instead of a menu.

**Why not pick 3 from 6 at once?** It's faster, but flatter: it's easy to just grab the three best heroes.

## 2. The team in a fight

- **All three heroes always fight.** Backup and the bench are removed.
- Each hero's current Backup effect can become an **innate passive**, so that content isn't wasted.
- The player places heroes in the **front and back rows** freely. The game warns if nobody stands in front.
- Fallen heroes still always come back after a fight.

## 3. Ranks: rank-ups as a resource

- After each **elite** and each **boss**, you get **one rank-up to give to the hero of your choice.**
- Across a three-act run there are about **6** of them. Taking all three heroes to S would take 9, so you choose between carrying one hero and spreading the ranks.
- The Caravan never sells heroes, and duplicate heroes no longer combine.
- Ranks add slots. Starting values to tune:

| Rank | Basic attack | Abilities | Passives | Also |
| --- | --- | --- | --- | --- |
| C | 1 | 2 | 1 | |
| B | 1 | 3 | 1 | choose a specialization |
| A | 1 | 3 | 2 | |
| S | 1 | 4 | 3 | Oathbinding |

A C-rank team holds 12 items; a maxed team holds 24.

Ranks still boost stats (+25% per rank, compounding, as now).

## 4. Deeds: heroes level up by playing to type

Each hero has **deeds**: goals counted during fights, like "Brannoc: block 600 damage with Shield." Progress carries over from fight to fight. Reaching a threshold gives the hero a **level**, and each level unlocks one of their locked features.

### Two deed tracks per hero

| Track | Active from | Its levels unlock |
| --- | --- | --- |
| **Calling** | The start of the run | The hero's own features: an empowered basic attack, a stronger innate passive |
| **Specialization** | Choosing a specialization at rank B | The specialization's locked potential |

This replaces "a specialization unlocks more at ranks A and S." **Ranks now give slots, and deeds give power.**

### How deeds work

- **Levels land mid-fight.** When a threshold is crossed, the unlock turns on right away, with a banner. That's the "growing during the fight" moment. Infusions already level mid-fight the same way.
- **Some levels offer a choice:** pick 1 of 2 unlocks. This adds a decision without adding a menu. The choice is made between fights; until then the level waits, unspent.
- **Deeds count everything the hero does**: basic attack, abilities, and passives. So a deed tells the player what to buy: Brannoc's deed wants Shield items, which points at the Shield keyword and the right shop types.
- **Thresholds grow each level**, and scale by act, so a hero reaches about **2 levels per act**.
- **Retraining** switches the specialization. The new specialization's deed starts from zero; the calling track is kept.

### Readability

- Deed progress shows on the hero card: "Block damage with Shield: 340 / 600."
- The post-fight screen lists each hero's deed progress from that fight.
- The level-up banner says what unlocked, and the combat log credits the deed.

### Code notes

- Deeds are counted from sim events, **deterministically and in integers**, and written back after the fight like infusion XP.
- The Legendary "grows by use" path already counts hits this way, so the code can be shared.
- A level that lands mid-fight turns on through the same parts system specializations use (auras, grants, abilities, basic-attack changes).
- Deeds and their unlocks are data: `data/heroes.json` gets the calling deed, and `data/specializations.json` gets a deed per specialization.

### Example callings (placeholders)

| Hero | Class | Calling deed | Example unlock |
| --- | --- | --- | --- |
| Brannoc | Warden | Block damage with Shield | Shield Bash also gives Shield to the ally behind him |
| Hesk | Warden | Take hits while in the front row | Enemies that hit him take Thorns |
| Wren | Striker | Land crits | Her crits apply Bleed |
| Pell | Trickster | Apply statuses (Blind, Poison) | Every 3rd status he applies is doubled |
| Maren | Ranger | Hit the back row | Her first shot each fight Marks its target |
| Odo | Arcanist | Fire Tome abilities | Tome cooldowns −10% |
| Ysolde | Arcanist | Deal Burn damage | Her Burn spreads when a target dies |
| Vell | Mender | Heal allies | Overhealing becomes Shield |

Specialization deeds follow the same pattern. For example, Wren's Nightstalker might count Bleed applied, while her Duelist counts hits on a single target.

## 5. What each hero needs

- **Stats and a built-in basic attack** (already there).
- **2 affinity keywords.** Matching items get a bonus. Placeholders:

  | Hero | Affinities |
  | --- | --- |
  | Brannoc | Shield, Food |
  | Hesk | Shield, Thorns |
  | Wren | Blade, Bleed |
  | Pell | Crit, Poison |
  | Maren | Bow, Frost |
  | Odo | Tome, Hex |
  | Ysolde | Burn, Ember |
  | Vell | Heal, Cleanse |

  Some overlap on purpose (both Wardens have Shield) creates natural pairings in the draft.
- **A starter ability item** that fits their affinities, so day 1 has a direction.
- **A calling deed.**
- **3 specializations that pull different ways**, each with its own deed. At least one should shift the hero's role (for example, a damage specialization for a Warden), so a team drafted without a healer or tank can still adapt.

## 6. Duo bonds

Hidden, named synergies between two specific heroes on the same team.

- Example: Vell + Hesk, **"The Gate and the Lantern"**: Vell's heals also give Shield to whoever Hesk is guarding.
- They show as "?" during the draft once one half is picked, and are saved in the Codex when found.
- Keyword overlaps between heroes give the systemic version for free.

---

## 7. Snowballing

**The risk:** a hero who is already doing well does more in each fight, so they fill their deed faster, level faster, and do even more. Rank-ups make it worse: if you give your ranks to one hero, that hero gets more slots, does more, and levels even faster. The two growth systems can stack into one runaway hero.

Some snowball is fine; it's part of what makes a build feel like it's "coming online." The problem is when:

- one hero ends the run at max level while the other two are still near the start, so the team feels like one hero plus two passengers, or
- the outcome of a run is decided by day 2, because whoever got ahead early can't fall behind.

### Ways to keep it in check

1. **Unlocks change how a hero plays, not how big their numbers are.** "Wren's crits apply Bleed" opens a new direction; "+20% damage" just widens the gap. This is the most important rule.
2. **Thresholds grow each level.** Each level costs more than the last, so a hero who's far ahead slows down while the others catch up.
3. **Catch-up bonus.** A hero with fewer deed levels than the team's highest earns deed progress faster (for example, +50% per level behind). The team stays roughly even without a hard cap.
4. **A level cap per act.** A hero can reach at most a set number of levels in each act (for example, 2 in Act 1, 4 by the end of Act 2). Extra progress is kept for the next act, so it isn't wasted.
5. **Losing still counts.** A lost fight still counts deed progress, so a struggling team isn't also locked out of growth.
6. **Deeds for support roles count what they absorb or enable, not only kills and damage.** Hesk's "take hits" and Vell's "heal allies" fill up even when the damage dealers are the ones winning fights. Deeds shouldn't all reward the same hero.

### How to measure it

Add these to the run bot report (`tools/run_runner.gd`):

- **Level spread:** the gap between each run's highest-level and lowest-level hero, at the end of each act.
- **Win rate by level gap:** do runs with a big gap win more often? If so, "carry one hero" is the dominant strategy.
- **When the run is decided:** the win rate of runs split by how the team was doing on day 2. If day-2 standing predicts the result almost perfectly, the snowball is too strong.
- **Rank-up spread:** do the best runs give all their rank-ups to one hero?

Start with rules 1, 2, and 5, which are cheap and don't feel like rubber-banding. Add 3 or 4 only if the numbers show a problem.

---

## What this removes or changes in the code

- **Removed:** buying heroes; ranking up from duplicate heroes; Backup, the bench, and items' backup modes.
- **Changed:**
  - `RunFlow` gets the team draft and rank-ups to hand out.
  - `data/heroes.json` gains affinities, a starter item, slot counts per rank, and a calling deed.
  - `data/specializations.json` gains a deed per specialization, and its locked potential moves from ranks to deed levels.
  - The sim counts deed progress and applies level unlocks mid-fight.
  - The UI shows deed progress on hero cards and after fights, and the level-up banner.
- **Unchanged:** the deterministic, integer-only sim; content as data; the combat log rule; specializations at rank B; Oathbinding at S.

## Open questions

- **Levels per track:** how many levels do the calling and specialization tracks each have?
- **Choices:** which levels offer a choice of 2 unlocks?
- **Pace:** is about 2 levels per act right?
- **Rank-ups:** is 6 per run right, and do they come from elites and bosses only?
- **Slot counts per rank:** are 2 + 1 at C and 4 + 3 at S right?
- **Snowball rules:** start with rules 1, 2, and 5 only, or build the catch-up bonus in from the start?

---

## Decisions (2026-09-26)

**Decided:**
- **The team, the draft, deeds, and duo bonds:** approved as written.
- **Class traits are replaced** by shared affinities and duo bonds. With three heroes from five classes, class traits would rarely trigger.
- **Backup is removed completely:** the bench, items' backup modes, the "Legendaries must have a backup mode" rule, `benched` specialization parts, and resonance counting backup heroes. Each hero's Backup effect becomes their innate passive. A few of the best backup modes may come back later as passive items.

**Step 1 answers (2026-09-26), built in step 1:**
- **Rank-ups:** one per **elite** win ("for now; this might change later"). That's 2 per act and 6 per run, which is less than the 9 needed to take everyone to S, so it stays a choice. The boss keeps its Legendary relic choice. The rewards screen offers the rank-up with a button per hero; a hero reaching B picks a specialization.
- **The 5 aura items** (items whose only job was an aura) became **passives**.
- **Innates** should be **pretty unique** to each hero. Some reuse a Backup effect, but not all: Brannoc's Hearthguard (shields an ally who drops below 40%), Wren's Opening Flurry (faster basic attacks for the first 6s), Vell's Lantern Vigil (a heal every 5s), Odo's Smoldering Hex (Burn every 6s), Maren's Marking Shot (Bleed on the back row every 6s), Pell's Loaded Dice (Blind every 6s), Hesk's Gatekeeper's Toll (a shield for every ally at the start), and Ysolde's Flashpoint (3 Burn on every enemy at 10s). Their strength is a first pass; the sim shows most contribute 1–3% of hero output, to tune with deeds (step 3).
- **Old saves may break:** the save version is now 2, and version-1 saves are refused.

**Step 3 answers (2026-09-27), built in step 3 (`docs/plans/deeds.md`):**
- **Levels:** 3 per track, and level 2 offers a choice of 2 unlocks: yes.
- **Specializations:** the old B, A, S parts become deed levels 1, 2 (next to a new alternative), 3: correct.
- **Callings** use the existing building blocks now; the example unlocks that need new triggers (Thorns, spread on death, overheal to Shield, every 3rd status) wait for step 5.
- **Content** (8 callings, 24 specialization deeds and alternatives) was built directly and is reviewed in the PR.
- **Snowball rules:** not decided yet. Rules 1, 2, and 5 are in by construction; the run bot report measures the level spread.

**Still open:**
- **Snowballing:** whether to add the catch-up bonus (rule 3) or a level cap per act (rule 4). The run bot report now measures the level spread to decide from.
