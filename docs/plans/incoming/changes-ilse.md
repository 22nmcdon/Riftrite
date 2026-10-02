# Changes: Ilse, the fourth hero (Burn)

Decided 2026-10-02. This adds Ilse Cinderhand, a Burn caster whose only mana comes from Burn ticking near her: her kit, three paths, six apexes, and upgrade pool. It also sets a new rule that nothing may depend on who applied the Burn on an enemy, and drops Burn from lifesteal for the same reason.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply `changes-upgrade-pools.md` and `changes-apexes.md` first (sections 3 and 4 add to files they create).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after section 8 (Sister Vell), before "## 9. How the three fit together":

```markdown
## 8b. Ilse Cinderhand: the fire-speaker (caster damage)

*Added 2026-10-02.* **Role:** back-line magic damage. She shares the damage role with Maren: Maren hits hard right away, while Ilse's damage builds up over a fight. Fragile up close, like Maren.

| | |
| --- | --- |
| **Stats** | HP 260, ATK 6, MGK 22, DEF 8, CRIT 5 |
| **Speed / range** | speed 2, casts at up to 3 hexes |
| **Basic attack: Cinder Flick** | a mote of fire at the nearest enemy in range: damage from her MGK, plus Burn equal to 10% of her MGK. **It gives no mana** |
| **Signature: Flare** (60 mana) | a fireball that bursts on a 1-hex circle around her target, applying Burn equal to 60% of her MGK to each enemy in it |
| **Passive: Heat** | **her only source of mana:** each Burn tick on any enemy within 3 hexes gives her 1 mana (Burn ticks twice a second) |

Heat is her hook: she starts slow, and the more of the field is on fire, the faster she casts. Burn from allies, relics, and charms is her fuel. **All her Burn scales with her MGK**, never a flat number, because a hero must scale all run.

### Path 1: Furnace (one target, built up)

The fantasy: one enemy burns hotter and hotter until nothing's left.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Stoke:** every 4th basic attack adds 5% of the target's current Burn | Every 3rd basic attack stokes, adding 8%; and Burn on any enemy she has hit in the last 3s decays half as fast |
| **Signature** | Flare | **Immolate:** sets off all the target's Burn at once (5× its stacks as damage); enemies within 1 hex catch half the Burn it removed |
| **Cost** | –10% MGK | Immolate hits one target, with no area |

- **Deed:** Burn added by Stoke. Without Stoke it stays at zero.
- **Attack speed is her scaling:** Burn decays about 10% a second, about 5% on her targets once she's transformed. Stoke outpaces that at about 2 attacks a second, and past it, Burn on her target grows on its own. Putting attack speed on a mage is the point.
- **Stoke works on all Burn on the target**, whoever applied it.
- **Where she stands:** where she can keep hitting one target.

### Path 2: Wildfire (fire on the ground)

The fantasy: the ground itself catches, and the fire spreads where enemies stand.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Kindling:** Flare leaves burning ground on its circle for 3s | Her burning ground spreads 1 hex every 2s (up to 3 hexes from where it started) and lasts 6s. Enemies standing on it gain Burn equal to 10% of her MGK per second |
| **Signature** | Flare | **Firestorm:** starts a fire under each of the 3 largest groups of enemies |
| **Cost** | Flare's circle is smaller | Her basic attack applies no Burn; the ground does the work |

- **Deed:** Burn applied by her burning ground. Without Kindling she makes none.
- **Where she stands:** where enemies will gather, with room for the fire to spread.

### Path 3: Ember Choir (fire on every ally's weapon; gains a second role, Support)

The fantasy: she sings fire into her allies' weapons.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Blessing:** every 8s, the ally nearest her has their next 3 basic attacks apply 1 Burn | Every ally's basic attack applies Burn equal to 5% of her MGK |
| **Signature** | Flare | **Hymn of Cinders:** for 5s, allies' basic attacks apply Burn equal to 20% of her MGK and gain +15% attack speed |
| **Cost** | –1 range | Her own Burn is 30% weaker |

- **Deed:** Burn applied by allies. Without Blessing they apply none.
- **The taste stays at 1 Burn on purpose:** it's there to fill the deed, not to be strong.
- **With Heat,** allies setting enemies on fire is what fills her mana.
- **Where she stands:** behind the team, in range of every ally (once transformed, range doesn't matter for the blessing).

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4 ("How mana works"):

```markdown
| Ilse | 60 | none | none | none: **Heat**, 1 per Burn tick on any enemy within 3 hexes | 0 |
```

**Add** to section 5 ("Shared statuses"):

> - **Burn is one shared pile of stacks** on an enemy. **Nothing may depend on who applied it,** only on how much is there. (No per-source tracking in the sim.)

**Replace** the heading "## 9. How the three fit together" with "## 9. How the heroes fit together", and **add** to that section:

> - **Ilse turns any team's Burn into tempo:** every Burn source on the team feeds Heat. Furnace wants attack speed, Wildfire wants enemies bunched (Last Watch's taunts, Ironbrand's knockback), and Ember Choir wants allies who hit often or hit many (Volley, Ironbrand).

---

## 2. `docs/plans/rebuild-combos.md` (part 7)

**Replace** in section 2b:

> - **Lifesteal is its own mechanic:** a hero heals for a percent of the damage they deal, from any source (basic attacks, signatures, Burn they applied). Lifesteal from several sources adds up.

with:

> - **Lifesteal is its own mechanic:** a hero heals for a percent of the direct damage they deal (basic attacks and signatures). **Burn and other damage over time never count toward lifesteal,** since a pile of Burn has no single owner. Lifesteal from several sources adds up.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after the Vell section, before "## Left out on purpose":

```markdown
## Ilse

