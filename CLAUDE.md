# CLAUDE.md

## Project

A PvE roguelite auto-battler (working title **Riftrite**, a placeholder). The player leads a guild of heroes through branching rift maps. Each hero has a row of items that fire on cooldowns, and items are infused with essences harvested from enemies. Hidden, discoverable synergies drive build variety.

**The full design lives in `docs/design.md`.** Before building or changing a game system, read the matching section there. If the code and the design doc disagree, stop and ask. Don't silently pick one.

## Tech stack

- Engine: Godot 4.x, GDScript (static typing everywhere: `var hp: int`, typed function signatures)
- Tests: GUT (Godot Unit Test)
- Game data: JSON files in `data/`, loaded at startup and validated
- **Pinned versions:** Godot `TBD`, GUT `TBD`. Set the exact versions when the project is created. Upgrade either one only on purpose, in its own change, and rerun the determinism tests afterward.

## Commands

<!-- Update these once the project is set up -->
- Run the game: `godot --path .`
- Run all tests: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
- Headless balance sim: `godot --headless --path . -- --sim --fights=1000 --seed=1`

## Folder layout

```
data/          items, essences, alloys, relics, heroes, enemies, synergies (JSON)
docs/          design.md and other design notes
src/sim/       combat simulation: pure logic, NO nodes, NO rendering
src/run/       map, nodes, shop, forge, economy
src/meta/      Guildhall, unlocks, codex, save data
src/ui/        scenes and UI scripts (reads sim state, never changes it)
tests/         GUT tests, mirroring src/
tools/         headless sim runner, data validators
```

## Rules the code must never break

1. **The combat sim is deterministic.** Same seed + same inputs = same fight, every time. Use only the sim's seeded RNG (never `randi()`, `randf()`, or unseeded RandomNumberGenerator). Use a fixed timestep, not frame delta. Never iterate a Dictionary where order affects the outcome.
   - **Integer math only in `src/sim/`.** No `float`: HP, damage, shields, and stats are `int`; percentages are basis points (`10000` = 100%); time is ticks at a fixed **20 ticks per second**. Data files give durations in milliseconds, and the loader converts them to ticks. Round with explicit integer division, in one shared helper.
2. **The sim is separate from presentation.** `src/sim/` never references nodes, scenes, animations, or UI. The UI plays back events the sim emits.
3. **Content is data, not code.** New items, essences, alloys, relics, and synergies are added as JSON entries using existing effect/trigger types. Only add a new effect type in code when no combination of existing ones can express it, and say so when you do.
4. **Every combat effect writes to the combat log** with its source (hero, item, infusion, synergy). If a player can't trace why something happened, it's a bug.
5. **Meta progression never adds stats.** Unlocks add variety (items, heroes, alloys into the pool), cosmetics, and codex entries only.

## Infusion rules (easy to get wrong)

- Small items: 1 socket. Medium/Large items: 2 sockets. Relics: 1 socket.
- Two different essences in one item = an **Alloy** with its own effect. Two of the same = a **pure double**.
- Pure doubles are alloys too, and each has its own effect.
- Infusions level up: base → Attuned → Resonant. XP comes from **item fires** (XP per fire is set per item in data, based on type and size; auto-attacks get less) **plus each battle fought**.
- XP **resets** when a second essence is added (single → alloy or pure double) and when an infusion is removed.
- Only **Resonant** infusions spill to neighbors:
  - Single essence: partial effect (~30%) to **both** sides
  - Alloy: first essence's partial effect to the **left**, second's to the **right**, each at the single-essence strength (its own tuning value, currently equal to the single's); the alloy effect itself never spills
  - Pure double: the base essence's partial effect (~30%) to both sides. Its bonus effect never spills and never strengthens the spill. The one exception is a pure double whose alloy effect *is* "doubled spill."
  - Essence transformation: **never** spills
- Item spills stay inside that hero's row. Relic spills stay on the relic board, never reaching hero items.
- Spill percentages and XP thresholds are tuning values in `data/`, never hard-coded.
- Essence resonance counts **essences**, not items: a single = 1, an alloy = 1 of each half, a pure double = 2, and a transformation counts its socketed essence(s). Relics count too.

## Item rules

- The auto-attack is an item in the row and **takes up a slot**.
- **Two** copies of the same item at the same tier combine into the next tier (never three). If the new copy has an infusion, it replaces the old one (and the old XP is lost); if not, the old infusion and its XP stay. The player chooses whether to combine.
- Enemies use hand-made, fixed item layouts built from the same item system; some items are enemy-only.

## Other core rules

- Items are per hero; the relic board is shared by the team. Items can move between heroes freely between fights (never during combat).
- Roster cap 6, fielded heroes 3–5. Benched heroes' Backup effects still apply.
- Rift Collapse starts at 45s of combat; fights should end by ~60s.
- Formation for now: each side has fixed **front and back rows**, ordered left to right. The hex arena comes later, so don't build hex code until asked.
- PvE only. Don't add networking or PvP code.

## How to work in this repo

- For any new system, propose a plan first (files, data shape, tests) and wait for approval before writing code.
- Write or update tests for sim logic in the same change. Determinism tests (run a seeded fight twice, compare logs) must keep passing.
- Keep changes small and focused. Don't refactor unrelated code.
- When adding content, validate the JSON with `tools/` before finishing.
- If a design question isn't answered in `docs/design.md`, ask instead of inventing an answer. Then note the answer in the design doc. Unanswered questions live under **Open questions** in `docs/design.md`.

## Tone and naming

The setting mixes cozy and grim: a warm Guildhall and dark rifts. Content names should fit that. Don't use names, characters, or items from Guildrun, The Bazaar, or Enter the Gungeon.
