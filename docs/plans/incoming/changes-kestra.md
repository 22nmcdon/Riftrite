# Changes: Kestra, the thirteenth hero (the beastwarden)

Decided 2026-10-02. This adds Kestra Fenn, a spear fighter who fights beside her rift-hound, Grit. Her paths close the last single-hero gaps:

- **Cinderhound** is a second Burn maker hero.
- **Serpent-Keeper** is a second Poison maker hero.
- **Packleader** is a second Summons payoff hero.

With her, every build passes the build map's rules 5 and 6. Grit adds a new kind of summon: permanent, and he returns after he falls.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-lucan.md` (and the files it depends on).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Lucan's section (8j), before "## 9. How the heroes fit together":

```markdown
## 8k. Kestra Fenn: the beastwarden (skirmisher with a companion)

*Added 2026-10-02.* **Role:** a mid-line spear fighter who fights beside her rift-hound. Builds (`build-map.md`): Burn (maker, Cinderhound), Poison (maker, Serpent-Keeper), Summons (payoff, Packleader; and a maker, through her pets).

| | |
| --- | --- |
| **Stats** | HP 300, ATK 18, DEF 12, CRIT 8 |
| **Speed / range** | speed 2, spear at up to 2 hexes |
| **Basic attack: Spear Jab** | a thrust at the nearest enemy in range; her main source of mana |
| **Companion: Grit** | a rift-hound that starts every fight beside her: 40% of her max HP, 60% of her ATK, fast melee. If Grit falls, he returns 10s later. He counts as an allied summon |
| **Signature: Sic 'Em** (50 mana) | Grit leaps to her target and bites for 200% of his ATK |
| **Passive: Bond** | while Grit is up, both get +10% attack speed |

- **Grit is a new kind of summon:** permanent for the fight, and he returns after falling. He uses the hero-side summon pieces (shared with Severine's thralls and Lucan's copies), counts toward the 30-units-per-side cap, and is logged with his source.

### Path 1: Cinderhound (Burn: maker)

The fantasy: her hound runs hot, and everything it bites catches.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Smoldering Fangs:** every 3rd bite from Grit applies Burn equal to 20% of her ATK | Grit is ember-wreathed: every bite applies Burn equal to 15% of her ATK, and enemies that hit him gain Burn equal to 10% of her ATK |
| **Signature** | Sic 'Em | **Firebrand Pounce:** Grit leaps to her target and bursts, applying Burn equal to 60% of her ATK to enemies within 1 hex |
| **Cost** | –10% ATK | Grit has 20% less HP |

- **Deed:** Burn applied by Smoldering Fangs.
- **Unlike Ilse:** Ilse's Burn scales with MGK and her own casting; Kestra's rides on her hound and scales with ATK.

### Path 2: Serpent-Keeper (Poison: maker)

The fantasy: the rift's vipers answer to her.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Venomed Jab:** every 3rd Spear Jab applies Poison equal to 15% of her ATK | Grit is replaced by a rift viper that spits from up to 3 hexes, applying Poison equal to 20% of her ATK; her jabs apply Poison equal to 10% of her ATK |
| **Signature** | Sic 'Em | **Nest:** releases 3 small vipers for 6s, whose bites apply Poison equal to 10% of her ATK |
| **Cost** | –10% max HP | The viper has 20% less HP than Grit |

- **Deed:** Poison applied by Venomed Jab.
- **Unlike Severine:** Severine's Poison comes from her own melee claws and pays off with lifesteal; Kestra's comes from her spear and ranged pets.

### Path 3: Packleader (Summons: payoff)

The fantasy: the pack is the weapon, and she runs it.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Pack Call:** Grit gets +3% ATK for each allied summon on the field | Two hounds (Grit and a second). Every allied summon gets +5% ATK and attack speed per allied summon. **Pack Fury:** when an allied summon falls, the others get +15% attack speed for 4s |
| **Signature** | Sic 'Em | **Howl:** every allied summon gets +40% ATK and a Shield of 20% of its max HP for 5s |
| **Cost** | –10% ATK | –1 range |

- **Deed:** extra damage from Pack Call.
- **Unlike Lucan's Puppeteer:** Lucan counts every allied unit (heroes too) and powers himself; Kestra counts summons only and powers the summons.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Kestra | 50 | +8 | none | 2/s | 0 |
```

