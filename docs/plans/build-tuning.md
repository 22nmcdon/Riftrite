# Build tuning

Status: **first draft (2026-10-06).** How to judge whether a path is too weak or too strong. Tuning is per build, not per hero: a path is judged by its **type**, its **floor**, and its **ceiling**. Teams and test groups: `test-teams.md`; builds: `build-map.md`; apex targets: `apexes.md`.

## 1. Path types

| Type | What it is | Floor | Ceiling |
| --- | --- | --- | --- |
| **Self-sufficient** | Strong by itself; needs nothing from the team | High | Modest |
| **Engine** | Weak alone; strong once its build comes together | Low | High (set by the rule in section 3) |
| **Enabler** | Makes the team stronger; judged by its teammates | Low to middling | Judged by **lift** (section 2) |
| **Long-game** | Weak early on purpose (money paths); pays off late | Low in Act 1 | Judged by Act 3 and endless |

## 2. Targets

All numbers are the **Act 1 win-rate gain from transforming**, in points (the team's win rate after the transform minus the same team's before). Placeholders until the bot has run.

| Type | Floor (neutral team) | Ceiling (its build team) |
| --- | --- | --- |
| **Self-sufficient** | +25 to +35 | +35 to +45 |
| **Engine** | +5 to +15 | Set by the engine rule (section 3). **Until measured: +45 to +55** (about +10 above self-sufficient) |
| **Enabler** | +10 to +20 alone | **Lift:** its synergy team wins +10 to +20 more than the same team with the enabler swapped for a self-sufficient path of the same hero |
| **Long-game** | +0 to +10 | Its Act 3 win rate and endless depth land within ±10 of a self-sufficient path's |

**How each number is measured:**
- **Floor:** the path on a neutral team (random teammates, random vows, no shop lean).
- **Ceiling:** the path in its synergy team from `test-teams.md`, with the shop lean on.
- **Lift (enablers):** the synergy team as listed, against the same team with the enabler swapped for a self-sufficient path of the same hero.

## 3. The engine rule

An engine's ceiling isn't a fixed number. It's set so that **its average run matches a self-sufficient path's average run**:

> Engine average = floor + (share of runs where its build comes together) × (ceiling − floor)

| Build comes together in… | Engine ceiling needed (floor +10, self-sufficient average +35) |
| --- | --- |
| 80% of runs | about +41 |
| 60% of runs | about +52 |
| 50% of runs | about +60 |

- **"Comes together"** means: by its transform, the team has a maker for the engine's build (a teammate or a relic) and at least 2 of its key items from `test-teams.md`.
- **The bot measures it:** in the random group (no lean), count the runs with the engine where its build came together by the transform.
- **Hard cap:** no transformed path at its ceiling may beat the apex tier shift. A first-transform team at its ceiling must not win as often as an apex team is meant to (`apexes.md`, "Tier shift"). If an engine needs more than that to be worth it, make its build come together more often (more makers, cheaper key items) instead of raising the ceiling.
- **Not above the math either:** a ceiling far above what its odds justify makes forcing that build the best play every run, and self-sufficient paths become the fallback. Endless depth shows this first.

## 4. Base kits first

Before judging paths, every hero's **base kit** should land its team within **±10 points** of the original three's team win rate in Act 1. A base kit far below the band inflates every one of its paths' gains (a path looks strong because the base was weak), so fix the base before tuning the paths.

## 5. Flags

| Flag | What it means | What to try |
| --- | --- | --- |
| **Floor above its type's ceiling** | Too strong in any team | Tune it down first, before anything else |
| **Engine ceiling less than 10 above its floor** | The build doesn't pay off | Raise the build-dependent part, not the base numbers |
| **Engine average well below self-sufficient** | Not worth the risk | Raise the ceiling (within the cap) or make the build come together more often |
| **Enabler lift under +5** | It isn't enabling anything | Check that its teammates actually use what it makes |
| **Enabler floor above +25** | It's really self-sufficient | Move its power from itself into what it gives the team |
| **Long-game path ahead of self-sufficient in Act 1** | Greed pays too early | Push its payoff later |

