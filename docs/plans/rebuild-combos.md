# Rebuild plan, part 7: combos, scaling, and breaking the game

Status: **agreed in discussion (2026-09-30), not built; it's phase 5c, before phase 6, starting with the damage rule** (`rebuild-build-order.md`). Adds to part 1 (`rebuild-heroes.md`), part 4 (`rebuild-run.md`), and part 6 (`rebuild-between-fights.md`); where this part changes a rule there, this part wins. Numbers are placeholders to tune.

**Why:** a big part of the fun in games like this is finding combos, and the chance to "break" the game with them. That's what makes an endless mode work: your engine scales fast, but the rift scales faster, so you still lose eventually. The earlier plans were all about keeping things in check (every relic has a cost, no pure upsides, small tastes, narrow charms), which leaves nothing that multiplies. This part adds the pieces combos are built from.

## Decisions

- **Shared keywords:** a handful of statuses any hero can apply and any hero can exploit (section 1).
- **More triggers** for charms, relics, and upgrades to hang on (section 2).
- **One damage rule:** bonuses of the same kind add; bonuses of different kinds multiply (section 3).
- **Permanent scaling** across the run: some upgrades and relics grow every fight and never stop (section 4).
- **More relics, in tiers,** including **really strong, build-defining relics after each boss** (section 5). **Changed by the relic pool (`relics/README.md`, 2026-09-30):** five tiers, no downsides, about 8–14 a run, bought in every shop.
- **Every stat change says its amount:** "+10% attack speed", "+5 ATK", never "attacks faster" (section 6).
- **No combo readouts for players.** Working out whether a combo does what you meant is part of the fun. Readouts exist only for testing (section 7).
- **An endless mode** where the rift scales exponentially (section 8).

## 1. Keywords

A keyword is a status with a name every hero, charm, relic, and upgrade can refer to. Builds form around one: a Mark team, a Shield team, a Burn team.

| Keyword | Applied by (now) | Payoff examples |
| --- | --- | --- |
| **Marked** | Maren's Marking Shot | "Crits on Marked enemies refund 10 mana"; "Marked enemies take +1 hit from every split arrow" |
| **Rooted** | Trapper's snares | "Attacks on Rooted enemies always crit"; "A Rooted enemy that dies roots the nearest enemy for 1s" |
| **Burning** | Ashlings (enemy), later heroes and relics | "Burn you apply stacks twice"; "Burning enemies explode on death for their remaining Burn" |
| **Shielded** | Vell (Wardweaver), Hearthguard | "When a Shield breaks, it bursts for its value around the holder"; "Shielded allies deal +15% damage" |
| **Stealthed** | Maren's Slip Away | "Your first attack out of Stealth deals +100% damage"; "Stealth lasts 1s longer" |

- **Keywords are team-wide:** a Mark from Maren counts for Brannoc's and Vell's charms too.
- Any existing status can become a keyword later (Slow, Bleed); five is the start.

## 2. Triggers

Things charms, relics, and upgrades can react to. Most are read from the combat log, like the events the sim already uses.

| Trigger | Fires when |
| --- | --- |
| `on_crit` | the unit lands a critical hit |
| `on_kill` | the unit's damage fells an enemy |
| `on_apply(keyword)` | the unit applies a keyword |
| `on_hit_keyword(keyword)` | the unit hits an enemy that has a keyword |
| `on_shield_broken` | a Shield on the unit (or one it gave) breaks |
| `on_signature` | the unit fires its signature (exists as an event) |
| `on_ally_signature` | an ally fires theirs |
| `on_heal` | the unit heals someone |
| `on_hop` | the unit hops (exists since playtest gate 1) |

**Loop guard:** an effect caused by a trigger can set off other triggers, but one chain stops after a set depth (say 8 steps) per tick. Chains are the point, but they can't be infinite.

## 3. The damage rule

A hit's damage is its base (ATK or MGK times the ability's %), plus flat bonuses, **times one factor per bonus kind**:

```
damage = (base + flat) × (1 + crit bonuses) × (1 + vulnerability) × (1 + power) × (1 + relic bonuses)
```

