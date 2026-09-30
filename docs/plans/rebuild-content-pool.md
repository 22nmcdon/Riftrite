# Rebuild plan, part 7b: the first content pool

Status: **first draft (2026-09-30), not built.** The actual relics, charms, tactics, sigils, grafts (since cut), and growing upgrades for Act 1, written to the rules of part 6 (`rebuild-between-fights.md`) and part 7 (`rebuild-combos.md`). **Every number is a placeholder** until the sim runner has had a pass at it. Names are placeholders too.

**How to read it:**

- Every stat change says its amount (part 7, section 6).
- **Tags** say which keyword (Marked, Rooted, Burning, Shielded, Stealthed), trigger, or damage kind (crit, vulnerability, power, relic) an entry uses, so combos can be found and checked. Tags are for design and testing; players never see them.
- "Any hero" means the entry is written against something every hero has (basic attack, signature, being hit). Entries that need something (hops, mana, heals) say so under **Needs**.

## 1. Keywords: who can apply them

A keyword with no way to apply it is dead. After this pool, every keyword has at least three sources:

| Keyword | Heroes and paths | Charms, sigils, relics |
| --- | --- | --- |
| **Marked** | Maren (Marking Shot), Deadeye (Heartseeker Marks, an upgrade) | Hunter's Chalk (charm), Tolling Sigil (sigil), Brand of Guilt and Hunter's Engine (relics) |
| **Rooted** | Trapper (snares) | Bramble Knot (charm), Grasping (sigil), Bramble Seed and Grasping Mire (relics) |
| **Burning** | Vell (Ember Glow, an upgrade) | Ember-Tipped (charm), Kindled Sigil (sigil), Ember Bauble and Ashen Engine (relics) |
| **Shielded** | Vell (Wardweaver), Brannoc (Hearthguard) | Warding Thread (charm), Bulwark Sigil (sigil), Tithe of Iron (relic) |
| **Bleeding** | Deadeye (Bleeding Shot), Ironbrand (Cleaving Wounds), both upgrades | Bloodletter (charm) |
| **Stealthed** | Maren (Slip Away) | Smoke Vial (charm), Veiled (sigil), Smoke Pouch (relic) |

## 2. Relics

**Moved to `relics/`** (2026-09-30): one file per tier (common, rare, epic, legendary, boss), with the rules every relic follows in `relics/README.md`.

## 3. Charms (18)

**Superseded by `loadout/charms.md`** (2026-09-30): 27 charms with three ranks, at 6 shards. This first draft is kept for reference.

A small change to a hero's kit, slotted, swapped free between fights, bought at the Pedlar (3 shards). Any hero can hold any charm (part 6, section 8).

| Charm | Effect | Needs | Tags |
| --- | --- | --- | --- |
| **Fletched for Wings** | Your basic attack deals +40% to flying enemies | | vulnerability |
| **Light Feet** | You hop away when an enemy comes within 1.5 hexes, not just adjacent | a hop | |
| **Hunter's Chalk** | Your crits Mark the target for 2s | | on_crit, Marked |
| **Bramble Knot** | Every 5th basic attack Roots the target for 1s | | Rooted |
| **Ember-Tipped** | Your basic attack applies 1 Burn | | Burning |
| **Warding Thread** | When you drop below 50% HP, gain a Shield of 15% of your max HP (once per fight) | | Shielded |
| **Purifying Light** | Your heals also cleanse Bleed and Poison | heals | |
| **Braced** | A charge or leap that hits you gives you a Shield of 10% of your max HP | | Shielded |
| **Opportunist** | +25% damage to enemies that are Rooted or Stunned | | vulnerability, Rooted |
| **Flint and Tinder** | Your crits on Burning enemies add 2 Burn | | on_crit, Burning |
| **Headsman's Patience** | +20% damage to enemies below 30% HP | | vulnerability |
| **Shadow Step** | Your first attack out of Stealth has +100% ATK | Stealth | Stealthed, power |
| **Mana Leech** | Your crits give 5 mana | mana | on_crit, signature |
| **Spiteful Blood** | When you're hit, 10% of the damage goes back to the attacker | | on_hit_taken |
| **Steady Stance** | +10% ATK and MGK while you haven't moved for 2s | | power |
| **Bloodhound** | +15% damage to enemies below 50% HP; your attacks prefer them | | vulnerability |
| **Kindling Ward** | Enemies that break one of your Shields catch 3 Burn | | Shielded, Burning |
| **Last Breath** | When you fall, allies within 2 hexes gain a Shield of 15% of their max HP | | on_fall, Shielded |

## 4. Tactics (10)

**Superseded by `loadout/tactics.md`** (2026-09-30): 14 tactics with three ranks, at 4 shards. This first draft is kept for reference.

How a hero behaves, never what they can do. Slotted, 2 shards.

