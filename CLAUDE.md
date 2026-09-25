# CLAUDE.md

## Project

A PvE roguelite auto-battler (working title **Riftrite**, a placeholder). The player leads a guild of heroes through branching rift maps. Each hero has a row of items that fire on cooldowns, and items are infused with essences harvested from enemies. Hidden, discoverable synergies drive build variety.

**The full design lives in `docs/design.md`**, with item tiers, backup mode, and Oathbinding detailed in `docs/tiers-backup-specialization.md`. Before building or changing a game system, read the matching section there. If the code and the design doc disagree, stop and ask. Don't silently pick one.

## Tech stack

- Engine: Godot 4.7, GDScript (static typing everywhere: `var hp: int`, typed function signatures). `project.godot` makes untyped declarations a compile error, and the test run fails if any script in `src/`, `tests/`, or `tools/` doesn't compile.
- Tests: GUT (Godot Unit Test)
- Game data: JSON files in `data/`, loaded at startup and validated
- **Pinned versions:** Godot `4.7.2-stable`, GUT `9.7.1` (vendored in `addons/gut/`). Upgrade either one only on purpose, in its own change, and rerun the determinism tests afterward. The Godot version also appears in `.claude/hooks/session-start.sh` and `tests/test_project_setup.gd`; keep all three in sync.

## Commands

<!-- Update these once the project is set up -->
- Run the game: `godot --path .` (no main scene yet)
- Run all tests: `godot --headless -s addons/gut/gut_cmdln.gd -gexit` (settings in `.gutconfig.json`)
- Run one test file: add `-gselect=test_project_setup.gd`
- Fresh checkout: run `godot --headless --import` once first, so class names are registered. The session-start hook does this in cloud sessions.
- Validate game data: `godot --headless --path . -s tools/validate_data.gd` (also covered by the test run)
- Headless balance sim: `godot --headless --path . -s tools/sim_runner.gd -- --fights=200 --seed=1` (optional `--party=id`, `--encounter=id`). Parties live in `tools/sim_parties.json`; encounters in `data/encounters.json`.
- Cloud sessions: `.claude/hooks/session-start.sh` installs the pinned Godot as `godot` in `~/.local/bin`.

## Folder layout

