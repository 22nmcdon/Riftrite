# Rebuild plan, part 4: the run

Status: **agreed in discussion (2026-09-27), not built.** Part of the from-scratch rethink: part 1 is `docs/plans/rebuild-heroes.md`, part 2 `docs/plans/rebuild-arena.md`, part 3 `docs/plans/rebuild-enemies.md`. Numbers are placeholders to tune.

**Why:** items and essences are gone, and heroes only grow through deeds. So the run has to be built around one question: **what does the player decide between fights?**

## Decisions

- **The fight card doesn't say which paths a fight is good for.** Players work that out from the enemies they see.
- **Relics stay, and are rarer** (about 3–5 per run), and every relic has a real cost.
- **Duo bonds come from paths**, not from heroes or camp (section 6).
- **The cozy side of the game is gone.** The setting is the rift: dark and dangerous, with no warm Guildhall to come home to. Names and camps follow that, and **the art gets a complete rehaul** (its own part of the build order).
- **Items and shops are gone, and there's no currency to start with** (section 8). Camp options are free: you just pick one.

## Goals

- **Every step between fights is a real decision**, and most of them feed back into your heroes' deeds.
- **Transformations land at satisfying moments**, not all at once and not too late.
- **Fewer systems:** nothing that recreates the old item treadmill.

## 1. Shape of a run

- **3 acts, each ending in a boss.** The vertical slice is Act 1 only.
- **Act 1 is about 7 days:** normal fights, elites on 2 of the days, and the boss on the last day.
- **About 45–60 minutes** for a full three-act run.

## 2. The start of a run

