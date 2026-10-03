# Rebuild plan, part 1: heroes

Status: **agreed in discussion (2026-09-27), not built.** This is the first part of a from-scratch rethink of the game. Later parts (the arena, enemies, the run, and what replaces items and shops) build on it. Numbers are placeholders to tune. **Part 7 (`rebuild-combos.md`, 2026-09-30) adds to this part:** shared keywords, more triggers, one damage rule, and permanent scaling.

**Why:** playtests say the game is far too easy, essences aren't fun, two rows of units make tanks pointless, and items all feel the same. The rethink puts **heroes** at the center: each hero changes over a run in ways you choose and then earn by playing them well.

## Decisions

- **A team is 3 heroes, kept for the whole run.** All three fight.
- **Start with 3 heroes only: Brannoc, Maren, and Vell.** Get them right before adding more. With a roster of 3 there's no team draft yet; it comes back with hero 4.
- **Every hero has a main role** (tank, damage, support, control), and their path can bend it. **There are no shared role traits:** each hero's own passives and traits do that job (Brannoc's Engage is his, not every tank's).
- **Vows happen when the team is chosen:** after picking your three heroes, you vow each one to a path before the first fight. You can switch a vow between fights until that hero transforms.
- **Transformations are permanent.** Only the apex vow can still be switched, until the apex is earned.
- **Heroes grow through deeds and after-fight picks.** No ranks, no buying heroes, no combining duplicates. Deeds bring the big moments (the transformation, then the apex); upgrade picks come after every won fight, not from deeds (part 6, `rebuild-between-fights.md`, 2026-09-29).
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
| **Transformation** | The vowed path's deed fills | The hero becomes the path: new signature, reshaped stats, the full mechanic, and the path's upgrade pool joins their offers |
| **Upgrades** | After every won fight (part 6) | Pick 1 of 3 upgrades, each card naming its hero: before the transformation from the hero and role layers (and some leaning to the vowed path), after it from the path's pool too |
| **Apex** | After the Act 1 boss | The path splits into 2 final forms. You vow to one, earn it the same way, and the hero transforms again. Each apex has a built-in snowball (`apexes.md`) |

### The rules

- **The vow is the player's decision.** It's made when the team is chosen, and you can switch it between fights until the hero transforms.
- **The transformation is permanent.** After it, only the apex vow can be switched, until the apex is earned.
- **The taste is small: about 5–10% of the path, and only one piece of it.** It previews one mechanic and doesn't make the hero feel transformed. The transformation must feel like a different, stronger hero.
- **The taste is the tool for the deed.** All three path deeds count whatever the hero actually does, all the time, with no bonus for being vowed. But each deed measures something the taste makes possible, so without the vow it barely moves. That's why the vowed path fills.
- **Only the vowed path can complete.** Switching vows keeps whatever the other paths have built, which is usually very little.
- **Every deed must be hard to fill without its taste.** A deed that counts something the hero does anyway ("deal damage") makes the vow meaningless.
- **Apexes work the same way**: vow, taste, earn, transform.
- **A deed can be a feat:** one hard thing done once (Bounty Hunter: collect 1 Bounty), instead of a running total. A feat must still need the taste, and must be something the player plans for (placement, fight choice).

### Upgrade pools

> **Superseded (2026-09-30):** the pools are now a hero pool (12, merging hero and role), taste upgrades (2 per path), and path upgrades (4 per path plus the growing upgrade). See `upgrade-pools.md`. The layers below are kept for reference.

Upgrade picks only mean something if the pool is big enough to vary between runs. Picks come after every won fight (part 6), shared among the three heroes, so each offer draws from three layers:

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
- **New heroes are designed against the build map** (`build-map.md`): each of a new hero's three paths makes or pays off a different team build, and the map's table is updated.

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
| Ilse | 60 | none | none | none: **Heat**, 1 per Burn tick on any enemy within 3 hexes | 0 |
| Tamsin | 50 | +8 (fast attacks) | none | 2/s | 0 |
| Garrow | 70 | +6 | +1 per 10 damage taken | none | 0 |
| Aldous | 60 | +10 | none | 2/s | 0 |
| Hob | 50 | +8 | none | 2/s | 0 |
| Severine | 60 | +8 | none | 2/s | 0 (Hemomancer: none; she casts with HP) |
| Edric | 70 | +8 | none | 2/s | 0 |
| Ottilie | 60 | +10 | none | 2/s | 0 |
| Lucan | 60 | +10 | none | 2/s | 0 |
| Kestra | 50 | +8 | none | 2/s | 0 |

