# Rebuild plan, part 1: heroes

Status: **agreed in discussion (2026-09-27), not built.** This is the first part of a from-scratch rethink of the game. Later parts (the arena, enemies, the run, and what replaces items and shops) build on it. Numbers are placeholders to tune.

**Why:** playtests say the game is far too easy, essences aren't fun, two rows of units make tanks pointless, and items all feel the same. The rethink puts **heroes** at the center: each hero changes over a run in ways you choose and then earn by playing them well.

## Decisions

- **A team is 3 heroes, kept for the whole run.** All three fight.
- **Start with 3 heroes only: Brannoc, Maren, and Vell.** Get them right before adding more. With a roster of 3 there's no team draft yet; it comes back with hero 4.
- **Every hero has a main role** (tank, damage, support, control), and their path can bend it. **There are no shared role traits:** each hero's own passives and traits do that job (Brannoc's Engage is his, not every tank's).
- **Vows happen when the team is chosen:** after picking your three heroes, you vow each one to a path before the first fight. You can switch a vow between fights until that hero transforms.
- **Transformations are permanent.** Only the apex vow can still be switched, until the apex is earned.
- **Heroes only grow through deeds.** No ranks, no buying heroes, no combining duplicates. Upgrade picks come from deeds.
- **Essences are removed.**
- **Fights happen in an arena**, not two rows: heroes are placed on a hex grid, then fight on a free-moving plane. The arena gets its own part of the plan; the heroes below are designed for it.
- **Mana is the most common way a signature fires, but not the only one** (see section 4). Some signatures fire on other triggers, and some heroes or paths have no mana at all. Only signatures ever use mana.
- **What happens to items and shops is still open.** It comes in a later part.

## 1. What a hero is

| Part | What it is | Changes over a run? |
| --- | --- | --- |
| **Stats** | HP, ATK, MGK, DEF, CRIT, ATSP, plus speed (hexes per second) and range | Yes, when the hero transforms |
| **Basic attack** | Their steady attack; it builds mana | Some paths change it |
| **Signature** | Their big move. It fires on its trigger: usually a full mana bar, sometimes something else (section 4) | Replaced when the hero transforms |
| **Passive** | Always on; usually about positioning | Rarely |

## 2. How a hero grows: vow, then earn

Each hero has **three paths**. A path is a transformation: it changes what the hero is, not just their numbers, much like a specialization in Guildrun.

### The stages

| Stage | When | What happens |
| --- | --- | --- |
| **Base** | Start of the run | The hero's own kit |
| **Vow** | When the team is chosen, before the first fight | You vow the hero to one path. They get the path's **taste** and its **cost** at once |
| **Transformation** | The vowed path's deed fills | The hero becomes the path: new signature, reshaped stats, the full mechanic, and the path's upgrade pool opens |
| **Path upgrades** | Each deed level after the transformation | Pick 1 of 3 upgrades from the path's pool |
| **Apex** | Late in the run | The path splits into 2 final forms. You vow to one, earn it the same way, and the hero transforms again |

### The rules

- **The vow is the player's decision.** It's made when the team is chosen, and you can switch it between fights until the hero transforms.
- **The transformation is permanent.** After it, only the apex vow can be switched, until the apex is earned.
- **The taste is small: about 5–10% of the path, and only one piece of it.** It previews one mechanic and doesn't make the hero feel transformed. The transformation must feel like a different, stronger hero.
- **The taste is the tool for the deed.** All three path deeds count whatever the hero actually does, all the time, with no bonus for being vowed. But each deed measures something the taste makes possible, so without the vow it barely moves. That's why the vowed path fills.
- **Only the vowed path can complete.** Switching vows keeps whatever the other paths have built, which is usually very little.
- **Every deed must be hard to fill without its taste.** A deed that counts something the hero does anyway ("deal damage") makes the vow meaningless.
- **Apexes work the same way**: vow, taste, earn, transform.

### Upgrade pools