| Kind | What goes in it | Examples |
| --- | --- | --- |
| **Crit** | crit damage bonuses, only when it crits | "Crits deal +50%" |
| **Vulnerability** | bonuses from the target's state | Marked (+15%), "vs Rooted +20%", "vs wounded +10%" |
| **Power** | the attacker's own bonuses | "+10% damage", Last Watch below 30% HP |
| **Relic** | relic bonuses | "Every Burning enemy on the field gives +3% damage" |

- **Same kind adds; different kinds multiply.** Two vulnerability bonuses of 15% and 20% give ×1.35; a 15% vulnerability and a 20% power bonus give ×1.38. One more piece of a different kind can double a build.
- Integers, like the rest of the sim: each factor is basis points, multiplied in one shared helper, rounded once at the end.
- DEF, Shield, and healing work the same way (bonuses of the same kind add, different kinds multiply).

## 4. Permanent scaling

Some upgrades and relics **grow every fight and never reset** during a run.

- **They count something the hero does**, the same way deeds do. After a transformation, the deed keeps counting, and a path's "growing" upgrades turn that count into a bonus.
- **Examples:**
  - *Deadeye, Hunter's Tally:* +1% damage per 500 damage ever dealt from 5+ hexes.
  - *Hearthwall, Old Scars:* +1 DEF per 200 damage ever taken for allies.
  - *Volley, Arrow Glut:* every 25 extra targets hit gives +1% attack speed.
  - *Relic, Collector's Chain:* +1 ATK for all heroes for every 10 enemies killed this run.
- **The card shows its current value**, "Now: +12% damage", so the growth is visible. What it's doing in a fight isn't.
- Counters live in run state, saved with the run, and are deterministic from what happened (like everything else in the run).

## 5. Relics: more of them, in tiers

**Superseded by the relic pool (`relics/README.md`, 2026-09-30), which wins where this section disagrees:** five tiers (common, rare, epic, legendary, boss), **relics have no downsides** (trade-offs live in events, Rift Tear, and Bloodied Oath), about 8–14 a run, and every shop shows one relic at a time with rerolls that climb in price. The full pool is in `relics/`, one file per tier. What follows is the first version, kept for its reasoning.

Relics go from "about 3–5 per run" to **about 6–9 per run**, and they come in three tiers:

| Tier | Where from | What it's like |
| --- | --- | --- |
| **Common** | Elites, the Shrine, Rift Tear, the Pedlar now and then | A small rule change with a cost |
| **Rare** | Elites (sometimes), the Magpie, Rift Tear | A strong rule change with a cost that some builds can dodge |
| **Boss** | **Every boss: choose 1 of 3** | **Build-defining.** Often pure upside, or a huge twist. The kind you plan the rest of the run around |

**A sixth kind, bond relics** (2026-09-30): free, found in shops only once their duo bond switches on (`duo-bonds.md`).

- **Costs that builds dodge are the point of rares.** *Ember Heart* (Burn doubled, healing 20% weaker) is a real trade for most teams and free for a team with no healer. Finding that is the "I broke it" moment.
- **Boss relic examples** (placeholders):
  - *Crown of the Hollow King:* every keyword you apply is applied twice.
  - *The Second Sun:* signatures fire twice; the second fires at 50%.
  - *Rift-Bound Heart:* every permanent scaling bonus grows twice as fast.
  - *Oathbreaker's Ring:* a hero can hold a second path's taste (not its deed).
  - *Mirror of Ash:* damage you take is also dealt to the enemy that dealt it.
- **More relics means more of them are written for keywords and triggers**, so they combine with each other and with charms.

## 6. Every stat change says its amount

- Upgrades, charms, and relics that change a stat **name the stat and the amount**: "+10% attack speed", "+5 ATK", "+1 range", "−15% max HP".
- A percentage says what it's a percentage of when that's not obvious ("+10% of max HP as Shield").
- Effects that aren't stats (a new trigger, a keyword) are described in words, with their numbers.
- This is for the cards and tooltips. The kits' ability `"text"` still keeps numbers out, since the UI adds a numbers line (CLAUDE.md, "Ability text").

