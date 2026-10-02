# Changes: Garrow, the sixth hero (the shield-bruiser)

Decided 2026-10-02. This adds Garrow of the Chains, a front-line bruiser. He is the second hero from the build map's roster plan, and fills the Shield payoff (Aegisfang), a second Clump maker (Chainwarden), and a thorns payoff for Sustain (Spitemail). It also extends the "no attribution" rule from Burn to every damage-over-time status.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-tamsin.md` (and the files it depends on).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Tamsin's section (8c), before "## 9. How the heroes fit together":

```markdown
## 8d. Garrow of the Chains: the anchor (bruiser)

*Added 2026-10-02.* **Role:** front line, like Brannoc, but he trades protecting allies for hitting back and dragging enemies in. Shares the tank role with Brannoc. Builds (`build-map.md`): Shield (payoff), Clump (maker), Sustain (thorns payoff).

| | |
| --- | --- |
| **Stats** | HP 380, ATK 18, DEF 22 |
| **Speed / range** | speed 2, melee (1) |
| **Basic attack: Chain Fist** | a heavy blow on an adjacent enemy |
| **Signature: Haul** (70 mana) | throws a chain at the farthest enemy within 4 hexes and pulls it next to him |
| **Passive: Stand Fast** | the first time each fight he drops below 50% HP, he gains a Shield of 15% of his max HP |
| **Trait: Heavy** | he can't be knocked back or pulled |

### Path 1: Aegisfang (Shield: makes his own, then cashes it in)

The fantasy: every blow thickens his armor, and the armor is the weapon.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Plated Blows:** each basic attack gives him a Shield of 1% of his max HP | Each basic attack gives him a Shield of 3% of his max HP, up to a Shield of 50% of his max HP |
| **Signature** | Haul | **Bulwark Burst:** his whole Shield bursts, dealing 150% of its value as damage to enemies within 1 hex |
| **Cost** | –10% max HP | –15% DEF |

- **Deed:** Shield he gives himself from his attacks. Only Plated Blows does that.
- **Bulwark Burst uses his whole Shield, including Shields from allies** (Wardweaver, Hearthguard, Tithe of Iron): other heroes' Shields become his damage. That's what makes him the Shield payoff.
- **Attack speed matters:** faster attacks build the Shield faster.

### Path 2: Chainwarden (Clump: drags enemies in, grows stronger with them close)

The fantasy: the chains bring them to him, and every one in reach makes him stronger.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Barbed Chain:** Haul applies Bleed equal to 20% of his ATK to the enemy it pulls | Haul pulls up to 3 enemies, Bleeding each. **Crowd Strength:** +5% ATK and +2 DEF for each enemy within 1 hex |
| **Signature** | Haul | **Maelstrom:** pulls every enemy within 3 hexes next to him, Roots them for 1s, and applies Bleed equal to 30% of his ATK to each. He can attack again at once |
| **Cost** | –10% ATK | –1 speed |

- **Deed:** Bleed applied by his chains. Only Barbed Chain applies it. (It counts Bleed *applied*, never Bleed damage; see section 5.)
- **No taunting:** enemies come to him because he drags them, not because he forces their attention. That keeps him apart from Brannoc.
- **Plays off:** clump payoffs (Volley, Wildfire, Arrow Storm, Sunfall, Ironbrand's cleave); Maelstrom's Roots feed Garrote and Deadeye.

### Path 3: Spitemail (Sustain: thorns)

The fantasy: every blow on him costs the one who struck it.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Spikes:** enemies hitting him take 5% of the damage back | Enemies hitting him take 25% of the damage back, and he heals for half of what he sends back |
| **Signature** | Haul | **Iron Maiden:** for 4s, he taunts enemies within 2 hexes and sends back 100% of the damage |
| **Cost** | –10% ATK | Healing from others on him is 20% weaker |

- **Deed:** damage sent back by Spikes. Only Spikes sends damage back.
- **Unlike Last Watch:** both taunt, but Last Watch wants to be near death, and Spitemail wants to be hit a lot at any HP.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Garrow | 70 | +6 | +1 per 10 damage taken | none | 0 |
```

**Replace** in section 5 (the line added by `changes-ilse.md`):

