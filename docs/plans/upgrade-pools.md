# Upgrade pools

Status: **agreed in discussion (2026-09-30), not built.** What the after-fight pick (part 6, `rebuild-between-fights.md`, section 1) offers, for each hero. Replaces part 1's three layers (`rebuild-heroes.md`, "Upgrade pools"). The growing upgrades are from part 7b (`rebuild-content-pool.md`, section 7). **Numbers and names are placeholders.**

## How the pools work

| Pool | Offered | Size |
| --- | --- | --- |
| **Hero** | Always | 12 per hero |
| **Taste** | Once the hero is vowed, until they transform | 2 per path |
| **Path** | Once the hero has transformed | 4 per path, plus the path's growing upgrade |

- **Apex upgrades:** once a hero earns an apex, its 2 upgrades join their path pool (`apexes.md`).
- **Hero and role are one pool for now.** Each of the three heroes has a different role, so a role layer would hold the same things as the hero layer. Split a role pool out when a second hero shares a role.
- **Hero upgrades are written against slots** ("her Marks", "his taunts", "her heals"), so they survive a transformation that replaces a signature.
- **Hero upgrades never give a path's key mechanic** (range, roots, extra targets, Guard, cleave, surviving a fall, Shields, Kindle's extra heal, smites), so no deed fills without its vow.
- **The relic rules apply:** no downsides, ATK and MGK rather than "damage", and every amount stated.

### Stacking upgrades

- Only the plain stat upgrades (marked **stacks**) can be picked more than once. Everything else can be taken once
- **A stacking upgrade is a percentage of the hero's stat when you pick it, locked in as a flat amount.** It never recalculates. At 15 attack speed, +10% gives +1.5; at 150, it gives +15. Picked early it's small, picked late it's big, and picks don't compound on each other.

## Maren

### Hero pool

| Upgrade | Effect |
| --- | --- |
| **Honed Tips** | ATK +10% of her current ATK (stacks) |
| **Keen Eye** | CRIT +25% of her current CRIT (stacks) |
| **Quick Draw** | Attack speed +10% of her current attack speed (stacks) |
| **Fletcher's Leathers** | Max HP +10% of her current max HP (stacks) |
| **Deep Mark** | Her Marks last 2s longer |
| **Heavy Mark** | Enemies she Marks take +5% more damage (20% instead of 15%) |
| **Light Step** | Her hop's cooldown is 2s shorter |
| **Long Vanish** | Her hop hides her 1s longer |
| **Parting Shot** | Her first attack after a hop is a crit |
| **First Blood** | Her first attack each fight deals +100% damage |
| **Close Quarters** | +20% damage to enemies within 1 hex of her |
| **Notched Bow** | Grows: +1% ATK per 10 enemies she Marks, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Deadeye** | **Steady Hands:** Steady kicks in after 1s, not 1.5s. **Eyes Up:** +5 CRIT while Steady | **Quick Plant:** she plants in 0.75s. **Seeker's Mark:** Heartseeker Marks everything it hits for 4s. **Heart's Refund:** Heartseeker kills refund 50% of its mana. **Bleeding Shot:** crits from 6 hexes apply 3 Bleed. Growing: **Hunter's Tally** (+1% damage per 500 damage dealt from 5+ hexes) |
| **Trapper** | **Second Snare:** her Snare triggers twice per fight. **Tight Weave:** snares root 0.5s longer | **Tangle:** enemies next to a rooted one are Slowed 30% for 2s. **Hunter's Opening:** rooted enemies take +20% damage from her. **Guarded Ground:** at the fight's start, a snare appears under your front-most ally. **Snag:** snares root enemies that leap or charge over them. Growing: **Patient Hunter** (+1% damage to Rooted enemies per 5 seconds of root) |
| **Volley** | **Quick Split:** Split Shot every 3rd shot, not every 4th. **Restless:** +10% attack speed if she moved in the last 2s | **Chasing Storm:** Arrow Storm follows the largest group. **Ricochet:** a split arrow can split once more. **Harrying Storm:** Arrow Storm Slows 20%. **Glutton's Quiver:** kills with split arrows give 10 mana. Growing: **Arrow Glut** (+1% attack speed per 25 extra targets hit) |

## Brannoc

### Hero pool

