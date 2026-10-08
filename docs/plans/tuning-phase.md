# The tuning phase (all six heroes and the acts)

Status: **a build plan, approved (2026-10-08; Decisions 1–10); T-1 and T-2 built.** Order: T-2 (the bot) and T-1 (the relics), then T-3 onward. The phase `rebuild-phase8-heroes.md` named next: tune all six heroes and the three acts at once, starting from what `easy-start.md`'s runs left (ES-4 and ES-5) and the playtester's relic additions (`changes-plan-relics.md`, 2026-10-08, applied to `relics/`). Questions are in section 6.

## 1. Where it starts

From the good bot's runs over all 20 teams after the easy start (`easy-start.md`, "Built in ES-4" and "Built in ES-5"):

| What | Now |
| --- | --- |
| Act 1 (random teams) | 40% won; 87 of 120 runs reach Old Mother Ash, 56% of them win her |
| Act 2, Act 3 | 40% and 50% of the runs that reach them |
| The run | 8% |
| Plan teams (12 runs each, with the lean) | tank 58% Act 1, 25% the run; burst 58%, 0%; **sustain and control 0%** (they lose on day 4) |
| Bad stand-ins | Glass 8% Act 1; all melee 83% (not bad); no makers 58% |
| Slow paths | Garrote 5% transform, Headhunter 30%, Windcaller 35% |
| The bot | spends 44 of 146 shards a run and takes about half a pick per hero |

## 2. What the playtester decided (2026-10-08)

- **Half-plans aren't whole plans** (Decision 1): a team of only sustain, or only control, isn't meant to be as strong as one with damage and a tank. It's much harder, and works only with the right relics and items. This replaces `easy-start.md`'s Decision 4 ("about the random-team rate when the build comes together").
- **Thirteen new relics** (Decision 2; `changes-plan-relics.md`, applied to `relics/`; the file says twelve, but its tiers add 3 common, 5 rare, 2 epic, and 3 legendary): four for sustain (Soothing Salve, Thorned Bandage, Full Vigor, Unending Vigil), eight for control (Weighted Net, Snare Wire, Heavy Pommel, Dulled Shackles, Choking Hold, Shackle Engine, Iron Garden, Stillwater Seal), and one for damage against swarms (Splinter Shot). Iron Garden replaces the proposed Huntsman's Horn.

## 3. The targets

| Group | Target | How it's measured |
| --- | --- | --- |
| Random teams (all 20) | reach Act 1's boss about 73%, win Act 1 40–49%, win the run about 8% (Decision 3's reference) | the good bot, 120 runs |
| Synergy plans with damage (tank + damage, burst) | above random | `--test-teams=plan`, with the lean |
| Half-plans (pure sustain, pure control), with the lean | reach Act 1's boss about 70%, win Act 1 about 20–25%, win the run about 2–4% (Decision 3) | `--test-teams`, with the lean (now holding the new relics) |
| Half-plans, without the lean | reach the boss about 50–60%, Act 1 about 5–10%, the run about 0–1% (Decision 3) | `--test-teams --no-lean` |
| Bad teams | below random | `--test-teams=bad`; two of the four stand-ins aren't bad (section 5, part T-5) |
| Paths | every path transforms by the boss in most runs that reach it | By path |

## 4. Parts

- **T-1: the thirteen relics.** Data where the sim already has the pieces; the new pieces where it doesn't (section 5). Each relic gets its card text, numbers line, icon, and a test; the chaos fight picks up the new pieces; no fight without them changes (the bench's fingerprints stay). The plan teams' leans in `tools/test_teams.json` take the new relics.
- **T-2: the bot's shopping** (Question TD). The good bot spends a third of what it earns and takes few picks, so items, relics, and cards reach its teams slowly; every number below leans on that. Find why (practice fights all-or-nothing early, so a buy's gain reads as zero) and fix it in the bot, not the game.
- **T-3: the slow paths.** Garrote, Headhunter, and Windcaller (Question HI): their deeds and tastes, by the builds report and runs.
- **T-4: the heroes.** By hero and by plan from the runs: bring each hero's runs won into a band of the others (Tamsin 13% and Aldous 5% now), with the builds report's floors and ceilings as the guide (`build-tuning.md`).
- **T-5: the test teams.** Bad stand-ins that are bad with these six (Question TE); the half-plans measured against Decision 1.
- **T-6: the acts.** Act 1 to the random target (the boss only if it lands above 49%, `easy-start.md` Decision 16), then Act 2 and Act 3 for the runs that now reach them.
- **T-7: docs, HOW-TO-PLAY, playtest build.**

## 5. The relics' sim work (T-1)

What each needs, from what's built:

