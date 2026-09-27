# Plan: Phase 2 combat sim

Status: **approved; in progress.** **All 9 steps are done** (step 4's essences were reworked along the way; see `docs/plans/essence-rework.md`). Phase 2 is complete apart from balancing; backup in the sim comes next (decided: after Phase 2).

Goal (from the roadmap in `docs/design.md`): a deterministic auto-battle on fixed front/back rows, with no art. It must include essences, alloys, attunement, and spill. Done when a fight can be explained from its log, and the headless runner shows whether alloys feel worth fusing.

## Scope

**In:** front/back rows, items firing on cooldowns, the built-in basic auto-attack and auto-attack items that replace it, in-row adjacency, Linked effects (neighbor in the same row), the 6 essences and their statuses, the 6 alloys already named in the design doc (Steam, Plasma, Glacier, Bloom, Blight, Inferno) plus **Overgrowth** (Verdant + Verdant, doubled spill) as a test of the doubled-spill idea, infusion XP and the Attuned/Resonant levels, spill, Rush/Stall timing, Rift Collapse, the combat log, damage-meter data, the headless runner, and the data validator.

**Out (later phases):** hex arena, relics and the relic board (hero or enemy), drops and loot, named synergies, signature gear, essence resonance counters, class traits, Backup effects, hero ranks and specializations, item tiers and combining, essence transformations, and all UI. The data format leaves room for each of these, but no code gets written for them yet.

## Files

```
project.godot
addons/gut/                  GUT, pinned version (committed so tests run offline)
data/
  tuning.json                spill basis points, XP thresholds and per-battle XP, crit multiplier,
                             Rush/Stall windows, collapse ramp per act, tie time
  essences.json              6 essences: on-hit effects and the spill effect
  alloys.json                recipes (cross-pairs and pure doubles) and effects
  statuses.json              burn, slow, freeze, bleed, blind: tick rate, stacking, duration
  items.json                 player-pool items (about 20 for this phase)
  enemy_items.json           enemy-only items
  heroes.json                4 heroes: class, HP, slot count, own basic auto-attack (no sockets), starting items
  enemies.json               3 enemies: HP, basic auto-attack, fixed item layout (with infusions)
src/sim/
  sim_rng.gd                 the only RNG; seeded; also rolls in basis points
  fixed_math.gd              basis-point math, ms → ticks, the tick rate (a constant, 20/s), and the one rounding rule
  data_reader.gd             typed JSON accessors with path-prefixed errors; flags unknown keys
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
- **Rift Collapse:** starting at 45s, once per second, every living unit on both sides takes flat collapse damage. It hits **Shield first, then HP**, like any other damage.
  - **45–90s:** damage starts at `base` and grows by `growth` each second.
  - **From 90s:** the growth itself goes up by `accel` each second, so the ramp keeps getting steeper.
  - Act 1 values: base 10, growth 10, accel 2. Act 2 doubles all three (20 / 20 / 4). Act 3 is still open. The sim is told which act a fight is in.
  - What that works out to, per unit (Act 1):

    | Time | Damage that second | Total so far |
    | --- | --- | --- |
    | 60s | 160 | 1,360 |
    | 90s | 460 | 10,810 |
    | 120s | 1,690 | 39,180 |
    | 150s | 4,720 | 132,350 |
    | 180s | 9,550 | 344,320 |

    In Act 2 every number is doubled (about 689,000 in total by 180s). With Phase 2 heroes at roughly 300–800 HP, an early stalemate ends around 52–57s. The ~93,000 figure that you said should be common mid- to late-game gets reached at about 2:21 in Act 1, or about 2:04 in Act 2.
- **Tie:** if both sides still have someone standing at **180s**, or both sides are wiped out on the same tick, the fight is a tie, and a tie is a guild victory. The runner reports the tie rate as information, not as a sign that something is broken.
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
  "spill_single_bp": 3000,
  "spill_alloy_bp": 3000,
  "spill_pure_double_bp": 3000,
  "xp_thresholds": [100, 300],
  "xp_per_battle": 10,
  "crit_damage_bp": 15000,
  "collapse_start_ms": 45000,
  "collapse_surge_ms": 90000,
  "collapse_by_act": {
    "1": { "base": 10, "growth": 10, "accel": 2 },
    "2": { "base": 20, "growth": 20, "accel": 4 }
  },
  "tie_at_ms": 180000
}
```

Vocabulary as built in step 2 (`src/sim/defs/effect_def.gd`, `modifier_def.gd`). Every new item should be expressible with these; adding a new one means changing code and saying so. Later steps add what they need (for example `modify_status` for Inferno, `buff_adjacent` for adjacency).
- **Effect triggers:** `on_fire`, `on_hit`, `on_crit`
- **Effect types:** `damage`, `heal`, `shield` (flat `amount` or `amount_bp_of_damage`), `apply_status`
- **Targets:** `hit_target` (on_hit/on_crit only), `self`, `ally_lowest_hp`, `enemy_front`, `enemy_back`, `enemy_random`, `enemy_lowest_hp`, `linked_ally`
- **Modifiers** (passive item stats, basis points): `cooldown_bp`, `crit_chance_bp`, `extra_trigger_chance_bp`
- **Status kinds:** `damage_over_time`, `slow` (with optional stack threshold, used for Frost → Freeze), `freeze`, `blind`
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
- **Timing and collapse:** Rush items stop after 8s, Stall items start at 15s, collapse damage matches the table above for Acts 1 and 2, hits Shield before HP, and hits both sides equally, and reaching 180s or a mutual wipe gives a tie that counts as a win.
- **Auto-attacks:** a hero with no auto-attack item uses their own basic auto-attack; equipping an auto-attack item replaces it; the validator and sim setup reject a loadout with two auto-attack items; the basic auto-attack can't take an infusion.
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

## Built so far: decisions made in code

- **First fire:** an item fires one full cooldown after the fight starts (a 3s item fires at 3.00s, 6.00s, ...).
- **Basic auto-attack** resolves before the unit's row items on the same tick.
- **Downed vs. dead:** a unit at 0 HP stops being a target immediately, but still fires what it had ready that tick; deaths are processed at the end of the tick.
- **Triggers:** on_fire effects run when an item fires; each hit then runs the item's on_hit effects (and on_crit on a crit). Damage from an on_hit/on_crit effect doesn't trigger more on_hit effects, so triggers can't loop.
- **Crits** roll per hit, only when the item has crit chance.
- **Collapse** hits before items fire each second, in resolution order; a unit killed by collapse can still fire that tick.
- **RNG:** xoshiro128**, implemented in GDScript and pinned by tests, so seeds replay across Godot versions.
- **Speed:** about 9 ms per 20-second fight; 1,000 fights in about 10 s.
- **Lowest HP** (heals, `ally_lowest_hp`, `enemy_lowest_hp`) means lowest HP percentage.
- **Essences** fold into the item at fight start: their effects join the item's list (tagged with the essence for the log), and their modifiers change the item's stats. Basic auto-attacks can't hold essences.
- **Status stacks are credited per source:** damage over time is split by who applied each stack, and stacks fall off (or get capped) oldest first.
- **Status damage** hits shield first, like all damage.
- **Slow** sits on items: each application picks one random non-auto-attack item of the target (seeded RNG) plus its auto-attack, and stretches those cooldowns (progress is tracked in basis points of a tick, so partial slows are exact). **Freeze** pauses all of a unit's cooldowns; nothing applies it yet. Slow caps at 100% per item.
- **Blind** makes the blinded unit's next hit of any kind miss (no damage, no on_hit effects).
- **Storm's extra fire** happens immediately after the normal fire, doesn't reset the cooldown, and can't chain.
- **Tick order is now:** collapse, statuses, cooldowns, firing, deaths, end check.

### Step 5 (XP, levels, spill)

- **Levels scale everything an essence does:** its conversion rate, its same-kind bonus, its modifiers, and its effects (Attuned x1.5, Resonant x2 as placeholders). So Attuned Wrath on a sword is x1.75 instead of x1.5, and Attuned Storm cuts cooldowns by 22.5%.
- **Level-ups happen mid-fight.** Fire XP is added right after each fire (extra Storm fires count too); crossing a threshold levels the infusion up at once and re-derives the holder's row. The per-battle XP is added after the fight ends and can level an infusion up "after the fight".
- **The fight reports each infused item's XP and level before and after**; the run layer keeps it.
- **Spill = 30% of the Resonant-strength effect** (so 0.6x the base essence), to both row neighbors. The basic auto-attack is not in the row, so it never gives or gets spill. Spill never crosses to another unit.
- **Small numbers don't round away:** essence effects (like Frost's 1 Slow) and conversions carry fractions between uses, so a 1.5-stack Slow lands 1, 2, 1, 2.
- A re-derive (level-up) keeps cooldown progress and Slow, but restarts fractional carries.