Upgrade picks only mean something if the pool is big enough to vary between runs. A path offers 1 of 3 about 4–5 times a run, so each offer draws from three layers:

| Layer | What it holds | About how many |
| --- | --- | --- |
| **Path** | Changes that only fit that path | 6 per path |
| **Hero** | Tweaks to the hero's base kit, on any path | 4 per hero |
| **Role** | Shared upgrades for every hero with that main role | 8 per role |

That gives each path about 18 options. **Hero and role upgrades must never give another path's key mechanic** (range, roots, extra targets, and so on); otherwise a hero could fill a deed without the vow.

## 3. Design rules for every hero

1. **The taste previews one mechanic; the transformation brings a new signature, reshaped stats, that mechanic at full strength, and the upgrade pool.**
2. **Every deed is hard to fill without its taste.**
3. **Each path changes where you'd place the hero in the arena.** If you'd put them in the same spot on all three paths, the paths aren't different enough.
4. **Every path has a real cost**, so choices aren't pure upside.
5. **Every cost should have an answer somewhere in the team.**
6. **Paths can change how the hero earns mana, or what triggers their signature at all.** It's one of the strongest ways to make a path feel different.

## 4. Signature triggers and mana

**Every signature has a trigger.** Mana is the most common one, but a signature fits its hero, not a rule:

| Trigger | How it fires | Example |
| --- | --- | --- |
| **Mana** | when the mana bar is full | Maren's Marking Shot, Vell's Mend |
| **HP threshold** | when the hero drops below a set HP, once per fight | Last Watch Brannoc's Last Rites |
| **Count** | after a number of events (hits taken, allies healed, kills) | a possible later hero |
| **Once per fight** | at a set moment (fight start, the first ally falling) | a possible later hero |

- **A hero without a mana signature has no mana bar at all.** The UI only shows a mana bar for heroes who use it.
- **A path can change the trigger.** Last Watch Brannoc trades his mana signature for an HP-triggered one, so he has no mana once he transforms.
- **Only signatures ever use mana**, never other mechanics.

### How mana works (for heroes who use it)

- When the bar is full, the signature fires and the bar empties.
- **Small mechanics keep timers** (Maren's hop, Hearthguard, Deadeye's planting) or once-per-fight rules.
- **Sources:** basic attacks (the main one), damage taken (mainly tanks), a slow regen, and starting mana set per hero.
- **Slow attackers get more mana per hit**, so attack speed doesn't decide everything.
- **Integers only**, like the rest of the sim. The mana bar shows under the HP bar.
- **Enemies can interact with it:** mana drain and Silence (no mana gain for a few seconds) are fair, readable threats against caster-heavy teams. Heroes without mana are immune to both, which is part of their appeal.

| Hero | Signature cost | Per basic attack | Per hit taken | Regen | Starts with |
| --- | --- | --- | --- | --- | --- |
| Maren | 50 | +10 (fast attacks) | none | 2/s | 0 |
| Brannoc | 80 | +8 | +1 per 10 damage taken | none | 30 |
| Vell | 60 | +12 (slow attacks) | none | 2/s | 20 |

Example: if Vell attacks, she earns about 10 mana a second and Mends every 6s. If she can't attack, she only has regen and Mends every 30s. Her attack matters, and placing her where she can attack safely is part of the puzzle.

## 5. Shared statuses

- **Marked:** a single team-wide status. Maren's Marking Shot applies it; Vell's Inquisitor and Brannoc's Brand Slam build on it. Later heroes should build on it too, rather than inventing their own marks.
- **Engaged:** set by Brannoc's Engage trait (later tanks may have their own version). An engaged enemy can't walk past the tank without spending time breaking free.
- Others used below: Root, Slow, Bleed, Taunt, Shield, Silence. The full status list is part of the arena plan.

---

## 6. Maren Thistledown: the ranger (ranged damage)

**Role:** back-line damage. Strong at range and fragile up close, so she needs a tank to keep flankers off her.