## 6. Every path's type

| Hero | Path | Type | Why |
| --- | --- | --- | --- |
| **Maren** | Trapper | Enabler | Roots that others cash in |
| | Volley | Self-sufficient | Split arrows deal damage by themselves (and multiply on-hit effects) |
| | Deadeye | Self-sufficient | Long-range crits with no setup |
| **Brannoc** | Hearthwall | Enabler | Protects the back line |
| | Ironbrand | Self-sufficient | A bruiser who fights alone |
| | Last Watch | Self-sufficient | Holds by himself; healers help but aren't needed |
| **Vell** | Lanternbearer | Enabler | Healing |
| | Wardweaver | Enabler | Shield maker |
| | Vigil Keeper | Self-sufficient | Sunfall deals damage by itself |
| **Ilse** | Furnace | Engine | Needs attack speed and steady Burn from the team |
| | Wildfire | Self-sufficient | Burning ground does the work |
| | Ember Choir | Enabler | Sets allies' hits on fire |
| **Tamsin** | Nightblade | Self-sufficient | Makes her own Stealth and cashes it in |
| | Headhunter | Engine | Needs Marks from others |
| | Garrote | Engine | Needs Roots and Stuns from others |
| **Garrow** | Aegisfang | Engine | Strong with outside Shields (Edric, Vell, Shield relics) |
| | Chainwarden | Self-sufficient | His drag protects any team; retyped from enabler after its first measure (lift about 0, `rebuild-phase8-heroes.md` Decision 13) |
| | Spitemail | Self-sufficient | Returns damage by itself |
| **Aldous** | Chorister | Enabler | Mana for allies |
| | Windcaller | Enabler | Buffs ranged allies |
| | Bellwarden | Enabler | Marks the field for payoffs |
| **Hob** | Hoarder | Long-game | Grows with shards held |
| | Fence | Long-game | Grows with shards spent across the run |
| | Bounty Hunter | Enabler | A Mark maker that also pays |
| **Severine** | Bloodglut | Self-sufficient | Grows on her own lifesteal |
| | Plaguebearer | Self-sufficient | Makes her own Poison and feeds on it |
| | Hemomancer | Engine | Needs healing to keep her above 50% HP |
| **Edric** | Aegis | Enabler | Shields for the team |
| | Tithe-Collector | Long-game | Shards after won fights |
| | Psalmist | Enabler | Mana from broken Shields |
| **Ottilie** | Catalyst | Engine | Needs Burn and Poison from others |
| | Transmuter | Long-game | Shards from double-afflicted kills |
| | Apothecary | Enabler | Mana vials for allies |
| **Lucan** | Mirrorwright | Self-sufficient | His copies fight by themselves |
| | Veilweaver | Enabler | Hides allies; payoff is their first strike |
| | Puppeteer | Engine | Needs summons on the field |
| **Kestra** | Cinderhound | Self-sufficient | Her hound burns by itself |
| | Serpent-Keeper | Self-sufficient | Her viper poisons by itself |
| | Packleader | Engine | Needs other summons |

**Counts:** 14 self-sufficient, 8 engines, 13 enablers, 4 long-game. A path's type can change in tuning: an enabler whose floor stays above +25 is really self-sufficient (section 5).

## 7. Worked example: Garrow (first bot run)

| Measured | Type | Verdict |
| --- | --- | --- |
| **Base Garrow:** his team wins 0%, against 22% for the original three | Base kit | Outside the ±10 band. Fix the base kit first; it inflates every path's gain below |
| **Spitemail:** +75 | Self-sufficient | About 30 above its type's ceiling. Too strong in any team; tune it down |
| **Aegisfang:** +7 | Engine | A fine floor. The open question is its ceiling in #7 Bulwark |
| **Chainwarden:** +27 | Enabler | A bit high alone. Check its lift in #8 Whirlpool before cutting it. **Measured:** lift about 0 (it wins by itself), so retyped self-sufficient and tuned to that band |

## 8. Apexes

The same types apply at apex, with the tier shift (`apexes.md`) as the target for every type. An apex keeps its path's type unless its section says otherwise.