> - **Burn is one shared pile of stacks** on an enemy. **Nothing may depend on who applied it,** only on how much is there. (No per-source tracking in the sim.)

with:

> - **Damage over time (Burn, Bleed, Poison) is one shared pile of stacks** on an enemy. **Nothing may depend on who applied it,** only on how much is there, or on how much a hero *applied* at the moment they applied it. (No per-source tracking in the sim.)

**Add** to section 9 ("How the heroes fit together"):

> - **Garrow turns other heroes' work into his:** Shields from Vell and Brannoc into Bulwark Burst, clumps into Crowd Strength, and enemy attention into damage sent back. Chainwarden's pulls set up Volley, Wildfire, Tamsin, and Ironbrand.

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** a new section after Tamsin's section, before "## Notes":

```markdown
## Garrow

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Endless Bulwark** (Aegisfang) | His Shield cap rises to 60% of his max HP | Shield gained past 50% of his max HP | **No Shield cap.** **Snowball:** the Shield each attack gives grows by +0.5% of his max HP for the rest of the fight | **Layered Plate:** +1% per attack. **Plate on Plate:** while his Shield is bigger than his max HP, he takes 20% less damage |
| **Shatterburst** (Aegisfang) | Bulwark Burst reaches 2 hexes | Damage dealt by Bulwark Burst | Bulwark Burst deals 250% of the Shield, reaches 2 hexes, and leaves him 25% of the Shield. **Snowball:** each enemy hit by a Burst makes later Bursts +5% stronger, for the rest of the fight | **Echoing Burst:** +8% per enemy hit. **Aftershock:** Bursts Stun for 0.5s |
| **Grinder** (Chainwarden) | Enemies within 1 hex take damage equal to 3% of his ATK each second | Damage dealt by it | Enemies within 1 hex take damage equal to 25% of his ATK each second. **Snowball:** each enemy that dies within 1 hex makes it +20% stronger for the rest of the fight | **Meat Grinder:** +30% per kill. **Barbed Ring:** it also applies Bleed equal to 5% of his ATK each second |
| **Undertow** (Chainwarden) | Haul reaches 1 hex further | Hexes enemies are pulled | Every 4s, every enemy within 4 hexes is pulled 1 hex toward him; Maelstrom reaches 4 hexes and Roots for 2s. **Snowball:** each enemy pulled next to him gives him +1% ATK and +1 DEF for the rest of the fight | **Deep Current:** +2% and +2 per pull. **Drowning Depths:** pulled enemies are Slowed 30% for 2s |
| **Thorned King** (Spitemail) | Spikes sends back 7%, not 5% | Damage sent back during Iron Maiden | He always sends back 50%, and damage he sends back also hits enemies within 1 hex of the attacker. **Snowball:** every 1,000 damage sent back raises it by +5% for the rest of the fight | **Crown of Thorns:** +8% per 1,000. **Barbed Hide:** damage he sends back applies Bleed |
| **Vengeance** (Spitemail) | 5% of each hit he takes is stored instead of taken, and released the next time Iron Maiden ends | Damage he releases | 50% of each hit he takes is stored instead of taken. When Iron Maiden ends, it's all released as a blast on enemies within 2 hexes; if he falls, it's released at once. **Snowball (Grudge):** stored damage grows by 3% every second until it's released | **Wrath:** grows by 5% a second. **Patient Fury:** the blast also heals him for 20% of its damage |
```

**Add** to "Notes":

> - **Vengeance's Grudge** is the only snowball that grows by waiting: Iron Maiden's timing (and any sigil that changes it) decides the blast's size.
> - **Endless Bulwark** has no Shield cap at all; Bulwark Burst still spends the Shield, so the cap's job moves to how often he bursts.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after Tamsin's section, before "## Left out on purpose":