| | |
| --- | --- |
| **Stats** | HP 270, ATK 22, DEF 8, CRIT 8, ATSP 10 |
| **Speed / range** | speed 2, fires at up to 4 hexes |
| **Basic attack: Longshot** | an arrow at the nearest enemy in range |
| **Signature: Marking Shot** (50 mana) | Marks an enemy: it takes +15% damage from everyone for 4s |
| **Passive: Keep Your Distance** | when an enemy moves next to her, she hops 1 hex away (once every 6s); *since playtest gate 1, each hop also hides her for 1s (Slip Away: Stealth, so no enemy can target her)* |

### Path 1: Deadeye (the sniper)

The fantasy: she plants her feet and makes one shot count.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Steady:** after 2s without moving, she gets +1 range | Planted, she gets +2 range (6 hexes) and +CRIT |
| **Signature** | Marking Shot | **Heartseeker:** a charged shot for heavy damage that pierces through the first enemy |
| **Stats** | unchanged | +ATK, +CRIT, –ATSP |
| **Mana** | unchanged | double mana from shots fired from 5+ hexes |
| **Cost** | –10% attack speed | after moving, she needs 1.5s to plant before firing again |

- **Deed:** damage dealt from 5 or more hexes away. Her base range is 4, so without Steady she can't do it at all.
- **Where she stands:** a corner with a long sightline.
- **Upgrade pool examples:** Heartseeker kills refund mana / she plants in 0.75s / crits from 6 hexes cause Bleed / Heartseeker also Marks / she starts each fight with half mana.
- **Apex options:**
  - **Eagle Eye:** Heartseeker executes enemies below 20% HP. *Taste:* Heartseeker deals +10% to wounded enemies. *Deed:* kills with Heartseeker.
  - **Stormline:** Heartseeker hits every enemy in a line. *Taste:* it pierces one more enemy. *Deed:* enemies hit by Heartseeker's pierce.

### Path 2: Trapper (control)

The fantasy: she controls the ground, and enemies walk into her plan.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Snare:** once per fight, she drops one snare in the path of the nearest enemy; it roots whoever steps on it for 1.5s | Snares root for 2s and Bleed |
| **Signature** | Marking Shot | **Bramble Field:** throws a snare onto an enemy's predicted path; up to 3 at once |
| **Stats** | unchanged | +DEF, –ATK |
| **Cost** | –10% basic attack damage | her Longshot range drops to 3 |

- **Deed:** seconds enemies spend rooted by her. Without the taste she has no roots.
- **Arena hook:** once transformed, **you place her first 2 snares yourself** before the fight.
- **Where she stands:** near the front, where her snares go.
- **Upgrade pool examples:** snares Slow the enemies next to the rooted one / rooted enemies take +20% from her / a snare under Brannoc protects him / snares root leaping enemies / Bramble Field costs less mana.
- **Apex options:**
  - **Warden of Thorns:** sprung snares grow into briar walls that block movement. *Taste:* a sprung snare leaves a briar that blocks 1 hex for 2s. *Deed:* enemy moves blocked by briars.
  - **Huntmaster:** allies deal +30% to trapped enemies and prioritize them. *Taste:* allies deal +5% to rooted enemies. *Deed:* damage allies deal to rooted enemies.

### Path 3: Volley (area and mobility)

The fantasy: she's always moving and filling the air with arrows.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Split Shot:** every 4th basic attack also hits one enemy next to the target | Every basic attack splits to one extra enemy |
| **Signature** | Marking Shot | **Arrow Storm:** arrows rain on a 3-hex circle for 3s |
| **Stats** | unchanged | +ATSP, –damage per arrow |
| **Mana** | unchanged | each extra enemy hit gives mana |
| **Cost** | –1 range (3 hexes) | same, but she fires while moving, with no planting |

