# CLAUDE.md

## Project

A PvE roguelite auto-battler (working title **Riftrite**, a placeholder). The player leads a guild of heroes through the rifts, one day at a time. Each hero has a row of items that fire on cooldowns, and items are infused with essences harvested from enemies. Hidden, discoverable synergies drive build variety.

**Redesign in progress:** `docs/plans/fun-redesign.md` and `docs/plans/heroes-and-deeds.md` (approved, built in steps; their **Decisions** sections win). The rules below describe the code as it is now; each redesign step updates them as it lands.

**The full design lives in `docs/design.md`**, with item tiers and Oathbinding detailed in `docs/tiers-backup-specialization.md` (its Backup parts are superseded). A redesign is being built in steps (`docs/plans/fun-redesign.md`, `docs/plans/heroes-and-deeds.md`); step 1 (loadout, drafted trio, no Backup) is in. The UI's look follows `docs/ui-asset-design.md` (for now). Before building or changing a game system, read the matching section there. If the code and the design doc disagree, stop and ask. Don't silently pick one.

## Tech stack

- Engine: Godot 4.7, GDScript (static typing everywhere: `var hp: int`, typed function signatures). `project.godot` makes untyped declarations a compile error, and the test run fails if any script in `src/`, `tests/`, or `tools/` doesn't compile.
- Tests: GUT (Godot Unit Test)
- Game data: JSON files in `data/`, loaded at startup and validated
- **Pinned versions:** Godot `4.7.2-stable`, GUT `9.7.1` (vendored in `addons/gut/`). Upgrade either one only on purpose, in its own change, and rerun the determinism tests afterward. The Godot version also appears in `.claude/hooks/session-start.sh`, `.github/workflows/*.yml`, and `tests/test_project_setup.gd` (which checks the others); keep them all in sync.

## Commands

<!-- Update these once the project is set up -->
- Run the game: `godot --path .` (main scene `src/ui/main.tscn`; the run saves to `user://run.json`, and each run writes a playtest journal to `user://playtests/run_<seed>.json`)
- Screenshots of each screen (needs a display): `xvfb-run godot --path . -s tools/ui_screenshots.gd -- --out=/tmp/shots`
- Run all tests: `godot --headless -s addons/gut/gut_cmdln.gd -gexit` (settings in `.gutconfig.json`)
- Run one test file: add `-gselect=test_project_setup.gd`
- Fresh checkout: run `godot --headless --import` once first, so class names are registered. The session-start hook does this in cloud sessions.
- Validate game data: `godot --headless --path . -s tools/validate_data.gd` (also covered by the test run)
- Headless balance sim: `godot --headless --path . -s tools/sim_runner.gd -- --fights=200 --seed=1` (optional `--party=id`, `--encounter=id`). Parties live in `tools/sim_parties.json`; encounters in `data/encounters.json`.
- Run-level balance (the run bot): `godot --headless --path . -s tools/run_runner.gd -- --runs=200 --seed=1`. Run data lives in `data/economy.json`, `data/acts.json`, `data/events.json`.
- Cloud sessions: `.claude/hooks/session-start.sh` installs the pinned Godot as `godot` in `~/.local/bin`.
- CI: `.github/workflows/tests.yml` runs the tests and the data validator on every PR and push to main.
- Playtest builds (Windows and macOS, from `export_presets.cfg`): run the "Playtest build" workflow from the Actions tab (or push a `playtest-*` tag). It publishes the zips on a GitHub pre-release. Locally: `tools/ci/install_godot.sh --templates` (with `GODOT_VERSION` set), then `tools/ci/export_builds.sh` (zips land in `build/dist/`). Builds aren't code-signed; `tools/ci/HOW-TO-PLAY.txt` (shipped in each zip) covers the first-launch warnings.

## Folder layout