**Add** to section 9 ("How the heroes fit together"):

> - **Kestra completes the summons team** with Lucan and Severine, and gives Burn and Poison teams a second maker that isn't a caster.

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** a new section after Lucan's section, before "## Notes":

```markdown
## Kestra

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Hellhound** (Cinderhound) | Smoldering Fangs every 2nd bite, not every 3rd | Burn applied by Grit | Grit is wreathed in fire: enemies within 1 hex of him gain Burn equal to 10% of her ATK every second, and he takes 30% less damage from Burning enemies. **Snowball:** each enemy that dies Burning within 2 hexes of Grit gives him +15% ATK for the rest of the fight | **Inferno Hound:** +20% per kill. **Ember Coat:** his fire reaches 2 hexes |
| **Firestarter** (Cinderhound) | Firebrand Pounce also lands on 1 more enemy | Burn applied by allied summons | Every allied summon's attacks apply Burn equal to 10% of her ATK (her hounds, Lucan's copies, Severine's thralls, all of them). No snowball | **Hotter Pack:** 15% of her ATK. **Kindled Pack:** a summon that falls bursts, applying Burn equal to 40% of her ATK within 1 hex |
| **Brood Mother** (Serpent-Keeper) | Nest releases 4 vipers, not 3 | Poison applied by Nest's vipers | Nest's vipers stay all fight (up to 6 at once), and each cast adds 3 more. No snowball | **Big Brood:** up to 9 at once. **Venom Glands:** vipers' Poison is 15% of her ATK |
| **Viper Queen** (Serpent-Keeper) | Her viper's spit Slows by 10% for 1s | Poison applied by her viper | Her viper's Poison is 35% of her ATK and its spit Slows by 20%. **Snowball:** each enemy that dies Poisoned gives the viper +15% ATK and max HP for the rest of the fight | **Queen's Venom:** +25% per kill. **Constrict:** every 8s, the viper Roots its target for 1s |
| **Alpha** (Packleader) | Pack Fury gives +20% attack speed, not 15% | Attacks summons make under Pack Fury | Three hounds, and Pack Fury lasts the rest of the fight instead of 4s. **Snowball:** each allied summon that falls gives every summon +10% attack speed for the rest of the fight | **Blood of the Pack:** +15% per fall. **Bloodied Pack:** summons get 5% lifesteal |
| **Wild Hunt** (Packleader) | Howl lasts 1s longer | Damage summons deal during Howl | Howl lasts 8s, and summons under it Mark what they hit and deal +25% damage to Marked enemies. No snowball | **Long Howl:** 10s. **Blood Scent:** summons under Howl get +1 speed |
```

**Add** to "Notes":

> - **Firestarter makes a summons team a Burn team:** every summon on your side applies Burn, whoever summoned it.
> - **Alpha rewards summons falling,** and Lucan's copies fall constantly: a natural combo; the per-fall amount is the number to tune.
> - **Brood Mother with Lucan's Thousand Faces** can reach the 30-unit cap fast; the cap is the limit.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after Lucan's section, before "## Left out on purpose":