- **Deed:** extra enemies hit by a single shot. Without Split Shot it stays at zero.
- **Where she stands:** a loose spot with room to move.
- **Upgrade pool examples:** Arrow Storm follows the largest group / splits chain twice / her hop happens every 3s and she fires mid-hop / Arrow Storm Slows / kills with split arrows give mana.
- **Apex options:**
  - **Rain of Ash:** Arrow Storm is larger and leaves burning ground. *Taste:* Arrow Storm lasts 0.5s longer. *Deed:* enemy-seconds spent inside Arrow Storm.
  - **Windrunner:** she never stops moving, hopping after every few shots. *Taste:* her hop cooldown drops by 1s. *Deed:* shots fired within 1s of hopping.

---

## 7. Brannoc of the Hearthwatch: the warden (tank)

**Role:** front line. He holds enemies in place, soaks damage, and protects the back line.

| | |
| --- | --- |
| **Stats** | HP 420, ATK 14, DEF 30 |
| **Speed / range** | speed 2, melee (1) |
| **Basic attack: Shield Bash** | a blow on an adjacent enemy |
| **Signature: Hold the Line** (80 mana) | taunts enemies within 2 hexes for 3s; he gains DEF while they're taunted |
| **Passive: Hearthguard** | the first ally to drop below 40% HP gets a Shield from him (once per fight) |
| **Trait: Engage** | enemies next to him are engaged and can't walk past him without spending time breaking free |

### Path 1: Hearthwall (the protector; stays a tank)

The fantasy: nothing reaches the people behind him.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Guard:** the ally directly behind him takes 10% less damage; Brannoc takes that 10% instead | Guard covers every adjacent ally at 30% |
| **Signature** | Hold the Line | **Hearthwall:** a wall of shields across 3 hexes in front of him that blocks ranged attacks for 4s |
| **Stats** | unchanged | +HP, +DEF, –ATK |
| **Mana** | unchanged | gains mana from damage he takes for allies |
| **Cost** | –10% Shield Bash damage | speed 1; can't move while his wall stands |

- **Deed:** damage he takes in place of allies. Taunted hits don't count (they're attacks on him), so without Guard it doesn't move.
- **Where he stands:** right in front of Maren and Vell, covering the lane to them.
- **Upgrade pool examples:** his wall reflects arrows / guarded allies recover 2% HP when he takes their hit / Hold the Line pulls enemies 1 hex toward him / Hearthguard triggers twice / his wall lasts 2s longer.
- **Apex options:**
  - **The Unbroken Gate:** his wall also blocks movement and stands until broken. *Taste:* the wall is 1 hex wider. *Deed:* ranged attacks blocked by his wall.
  - **The Hearthkeeper:** damage he takes for others partly heals the allies he guards. *Taste:* guarded allies heal 1% of the damage he takes for them. *Deed:* healing given to guarded allies.

### Path 2: Ironbrand (the bruiser; gains a second role, Striker)

The fantasy: the best defense is standing in the middle of them and swinging.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Brand:** Shield Bash also hits one other adjacent enemy, for 30% damage | His basic attack becomes **Hearthbrand Mace**: hits every adjacent enemy and heals him for 5% of the damage |
| **Signature** | Hold the Line | **Brand Slam:** leaps up to 2 hexes into the largest group of enemies, damages them, and knocks them back |
| **Stats** | unchanged | +ATK, +HP, –DEF |
| **Mana** | unchanged | gains mana for each enemy his cleave hits |
| **Cost** | Hold the Line taunts for 1s less | Hold the Line only taunts adjacent enemies |

- **Deed:** extra enemies hit by a single Shield Bash. Without Brand it only ever hits one.
- **Where he stands:** forward, where the enemies will bunch up.
- **Upgrade pool examples:** his healing grows with each enemy hit / enemies knocked into other enemies are stunned / Brand Slam aims for Marked targets / +ATK for each adjacent enemy / his cleave causes Bleed.
- **Apex options:**
  - **Forgebreaker:** each hit brands its target; at 5 brands it explodes. *Taste:* every 5th hit on the same enemy deals +20%. *Deed:* 5th hits landed.
  - **Warlord:** Brand Slam rallies the team; allies near where he lands gain ATK. *Taste:* allies within 1 hex of his landing gain +5% ATK for 2s. *Deed:* attacks allies make while rallied.

