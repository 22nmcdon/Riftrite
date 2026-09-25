# Plan: rank-B specializations (Phase 3, step 3)

Status: **proposed, second draft. Awaiting approval and answers (end of file).** Nothing here is built yet.

## The idea

- **Each hero has three specializations of their own,** not shared with their class, and picks one at rank B.
- **Each one is unique to the hero and unlike the other two.** Sometimes it's an ability, sometimes an aura or an effect on their items, much like relics.
- **Locked potential:** each specialization has more power that opens as the hero ranks up. A part unlocks at **A**, and a capstone at **S**. This replaces class-wide rank-up picks.
- **Recruits and retraining:**
  - A hero recruited at B or above comes with a preset specialization and everything it has unlocked by that rank.
  - Retraining (an event) switches to another of the hero's specializations at the same rank.

**What this step covers:** what a specialization does *in a fight*. Picking, presets, and retraining are run-layer work (steps 4 and 5).

## Making them unique: design rules for content

These guide the drafts below:
1. **Three levers per hero.** A hero's three specializations pull different levers. For example: one reshapes their item row (auras, grants), one gives them an ability, and one changes their auto-attack or what they do from backup. Two specializations that both say "+X% to your items" are one too many.
2. **Built from the hero.** Each one leans on the hero's own identity: their stats, basic attack, Backup effect, and signature item.
3. **Unlocks deepen, they don't wander.** The A unlock strengthens or extends the same idea. The S capstone bends a rule (not just "+more").
4. **Readable.** Every effect is logged with the specialization's name, and the UI can show all three ranks with the locked parts greyed out.

## What a specialization can be made of

A specialization is a set of **parts**, each unlocked at a rank. A later rank's part with the same key replaces the earlier one (that's how an ability "gets stronger"); a new key adds. The part kinds:

| Part | What it is |
| --- | --- |
| `aura` | The existing aura vocabulary from the hero: `holder`, `linked_*`, `row_allies`, `all_allies`, `all_items`, and new **`holder_items`** (every item the hero holds, filtered by tag, size, applies, essence, or new **`auto_attack`**) |
| `grant` | An extra effect on the hero's matching items (like a relic grant, but numbered from the hero's stats) |
| `ability` | A slotless effect: on a cooldown, or on a trigger (`on_fight_start`, `at_time`, `on_ally_below_hp`), scaled from the hero's stats |
| `basic_attack` | A new basic attack. **It must come with an `auto_attack` part** (an aura or grant filtered to `auto_attack`) that says what changes when an auto-attack item replaces it, so the specialization never goes blank |
| `backup` | A change to the hero's Backup effect (adds effects or auras to it) |

Every part has **`when`**: `fielded` (default), `benched`, or `always`. That covers specializations that only work on the field, that also work from the bench, or that only work from the bench.

Stat changes are `aura` parts on `holder` (e.g. ×1.2 DEF).

```json
{ "id": "brannoc_hearthwall", "hero": "brannoc", "name": "Hearthwall",
  "parts": {
    "b": [ {"key": "wall", "kind": "aura", "target": "linked_allies", "stat": "def_bp", "value": 11500} ],
    "a": [ {"key": "catch", "kind": "ability", "trigger": "on_ally_below_hp", "threshold_bp": 4000, "once": false,
            "effects": [ {"type": "shield", "amount": 10, "scaling": {"def": 8000}, "target": "trigger_ally"} ]} ],
    "s": [ {"key": "wall", "kind": "aura", "target": "all_allies", "stat": "def_bp", "value": 11500} ]
  } }
```
(Here the S part replaces the B part: the wall now covers every ally, not just the linked ones.)

## Draft content: the four current heroes (placeholders)

