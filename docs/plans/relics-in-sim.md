# Plan: relics in the combat sim (Phase 3, step 1)

Status: **built** (Phase 3, step 1). Answers and balance findings are at the end.

Design (docs/design.md, "Relics"):
- The guild holds any number of relics: no board, no slots, no adjacency, no sockets.
- Relics are rare and **change how a build works** rather than adding flat stats. Epic ones change it the most.
- Enemy teams can carry relics too, including enemy-only ones.

Taking and declining relics is run-layer work (step 4); this step is only what relics do in a fight.

## What a relic can do

A relic has **auras** (always on) and **effects** (on triggers). Both reuse the existing vocabulary, plus a few new pieces. Each new piece is a code change, listed here as the design rules require.

### 1. Auras, with filters (new: `filter`)

Relic auras reach **every item or every hero on the relic holder's side**, optionally narrowed by a filter. The filter is what makes a relic build-shaping instead of a flat stat:

```json
{ "target": "all_items", "filter": {"tag": "weapon"},       "stat": "crit_chance_bp", "value": 1000 }
{ "target": "all_items", "filter": {"size": 1},             "stat": "cooldown_bp",    "value": -1000 }
{ "target": "all_items", "filter": {"applies": "burn"},     "stat": "over_time_bp",   "value": 12500 }
{ "target": "all_items", "filter": {"essence": "frost"},    "stat": "damage_bp",      "value": 12000 }
{ "target": "all_allies", "filter": {"row": "front"},       "stat": "def_bp",         "value": 12000 }
{ "target": "all_allies", "filter": {"class": "warden"},    "stat": "atk_bp",         "value": 12000 }
```

- **New target `all_items`:** every item on every hero of that side. `all_allies` already exists.
- **New `filter` field**, with one key per filter:
  - items: `item` (a specific item id), `tag`, `size`, `applies` (the item applies that status, from its own effects, its infusion, or spill), `essence` (infused with it)
  - heroes: `row`, `class`
- Filters are allowed on item auras too, so later items can say "adjacent Weapons get +10% crit".
- **Backup heroes:** relic auras reach them too, so their backup effects get the boost. Item auras keep today's rule.

### 2. Grants (new): add an effect to matching items

This is how an Epic relic can reshape a build:

```json
"grants": [ { "filter": {"tag": "weapon"}, "effect": {"trigger": "on_hit", "type": "apply_status", "status": "burn", "stacks": 1} } ]
```

- Every matching item gains that effect for the fight, fired by the item's own triggers (on_fire, on_hit, on_crit). Its number is flat (see below), and essences don't convert it.
- The log names the relic: `wren · Rust Hook (Cinder Crown) applies 1 Burn`.
- **Grants never spill** and don't count as essences.

### 3. Relic effects, with new triggers

```json
{ "trigger": "on_fight_start",  "type": "shield", "amount": 30, "target": "all_allies" }
{ "trigger": "at_time", "at_ms": 20000, "type": "apply_status", "status": "slow", "stacks": 2, "target": "all_enemies" }
{ "trigger": "on_ally_below_hp", "threshold_bp": 3000, "once": true, "type": "shield", "amount": 80, "target": "trigger_ally" }
{ "trigger": "on_fire", "type": "heal", "amount": 25, "target": "ally_lowest_hp" }
```

- **New triggers:**
  - `on_fight_start`: at tick 0, before anything fires.
  - `at_time`: once, at `at_ms`.
  - `on_ally_below_hp`: when an ally first drops below `threshold_bp` of max HP while still standing. It's checked once per tick, after firings and before deaths. `once: true` means only the first ally in the fight triggers it; otherwise each ally can trigger it once.
- **On a cooldown:** `on_fire` with the relic's own `cooldown_ms`, like a backup effect. Nothing speeds it up or slows it down (no holder, no Slow).
- **New target `trigger_ally`:** the ally that set off `on_ally_below_hp`.
- **Targets relics can't use:** targets that need a spot on the field (`self`, `hit_target`, the `linked_*` variants, `row_allies`). The checker rejects them.

### Relic numbers are flat