### Path 3: Last Watch (the martyr)

The fantasy: he's at his most dangerous when he should already be dead.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Unyielding:** once per fight, a hit that would fell him leaves him at 1 HP instead | Below 30% HP he gains DEF and ATK, and he gets stronger for each fallen ally |
| **Signature** | Hold the Line | **Last Rites** (HP-triggered, no mana: fires once per fight, when he first drops below 30% HP): taunts every enemy within 3 hexes, and he can't be felled for 3s |
| **Stats** | unchanged | +ATK, –10% max HP |
| **Mana** | unchanged | **none**: his only signature is HP-triggered, so he has no mana bar (and mana drain and Silence can't touch him) |
| **Cost** | –5% max HP | healing on him is 30% weaker |

- **Deed:** damage he deals while below 30% HP. Without Unyielding he rarely survives long at low HP.
- **Where he stands:** the most exposed spot, to draw fire away from everyone else.
- **Upgrade pool examples:** when he finally falls, allies gain a Shield / each second below 30% stacks DEF / Last Rites heals the allies it protected / kills while low restore 5% HP / Last Rites taunts for 1s longer.
- **Apex options:**
  - **Undying Oath:** he returns 3s after falling, at 30% HP, fully fighting. *Taste:* **Smoldering Oath**: when he falls, he rises 8s later at 5% HP; he can't attack, but he still engages and taunts. *Deed:* damage he absorbs after rising. (Last Rites is about refusing to fall; Undying Oath is about coming back after he does.)
  - **Martyr's Pyre:** when he falls, he bursts, damaging nearby enemies and healing allies. *Taste:* when he falls, adjacent allies heal 5%. *Deed:* healing given by his fall.

---

## 8. Sister Vell: the mender (support)

**Role:** back-line support. She heals, and depending on her path she protects or punishes.

| | |
| --- | --- |
| **Stats** | HP 300, ATK 6, MGK 20, DEF 10 |
| **Speed / range** | speed 2, casts at up to 3 hexes |
| **Basic attack: Lantern Glow** | a bolt of light at the nearest enemy in range; her main source of mana |
| **Signature: Mend** (60 mana) | heals the ally lowest on HP (by %) within 3 hexes |
| **Passive: Hearthlight** | allies within 1 hex of her regenerate 1% HP per second |

Hearthlight is her arena hook: standing close to her is safer, but bunching up is what enemy area attacks punish.

### Path 1: Lanternbearer (the pure healer)

The fantasy: a warm light that keeps everyone standing.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Kindle:** Mend also heals one ally next to its target, for 10% | Mend heals every ally next to its target, at 50% |
| **Signature** | Mend | **Night Lantern:** sets a lantern on a hex; for 5s, allies within 2 hexes heal over time and are cleansed of Burn and Poison |
| **Stats** | unchanged | +MGK, –HP |
| **Cost** | Mend costs 5 more mana | her Lantern Glow deals no damage (it still builds mana) |

- **Deed:** healing Mend gives to allies next to its target. Without Kindle, Mend heals one ally.
- **Where she stands:** in the middle, behind Brannoc, where her lantern reaches everyone.
- **Upgrade pool examples:** place the first lantern yourself before the fight / overhealing becomes Shield / the cleanse also removes Slow / Mend chains to a third ally / Mend refunds 20 mana if its target was below 30% HP.
- **Apex options:**
  - **The Beacon:** her lantern's light also weakens and burns enemies inside it. *Taste:* enemies in the light deal 5% less damage. *Deed:* damage prevented by the light.
  - **Dawnbringer:** her heals also speed allies up. *Taste:* healed allies gain +5% attack speed for 2s. *Deed:* attacks allies make while sped up.

### Path 2: Wardweaver (the shielder; gains a second role, Warden)

The fantasy: stop the damage before it lands, rather than fixing it afterward.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Ward Thread:** Mend on an ally already at full HP gives them a small Shield instead (10% of the heal) | Mend becomes **Weave**: mostly Shield, plus a little healing |
| **Signature** | Mend | **Warding Circle:** a ring 2 hexes wide for 4s; enemies entering it are Slowed, and allies inside take 20% less damage |
| **Stats** | unchanged | +HP, +DEF, –MGK |
| **Cost** | Mend heals 10% less | her healing is 40% weaker; she's built around Shield |

- **Deed:** Shield she gives. Without Ward Thread she gives none.
- **Where she stands:** forward, next to Brannoc; where the circle goes matters.
- **Upgrade pool examples:** her Shields burst when broken / Shields on a tank are doubled / the circle blocks arrows / Weave also cleanses / her Shields last until broken.
- **Apex options:**
  - **Loomwarden:** her Shields link allies, and damage is split among everyone linked. *Taste:* two allies with her Shields share 5% of the damage they take. *Deed:* damage shared through links.
  - **Thornweave:** broken Shields strike back at the attacker. *Taste:* a broken Shield deals 10% of its value to whoever broke it. *Deed:* damage dealt by broken Shields.

### Path 3: Vigil Keeper (the battle cleric; bends toward damage)

The fantasy: her light heals friends and burns enemies.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Judgment:** every 4th Mend also smites the enemy nearest its target, for 10% of the heal as damage | Every Mend smites |
| **Signature** | Mend | **Sunfall** (replaces Mend as her signature; Mend becomes a smaller heal that fires every 4th basic attack): a beam of light along a line that damages enemies and heals allies in it |
| **Stats** | unchanged | +MGK, +CRIT, –DEF |
| **Mana** | unchanged | her smites give mana |
| **Cost** | Mend's range –1 | her healing is 30% weaker |

- **Deed:** damage dealt by smites. Without Judgment she never smites.
- **Where she stands:** off to the side, with a clean line for Sunfall.
- **Upgrade pool examples:** smites jump to a second enemy / Sunfall is wider / her crits also heal / smitten enemies are Slowed / heals on allies below 30% HP give extra mana.
- **Apex options:**
  - **Inquisitor:** smites finish off wounded enemies. *Taste:* smites deal +10% to Marked enemies. *Deed:* kills by smite.
  - **Sanctifier:** Sunfall leaves hallowed ground behind. *Taste:* Sunfall lingers for 0.5s. *Deed:* enemy-seconds spent on hallowed ground.

---

## 9. How the three fit together

- **Maren's weakness is flankers.** Hearthwall's Guard and wall, Brannoc's Engage, and Trapper's snares all answer it.
- **Last Watch Brannoc and a healer Vell pull against each other.** His cost is weaker healing, which hurts with Lanternbearer but not with Wardweaver. That's a real decision.
- **Wardweaver + Hearthwall** make a nearly unbreakable but slow front line.
- **Marked** ties Maren, Ironbrand's Brand Slam, and Vigil Keeper's Inquisitor together.
- These pairings are what duo bonds could be built on later.

## 10. What this removes from the current game

- **Removed:** essences (and everything built on them: infusions, alloys, Awakening, spill, spread, conduits, transformations, resonance, essence shops, the Forge, kits); ranks and rank-ups; the calling deed track (replaced by path deeds); shared affinities; the team draft (until hero 4); the other 5 heroes (for now).
- **Replaced:** the rank-B specialization pick becomes the vow; the two rows become the arena; item cooldowns on signatures become mana.
- **Still open:** items, shops, and gold (a later part of the plan).

## Open questions

- **Pacing:** how many fights should a transformation take? How many upgrade picks come before the apex vow opens? (Depends on the run's structure.)
- **Deed thresholds after the transformation:** does the same deed keep counting, with each threshold giving an upgrade pick?
- **Mana numbers:** the table in section 4 is a first pass for the sim to tune.
- **Last Watch after Last Rites:** once his one HP-triggered signature has fired, he has no big move left in that fight. Whether that's the right feel is decided by playtesting.