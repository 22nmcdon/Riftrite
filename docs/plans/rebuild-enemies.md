# Rebuild plan, part 3: enemies

Status: **agreed in discussion (2026-09-27), not built.** Part of the from-scratch rethink: part 1 is `docs/plans/rebuild-heroes.md`, part 2 is `docs/plans/rebuild-arena.md`. Numbers are placeholders to tune.

**Why:** the game is far too easy, and enemies are mostly bags of HP. In the arena, enemies become where difficulty comes from: **each one creates a positioning problem**, with a clear answer somewhere in the heroes' paths.

## Goals

- **Every enemy type tests one thing**, and has an answer in the heroes' paths.
- **Fair:** you always see what's coming. Enemy positions and threats are shown before you place your heroes, and big attacks are marked before they land.
- **Harder means new problems, not more HP.** Later days combine threats instead of inflating stats. (Part 7, `rebuild-combos.md`: still true in the campaign; only the endless mode scales numbers.)

## Decisions

- **Heroes never step out of marked areas.** Placement before the fight is the skill. A hero that can dodge areas may come later, but it isn't Maren (her hop is about getting away from enemy units, not areas).
- **Enemies can have specializations and upgrades later** (section 7), far narrower than a hero's.
- **"The rift learns" is a difficulty modifier**, not always on (section 8).
- **Summon limit:** at most 30 standing units per side (2026-09-27), because summons may be small and spawn often.

## 1. What an enemy is

A simpler version of a hero:

- **Stats, movement, and range.**
- **A targeting rule** (nearest, weakest back-liner, largest group, farthest hero, and so on).
- **A basic attack.**
- **A signature**, using the same triggers as heroes (mana, HP threshold, count, or once per fight).
- **Sometimes a trait** (flying, Engage, a pack bonus).
- **No paths.** (See section 7 for the light version.)

Every enemy has a **one-line threat** shown on the fight card ("Pounces on your weakest back-liner") and an **archetype icon**, so a fight can be read at a glance.

## 2. Archetypes and the Act 1 roster

| Archetype | Enemy | What it does | What it tests | Answers |
| --- | --- | --- | --- | --- |
| **Swarm** | **Rift Pup** | fast (speed 3), weak; +ATK for each adjacent pup | Area damage, and closing lanes | Ironbrand's cleave, Arrow Storm, Engage holding a gap |
| **Swarm** | **Ashling** | bursts into Burn on adjacent units when it dies | Standing in melee crowds | Ranged damage, Lanternbearer's cleanse |
| **Flanker** | **Rift Hound** | **Pounce** (once per fight, at the start): leaps to the weakest back-liner within 4 hexes | Protecting the back line | Hearthwall's Guard, Engage, a snare on the landing spot |
| **Caster** | **Cinder Moth** | flies over units; **Ember Dust** (mana): a marked 2-hex circle on your largest group, which Burns | Bunching up | Spreading out, killing it fast with Deadeye |
| **Ranged** | **Hollow Archer** | range 5, so it outranges Maren; steps back when approached | Closing distance | Brand Slam's leap, Deadeye's range, Hearthwall's arrow-blocking wall |
| **Anchor** | **Rift-Worn Sentinel** | enemy tank: taunts heroes near it, and has its own Engage | Going around a wall | Marked focus fire, Trapper's roots, flanking placement |
| **Charger** | **Cairn Guardian** | **Rampart Charge** (mana): charges 3 hexes in a line and knocks the first hero back 2 (stunned if they hit someone) | Tank displacement | Space behind Brannoc, Last Watch soaking it |
| **Disruptor** | **Bog Lurker** | **Drag** (mana): hooks the farthest hero and pulls them 2 hexes toward itself, rooted | Back-line safety | Wardweaver's Shields, Brannoc next to the landing spot |
| **Support** | **Gloam Witch** | Shields its allies; **Hush** curse: Silences the hero with the most mana | Target priority and mana heroes | Focus it with Marked, heroes without mana (Last Watch) |

The same archetypes carry over to later acts with new faces.

## 3. Elites

An elite is a **named leader plus a pack, built around one mechanic**, previewed days ahead:

- **The Hound Alpha, "The Hunt":** when any hound Pounces, every hound Pounces on the same hero.
- **The Witch Coven, "Gloam Totem":** a totem on a hex Shields every enemy within 2 hexes until it's destroyed; a Sentinel stands in the way.
- **The Cairn Watch, "Stone Ward":** a Cairn Guardian charges while two Archers fire from behind rocks.

## 4. The boss: Old Mother Ash

| When | What happens |
| --- | --- |
| **Start** | She stands at the back with two Ash Hounds. **Pack Bond:** the pack takes less damage while a hound lives. Both hounds Pounce at the start. |
| **Below 60%: Molt** | She stalks into the middle, and every 10s two Rift Pups crawl in from the arena's edges. |
| **Below 25%: Last Ember** | **Ember Breath** (marked in advance): a cone toward your largest group. **The rift closes early:** the arena starts shrinking at once. |

**What she tests:** protecting the back line, then handling a swarm, then spreading out while the arena shrinks.

## 5. Encounters and scaling

- **Enemy formations are hand-placed**; later encounters add rocks.
- **Early days ask one question each** (a hound pack, a moth cloud).
- **Later days combine two** (a Sentinel holding the line while Archers fire behind it).
- **The harder fight adds a threat** (an extra archetype), not just stats.
- **Stats grow only a little per day.** New enemies and combinations do most of the work.
- **Fights last 30–60s.** The boss's HP is rebuilt from scratch.
- **Target:** a good player clears Act 1 about half the time.

## 6. What it means for the code

- **Enemies become data:** stats, targeting rules, signatures with triggers, traits, and phases (phases already exist).
- **New pieces:** targeting rules ("weakest back-liner", "largest group", "farthest hero"), leaps, pulls, charges, flying over units, marked areas, and **summons** (units joining mid-fight).
- **The fight card** shows each enemy's position, archetype icon, and threat line.

## 7. Later: enemy specializations and upgrades

**Filled in (2026-09-30):** all 9 enemies' specializations, 11 upgrades with numbers, when they show up, rift modifiers, and how the rift learns picks counters are in `enemy-growth.md`. The examples below are kept for reference.

Enemies can grow too, far more narrowly than heroes: each enemy type has **2 specializations** you run into later in a run or in later acts, plus a few **upgrades** (small modifiers, mostly on elites). The same Rift Hound you learned on day 2 shows up changed, and your answer has to change with it.

**Specialization examples:**

| Enemy | Specialization 1 | Specialization 2 |
| --- | --- | --- |
| **Rift Hound** | **Ashback Hound:** its Pounce leaves burning ground where it lands | **Gloam Hound:** after Pouncing, it leaps back out after 3s and Pounces again later |
| **Hollow Archer** | **Pinning Archer:** its shots Root for 0.5s | **Volley Archer:** fires at every hero in a line |
| **Rift-Worn Sentinel** | **Warden Sentinel:** its Engage reaches 2 hexes | **Shattered Sentinel:** when it falls, it bursts and Slows nearby heroes |
| **Bog Lurker** | **Deep Lurker:** Drag pulls 3 hexes | **Rot Lurker:** a dragged hero is Poisoned |

**Upgrade examples:** Frenzied (+attack speed below 50% HP), Warded (starts with a Shield), Swift (+1 movement), Rift-Touched (gains mana 25% faster).

- **Rules:** specializations follow the same idea as hero paths (they change how the enemy plays, not only its numbers), and the fight card always shows them.
- **"The rift learns" (decided: a difficulty modifier):** later enemy specializations are picked to counter what your team leans on. It isn't always on; it's one of the modifiers a higher difficulty adds (section 8). It stays deterministic from the seed plus your team, and it's the one deliberate exception to "offers don't depend on earlier choices".

## 8. Difficulty tiers (meta progression)

Higher difficulties stack modifiers, each unlocked by beating the one before. Modifiers the user named so far:

- **The rift learns:** enemy specializations and upgrades counter your team (`enemy-growth.md`, section 5).
- **Specialized enemies come sooner and more often.**
- **Deeds take longer to fill**, so heroes transform later.
- **Specializations are hidden until the fight starts** (a candidate, the playtester, 2026-10-04; `act2-glassmere.md`, Decision 6): on normal they show on the fight's card the day it's offered.

More come later (the list and order are tuned with playtesting). Meta progression still never adds stats; difficulty only makes the rift harder.

## Open questions

- **Rocks:** hand-placed per encounter, or drawn from a few layouts?