## 7. No combo readouts for players

- **The player never sees counts like "Heartseeker fired 14 times, 9 from refunds".** Working out whether a combo is doing what you meant is part of the fun. The combat log stays as it is (every effect with its source, rule 4), so a curious player can still dig.
- **For testing only:** a combo readout behind the same testing toggle as target lines, and in the sim runner's report, so tuning can see which engines work. **Built in phase 5c step 9** (`rebuild-phase5c-combos.md`, sections 17.11–17.12): "Combo readout (for testing)" beside the target lines, and the engine report in the run report (`--engines`, Decision 45: the sim runner's heroes hold no engines).

## 8. Endless mode

**Filled in (2026-09-30):** `endless.md` has the structure (floors are days, elites every 5th, bosses every 10th), the scaling, and the score.

- **Unlocked after beating Act 3** (a placeholder). A run continues past the final boss into floors.
- **The rift scales exponentially:** enemy HP and ATK ×1.15 per floor (placeholder), plus a new rift modifier every 3 floors (`enemy-growth.md`), and the rift learns is always on.
- **Your engine scales too:** permanent scaling keeps counting, and floors keep offering picks, relics, and shops.
- **You always lose eventually.** The score is how deep you got.
- **The campaign keeps its own rule:** harder means new problems, not more HP. Exponential numbers are only for endless.
- The sim's integers are 64-bit, so big numbers are safe; the UI shortens them (12.4k, 3.1M).

## 9. Combos the three heroes could already have

- **Deadeye plus Mark:** "Heartseeker Marks" and "crits on Marked enemies refund 10 mana" make a Heartseeker that nearly casts itself.
- **Volley plus on-hit effects:** every split arrow carries your on-hit charms, so more targets multiplies everything else.
- **Hearthwall plus Wardweaver:** Vell shields Brannoc, Guard pulls hits onto him, and "Shields burst when broken" turns the team's defense into its damage.
- **Last Watch plus Vell:** his low-HP bonuses with just enough healing to hover at 25%. His cost (healing on him is weaker) becomes a tuning knob, not a downside.
- **Trapper plus Rooted payoffs:** "Attacks on Rooted enemies always crit" plus a crit engine on Maren or a charm on Brannoc.

## 10. What this changes in earlier plans

| Plan | Rule | Now |
| --- | --- | --- |
| `rebuild-run.md` | "About 3–5 relics per run", "every relic has a cost" | About 8–14, in five tiers, with no downsides (`relics/README.md`) |
| `rebuild-arena.md` | Crumbled ground can't be walked into | Walkable; it damages whoever stands on it (`relics/README.md`, Decisions) |
| `rebuild-between-fights.md` | After-fight picks are the steady drip | Some picks are *growing* upgrades (section 4) |
| `rebuild-enemies.md` | Harder means new problems, not more HP | Still true in the campaign; endless mode scales numbers |
| `rebuild-between-fights.md` | Charms, tactics, sigils, and grafts; a few charms with costs; "no effect on this hero"; the Pedlar filters | Tactics, gambits, sigils, and charms, three ranks each, no downsides, no warnings, no filtering, items sell back; grafts cut into charms, and the Magpie a node (`loadout/README.md`, `magpie.md`) |
| CLAUDE.md, rule 5 | Meta progression never adds stats | Unchanged: scaling lasts one run only |

## 11. What it means for the code

- **The sim:** keyword statuses (a flag on `StatusDef`), the new triggers (from the log, like the existing events), a chain-depth guard, and damage computed by bonus kind in one helper. Permanent scaling is a per-hero counter passed into the fight's setup as bonuses.
- **Run state:** scaling counters, relic tiers.
- **The UI:** "Now: +X" on growing cards; exact amounts on every stat card; big-number formatting; a combo readout behind the testing toggle.
- **Tests:** the damage rule (same kind adds, different kinds multiply), the chain guard, determinism with long chains, and scaling counters surviving a save.
- **The sim runner:** a report of which triggers fired how often, per build, so tuning can find engines that are too weak or break too early.