| Hero | Specialization | B | A unlock | S capstone |
| --- | --- | --- | --- | --- |
| Brannoc (Warden) | **Hearthwall** (protector) | Linked allies ×1.15 DEF | When an ally drops below 40% HP, he shields them (once each) | The wall covers every ally |
| | **Ironbrand** (auto-attack) | New basic attack: a heavy blow that also shields himself; an auto-attack item gains that self-shield | His auto-attack applies 1 Bleed | Each auto-attack hit charges his other items by 0.2s |
| | **Last Watch** (backup) | Benched: his Backup effect also shields the lowest-HP ally every 6s | Benched: all allies ×1.1 DEF | Benched: from 45s (Rift Collapse), all allies' shields ×1.3 |
| Wren (Striker) | **Duelist** (item row) | Her weapons +10% crit chance | Her weapon crits apply 1 Bleed | Her crits deal ×1.2 damage on weapons |
| | **Windrunner** (auto-attack) | New basic attack: two quick cuts; ×1.2 ATSP; an auto-attack item also gets the ATSP | Her auto-attack charges her Small items by 0.1s | Her auto-attack hits the back row too |
| | **Nightstalker** (ability) | Every 6s, strikes the lowest-HP enemy | The strike applies 2 Bleed | From 20s, the strike's cooldown halves |
| Vell (Mender) | **Lanternbearer** (item row) | Her healing items heal ×1.2 | Her heals also give a small shield | Her Old Lantern-style heals hit two allies (a grant on healing items) |
| | **Wardweaver** (ability) | Every 5s, shields the lowest-HP ally | The ward also cleanses damage over time (needs a cleanse effect; otherwise a bigger shield) | The first ally to drop below 30% gets a big ward |
| | **Vigil Keeper** (backup) | Benched: her Backup heal is ×1.5 | Benched: heals also shield | Always: while she's benched *or* fielded, all allies' healing ×1.15 |
| Odo (Arcanist) | **Pyromancer** (item row) | His Burn items: ×1.25 damage over time | His magic items apply +1 Burn on hit | His Burn never loses more than 1 stack per tick (needs its own status type, like Golden Flame) |
| | **Hexweaver** (auto-attack) | New basic attack: hits every enemy for less; an auto-attack item also applies 1 Poison | His auto-attack applies 1 more Poison | His auto-attack also Blinds (once per 5s) |
| | **Stormcaller** (ability) | Every 6s, damage to every enemy | His magic items fire 10% faster | The storm also charges his items by 0.3s |

The rest of the slice's heroes get theirs in the content step: 8 heroes, so 24 specializations.

## Code shape

- **Definition:** `src/sim/defs/specialization_def.gd`, holding the id, hero, name, and parts by rank. Each part is an `AuraDef`, a `GrantDef`, an ability (read like a `BackupDef`, with triggers allowed), a basic attack (`ItemDef`), or a backup addition, plus `key` and `when`.
- **Setup:**
  - `UnitSetup.specialization` (or null). The sim works out which parts are unlocked from the hero's rank.
  - `SetupBuilder.hero()` takes a specialization id.
  - Balance parties can name one.
- **Checks:**
  - The specialization's hero matches the unit's hero, and rank C has none.
  - A `basic_attack` part needs an `auto_attack` part at the same or an earlier rank.
  - Keys are unique within a rank.
- **In the fight:**
  - **Abilities** become slotless items that fire from the hero (on a cooldown or a trigger).
  - **Auras and grants** go through the existing aura and grant code, with the hero as holder.
  - **`when`** picks which parts apply, depending on whether the hero is fielded or benched.
  - **Backup additions** join the hero's Backup effect.
  - **The log** names the specialization: `brannoc · Hearthwall (A) shields wren for 32`.
- **New vocabulary** (flagged per CLAUDE.md):
  - the `holder_items` aura target and the `auto_attack` filter key
  - ability triggers for heroes (reusing the relic triggers)
  - a hero-side `trigger_ally` target

  Some capstones in the table need more (a cleanse effect, a Burn variant, auto-attacks that reach the back row); those are listed as open, not built here.

## Tests

- **Data:**
  - reading parts and ranks
  - rejecting bad kinds, a `basic_attack` without an `auto_attack` part, duplicate keys, and unknown keys
  - `holder_items` outside a specialization
- **Unlocking:**
  - at B only B parts apply
  - at A the A parts join and same-key parts replace
  - at S the capstone applies
- **`when`:** fielded, benched, and always parts apply at the right times.
- **Auto-attack:** a replaced basic attack works, and an auto-attack item gets the `auto_attack` part instead.
- **Abilities:** they fire on cooldown and on triggers, scale from the hero's stats, and are logged with the specialization's name and rank.
- **Setup checks:** a wrong hero and a rank-C specialization are rejected.
- **Determinism and balance:** the determinism fight includes a specialization with A and S parts, and balance parties can name one.

## Questions

1. **Locked potential instead of class additions:** go with it? (My recommendation: yes; see the reply that came with this draft.)
2. **Draft content:** are the kinds of specializations in the table the right direction for how unique you want them? I'd rather adjust the direction now than after building 24 of them.
3. **Capstones that need new mechanics:** build the few new effects they need in this step (a cleanse effect, Odo's slow-fading Burn as its own status, auto-attacks that reach the back row), or draft capstones from existing blocks first and add those when the content step comes?
