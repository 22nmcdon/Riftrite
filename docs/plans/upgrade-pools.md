# Upgrade pools

Status: **agreed in discussion (2026-09-30); built as phase 5c step 7 (2026-10-01)** (`rebuild-phase5c-combos.md`, section 15, Decisions 34–39: taste cards carry on after the transformation, five cards replaced (Thread the Hurt, Drawing Wall, Crushing Blow, Lasting Circle, Wide Guard), cards that change nothing never offered, the pick keeps its shape). What the after-fight pick (part 6, `rebuild-between-fights.md`, section 1) offers, for each hero. Replaces part 1's three layers (`rebuild-heroes.md`, "Upgrade pools"). The growing upgrades are from part 7b (`rebuild-content-pool.md`, section 7). **Numbers and names are placeholders.**

## How the pools work

| Pool | Offered | Size |
| --- | --- | --- |
| **Hero** | Always | 12 per hero |
| **Taste** | Once the hero is vowed, until they transform | 2 per path |
| **Path** | Once the hero has transformed | 4 per path, plus the path's growing upgrade |

- **Apex upgrades:** once a hero earns an apex, its 2 upgrades join their path pool (`apexes.md`).
- **Hero and role are one pool for now.** A role layer would mostly hold the same things as the hero layer. Split a role pool out when a third hero shares a role (the next bullet).
- **Hero upgrades are written against slots** ("her Marks", "his taunts", "her heals"), so they survive a transformation that replaces a signature.
- **Upgrades to a base signature keep working after a transformation,** on that signature's habit (`rebuild-heroes.md`, section 3). Cards like Swift Haul or Wide Flare never go dead. A "costs less mana" upgrade makes the habit fire **one attack sooner** instead (every 7th, not 8th).
- **Hero upgrades never give a path's key mechanic** (range, roots, extra targets, Guard, cleave, surviving a fall, Shields, Kindle's extra heal, smites), so no deed fills without its vow.
- **The relic rules apply:** no downsides, ATK and MGK rather than "damage", and every amount stated.
- **A shared role pool waits for a third hero in a role.** Brannoc and Garrow are both tanks, but two heroes don't need a shared pool yet.

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
| **Deep Hearth** | Hearthguard's Shield is 35% larger (was 50%; tuning T-4) |
| **Hard to Pass** | Enemies he engages take 1s longer to break free |
| **Staggering Bash** | Every 4th basic attack Slows the target 20% for 2s |
| **Grudge** | He gains 30% more mana from damage taken (was 50%; tuning T-4) |
| **Opening Stand** | +30% DEF for the first 5s of each fight |
| **Weathered** | Grows: +1% max HP per 800 damage he takes, for the rest of the run (tuning T-4) |

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
| **Deep Well** | Her basic attack gives a third more mana (was a quarter; tuning T-4) |
| **Urgent Mercy** | Her heals on allies below 30% HP heal 25% more |
| **Cleansing Touch** | Her heals remove one status from their target |
| **Ember Glow** | Her basic attack applies 1 Burn |
| **Sanctuary** | Allies within 1 hex of her take 10% less damage (was 5%; tuning T-4) |
| **Vigilant** | When an ally first drops below 50% HP, she gains 30 mana (once per ally per fight; was 20, tuning T-4) |
| **Lamp Oil** | Grows: +1% MGK per 500 healing she gives, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Lanternbearer** | **Bright Kindle:** Kindle heals for 30% of Mend, not 20%. **Steady Flame:** Mend costs 5 less mana | **First Lantern:** you place her first lantern yourself before the fight. **Wide Cleanse:** her lantern also cleanses Slow and Bleed. **Last-Minute Mercy:** Mend refunds 20 mana if its target was below 30% HP. **Long Night:** her lantern lasts 2s longer. Growing: **Kindled Flame** (+1% healing per 300 healing next to Mend's target) |
| **Wardweaver** | **Thick Thread:** Ward Thread's Shield is 40% of the overheal, not 20%. **Thread the Hurt:** Ward Thread also works on allies above 80% HP | **Front Ward:** her Shields on your front-most ally are 50% larger. **Cleansing Weave:** Weave removes one status. **Thick Weave:** Weave's Shields are 20% larger. **Wide Circle:** Warding Circle is 1 hex wider. Growing: **Woven Deep** (+1% Shield size per 300 Shield given) |
| **Vigil Keeper** | **Swift Judgment:** every Mend smites, not every 2nd. **Burning Judgment:** smites deal 50% more damage | **Leaping Smite:** smites jump to a second enemy at 50%. **Wide Sunfall:** Sunfall's beam is 1 hex wider. **Holy Crits:** her crits heal the lowest-HP ally for 5% of their max HP. **Searing:** smitten enemies are Slowed 20% for 2s. Growing: **Sunwrought** (+1% smite damage per 200 smite damage) |

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

## Tamsin

Built in phase 8 part 4 (`rebuild-phase8-heroes.md`, "Built in 8d-3b and 8d-3d"): her 33 cards, with the approximations flagged there (Night Tally, Trophy Belt, Marked for Death, Swift Step); her 12 apex cards in 8d-3c.

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

## Garrow

Built in phase 8 part 4 (`rebuild-phase8-heroes.md`, "Built in 8d-2b and 8d-2d"): his 33 cards; his 12 apex cards in 8d-2c.

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
| **Spitemail** | **Bitter Blood:** damage Spikes sends back ignores DEF. **Prickly:** +10% DEF | **Long Maiden:** Iron Maiden lasts 1s longer. **Wide Maiden:** Iron Maiden taunts within 3 hexes. **Spiteful Heal:** he heals for 75% of what he sends back, not half. **Spite Burst** (built under this name, since Thornweave's apex has a Thorn Burst; phase 8 part 4): when Iron Maiden ends, enemies within 1 hex are Stunned for 0.5s. Growing: **Old Grudge** (+1% damage sent back per 2,000 sent back) |

## Aldous

Built in phase 8 part 4 (`rebuild-phase8-heroes.md`, "Built in 8d-4b and 8d-4d"): his 33 cards, with the approximations flagged there (Clear Note, Eye of the Storm, Old Rope, Long Choir, Bell Metal); his 12 apex cards in 8d-4c.

### Hero pool

These never give mana to allies (Chorister), bonuses for ranged allies (Windcaller), or Marks (Bellwarden).

| Upgrade | Effect |
| --- | --- |
| **Bright Voice** | MGK +10% of his current MGK (stacks) |
| **Quick Rhythm** | Attack speed +10% of his current attack speed (stacks) |
| **Traveler's Coat** | Max HP +10% of his current max HP (stacks) |
| **Padded Vestments** | DEF +10% of his current DEF (stacks) |
| **Long Peal** | Peal lasts 2s longer |
| **Wide Peal** | Peal reaches allies within 4 hexes |
| **Strong Resonance** | Resonance gives +10% attack speed, not 5% (was +8%; tuning T-4) |
| **Far Resonance** | Resonance reaches allies within 3 hexes |
| **Cracked Bell** | Toll Slows its target 15% for 1s |
| **Clear Note** | Toll deals +20% damage to enemies targeting an ally |
| **Steadying Hymn** | Peal also removes Slow from allies |
| **Old Rope** | Grows: +1% to Peal's attack speed bonus per 10 Peals, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Chorister** | **Deep Breath:** Shared Breath gives 25 mana, not 15. **Two Breaths:** Shared Breath reaches the 2 allies with the least mana | **Quick Crescendo:** Crescendo costs 10 less mana. **Wide Chorus:** his half-share of mana reaches allies within 4 hexes. **Kindled Chorus:** allies who gain mana from him get +5% ATK and MGK for 3s. **Full Voice:** Crescendo gives 50 mana, not 40. Growing: **Long Choir** (+1% to his half-share per 300 mana given) |
| **Windcaller** | **Steady Tailwind:** Tailwind gives +8% attack speed, not 5%. **Gusting:** under Tailwind, allies' shots fly 25% faster | **Strong Gale:** Gale knocks back 1 hex further. **Quick Gale:** Gale costs 10 less mana. **Eye of the Storm:** ranged allies take 10% less damage while no enemy is within 2 hexes of them. **Keen Wind:** ranged allies get +5 CRIT. Growing: **Prevailing Wind** (+1% damage for ranged allies per 500 attacks made under Tailwind) |
| **Bellwarden** | **Sharp Toll:** every 3rd Toll Marks, not every 4th. **Long Toll:** Toll the Hour's Marks last 3s | **Wide Knell:** Death Knell reaches 4 hexes. **Ringing Mark:** his Marks also Slow 10%. **Quick Knell:** Death Knell costs 10 less mana. **Heavy Toll:** Toll deals +30% damage to Marked enemies. Growing: **Bell Metal** (+1% to his Marks' damage bonus per 50 Marks he applies) |

## Hob

### Hero pool

These never give shard-based power (Hoarder), shop discounts or spending bonuses (Fence), or Bounties (Bounty Hunter).

| Upgrade | Effect |
| --- | --- |
| **Lean Muscle** | ATK +10% of his current ATK (stacks) |
| **Quick Sling** | Attack speed +10% of his current attack speed (stacks) |
| **Patched Coat** | Max HP +10% of his current max HP (stacks) |
| **Lucky Charm** | CRIT +25% of his current CRIT (stacks) |
| **Wider Pickings** | Pickings counts enemies dying within 3 hexes |
| **Long Grab** | Grab reaches 4 hexes |
| **Hard Grab** | Grab hits for 200% of his ATK |
| **Slippery Exit** | +1 speed for 3s after Grab |
| **Scavenger's Nose** | Grab goes for enemies below 30% HP within 5 hexes first |
| **Lucky Find** | Once per act, a won fight pays 5 extra shards |
| **Pocket Sand** | His crits Slow by 20% for 1s |
| **Well-Worn Sling** | Grows: +1% ATK per 20 shards from Pickings, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Hoarder** | **Deep Pockets:** Nest Egg's taste cap rises to +15%. **Penny Wise:** Nest Egg counts every 8 shards, not 10 | **Stunning Purse:** Heavy Purse Stuns for 0.5s. **Guarded Gold:** +10 DEF while holding 30+ shards. **Miser's Grip:** Heavy Purse costs 10 less mana. **Shared Wealth:** allies get 3/4 of Nest Egg's bonus, not half. Growing: **Old Coins** (+1% to Nest Egg's bonus per 5 fights won while holding 30+ shards) |
| **Fence** | **Second Haggle:** the second reroll in each shop costs 1 shard. **Quick Count:** Cut Purse costs 10 less mana | **Wholesale:** loadout items cost 1 shard less. **Fair Trade:** Cut Purse makes elites and bosses drop 2 shards. **Insider:** each shop shows one charm already at rank II. **Big Spender:** the per-shard team bonus is +0.15%. Growing: **Old Contacts** (+1 shard after each won fight per 5 shops visited, up to +5) |
| **Bounty Hunter** | **Wanted Poster:** the taste's Bounty Mark lasts 12s, not 8s. **Clear Sight:** +15% damage to the Bounty | **Long Arm:** Collect reaches 6 hexes. **Hunter's Rest:** collecting a Bounty heals him 15% of his max HP. **Tracker:** the team deals +10% damage to the Bounty. **Fast Collect:** Collect costs 10 less mana. Growing: **Seasoned Hunter** (+1% attack speed per 3 Bounties collected) |

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