## 12. Where this meets what's already built (2026-09-30)

Part 7 was agreed after phases 5 and 5b were built. It isn't built yet, and nothing below changes a decision above; it's what a build plan for part 7 has to deal with.

- **Relics:** phase 5 built 8 (plus none of the new pool), all one tier, each with a cost, about 1.6–2.7 a run (`rebuild-phase5-run.md`, sections 8 and 16). `relics/README.md` says what becomes of each: most lose their costs and join a tier, Pilgrim's Lantern and Hungry Blade are cut. Tiers, a relic in every shop with climbing rerolls, the shop before each boss, the boss relic choice, and the new income are new work in the run layer. The Act 1 boss (Old Mother Ash) would be the first to offer a boss relic.
- **Ember Heart** becomes a rare with no cost: every hero's basic attack applies 1 Burn (`relics/README.md`), close to what's built, minus the weaker healing.
- **Stat amounts (section 6):** many built cards name no amount ("Your DEF is higher.", "You walk faster."). Their text in `items.json`, `upgrades.json`, and `relics.json` gets rewritten; the numbers are already in each entry's mod, so the card's amount can be generated from it, the way ability numbers lines are.
- **The damage rule (section 3):** the sim already adds bonuses in a few places (Marked, the tactics' payoffs, kit mods, Rift Tear). Each has to be sorted into a kind, and the rule applied in the one helper that lands hits (`EffectRunner.deal_hit`). That changes fights, so the bench fingerprints and every tuned number move, and the tuning of playtest gate 3 (section 16 there) is redone.
- **Keywords and triggers** build on what exists: statuses (`StatusDef`) and the events read from the log (`Events`, `Passives`). **Built in phase 5c step 3** (`rebuild-phase5c-combos.md`, section 8): Marked, Rooted, Burning, and Stealthed are a status's `"keyword"`, and Shielded is a Shield above 0. Section 2's triggers in the sim: `on_crit` is `on_holder_crit`, `on_apply(keyword)` is `on_status` with `keywords`, `on_hit_keyword(keyword)` is `on_holder_hit` with `"vs"`, `on_signature` is `on_ability`, `on_ally_signature` is `on_ally_ability`, and `on_kill`, `on_shield_broken`, `on_heal`, and `on_hop` keep their names. `on_shield_broken` is the holder's only (Shields aren't tracked by giver). The loop guard is the chain limit, 8 a tick (`tuning.json`). Every "+X% damage to some enemies" bonus is power (that plan's Decision 12), so section 3's "vs Rooted +20%" is power, not vulnerability; only Marked is vulnerability.
- **Crumbled ground becomes walkable** (`relics/README.md`, Decisions): today the sim refuses to walk onto it and re-targets when it walls a target off. That changes fights too, so it lands beside the damage rule and shares its retune.
- **The loadout pool** (`loadout/README.md`): 14 tactics, 6 gambits, 15 sigils, and 27 charms (six were grafts; `magpie.md`), many written on the keywords (Marked, Rooted, Burning, Shielded, Stealthed). Phase 5 built 22 items: the four tactics stay, eight others map into the pool, and the rest are cut (Iron Skin's and Sidestep's names return as new charms from the grafts). Selling items at any shop and relics to the Magpie (a node with a fixed stall, `magpie.md`) are new run actions. Ranks are new run state (each kind counts its own thing: time following the order, fights, casts, won fights), and gambits are new sim pieces (placement outside the zone, sharing a hex, entering late, swapping places).
- **Endless mode** needs Acts 2 and 3 first.

## Open questions

- Relics' open questions (stacking, boss offers, relics per run, chain limits) are in `relics/README.md`; the loadout's (rank-up numbers, charms in relic lanes, the shop mix, gambits' frame) are in `loadout/README.md`.
- **The chain-depth limit** (8 is a guess).
- **Endless:** answered in `endless.md` (it continues past the Act 3 boss by choice; a floor is a day, with its shop); its own open questions (the scaling rate, income) are there.
- **Which statuses become keywords next** (Slow, Bleed, Stun).
