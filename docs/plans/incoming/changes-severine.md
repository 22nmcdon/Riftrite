# Changes: Severine, the ninth hero (the blood warlock)

Decided 2026-10-02. This adds Severine Hollowell, a melee blood hunter whose only sustain is lifesteal: she never heals. She is the last hero from the build map's roster plan. Bloodglut gives Sustain its lifesteal payoff, Plaguebearer gives Poison its first build, and Hemomancer turns blood into spells. Her Gravecaller apex starts a Summons build, which needs hero-side summons in the sim.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-hob.md` (and the files it depends on).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Hob's section (8f), before "## 9. How the heroes fit together":

```markdown
## 8g. Severine Hollowell: the bloodwitch (melee; two paths become casters)

*Added 2026-10-02.* **Role:** a melee blood hunter in the thick of the fight. **She never heals: all her sustain is lifesteal.** Builds (`build-map.md`): Sustain (lifesteal payoff, Bloodglut), Poison (Plaguebearer), and blood-for-power (Hemomancer). Bloodglut and Plaguebearer stay melee on ATK; Hemomancer becomes a caster on MGK.

| | |
| --- | --- |
| **Stats** | HP 330, ATK 20, MGK 12, DEF 12 |
| **Speed / range** | speed 2, melee (1) |
| **Basic attack: Rend** | a clawing strike with 15% lifesteal; her main source of mana |
| **Signature: Drain** (60 mana) | strikes her target for 200% of her ATK, with 50% lifesteal |
| **Passive: Hemophage** | her lifesteal is doubled against enemies below 50% HP |

Being melee is the point: she's in the fight taking hits, so lifesteal matters to her.

### Path 1: Bloodglut (melee; grows on lifesteal past full)

The fantasy: she drinks past full and keeps swelling.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Engorge:** lifesteal past full HP raises her max HP by that much, for the rest of the fight (up to +5%) | Engorge has no cap, and Rend deals extra damage equal to 3% of her max HP |
| **Signature** | Drain | **Gorge:** strikes her target for 100% of her ATK plus 10% of her max HP, with 50% lifesteal |
| **Cost** | –10% ATK | –1 speed |

- **Deed:** max HP gained from Engorge.
- **The loop:** lifesteal past full → more max HP → more damage → more lifesteal.

### Path 2: Plaguebearer (melee; Poison)

The fantasy: every wound she opens festers, and she feeds on the sick.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Blight:** Rend applies Poison equal to 10% of her ATK | Rend applies Poison equal to 20% of her ATK, and her lifesteal is doubled against Poisoned enemies (direct hits only) |
| **Signature** | Drain | **Plague Burst:** a 2-hex cloud around her for 4s; enemies inside gain Poison equal to 30% of her ATK each second |
| **Cost** | –10% max HP | –10% ATK |

- **Deed:** Poison applied by Blight.
- **Poison never counts toward lifesteal;** only her direct hits on Poisoned enemies do (`rebuild-combos.md`, section 2b).

### Path 3: Hemomancer (becomes a caster; blood for power)

The fantasy: every drop above the line is a spell.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Blood Price:** Drain costs 30 mana plus 5% of her max HP, instead of 60 mana | She becomes a caster and **starts every fight at 50% HP**. Her basic attack is **Blood Bolt**: up to 3 hexes, 150% of her MGK, 25% lifesteal. Her signature costs 10% of her max HP and no mana, and she casts it whenever she's above 50% HP, with no cooldown |
| **Signature** | Drain | **Exsanguinate:** instant (no cast time, doesn't delay her attacks); hits her target and enemies within 1 hex for 400% of her MGK plus twice the HP she spent. No lifesteal |
| **Cost** | –10% DEF | Starting at 50% HP is the cost |

- **Deed:** HP spent on spells.
- **The flow:** lifestealing Blood Bolts push her above 50%; everything above the line becomes Exsanguinates. Lifesteal and attack speed set her cast rate.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Severine | 60 | +8 | none | 2/s | 0 (Hemomancer: none; she casts with HP) |
```