### Hero pool

These never give Stoke-style Burn growth (Furnace), burning ground (Wildfire), or Burn on allies' hits (Ember Choir).

| Upgrade | Effect |
| --- | --- |
| **Bright Mind** | MGK +10% of her current MGK (stacks) |
| **Quick Hands** | Attack speed +10% of her current attack speed (stacks) |
| **Cinder Robe** | Max HP +10% of her current max HP (stacks) |
| **Focus** | CRIT +25% of her current CRIT (stacks) |
| **Hot Hands** | Cinder Flick's Burn is 15% of her MGK, not 10% |
| **Wide Flare** | Flare's circle is 1 hex larger |
| **Fan the Coals** | Heat counts Burn ticks within 4 hexes, not 3 |
| **Kindled Start** | At the fight's start, the nearest enemy gains Burn equal to 40% of her MGK |
| **Heat Shimmer** | Enemies attacking her from within 1 hex miss 20% of their attacks |
| **Scorch** | +15% damage to Burning enemies |
| **Flashover** | When a Burning enemy dies within 3 hexes, she gains 10 mana |
| **Tinder Box** | Grows: +1% MGK per 1,000 Burn damage dealt within 3 hexes of her, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Furnace** | **Deep Stoke:** Stoke adds 7%, not 5%. **Kindled Hands:** +10% attack speed while attacking a Burning enemy | **Searing Stoke:** each Stoke also deals damage equal to 10% of her MGK. **Short Fuse:** Immolate costs 15 less mana. **Slow Coals:** Burn on her targets decays 60% slower, not 50%. **Ashfall:** Immolate's splash reaches 2 hexes. Growing: **Furnace Heart** (+1% attack speed per 200 Burn added by Stoke) |
| **Wildfire** | **Long Kindling:** her burning ground lasts 1s longer. **Wide Kindling:** Flare's burning ground is 1 hex larger | **Fast Spread:** her ground spreads every 1.5s, not 2s. **Far Spread:** up to 4 hexes from where it started. **Hot Ground:** enemies on it gain Burn equal to 15% of her MGK per second. **Smoke:** enemies on her ground miss 15% of their attacks. Growing: **Scorched Earth** (+1% ground Burn per 10 enemy-seconds on her ground) |
| **Ember Choir** | **Quick Blessing:** Blessing every 6s, not 8s. **Shared Blessing:** Blessing reaches the 2 nearest allies | **Fervor:** Hymn of Cinders also gives +10% ATK. **Rekindle:** when an ally kills a Burning enemy, she gains 10 mana. **Ember Ward:** allies take 10% less damage from Burning enemies. **Long Hymn:** Hymn lasts 2s longer. Growing: **Choir's Swell** (+1% to allies' Burn per 500 Burn applied by allies) |
```

**Add** to "Keyword sources this adds":

> - **Burning:** Ilse is the first hero built on Burn: every path applies it, and Heat turns all Burn near her into mana.

---

## 4. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** a new section after the Vell section, before "## Notes":

```markdown
## Ilse

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Blast Furnace** (Furnace) | +5% attack speed while her target is Burning | Stokes landed | Every 2nd basic attack stokes. **Snowball:** each Stoke gives her +2% attack speed and +1% MGK for the rest of the fight, with no cap | **Roaring Bellows:** +3% attack speed per Stoke. **Bellows:** each Stoke also adds 2% to the Burn on enemies within 1 hex |
| **Crucible** (Furnace) | Immolate leaves 10% of the Burn it set off | Damage dealt by Immolate | Immolate no longer removes the Burn it sets off. **Snowball:** each Immolate makes Stoke add +1% more for the rest of the fight | **White Heat:** +2% per Immolate. **Molten Core:** Immolate's splash reaches 2 hexes |
| **Living Flame** (Wildfire) | Her burning ground spreads toward the nearest enemy, not evenly | Enemies killed on her burning ground | Her fires creep 1 hex a second toward the nearest enemy group, never go out while an enemy is within 1 hex, and enemies on them gain Burn equal to 20% of her MGK per second. **Snowball:** each enemy that dies in her fire makes it 1 hex larger and 25% hotter for the rest of the fight, and starts a new fire under the nearest enemy | **Hungry Fire:** 40% hotter per kill. **Choking Smoke:** enemies on her fire are Slowed 20% |
| **Ring of Fire** (Wildfire) | Enemies stepping onto her burning ground gain Burn equal to 10% of her MGK | Times enemies step onto her burning ground | Firestorm draws a ring of fire around the largest group; rings last the rest of the fight, up to 3 at once. Enemies crossing one gain Burn equal to 80% of her MGK and are Slowed 30% for 2s. **Snowball:** each crossing makes every ring's Burn 10% stronger for the rest of the fight | **Searing Ring:** +15% per crossing. **Wide Ring:** rings are 1 hex wider |
| **Cinder Saint** (Ember Choir) | Allies she has blessed gain +5% ATK while blessed | Damage allies' basic attacks deal to Burning enemies | Allies deal +20% damage to Burning enemies, and the Burn on their basic attacks rises to 10% of her MGK. **Snowball:** every ally basic attack gives her +1% MGK (of her MGK at the fight's start, so it adds up rather than compounding) for the rest of the fight | **Rising Choir:** +1.5% MGK per ally attack. **Crowned in Flame:** allies get +10% ATK during Hymn |
| **Kindred Flame** (Ember Choir) | Every hero heals 0.2% of all Burn damage dealt | Healing from it | **Every hero heals 1% of all Burn damage dealt**, by anyone, anywhere. This is healing, not lifesteal. **Snowball:** overhealing from it becomes Burn on the nearest enemy (1 Burn per 5 overheal), so a healthy team feeds the fire that heals it | **Iron Embers:** every 500 healing from it gives each hero +3 DEF for the rest of the fight. **Hearth Embers:** heroes below 50% HP heal twice as much from it |
```

**Add** to "Notes":

> - **Kindred Flame scales with the team's total Burn, not with attack speed,** so it plays differently from Furnace. Its loop (heal → overheal → Burn → heal) gives back far less than it takes, so it can't run away by itself; the 1-per-5 rate is the number to tune.
> - **Blast Furnace and Furnace Heart** both grow her attack speed (one per fight, one per run): the fastest snowball in the game, on purpose. Watch it in testing.

---

## 5. `docs/plans/rebuild-content-pool.md` (part 7b)

**Replace** the Burning row's "Heroes and paths" cell in section 1's keyword table (after `changes-upgrade-pools.md` set it to `Vell (Ember Glow, an upgrade)`):

> `Vell (Ember Glow, an upgrade)` → `Ilse (every path), Vell (Ember Glow, an upgrade)`

---

## 6. Still to do (not in this file)

- **Maren's Rain of Ash apex** leaves burning ground, which overlaps with Wildfire. It needs a new idea.
- **Ilse's "makes / feeds on" line** waits for the synergy pass (tentative: Furnace makes Burn and feeds on Roots; Wildfire makes spreading Burn and feeds on clumps; Ember Choir makes Burn on allies' hits and feeds on extra hits).
- **Art:** four figures (base and three paths) and a portrait, to `asset-contract.md`; placeholders in the hero kit.

---

## 7. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet:

> a team of 3 (Brannoc, Maren, Vell for now)

with:

> a team of 3, chosen from Brannoc, Maren, Vell, and Ilse (the Burn caster)
