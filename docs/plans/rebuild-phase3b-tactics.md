# Rebuild phase 3b: tactics in Practice (build plan)

Status: **built (2026-09-29), with round 2's payoffs (section 9) built and tuned the same day.** Then its playtest (does a tactic change how a fight plays, readably?). Its questions were answered the same day (Decisions); each section's "Built in step N" notes say what was built. Phase 3b of `docs/plans/rebuild-build-order.md`, before paths. Design source: part 6, `rebuild-between-fights.md` (tactics are one of the three kinds of loadout things, and the playtester's answers put the first three in Practice early). It builds on the arena sim (phase 1), the content (phase 2), and Practice (phase 3, now landscape).

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

**Built in step 2 (2026-09-29):**
- `src/sim/tactics.gd` (`Tactics`) holds all three rules, and a unit without a tactic never reaches it.
- **Casters first:** `Targeting.update` asks `Tactics.preferred` first. It's the path search `nearest` uses, now `Targeting.nearest_of`, over the enemies of the tactic's archetypes.
- **Hold your ground:**
  - `CombatSim` calls `Tactics.check_release` in the unit's update, after a cast and before targeting. It calls `Tactics.stay` where the unit would walk.
  - `stay` turns to the nearest enemy in reach unless Taunted.
  - A holder never starts a walk. An escape from crumbling ground walks its whole leg.
- **Wait to heal:** `Signatures.act` asks `Tactics.hurt_enough` before a mana signature fires.
- **The log:** the TACTIC kind reads "maren · Hold your ground: holds its ground", "…: moves out: rift_hound came within 2 hexes" (naming the enemy), and "vell · Wait to heal: Mend waits: no ally within 3 hexes below 50%". A pick reads "maren targets gloam_witch: Casters first".
- **The audit and determinism use a Witch Circle fight with all three tactics** (`test_tactics.gd`'s `tactics_setup`), not the chaos fight as planned. A tactic would change the chaos fight's seed, which uses every piece.
- **Without tactics nothing moves:** all 20 of the bench's fingerprints are the same.
- **Tests:** `tests/sim/test_tactics.gd` (12). The crumbling-ground case is left to the code path it shares with every unit.
- **Mutation checks:** 14 on the three rules, all caught. One was a dead halt in `stay`, now removed.
- The board's form for TACTIC is step 3. `test_every_encounter_plays.gd` has its row, and the encounters, played without tactics, don't make any.

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

**Built in step 3 (2026-09-29):**
- **The session:** `PracticeSession.tactics` (hero id -> tactic id, kept while the game is open, for every encounter). `set_tactic` takes only one the hero can take. `tactics_for` lists a hero's choices. Every setup and legality check carries the tactics of the heroes in its formation (`tactics_in`).
- **Choosing:** the hero popup's **Tactic** row. While placing, it has None plus a button per tactic, the chosen one in the primary style, with its sentence under them. In a fight it's "Tactic: Casters first" (or "none"), with no buttons. The popup's signal is connected deferred, since choosing rebuilds its buttons.
- **The board:** while placing, the tactic's name is under the hero's.
- **In the fight:** a TACTIC line shows over the hero as the note's first part: "Holds its ground", "Moves out", "Mend waits". `test_every_encounter_plays.gd`'s tables have it.
- **The result:** a line naming the tactics ("Tactics: Brannoc, Hold your ground · Maren, Casters first · Vell, Wait to heal") when any were taken.
- **Screenshots:** a new shot of Maren's popup choosing Hold your ground.
- **Tests:** `tests/ui/test_tactics_ui.gd` (6), including a Witch Circle fight on screen with all three tactics that matches `CombatSim.run`. Mutation checks: 10, all caught.

## 5. The sim runner

- **A tactics report** (`--tactics`): for each encounter's named formations, the win rate with no tactics, then with each tactic on each hero who can take it (one at a time).
- **It's a report, not a gate.** The loadout gate comes with phase 5. It answers whether a tactic ever changes an outcome and whether any tactic is always right; this plan's bar needs both.
- `tools/sim_formations.json` gains nothing. Formations stay tactic-free.

**Built in step 4 (2026-09-29):**
- `--tactics` on `tools/sim_runner.gd` runs the report instead of the placement report, and always exits 0. `Report.run_tactics`, `tactics_text`, and `tactics_summary` are in `tools/sim_report.gd`.
- **The fights:** the placement report's formations (named, then drawn; `formations_for`, shared), fought with 8 variants: no tactics, then each tactic on each hero who can take it, one at a time.
- **Per variant:** its win rate, its change from no tactics, and how many formations it helps or hurts. **Across encounters:** where each variant helps on the whole, how many formation outcomes it changes, and the plan's two questions.
- **Tests:** `tests/tools/test_sim_runner.gd` (4 more). Mutation checks: 6, all caught, one after a test was added.

**First read** (`--tactics --seeds=5`, 44 formations, 2026-09-29; about 21 minutes). Win rate with each variant, in points against no tactics:

| Encounter | No tactics | Casters first (B / M / V) | Hold your ground (B / M / V) | Wait to heal (V) |
| --- | --- | --- | --- | --- |
| Pup Warren | 47% | 0 / 0 / 0 | −11 / −2 / +2 | −2 |
| Ash Nest | 55% | 0 / 0 / 0 | 0 / −1 / −4 | −1 |
| The Pack | 34% | 0 / 0 / 0 | +5 / −2 / −3 | −8 |
| Moth Cloud | 67% | +18 / −17 / +1 | +1 / −7 / −1 | −7 |
| Hollow Line | 59% | 0 / 0 / 0 | −43 / −58 / −55 | −3 |
| Bog Crossing | 49% | 0 / 0 / 0 | −8 / −3 / 0 | −5 |
| Sentinel Gate | 71% | 0 / 0 / 0 | −26 / −35 / −36 | −17 |
| Cairn Road | 58% | 0 / 0 / 0 | −9 / +1 / −6 | −5 |
| Witch Circle | 54% | −32 / −14 / −14 | −27 / −28 / −35 | −29 |

- **The plan's bar is met:** every tactic changes outcomes (Casters first 131 formation outcomes, Hold your ground 318, Wait to heal 74), and no variant helps in every encounter.
- **Casters first** does nothing without casters, as it should (it falls back to the hero's own rule). With them it's a real choice: Brannoc going for the Moths wins Moth Cloud 18 points more, Maren doing the same loses 17, and every hero chasing the Witch loses Witch Circle.
- **Hold your ground** is a trap against ranged enemies: a holder stands under the Hollow Archers' and the Sentinel Gate archers' fire and never closes (Hollow Line falls to 1–16%). It helps Brannoc against the Hounds (The Pack, +5) and Vell in Pup Warren (+2).
- **Wait to heal** never helps on the whole (−1 to −29): the heals it saves are worth less than the ones it skips, though it wins a few formations (Ash Nest, Bog Crossing).
- **For the playtest:** whether these read as choices with answers (Casters first, Hold) or as traps (Wait to heal). A higher threshold for Wait to heal (say 70%) is the obvious knob if it's always wrong. The numbers are left alone until the playtest says.

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

**Built in step 5 (2026-09-29):**
- CLAUDE.md: phase 3b is built.
- `tools/ci/HOW-TO-PLAY.txt`: tactics, the landscape board (your side is on the left), the log popup, and what the playtest asks.
- The screenshots already show choosing a tactic (step 3).
- A playtest build carries it all.

## 9. Round 2: payoffs (proposed and built 2026-09-29)

**Why:** the tactics report and the playtester agree that a tactic that is only a cost is rarely worth taking. Wait to heal never helped on the whole, and Hold your ground mostly hurt. So **every tactic becomes a trade:** its behavior is the cost, and a small payoff makes the cost worth paying in the right fight.

**The rule:** the payoff applies **only while the behavior does, or to what the behavior produced**, and it's in the tactic's own sentence. A flat buff would make the choice "take the biggest number"; a payoff tied to the behavior keeps it situational. The numbers are placeholders for the tactics report to tune.

| Tactic | Behavior (the cost) | Payoff |
| --- | --- | --- |
| Casters first | Goes for casters and supports first | **+20% damage** to casters and supports |
| Hold your ground | Doesn't walk until an enemy comes within 2 hexes | **+20% attack speed** while it holds |
| Wait to heal | Mend waits until an ally is **below 60%** (was 50%) | **The heal it waited for is 30% stronger** |

**The data:** each tactic gains a `payoff` with its own key:
- `"damage_vs_bp": 2000` for prefer_target: more damage from the unit's own hits (its basic attack and signature, not damage over time) on a target of the tactic's archetypes.
- `"atsp_bp": 2000` for hold_ground: its attack cooldown runs 20% faster while `holding`.
- `"heal_bp": 3000` for signature_threshold: the signature fire that waited heals 30% more.

`below_pct` becomes 60. `TacticDef` reads the payoff each kind allows, and only that.

**The sim** (still `Tactics`, and still skipped for a unit without a tactic, so tactic-free fights keep their fingerprints):
- The damage bonus multiplies a hit before defense, in `EffectRunner`, and the attack-speed bonus multiplies the unit's attack rate while it holds.
- The heal bonus is set when `hurt_enough` lets the bar go, applies to that fire's heals, and is cleared after. A heal that flies as a shot keeps the bonus it left with, like every shot's numbers.
- These are the sim's first **modifiers** (part 6 asked for one shape before charms and enemy specializations). The shape: a modifier names what it changes (damage dealt, attack rate, healing), a condition (against these archetypes, while holding, on this fire), and a basis-point amount. Charms and specializations are meant to reuse it.

**The log** (rule 4):
- A hit or heal the payoff changed says so after its number: "maren · Longshot hits cinder_moth for 26 (+20% from Casters first, …)" and "vell · Mend heals brannoc for 52 (+30% from Wait to heal)".
- The hold lines name it: "holds its ground (+20% attack speed while it holds)".
- The audit (`test_arena_log.gd`) checks a payoff's note names the tactic.

**The UI:** the hero popup's Tactic row adds a generated numbers line under the sentence ("+20% damage to casters and supports"), like every ability's. The sentences in `tactics.json` say what the payoff is for, without numbers.

**Tests:**
- Each payoff applies only under its condition: the damage bonus not on a swarm unit, the attack speed not after the hold lets go, the heal bonus only on the fire that waited.
- The log names the payoff every time it applies.
- Tactic-free fights and the bench's fingerprints are unchanged.

**Order of work** (each step: code, tests, green run, commit):
- **R1:** the payoff data and `TacticDef`, and the threshold at 60%.
- **R2:** the three payoffs in the sim, their log notes and audit rule, and mutation checks.
- **R3:** the popup's numbers line and the how-to-play text.
- **R4:** rerun the tactics report and tune the three payoffs toward the report's two questions (each tactic helps somewhere, none everywhere).
- **R5:** docs and a playtest build.

**Built in R1 (2026-09-29):**
- `TacticDef` reads an optional `payoff` object with only its kind's key (`damage_vs_bp`, `atsp_bp`, `heal_bp`; 1 to 20000 bp); another kind's key is refused.
- `tactics.json` gives each tactic its payoff, and Wait to heal waits until below 60%.
- The sentences say what each payoff is for ("hits them harder", "attacking faster", "the heal it saved is stronger").
- Nothing in a fight uses a payoff yet (R2); only the threshold moved.

**Built in R2 (2026-09-29):**
- **Casters first:** `EffectRunner.deal_hit` adds `damage_vs_bp` before Mark and defense, through `Tactics.damage_bonus_bp`. Only the attacker's own basic attack or signature counts (not a passive, a status, or a summon), and only on a target of the tactic's archetypes. `CombatSim.damage_payoffs` is set only when some unit has this payoff, so other fights never ask.
- **Hold your ground:** the attack's progress runs `atsp_bp` faster while `holding`, and stops the moment the hold lets go.
- **Wait to heal:** the payoff is on **every** fire of the signature, not a flag set by the fire that waited. With this tactic the bar can only go once an ally in reach is below 60%, so every Mend it lets go is one it waited for; a separate flag added state and a way to get out of step. It applies only to heal effects (Mend's shield isn't boosted). A Mend that flies as a shot keeps the boosted amount it left with.
- **The log:** `EffectSource.with_bonus(note)` copies a source with a note, and `LogEntry.bonus` carries it: "(+20% from Casters first)" after a hit's number (before its crit and defense notes), "(+30% from Wait to heal)" after a heal's. The hold line says "holds its ground (+20% attack speed while it holds)". The audit checks every non-empty `bonus` ends "from <the unit's tactic>".
- **The board:** the TACTIC popup drops the parenthesis, so it stays short.
- **Checks:** the bench's fingerprints are unchanged, and every mutant of the three payoffs (wrong condition, wrong scope, no note) is caught by a test.

**Built in R3 (2026-09-29):**
- `UnitInfo.tactic_numbers` makes the tactic's numbers line from its data: what the behavior waits for or goes after, then the payoff ("Holds until an enemy is within 2 hexes · +20% attack speed while it holds"). The hero popup shows it under the sentence, while placing and in a fight; with no tactic there's no line.
- `HOW-TO-PLAY.txt` gives each tactic's payoff and the 60% threshold, and asks whether the payoffs make each tactic worth trying.

**Built in R4 (2026-09-29): the second read, and tuning.** `--tactics --seeds=5`, the same 44 formations, with the payoffs. Points against no tactics (no-tactics win rates as in the first read):

| Encounter | Casters first (B / M / V) | Hold your ground (B / M / V) | Wait to heal (V): +30% / **+15%** |
| --- | --- | --- | --- |
| Pup Warren | 0 / 0 / 0 | −11 / −2 / +3 | +3 / **0** |
| Ash Nest | 0 / 0 / 0 | 0 / +1 / −1 | +5 / **+2** |
| The Pack | 0 / 0 / 0 | +5 / −2 / −3 | +9 / **+7** |
| Moth Cloud | +24 / +33 / +3 | +1 / −11 / +1 | +3 / **−2** |
| Hollow Line | 0 / 0 / 0 | −43 / −55 / −55 | +7 / **+1** |
| Bog Crossing | 0 / 0 / 0 | −7 / −1 / +4 | +9 / **+3** |
| Sentinel Gate | 0 / 0 / 0 | −26 / −34 / −37 | +18 / **+10** |
| Cairn Road | 0 / 0 / 0 | −9 / +4 / −6 | +18 / **+12** |
| Witch Circle | −26 / +8 / −6 | −27 / −26 / −34 | +12 / **−8** |

- **Casters first** is now the answer to casters: with the Moths, Maren wins every formation (+33) and Brannoc +24; at the Witch Circle, Maren gains (+8) but Brannoc leaving the front loses (−26). Nothing changes without casters, as before. The +20% stays.
- **Hold your ground** barely moved: the +20% attack speed helps a holder with something in reach, but against archers (Hollow Line, Sentinel Gate) the holder stands under fire and never closes, and no payoff fixes that. It helps each hero in two or three encounters (Brannoc against the Hounds, Maren at Cairn Road, Vell in Pup Warren and Bog Crossing), so it meets the bar as a choice with an answer ("not against archers"). The +20% stays; whether the trap is too harsh is for the playtest.
- **Wait to heal** went from never helping to helping in all nine at +30%: always right, which fails the bar. A run of Wait to heal alone at +0% (60% threshold, no payoff), +10%, +15%, and +20% found:
  - +0% helps in 2 of 9;
  - +10% helps in 6, and Witch Circle drops to −18;
  - **+15% helps in 6, costs a little in Moth Cloud (−2) and Witch Circle (−8), and does nothing in Pup Warren**;
  - +20% helps in 7 and hurts only in Moth Cloud (−1), almost everywhere.
  **It's now +15%**: worth taking against slow, grinding fights (Sentinel Gate, Cairn Road, The Pack), a mistake against the Witch (probably because her Hush silences the hero with the most mana, and a Vell sitting on a full bar is that hero; not yet checked in a log).
- **The bar:** every tactic changes outcomes, and none helps everywhere.


1. **"Casters" are the caster and support archetypes:** Cinder Moth and Gloam Witch in Act 1. (Caster only would have been just the Moth; any enemy with a signature would have taken in the Sentinel.)
2. **Hold your ground lets go for good** once an enemy comes within 2 hexes: one clear moment, then it fights normally. (Holding again whenever it's clear could stall and look indecisive.)
3. **Wait to heal waits with a full bar** until an ally in reach is below 50%. The wasted mana is the tactic's cost. (Firing on schedule but only at a hurt ally would empty the bar for nothing, which is odd to watch.)
4. **Casters first and Hold your ground are for all three heroes; Wait to heal is for Vell only**, the only healing signature.
5. **Every tactic is a trade** (after the first tactics report, 2026-09-29): its behavior is the cost, and a small payoff tied to the behavior pays for it (section 9). Wait to heal waits until below 60% (was 50%). The playtester's example payoffs were "wait below 70%, then heal 15% more below 50%" and "heal the healthiest hero, with overheal as double shield". The first became the simpler one-threshold version above. The second changes how the signature works, so it's a **sigil** (part 6), kept for phase 5.