| Upgrade | Effect |
| --- | --- |
| **Hearthblood** | Max HP +10% of his current max HP (stacks) |
| **Iron Hide** | DEF +10% of his current DEF (stacks) |
| **Heavy Arm** | ATK +10% of his current ATK (stacks) |
| **Long Hold** | His taunts last 1s longer |
| **Stubborn Taunt** | Enemies he taunts deal 10% less damage |
| **Twice Guarded** | Hearthguard can trigger twice per fight |
| **Deep Hearth** | Hearthguard's Shield is 50% larger |
| **Hard to Pass** | Enemies he engages take 1s longer to break free |
| **Staggering Bash** | Every 4th basic attack Slows the target 20% for 2s |
| **Grudge** | He gains 50% more mana from damage taken |
| **Opening Stand** | +30% DEF for the first 5s of each fight |
| **Weathered** | Grows: +1% max HP per 1,000 damage he takes, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Hearthwall** | **Broad Guard:** Guard's share is 15%, not 10%. **Two Behind:** Guard covers the 2 allies behind him | **Reflecting Wall:** his wall sends arrows back at 50% damage. **Shared Strength:** guarded allies heal 2% of their max HP when he takes a hit for them. **Drawing Hold:** his taunts pull enemies 1 hex toward him. **Lasting Wall:** his wall lasts 2s longer. Growing: **Old Scars** (+1 DEF per 200 damage taken for allies) |
| **Ironbrand** | **Heavy Brand:** Brand's second hit is 50% damage, not 30%. **Crowd Sense:** +10% ATK while 2 or more enemies are adjacent | **Hungry Mace:** his mace heals 1% more per enemy hit. **Crushing Blow:** enemies knocked into other enemies are Stunned for 1s. **Brand the Marked:** Brand Slam leaps toward Marked enemies first. **Cleaving Wounds:** his mace applies 2 Bleed. Growing: **Brandmarks** (+1 ATK per 30 extra enemies cleaved) |
| **Last Watch** | **Grim Resolve:** Unyielding also gives him a Shield of 10% of his max HP. **Hard to Kill:** +20% DEF while below 30% HP | **Final Gift:** when he falls, allies get a Shield of 15% of their max HP. **Scar Tissue:** each second below 30% HP gives +2 DEF for the rest of the fight. **Rites of Mercy:** Last Rites heals allies within 3 hexes for 10% of their max HP. **Bloody Kills:** kills while he's below 30% HP restore 5% of his max HP. Growing: **Borrowed Time** (+1% damage below 30% HP per 3 seconds spent below 30% HP) |

## Vell

### Hero pool

