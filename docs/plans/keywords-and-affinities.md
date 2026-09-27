# Plan: keywords, affinities, event passives, duo bonds, and conduits (redesign step 5)

Step 5 of `docs/plans/fun-redesign.md`: section 4, and part E of section 5. It also covers `docs/plans/heroes-and-deeds.md`, sections 5 and 6. The user's answers are under **Decisions** at the end.

## 1. Event triggers (new code: new trigger types)

Items can now react to what their holder does. Rule 3 in `CLAUDE.md` says new trigger types need a note; these are needed because no combination of the existing triggers (`on_fire`, `on_hit`, `on_crit`, and the relic ones) can say "when the holder does X".

| Trigger | When | `hit_target` is |
| --- | --- | --- |
| `on_ability` | One of the holder's other abilities fires (optional `"keyword"`: only abilities with it) | nobody |
| `on_basic_attack` | The holder's basic attack fires | nobody |
| `on_holder_crit` | Any of the holder's hits crits | the unit hit |
| `on_shielded` | The holder gains Shield | the holder |
| `on_hit_taken` | An enemy's hit lands on the holder | the attacker |
| `on_heal` | The holder restores HP to an ally | the ally healed |
| `on_status` | The holder applies a status (optional `"statuses"`: only those) | the unit it went on |
| `on_kill` | An enemy the holder hit last falls | nobody |

- **`"every": N`** (any of these): the effect runs on every Nth time the event happens.
- **Timing:** events are read from the combat log each tick, after everything has fired. `on_kill` is read when deaths are processed.
- **No chains:** what an event effect does never sets off another event effect. This is the same rule as for `on_hit`.
- **Who can use them:** any item or slotless ability (so also innates, deeds, and duo bonds), on either side.
- **XP:** event effects don't earn infusion XP. Only fires do, as before.

**Passives can now have effects,** but only event triggers, never `on_fire`. A passive still never fires on a cooldown.

## 2. Passives spread their infusion (the user's pick)

- **What spreads:** an infused passive spreads each of its essences to the holder's other items that share a keyword with it.
- **How strong:** `passive_spread_bp` of the essence's strength at the passive's level: 15% at base, 25% at Attuned, 35% at Resonant (tuning values in `data/tuning.json`). At Resonant that is 7,000 bp, a little more than a normal item's spill (6,000).
- **Passives never spill.** A passive's spread replaces the Resonant spill.
- **Other spill rules still hold:** at most one spill per essence per item, and it stays inside the holder's loadout unless a conduit says otherwise.
- **An alloy on a passive:** it spreads both of its essences, one spill each. Its special works only on the passive itself, once it awakens.

## 3. Conduits (new code: an item field)

A `"conduit"` on a passive changes where its holder's spills go:

| Conduit | Item | Effect |
| --- | --- | --- |
| `basic_attack` | Ember Censer | The holder's spills and spreads also reach its basic attack (the built-in one too), keyword or not |
| `all_abilities` | Open Channel | They reach every ability the holder has, keyword or not |
| `row` | Bond Chain | They also reach the items of the heroes standing in the holder's row, when those items share a keyword |
| `awakened` | Prism | The holder's awakened alloys and pure doubles also spill, as a single would |

## 4. Hero affinities