**Add** to section 9 ("How the heroes fit together"):

> - **Severine is the lifesteal payoff the relics needed:** Aldous's attack speed and the lifesteal relics (Shadow Engine, Blood Communion) feed Bloodglut and Hemomancer; Tamsin's Poisoned Blades feeds Plaguebearer.

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** a new section after Hob's section, before "## Notes":

```markdown
## Severine

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Leviathan** (Bloodglut) | Rend's bonus damage is 4% of her max HP, not 3% | Damage from Rend's max-HP bonus | Engorge raises her max HP by twice the lifesteal past full. **Snowball:** every 10% max HP she gains gives her +5% lifesteal for the rest of the fight | **Bottomless:** +8% per 10%. **Thick Hide:** +1 DEF per 5% max HP gained |
| **Sanguine Nova** (Bloodglut) | Gorge also hits enemies within 1 hex for half its damage | Damage dealt to enemies beside Gorge's target | New signature **Sanguine Nova:** releases half her bonus max HP from Engorge as damage to enemies within 2 hexes, and loses that bonus. **Snowball:** each Nova makes Engorge grow 20% faster for the rest of the fight | **Gluttony:** +30% per Nova. **Blood Rain:** Nova Slows by 30% for 2s |
| **Gravecaller** (Plaguebearer; the necromancer) | A Poisoned enemy that dies leaves a corpse cloud for 2s (Poison equal to 10% of her ATK each second) | Poison applied by corpse clouds | Poisoned enemies that die rise as her thralls, up to 3 at once: for 8s, at 30% of their HP, with their own kit, fighting for you. **Snowball:** each thrall raised makes later thralls last 2s longer and rise with 10% more HP, for the rest of the fight | **Deep Grave:** +20% HP per thrall. **Plague Thralls:** thralls' attacks apply Poison equal to 10% of her ATK |
| **Pestilence** (Plaguebearer) | Plague Burst lasts 1s longer | Enemy-seconds spent inside Plague Burst | Plague Burst covers 3 hexes, and enemies inside deal 15% less damage. **Snowball:** each enemy that dies while Poisoned makes all Poison 20% stronger for the rest of the fight | **Epidemic:** +30% per kill. **Wasting:** Poisoned enemies are Slowed 15% |
| **Blood Tide** (Hemomancer) | She starts fights at 55% HP, not 50% | Damage dealt by Exsanguinate | She can cast down to 30% HP, not 50%, and Exsanguinate adds 3× the HP spent, not 2×. **Snowball:** each cast gives her Blood Bolt +3% lifesteal for the rest of the fight | **Crimson Flood:** +5% per cast. **Crimson Spray:** Exsanguinate's splash reaches 2 hexes |
| **Blood Rite** (Hemomancer) | Each Exsanguinate gives allies within 2 hexes +5% ATK for 3s | Attacks allies make during Blood Rite | Each Exsanguinate gives every ally +20% ATK and MGK for 4s. **Snowball:** every 100 HP she spends gives every hero +2% ATK and MGK for the rest of the fight | **Sacrament:** +3% per 100 HP. **Shared Blood:** Blood Rite also gives allies 5% lifesteal |
```

**Add** to "Notes":

> - **Severine never heals,** in her apexes too: Blood Rite's Shared Blood gives lifesteal, not healing.
> - **Gravecaller needs hero-side summons in the sim.** Only enemies summon today. Thralls use the existing summon pieces, count toward the 30-units-per-side cap, and are logged as summons with their source.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after Hob's section, before "## Left out on purpose":

