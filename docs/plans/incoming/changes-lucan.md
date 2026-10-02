# Changes: Lucan, the twelfth hero (the illusionist)

Decided 2026-10-02. This adds Lucan Merrow, a back-line caster who fills the field with copies. Mirrorwright gives Summons a second maker hero, Veilweaver gives Stealth a second payoff hero, and Puppeteer is the first Summons payoff. Like Severine's Gravecaller, he needs hero-side summons in the sim. Two of his apexes also need a new targeting state, where an enemy fights its own side.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-ottilie.md` (and the files it depends on).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Ottilie's section (8i), before "## 9. How the heroes fit together":

```markdown
## 8j. Lucan Merrow: the illusionist (caster)

*Added 2026-10-02.* **Role:** back-line caster who fills the field with copies; most of his damage comes from what he summons. Shares the damage role. Builds (`build-map.md`): Summons (maker, Mirrorwright; payoff, Puppeteer), Stealth (maker and payoff, Veilweaver).

| | |
| --- | --- |
| **Stats** | HP 270, ATK 8, MGK 18, DEF 8 |
| **Speed / range** | speed 2, up to 3 hexes |
| **Basic attack: Glimmer** | a shard of light at the nearest enemy in range (MGK damage); his main source of mana |
| **Signature: Mirror** (60 mana) | a copy of himself appears beside him for 6s, with 30% of his stats; it attacks with Glimmer but has no signature |
| **Passive: Unreal** | enemies attacking him miss 15% of the time |

- **Hero-side summons:** copies use the existing summon pieces, count toward the 30-units-per-side cap, and are logged as summons with their source (shared with Severine's Gravecaller).
- **"Allied unit"** means anything on your side of the field: heroes, copies, thralls, controlled enemies, any summon.

### Path 1: Mirrorwright (Summons: maker)

The fantasy: which one is real? All of them hit.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Reflection:** every 12s, a copy of him appears for 4s, at 20% of his stats | Reflection every 6s, copies at 40% of his stats, up to 3 at once; copies carry his basic-attack upgrades |
| **Signature** | Mirror | **Hall of Mirrors:** every ally gets a copy for 6s, at 30% of their stats (basic attack only) |
| **Cost** | –10% max HP | –15% MGK; his power is in the copies |

- **Deed:** copies made by Reflection (his base Mirror's copies don't count).
- **Plays off:** on-hit effects ride on copies (Ember Choir's Burn, Volley's split arrows doubled by Hall of Mirrors).

### Path 2: Veilweaver (Stealth: maker and payoff)

The fantasy: the one they aim at simply isn't there.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Shroud:** every 10s, the lowest-HP ally is hidden for 1s | Every 5s, the ally targeted by the most enemies is hidden for 1.5s, and an ally's first attack out of Stealth deals +40% damage and Silences for 0.5s |
| **Signature** | Mirror | **Vanishing Act:** every ally is hidden for 2s, and their next attack is a crit |
| **Cost** | –10% MGK | Mirror's copy lasts only 3s |

- **Deed:** Stealth given by Shroud.
- **Unlike Tamsin:** Tamsin hides herself to strike; Veilweaver hides whoever is in danger, and pays off Stealth for the whole team.

### Path 3: Puppeteer (Summons: payoff)

The fantasy: every body on the field is a string in his hand.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Strings:** +2% MGK for each allied unit on the field | +5% MGK and +3% attack speed per allied unit, and allied summons get +10% ATK and MGK |
| **Signature** | Mirror | **Dance of Strings:** for 5s, every allied summon gets +50% attack speed and attacks his target |
| **Cost** | –10% max HP | –1 range |

- **Deed:** extra damage from Strings.
- **Plays off:** his own copies, Severine's Gravecaller thralls, and the heroes themselves (3 at minimum).

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Lucan | 60 | +10 | none | 2/s | 0 |
```

**Add** to section 9 ("How the heroes fit together"):

