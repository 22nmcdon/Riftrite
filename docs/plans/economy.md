# Economy

Status: **agreed in discussion (2026-09-30), not built.** Every shard source and price in one place. Where another plan's numbers disagree, this file wins. **Numbers are placeholders** until a sim pass.

## Income

| Source | Shards |
| --- | --- |
| **Start of a run** | 10 |
| **Normal fight** (won) | 10 |
| **Harder fight** (won) | 13 |
| **Elite** (won) | 15 |
| **Boss** (won) | 60 (25 until 2026-10-01: `rebuild-phase5c-combos.md` Decision 49) |
| **Selling an item** at any shop | Half its price, rounded down, whatever its rank |
| **Selling a relic** to the Magpie | Half its tier's price (common 2, rare 6, epic 10, legendary 15, boss 15) |

Money relics add more (Gravedigger's Coin, Bounty Hunter's Tag, Loose Change, Miser's Vault, Bloodied Coin, Lucky Strike, Overkill Tithe, Bounty Board, and Gilded Rift pays in power for holding shards).

## Prices

| What | Shards |
| --- | --- |
| **Relics** | Common 5, rare 12, epic 20, legendary 30 |
| **Bond relics** | Free (`duo-bonds.md`) |
| **Tactics** | 4 |
| **Charms** | 6 (12 at rank II from the Magpie) |
| **Sigils** | 8 |
| **Gambits** | 12 |
| **Treating one wound** | 4 |
| **Rerolling a shop's relic** | 1, then +1 each time; starts at 5 in the boss shop (after the boss since 2026-10-01) |
| **The Magpie's relic** | 25% off (epic 15, legendary 22) |
| **The Shrine** | 15 shards for a rare (one of three offerings) |

## The target

- **Act 1 brings in about 76–86 shards before the pre-boss shop** (the start, 4 fights, and 2 elites, depending on how many harder fights you take).
- **A modest spend** over the first five shops (2 commons, a charm, a tactic, a sigil, a wound, and a few rerolls) leaves **about 30**: enough for a legendary if you planned for it, not by default.
- **The harder fight's +3** makes choosing it a real trade: more risk, more shards.
- **Checked against Act 1's days (2026-09-30):** the days are normal, normal, elite, normal, elite, normal, boss, so income before the pre-boss shop is really **80–92**, and the modest spend (about 35–40) leaves **about 40–57**. The playtester's call: that's fine, and the numbers stand until the sim pass.
- **Changed (2026-10-01, `rebuild-phase5c-combos.md` Decisions 48 and 49):** the legendary shop moved to after the boss (the day before the boss's is a plain Pedlar), and the boss pays **60**, so that shop is spent with what the act saved plus the boss's 60. The targets above were for a shop before the boss; phase 6's tuning revisits them.

## Where this meets what's built

Phase 5 built the old economy (`data/act1.json`, `rebuild-phase5-run.md` Decision 11): start 3 shards; a win pays 3, the harder fight 5, an elite 6, the boss 0, a Hunt 2; a wound costs 2 to treat, a reroll 1, a relic 9; charms and tactics 2–3, sigils 4, grafts 5; the Magpie's markup is 150%. This file replaces all of it when the relic and loadout pools are built (phase 5c). A Hunt at camp still pays shards (`days-and-nodes.md` keeps Hunt); its amount isn't set here.

## Open questions

- **A sim pass** on the whole curve, once the run exists (phase 6's run bot).
- **A Hunt's pay** at camp, beside a normal win's 10.
- **Income in endless:** grows with the floor, or stays flat (`endless.md`)?
