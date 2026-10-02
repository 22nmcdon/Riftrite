# Changes: Tamsin, the fifth hero (the assassin)

Decided 2026-10-02. This adds Tamsin Gloamstep, a melee assassin. She is the first hero from the build map's roster plan and fills three gaps: Stealth (maker and payoff), Mark (payoff), and Root (payoff). It also adds a rule that rarer snowball triggers get bigger payoffs, and buffs Inquisitor to match.

Each section below is one file. **Replace** means swap the quoted text for the new text, **Add** means insert it where stated, and **Remove** means delete it. Paths are from the repo root. Apply after `changes-upgrade-pools.md`, `changes-apexes.md`, `changes-ilse.md`, and `changes-build-map.md` (this file adds to what they create).

---

## 1. `docs/plans/rebuild-heroes.md` (part 2)

**Add** a new section after Ilse's section (8b), before "## 9. How the heroes fit together":

```markdown
## 8c. Tamsin Gloamstep: the knife (melee damage)

*Added 2026-10-02.* **Role:** a flanker who goes after weak or held targets in the back line; very fragile if caught. The first melee damage hero (Maren and Ilse are ranged; Brannoc tanks). Builds (`build-map.md`): Stealth, Mark, and Root.

| | |
| --- | --- |
| **Stats** | HP 280, ATK 24, DEF 10, CRIT 15, fast attacks |
| **Speed / range** | speed 3, melee (1) |
| **Targeting** | the lowest-HP (by %) enemy within 3 hexes, otherwise the nearest |
| **Basic attack: Knife** | a quick stab; her main source of mana |
| **Signature: Shadowstep** (50 mana) | she's hidden for 2s and slips behind her target |
| **Passive: Ambusher** | she starts every fight hidden for 2s, and attacks from Stealth always crit |

### Path 1: Nightblade (Stealth: maker and payoff)

The fantasy: she's never where you look.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Fade:** a kill hides her for 1s | Kills hide her for 2s and refund 30% of her mana; attacks from Stealth deal +50% damage |
| **Signature** | Shadowstep | **Shadow Dance:** hidden for 3s, and her next 3 attacks don't break Stealth |
| **Cost** | –10% max HP | Healing on her is 30% weaker while she's hidden |

- **Deed:** Stealth gained from kills. Only Fade hides her after a kill; Stealth from Ambusher and Shadowstep doesn't count.

### Path 2: Headhunter (Mark: payoff)

The fantasy: once she has your scent, you're already dead.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Scent:** she goes after Marked enemies first (within 4 hexes), and her hits extend a Mark by 0.5s | +30% damage to Marked enemies. Killing a Marked enemy lets her step to the next Marked enemy within 4 hexes, and her attack resets |
| **Signature** | Shadowstep | **Sentence:** a strike on a Marked enemy for 250% of her ATK; if it kills, it fires again for free (once) |
| **Cost** | –10% ATK against unmarked enemies | Nothing special against an enemy with no Mark |

- **Deed:** seconds of Mark she extended. Only Scent extends Marks.
- **Plays off:** Mark makers (Maren's Marking Shot, Brand of Guilt, Hunter's Chalk, later the scavenger's Bounty Hunter).

### Path 3: Garrote (Root: payoff)

The fantasy: hold still, and it's over.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Choke:** her crits on Rooted or Stunned enemies extend the hold by 0.3s | Her attacks on Rooted or Stunned enemies always crit, with +25% crit damage, and extend the hold by 0.5s |
| **Signature** | Shadowstep | **Garrote:** she grabs her target, Rooting it for 2s, hitting it for 30% of her ATK every 0.5s, and staying hidden while she holds it |
| **Cost** | –1 speed | She can't move while garroting |

- **Deed:** seconds of hold she extended. Only Choke extends holds.
- **Plays off:** Root and Stun makers (Trapper, Ironbrand's knock-into-stun, Bramble Knot). Garrote also makes Roots, which feeds other Root payoffs.

- **The counter:** the Watchful enemy upgrade (`enemy-growth.md`) lets enemies target stealthed heroes.
- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.
```

**Add** a row to the mana table in section 4:

```markdown
| Tamsin | 50 | +8 (fast attacks) | none | 2/s | 0 |
```

**Add** to section 9 ("How the heroes fit together"):

> - **Tamsin cashes in what others set up:** Marks (Headhunter), Roots and Stuns (Garrote), or her own kills (Nightblade). Hearthwall and Last Watch keep enemies busy while she's out of Stealth.

