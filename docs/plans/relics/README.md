# Relics

Status: **agreed in discussion (2026-09-30), not built.** The relic pool for Act 1, one file per tier. The rules behind it are in part 7 (`../rebuild-combos.md`); this file gathers the ones every relic follows. **Numbers and names are placeholders** until the sim runner has had a pass at them.

| Tier | File | Where from | Price | Count |
| --- | --- | --- | --- | --- |
| **Common** | `relics-common.md` | Every shop | 5 shards | 25 |
| **Rare** | `relics-rare.md` | Every shop (less often), elites | 12 shards | 21 |
| **Epic** | `relics-epic.md` | Shops (rarely), elites, the Magpie | 20 shards | 14 |
| **Legendary** | `relics-legendary.md` | The shop before each boss | 30 shards | 15 |
| **Boss** | `relics-boss.md` | After each boss: choose 1 of 3 | free | 11 |
| **Bond** | `../duo-bonds.md` | Shops, once its duo bond switches on (more likely than an epic) | Free | 3 (Act 1) |

## What each tier is for

- **Common:** one clean bonus. A stat for every hero, a small keyword starter, or a little economy. The bricks of a build.
- **Rare:** turns a keyword or trigger into something: a payoff, a growing bonus, a quest.
- **Epic:** a strong engine for **one** lane (one keyword, one mechanic).
- **Legendary:** an engine that spans builds, or a big structural change.
- **Boss:** **rewrites a rule of the game.** Every build feels it differently, and it multiplies an engine rather than replacing one. A boss relic must not win by itself.

## Rules every relic follows

1. **Team-wide, never hero-specific.** Relics key on stats, keywords (Marked, Rooted, Burning, Shielded, Stealthed), triggers, positions, and kinds of hero (ranged). None names a hero, a path, or an ability. Some relics will do nothing for some builds; that's fine.
2. **No downsides.** A relic can happen to clash with a build, but it's never written to hurt. Real trade-offs live in events, Rift Tear, and Bloodied Oath.
3. **Buffs to heroes raise ATK or MGK, not "damage".** Everything that scales off ATK or MGK benefits, and physical and magic builds stay separate. "Damage" stays for:
   - bonuses tied to the target ("Rooted enemies take +30% damage");
   - hit multipliers (crits, triple damage);
   - effects scoped to one kind of attack ("basic attacks deal +100% damage").
4. **Every stat change says its amount:** "+6 ATK", "+8% attack speed", never "attacks faster".
5. **Lifesteal is its own mechanic.** A hero heals for a percent of the damage they deal, from any source. It isn't healing: healing bonuses and healing triggers ignore it, unless Blood Communion (epic) says otherwise. Lifesteal from several sources adds up.
6. **Chains.** Anything that repeats off its own result is a chain: triggered effects setting off triggers, Crown of Stars' crit rolls, Shared Pain's echoes, The Hungering Rift's carried overkill, Overcharge's extra casts. Every chain has a step limit, and Chain of Echoes (boss) affects every chain in the game.
7. **Two relics can use the same thing.** The same overheal can feed Overflow Chalice and Shadow Engine at full value; nothing is split between relics.
8. **Bond relics** are the one kind whose availability depends on the heroes: only a run with that duo bond can find one. What they do is still team-wide.

## Shops

- **Every shop shows 1 relic at a time.** Rerolling replaces it with a new one, so a shop has no limit: with enough shards you can keep buying. The first reroll costs 1 shard, and each reroll after it costs 1 more (Tinker's Purse makes the first free; Merchant's Covenant stops the price climbing).
- **The Pedlar:** its 1 relic is mostly common, sometimes rare, rarely epic.
- **The Magpie** (`../magpie.md`): his 1 relic is always epic or legendary, at 25% off. He's also the only place to sell a relic (for half its tier's price) or swap one for another of the same tier.
- **The shop before each boss:** 1 legendary plus 1 relic of another tier. Rerolls work the same way but start at 5 shards.
- **After each boss:** 3 boss relics, take 1.

## Income (placeholders)

You start a run with 10 shards. A normal win pays 10, the harder fight 13, an elite 15, the boss 25. All shard numbers are in `../economy.md`.

## Decisions (2026-09-30)

These win over part 7 (`../rebuild-combos.md`), part 6 (`../rebuild-between-fights.md`), the run plan (`../rebuild-run.md`), and the arena plan (`../rebuild-arena.md`) where they disagree; those plans carry notes saying so.

