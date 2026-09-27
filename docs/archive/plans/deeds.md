# Plan: deeds (redesign step 3)

Step 3 of `docs/plans/fun-redesign.md`, built from `docs/plans/heroes-and-deeds.md` (section 4). Ranks now give slots; **deeds give power**.

## Rules

**Two deed tracks per hero**, each with a deed (a goal counted in fights) and **3 levels**:

| Track | Starts | Level 1 | Level 2 | Level 3 |
|---|---|---|---|---|
| **Calling** (`"calling"` in `data/heroes.json`) | The start of the run | A stronger innate | A choice of 2 unlocks | A capstone |
| **Specialization** (`data/specializations.json`) | The pick at rank B | The old rank-B parts | The old rank-A parts, or a new alternative | The old rank-S parts |

- **Progress carries over** between fights. Every fight counts, including a loss and a skirmish.
- **Levels land mid-fight.** When a goal is crossed, the level's parts turn on at once. The log says "vell reaches Lamplighter 1: …", a ✦ banner floats over the hero, and the parts are credited as "Lamplighter 1".
- **Level 2 is a choice.** Pick one of 2 options on the hero sheet, between fights. Until then the level waits, unspent. Fights aren't blocked, and the choice is for good.
- **Retraining** starts the new specialization's deed at zero and keeps the calling.
- Picking a specialization gives nothing until its level 1. That goal is about one fight's worth.
- **Parts** are the specialization part kinds (aura, grant, ability, basic_attack, replace_status). A later part with the same key replaces the earlier one, in its place. A calling part can replace an innate part (level 1 does). A specialization's keys can't reuse the hero's innate or calling keys.
- **Ranks** give only slots, stats, and the specialization pick at B. Specialization parts no longer unlock by rank.

## What a deed counts

`"deed": {"text", "counts", "filter"?, "goals": [3 rising numbers]}`. Always for the deed's own hero, from the combat log, in whole numbers. Relic effects never count; relic grants on the hero's items do.

| counts | What | Filters |
|---|---|---|
| `damage` | damage dealt (hits and damage over time) | `statuses`, `target_row`, `keyword` |
| `shield` | Shield given | |
| `healing` | HP restored | |
| `damage_taken` | damage taken from hits | `own_row` |
| `crits` | critical hits | `target_row`, `keyword` |
| `stacks` | status stacks applied | `statuses` |
| `fires` | item fires | `keyword` |

## Content

Deed goals come from measured rates. A calibration pass ran the run bot for 120 runs and averaged each hero's progress per fight. Goals are set so that:
- a calling reaches levels 1–3 after about 2, 6, and 14 fights
- a specialization reaches them after about 1, 4, and 10 fights

The bot only ever takes each hero's first specialization. The other 16 specializations' rates are estimates.

Callings (with the user's go-ahead, all built from the existing building blocks; step 5's event triggers can upgrade them):

| Hero | Calling | Deed | Level 1 | Level 2 options | Level 3 |
|---|---|---|---|---|---|
| Brannoc | Shieldbearer | Give Shield | Hearthguard answers at 60% HP | Shield Wall / Rally | Unbreakable |
| Wren | Bladedancer | Land critical hits | Opening Flurry lasts 10s | Opening Wounds / Keen Edges | Second Wind |
| Vell | Lamplighter | Heal your allies | Lantern Vigil also cleanses | Lantern Ward / Shared Light | Last Light |
| Odo | Hexbinder | Fire Spell items | Smoldering Hex also Poisons | Cinder Script / Quick Study | Wildfire Hex |
| Maren | Far Sight | Hit the back row | Marking Shot also Slows | Pinning Shot / Hunter's Eye | Rain of Marks |
| Pell | Card Sharp | Apply Blind, Poison, or Slow | Loaded Dice also Poisons | Marked Deck / Tainted Blade | The House Always Wins |
| Hesk | Gatewarden | Take hits in the front row | Gatekeeper's Toll rings again at 30s | Stonebound / Rebuke | Hold the Gate |
| Ysolde | Ashbringer | Deal Burn damage | Flashpoint again at 25s | Kindling / Ember Tongue | Firestorm |

Each of the 24 specializations got a deed that fits it (for example, Duelist: deal damage with Blade items; Trapper: apply Slow) and a new level-2 alternative next to its old rank-A part.

**A code addition:** aura and grant filters take `"keyword"`, so unlocks can say "your Blade items crit more". It's a filter key, not a new effect type.

## Snowballing (still open)

The user hasn't decided the snowball rules yet. Rules 1, 2, and 5 are in by construction:
- unlocks change how a hero plays
- goals rise level by level
- losses count

There is no catch-up bonus and no level cap. The run bot report measures:
- average calling and specialization levels at the end
- the level spread between each run's highest and lowest hero
- the clear rate by that spread
- the rank spread

Longer runs level more, so the clear rate by spread is confounded with run length. Read it with that in mind.

## Code

- `src/sim/defs/deed_def.gd`: the deed and what it counts.
- `src/sim/defs/deed_track_def.gd`: a track's levels and parts.
- `src/sim/setup/deed_setup.gd`: the progress a hero brings into a fight.
- `CombatSim._check_deeds`: counts each tick's log entries and applies levels. It reuses the part application that boss phases use.
- `FightResult.deeds` reports progress, which `RunFight` writes back.
- `RunHero` stores:
  - `calling_progress` and `calling_choice`
  - `spec_progress` and `spec_choice`
- `RunActions.choose_deed_unlock` makes the level-2 choice.
- The save version is 3.
- UI:
  - the hero sheet's deeds panel and choice buttons
  - the calling on draft cards
  - the "Deeds" summary after a fight
  - the ✦ level-up banner and log line

## Decisions (from the user)

- 3 levels per track; level 2 offers a choice: yes.
- Specialization parts: B, A, S become levels 1, 2 (with a new alternative), 3: correct.
- Callings use existing building blocks now, upgraded when step 5's triggers exist: option 1.
- Content: built directly, reviewed in the PR.
- Snowball rules: not decided yet.