> - **Lucan multiplies whatever the team already does:** copies carry allies' on-hit effects, Veilweaver keeps the threatened hidden, and Puppeteer grows with every unit on your side (Severine's thralls included).

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** a new section after Ottilie's section, before "## Notes":

```markdown
## Lucan

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Thousand Faces** (Mirrorwright) | His copies last 1s longer | Damage dealt by his copies | Up to 6 copies at once, at 50% of his stats; a copy that's destroyed bursts for 50% of his MGK within 1 hex. **Snowball:** each copy he makes gives later copies +2% of his stats for the rest of the fight (up to 80%) | **Perfect Likeness:** +3% per copy. **Shattering Glass:** bursts deal 80% of his MGK |
| **True Reflection** (Mirrorwright) | Hall of Mirrors lasts 2s longer | Damage dealt by allies' copies | Hall of Mirrors' copies are at 50% of each ally's stats and cast their signature once. No snowball | **Clear Glass:** 60% of their stats. **Mirror Guard:** the first hit on each ally lands on their copy instead |
| **Unseen Host** (Veilweaver) | Shroud hides for 0.5s longer | Attacks allies make out of Stealth | Shroud every 3s, hiding for 2s; the first attack out of Stealth deals +60% damage and Silences for 1s. **Snowball:** each first strike from Stealth gives every hero +2% crit damage for the rest of the fight | **Knife in the Dark:** +3% per strike. **Ghost Step:** leaving Stealth gives +1 speed for 2s |
| **Night Veil** (Veilweaver) | Vanishing Act hides for 0.5s longer | Times enemies lost their target | When an enemy's target vanishes, it's confused for 2s and attacks the nearest other enemy. No snowball | **Long Night:** confused for 3s. **Bewilder:** confused enemies take +20% damage |
| **Grand Puppeteer** (Puppeteer) | +1% attack speed per allied unit on the field | Attacks allied summons make during Dance of Strings | Dance of Strings stays on all fight at half strength (+25% attack speed for summons); casting it doubles that for 5s. **Snowball:** each summon that joins the field gives every summon +3% ATK and MGK for the rest of the fight | **Tight Weave:** +5% per summon. **Taut Strings:** summons take 15% less damage |
| **Marionette** (Puppeteer) | **Puppet Thread:** once per fight, the first enemy to drop below 30% HP fights for you for 3s | Seconds enemies fought for you | New signature **Marionette:** takes control of the enemy with the lowest HP (by %) for 6s; it fights for you and counts as an allied unit. Elites and bosses can't be controlled; they take +25% damage for 6s instead. **Snowball:** each controlled enemy that dies while under his control makes Strings' bonus +20% stronger for the rest of the fight | **Puppet Master:** +30% per kill. **Long Strings:** control lasts 8s |
```

**Add** to "Notes":

> - **Night Veil and Marionette need a new targeting state** in the sim: an enemy that attacks its own side (confused) or fights for yours (controlled), much like Taunt. Every switch is logged with its source.
> - **Elites and bosses can't be controlled,** so no apex can neutralize a boss.
> - **The 30-unit cap** is the hard limit on Thousand Faces, Hall of Mirrors, and Gravecaller together.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after Ottilie's section, before "## Left out on purpose":