```
data/          items, essences, alloys, relics, heroes, enemies, synergies (JSON)
docs/          design.md and other design notes
src/sim/       combat simulation: pure logic, NO nodes, NO rendering
src/run/       run state, days and stops, shop, forge, economy, save
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
- An alloy **keeps both essences' normal effects** and adds its special. A special that changes how a status behaves must use **its own status type** (Inferno → Golden Flame), never modify the shared one, so it can't leak into other items' statuses.
- Infusions level up: base → Attuned → Resonant. XP comes from **item fires** (XP per fire is set per item in data, based on type and size; auto-attacks get less) **plus each battle fought**.
- XP **resets** when a second essence is added (single → alloy or pure double) and when an infusion is removed.
- Only **Resonant** infusions spill to neighbors:
  - Single essence: partial effect (~30%) to **both** sides
  - Alloy: first essence's partial effect to the **left**, second's to the **right**, each at the single-essence strength (its own tuning value, currently equal to the single's); the alloy effect itself never spills
  - Pure double: the base essence's partial effect (~30%) to both sides. Its bonus effect never spills and never strengthens the spill. The one exception is a pure double whose alloy effect *is* "doubled spill" (optional idea, first tried on Overgrowth, Verdant + Verdant).
  - Essence transformation: **never** spills
- Item spills stay inside that hero's row. Relic spills stay on the relic board, never reaching hero items.
- Spill percentages and XP thresholds are tuning values in `data/`, never hard-coded.
- Essence resonance counts **essences**, not items: a single = 1, an alloy = 1 of each half, a pure double = 2, and a transformation counts its socketed essence(s). Relics count too.

## Item rules

- Every unit has a built-in **basic auto-attack** (no slot). Each hero's basic auto-attack is their own and **can't be upgraded** (no sockets, no tier). **Auto-attack items** replace it, take up slots, and can be Small, Medium, or Large. **Max one auto-attack item per hero.** Remove the item and the unit falls back to its basic auto-attack.
- **Two** copies of the same item at the same tier combine into the next tier (never three). If the new copy has an infusion, it replaces the old one (and the old XP is lost); if not, the old infusion and its XP stay. The player chooses whether to combine. Copies at *different* tiers can be held together.
- Tier and rarity are separate. Rarity decides how often an item appears; any item can be tiered up. Tiers are **C → B → A → S** (same as hero ranks). Items and heroes can be found above C; normal shops and the Tavern unlock higher tiers as the run progresses (a schedule in `data/`). Earlier, higher tiers come only from events (such as tier-specific shops), enemy drops, and loot.
- Rarities: **Common, Uncommon, Rare, Epic, Legendary**. S is the top tier (S items can't combine). **Legendaries never combine**; they upgrade through their own paths and appear at most once per run.
- **Oathbinding:** an S hero + an S item can be permanently oathbound (one per hero; the item then can't be removed, moved, or sold, but can be repositioned and infused). "Specialization" means only the hero's rank-B choice; don't mix the two terms.
- **Reforging** = removing an item's infusion.
- **Item numbers** are a small base plus multipliers on the holder's stats (HP, ATK, MGK, DEF, CRIT, ATSP). **Percentage boosts** (tier, and later others) then **multiply** on top. Keep base, stat-scaled, and final values all available (the UI shows the breakdown). Basic auto-attacks scale from stats but have no tier.
- Items carry **multiple tags** (item tags and class-fit tags).
- **Size never affects rarity.** Each item of a given rarity has the same appearance odds whatever its size; there are just more Small items in the pool.
- Every item has its own crit chance (default 0). Crit damage multiplier is a tuning value (150%).
- Enemies use hand-made, fixed item layouts with set tiers, built from the same item system; some items are enemy-only. Some enemy teams carry relics (enemy-only relics exist too). Every fight guarantees one drop from the enemy team's items and relics, enemy-only ones included.

## Other core rules

- Items are per hero; the relic board is shared by the team. Items can move between heroes freely between fights (never during combat).
- Fallen heroes always come back after a fight, with no downside.
- A lost fight restarts the day (everything kept, plus bonus gold); the second loss ends the run. Every fight starts at full HP (unless an item or relic says otherwise). Unequipped items wait in a shared stash of 6 slots that works like a hero row; relics can't go there.
- There is no branching map: each act is a set number of days, each with a shop, one fight, and a stop the player picks. Offers come from the run seed and don't depend on earlier picks (for now). The run layer is deterministic from its seed, like the sim.
- A run starts with one hero; roster cap 6, 1–5 fielded. Which heroes sit in backup is the player's choice; backup heroes' Backup effects and their items' backup modes apply. In a fight, backup heroes are off the field (never targeted, no collapse damage, don't count for victory); only `"backup"` blocks act from the bench. Common items can't have a backup mode (until Oathbinding); Legendary items must.
- "Lowest HP" (heals and targeting) means lowest HP **percentage**.
- Rift Collapse starts at 45s of combat and deals **flat** damage (never % of max HP) that grows every second, hitting **Shield before HP**. From 90s the growth itself accelerates. The numbers are set per act (Act 2 = double Act 1) in `data/`. Early fights end around 60s; later ones can run much longer. There is no hard time limit, but a fight still running at **180s is a tie**, as is both sides dying on the same tick, and **a tie counts as a guild victory**.
- Formation for now: each side has fixed **front and back rows**, ordered left to right. The hex arena comes later, so don't build hex code until asked.
- PvE only. Don't add networking or PvP code.

## How to work in this repo

- For any new system, propose a plan first (files, data shape, tests) and wait for approval before writing code.
- Write or update tests for sim logic in the same change. Determinism tests (run a seeded fight twice, compare logs) must keep passing.
- Keep changes small and focused. Don't refactor unrelated code.
- When adding content, validate the JSON with `tools/` before finishing, and run the balance sim on anything that changes numbers.
- Damage-over-time scale: one Burn stack is worth about 20 damage over its life, and one Poison or Bleed stack deals 1 damage per second for the rest of the fight. Items that apply these directly should apply few stacks (the conversion rule's 5% already assumes this).
- If a design question isn't answered in `docs/design.md`, ask instead of inventing an answer. Then note the answer in the design doc. Unanswered questions live under **Open questions** in `docs/design.md`.

## Tone and naming

The setting mixes cozy and grim: a warm Guildhall and dark rifts. Content names should fit that. Don't use names, characters, or items from Guildrun, The Bazaar, or Enter the Gungeon.