```markdown
## Severine

### Hero pool

These never give growth from lifesteal past full (Bloodglut), Poison (Plaguebearer), or spending HP (Hemomancer). No upgrade of hers heals.

| Upgrade | Effect |
| --- | --- |
| **Sharp Claws** | ATK +10% of her current ATK (stacks) |
| **Quick Talons** | Attack speed +10% of her current attack speed (stacks) |
| **Thick Blood** | Max HP +10% of her current max HP (stacks) |
| **Hardened Skin** | DEF +10% of her current DEF (stacks) |
| **Deep Bite** | Rend's lifesteal is 20%, not 15% |
| **Hungry Drain** | Drain's lifesteal is 75%, not 50% |
| **Heavy Drain** | Drain hits for 250% of her ATK |
| **Blood Scent** | +15% damage to enemies below 50% HP |
| **Frenzy** | +15% attack speed while she's below 50% HP |
| **Predator** | Drain goes for the lowest-HP enemy within 3 hexes |
| **Wounded Rage** | She gains 2 mana when she's hit |
| **Old Thirst** | Grows: +1% lifesteal per 2,000 healing from lifesteal, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Bloodglut** | **Greedy Gorge:** Engorge's taste cap rises to +10%. **Swell:** +5% lifesteal on Rend while she's at full HP | **Massive:** Gorge hits for 15% of her max HP, not 10%. **Overflow:** lifesteal past full counts 20% more toward Engorge. **Feast:** a kill with Gorge gives back 20 mana. **Heavy Frame:** she can't be knocked back while above 120% of her starting max HP. Growing: **Ever Hungry** (+1% to Engorge's growth per 1,000 max HP gained) |
| **Plaguebearer** | **Virulent:** Blight's Poison is 15% of her ATK, not 10%. **Toxic Claws:** +10% damage to Poisoned enemies | **Septic Wounds:** Rend deals +20% damage to Poisoned enemies. **Carrier:** Plague Burst moves with her. **Weakening Venom:** Poisoned enemies she hits deal 10% less damage for 2s. **Quick Burst:** Plague Burst costs 10 less mana. Growing: **Strain** (+1% to Blight's Poison per 500 Poison applied) |
| **Hemomancer** | **Thin Blood:** Blood Price costs 4% of her max HP, not 5%. **Bloodied Focus:** +10% MGK | **Long Bolt:** Blood Bolt reaches 4 hexes. **Bloodline:** Exsanguinate costs 8% of her max HP, not 10%. **Leeching Bolt:** Blood Bolt's lifesteal is 30%, not 25%. **Hemorrhage:** Exsanguinate applies Bleed equal to 20% of her MGK. Growing: **Blood Memory** (+1% Exsanguinate damage per 500 HP spent) |
```

**Add** to "Keyword sources this adds":

> - **Poison:** Plaguebearer (Severine) is the first Poison build; Tamsin's Poisoned Blades is a second maker.

---

## 4. `docs/plans/build-map.md` (created by `changes-build-map.md`)

In section 3's table:

- **Sustain row:** "Payoffs now" → `Bloodglut, Leviathan, Hemomancer (Severine); Spitemail, Thorned King, Vengeance (Garrow); Last Watch`. "What's missing" → `Covered for now`.

**Add** two rows to section 3's table:

```markdown
| **Poison** | Plaguebearer (Severine); Poisoned Blades (a Tamsin upgrade) | Plaguebearer, Pestilence (Severine) | **A payoff on another hero:** someone who gets stronger from Poisoned enemies |
| **Summons** | Gravecaller (Severine's apex) | None yet | **The whole build:** a summoner hero, and payoffs for having allies on the field. Needs hero-side summons in the sim |
```

In section 4's table, **replace** the blood warlock row's "Notes" cell with:

> **Designed: Severine Hollowell** (`rebuild-heroes.md`, section 8g). Melee, lifesteal only (never heals); Plaguebearer took Poison instead of a second Burn payoff, so Burn's second payoff stays open

**Replace** in Open questions (as set by `changes-hob.md`):

> - **The last hero in the plan:** the blood warlock (Sustain's lifesteal payoff).

with:

> - **The roster plan is done.** Gaps left: a Burn payoff that isn't Ilse, a Poison payoff on another hero, and the Summons build. Next heroes come from those.

---

## 5. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (as set by `changes-hob.md`):

> and Hob (the scavenger)

with:

> Hob (the scavenger), and Severine (the blood warlock)
