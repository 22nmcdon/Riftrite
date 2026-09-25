# Plan: Phase 2 combat sim

Status: **proposed, awaiting approval.** Nothing here is built yet. Targeting, same-tick deaths, and HP-only stats were confirmed in round 2; the collapse and tie rules were revised then too.

Goal (from the roadmap in `docs/design.md`): a deterministic auto-battle on fixed front/back rows, with no art. It must include essences, alloys, attunement, and spill. Done when a fight can be explained from its log, and the headless runner shows whether alloys feel worth fusing.

## Scope

**In:** front/back rows, items firing on cooldowns, the auto-attack as an item, in-row adjacency, Linked effects (neighbor in the same row), the 6 essences and their statuses, the 6 alloys already named in the design doc (Steam, Plasma, Glacier, Bloom, Blight, Inferno) plus **Overgrowth** (Verdant + Verdant, doubled spill) as a test of the doubled-spill idea, infusion XP and the Attuned/Resonant levels, spill, Rush/Stall timing, Rift Collapse, the combat log, damage-meter data, the headless runner, and the data validator.

**Out (later phases):** hex arena, relics and the relic board (hero or enemy), drops and loot, named synergies, signature gear, essence resonance counters, class traits, Backup effects, hero ranks and specializations, item tiers and combining, essence transformations, and all UI. The data format leaves room for each of these, but no code gets written for them yet.

## Files

```
project.godot
addons/gut/                  GUT, pinned version (committed so tests run offline)
data/
  tuning.json                tick rate, spill basis points, XP thresholds and per-battle XP, crit multiplier,
                             Rush/Stall windows, collapse start/base damage/growth, tie time
  essences.json              6 essences: on-hit effects and the spill effect
  alloys.json                recipes (cross-pairs and pure doubles) and effects
  statuses.json              burn, slow, freeze, bleed, blind: tick rate, stacking, duration
  items.json                 player-pool items (about 20 for this phase)
  enemy_items.json           enemy-only items
  heroes.json                4 heroes: class, HP, slot count, auto-attack item
  enemies.json               3 enemies: HP, fixed item layout (with infusions)
src/sim/
  sim_rng.gd                 the only RNG; seeded; also rolls in basis points
  fixed_math.gd              basis-point math, ms → ticks, and the one rounding rule
  content_db.gd              loads and validates JSON into typed definitions (no nodes)
  defs/*.gd                  typed definition classes (ItemDef, EssenceDef, ...)
  state/unit_state.gd        runtime unit: HP, shield, statuses, side, row, index
  state/item_state.gd        runtime item: cooldown, infusion, XP, level
  state/infusion_state.gd    essences, alloy id, XP, level
  effects/effect_runner.gd   runs one effect and writes the log entry
  effects/targeting.gd       target selection rules
  statuses.gd                applying statuses and ticking them
  spill.gd                   works out what spills to each item's neighbors
  combat_sim.gd              setup, the per-tick loop, end conditions
  combat_log.gd              typed log entries and per-item totals for the damage meter
tools/
  sim_runner.gd              headless: --sim --fights --seed [--matchup]
  validate_data.gd           runs the content_db validation and exits non-zero on errors
tests/sim/                   one test file per src file, plus test_determinism.gd
```

## How a fight runs

- **Fixed timestep:** 20 ticks per second.
- **Rift Collapse:** starting at 45s, once per second, every living unit on both sides takes flat collapse damage. It starts at **10** and grows by **10** each second (10, 20, 30, ...), so by 60s it is 160 per second and has dealt 1,360 in total. With Phase 2 heroes at roughly **300–800 HP**, a fight nobody is winning ends around 52–57s. All three numbers are tuning values.
- **Tie:** if both sides still have someone standing at **180s**, the fight ends as a tie, and a tie is a guild victory. The runner reports how many fights end this way, since a build that reaches 3 minutes is surviving about 93,000 collapse damage and is probably broken.
- **Deterministic order:** heroes, then enemies; front row before back row; left to right; and within a unit, items left to right. The order never comes from Dictionary iteration.
- **Each tick:**
  1. Apply the time-based rules: Rush ends at 8s, Stall wakes at 15s, and Collapse damage starts at 45s.
  2. Tick statuses (burn and bleed deal damage; slow, freeze and blind count down).
  3. Count down each item's cooldown and collect every item that fires this tick.
  4. Resolve all of those firings in the order above. **Deaths wait until the end of the tick**, so a unit killed this tick still gets the attacks it had ready. That way hero-first ordering doesn't give the heroes an edge.
  5. Remove dead units; then check for a win, a loss, or a tie (both sides wiped out on the same tick, or 180s reached).
- **Firing an item:** run its effects, then its infusion's on-hit effects, then any spill it receives from its neighbors. Then add XP and check for a level-up. Every step writes a log entry.

## Data shape (examples)

Durations are in milliseconds and percentages in basis points. Every number is an integer.