| Relic | Built pieces it uses | New |
| --- | --- | --- |
| Soothing Salve | a `heal_bp` aura | none |
| Weighted Net | `on_holder_hit` `from_ability`, `once` | none (habits aren't signatures, so they don't set it off) |
| Heavy Pommel | `on_holder_hit`, once per enemy (Decision 5: the first hero to hit it) | **a once-per-enemy mark shared by the team** |
| Choking Hold | `on_holder_hit` `vs` Rooted or Stunned, `mana_drain` | none |
| Shackle Engine | a kit mod's change limited to some statuses (Root and Stun +30% duration) | **held enemies gain no mana** (a hero rule, like the built ones in `SideRules`) |
| Iron Garden | `on_status` (Root, Stun) on each hero, a whole-fight stacking boost on all heroes | none, if each hero's own holds count (Question TB) |
| Unending Vigil | `on_interval` (1s), a whole-fight stacking boost | **a condition "above an HP share"** |
| Full Vigor | an aura `"while": "state"` | the same condition |
| Dulled Shackles | `damage_reduced_bp` | **"vs" on the attacker, lingering 2s after its hold ends** |
| Thorned Bandage | `on_heal` (the healed hero) | **damage as a share of the event's amount**, with no crit and no lifesteal |
| Splinter Shot | `on_holder_crit` | the same share-of-the-event damage, on an enemy within 1 hex of the target, never a crit, never setting itself off |
| Snare Wire | Root | **a trigger: an enemy first comes within 1 hex of a hero** (once per enemy) |
| Stillwater Seal | crit damage `vs` a condition | **Burn's stack loss skipped while the enemy is held** (Bleed never fades; nothing applies Poison yet) |

So seven new pieces: the team's once-per-enemy mark, the hero rule for mana, the above-HP condition, the lingering attacker condition, damage from an event's amount, the enemy-steps-near trigger, and DoT that holds while held. Each is skipped by a fight that doesn't use it.

### Built in T-1

All thirteen relics are data in `data/relics.json`, with two whole-fight boosts in `statuses.json` (`vigilant`, `iron_garden`, +1% and +2% ATK and MGK a stack). The seven new pieces, each skipped by a fight that doesn't use it (the bench's fingerprints are unchanged):

