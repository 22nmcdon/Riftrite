# Rebuild phase 3b: tactics in Practice (build plan)

Status: **proposed (2026-09-29); its questions answered the same day (Decisions); waiting on the go-ahead to build.** Phase 3b of `docs/plans/rebuild-build-order.md`, before paths. Design source: part 6, `rebuild-between-fights.md` (tactics are one of the three kinds of loadout things, and the playtester's answers put the first three in Practice early). It builds on the arena sim (phase 1), the content (phase 2), and Practice (phase 3, now landscape).

**Goal:** give the player the first way to shape what heroes do in a fight they can't control. Before a Practice fight, each hero can take **one tactic** from three: **Casters first**, **Hold your ground**, and **Wait to heal**. The sim follows it, the log says so, and the board shows it.

**Why now:** tactics are the part-6 idea most likely to change how fights feel, and the riskiest if they don't work. Practice is ready to test them, and they're a small sim change: a targeting override, a movement rule, and a signature condition.

**Done when:** in a playtest build, **tactics change how a fight plays, and you can see why** (the build order's gate for 3b). This plan's own bar, before the playtest:
- with no tactics taken, every fight is exactly what it was (the bench's fingerprints don't move);
- each tactic changes the outcome of at least one encounter in the sim runner's tactics report, and none is right in every encounter;
- every tactic's effect is in the log with its source (rule 4), and has a form on the board.

## Scope

**In phase 3b:**

- The three tactics, as data (`data/tactics.json`), with three new tactic kinds in the sim.
- One tactic slot per hero in Practice, chosen at placement and remembered while the game is open.
- The log and the board showing what a tactic did.
- A tactics report in the sim runner.

**Not in phase 3b:**

- The loadout step, charms, sigils, the currency, buying, and wounds (phase 5, part 6).
- More than one slot, or more than three tactics.
- Enemies with tactics.
- Changing any number in the content. With no tactic, every fight must be exactly what it was.

## Decisions this plan builds on

- **Tactics change how a hero behaves, not what they can do** (part 6). No tactic adds a move.
- **Tactics are written against the slot, not the ability** (part 6, section 3). "Wait to heal" says "your healing signature", not "Mend", so it survives a transformation in phase 4.
- **Content is data** (CLAUDE.md rule 3): each tactic is a JSON entry. The three tactic **kinds** (below) are new code, since no existing effect, trigger, or part can change how a unit picks targets, walks, or holds its signature.
- **Every change in a fight is in the log with its source** (rule 4).
- **Targets are sticky** (arena plan): a unit keeps its target until it falls, a Taunt pulls it away, it's stealthed, or it can't be reached. Tactics change the pick, not the stickiness.
- **Taunt still wins** over every tactic.

## 1. What a tactic is

A tactic is a JSON entry in `data/tactics.json`, loaded by `ContentDb` as a `TacticDef`:

```json
{
  "id": "casters_first",
  "name": "Casters first",
  "text": "Goes for enemy casters and supports first; otherwise picks as usual.",
  "kind": "prefer_target",
  "archetypes": ["caster", "support"],
  "heroes": ["brannoc", "maren", "vell"]
}
```

- **`kind`** is one of three (the new code):
  - `prefer_target`: which enemies it goes for first (`archetypes`).
  - `hold_ground`: it doesn't walk until an enemy comes near (`release_hexes`).
  - `signature_threshold`: its healing signature waits for a hurt ally (`below_bp`).
- **`heroes`** lists who can take it. A tactic shared by a role comes in phase 5 (part 6).
- **`text`** is the player's sentence, like every ability's. It names every reach (the content rule), and numbers are left to a generated line.
- **The sim needs enemies' archetypes** for `prefer_target`. `UnitDef` gains `archetype` (a name, "" for heroes), copied from `EnemyDef` when content loads, so summons have theirs too.

**Built in step 1 (2026-09-29):**
- `TacticDef` (`src/sim/defs/tactic_def.gd`) reads each kind's own numbers, and only those:
  - `archetypes` for prefer_target;
  - `release_hexes` (1–10, kept as plane units) for hold_ground;
  - `below_pct` (1–99, kept as basis points) for signature_threshold.
- `ContentDb` loads `data/tactics.json` (Casters first, Hold your ground, Wait to heal) and checks:
  - each tactic's heroes exist and aren't listed twice;
  - a signature_threshold hero's signature heals the lowest ally on mana.
- `UnitDef.archetype` comes from the enemy's entry, and `copy()` keeps it, so scaled kits and phases have it.
- `UnitSetup.tactic`. `Encounters.setup` takes hero id -> tactic id and refuses an unknown tactic, or one for a hero not in the fight. `FightSetup.validate` refuses a tactic the unit can't take (enemies take none).
- Tests: `tests/sim/test_tactic_defs.gd`. Mutation checks on the new code: all 9 caught, one after a test was added (a hero's kit on the enemies' side). Nothing in a fight uses a tactic yet (step 2).

## 2. The three tactics

### Casters first (`prefer_target`)

- **When the unit picks a target** (at the start, or when its target falls, is stealthed, or can't be reached), it picks the **nearest** enemy whose archetype is in the list, by the same path search as `nearest`. With none standing, it picks by its own rule as usual.
- **It stays sticky.** It doesn't drop a target to go for a caster that turns up later (a summon, say).
- **Taunt pulls it away** as it does now.
- **The log:** the TARGET line's reason is the tactic ("targets Gloam Witch: Casters first").
- **What it tests:** a melee hero walking past the front line, or a ranged one ignoring the nearest threat.

### Hold your ground (`hold_ground`)

- **From the fight's start, the unit doesn't walk** until an enemy comes within **2 hexes** of it (center to center). Then it lets go **for the rest of the fight** (Decision 2).
- **While holding, it still attacks and casts anything in reach.** If its target is out of reach and another enemy is in reach, it turns to that one.
- **A push, pull, or leap still moves it.** It holds wherever it lands, and Rift Collapse still moves it off crumbling ground.
- **The log:** a new kind, **TACTIC**, sourced to the unit and the tactic. There's a line when it starts holding ("Maren holds her ground: Hold your ground"), and one when it lets go ("Maren moves out: Rift Hound came within 2 hexes").
- **What it tests:** a back-liner who stays behind the tank, or a tank who waits for the charge instead of walking into it.

### Wait to heal (`signature_threshold`)

- **For a hero whose signature heals the lowest ally** (Vell's Mend now). It fires only when an ally in its reach is **below 50% HP**.
- **Until then the bar waits, full**, as it does now when no one is in reach, so mana regen and attacks go to waste (Decision 3).
- **The log:** a TACTIC line when the full bar starts waiting ("Mend waits: no ally within 3 hexes below 50%"), and the FIRE line as usual when it goes off.
- **What it tests:** saving the big heal for the moment it matters, at the cost of heals that would have landed early.

## 3. In the fight's setup

- **`UnitSetup` gains `tactic`** (a `TacticDef`, or null).
- **`Encounters.setup`** takes an optional map of hero id to tactic id.
- **`FightSetup.validate`** refuses a tactic that doesn't exist or that the hero can't take.
- **No tactic means the fight is exactly what it was.** The code paths are skipped, not just no-ops: no extra log lines, and the same fingerprints.
- **`UnitState`** keeps the tactic, and whether a hold has been let go.

## 4. Practice

- **Choosing:** at placement, a hero's popup (click the hero) gains a **Tactic** row: None, plus each tactic that hero can take, each with its sentence. Picking one takes effect at once.
- **Seeing it:**
  - The board shows a small tag under the hero's name while placing ("HOLD", "CASTERS", "WAIT").
  - The hero popup names it during the fight.
  - The tactics report and the result say which heroes had one.
- **Remembered:** `PracticeSession` keeps each hero's tactic while the game is open, like the formation. Nothing is saved to disk.
- **On the board:** a TACTIC entry shows as a name over the unit, like a signature's FIRE ("Holds", "Moves out", "Waits"). It gets a row in `test_every_encounter_plays.gd`'s FORMS table, and an audit rule in `test_arena_log.gd`.

## 5. The sim runner

- **A tactics report** (`--tactics`): for each encounter's named formations, the win rate with no tactics, then with each tactic on each hero who can take it (one at a time).
- **It's a report, not a gate.** The loadout gate comes with phase 5. It answers whether a tactic ever changes an outcome and whether any tactic is always right; this plan's bar needs both.
- `tools/sim_formations.json` gains nothing. Formations stay tactic-free.

## 6. Files

| File | Change |
| --- | --- |
| `data/tactics.json` | New: the three tactics |
| `src/sim/defs/tactic_def.gd` | New: `TacticDef` (kinds, reading, checks) |
| `src/sim/defs/unit_def.gd`, `src/sim/content_db.gd` | `archetype` on kits; load and cross-check tactics |
| `src/sim/setup/unit_setup.gd`, `fight_setup.gd`, `encounters.gd` | The tactic on a unit, validated |
| `src/sim/state/unit_state.gd` | The tactic and its hold state |
| `src/sim/effects/targeting.gd` | `prefer_target` in `update` |
| `src/sim/combat_sim.gd`, `src/sim/arena/movement.gd` | `hold_ground` in the unit's update |
| `src/sim/signatures.gd` | `signature_threshold` in `pick_target` |
| `src/sim/log_entry.gd` | The TACTIC kind |
| `src/ui/practice/practice_session.gd`, `src/ui/widgets/hero_popup.gd`, `src/ui/arena/unit_token.gd`, `src/ui/arena/fight_fx.gd`, `src/ui/fight_names.gd` | Choosing, showing, and logging tactics |
| `tools/sim_runner.gd`, `tools/sim_report.gd` | `--tactics` |
| `tests/sim/test_tactics.gd` | New: each kind's rules |
| `tests/ui/test_tactics_ui.gd` | New: choosing, remembering, and showing |
| `tests/sim/chaos_fight.gd`, `test_arena_log.gd`, `test_every_encounter_plays.gd`, `tests/tools/test_sim_runner.gd` | The chaos fight uses a tactic; the audit and board rows for TACTIC; the report |

## 7. Tests

- **Casters first:**
  - picks a caster over a nearer swarm unit;
  - falls back to its own rule with no caster standing;
  - stays on its target when a caster turns up;
  - Taunt still pulls it away;
  - the log names the tactic.
- **Hold your ground:**
  - doesn't walk while no enemy is within 2 hexes, and attacks what's in reach;
  - turns to an enemy in reach when its target is out of reach;
  - lets go when an enemy comes within 2, for good;
  - a push moves it and it holds where it lands;
  - it leaves crumbling ground;
  - both log lines.
- **Wait to heal:**
  - the full bar waits while every ally in reach is at 50% or more;
  - it fires on the first ally below;
  - the wait is logged once per full bar.
- **Setup:**
  - an unknown tactic, or one a hero can't take, is refused;
  - with no tactics, the chaos fight and the bench fights are unchanged (their fingerprints).
- **Practice:**
  - choosing in the popup, the tag, remembered between fights;
  - the fight on screen is the fight `CombatSim.run` gives with the same tactics.
- **The runner:** the tactics report runs small in `test_sim_runner.gd`.
- **Mutation checks** on the three kinds, as in earlier phases.

## 8. Order of work (each step: code, tests, green run, commit)

1. **Data:** `TacticDef`, `tactics.json`, `archetype` on kits, the setup and validation.
2. **Sim:** the three kinds, the TACTIC log kind and its audit rule, and tests. The fingerprints are unchanged with no tactics.
3. **Practice:** choosing in the hero popup, the tag, remembering, and the board's form for TACTIC.
4. **Sim runner:** the tactics report, and a first read of what it says.
5. **Docs** (CLAUDE.md, this plan's "Built in step N" notes), screenshots, and a playtest build for the gate.

## Decisions (2026-09-29, the playtester's answers)

1. **"Casters" are the caster and support archetypes:** Cinder Moth and Gloam Witch in Act 1. (Caster only would have been just the Moth; any enemy with a signature would have taken in the Sentinel.)
2. **Hold your ground lets go for good** once an enemy comes within 2 hexes: one clear moment, then it fights normally. (Holding again whenever it's clear could stall and look indecisive.)
3. **Wait to heal waits with a full bar** until an ally in reach is below 50%. The wasted mana is the tactic's cost. (Firing on schedule but only at a hurt ally would empty the bar for nothing, which is odd to watch.)
4. **Casters first and Hold your ground are for all three heroes; Wait to heal is for Vell only**, the only healing signature.