```markdown
## Kestra

### Hero pool

These never give Burn on Grit (Cinderhound), Poison (Serpent-Keeper), or bonuses from counting summons (Packleader).

| Upgrade | Effect |
| --- | --- |
| **Hard Muscle** | ATK +10% of her current ATK (stacks) |
| **Quick Spear** | Attack speed +10% of her current attack speed (stacks) |
| **Hide Armor** | Max HP +10% of her current max HP (stacks) |
| **Hunter's Eye** | CRIT +25% of her current CRIT (stacks) |
| **Big Grit** | Grit has 55% of her max HP, not 40% |
| **Fierce Grit** | Grit has 75% of her ATK, not 60% |
| **Quick Return** | Grit returns 6s after falling, not 10s |
| **Hard Bite** | Sic 'Em bites for 250% of Grit's ATK |
| **Quick Sic** | Sic 'Em costs 10 less mana |
| **Strong Bond** | Bond gives +15% attack speed, not 10% |
| **Guard Dog** | Grit goes after enemies attacking her first |
| **Old Leash** | Grows: +1% to Grit's ATK per 10 kills he makes, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Cinderhound** | **Hot Fangs:** Smoldering Fangs' Burn is 25% of her ATK, not 20%. **Ashen Coat:** Grit takes 10% less damage from Burning enemies | **Long Pounce:** Firebrand Pounce's burst reaches 2 hexes. **Quick Pounce:** Firebrand Pounce costs 10 less mana. **Searing Bite:** Grit deals +15% damage to Burning enemies. **Fire Retort:** enemies that hit Grit gain Burn equal to 15% of her ATK, not 10%. Growing: **Kindled Hound** (+1% to Grit's Burn per 500 Burn he applies) |
| **Serpent-Keeper** | **Sharp Jab:** Venomed Jab every 2nd jab, not every 3rd. **Thick Venom:** Venomed Jab's Poison is 20% of her ATK | **Long Nest:** Nest's vipers last 9s. **Quick Nest:** Nest costs 10 less mana. **Long Spit:** her viper spits from up to 4 hexes. **Numbing Venom:** Poisoned enemies she hits are Slowed 10% for 1s. Growing: **Serpent Lore** (+1% to her viper's Poison per 500 Poison it applies) |
| **Packleader** | **Strong Call:** Pack Call gives +4% ATK per summon, not 3%. **Loyal Hound:** Grit returns 5s after falling | **Lasting Howl:** Howl lasts 7s. **Quick Howl:** Howl costs 15 less mana. **Pack Tactics:** summons attacking the same enemy deal +10% damage. **Thick Hides:** summons get +15% max HP. Growing: **Pack Lore** (+1% to the per-summon bonus per 50 summons that join the field) |
```

**Add** to "Keyword sources this adds":

> - **Burning and Poisoned:** Cinderhound and Serpent-Keeper (Kestra) are the second makers for each, beside Ilse and Severine.
> - **Marked:** Wild Hunt (Kestra) lets summons Mark what they hit.

---

## 4. `docs/plans/build-map.md` (created by `changes-build-map.md`)

In section 3's table:

- **Burn row:** "Makers now" → `Ilse (every path); Cinderhound, Hellhound, Firestarter (Kestra); Ember Glow (a Vell upgrade)`. "What's missing" → `Covered: two heroes`.
- **Poison row:** "Makers now" → `Plaguebearer (Severine); Serpent-Keeper, Brood Mother, Viper Queen (Kestra); Poisoned Blades (a Tamsin upgrade)`. "What's missing" → `Covered: two heroes`.
- **Summons row:** "Makers now" → `Gravecaller (Severine); Mirror, Mirrorwright, Thousand Faces, True Reflection (Lucan); Grit, Nest, Packleader's hounds (Kestra)`. "Payoffs now" → `Puppeteer, Grand Puppeteer, Marionette (Lucan); Packleader, Alpha, Wild Hunt (Kestra)`. "What's missing" → `Covered: two heroes`.
- **Mark row:** "Makers now" → add `Wild Hunt (Kestra)`.

In section 4's table, **add** a row:

```markdown
| 7 | **The beastwarden** | Burn (maker), Poison (maker), Summons (payoff) | **Designed: Kestra Fenn** (`rebuild-heroes.md`, section 8k) |
```

**Replace** in Open questions (as set by `changes-lucan.md`):

> - **Single-hero builds left (rule 5):** Burn makers (Ilse only), Poison makers (Severine only), and Summons payoffs (Lucan only). A later hero should cover them.

with:

> - **Every build passes rules 5 and 6** with 13 heroes. New heroes from here add variety, and should still be checked against this map.

---

## 5. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (as set by `changes-lucan.md`):

> and Lucan (the illusionist)

with:

> Lucan (the illusionist), and Kestra (the beastwarden)