## Edric

### Hero pool

These never give timed Shields like Hallow (Aegis), shards (Tithe-Collector), or mana from Shields (Psalmist).

| Upgrade | Effect |
| --- | --- |
| **Steady Faith** | MGK +10% of his current MGK (stacks) |
| **Iron Vestments** | DEF +10% of his current DEF (stacks) |
| **Pilgrim's Frame** | Max HP +10% of his current max HP (stacks) |
| **Quick Seal** | Attack speed +10% of his current attack speed (stacks) |
| **Strong Ward** | Ward's Shields are 10% of max HP, not 8% |
| **Swift Ward** | Ward costs 10 less mana |
| **Wide Vigil** | Vigil reaches allies within 3 hexes |
| **Deep Vigil** | Vigil cuts damage by 8%, not 5% |
| **Heavy Seal** | Seal Slows its target 15% for 1s |
| **Warding Seal** | Seal deals +20% damage to enemies attacking a Shielded ally |
| **First Ward** | At the fight's start, every ally gains a Shield of 5% of their max HP |
| **Old Prayers** | Grows: +1% to Ward's Shield size per 10 Wards cast, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Aegis** | **Quick Hallow:** Hallow every 5s, not 6s. **Strong Hallow:** Hallow's Shield is 5%, not 4% | **Faster Hallow:** Hallow every 2.5s. **Sanctified:** Sanctuary also gives +10 DEF for 4s. **Steady Hallow:** Hallow goes to allies without a Shield first. **Quick Sanctuary:** Sanctuary costs 15 less mana. Growing: **Sainthood** (+1% to Hallow's size per 50 Hallows) |
| **Tithe-Collector** | **Elite Tithe:** Tithe pays double after elites. **Bold Tithe:** Tithe pays 1 more after the harder of the day's fights | **Long Collection:** Collection lasts 8s. **Full Plate:** Collection pays up to 5 shards per cast. **Quick Collection:** Collection costs 10 less mana. **Thick Collection:** Collection's Shields are 12%. Growing: **Ledger of Debts** (+1 shard per won fight for every 10 fights won, up to +5) |
| **Psalmist** | **Shared Offering:** Offering also gives 3 mana to the nearest other ally. **Quick Breath:** +5% mana gain while Shielded | **Full Vesper:** Vesper Ward gives 35 mana. **Quick Vesper:** Vesper Ward costs 10 less mana. **Steady Song:** mana gain while Shielded is 15%, not 10%. **Bright Offering:** Offering also gives +10% attack speed for 2s. Growing: **Long Hymnal** (+1% mana gain while Shielded per 500 mana given by Offering) |

## Ottilie

### Hero pool

These never give damage from Burn and Poison counts (Catalyst), shards (Transmuter), or mana to allies (Apothecary). Vial upgrades ride on her next Toss, like Brewing.

| Upgrade | Effect |
| --- | --- |
| **Steady Hand** | MGK +10% of her current MGK (stacks) |
| **Quick Pour** | Attack speed +10% of her current attack speed (stacks) |
| **Leather Apron** | Max HP +10% of her current max HP (stacks) |
| **Thick Gloves** | DEF +10% of her current DEF (stacks) |
| **Quick Brew** | Brewing every 3s, not 4s |
| **Strong Brew** | Brewing's vials apply 30% of her MGK, not 20% |
| **Wide Flask** | Volatile Flask's circle is 1 hex larger |
| **Quick Flask** | Volatile Flask costs 10 less mana |
| **Long Toss** | Toss reaches 4 hexes |
| **Sticky Vials** | Brewing's vials Slow 15% for 1s |
| **Acrid Fumes** | Enemies within 1 hex of her deal 10% less damage |
| **Notebook** | Grows: +1% MGK per 50 vials brewed, for the rest of the run |

### Path pools

| Path | Taste upgrades | Path upgrades |
| --- | --- | --- |
| **Catalyst** | **Sharp Reaction:** Reaction counts every 4, up to +12%. **Mixed Flask:** Volatile Flask's Burn and Poison are 25% of her MGK | **Strong Reaction:** +35% against enemies with both, not +25%. **Heavy Flask:** Reaction Flask adds 4 per Burn and Poison, not 3. **Quick Reaction:** Reaction Flask costs 10 less mana. **Corrosive:** enemies with both have 15% less DEF. Growing: **Lab Notes** (+1% to Reaction's bonus per 1,000 Reaction damage) |
| **Transmuter** | **Assayer:** Gilded Death pays 1 more after elites. **Coin Flask:** Volatile Flask kills pay 1 shard | **Strong Philosopher:** Philosopher's Flask hits for 150% of her MGK. **Quick Philosopher:** it costs 10 less mana. **Appraise:** transmuting a rank II or III item pays 2 or 4 more shards. **Deep Purse:** Gilded Death's cap is 10. Growing: **Ledger** (+1 shard per won fight per 30 shards from Gilded Death, up to +5) |
| **Apothecary** | **Rich Tonic:** the vial gives 12 mana, not 10. **Quick Tonic:** every 6s, not 8s | **Fast Tonic:** every 3s, not 4s. **Fizzing Vial:** the vial's attack speed bonus is +15%. **Bracing Vial:** the vial also gives +10 DEF for 3s. **Long Elixir:** Elixir's bonus lasts 6s. Growing: **Recipe Book** (+1 mana per vial per 100 vials thrown, up to +10) |

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
- **Burning:** Ilse is the first hero built on Burn: every path applies it, and Heat turns all Burn near her into mana.
- **Poison:** Poisoned Blades (Tamsin) is the first hero source; Lanternbearer's cleanse already removes it from allies.
- **Rooted:** Garrote, Wire Snare, and Pinning Knives (Tamsin) add Root makers beside Trapper.
- **Stealthed:** Nightblade and Veilmaster (Tamsin) make Stealth a team build.
- **Bleeding:** Chainwarden (Garrow) applies Bleed with every chain.
- **Marked:** Bellwarden (Aldous) is the first path built to make Marks for others.
- **Poison:** Plaguebearer (Severine) is the first Poison build; Tamsin's Poisoned Blades is a second maker.
- **Burning and Poisoned:** Brewing (Ottilie's base kit) applies both on every path.
- **Stealthed:** Veilweaver (Lucan) hides allies on a timer, beside Tamsin and Maren's hop.
- **Burning and Poisoned:** Cinderhound and Serpent-Keeper (Kestra) are the second makers for each, beside Ilse and Severine.
- **Marked:** Wild Hunt (Kestra) lets summons Mark what they hit.

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

Answered for now (2026-10-01, `rebuild-phase5c-combos.md` Decision 38): the pick keeps its shape (one card per hero and the wild card), every card a hero can be offered equally likely, stacking cards without a cap; the run report counts each layer's picks, and phase 5c step 9 retunes.


- **How cards are weighted:** how often a hero-pool card shows against a taste or path card, and whether stacking upgrades show up less often.
- **Picks per hero:** a day gives one pick for the whole team, so a hero may go several days without one. Is that fine, or should each pick offer one card per hero?
- **Stacking with no cap:** is the lock-in rule enough, or do stacking upgrades need a limit per run?
