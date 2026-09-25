# Plan: unit stats, item scaling, and the essence rework

Status: **built** (all three build steps below). Numbers are placeholders for the balance sim to tune. This replaces how essences work in build step 4 and comes before step 5 (XP and spill), because spill copies whatever an essence does.

## Decided

### Essences (8 total)

| Essence | Adds | Notes |
| --- | --- | --- |
| Ember | Burn | |
| **Venom** (new) | Poison | Drops from spiders, serpents, bog things (proposed) |
| **Wrath** (new) | Attack damage | Drops from berserkers, war-beasts (proposed) |
| Stone | Shield | |
| Verdant | Heal | |
| Frost | Slow | See Slow below |
| Storm | −15% cooldown, a chance to fire twice | Unchanged |
| Umbral | +crit chance; crits apply Bleed | Bleed sized by the conversion rule |

This takes alloys from 21 to 36 (28 cross-pairs + 8 pure doubles), and essence resonances from 6 to 8. Both are OK.

### The conversion rule

Output kinds come in two families. **Direct:** hit damage, shield, heal. **Over time:** burn, poison, bleed.

Whenever an item produces output, an essence that adds a kind (Ember, Venom, Wrath, Stone, Verdant) adds its kind, sized from that output:

| The essence's kind vs. the item's output | Added |
| --- | --- |
| Same kind (Ember on a burn item) | The output is 50% bigger |
| Same family, other kind (Ember on a poison dagger) | 50% of the output, as the essence's kind |
| Item direct → essence over time (Ember on a sword) | 5% of the output |
| Item over time → essence direct (Wrath on a burn item) | 500% of the output |

All four rates are tuning values.

**Where the added output goes:**
- **Added damage, burn, poison, bleed:** the enemy the item hit. If the item doesn't hit anyone, the essence needs a different behavior (see question 1).
- **Added shield:** whoever the item shields; otherwise the item's holder.
- **Added heal:** whoever the item heals; otherwise the item's holder. A weapon with Verdant heals only its holder, never teammates.

### Damage over time

Over-time effects are amounts: stacks, where each stack deals damage every second (`damage_per_stack` per status, so Burn can hit harder per stack).

| Status | Fades? | Shields | Special |
| --- | --- | --- | --- |
| **Burn** | Fast | Weaker against shields than HP | Strongest per stack |
| **Poison** | Never | Ignores shields (straight to HP) | |
| **Bleed** | Never | Hits shields normally | Lowers the target's defense by its stack count |

### Slow, Freeze, Stun

- Frost's Slow lands on **one random item** of the unit that was hit, and **also slows that unit's auto-attack**.
- Slow no longer turns into Freeze. No essence applies Freeze. Later, items and heroes can Freeze or Stun.

### Boosts multiply

Percentage boosts multiply together: B tier (×1.5) with a +20% bonus gives ×1.8. Tier placeholders: C ×1, B ×1.5, A ×2, S ×3.

### Unit stats and item scaling

Heroes (and enemies) have six stats: **HP, ATK (attack), MGK (magic), DEF (defense), CRIT, ATSP (attack speed)**.

An item's numbers are a small base amount plus multipliers on those stats. For example, a dagger's hit might be `4 + 60% of ATK + 20% of ATSP`. Then the item's multiplicative boosts (tier, and later infusion level, relics, synergies) apply on top. Basic auto-attacks scale the same way, but have no tier.

Every item in a fight keeps its base values, its stat-scaled values, and its final values, so the UI can show the breakdown.

## Decided in round 3

- **Damage essences on items that don't hit** (Ember, Venom, Wrath, and Umbral's Bleed on a heal or shield item): designer's call per item later; items might boost stats, buff neighbors or the team, or deal damage in new ways. **For now:** the added damage or damage over time lands on the enemy directly across from the holder. Easy to change once real items exist.
- **Hero ranks boost stats by 25% per rank**, compounding like all boosts: C ×1, B ×1.25, A ×1.5625, S ×1.953. Enemies use the same table for their tiers.
- **Burn** ticks twice a second and loses 5% of its stacks each tick (rounded up, so at least 1). It does half damage to shields.
- **Scaling by rarity:** Common, Uncommon, and Rare items (and basic auto-attacks) scale only from HP, ATK, MGK, and DEF. ATSP and CRIT act only as rates for them. Epic and Legendary items may also scale from ATSP and CRIT, and can scale more steeply.
- **Healing weakens damage over time:** each heal that restores HP removes 10% of the healed unit's Burn, Poison, and Bleed stacks (tuning value). This is a first attempt at taming the runaway numbers.
- The stat-rule defaults below were not objected to, so they're built as placeholders.

## Defaults being built (placeholders)

These fill gaps so building can start. Each is a tuning value or an easy switch.

- **Stat scale:** all six stats are whole numbers. A C-rank hero is roughly HP 300, ATK/MGK 10–30, DEF 0–30, CRIT 0–10, ATSP 0–20.
- **DEF:** hit damage is multiplied by `100 / (100 + DEF)`. So DEF 100 halves hits, and nothing ever becomes immune. It applies to hits only: DoTs and Rift Collapse ignore DEF. That makes Bleed's DEF shred pay off for your *other* attacks.
- **Bleed shred:** can't take DEF below 0.
- **CRIT:** each point adds +1% crit chance to all of the unit's items, on top of each item's own crit chance.
- **ATSP:** each point makes the unit's auto-attack (basic or item) fire 1% faster. Other items keep their own cooldowns.
- **Burn vs. shields:** Burn does 50% damage to shields. Once the shield is gone, the rest hits HP at full strength.
- **Burn fading:** Burn loses a third of its stacks each second (rounded up, so at least 1).
- **Per-stack damage:** Burn 2 damage per stack per second, Poison 1, Bleed 1 (placeholders).
- **Slow:** each Slow stack makes its item (and the auto-attack) 10% slower. Slow lasts 3s, and each new Slow refreshes the timer. If the hit unit has no items besides its auto-attack, only the auto-attack gets slowed.

## Pushback

1. **Scaling off ATSP and CRIT double-dips.** ATSP already makes a dagger fire faster, and CRIT already makes it crit more. If the dagger's damage *also* scales with ATSP, ATSP counts twice. Allowing it is fine if you want fast-attack builds to snowball; the balance sim will show it. The alternative is to let damage scale only from HP/ATK/MGK/DEF, and treat ATSP and CRIT purely as rates.
2. **Verdant on a weapon is 50% lifesteal.** Damage and heal are the same family, so a sword with Verdant heals its holder for half its damage. That's strong. It may need its own rate, separate from the 50% "same family" default.
3. **Poison and Bleed never fading + multiplicative boosts = runaway numbers.** That's intended ("crazy numbers could be fun"). The balance sim will report the biggest single fights so we can see where it goes.
4. **Damage essences on items that don't hit.** Ember, Venom, Wrath, and Umbral's Bleed need a behavior for heal and shield items (question 1). Until that's designed, I propose they do nothing on those items, and the balance sim lists every such case so none get missed.

## Build order

1. Unit stats (HP, ATK, MGK, DEF, CRIT, ATSP), item scaling, and multiplicative boosts, with base/scaled/final values per item.
2. Output families and the conversion rule. Venom and Wrath, and Burn/Poison/Bleed as amounts with their new rules.
3. Slow on a random item plus the auto-attack. Freeze stays in data for items to use later.
4. Then the original step 5 (XP, Attuned/Resonant, spill).