---

## 2. `docs/plans/apexes.md` (created by `changes-apexes.md`)

**Add** to "How apexes work", after the bullet "**The snowball is built in.**":

> - **The rarer the trigger, the bigger the payoff.** A fight has a handful of kills but hundreds of attacks, so a per-kill snowball is many times stronger than a per-attack one; per-application snowballs sit in between, by how often they trigger.

**Replace** the Inquisitor row's apex and upgrades cells:

> **Snowball:** each smite kill gives +3% MGK for the rest of the fight | **Zeal:** +5% MGK per kill.

with:

> **Snowball:** each smite kill gives +15% MGK for the rest of the fight | **Zeal:** +20% MGK per kill.

**Add** a new section after Ilse's section, before "## Notes":

```markdown
## Tamsin

| Apex | Taste (on vow) | Deed | The apex | Upgrades |
| --- | --- | --- | --- | --- |
| **Phantom** (Nightblade) | Kills hide her 0.5s longer | Attacks made from Stealth | Each kill hides her for 3s, and attacks from Stealth no longer break it. **Snowball:** each attack from Stealth gives her +2% ATK for the rest of the fight, with no cap | **Deeper Dark:** +3% per attack. **Smoke Trail:** when she leaves Stealth, enemies within 1 hex are Slowed 30% for 2s |
| **Veilmaster** (Nightblade) | When she becomes hidden, the nearest ally is hidden for 0.5s | Stealth given to allies | Whenever she becomes hidden, every ally within 2 hexes is hidden for 1.5s, and their first attack out of Stealth is a crit. **Snowball:** each ally attack from Stealth gives every hero +2% attack speed for the rest of the fight | **Shadow Pact:** +3% per attack. **Long Shadows:** allies stay hidden 1s longer |
| **Executioner** (Headhunter) | Sentence deals +10% damage to enemies below 50% HP | Kills by Sentence | Sentence executes Marked enemies below 25% HP. **Snowball:** each Sentence kill gives her +25% ATK for the rest of the fight, and Sentence costs 5 less mana (down to 20) | **Bloodied Axe:** +35% ATK per kill. **Hanging Judge:** an execution Marks every enemy within 2 hexes for 3s |
| **Bloodtrail** (Headhunter) | She steps to Marked enemies within 5 hexes, not 4 | Steps between Marked enemies | After a kill, she steps to any Marked enemy on the field, and her next attack deals +100% damage. **Snowball:** each kill she makes after a step Marks the nearest unmarked enemy (so the chain keeps going), and every kill in the fight makes all Marks deal +10% more damage to their targets, for everyone, for the rest of the fight | **Relentless:** +15% per kill. **Open Veins:** each step applies Bleed equal to 20% of her ATK to her new target |
| **Strangler** (Garrote) | Garrote lasts 0.5s longer | Damage dealt by Garrote | Garrote holds until the target dies or 5s pass. **Snowball:** each tick of Garrote hits 10% harder than the last, and a kill with it refunds 50% of its mana | **Tightening Cord:** +15% per tick. **Silent Grip:** a garroted enemy is Silenced |
| **Pinmaster** (Garrote) | Allies deal +5% damage to enemies she holds or keeps held | Damage allies deal to enemies she holds or keeps held | Every enemy she holds or keeps held takes +25% damage from everyone. **Snowball:** every 2s of hold she adds gives every hero +1% ATK and MGK for the rest of the fight | **Iron Grip:** +2% per 2s. **Pinning Knives:** her hits on a held enemy also Root an enemy within 1 hex for 0.5s |
```

**Add** to "Notes":

> - **Each of Tamsin's paths has a solo apex and a team apex:** Phantom / Veilmaster, Executioner / Bloodtrail, Strangler / Pinmaster.
> - **Phantom** can stay hidden nonstop on a team that keeps getting kills; Watchful enemies and later-act counters are the check.

---

## 3. `docs/plans/upgrade-pools.md` (created by `changes-upgrade-pools.md`)

**Add** a new section after Ilse's section, before "## Left out on purpose":