### Step 6 (alloys)

- `data/alloys.json` lists named alloys by unordered recipe. Built: Inferno, Plasma, Blight, Bloom.
- New data-driven mechanics (code changes, per CLAUDE.md rule 3): alloy `replaces` (swap a status for its alloy version) and `heal_echo_bp`; status `cleanse_effectiveness_bp`, `jumps`, and `heal_team_bp`.
- **Plasma jumps** to the nearest other standing enemy (column distance, +1 for the other row), moving all its stacks; it stays put if there's nobody else.
- **Blight's heal** splits the damage evenly across the applier's living team.
- **Bloom's echo** goes to a random other living ally (seeded RNG); echoes don't echo. Alloy specials don't scale with infusion level (the essences' parts do).
- **Alloy spill:** first socket's essence left, second's right (30% of Resonant); pure doubles spill their essence once to each side. The special never spills, so Plasma's spilled Ember is plain Burn.

### Step 7: time windows, auras, area targets, Linked (approved and built)

Rush/Stall behavior is per item, so step 7 adds building blocks instead of one fixed rule.

**1. Time windows on any effect.** `"window": {"from_ms": 0, "until_ms": 8000}` means the effect only happens during that part of the fight (either end optional).
- Rush dagger, 2x damage for 8s: `{"amount": 20, "window": {"until_ms": 8000}}` plus `{"amount": 10, "window": {"from_ms": 8000}}`.
- Stall tome that sleeps until 15s: its effects get `"window": {"from_ms": 15000}`.