Example: if Vell attacks, she earns about 10 mana a second and Mends every 6s. If she can't attack, she only has regen and Mends every 30s. Her attack matters, and placing her where she can attack safely is part of the puzzle.

## 5. Shared statuses

- **Marked:** a single team-wide status. Maren's Marking Shot applies it; Vell's Inquisitor and Brannoc's Brand Slam build on it. Later heroes should build on it too, rather than inventing their own marks.
- **Engaged:** set by Brannoc's Engage trait (later tanks may have their own version). An engaged enemy can't walk past the tank without spending time breaking free.
- **Damage over time (Burn, Bleed, Poison) is one shared pile of stacks** on an enemy. **Nothing may depend on who applied it,** only on how much is there, or on how much a hero *applied* at the moment they applied it. (No per-source tracking in the sim.)
- **A Shield is one pool per unit, with no owner and no duration** (as the sim stores it). **Nothing may depend on who gave a Shield,** only on whether a unit has one, how big it is, or the moment a Shield is given or breaks. Shields last until broken.
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
- **Upgrade pool examples:** Heartseeker kills refund mana / she plants in 0.75s / crits from 6 hexes cause Bleed / Heartseeker also Marks / she starts each fight with half mana. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
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
- **Upgrade pool examples:** snares Slow the enemies next to the rooted one / rooted enemies take +20% from her / a snare under Brannoc protects him / snares root leaping enemies / Bramble Field costs less mana. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
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
- **Upgrade pool examples:** Arrow Storm follows the largest group / splits chain twice / her hop happens every 3s and she fires mid-hop / Arrow Storm Slows / kills with split arrows give mana. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
  - **Hailstorm** (replaced Rain of Ash, 2026-10-03; `apexes.md`): Arrow Storm is larger, her shots drop volleys of it, and its hits grow her damage for the fight. *Taste:* Arrow Storm fires 1 more volley. *Deed:* enemies hit by Arrow Storm.
  - **Windrunner:** she never stops moving, hopping after every few shots. *Taste:* her hop cooldown drops by 1s. *Deed:* shots fired within 1s of hopping.

---

## 7. Brannoc of the Hearthwatch: the warden (tank)

**Role:** front line. He holds enemies in place, soaks damage, and protects the back line.

| | |
| --- | --- |
| **Stats** | HP 630, ATK 14, DEF 50 (was HP 420, DEF 30; raised after playtest gate 3, `rebuild-phase5-run.md` Decision 18) |
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
- **Upgrade pool examples:** his wall reflects arrows / guarded allies recover 2% HP when he takes their hit / Hold the Line pulls enemies 1 hex toward him / Hearthguard triggers twice / his wall lasts 2s longer. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
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
- **Upgrade pool examples:** his healing grows with each enemy hit / enemies knocked into other enemies are stunned / Brand Slam aims for Marked targets / +ATK for each adjacent enemy / his cleave causes Bleed. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
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

