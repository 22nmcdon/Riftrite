# Plan: relics in the combat sim (Phase 3, step 1)

Status: **proposed, awaiting approval and two answers (end of file).**

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
  - items: `tag`, `size`, `applies` (the item applies that status, including through its infusion), `essence` (infused with it)
  - heroes: `row`, `class`
- Filters are allowed on item auras too, so later items can say "adjacent Weapons get +10% crit".
- **Backup heroes:** relic auras reach them too, so their backup effects get the boost. Item auras keep today's rule.

### 2. Grants (new): add an effect to matching items

This is how an Epic relic can reshape a build:

```json
"grants": [ { "filter": {"tag": "weapon"}, "effect": {"trigger": "on_hit", "type": "apply_status", "status": "burn", "stacks": 1} } ]
```

- Every matching item gains that effect for the fight, fired and scaled like the item's own effects.
- The log names the relic: `wren · Rust Hook (Cinder Crown) applies 1 Burn`.
- **Grants never spill** and don't count as essences.

### 3. Relic effects, with new triggers

```json
{ "trigger": "on_fight_start",  "type": "shield", "amount": 10, "scaling": {"def": 5000}, "target": "all_allies" }
{ "trigger": "at_time", "at_ms": 20000, "type": "apply_status", "status": "slow", "stacks": 2, "target": "all_enemies" }
{ "trigger": "on_ally_below_hp", "threshold_bp": 3000, "once": true, "type": "shield", "amount": 20, "scaling": {"def": 10000}, "target": "trigger_ally" }
{ "trigger": "on_fire", "cooldown_ms": 8000, "type": "heal", "amount": 6, "scaling": {"mgk": 2000}, "target": "ally_lowest_hp" }
```

- **New triggers:**
  - `on_fight_start`: at tick 0, before anything fires.
  - `at_time`: once, at `at_ms`.
  - `on_ally_below_hp`: when an ally first drops below `threshold_bp` of max HP while still standing. It's checked once per tick, after firings and before deaths. `once: true` means only the first ally in the fight triggers it; otherwise each ally can trigger it once.
- **On a cooldown:** `on_fire` with the relic's own `cooldown_ms`, like a backup effect. Nothing speeds it up or slows it down (no holder, no Slow).
- **New target `trigger_ally`:** the ally that set off `on_ally_below_hp`.
- **Targets relics can't use:** targets that need a spot on the field (`self`, `hit_target`, the `linked_*` variants, `row_allies`). The checker rejects them.

### Where relic numbers come from (question 1)

A relic has no holder, so `scaling` needs a unit whose stats it reads. My proposal: **it reads the stats of the ally the effect lands on or the ally that triggered it.** For example, a relic shield on each ally is 10 + 50% of *that ally's* DEF. Relic damage, and statuses on enemies, use flat amounts. Stacks are flat anyway, and relic damage should be rare.

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
  "effects": [ { "trigger": "on_ally_below_hp", "threshold_bp": 3000, "once": true, "type": "shield", "amount": 20, "scaling": {"def": 10000}, "target": "trigger_ally" } ],
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
| Warding Knot | Common | The first ally to drop below 30% HP gains a Shield |
| Tinker's Loupe | Common | Small items get −10% cooldown |
| Emberglass | Uncommon | Items that apply Burn: ×1.25 damage over time |
| Vanguard Banner | Uncommon | Front-row allies: ×1.2 DEF |
| Hourglass | Rare | At 20s, every enemy gets 2 Slow |
| Frostbound Sigil | Rare | Items infused with Frost: ×1.2 damage |
| Cinder Crown | Epic | Every Weapon also applies 1 Burn on hit |
| Gloam Totem | Enemy-only | Back-row units: ×1.2 MGK (carried by the witch coven) |

## Tests

- **Data:** reading relics, and rejecting bad ones (no auras, grants, or effects; a bad filter; a field-bound target; `on_fire` without a cooldown; unknown keys).
- **Auras:** each filter picks exactly the matching items or heroes; relic auras reach benched heroes; they stack with item auras.
- **Grants:** matching items gain the effect, scaled from the item's holder; they're logged with the relic's name; they never spill.
- **Triggers:**
  - `on_fight_start` fires once at tick 0.
  - `at_time` fires once, at the right tick.
  - `on_ally_below_hp`: `once` versus once per ally; it doesn't trigger for an ally killed outright.
  - A cooldown relic fires on schedule.
- **Scaling:** relic numbers read from the target or the triggering ally (per question 1).
- **Enemies:** enemy relics work on the enemy side; the encounter's `relics` list loads.
- **Determinism:** the determinism fight includes relics on both sides.
- **Real content:** the draft relics pass the data checker, and the balance runner has a relic party.

## Questions

1. **Relic numbers:** scale from the ally they land on or that triggered them (my proposal), or something else, such as flat amounts that grow by act?
2. **Grants:** is "Epic relics can give matching items a new effect" the kind of build change you want? It's the most powerful new piece here.