**2. Auras: continuous boosts while their window is open.** A new item field, `"auras": [...]`, each entry `{target, stat, value, window?}`:
- Targets: `self_item`, `left_item`, `right_item`, `adjacent_items`, `row_items`, `holder`, `linked_allies`, `all_allies`.
- Item stats: `damage_bp`, `heal_bp`, `shield_bp`, `over_time_bp` (multipliers, like tier), `crit_chance_bp`, `cooldown_bp` (added, like essence modifiers).
- Unit stats: `atk_bp`, `mgk_bp`, `def_bp`, `atsp_bp`, `crit_bp` (multipliers on the holder's or allies' stats).
- Examples: "adjacent items get +20% crit": `{"target": "adjacent_items", "stat": "crit_chance_bp", "value": 2000}`. "Defense x2 for 8s": `{"target": "holder", "stat": "def_bp", "value": 20000, "window": {"until_ms": 8000}}`.
- Auras show in the base/final breakdown (for example "x2 Rush (Dagger)"), and items re-derive when a window opens or closes.

**3. Area targets:** `all_enemies` and `all_allies`, for effects. Each target is a separate hit or heal.

**4. Linked:** `linked_allies` means the units directly left and right of the holder in the same row. Effects can target them, and auras can boost them (and their items).

**5. Rush/Stall stay labels.** The item's `timing` field stays, for the shop and synergies; windows and auras do the work.

**As built:** aura multipliers multiply and crit/cooldown add (confirmed). Linked comes in variants per item (confirmed): `linked_ally` (left, else right), `linked_left_ally`, `linked_right_ally`, `linked_allies`, `row_allies`. Auras stop when their holder falls. Everything re-derives at fight start, when an aura window opens or closes, after a death, and after an infusion level-up. The log records each aura starting and ending.

### Steps 8–9: balance runner and draft content

- **Draft content** (placeholders for the designer to replace): 4 heroes (Brannoc the Warden, Wren Ashfoot the Striker, Sister Vell the Mender, Odo Quillmire the Arcanist), 20 hero items plus 3 enemy-only items, 3 enemies (Rift Hound, Rift-Worn Sentinel, Gloam Witch), and 3 Act 1 encounters. Files: `data/items.json`, `heroes.json`, `enemies.json`, `encounters.json`.
- **Heroes** get item slots from rank (4 at C, +1 per rank). **Enemies** have fixed layouts with infusions; encounter units are numbered in the log (`rift_hound_1`).
- **Runner:** `tools/sim_runner.gd` runs the parties in `tools/sim_parties.json` against each encounter and reports win rate (ties count as wins), fight length, biggest hit, infusion level-ups, per-item damage/healing/shielding per fight with share of the party's output, and flags items under 3% of output.
- `DamageMeter` builds per-item totals from the combat log.

**Findings from the first runs** (these shaped the draft numbers):
- **Damage-over-time scale:** one Burn stack is worth about 20 damage, so the first draft's torch (4+ stacks per fire) did a third of all damage. Items that apply damage over time now apply 1 stack plus a small share of MGK.
- **Stall needs long fights:** with the first draft, fights ended before 15 s and the Stall tome never fired. Tuned fights now last 12–50 s.
- **Outcomes are nearly all-or-nothing** for a given matchup (little randomness: only crits, random targets, Storm, and Slow's item choice). Worth deciding whether fights should be swingier.
- **Infusions and rank are big:** the infused party and the rank-B party win matchups the plain starter loses.
- **Aura items look weak in the meter** because their boosts show up in other items' numbers, not their own. A future meter could credit aura contributions to the aura's item.

## Needs your call before coding

Confirmed: targeting (front row first), same-tick deaths still fire, HP-only heroes, per-item crit chance starting at 0 with 150% crits, no time limit, a tie at 180s or on a mutual wipe counts as a victory, collapse hits Shield before HP, and the collapse ramp above (numbers still to be tuned).

Also confirmed: each hero has their own basic auto-attack, which can't be upgraded, and a hero can equip at most one auto-attack item.

Nothing blocks coding. Act 3 collapse numbers are only needed once Act 3 content exists.