```markdown
## Lucan

### Hero pool

These never give copies on a timer (Mirrorwright), hiding allies (Veilweaver), or power from counting allied units (Puppeteer).

| Upgrade | Effect |
| --- | --- |
| **Clear Mind** | MGK +10% of his current MGK (stacks) |
| **Quick Glimmer** | Attack speed +10% of his current attack speed (stacks) |
| **Silk Robes** | Max HP +10% of his current max HP (stacks) |
| **Keen Sight** | CRIT +25% of his current CRIT (stacks) |
| **Long Mirror** | Mirror's copy lasts 3s longer |
| **Strong Mirror** | Mirror's copy has 45% of his stats, not 30% |
| **Quick Mirror** | Mirror costs 10 less mana |
| **Deep Unreal** | Unreal's miss chance is 25%, not 15% |
| **Dazzling Glimmer** | Glimmer Slows by 10% for 1s |
| **Bright Shard** | Glimmer deals +20% damage to enemies attacking a copy or summon |
| **Misdirect** | When one of his copies is destroyed, he gains 10 mana |
| **Gallery** | Grows: +1% MGK per 20 copies made, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Mirrorwright** | **Quick Reflection:** Reflection every 10s, not 12s. **Lasting Reflection:** Reflection's copies last 5s | **Fast Reflection:** Reflection every 5s. **Many Mirrors:** up to 4 copies at once. **Long Hall:** Hall of Mirrors lasts 8s. **Quick Hall:** Hall of Mirrors costs 15 less mana. Growing: **Silvered Glass** (+1% copy stats per 50 copies made) |
| **Veilweaver** | **Quick Shroud:** Shroud every 8s, not 10s. **Deep Shroud:** Shroud hides for 1.5s | **Faster Shroud:** Shroud every 4s. **Shroud Splits:** Shroud also hides the next most-targeted ally. **Long Act:** Vanishing Act hides for 3s. **Veiled Step:** hidden allies get +1 speed. Growing: **Velvet Dark** (+1% first-strike damage per 20 strikes from Stealth) |
| **Puppeteer** | **Strong Strings:** Strings gives +3% MGK per unit, not 2%. **Lead Puppet:** his own copies count twice for Strings | **Long Dance:** Dance of Strings lasts 7s. **Quick Dance:** Dance of Strings costs 15 less mana. **Sharpened Puppets:** allied summons get +15% crit damage. **Sturdy Puppets:** allied summons get +20% max HP. Growing: **Old Strings** (+1% to Strings' bonus per 50 summons that join the field) |
```

**Add** to "Keyword sources this adds":

> - **Stealthed:** Veilweaver (Lucan) hides allies on a timer, beside Tamsin and Maren's hop.

---

## 4. `docs/plans/build-map.md` (created by `changes-build-map.md`)

In section 3's table:

- **Stealth row:** "Makers now" → `Maren's hop (Slip Away); Tamsin (Ambusher, Shadowstep, Nightblade, Veilmaster); Veilweaver, Unseen Host, Night Veil (Lucan)`. "Payoffs now" → `Nightblade, Phantom (Tamsin); Veilweaver, Unseen Host (Lucan); charms and relics`. "What's missing" → `Covered: two heroes`.
- **Summons row:** "Makers now" → `Gravecaller (Severine); Mirror, Mirrorwright, Thousand Faces, True Reflection (Lucan)`. "Payoffs now" → `Puppeteer, Grand Puppeteer, Marionette (Lucan)`. "What's missing" → `A Summons payoff on a second hero. Needs hero-side summons in the sim`.

In section 4's table, **add** a row:

```markdown
| 6 | **The illusionist** | Summons (maker and payoff), Stealth (payoff) | **Designed: Lucan Merrow** (`rebuild-heroes.md`, section 8j) |
```

**Replace** in Open questions (as set by `changes-ottilie.md`):

> - **Single-hero builds left (rule 5):** Stealth payoff (Tamsin only), Summons (Severine's Gravecaller only, no payoff), Burn makers (Ilse only), and Poison makers (Severine only). Planned: **the illusionist** (Summons maker and payoff, Stealth payoff); a later hero for the Burn and Poison makers.

with:

> - **Single-hero builds left (rule 5):** Burn makers (Ilse only), Poison makers (Severine only), and Summons payoffs (Lucan only). A later hero should cover them.

---

## 5. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (as set by `changes-ottilie.md`):

> and Ottilie (the alchemist)

with:

> Ottilie (the alchemist), and Lucan (the illusionist)