```markdown
## Garrow

### Hero pool

These never give Shield from attacks (Aegisfang), multi-pulls, chain Bleed, or Crowd Strength (Chainwarden), or sending damage back (Spitemail).

| Upgrade | Effect |
| --- | --- |
| **Iron Frame** | Max HP +10% of his current max HP (stacks) |
| **Heavy Plate** | DEF +10% of his current DEF (stacks) |
| **Thick Fists** | ATK +10% of his current ATK (stacks) |
| **Steady Swing** | Attack speed +10% of his current attack speed (stacks) |
| **Swift Haul** | Haul costs 10 less mana |
| **Hard Landing** | An enemy pulled by Haul is Stunned for 0.5s when it lands |
| **Second Stand** | Stand Fast can trigger again, the first time he drops below 25% HP |
| **Deep Stand** | Stand Fast's Shield is 25% of his max HP, not 15% |
| **Anchor's Weight** | Enemies he hits are Slowed 15% for 1s |
| **Bitter Mana** | +50% mana from damage taken |
| **Iron Will** | Stuns on him last half as long |
| **Scarred Iron** | Grows: +1 DEF per 1,500 damage he takes, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Aegisfang** | **Thick Plating:** Plated Blows gives 1.5%, not 1%. **Braced Strike:** +10% attack speed while Shielded | **Quick Burst:** Bulwark Burst costs 15 less mana. **Reinforce:** each attack's Shield is 4% of his max HP, not 3%. **Spiked Plate:** +15% ATK while Shielded. **Shared Ward:** when Bulwark Burst fires, allies within 2 hexes get a Shield of 10% of the Shield he burst. Growing: **Forged Aegis** (+1% Bulwark Burst damage per 1,000 Shield he gains from attacks) |
| **Chainwarden** | **Long Barbs:** Barbed Chain's Bleed is 30% of his ATK, not 20%. **Heavy Chain:** Haul's target is Slowed 30% for 2s | **Wide Crowd:** Crowd Strength counts enemies within 2 hexes. **Iron Hooks:** Maelstrom Roots for 1.5s. **Bloodied Links:** Bleeding enemies count twice for Crowd Strength. **Back-Line Hook:** Haul targets enemy casters and archers first. Growing: **Iron Links** (+1% to Crowd Strength's ATK bonus per 20 enemies pulled) |
| **Spitemail** | **Bitter Blood:** damage Spikes sends back ignores DEF. **Prickly:** +10% DEF | **Long Maiden:** Iron Maiden lasts 1s longer. **Wide Maiden:** Iron Maiden taunts within 3 hexes. **Spiteful Heal:** he heals for 75% of what he sends back, not half. **Thorn Burst:** when Iron Maiden ends, enemies within 1 hex are Stunned for 0.5s. Growing: **Old Grudge** (+1% damage sent back per 2,000 sent back) |
```

**Add** to "How the pools work":

> - **A shared role pool waits for a third hero in a role.** Brannoc and Garrow are both tanks, but two heroes don't need a shared pool yet.

**Add** to "Keyword sources this adds":

> - **Bleeding:** Chainwarden (Garrow) applies Bleed with every chain.

---

## 4. `docs/plans/build-map.md` (created by `changes-build-map.md`)

In section 3's table:

- **Shield row:** "Payoffs now" → `Aegisfang, Endless Bulwark, Shatterburst (Garrow); Thornweave (Wardweaver's apex)`. "What's missing" → `Covered for now`.
- **Clump row:** "Makers now" → `Chainwarden and Undertow (Garrow); Last Watch's taunts; Hold the Line (Brannoc)`. "What's missing" → `Covered for now`.
- **Sustain row:** "Payoffs now" → `Spitemail, Thorned King, Vengeance (Garrow); Last Watch`. "What's missing" → `A lifesteal payoff (the blood warlock)`.

In section 4's table, **replace** the shield-bruiser row's "Notes" cell with:

> **Designed: Garrow of the Chains** (`rebuild-heroes.md`, section 8d)

**Replace** in Open questions (as set by `changes-tamsin.md`):

> - **Which hero comes after Tamsin:** the shield-bruiser fills the most remaining gaps.

with:

> - **Which hero comes after Garrow:** the battery (Mana and Rangers, both still open).

---

## 5. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (as set by `changes-tamsin.md`):

> a team of 3, chosen from Brannoc, Maren, Vell, Ilse (the Burn caster), and Tamsin (the assassin)

with:

> a team of 3, chosen from Brannoc, Maren, Vell, Ilse (the Burn caster), Tamsin (the assassin), and Garrow (the shield-bruiser)