```
data/          items, essences, alloys, relics, heroes, enemies, synergies, specializations; economy, acts, events (JSON)
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

- **Sockets depend on rarity:** Epic and Legendary items have 2 sockets (Epic is a placeholder to try; the list is `two_socket_rarities` in `data/tuning.json`); every other item has 1. Relics have no sockets. Infusing can happen any time between fights (for now).
- Two different essences in one item = an **Alloy** with its own effect. Two of the same = a **pure double**.
- Pure doubles are alloys too, and each has its own effect.
- An alloy **keeps both essences' normal effects** and adds its special. A special that changes how a status behaves must use **its own status type** (Inferno → Golden Flame), never modify the shared one, so it can't leak into other items' statuses.
- Infusions level up: base → Attuned → Resonant. XP comes from **item fires** (XP per fire is set per item in data; basic attacks get less) **plus each battle fought**.
- XP **resets** when a second essence is added (single → alloy or pure double) and when an infusion is removed.
- **Nothing spills right now.** Neighbor spill went with item rows (redesign step 1). The infusion rework (step 2, `docs/plans/fun-redesign.md`) brings: a Resonant single spills ~30% to the holder's other items that share a keyword (at most one spill per essence per item); alloys and pure doubles **Awaken** at Resonant and never spill; transformations never spill.
- Spill percentages and XP thresholds are tuning values in `data/`, never hard-coded.
- Essence resonance counts **essences**, not items: a single = 1, an alloy = 1 of each half, a pure double = 2, and a transformation counts its socketed essence(s).

## Synergy rules

- Five layers (`data/synergies.json`, `docs/plans/synergies-in-sim.md`): pairs (two items on one hero), transformations (item + essence), signatures (item on a specific hero), essence resonance (3/5/7), class traits (2/3 heroes; to be replaced by affinities and duo bonds). Tiered layers apply only their highest tier reached.
- Synergies are checked once at fight start, for the guild only (enemies get none for now). Their bonuses run through the relic code (auras, grants, relic triggers), and the log credits the synergy.
- Resonance counts every hero's essences.
- A transformation replaces the item's own effects, uses one copy of its essence (other essences work as plain singles, no alloy special), never spills, and still counts for resonance.

## Specialization rules

- Each **hero** has three specializations of their own (`data/specializations.json`, `docs/plans/specializations-in-sim.md`), each unique to the hero and unlike the other two. A hero picks one at rank B.
- **Locked potential:** parts unlock at B, A, and S. A later part with the same key replaces the earlier one.
- Part kinds: aura, grant (numbered from the hero's stats), ability (slotless, on a cooldown or relic trigger), basic_attack, replace_status.
- A part that replaces the basic attack must come with an `auto_attack` part, so equipping a basic-attack item never blanks the specialization.
- **Innates** (`"innate"` in `data/heroes.json`): every hero has one, always on while they fight, made of the same parts (no basic_attack) and credited by name. Keep them unique to the hero.

## Boss rules

- Bosses (and any enemy) can have **HP-threshold phases** (`PhaseDef`, `docs/plans/act1-boss.md`). A phase is entered once, the first time the enemy drops below its threshold while still standing, and is made of specialization-style parts; a same-key part replaces an earlier one. Summons (units joining mid-fight) come later.
- **Legendary relics are boss relics:** only the boss's relic choice and rare events give them.

## Item rules

- **Loadout slots** (`"slot"` on every item): `basic_attack`, `ability` (fires on its cooldown, needs effects), or `passive` (auras only, no effects). Slots by rank are tuning values (`ability_slots`, `passive_slots`: C 2/1, B 3/1, A 3/2, S 4/3) plus one basic-attack slot. There's no item size, no row order that matters, and no adjacency: "neighbor" effects reach the holder's other items (`holder_items`).
- Every unit has a built-in **basic auto-attack** (no slot). Each hero's basic auto-attack is their own and **can't be upgraded** (no sockets, no tier). A **basic-attack item** replaces it and takes the one basic-attack slot. Remove the item and the unit falls back to its basic auto-attack.
- **Two** copies of the same item at the same tier combine into the next tier (never three). If the new copy has an infusion, it replaces the old one (and the old XP is lost); if not, the old infusion and its XP stay. The player chooses whether to combine. Copies at *different* tiers can be held together.
- Tier and rarity are separate. Rarity decides how often an item appears; any item can be tiered up. Tiers are **C → B → A → S** (same as hero ranks). Items and heroes can be found above C; the Caravan (the shop, selling items) unlocks higher tiers as the run progresses (a schedule in `data/`). Earlier, higher tiers come only from events (such as tier-specific shops), enemy drops, and loot.
- Rarities: **Common, Uncommon, Rare, Epic, Legendary**. S is the top tier (S items can't combine). **Legendaries never combine**; they upgrade through their own paths and appear at most once per run.
- **Legendary paths** (`"legendary"` on the item, `docs/plans/legendary-items.md`): hits, essence (fed from the pouch), devour (fed other items; each meal leaves a trace, a % boost to the item's own numbers), bonded (holder ranks up), martyr (holder falls in a won fight), boss (a boss beaten while on a hero's loadout). A Legendary always joins at its path's start tier; progress carries over between tiers and stops at S. Legendaries come only from the Vault and rare events, never the Caravan, Loot, or tier shops (`rarity_weights` must give Legendary 0).
- **Oathbinding:** an S hero + an S item can be permanently oathbound (one per hero; the item then can't be removed, moved, or sold, but can be infused). "Specialization" means only the hero's rank-B choice; don't mix the two terms.
- **Reforging** = removing an item's infusion.
- **Item numbers** are a small base plus multipliers on the holder's stats (HP, ATK, MGK, DEF, CRIT, ATSP). **Percentage boosts** (tier, and later others) then **multiply** on top. Keep base, stat-scaled, and final values all available (the UI shows the breakdown). Basic auto-attacks scale from stats but have no tier.
- Items carry **multiple tags** (item tags and class-fit tags).
- Every item has its own crit chance (default 0). Crit damage multiplier is a tuning value (150%).
- Enemy-only items can end up with the guild through drops, but the Caravan never sells them: they upgrade only through a second copy from random loot or an upgrade stop.
- Enemies use hand-made, fixed item layouts with set tiers, built from the same item system; some items are enemy-only. Some enemy teams carry relics (enemy-only relics exist too). Every fight guarantees one drop from the enemy team's items and relics, enemy-only ones included.

## Other core rules

- Items are per hero; relics are shared by the team. The guild can hold any number of relics (no board, no slots, no sockets); a relic can be turned down, but once taken it can't be removed. Relics are rare and change how a build works rather than adding flat stats. Relic numbers are flat (no stat scaling); only percentage boosts that apply to everything of that kind ("all shields +10%", "shields on this hero +50%") change them. In the sim, such a boost is an `all_items` aura with no filter. Relic details: `docs/plans/relics-in-sim.md`.
- **The team** (`docs/plans/heroes-and-deeds.md`): a run drafts three heroes at the start (three picks, each 1 of 3 not yet taken) and keeps them all run; all three fight. No bench, no Backup, no buying heroes. Each elite win gives a **rank-up** the player hands to one hero (`RunFlow.give_rank_up`); a hero keeps their specialization and items as they rank up.
- **The Caravan never offers an item at a different tier than a copy the player already holds.** Different-tier copies of the same item can still be held when they come from elsewhere (Vault, loot, fights, events). Items can move between heroes freely between fights (never during combat).
- Fallen heroes always come back after a fight, with no downside.
- A lost fight restarts the day (everything kept, plus bonus gold); the second loss ends the run. Every fight starts at full HP (unless an item or relic says otherwise). Unequipped items wait in a shared stash that holds 6 items; relics can't go there.
- **The run layer** (`src/run/`, `docs/plans/run-state.md`): change a run only through `RunActions` (each refuses cleanly and changes nothing when it fails); `RunState.check()` lists every run rule, and loading a save checks them all. `RunFight` builds fights from a run and writes XP, discoveries, and results back.
- **The day structure** (`RunFlow`, `docs/plans/day-structure.md`): a run moves through phases (start, Caravan, stop choice, stop, fight, rewards, act end or run over); each RunFlow action checks the phase. Offers use `RunRandom` streams seeded by where they happen, never by earlier picks.
- There is no branching map: each act is a set number of days, each going Caravan (shop) → a stop the player picks → one fight. **Stops are nodes** (`data/nodes.json` plus every event in `data/events.json`, one weighted pool, `docs/plans/stop-nodes.md`): each day offers `node_choices` (2) different nodes that apply. A skirmish node is an extra fight: a win gives a normal win's rewards, and a loss gives nothing and isn't counted as a loss. A lost fight replays the day against the same enemies. Offers come from the run seed and don't depend on earlier picks (for now). The run layer is deterministic from its seed, like the sim.
- The sim still allows 1–5 heroes per side (balance parties use 4); the run layer fields exactly its three.
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
