# Proposal: essence rework and percentage boosts

Status: **proposed, awaiting answers.** Nothing here is built yet. This replaces how essences work in build step 4 and comes before step 5 (XP and spill), because spill copies whatever an essence does.

## 1. Two new essences (8 total)

| Essence (proposed name) | Adds | Proposed drops |
| --- | --- | --- |
| **Venom** | Poison | Spiders, serpents, bog things |
| **Wrath** | Attack damage | Berserkers, war-beasts |

Knock-on effects to confirm:
- Alloys go from 21 to **36** (28 cross-pairs + 8 pure doubles). The plan already ships 10 first, so this mostly grows the long-term list.
- Essence resonances go from 6 to 8.
- Biomes still favor two essences each; 8 essences fits 4 biomes cleanly.

## 2. Essences scale from the item's own numbers

Each item's output falls into one of two **families**:

- **Direct:** hit damage, shield, heal
- **Over time:** burn, poison, bleed

Five essences add an output kind: Ember → burn, Venom → poison, Wrath → hit damage, Stone → shield, Verdant → heal.

**The rule (my reading of your message):** whenever the item produces some output, a socketed essence adds its own kind, sized from that output:

| The item's output is... | ...and the essence adds | Result |
| --- | --- | --- |
| the same kind | (e.g. Ember on a burn item) | that output is **50% bigger** |
| the same family, a different kind | (e.g. Stone on a sword: shield from damage) | the essence's kind, worth **50%** of the output |
| direct, and the essence is over time | (e.g. Ember on a sword) | the essence's kind, worth **5%** of the output |
| over time, and the essence is direct | (e.g. Wrath on a burn item) | the essence's kind, worth **500%** of the output |

Worked examples (all four rates are tuning values in `data/tuning.json`):

- Sword hits for 100 + **Ember** → the target also gets 5 burn.
- Torch applies 10 burn + **Ember** → it applies 15 burn instead.
- Sword hits for 100 + **Stone** → the holder gets 50 shield.
- Torch applies 10 burn + **Wrath** → the target also takes 50 damage.
- Healing charm heals 40 + **Verdant** → it heals 60 instead.

Because this reacts to each output as it happens, crits and boosts carry through: a 150-damage crit with Ember adds 8 burn (5% of 150, rounded).

**Where the added output goes (proposed):**
- Added damage, burn, poison, or bleed lands on the enemy the item hit. If the item doesn't hit enemies (like a heal item), it goes to the enemy directly across.
- Added shield goes to whoever the item shields. If the item doesn't shield, it goes to the item's holder.
- Added heal goes to whoever the item heals. If the item doesn't heal, it goes to the ally with the lowest HP percentage.

**Over-time effects become amounts, not fixed stacks:** 1 stack = 1 damage each second. So "5 burn" means 5 stacks, which deal 5 damage in the next second. The data then sets how each one fades (see question 3).

**Unchanged:** Storm (−15% cooldown, a chance to fire twice) and Umbral (+crit chance). Umbral's Bleed-on-crit would follow the rule: bleed worth 5% of the crit's damage.

## 3. Slow and Freeze

- Slow no longer turns into Freeze at 3 stacks.
- Slow lands on **one random item** of the unit that was hit, chosen by the seeded RNG. That item's cooldown slows, not the whole unit's.
- Freeze: see question 4.

## 4. Percentage boosts (tier and hero stats)

- **Base values:** item numbers in data are base values. The fight uses **boosted = base × (100% + the sum of all % boosts)**, rounded once.
- **Boost sources for now:**
  - tier: C +0%, B +50%, A +100%, S +200% (placeholders)
  - hero stats: one boost per output kind (damage, burn, poison, bleed, shield, heal)
- **Basic auto-attacks** get hero boosts but no tier boost.
- **Base vs. boosted:** each item in a fight keeps both values, and can list them with where each boost came from, so the UI can show "Rust Cleaver: 25 damage (base 20, +25% from B tier)".
- **Essence output is boosted too:** it uses the hero stat for its kind, so Ember's burn benefits from a burn boost.

## Build order

1. Percentage boosts and base vs. boosted values (tier + hero stats).
2. Output families and the conversion rule; over-time effects as amounts; Venom, Wrath, and poison.
3. Slow on a random item; Freeze changes.
4. Then the original step 5 (XP, Attuned/Resonant, spill).

## Questions

See the chat summary; answers get recorded in `docs/design.md`.
