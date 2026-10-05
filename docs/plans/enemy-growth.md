# Enemy growth

Status: **agreed in discussion (2026-09-30); the rift modifiers (section 4) built in phase 5c step 8b (`rebuild-phase5c-combos.md`, section 16.13); specializations (`rebuild-phase8-act2.md` 8c-3a and `rebuild-phase8-act3.md` 8c-5a), upgrades (8c-5a), and the rift learns (8c-5d, its picks for a boss's adds) built in phase 8 part 3.** How enemies change over a run: specializations, upgrades, rift modifiers, and the rift learns. Fills in part 3, sections 7 and 8 (`rebuild-enemies.md`); where they disagree, this file wins. **Numbers and names are placeholders.**

## 1. When they show up

**Changed (the playtester, 2026-10-03; `rebuild-phase8-acts.md`, Decisions 4 and 10):** specializations start in **Act 2, from day 3**, not Act 1's day 5 (Act 1 has none); most of Act 3's enemies are specialized, with upgrades on its elites; and the rift learns (section 5) is on in Act 3 on normal difficulty, for the boss's adds only. The lines below are the earlier plan.

- **Act 1:** specializations appear from **day 5**, only in the harder of the day's two fights. **Built later, only when needed** (the playtester, 2026-09-30): Act 1 ships without them until they're wanted.
- **Act 2:** about half of a fight's enemies are specialized.
- **Act 3:** most are.
- **The fight card always shows** every specialization, upgrade, and rift modifier.

## 2. Specializations

A specialization changes how an enemy plays, not only its numbers, so the answer you learned has to change too. Each enemy has 2.

| Enemy | Specialization 1 | Specialization 2 |
| --- | --- | --- |
| **Rift Pup** | **Burrowing Pup:** burrows at the fight's start and comes up next to your back line 3s later | **Gnawing Pup:** its bites apply 1 Bleed, which stacks |
| **Ashling** | ~~**Splitting Ashling:** when it dies, it splits into 2 embers (10% of its HP each) that also burst into Burn~~ **Cut** (2026-10-03, `rebuild-phase8-acts.md` Decision 16: Act 2's Splitter archetype does it); a new one comes with Act 2's roster | **Smoldering Ashling:** leaves burning ground where it dies for 3s |
| **Rift Hound** | **Ashback Hound:** its Pounce leaves burning ground where it lands | **Gloam Hound:** after Pouncing, it leaps back out after 3s and Pounces again later |
| **Cinder Moth** | **Drifting Moth:** Ember Dust drifts toward the nearest hero for 2s | **Dazzling Moth:** heroes inside Ember Dust miss 30% of their attacks |
| **Hollow Archer** | **Pinning Archer:** its shots Root for 0.5s | **Volley Archer:** fires at every hero in a line |
| **Rift-Worn Sentinel** | **Warden Sentinel:** its Engage reaches 2 hexes | **Shattered Sentinel:** when it falls, it bursts and Slows heroes within 2 hexes by 30% for 3s |
| **Cairn Guardian** | **Avalanche Guardian:** its charge carries every hero in the line, not just the first | **Bulwark Guardian:** after charging, it engages and gains a Shield of 20% of its max HP |
| **Bog Lurker** | **Deep Lurker:** Drag pulls 3 hexes | **Rot Lurker:** a dragged hero is Poisoned |
| **Gloam Witch** | **Hex Witch:** Hush Silences the 2 heroes with the most mana | **Veil Witch:** instead of Shields, it hides one ally for 2s every 8s |

## 3. Upgrades

Small modifiers, mostly on elites and the boss, 1–2 at a time.

| Upgrade | Effect |
| --- | --- |
| **Frenzied** | +30% attack speed below 50% HP |
| **Warded** | Starts the fight with a Shield of 15% of its max HP |
| **Swift** | +1 speed |
| **Rift-Touched** | Gains mana 25% faster |
| **Thick-Hided** | +20% DEF |
| **Vengeful** | When it falls, allies within 2 hexes gain +20% ATK for 4s |
| **Anchored** | Can't be knocked back or pulled, and Roots on it last at most 1s |
| **Watchful** | Can target stealthed heroes |
| **Cinder-Skinned** | Burn on it deals half damage |
| **Shieldbreaker** | +50% damage to Shields |
| **Mark-Shy** | Marks on it last half as long |

## 4. Rift modifiers

Rules for the whole enemy side in one fight. **Rift Tear** adds 1 (Deep) or 2 (Abyssal), drawn at random (`days-and-nodes.md`). Endless mode can stack them later.

| Modifier | Effect |
| --- | --- |
| **Hastened** | Enemies get +20% attack speed |
| **Hardened** | Enemies get +20% DEF |
| **Rift-Charged** | Enemies start with 50% mana |
| **Reinforcements** | At 15s, 2 more enemies of a type already in the fight join from the edge |
| **Early Collapse** | The arena starts shrinking at 30s, not 45s |
| **Bloodthirst** | Enemies have 10% lifesteal |
| **Thornskin** | Enemies send 10% of the damage they take back to the attacker |
| **Blight** | Heroes' healing is 25% weaker |
| **Nightfall** | Enemies are hidden for the first 3s |
| **Blood Frenzy** | When an enemy falls, the rest gain +5% ATK for the rest of the fight (stacks) |

## 5. The rift learns

A difficulty modifier (part 3, section 8). With it on, the rift swaps some enemy specializations and upgrades for ones that counter what your team relies on.

- **What it reads:** at the start of each day, it adds up your last 3 fights from the combat log: keywords applied, healing, Shields, Stealth, mana spent, and where your heroes stood. It counters your top 1–2 habits.
- **How much it swaps:** up to half of a fight's specializations and upgrades. The rest are drawn as normal.
- **Deterministic:** the same seed, team, and fights always give the same result.
- **Counters blunt, never shut down.** No enemy is immune to anything, and the fight card shows every counter, so you can adapt your placement and loadout.

| If your team relies on | The rift answers with |
| --- | --- |
| **Roots and control** | Anchored |
| **Stealth** | Watchful |
| **Burn** | Cinder-Skinned, Smoldering Ashling |
| **Shields** | Shieldbreaker, Pinning Archer |
| **Marks** | Mark-Shy |
| **Healing and lifesteal** | Blight, Rot Lurker, Gnawing Pup |
| **Mana and signatures** | Hex Witch, Rift-Touched |
| **A protected back line** | Burrowing Pup, Gloam Hound, Deep Lurker |
| **Bunching up** | Drifting Moth, Avalanche Guardian, Smoldering Ashling |
| **A melee front line** | Shattered Sentinel, Thornskin (Splitting Ashling cut) |

## Where this meets what's built

None of the specializations, upgrades, rift modifiers, or the rift learns is built. What exists: enemy kit mods (`KitMod`, the shape the run already uses for Rift Tear's mod), which upgrades can use; Rift Tear as a camp option whose next fight gives every enemy a Shield (`data/camps.json`, `rift_tear_mod`), which is close to the Shallow depth; and every enemy ability the specializations name (Pounce, Ember Dust, Engage, Rampart Charge, Drag, Hush, and the Gloam Witch's Shields, Ward). Many specializations are new sim pieces (burrowing, splitting on death, drifting areas, misses, lines of shots); the rift learns needs a summary of the last 3 fights' logs kept in run state.

## Open questions

- **Where Blight and Thornskin come from under the rift learns:** they're rift modifiers, not upgrades. Can the rift learns add a modifier, or only swap specializations and upgrades?
- **Upgrades on normal enemies:** only elites and the boss, or occasionally normal enemies in Acts 2–3?
- **Later acts:** new enemies ("new faces" for the same archetypes) each need their own 2 specializations.