- **Plain damage** (`EffectDef.plain`): never a crit and never lifesteal, so Thorned Bandage can't loop with lifesteal and Splinter Shot can't set itself off. Both take a share of the event's amount (`amount_bp_of_damage`, which `on_heal`, whose amount is the HP healed, now takes too).
- **Once per enemy** (an event's `"once_per_enemy"`): a mark the team shares (`CombatSim.once_marks`, a lookup keyed by the passive and the enemy, never iterated). Heavy Pommel's Stun goes to the first hero to hit each enemy (Decision 5).
- **`on_enemy_near`** (a timed trigger, `near_hexes`): an enemy first coming within that reach of the holder, center to center (Question TF, taken as 1 hex until the playtester says otherwise); once per enemy for each hero, or for the team with `once_per_enemy` (Snare Wire).
- **`above_hp_pct`** (`UnitCondition`): Full Vigor's aura (`"while": "state"`) and Unending Vigil's `on_interval` holder check.
- **Three hero rules** (`SideRules`):
  - `holds`: Roots and Stuns from heroes on enemies last `time_bp` longer, and with `no_mana` a held enemy gains no mana, from regen or otherwise (Shackle Engine).
  - `held_weak`: a held enemy's hits on heroes deal `power_bp` less (a power bonus, noted "dulled"), and for `linger_ms` after its last hold ends (`UnitState.hold_ended_at`; Dulled Shackles).
  - `held_keeps_burn`: Burn loses no stacks while its enemy is held (Stillwater Seal; Bleed never fades, and nothing applies Poison yet).
- **Small additions:** Weighted Net reads `on_holder_hit`'s `from_signature`, so habits don't set it off; Choking Hold and Iron Garden read Root, Stun, and Garrote as holds.

`tests/sim/test_plan_relics.gd` fights each relic in a small fight. The plan teams' leans (`tools/test_teams.json`) take the new relics: control the eight control relics, sustain the four sustain ones, and burst Splinter Shot.

### Built in T-2

**The bot's shopping** (bot code only, Decision 6): practice fights read a lost fight by the share of the enemies' HP the heroes took (a rout no longer reads -1 whatever the team, so a buy's gain shows before the bot can win); cards, items, ranks, and relics carry a small prior worth practice can't see (relics by tier); the shop tries its options by that worth. Its first runs found the shard runaway (Decisions 7–10).

**Speed** (the fixed bot spent 51 practice fights per real fight, 79% of a run's time): the practice cache keys on what fights read (not the shop, the offers, or the shards), a shop visit is priced once and only its top 3 re-priced after a buy, the sim keeps per-unit lists of auras and listeners (10–21% faster on loaded fights, every fingerprint unchanged), and the bench loads content once and has a loaded case (six saved run states, `tools/bench_states/`). A long run went from 756 s to 392 s, 34 practice fights per real fight; 120 runs take about 2.5 hours, not 4.5.

**The baseline** (the good bot, 120 runs over all 20 teams, with the thirteen relics and the shard caps):

| What | Before T-2 | Now |
| --- | --- | --- |
| Reach Act 1's boss | 73% | 81% |
| Win Act 1 | 40% | 59% |
| Win Act 2, Act 3 (of runs reaching it) | 40%, 50% | 45%, 93% |
| Win the run | 8% | 25% |
| Shards earned, spent a run | 146, 44 | 240, 165 |
| Picks a run (cards taken) | about half a hero's | 10.7 (hero 8.0, taste 0.5, path 1.9, apex 0.3) |
| Relics a run | | 17.3 (target 8–14) |
| Garrote, Headhunter, Windcaller transform | 5%, 30%, 35% | 40%, 65%, 45% |
| Runs won by hero | | Brannoc 38%, Garrow 31%, Maren 26%, Tamsin 23%, Vell 16%, Aldous 13% (Windcaller 0 of 20) |

So the bot now buys and picks, and the numbers move a lot: Act 1 is above its 40–49% band, Act 3 is near-certain for the runs that reach it, and relics are above their target. These are the numbers T-3 to T-6 tune from.

## 6. Questions

- **TA. The half-plans' target** *(Answered: Decision 3.)* (Decision 1): with the right relics and items, what should a pure sustain or pure control team manage? Proposed: with the lean (their relics and items 3 times as likely), win Act 1 in about 10–20% of runs (random teams 40–49%), and without it near 0.
- **TB. Iron Garden and the uncapped relics.** *(Answered: Decision 4, as written.)* `build-map.md`'s payoff relics were to have a cap a fight (Huntsman's Horn: 15 times). Iron Garden is uncapped and counts refreshes, and the control team re-Roots constantly (Trapper's snares, Thicket Engine's refresh every 4th hit), so it could reach +100% early in a fight. Proposed: count new holds only (not refreshes) and cap it at 25 a fight (+50%), lifted in endless like the others. Unending Vigil (+1% a second) reaches +60% by a minute; leave it uncapped, like Quickening?
- **TC. Heavy Pommel at rare:** *(Answered: Decision 5.)* each hero's first hit on each enemy Stuns 1s, so every enemy is Stunned up to 3s by a team that reaches it, more than Bramble Seed's 2 Roots and stronger than most epics against swarms and bosses. Proposed: once per enemy (the first hero to reach it), 1s; or keep it per hero at 0.5s.
- **TD. The bot's shopping first** (T-2): *(Answered: Decision 6.)* fix the good bot's spending and picks before tuning the heroes, so the numbers measure the game and not the bot? Proposed: yes; it changes no game code.
- **TE. The bad stand-ins:** all melee (Aegisfang, Nightblade, Last Watch) wins Act 1 83%, so it isn't bad. Replace it and No makers with teams that are bad with these six heroes (proposed: three back-liners on their weakest paths, and two tanks with an enabler), or drop the bad group until Ilse, Ottilie, and Lucan are built?
- **TF. Snare Wire's "a hex next to a hero":** heroes move freely, so this reads as an enemy first coming within 1 hex of a hero (center to center). Right?

## Decisions

The playtester, 2026-10-08:

1. **Half-plans are much harder, not equal:** a pure sustain or pure control team isn't tuned to match teams with damage and a tank; it should work only with the right relics and items (this replaces `easy-start.md` Decision 4).
2. **Thirteen relics join the pool** (`changes-plan-relics.md`): sustain, control, and Splinter Shot; Iron Garden replaces Huntsman's Horn. Their files: `relics/` (common 28, rare 26, epic 16, legendary 18).
3. **The half-plans' targets** (Question TA), against random teams' 73% reaching Act 1's boss, 40–49% winning Act 1, and about 8% winning the run: **with the lean** (the right relics and items), reach the boss about 70%, win Act 1 about 20–25%, win the run about 2–4%; **without it**, about 50–60%, 5–10%, and 0–1%.
4. **Iron Garden as written** (Question TB): every Root or Stun on an enemy, refreshes included, no cap; tuned from the runs if it runs away.
5. **Heavy Pommel once per enemy** (Question TC): the first hero to hit each enemy Stuns it 1s; the others don't again.
6. **The bot's shopping first** (Question TD): T-2 (the good bot's spending and picks, bot code only) comes before the heroes are tuned, so the numbers measure the game, not the bot's hoarding.

The playtester, 2026-10-08, after T-2's first runs (the good bot, now buying relics, earned 20,848 shards a run against 146 before: Overkill Tithe paid for damage past an enemy's last HP, which grows without end with the heroes' damage, and its shards fed Gilded Rift's ATK and MGK, which fed the overkill):

7. **Overkill Tithe pays by kill, at most 3** (a cap on max HP wouldn't hold, since HP scales): a kill with any overkill pays 1 shard, one more past 50% of the enemy's max HP, one more past 100% (the deed count overkill's `"steps_at_pct": [0, 50, 100]`).
8. **Lucky Strike pays at most 5 shards a fight** (crits grow with attack speed, and Quickening has no cap; GrowthDef's `"max_steps_per_fight"`).
9. **Gilded Rift stays uncapped:** with the earners capped, the shards it reads grow only as fast as income.
10. **Bloodied Coin stays uncapped:** a fight's kills are bounded by what it spawns.