| Topic | Decision |
| --- | --- |
| **Costs** | **Relics have no downsides.** The README's rule wins over part 7 and the run plan. Trade-offs move to events, Rift Tear, and Bloodied Oath. Built relics lose their costs (section 2) |
| **Tiers** | Five tiers: common, rare, epic, legendary, boss. Part 7 and the run plan are updated to match the README |
| **Relics per run** | Roughly 8–14, depending on how much players reroll |
| **Shops** | **Every shop shows 1 relic at a time.** Rerolling replaces it with a new one, so a shop has no limit: with enough shards you can keep buying. The first reroll costs **1 shard**, and each reroll after it costs **1 more** |
| **The shop before each boss** | Shows **1 legendary plus 1 relic of another tier**. Rerolls work the same way but **start at 5 shards** |
| **After each boss** | Choose 1 of 3 boss relics, free |
| **Prices** | Common 5, rare 12, epic 20, legendary 30 |
| **Income** | A won fight pays **8**, an elite **12**, the boss **25** (placeholders). This replaces part 6's and part 7's earlier numbers. **Raised the same day (`../economy.md`):** start 10; a normal win 10, the harder fight 13, an elite 15, the boss 25 |
| **Crumbled ground** | **Walkable.** Standing on it deals flat damage every second (15, a placeholder) to heroes and enemies alike. Only rocks wall a target off. Riftwalker's Soles (boss) builds on this. The arena plan and the sim change to match |
| **Buffs** | A buff to a hero raises ATK or MGK, never "damage". "Damage" stays for bonuses tied to the target, hit multipliers, and effects scoped to one kind of attack |
| **Lifesteal** | Its own mechanic, separate from healing (unless Blood Communion) |
| **Chains** | Anything that repeats off its own result is a chain; Chain of Echoes (boss) affects every chain |

## The relics already built

Phase 5 built nine relics with costs (`../rebuild-phase5-run.md`). What becomes of each (Mirror of Ash was a boss relic in part 7's examples, not built):

| Relic | Built now (boon / cost) | Decision |
| --- | --- | --- |
| **Ember Heart** | Basic attacks apply 1 Burn / heals 20% weaker | **Rare, no cost:** every hero's basic attack applies 1 Burn |
| **Hollow Crown** | 4th loadout slot / wounds take 20% | **Legendary, no cost:** heroes get a 4th loadout slot |
| **Mirror of Ash** | (a boss relic in the old part 7) | **Epic, no cost:** enemies take 60% of the damage they deal to heroes |
| **Rift-Glass Eye** | Every fight is Scouted / enemies +10% HP | **Rare, no cost:** every fight is Scouted |
| **Pilgrim's Lantern** | Rest +10% max HP next fight / Pedlar +1 price | **Cut** |
| **Bloodstone** | +12% ATK / −8% max HP | **Common, no cost:** heroes gain +8% ATK |
| **Warden's Chain** | +15% DEF / walks slower | **Common, no cost:** heroes gain +10% DEF |
| **Gravedigger's Coin** | +2 shards per win / only 2 pick cards | **Common, no cost:** +3 shards after every won fight (replaces the planned Gravedigger's Spade; keeps the built name) |
| **Hungry Blade** | Basic attacks heal 10% of damage / 20% less healing taken | **Cut** |

## What's built (phase 5c step 5a, 2026-10-01)

`docs/plans/rebuild-phase5c-combos.md`, section 10: the five tiers, the prices, every shop's relic with climbing rerolls (a reroll replaces the relic and the wares), the pre-boss shop, the Magpie's relic at 25% off, an elite's and a Rift Tear's relic choices, the Shrine's rare for 15 shards, a choice of 3 boss relics after Old Mother Ash, and `economy.md`'s income. **44 relics are built** (17 common, 13 rare, 5 epic, 5 legendary, 4 boss); the rest need new sim pieces and come with steps 5b (shared pieces), 5c (engines and chains), and 5d (bond relics). The built relics lost their costs as the table above says; Pilgrim's Lantern and Hungry Blade are cut. Icons reuse the placeholder glyphs until the art rehaul.

## Open questions

- **Stacking:** can you buy the same common twice? If yes, pure-stat commons become a "go wide" plan (with Reliquary and Reliquary Lamp).
- **Boss offers:** three random, or three picked to fit the team's keywords and paths?
- **Relics per run:** roughly 8–14, depending on how much players reroll. To tune.
- **Chain limits:** Crown of Stars' 10 links, Shared Pain's 3 steps, and the trigger chain's 8 are guesses.