```markdown
## Tamsin

### Hero pool

These never give Stealth on a kill (Nightblade), Mark extension or stepping (Headhunter), or hold extension (Garrote).

| Upgrade | Effect |
| --- | --- |
| **Honed Knives** | ATK +10% of her current ATK (stacks) |
| **Quick Fingers** | Attack speed +10% of her current attack speed (stacks) |
| **Keen Edge** | CRIT +25% of her current CRIT (stacks) |
| **Leather Wraps** | Max HP +10% of her current max HP (stacks) |
| **Long Shadowstep** | Shadowstep hides her 1s longer |
| **Deep Ambush** | Ambusher hides her 1s longer at the fight's start |
| **Backstab** | +20% damage to enemies that aren't targeting her |
| **Evasive** | 15% of attacks on her miss |
| **Poisoned Blades** | Her basic attack applies Poison equal to 10% of her ATK |
| **Finisher** | +25% damage to enemies below 30% HP |
| **Throat Cut** | Her crits Silence the target for 0.5s (once per enemy every 6s) |
| **Notches** | Grows: +1% crit damage per 5 kills, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Nightblade** | **Lingering Fade:** Fade hides her for 1.5s, not 1s. **Quiet Kill:** kills give her 10 mana | **Assassin's Haste:** +20% attack speed for 3s after leaving Stealth. **Unseen Edge:** attacks from Stealth get +25% crit damage. **Long Dance:** Shadow Dance lasts 1s longer. **Mist Step:** becoming hidden removes Slow and Root from her. Growing: **Night Tally** (+1% ATK per 10 attacks from Stealth) |
| **Headhunter** | **Lasting Scent:** her hits extend a Mark by 0.75s, not 0.5s. **Stalker:** +10% attack speed against Marked enemies | **Quick Sentence:** Sentence costs 10 less mana. **Swift Step:** +30% attack speed for 2s after a step. **Deep Wounds:** her hits on Marked enemies apply Bleed equal to 10% of her ATK. **Marked for Death:** Marked enemies she attacks also take +10% damage from allies. Growing: **Trophy Belt** (+1% damage to Marked enemies per 3 Marked kills) |
| **Garrote** | **Tight Choke:** Choke extends holds by 0.5s, not 0.3s. **Grip Strength:** +10% crit damage against held enemies | **Long Garrote:** Garrote lasts 1s longer. **Drag:** Garrote pulls its target 1 hex toward your nearest ally. **Wire Snare:** when Garrote ends, enemies within 1 hex are Rooted for 0.5s. **Shadow Hold:** she takes 30% less damage while garroting. Growing: **Patient Knife** (+1% crit damage against held enemies per 3s of hold she adds) |
```

**Add** to "Keyword sources this adds":

> - **Poison:** Poisoned Blades (Tamsin) is the first hero source; Lanternbearer's cleanse already removes it from allies.
> - **Rooted:** Garrote, Wire Snare, and Pinning Knives (Tamsin) add Root makers beside Trapper.
> - **Stealthed:** Nightblade and Veilmaster (Tamsin) make Stealth a team build.

---

## 4. `docs/plans/build-map.md` (created by `changes-build-map.md`)

In section 3's table:

- **Replace** the Root row's "Payoffs now" cell with: `Huntmaster (Trapper's apex); Garrote and Pinmaster (Tamsin)`, and its "What's missing" cell with: `Covered for now. A second Root maker on another hero would help (Garrote makes some)`.
- **Replace** the Mark row's "Payoffs now" cell with: `Headhunter, Executioner, Bloodtrail (Tamsin); Inquisitor (Vigil Keeper's apex); Brand the Marked (an Ironbrand upgrade)`, and its "What's missing" cell with: `Covered for now. More Mark makers (the scavenger's Bounty Hunter)`.
- **Replace** the Stealth row's "Makers now" cell with: `Maren's hop (Slip Away); Tamsin (Ambusher, Shadowstep, Nightblade, Veilmaster)`, its "Payoffs now" cell with: `Nightblade and Phantom (Tamsin); charms and relics`, and its "What's missing" cell with: `Covered for now`.

In section 4's table, **replace** the assassin row's "Notes" cell with:

> **Designed: Tamsin Gloamstep** (`rebuild-heroes.md`, section 8c)

**Replace** in Open questions:

> - **Which hero comes after Ilse:** the assassin fills the most gaps.

with:

> - **Which hero comes after Tamsin:** the shield-bruiser fills the most remaining gaps.

---

## 5. `CLAUDE.md`

**Replace** in "The design the rebuild builds toward", the heroes bullet (after `changes-ilse.md`):

> a team of 3, chosen from Brannoc, Maren, Vell, and Ilse (the Burn caster)

with:

> a team of 3, chosen from Brannoc, Maren, Vell, Ilse (the Burn caster), and Tamsin (the assassin)