| Tactic | Order |
| --- | --- |
| **Fliers first** | Target flying enemies before anything else in range |
| **Casters first** | Target enemies with a signature before anything else in range |
| **Marked first** | Target Marked enemies before anything else in range |
| **Finish them** | Target the lowest-HP enemy in range |
| **Guard the weakest** | Target whoever is attacking your lowest-HP ally |
| **Hold your ground** | Don't leave your starting hex until an enemy comes within 2 hexes |
| **Keep your distance** | Back away to stay at your full range |
| **Stay with the tank** | Stay within 2 hexes of your team's tank |
| **Heal only the hurt** | Heal only allies below 50% HP |
| **Wait for two** | Hold your signature until two allies are hurt (heals) or two enemies are in reach (areas) |

## 5. Sigils (8)

**Superseded by `loadout/sigils.md`** (2026-09-30): 15 sigils with three ranks, at 8 shards. This first draft is kept for reference.

How the signature fires. Written against "your signature", so they survive transformations. 4 shards.

| Sigil | Effect | Needs | Tags |
| --- | --- | --- | --- |
| **Echo** | Your signature fires again 2s later at 40% | | signature |
| **Opener** | Your signature starts the fight ready, but costs 20 more mana | mana | signature |
| **Desperate** | Your signature also fires once when you first drop below 40% HP | | signature |
| **Wide** | Your signature's area is 1 hex larger, or it hits 1 more target | | signature |
| **Cheaper** | Your signature costs 15 less mana and is 10% weaker | mana | signature |
| **Tolling Sigil** | Your signature Marks everything it hits for 3s | | Marked |
| **Kindled Sigil** | Your signature applies 3 Burn to everything it hits | | Burning |
| **Bulwark Sigil** | Your signature gives you a Shield of 10% of your max HP | | Shielded |

## 6. Grafts

**Cut** (2026-09-30): they were charms by another name. Smoke Vial, Sidestep, Iron Skin, Spite Brand, Bloodletter, and Scavenger became charms (`loadout/charms.md`); see `magpie.md`.

## 7. Growing upgrades (one per path)

Each path's growing upgrade is part of its path pool in `upgrade-pools.md`. Each hero also has a growing upgrade in their hero pool (Notched Bow, Weathered, Lamp Oil).

Path upgrades that grow for the rest of the run (part 7, section 4). They show up in a path's pool once the hero has transformed. Each card shows its current value.

| Path | Upgrade | Grows by | Counts |
| --- | --- | --- | --- |
| Deadeye | **Hunter's Tally** | +1% damage | per 500 damage dealt from 5+ hexes |
| Trapper | **Patient Hunter** | +1% damage to Rooted enemies | per 5 seconds of root |
| Volley | **Arrow Glut** | +1% attack speed | per 25 extra targets hit |
| Hearthwall | **Old Scars** | +1 DEF | per 200 damage taken for allies |
| Ironbrand | **Brandmarks** | +1 ATK | per 30 extra enemies cleaved |
| Last Watch | **Borrowed Time** | +1% damage below 30% HP | per 3 seconds spent below 30% HP |
| Lanternbearer | **Kindled Flame** | +1% healing | per 300 healing next to Mend's target |
| Wardweaver | **Woven Deep** | +1% Shield size | per 300 Shield given |
| Vigil Keeper | **Sunwrought** | +1% smite damage | per 200 smite damage |

Growing relics are in `relics/` (Collector's Chain and Tally of the Dead, rare; Rift-Fed Blades, legendary; Rift-Bound Heart, boss).

## 8. Combos this pool is built for

These are the "break the game" lines. Testing checks that each one works, and that none of them is strong enough to win without the rest of the run.

| Combo | Pieces | Why it snowballs |
| --- | --- | --- |
| **Endless Heartseeker** | Deadeye; Heartseeker Marks (path upgrade); Hunter's Chalk; Mana Leech; Executioner's Mark | Crits Mark, crits on Marked give mana, the signature fires again sooner and Marks more |
| **Burning garden** | Ember-Tipped on everyone; Ember Bauble; Ashen Censer; Flint and Tinder; Kindled Sigil; Ashen Engine | Every hit adds Burn, crits add more, and the engine spreads it |
| **The bursting wall** | Hearthwall plus Wardweaver; Shattered Aegis; Kindling Ward; Bulwark Sigil; Woven Deep | Guard pulls hits onto shielded Brannoc; every broken Shield becomes damage and Burn |
| **Thicket** | Trapper; Bramble Knot on the others; Opportunist; Thornwoven Cloak; Grasping Mire; Patient Hunter | Roots from four sources, with two vulnerability bonuses and one that grows |
| **Hover at the edge** | Last Watch; Vell (Lanternbearer); Borrowed Time; Warding Thread; Glutton's Chalice | Brannoc stays below 30% HP forever while Borrowed Time climbs |
| **Arrow storm engine** | Volley; Hunter's Chalk; Flint and Tinder; Arrow Glut; The Ninth Arrow | Split arrows carry every on-hit charm, and every 9th hit triples |

## Open questions

- **Balance:** all numbers need a sim runner pass. The runner's combo report (testing only) should show each combo above firing.
- **Boss relic offers:** three random ones, or three picked to fit the team's keywords?
- **Charms that do nothing on a hero:** this pool keeps the "Needs" column short on purpose. Is that the right amount?