```json
// items.json
{
  "id": "rust_hook",
  "name": "Rust Hook",
  "size": 1,
  "tags": ["weapon"],
  "cooldown_ms": 3000,
  "crit_chance_bp": 0,
  "xp_per_fire": 4,
  "timing": "normal",
  "effects": [
    { "type": "damage", "amount": 14, "target": "enemy_front" }
  ]
}

// essences.json
{
  "id": "ember",
  "on_hit": [ { "type": "apply_status", "status": "burn", "stacks": 1 } ],
  "attuned_scale_bp": 15000
}

// alloys.json
{ "id": "steam",   "recipe": ["ember", "frost"], "effects": [ { "type": "apply_status", "status": "blind", "stacks": 1 } ] }
{ "id": "inferno", "recipe": ["ember", "ember"], "effects": [ { "type": "modify_status", "status": "burn", "never_expires": true } ] }

// tuning.json (excerpt)
{
  "ticks_per_second": 20,
  "spill_single_bp": 3000,
  "spill_alloy_bp": 3000,
  "spill_pure_double_bp": 3000,
  "xp_thresholds": [100, 300],
  "xp_per_battle": 10,
  "crit_damage_bp": 15000,
  "collapse_start_ms": 45000,
  "collapse_base_damage": 10,
  "collapse_growth_per_second": 10,
  "tie_at_ms": 180000
}
```

Starting vocabulary. Every new item should be expressible with these; adding a new one means changing code and saying so.
- **Effect types:** `damage`, `heal`, `shield`, `apply_status`, `modify_status`, `modify_cooldown`, `buff_adjacent`, `extra_trigger_chance`
- **Targets:** `enemy_front`, `enemy_back`, `enemy_random`, `enemy_lowest_hp`, `ally_lowest_hp`, `self`, `linked_ally`
- **Timing:** `normal`, `rush`, `stall`

## Combat log entry

```
{ tick, kind, source: { unit, item, infusion?, alloy?, via_spill_from? }, target, amount, detail }
```

Every effect, status tick, level-up, spill, and death writes one entry. The damage meter is built from the log, never counted separately, so the two can't disagree.

## Tests

- **Determinism:** run the same seeded fight twice and check the logs match exactly. Also check that a different seed gives a different log in a fight that uses RNG.
- **Cooldowns:** an item with a 3000ms cooldown fires on ticks 60, 120, ...; Storm cuts the cooldown by 15%; freeze pauses cooldowns.
- **Targeting:** the front row is targeted before the back row; Linked reaches only the neighbor in the same row.
- **Statuses:** burn and bleed deal their damage; 3 frost stacks freeze for 1s; blind makes the next attack miss.
- **Infusion XP:** XP from fires plus the per-battle amount; the level-up thresholds; XP resets when a second essence is added.
- **Spill:** a single spills to both sides, an alloy splits left/right, a pure double spills to both sides, a transformation-flagged infusion never spills, spill never leaves the hero's row, and spill only happens at Resonant.
- **Alloys:** each of the 6 alloys resolves its effect and logs its source.
- **Timing and collapse:** Rush items stop after 8s, Stall items start at 15s, collapse damage is flat and grows by the set amount each second from 45s, collapse hits both sides equally, and reaching 180s or a mutual wipe gives a tie that counts as a win.
- **Crit:** an item with 0 crit chance never crits; an item at 10000 always crits for 150% damage; Umbral adds crit chance.
- **Log sources:** every damage/heal/shield entry has a unit and an item, plus an infusion or alloy when one is involved.
- **Content:** every file in `data/` passes the validator (all ids resolve, all numbers are integers, alloy recipes are valid).

## Build order (each step is one small change with its tests)

1. Project skeleton: `project.godot`, the pinned GUT, one passing test, and a setup hook so Godot is installed in cloud sessions (so tests can run here).
2. `content_db` and the validator, with `tuning.json`, `statuses.json`, and `essences.json`.
3. Sim core: RNG, ticks, units, cooldowns, damage, targeting, collapse, the log, and the determinism test.
4. Essences and statuses.
5. Infusion XP, the Attuned/Resonant levels, and spill.
6. Alloys and pure doubles.
7. Rush/Stall, adjacency buffs, and Linked.
8. Headless runner and damage-meter report (win rate, average fight length, damage share per item, items that barely contribute, fights that end in a tie).
9. Content: 4 heroes, about 20 items, 3 enemies with fixed layouts.

## Needs your call before coding

Confirmed: targeting (front row first), same-tick deaths still fire, HP-only heroes, per-item crit chance starting at 0 with 150% crits, no time limit, 180s tie = victory, and flat, growing collapse damage.

Still open (proposed defaults):

1. **Collapse vs. shields:** collapse damage **goes straight to HP, ignoring shields**. Otherwise a Stone/Glacier shield-refresh build could stall to 180s and win by a tie.
2. **Mutual wipe:** if both sides die on the same tick, that's a **tie, which counts as a victory**, the same as reaching 180s.
3. **Collapse numbers:** 10 damage per second at 45s, growing by 10 each second, with Phase 2 heroes at about 300–800 HP. These are easy to change in `tuning.json`.