1. Choose your three heroes (with a roster of 3, it's always the same three until hero 4 exists).
2. **Vow each hero to a path** (see the heroes plan).
3. Day 1 begins.

## 3. A day

1. **Camp:** pick 1 option from the camp's offer (section 4).
2. **Choose the day's fight** from 2 options, known from the start of the act.
3. **Place your heroes** in the arena, and fight.
4. **After the fight:** deed progress comes from what your heroes did. Any waiting upgrade picks, transformations, or apex vows come up now.

## 4. Choosing fights feeds your heroes

Deeds count what heroes actually do, so **which enemies you fight decides which deeds fill.** A swarm suits Volley Maren's split shots and Ironbrand's cleave; an archer nest gives Deadeye long sightlines and Hearthwall arrows to block; a hound pack gives Hearthwall hits to take for allies.

The fight card shows the enemies and their threats, **not** which paths they suit. Choosing a fight means weighing difficulty, the deeds you're pushing, and the enemies you'd rather avoid.

## 5. Camp

One choice before each fight. **Different places offer different menus**, so where you camp shapes what you can do. Places for Act 1 (names are placeholders): a **Waystone**, a **Ruined Chapel**, a **Hunter's Blind**, a **Rift Scar**.

### Camp options

**Hero growth**

- **Train:** extra deed progress for one hero.
- **Spar:** two of your heroes practice against each other; both get a little deed progress.
- **Mentor:** move some deed progress from one hero to another.
- **Meditate:** see a hero's next upgrade choices early, so you can plan fights around them.
- **Study:** pick one upgrade from a hero's path pool; it's guaranteed in their next offer.
- **Bloodied Oath:** one hero takes a cost for the next 2 fights (less HP, say) in exchange for a big deed boost.

**Information and route**

- **Scout:** reveal the next 2 days' enemy positions and specializations.
- **Map the Rift:** swap one of tomorrow's fight options for a different fight.
- **Track the Elite:** learn the next elite's mechanic early, or choose which elite you'll face.

**The arena**

- **Dig In:** place a barricade (a rock) in your zone for the next fight.
- **Lay Traps:** place one hazard in the enemy's zone for the next fight.
- **Choose the Ground:** pick the rock layout for the next fight from 2 options.

**Risk and reward**

- **Hunt:** fight a small optional pack right now for extra deed progress. Losing doesn't count as a loss.
- **Rift Tear:** the next fight gets an enemy upgrade, but winning gives a relic choice.
- **Dare:** accept a challenge for the next fight ("win without Vell falling") for a reward.

**Safety**

- **Rest:** the next loss doesn't count toward the two-loss limit.
- **Fortify:** your heroes start the next fight with a small Shield.

**Relics**

- **Shrine:** a relic with a real cost.
- **Temper:** swap one of your relics for a random relic of the same rarity.

**Events**

- **Rift events:** a short choice with a trade-off, in the rift's grim tone.

Which places offer which options, and how many options each camp shows (2 or 3), are tuning values.

## 6. Duo bonds come from paths

- **A duo bond links two paths of two different heroes.** When both heroes follow those paths, **both get a boost**, one that ties their paths together.
- **The vow previews it:** when you vow two heroes to bonded paths, the bond shows as "?", and its name is revealed once found.
- **It switches on when both heroes have transformed** into those paths (a proposal; see open questions).
- **Found bonds go in the Codex.**
- **Not every pair of paths has a bond.** With 3 heroes and 3 paths each there are 27 cross-hero pairs; about 1 bond per path (roughly 9) is plenty for the slice.

Examples:

| Bond | Paths | What each gets |
| --- | --- | --- |
| **Sentry and Sniper** | Hearthwall Brannoc + Deadeye Maren | Brannoc's wall gains mana when Maren hits from 5+ hexes. Planted behind his wall, Maren gets +1 range |
| **Snare and Cleave** | Ironbrand Brannoc + Trapper Maren | Brand Slam aims for rooted enemies and deals +20% to them. Enemies knocked into her snares stay rooted 1s longer |
| **Light and Iron** | Wardweaver Vell + Hearthwall Brannoc | Her Shields on Brannoc are 25% stronger. Damage he takes for allies charges her mana |

## 7. Relics

- **Team-wide rule changers**, from elites, the boss, the Shrine, and Rift Tear.
- **Every relic has a cost.** Example: *Ember Heart*: all Burn you apply is doubled, but your healing is 20% weaker. No pure upsides, which also helps with difficulty.
- **About 3–5 per run.** A relic can be turned down, but once taken it stays.

## 8. Currency: none, to start

**Decided: start with no currency.** Camp options are free. If playtesting shows one free pick per camp isn't enough of a decision, these are the fallbacks:

- **Gold:** earned from fights, spent on stronger camp options.
- **Supplies:** each camp gives a few hours, and options cost 1–3 hours (Train is cheap, Rift Tear expensive); fights earn more.



## 9. Pacing

Targets for Act 1, with 3 heroes fighting about 8–9 fights:

| When | What happens |
| --- | --- |
| **Start** | Choose heroes, vow each one |
| **Around days 3–4** | The first transformation (the hero whose deed you pushed hardest) |
| **By the boss** | All three transformed, with 1–2 upgrade picks each |
| **Acts 2 and 3** | More upgrade picks, the apex vows, and the apexes by the Act 3 boss |

Choosing fights that suit a deed, and camp options like Train, let the player control this pace.

## 10. Losing

- **A lost fight replays the day; the second loss ends the run.**
- **Deed progress from a lost fight still counts.**
- **Rest** at camp buys a safety net.

## 11. Between runs

- **Difficulty tiers** (see the enemies plan): the rift learns, specialized enemies sooner and more often, longer deeds, and more.
- **Unlocks:** new heroes (once hero 4 exists), then new camp options, places, and relics into the pool.
- **A Codex:** paths and apexes seen, duo bonds found, enemy specializations met, relics found.
- **Still no stat unlocks.**

## What this removes

Gold, shops and the Caravan, items, the stash, rewards picks of items, the Forge, the Vault and keys, the old stop nodes, Legendary items, Oathbinding, the Guildhall hub, and the cozy tone.

## Open questions

- **When a duo bond switches on:** when both heroes transform, or already (weakly) when both are vowed?
- **Camp menus:** which places offer which options, and 2 or 3 options per camp?
- **Art direction:** the rehaul starts with a new style guide (replacing the old look, now `docs/archive/ui-asset-design.md`); its direction is still to be set.