- **No `scaling`** on relic effects or grants; the checker rejects it.
- **What can boost them:** only percentage boosts that apply to *everything* of that kind on the side. In the sim that means an aura with target `all_items` and **no filter** (e.g. a relic's "all shields ×1.1"): it boosts every item's output *and* the side's relic effects and grants.
- **Filtered auras don't:** "Weapons deal ×1.2 damage" doesn't boost a Weapon's granted Burn, and neither does the item's tier or its neighbors' auras.
- **Receiver-side boosts** ("shields on this hero +50%") don't exist in the sim yet. When they're added, they'll apply to relic numbers too.

## Order in a tick

- **When relics act:** a side's relic effects resolve after that side's units, in the order the relics are listed: guild units, guild relics, enemy units, enemy relics.
- **Fight start:** `on_fight_start` effects fire at tick 0, before any item. Relic auras apply from the first rederive and show in the log as AURA lines.

## Data shape

`data/relics.json`:

```json
{
  "id": "warding_knot",
  "name": "Warding Knot",
  "rarity": "common",
  "enemy_only": false,
  "auras": [],
  "grants": [],
  "effects": [ { "trigger": "on_ally_below_hp", "threshold_bp": 3000, "once": true, "type": "shield", "amount": 80, "target": "trigger_ally" } ],
  "cooldown_ms": 0
}
```

- **At least one** of auras, grants, or effects is required.
- **`cooldown_ms`** is required only if there's an `on_fire` effect.
- **Setup and encounters:**
  - `FightSetup.relics` and `FightSetup.enemy_relics` are lists of relic ids.
  - `encounters.json` gains an optional `"relics"` list.
  - A side can't hold the same relic twice.
  - Enemy-only relics are allowed on any side in the sim; the run layer decides who can get them.
- **Log source:** `relic · Warding Knot shields wren for 48` for the guild's relics, `enemy relic · Gloam Totem ...` for the enemy's.
- **Balance runner:** parties in `tools/sim_parties.json` gain an optional `"relics"` list, and the damage meter credits relics by name.

## Draft relics (placeholders)

| Relic | Rarity | Does |
| --- | --- | --- |
| Warding Knot | Common | The first ally to drop below 30% HP gains an 80 Shield |
| Tinker's Loupe | Common | Small items get −10% cooldown |
| Kindled Seal | Uncommon | All shields ×1.1 (side-wide, so it boosts relic shields too) |
| Emberglass | Uncommon | Items that apply Burn: ×1.25 damage over time |
| Vanguard Banner | Uncommon | Front-row allies: ×1.2 DEF |
| Hourglass | Rare | At 20s, every enemy gets 2 Slow |
| Frostbound Sigil | Rare | Items infused with Frost: ×1.2 damage |
| Pilgrim's Flask | Rare | Every 8s, heals the ally with the lowest HP% for 30 |
| Cinder Crown | Epic | Every Weapon also applies 1 Burn on hit |
| Gloam Totem | Enemy-only | Back-row units: ×1.2 MGK (carried by the Witch Coven) |

The balance runner has a `hearth_relics` party (the starter party plus Warding Knot, Tinker's Loupe, and Cinder Crown).

## Tests

- **Data:** reading relics, and rejecting bad ones (no auras, grants, or effects; a bad filter; a field-bound target; `on_fire` without a cooldown; unknown keys).
- **Auras:** each filter picks exactly the matching items or heroes; relic auras reach benched heroes; they stack with item auras.
- **Grants:** matching items gain the effect, scaled from the item's holder; they're logged with the relic's name; they never spill.
- **Triggers:**
  - `on_fight_start` fires once at tick 0.
  - `at_time` fires once, at the right tick.
  - `on_ally_below_hp`: `once` versus once per ally; it doesn't trigger for an ally killed outright.
  - A cooldown relic fires on schedule.
- **Flat numbers:** relic numbers ignore stats, tier, and filtered auras; an unfiltered `all_items` aura boosts them.
- **Enemies:** enemy relics work on the enemy side; the encounter's `relics` list loads.
- **Determinism:** the determinism fight includes relics on both sides.
- **Real content:** the draft relics pass the data checker, and the balance runner has a relic party.

## Answers

1. **Relic numbers are flat.** Only percentage boosts that apply to everything of that kind change them (a relic's "all shields +10%", a hero's "shields on this hero +50%").
2. **Grants: yes.** They may later be narrowed to specific combos, such as an enemy team's own item + relic pair that changes an interaction. The `item` filter already allows "only this item".

## Balance findings (placeholders; first run)

Each relic alone on the `hearth_starter` party, 100 fights per encounter (guild win %):

| Relic | Hound Pack | Sentinel's Vigil | Witch Coven |
| --- | --- | --- | --- |
| (none) | 1% | 100% | 0% |
| Warding Knot | 100% | 100% | 0% |
| Tinker's Loupe | 100% | 100% | 0% |
| Kindled Seal | 1% | 100% | 0% |
| Emberglass | 7% | 100% | 0% |
| Vanguard Banner | 18% | 100% | 0% |
| Hourglass | 1% | 100% | 0% |
| Frostbound Sigil | 1% | 100% | 0% (the party has no Frost) |
| Pilgrim's Flask | 86% | 100% | 0% |
| Cinder Crown (Epic) | 100% | 100% | 100% |

- **The Hound Pack is a knife-edge matchup:** almost any edge flips it, as a log comparison shows (Warding Knot's 80 shield keeps Wren alive at 5s, and that decides the fight). The same all-or-nothing matchups were already noted in `docs/plans/phase2-combat-sim.md`; they're an encounter-tuning problem more than a relic one.
- **Cinder Crown** flips the Witch Coven from 0% to 100%. An Epic is meant to reshape a build, but this is probably too strong for one relic; worth revisiting with the Act 1 content pass.
- **Kindled Seal, Hourglass, and Frostbound Sigil** do little for this party, which has few shields, fights ending before 20s matter, and no Frost. That's expected: they're build-shaping.
