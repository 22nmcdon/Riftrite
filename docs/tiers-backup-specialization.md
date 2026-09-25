# Item Tiers, Backup & Oathbinding

Sep 25, 2026 · @Noah

An add-on to the Roguelite Game Plan. Items now have both a rarity and a tier, heroes can go into backup by choice, and an S-rank hero can be permanently **oathbound** to an S-rank item.

> **Naming (decided):** the S hero + S item mechanic is called **Oathbinding**. "Specialization" means only the hero's rank-B pick of one of three specializations.

## Item tiers and combining

Every item has two separate properties. **Rarity** is what kind of item it is. **Tier** is how far it has been upgraded, on the same C → B → A → S ladder heroes use.

| Property | Values | What it controls |
| --- | --- | --- |
| Rarity | Common, Uncommon, Rare, Epic, Legendary | Complexity, whether it has a backup mode, how tailored its Oathbinding is |
| Tier | C, B, A, S | Power level; S is required for Oathbinding |

**Combining**

- Two copies of the same item at the same tier combine into one copy at the next tier: C + C → B, B + B → A, A + A → S.
- An S-tier item is maxed out and cannot combine further.
- Legendaries never combine. They upgrade through their own paths (see Legendaries).

This replaces the three-copy combine in the main plan. Epic is a new, fifth rarity between Rare and Legendary.

## Finding higher tiers

Items and heroes don't have to start at C. Shops can sell B, A, or even S tier, but higher tiers are locked until later in the run. Normally you won't see an A or S tier in Act 1.

**Shop odds by act (starting point for tuning)**

| Tier | Act 1 | Act 2 | Act 3 |
| --- | --- | --- | --- |
| C | \~80% | \~45% | \~20% |
| B | \~20% | \~40% | \~40% |
| A | 0% | \~15% | \~30% |
| S | 0% | 0% | \~10% |

**Lucky sources skip the table.** An event that opens an A-tier-only shop, an enemy drop, or a Vault chest can hand out a high-tier item or hero early. These are rare jackpots that can define a run.

The same odds table applies to heroes and items in the Caravan (the shop, which sells both), so the values should live in one data file.

## Heroes recruited above C

A hero found at B tier or higher comes with a **predetermined specialization**. You don't get to choose it on recruit.

- To change it, you need an event that offers **retraining**.
- Why: this rewards finding the hero you want early and building them up, rather than swapping in whatever higher-tier hero shows up later.
- Heroes raised from C still pick their specialization at B as normal.

## Backup mode

Which heroes fight and which sit in backup is the player's choice. With a full roster of 6 and at most 5 fielded, at least one hero is always in backup, but you can put more there instead of fielding them.

- A backup hero's **Backup** effect applies, and so do the backup modes of the items in their row.
- This allows builds like 3 fielded + 3 backup (a "support guild").
- Balance watch: fewer fielded heroes means fewer bodies during Rift Collapse. Backup effects need to scale well enough to compete without making "bench everyone" the best play.

**Item backup modes by rarity**

| Rarity | Active mode | Backup mode |
| --- | --- | --- |
| Common | Always | None, unless oathbound (see Oathbinding) |
| Uncommon | Usually | Sometimes; some items are backup-only |
| Rare | Usually | Often; some items are backup-only |
| Epic | Always | Often; if present, the item always has both |
| Legendary | Always | Always |

**Backup-only items** need a clear icon in shops and on the item, so no one buys one by mistake. What they do on a fielded hero (nothing, or a small passive) is still open.

## Oathbinding (hero–item)

When a hero and an item are both S tier, you can **oathbind** the hero to that item. It changes both in a meaningful way, and it is permanent.

**Rules**

- One Oathbinding per hero.
- The item can't be removed from that hero, moved to another hero, or sold. It can still be repositioned within the hero's row.
- The item can still be infused and reforged (reforging = removing its infusion).
- If the hero is dismissed, the oathbound item goes with them.
- The Oathbinding also changes the item's backup mode when the hero is in backup.
- Show a preview of the result before the player confirms, since it can't be undone.

**Oathbinding by rarity**

| Rarity | How specific | Notes |
| --- | --- | --- |
| Common | Very basic, same rules for all | Also grants a basic backup ability based on item type (e.g. auto-attack item), scaled by item size |
| Uncommon | Generic, slightly stronger than Common |  |
| Rare | Class-specific, never hero-specific or unique | Stronger with the matching class, weaker with similar classes, generic with unrelated ones |
| Epic | Fairly unique with specific heroes | Otherwise works like Rare (class-based) |
| Legendary | Always unique | Suggested: one unique Oathbinding per item with a variant per class; fully hero-specific versions only for signature pairings |

**Class tags and fit**

Heroes and items both carry tags (such as Melee, Ranged, Magic, Healing, Defense), and classes are grouped by similarity. A fit check decides which version of an Oathbinding applies. For example, a magic weapon specializes poorly with a melee hero and falls back to a generic version.

| Fit | Result |
| --- | --- |
| Exact class | Full class version |
| Similar class | Partial version |
| Unrelated | Generic version |

Proposed similarity groups: Warden + Striker (melee), Arcanist + Mender (casters), Ranger + Trickster (agile/ranged).

## Legendaries

Legendaries are the rarest and most powerful items. Each one always has both an active and a backup mode, a unique Oathbinding, and **its own upgrade path** instead of combining copies.

- **One per run:** a Legendary can appear only once per run, so you'll almost never see a duplicate (barring extremely lucky events).
- **Starting tier depends on the path.** Most Legendaries start at B or A. Some start at C and must be raised all the way to S through their path.

**Upgrade path ideas**

| Path | How it upgrades |
| --- | --- |
| Grows by use | A set number of kills or triggers per tier; a natural fit for C-start Legendaries |
| Essence-hungry | Feed it essences instead of copies; each tier may want a specific essence, which steers your route |
| Boss-forged | Gains one tier per boss defeated while equipped |
| Devourer | Sacrifice another item to it; it keeps a trace of what it consumed |
| Bonded | Upgrades when the hero holding it ranks up |
| Martyr | Upgrades each time its holder is knocked out and the guild still wins the fight |

## Open questions

- [ ] Rare Oathbindings: hand-written per class, or one tag-based effect that scales by fit?
- [ ] What do backup-only items do on a fielded hero: nothing, or a small passive?
- [ ] Starting tier for each Legendary path (C, B, or A).
- [ ] Backup Oathbinding effects above Common: derived by a rule from the active effect, or hand-written?
- [ ] An early S hero + S item could allow an Act 1 Oathbinding. Track how often it happens in the headless sim.
- [ ] Final class similarity groups.
