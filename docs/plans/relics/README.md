# Relics

Status: **agreed in discussion (2026-09-30), not built.** The relic pool for Act 1, one file per tier. The rules behind it are in part 7 (`../rebuild-combos.md`); this file gathers the ones every relic follows. **Numbers and names are placeholders** until the sim runner has had a pass at them.

| Tier | File | Where from | Price | Count |
| --- | --- | --- | --- | --- |
| **Common** | `relics-common.md` | Every shop | 5 shards | 20 |
| **Rare** | `relics-rare.md` | Every shop (less often), the Magpie, elites | 12 shards | 16 |
| **Epic** | `relics-epic.md` | Shops (rarely), elites, the Magpie | 20 shards | 12 |
| **Legendary** | `relics-legendary.md` | The shop before each boss | 30 shards | 14 |
| **Boss** | `relics-boss.md` | After each boss: choose 1 of 3 | free | 11 |

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

## Shops

- **The Pedlar:** 2 relics beside its 4 wares; mostly common, sometimes rare, rarely epic.
- **The Magpie:** always 1 relic: rare or epic, rarely legendary.
- **The shop before each boss:** 3 legendaries and 2 epics.
- **After each boss:** 3 boss relics, take 1.

## Open questions

- **Stacking:** can you buy the same common twice? If yes, pure-stat commons become a "go wide" plan (with Reliquary and Reliquary Lamp).
- **Boss offers:** three random, or three picked to fit the team's keywords and paths?
- **Relics per run:** with every shop selling them, roughly 8–14. To tune.
- **Chain limits:** Crown of Stars' 10 links, Shared Pain's 3 steps, and the trigger chain's 8 are guesses.