- **Deed:** damage he deals while below 30% HP. Without Unyielding he rarely survives long at low HP. *(Phase 4 changed it provisionally to damage he deals while he can't fall: in the sim, Vell keeps base Brannoc fighting at low HP. See `rebuild-phase4-paths.md`, Decision 9.)*
- **Where he stands:** the most exposed spot, to draw fire away from everyone else.
- **Upgrade pool examples:** when he finally falls, allies gain a Shield / each second below 30% stacks DEF / Last Rites heals the allies it protected / kills while low restore 5% HP / Last Rites taunts for 1s longer. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
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
- **Upgrade pool examples:** place the first lantern yourself before the fight / overhealing becomes Shield / the cleanse also removes Slow / Mend chains to a third ally / Mend refunds 20 mana if its target was below 30% HP. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
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
- **Upgrade pool examples:** her Shields burst when broken / Shields on a tank are doubled / the circle blocks arrows / Weave also cleanses / her Shields last until broken. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
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
- **Upgrade pool examples:** smites jump to a second enemy / Sunfall is wider / her crits also heal / smitten enemies are Slowed / heals on allies below 30% HP give extra mana. (Final pool: `upgrade-pools.md`.)
- **Apex options:** (Final versions, with numbers and upgrades: `apexes.md`.)
  - **Inquisitor:** smites finish off wounded enemies. *Taste:* smites deal +10% to Marked enemies. *Deed:* kills by smite.
  - **Sanctifier:** Sunfall leaves hallowed ground behind. *Taste:* Sunfall lingers for 0.5s. *Deed:* enemy-seconds spent on hallowed ground.

---

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

---

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

---

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

---

## 8e. Aldous Vesper: the bell-ringer (support)

*Added 2026-10-02.* **Role:** back-line support who powers the team up rather than healing it. Shares the support role with Vell. Builds (`build-map.md`): Mana (maker), Rangers (support), Mark (maker).

| | |
| --- | --- |
| **Stats** | HP 290, ATK 10, MGK 16, DEF 10 |
| **Speed / range** | speed 2, up to 3 hexes |
| **Basic attack: Toll** | a ringing note at the nearest enemy in range (MGK damage); his main source of mana |
| **Signature: Peal** (60 mana) | allies within 3 hexes gain +15% attack speed for 4s |
| **Passive: Resonance** | allies within 2 hexes of him get +5% attack speed |

His base kit gives no mana to allies, has no ranged-ally bonus, and never Marks: each path's deed needs its taste.

### Path 1: Chorister (Mana: maker)

The fantasy: his breath becomes the whole band's breath.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Shared Breath:** when he fires his signature, the ally with the least mana gains 15 mana | Each time he gains mana, allies within 3 hexes gain half as much |
| **Signature** | Peal | **Crescendo:** allies within 3 hexes gain 40 mana |
| **Cost** | –10% max HP | His own signature costs 20 more mana |

- **Deed:** mana given to allies.
- **Gives mana, never cheaper signatures** (that's the Thrift sigil's job).
- **Plays off:** heroes with strong mana signatures: Ilse (a second fuel beside Heat), Vell, Tamsin's Sentence, and anyone holding Echo or The Second Sun.

### Path 2: Windcaller (Rangers: support)

The fantasy: the wind carries his allies' shots and keeps the enemy off them.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Tailwind:** allies attacking from 3 or more hexes away get +5% attack speed | Allies attacking from 3+ hexes deal +20% damage, and their shots fly 50% faster |
| **Signature** | Peal | **Gale:** knocks back every enemy within 2 hexes of each ranged ally |
| **Cost** | –1 range | Peal and Resonance no longer reach melee allies |

- **Deed:** attacks allies make under Tailwind.
- **No range and no pierce:** extra range would let base Maren fill Deadeye's deed without the vow, and pierce belongs to Volley and Stormline. Windcaller buffs damage and shot speed, and protects the back line.
- **Plays off:** ranged heroes (Maren, Ilse, Vell), and Ember Choir (faster attacks, more Burn).

### Path 3: Bellwarden (Mark: maker)

The fantasy: the bell names who dies next.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Toll the Hour:** every 4th Toll Marks its target for 2s | Every Toll Marks its target for 3s, and enemies he Marks take an extra +5% damage |
| **Signature** | Peal | **Death Knell:** Marks every enemy within 3 hexes of his target for 5s |
| **Cost** | –10% MGK | Toll deals 20% less damage |

- **Deed:** Marks he applies.
- **Plays off:** Mark payoffs: Tamsin's Headhunter, Inquisitor (Vigil Keeper), Brand the Marked (Ironbrand), and the Mark relics.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.

---

## 8f. Hob Gleaner: the scavenger (skirmisher)

*Added 2026-10-02.* **Role:** a light mid-line skirmisher who picks at weak enemies and pockets what drops. **Deliberately weaker in a fight than the other heroes:** you give up power now for a richer run. Builds (`build-map.md`): Economy (maker and payoff), Mark (maker).

| | |
| --- | --- |
| **Stats** | HP 300, ATK 16, DEF 12, CRIT 10 |
| **Speed / range** | speed 3, sling at up to 2 hexes |
| **Basic attack: Sling Stone** | a stone at the nearest enemy in range; his main source of mana |
| **Signature: Grab** (50 mana) | darts to the lowest-HP enemy within 3 hexes and hits it for 150% of his ATK |
| **Passive: Pickings** | when an enemy dies within 2 hexes of him, +1 shard |

- **The cap:** everything Hob earns in one fight, from any source in his kit, is capped at **8 shards** (raised by some apexes). Without it, endless mode becomes infinite money.
- **Shards from the sim:** shards he earns in a fight are combat log entries (with their source, rule 4), and the run reads them after the fight. That's a new log kind: it needs an audit rule in `test_arena_log.gd` and a form on the board (a coin popping from the enemy).

### Path 1: Hoarder (Economy: payoff for saving)

The fantasy: the heavier the purse, the harder he hits.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Nest Egg:** +1% ATK and DEF per 10 shards held (up to +10%) | +1% ATK and DEF per 5 shards held, with no cap; allies get half as much |
| **Signature** | Grab | **Heavy Purse:** slams his target for his ATK plus 2 damage per shard held |
| **Cost** | –10% max HP | Rerolls cost him 1 more shard |

- **Deed:** extra damage from Nest Egg. Only Nest Egg turns held shards into damage.
- **The gamble:** every relic you buy makes him weaker.

### Path 2: Fence (Economy: payoff for spending)

The fantasy: everything has a price, and he always gets a better one.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Haggle:** the first reroll in each shop is free | Rerolls cost half (rounded down). **Every shard spent in a shop gives the team +0.1% ATK, MGK, and max HP for the rest of the run** |
| **Signature** | Grab | **Cut Purse:** a hit that makes the target drop 1 shard (once per enemy) and lowers its ATK by 15% for 4s |
| **Cost** | –10% ATK | Shops buy items back from him for a quarter of their price, not half |

- **Deed:** shards saved by Haggle. (Counting shards *spent* wouldn't need the taste: everyone spends.)

### Path 3: Bounty Hunter (Mark: maker; Economy)

The fantasy: every fight has a price on one head.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Bounty:** at the fight's start, the toughest enemy (most max HP) is a Bounty, Marked for 8s. Killing it while it's still Marked pays 2 shards | The toughest enemy is a Bounty, Marked for as long as it lives; when it dies, the next toughest becomes the Bounty. Each Bounty pays 3 shards |
| **Signature** | Grab | **Collect:** strikes the Bounty for 200% of his ATK, from anywhere within 4 hexes |
| **Cost** | –1 speed | –10% damage to enemies that aren't the Bounty |

- **Deed: collect 1 Bounty.** The first **feat deed**: one kill transforms him, but it needs planning (place your damage next to the toughest enemy, pick a fight where the kill is realistic, burst it within 8s).
- **Plays off:** Mark payoffs (Tamsin's Headhunter, Inquisitor, Aldous's Requiem, Brand the Marked): a Mark that never drops on the toughest enemy.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.

---

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

---

## 8h. Edric Tithewell: the tithe-warden (support)

*Added 2026-10-02.* **Role:** a back-line support who wards the whole team. Wardweaver shields one ally at a time through her heals; Edric covers everyone, and each path asks what Shields pay out. Shares the support role with Vell and Aldous. Builds (`build-map.md`): Shield (maker; Bastion of Saints is also a payoff), Economy (maker and payoff), Mana (maker).

| | |
| --- | --- |
| **Stats** | HP 320, ATK 10, MGK 16, DEF 16 |
| **Speed / range** | speed 2, up to 3 hexes |
| **Basic attack: Seal** | a stamped seal at the nearest enemy in range (MGK damage); his main source of mana |
| **Signature: Ward** (70 mana) | every ally gains a Shield of 8% of their max HP |
| **Passive: Vigil** | Shielded allies within 2 hexes of him take 5% less damage |

**His paths count any Shield, never "his" Shields** (section 5: a Shield has no owner). His deeds count only what his own effect gives at that moment.

### Path 1: Aegis (Shield: maker)

The fantasy: no one under his watch goes unwarded.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Hallow:** every 6s, the lowest-HP ally gets a Shield of 4% of their max HP | Hallow every 3s, at 6% of their max HP |
| **Signature** | Ward | **Sanctuary:** every ally gains a Shield of 20% of their max HP |
| **Cost** | –10% MGK | None |

- **Deed:** Shield given by Hallow.

### Path 2: Tithe-Collector (Economy: maker)

The fantasy: the rift takes its toll, and he collects his share.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Tithe:** after a won fight, +1 shard for each hero still standing | +2 shards per hero still standing |
| **Signature** | Ward | **Collection:** every ally gains a Shield of 8% of their max HP, and each enemy that dies in the next 5s pays 1 shard (up to 3 per cast) |
| **Cost** | –10% DEF | –15% max HP |

- **Deed:** shards from Tithe.
- **Unlike Hob:** Hob earns by killing and pays in fight power; Edric earns by keeping everyone standing.

### Path 3: Psalmist (Mana: maker)

The fantasy: every ward that shatters becomes a breath of power.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Offering:** when any Shield on an ally breaks, that ally gains 5 mana | When any Shield on an ally breaks, they gain 10 mana, and allies gain mana 10% faster while they have any Shield |
| **Signature** | Ward | **Vesper Ward:** every ally gains a Shield of 10% of their max HP and 25 mana |
| **Cost** | –10% MGK | Vesper Ward's Shields are 25% smaller |

- **Deed:** mana given by Offering.
- **Unlike Aldous:** Aldous shares his own mana income; Edric gives mana when Shields break, so front-liners who take hits (Brannoc, Garrow, Severine) fill fastest.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.

---

## 8i. Ottilie Brack: the alchemist (caster)

*Added 2026-10-02.* **Role:** back-line caster who throws vials of fire and venom. Shares the damage role. Builds (`build-map.md`): Burn and Poison (payoff, Catalyst), Economy (maker, Transmuter), Mana (maker, Apothecary).

| | |
| --- | --- |
| **Stats** | HP 280, ATK 8, MGK 18, DEF 10 |
| **Speed / range** | speed 2, up to 3 hexes |
| **Basic attack: Toss** | a vial at the nearest enemy in range (MGK damage); her main source of mana |
| **Signature: Volatile Flask** (60 mana) | bursts on a 1-hex circle around her target: 120% of her MGK, plus Burn and Poison each equal to 20% of her MGK |
| **Passive: Brewing** | every 4s, her next Toss is a fire vial (Burn equal to 20% of her MGK) or a venom vial (Poison, the same amount), alternating |

**Her vials ride on her attacks:** Brewing, and Apothecary's mana vials, trigger on her *next Toss* after their timer, never on a free timer. With nothing in range, no vials fly.

### Path 1: Catalyst (Burn and Poison: payoff)

The fantasy: two poisons are worse than one, and she knows exactly how much worse.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Reaction:** +1% damage per 5 Burn and Poison on her target, combined (up to +10%) | +1% damage per 2 Burn and Poison on the target, with no cap, and +25% damage against enemies with both |
| **Signature** | Volatile Flask | **Reaction Flask:** hits her target and enemies within 1 hex for 100% of her MGK plus 3 per Burn and Poison on each. It reads them without using them up |
| **Cost** | –10% max HP | Brewing stops |

- **Deed:** extra damage from Reaction.
- **Reads totals, never sources** (section 5).
- **Plays off:** teams applying both Burn and Poison (Ilse with Severine, Tamsin's Poisoned Blades, the Burn relics). The only payoff for mixing the two.

### Path 2: Transmuter (Economy: maker)

The fantasy: lead into gold, and the dead into coin.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Gilded Death:** an enemy that dies while both Burning and Poisoned pays 1 shard (up to 3 per fight) | It pays 2 shards (up to 8 per fight), and once per shop she can turn an item you own into shards at its full price |
| **Signature** | Volatile Flask | **Philosopher's Flask:** hits her target and enemies within 1 hex for 120% of her MGK, plus Burn and Poison each equal to 20% of her MGK; enemies it kills pay 2 shards |
| **Cost** | –10% max HP | Brewing slows to every 6s |

- **Deed:** shards from Gilded Death.
- **Unlike Hob and Edric:** she earns from enemies dying while both Burning and Poisoned, and by transmuting items at full price (shops normally pay half).

### Path 3: Apothecary (Mana: maker)

The fantasy: a vial for the foe, and a tonic for the friend.

| | Taste (vowed) | Transformed |
| --- | --- | --- |
| **Mechanic** | **Tonic:** every 8s, her next Toss also throws a mana vial to the ally with the least mana (+10 mana) | Every 4s, her next Toss also throws a mana vial to the ally with the lowest mana (by %): +20 mana and +10% attack speed for 3s. Brewing stays |
| **Signature** | Volatile Flask | **Elixir:** every ally gains 30 mana, plus +10% ATK and MGK for 4s |
| **Cost** | –10% MGK | Toss deals 15% less damage |

- **Deed:** mana given by Tonic.
- **Unlike Aldous and Edric:** Aldous shares his own mana income, Edric gives mana when Shields break; Ottilie delivers it with her attacks, to whoever needs it most.

- **Upgrade pool:** `upgrade-pools.md`. **Apexes:** `apexes.md`.

---

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

---

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

---

## 9. How the heroes fit together

- **Maren's weakness is flankers.** Hearthwall's Guard and wall, Brannoc's Engage, and Trapper's snares all answer it.
- **Last Watch Brannoc and a healer Vell pull against each other.** His cost is weaker healing, which hurts with Lanternbearer but not with Wardweaver. That's a real decision.
- **Wardweaver + Hearthwall** make a nearly unbreakable but slow front line.
- **Marked** ties Maren, Ironbrand's Brand Slam, and Vigil Keeper's Inquisitor together.
- **Ilse turns any team's Burn into tempo:** every Burn source on the team feeds Heat. Furnace wants attack speed, Wildfire wants enemies bunched (Last Watch's taunts, Ironbrand's knockback), and Ember Choir wants allies who hit often or hit many (Volley, Ironbrand).
- **Tamsin cashes in what others set up:** Marks (Headhunter), Roots and Stuns (Garrote), or her own kills (Nightblade). Hearthwall and Last Watch keep enemies busy while she's out of Stealth.
- **Garrow turns other heroes' work into his:** Shields from Vell and Brannoc into Bulwark Burst, clumps into Crowd Strength, and enemy attention into damage sent back. Chainwarden's pulls set up Volley, Wildfire, Tamsin, and Ironbrand.
- **Aldous makes everyone else better at what they already do:** more signatures (Chorister), stronger ranged allies (Windcaller), or Marks for the payoff heroes (Bellwarden).
- **Hob trades fight power for run power:** Hoarder pays off saving, Fence pays off spending, and Bounty Hunter gives the Mark heroes a permanent target.
- **Severine is the lifesteal payoff the relics needed:** Aldous's attack speed and the lifesteal relics (Shadow Engine, Blood Communion) feed Bloodglut and Hemomancer; Tamsin's Poisoned Blades feeds Plaguebearer.
- **Edric turns Shields into whatever the team lacks:** more protection (Aegis), money (Tithe-Collector), or mana (Psalmist). Every Shield maker on the team (Wardweaver, Hearthguard, Garrow's Aegisfang, Tithe of Iron) feeds his paths.
- **Ottilie bridges the damage-over-time heroes:** Brewing adds both Burn and Poison to any team, and Catalyst cashes in Ilse's Burn and Severine's Poison together. Transmuter and Apothecary give every team a third choice for shards and mana.
- **Lucan multiplies whatever the team already does:** copies carry allies' on-hit effects, Veilweaver keeps the threatened hidden, and Puppeteer grows with every unit on your side (Severine's thralls included).
- **Kestra completes the summons team** with Lucan and Severine, and gives Burn and Poison teams a second maker that isn't a caster.
- These pairings are what duo bonds could be built on later.

## 10. What this removes from the current game

- **Removed:** essences (and everything built on them: infusions, alloys, Awakening, spill, spread, conduits, transformations, resonance, essence shops, the Forge, kits); ranks and rank-ups; the calling deed track (replaced by path deeds); shared affinities; the team draft (until hero 4); the other 5 heroes (for now).
- **Replaced:** the rank-B specialization pick becomes the vow; the two rows become the arena; item cooldowns on signatures become mana.
- **Settled in part 6** (`rebuild-between-fights.md`): no items or shops; loadout slots (charms, tactics, sigils, none of them abilities) bought with a currency. Charms are written against the slot ("your signature"), never an ability's name, so they survive a transformation.

## Open questions

- **Pacing:** how many fights should a transformation take? (The apex vow opens after the Act 1 boss; `apexes.md`.)
- **Deed thresholds after the transformation:** does the same deed keep counting toward the apex? (Upgrade picks no longer come from deed thresholds: part 6.)
- **Mana numbers:** the table in section 4 is a first pass for the sim to tune.
- **Last Watch after Last Rites:** once his one HP-triggered signature has fired, he has no big move left in that fight. Whether that's the right feel is decided by playtesting.