- **Two keywords per hero:** each hero gets `"affinities"` in `data/heroes.json`, 2 of the 8 keywords.
- **A perk per keyword:** each keyword has an `"affinity"` perk in `data/keywords.json`. It is made of specialization-style parts (usually an aura on the holder's items filtered to that keyword), applied to the hero like an innate, and credited as "Blade affinity".

| Keyword | Perk on the hero's items with it |
| --- | --- |
| Blade | +10% crit chance |
| Bow | ×1.15 damage |
| Spell | ×1.15 damage |
| Mend | ×1.2 healing |
| Ward | ×1.2 Shield |
| Burn | ×1.25 damage over time |
| Bleed | ×1.25 damage over time |
| Hex | cooldowns −10% |

| Hero | Affinities |
| --- | --- |
| Brannoc | Ward, Mend |
| Hesk | Ward, Blade |
| Wren | Blade, Bleed |
| Pell | Hex, Blade |
| Maren | Bow, Bleed |
| Odo | Spell, Hex |
| Ysolde | Spell, Burn |
| Vell | Mend, Ward |

**Shared affinities replace class traits.** Synergy layer `affinity` (always shown) counts the heroes with an affinity. At 2 and at 3 heroes, every hero's items with that keyword get a team bonus. The six class traits and the `class_trait` layer are removed. Classes stay for looks and the bot.

## 5. Duo bonds

- **What they are:** synergy layer `duo`: two specific heroes on the team. It is hidden until found and then saved in the Codex.
- **How they work:** a bond gives each hero its own parts (`"parts"`, each naming its `"hero"`), which can use the new triggers. The log credits the bond by name.
- **Eight bonds,** with each hero in two:

| Bond | Heroes | What it does |
| --- | --- | --- |
| Shield and Sword | Brannoc, Wren | Wren's every 3rd crit shields the lowest-HP ally; Brannoc hits the front enemy when he gains Shield (every 2nd time) |
| The Gate and the Lantern | Vell, Hesk | Vell's heals also give Shield (every 2nd heal); Hesk heals himself when hit (every 4th hit) |
| Ash and Ink | Odo, Ysolde | Odo's Spell abilities set a random enemy alight (every 2nd); Ysolde's every 3rd Burn charges her items |
| Marked Cards | Maren, Pell | Pell's Bow boost for the team; Maren's crits Poison |
| Twin Walls | Brannoc, Hesk | Brannoc's row takes less damage; Hesk's every 3rd hit taken shields his row |
| Hunters' Accord | Wren, Maren | Kills charge Maren's items; kills heal Wren |
| Candle and Page | Vell, Odo | Odo's every 3rd Spell ability heals the lowest-HP ally; Vell's Mend items fire faster for everyone |
| Smoke and Mirrors | Pell, Ysolde | Pell's every 4th status adds Burn; Ysolde's kills Blind every enemy |

The draft shows "shares Blade with Wren" and "a bond: ?" for heroes already picked (`docs/plans/heroes-and-deeds.md`, section 1).

## 6. Content

- **The four conduits** (passives).
- **Six event passives:**
  - Tinder Charm: when a Spell ability fires, 1 Burn on a random enemy
  - Duelist's Bracer: every 3rd crit charges the holder's items
  - Thorn Vest: when hit, damage back to the attacker
  - Drummer's Cadence: every 3rd basic attack, Shield for the holder
  - Leech Vial: a kill heals the holder
  - Hex Bag: every 3rd status also Slows
- **Callings upgraded with the new triggers** (step 3's examples):
  - Hesk: Rebuke becomes Thorns (a hit on him deals damage back)
  - Wren: Keen Edges makes her crits apply Bleed
  - Pell: The House Always Wins applies extra Poison on every 3rd status
  - Ysolde: Firestorm sets every enemy alight when she kills

## 7. Code

- **The sim:**
  - `EffectDef`: the new triggers and `every`
  - `CombatSim`: event dispatch (`Events`, `src/sim/events.gd`), plus kill tracking (`UnitState.last_attacker`)
  - `ItemDef`: passives with event effects, and `conduit`
  - `ItemState`: spread, conduit spill targets
  - `UnitState` / `CombatSim`: Bond Chain across units
- **Data:**
  - `KeywordDef.affinity`
  - `HeroDef.affinities`
  - `SynergyDef`: `affinity` and `duo` layers, `class_trait` removed
  - the tuning value `passive_spread_bp`
- **Setup:** `SetupBuilder` adds affinity parts to a hero, like the innate.
- **UI:**
  - trigger text in item descriptions
  - affinities on draft cards and hero sheets (with "shares ..." and "bond: ?")
  - the synergy panel shows the affinity and duo layers
  - conduit and spread lines in item info
- **Tests:** triggers (each fires, `every` counts, no chains), spread strength by level, each conduit, affinity parts, both synergy layers, and duo bond parts. Then determinism, mutation checks, the balance sim, and the run bot.

## Decisions (from the user, 2026-09-27)

- **Affinity:** a perk per keyword; shared affinities (2 or 3 heroes) give a team bonus, which replaces class traits.
- **An infused passive** spreads its essence to the holder's items that share a keyword, at every level.
- **Duo bonds:** 8, each hero in 2.
- **Snowball rules:** still open.
- **Built directly and reviewed in the PR,** like step 3's content: the trigger list, conduits, perks, bond effects, and calling upgrades.
