# CLAUDE.md

## Project

A PvE roguelite auto-battler (working title **Riftwright**, a placeholder). The player leads a guild of heroes through branching rift maps. Each hero has a row of items that fire on cooldowns, and items are infused with essences harvested from enemies. Hidden, discoverable synergies drive build variety.

**The full design lives in `docs/design.md`.** Before building or changing a game system, read the matching section there. If the code and the design doc disagree, stop and ask. Don't silently pick one.

## Tech stack

- Engine: Godot 4.x, GDScript (static typing everywhere: `var hp: int`, typed function signatures)
- Tests: GUT (Godot Unit Test)
- Game data: JSON files in `data/`, loaded at startup and validated

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
2. **The sim is separate from presentation.** `src/sim/` never references nodes, scenes, animations, or UI. The UI plays back events the sim emits.
3. **Content is data, not code.** New items, essences, alloys, relics, and synergies are added as JSON entries using existing effect/trigger types. Only add a new effect type in code when no combination of existing ones can express it, and say so when you do.
4. **Every combat effect writes to the combat log** with its source (hero, item, infusion, synergy). If a player can't trace why something happened, it's a bug.
5. **Meta progression never adds stats.** Unlocks add variety (items, heroes, alloys into the pool), cosmetics, and codex entries only.

## Infusion rules (easy to get wrong)

- Small items: 1 socket. Medium/Large items: 2 sockets. Relics: 1 socket.
- Two different essences in one item = an **Alloy** with its own effect. Two of the same = a **pure double**.
- Infusions gain XP when their item fires: base → Attuned → Resonant.
- Only **Resonant** infusions spill to neighbors:
  - Single essence: partial effect (~30%) to **both** sides
  - Alloy: first essence's partial effect to the **left**, second's to the **right**; the alloy effect itself never spills
  - Pure double: stronger partial effect (~50%) to both sides
  - Essence transformation: **never** spills
- Item spills stay inside that hero's row. Relic spills stay on the relic board, never reaching hero items.
- Spill percentages are tuning values in `data/`, never hard-coded.

## Other core rules

- Items are per hero; the relic board is shared by the team. Items can move between heroes freely between fights (never during combat).
- Roster cap 6, fielded heroes 3–5. Benched heroes' Backup effects still apply.
- Rift Collapse starts at 45s of combat; fights should end by ~60s.
- PvE only. Don't add networking or PvP code.

## How to work in this repo

- For any new system, propose a plan first (files, data shape, tests) and wait for approval before writing code.
- Write or update tests for sim logic in the same change. Determinism tests (run a seeded fight twice, compare logs) must keep passing.
- Keep changes small and focused. Don't refactor unrelated code.
- When adding content, validate the JSON with `tools/` before finishing.
- If a design question isn't answered in `docs/design.md`, ask instead of inventing an answer. Then note the answer in the design doc.

## Tone and naming

The setting mixes cozy and grim: a warm Guildhall and dark rifts. Content names should fit that. Don't use names, characters, or items from Guildrun, The Bazaar, or Enter the Gungeon.