| Upgrade | Effect |
| --- | --- |
| **Bright Soul** | MGK +10% of her current MGK (stacks) |
| **Pilgrim's Cloak** | Max HP +10% of her current max HP (stacks) |
| **Quick Glow** | Attack speed +10% of her current attack speed (stacks) |
| **Wide Hearth** | Hearthlight reaches allies within 2 hexes, not 1 |
| **Warm Hearth** | Hearthlight regenerates 2% HP per second, not 1% |
| **Deep Well** | Her basic attack gives 25% more mana |
| **Urgent Mercy** | Her heals on allies below 30% HP heal 25% more |
| **Cleansing Touch** | Her heals remove one status from their target |
| **Ember Glow** | Her basic attack applies 1 Burn |
| **Sanctuary** | Allies within 1 hex of her take 5% less damage |
| **Vigilant** | When an ally first drops below 50% HP, she gains 20 mana (once per ally per fight) |
| **Lamp Oil** | Grows: +1% MGK per 500 healing she gives, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Lanternbearer** | **Bright Kindle:** Kindle heals for 30% of Mend, not 20%. **Steady Flame:** Mend costs 5 less mana | **First Lantern:** you place her first lantern yourself before the fight. **Wide Cleanse:** her lantern also cleanses Slow and Bleed. **Last-Minute Mercy:** Mend refunds 20 mana if its target was below 30% HP. **Long Night:** her lantern lasts 2s longer. Growing: **Kindled Flame** (+1% healing per 300 healing next to Mend's target) |
| **Wardweaver** | **Thick Thread:** Ward Thread's Shield is 40% of the overheal, not 20%. **Thread the Hurt:** Ward Thread also works on allies above 80% HP | **Front Ward:** her Shields on your front-most ally are 50% larger. **Cleansing Weave:** Weave removes one status. **Lasting Shields:** her Shields last until broken. **Wide Circle:** Warding Circle is 1 hex wider. Growing: **Woven Deep** (+1% Shield size per 300 Shield given) |
| **Vigil Keeper** | **Swift Judgment:** every Mend smites, not every 2nd. **Burning Judgment:** smites deal 50% more damage | **Leaping Smite:** smites jump to a second enemy at 50%. **Wide Sunfall:** Sunfall's beam is 1 hex wider. **Holy Crits:** her crits heal the lowest-HP ally for 5% of their max HP. **Searing:** smitten enemies are Slowed 20% for 2s. Growing: **Sunwrought** (+1% smite damage per 200 smite damage) |

## Left out on purpose

- **Heartseeker pierces one more enemy:** Stormline's apex taste.
- **Starting a fight with half mana:** the Opener sigil.
- **Shields burst when broken:** Thornweave's apex taste.
- **Overhealing becomes Shield (Lanternbearer):** it would give Lanternbearer the Wardweaver's key mechanic.
- **+ATK per adjacent enemy (Ironbrand):** covered by Crowd Sense.

## Keyword sources this adds

- **Burning:** Ember Glow (Vell) is the first hero source of Burn.
- **Bleeding:** Bleeding Shot (Deadeye) and Cleaving Wounds (Ironbrand), alongside the Bloodletter charm.
- **Marked:** Seeker's Mark (Deadeye) and Brand the Marked (Ironbrand) build on Marks.

## Where this meets what's built

Added when this file came in (2026-09-30); nothing here changes a decision above.

- **The built upgrades:** phase 5 built 36 (`data/upgrades.json`: 3 per hero, and 3 per path, one of them the vow pick). The pools here replace them when they're built; a few names carry over with new rules (Quick Draw, Keen Eye, Warm Hearth, Steady Hands, Long Night, Grim Resolve).
- **Six "not X" numbers were the part 1 design's, not what phase 4 tuned** (`data/paths.json`). **Decided (2026-09-30), each set against the built kit** (the tables above now say these):

  | Upgrade | First written | Built | Now |
  | --- | --- | --- | --- |
  | Steady Hands (Deadeye) | Steady after 1s, not 2s | Steady after 1.5s | after 1s, not 1.5s |
  | Quick Split (Volley) | every 3rd attack, not every 4th | every 6th shot | every 3rd, not every 4th: **Volley's taste goes back to every 4th** (below) |
  | Bright Kindle (Lanternbearer) | 20%, not 10% | already a fifth (20%) | 30% of Mend, not 20% |
  | Thick Thread (Wardweaver) | 20% of the heal, not 10% | already a fifth of the overheal (20%) | 40% of the overheal, not 20% |
  | Swift Judgment (Vigil Keeper) | every 3rd Mend, not every 4th | every 2nd Mend | every Mend, not every 2nd |
  | Burning Judgment (Vigil Keeper) | 20% of the heal, not 10% | the smite is its own hit (8 plus 40% of MGK), not a share of the heal | smites deal 50% more damage |

  **Volley's taste changes** (the playtester, 2026-09-30): Split Shot goes back to the design's every 4th shot (`rebuild-heroes.md`), from the every 6th phase 4 tuned it to, and Quick Split makes it every 3rd. Phase 4 set every 6th because the vow already won 6 points more than base, a point past its Decision 3 cap of 5 (`rebuild-phase4-paths.md`, Open questions); every 4th makes the vow stronger again, so the paths report checks it when this is built.

  The rest match what's built: Guard's 10% (Hearthwall), Brand's 30% (Ironbrand), Marked's 15%, Hearthguard once a fight, and Hearthlight's 1 hex and 1% a second.
- **Stacking upgrades** are new: the pick locks in a flat amount from the hero's stat at the time, so run state keeps each hero's taken amounts (the kit mod is a flat stat add, not a multiplier).

## Open questions

- **How cards are weighted:** how often a hero-pool card shows against a taste or path card, and whether stacking upgrades show up less often.
- **Picks per hero:** a day gives one pick for the whole team, so a hero may go several days without one. Is that fine, or should each pick offer one card per hero?
- **Stacking with no cap:** is the lock-in rule enough, or do stacking upgrades need a limit per run?
