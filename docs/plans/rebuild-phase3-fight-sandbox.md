# Rebuild phase 3: the fight sandbox (build plan)

Status: **proposal (2026-09-28), waiting for approval.** Phase 3 of `docs/plans/rebuild-build-order.md`. Design sources: `rebuild-arena.md` (placement, the free-moving fight, areas, the shrinking arena), `rebuild-enemies.md` (fair fights: threats shown before placing), and `rebuild-run.md` (the fight card). It builds on the arena sim (phase 1, `rebuild-phase1-arena-sim.md`) and the content and sim runner (phase 2, `rebuild-phase2-heroes-enemies.md`).

**Goal:** a **Practice** mode on the title screen where you pick an Act 1 encounter, place Brannoc, Maren, and Vell on the hex board, and watch the fight play out on the free-moving plane, readable enough to tell who is attacking whom and why. All art is placeholder (decided: the art rehaul is phase 7).

**Done when** (the build order's gate): **Playtest gate 1** — a single arena fight with the base heroes is fun and readable. That's judged by you in a playtest build. This plan's own bar, before the playtest: every log kind the Act 1 content produces has a visible form on the board or in the log panel, and a full fight of every encounter plays to its end in the UI headless with no errors.

## Scope

**In phase 3:**

- Practice mode: pick an encounter, place, fight, see the result, place again.
- The hex board for placement, and the arena view for the fight (the same view, two modes).
- Fight playback: movement, attacks and shots in flight, area warnings, pushes and leaps, Rift Collapse, deaths, summons, statuses, HP, Shield, and mana bars, signatures.
- Controls: pause, speed, and restart.
- Unit info: hover a unit (placement or fight) for its threat line or role, stats, and what its abilities do.
- The fight log panel (readable lines, filtered) and the per-hero fight chart.
- The screenshot tool and tests for all of it.

**Not in phase 3:**

- Paths, vows, and transformations (phase 4; the sandbox gains a path picker then).
- The run, camp, fight choice, relics, and saves (phase 5). Practice keeps nothing between sessions except, perhaps, the last formation (question 4).
- Real art, animation beyond moving and tweening shapes, sound (phase 7).
- Changes to the sim's rules or content numbers. A playtest finding that needs one goes back to the plans.

## Decisions this plan builds on

- **The sandbox stays in the game as Practice** on the title screen, and can stay rough until the art rehaul (build order, Decisions).
- **The sim is separate from presentation** (CLAUDE.md rule 2): the UI reads sim state and the log; it never changes the fight.
- **Every change in a fight is in the log with its source** (rule 4), and the log alone replays every position (phase 1, section 11). So anything the player sees can be traced to a log line.
- **Enemy positions and threats show before you place** (enemies plan: fair fights).
- **Your last formation is remembered** (design: the arena).
- **A unit without a mana signature shows no mana bar** (heroes plan).
- **Leaps and pushes are instant in the sim; only the UI animates them** (arena plan).

## What comes back from the old UI

The old fight screen (in git history, the commit before phase 0's gut) was a row-based card view, but its playback and panels didn't depend on items or rows. The build order marked several of them **Keep (adapt)**; phase 0 removed them because nothing could run them. They come back from git history, adapted:

| Old piece | What it did | In phase 3 |
| --- | --- | --- |
| `FightPlayer` | Re-ran a fresh `CombatSim` from the setup and stepped it live: `advance(seconds)` returns the new log entries; speeds 0.5×, 1×, 2×, 4×; pause; skip to the end. Tested at every speed to replay the recorded log exactly | Back nearly as it was, plus rewind (section 4) |
| `FightTally` | The chart's totals, built only from log entries as they're shown, so the chart and the log always agree: damage by type, support (healing, Shield), taken (to HP, absorbed) | Back, minus items and relics, moved to `src/sim/` so the sim runner uses it too |
| `FightChart` | Tabs (damage, support, taken) of stacked bars per hero, with a breakdown on hover | Back as it was |
| `FightBanners` | A queue of short banners (phases, discoveries), each shown a moment scaled by speed | Back, for phases, the collapse, and the fight's end |
| `FightNames` | Unit ids to display names ("Rift Pup 2") and colored log lines | Back, for the new ids (`rift_pup#2`) |
| Fight screen keys | Space pauses, 1–4 set the speed, S skips to the end, L toggles the log | Kept |
| `FightFx` | Tweens on character figures: swings, projectiles, hit flashes, floating numbers, falls | Rewritten for tokens on the plane (section 5); its speed scaling and "kill the old tween" rules kept |
| The UI test kit | Headless helpers to find and press buttons and read labels on a real `Main` | Back, extended for the board (clicking hexes, dragging tokens) |

What doesn't come back: the row layout, unit cards, item panels, and the old figures and character art (phase 7 replaces those).

## 1. The flow

```
Title ──Practice──> Encounter list ──pick──> Placement ──Fight──> Fight ──end──> Result
                        ^                        ^                                 │
                        └──────── Back ──────────┴──── Place again / Rematch ──────┘
```

- **Encounter list:** the nine Act 1 encounters in `encounters.json`'s order. Each card shows the name, what it tests, its days, and its enemies (name, archetype, threat line).
- **Placement:** the board with the encounter's enemies and rocks already on it; the three heroes start on the last formation used (or the runner's "guarded" formation the first time). You move heroes between hexes of your zone; **Fight** is enabled when all three stand on legal hexes.
- **Fight:** the same board, now the free-moving plane, playing the fight live. Controls: pause, speed (question 2), and restart.
- **Result:** victory, defeat, or tie (a tie counts as a win), the fight's length, and the fight chart. **Place again** returns to placement with this formation; **Rematch** replays the same placement with the next seed (seeds only change crits); **Back** returns to the list.

## 2. The board

- **One view, `ArenaView`, for both modes.** It maps the plane to pixels: 1 hex (1000 units) = `hex_px` pixels, sized to fit the screen (about 120 px at 1920 × 1080 for the 8 × 7 board). Heroes' rows at the bottom of the screen, enemies' at the top (the sim's row 0 is the heroes' back row).
- **Placement mode** draws the flat-top hexes (`HexGrid` gives every center), shaded by zone: yours, the neutral row, theirs. Rocks are drawn as their circles.
- **Fight mode** keeps the hex outlines faint (distances are still counted in hexes) and draws the plane: rocks, units, and crumbling ground.
- **Units are placeholder tokens:** a circle of the unit's radius (400, so they read as big as they are), colored by side, with a short label (the hero's initial, or the enemy's short name) and a small role or archetype glyph. Fliers get a shadow offset. Summons are drawn smaller-labelled but the same size, since they are.
- **Everything is drawn with `_draw()`** on a few layers (ground, areas, units, shots and effects, overlays), not one node per hex. Units are nodes (for hover and tweening); shots and floating numbers are pooled.

## 3. Placement

- **Moving a hero:** drag a hero token to a hex, or click a hero and then a hex. A hero dropped on another hero swaps them. Illegal hexes (outside your zone, on a rock) refuse the drop and flash.
- **Legality comes from the sim:** the screen builds the formation, then `Encounters.setup` and `FightSetup.validate`; the Fight button shows the first error if there is one. The UI never keeps its own copy of the rules.
- **Enemies are shown where they'll stand**, with their threat lines on hover. Their reach is shown on request: hovering an enemy draws its attack range and, for signatures with a reach (Pounce's 4 hexes, Drag's 5), that reach too, so "the Hound can reach your back line from there" is visible before the fight.
- **Remembered formation:** the last formation you fought with is used again when you open any encounter (if a hex is now illegal, that hero goes to the nearest free legal hex). Question 4 asks whether it should outlast the session.

## 4. Fight playback

**The recommended approach (question 1): step the sim live.** A `FightPlayer` owns the `CombatSim`, built from the placement's `FightSetup`, and advances it tick by tick as real time passes (20 ticks a second at 1×). Each frame the view reads the sim's state for where things are, and reads the log entries added since the last frame for what happened.

- **Why live and not "run the fight, then replay the log":**
  - The sim is fast enough: the phase 2 swarm is the worst case at about 23 ms of sim per second of fight, so 4× costs under a tenth of each second.
  - Reading `UnitState` for positions, HP, Shield, mana, and statuses is exact and needs no second model of the fight in the UI. The log is only used for what's momentary (a shot fired, an area warned or landed, a push, a number to float).
  - Rewind still works: the sim is deterministic, so "back to 10s" is a fresh sim from the same setup run to tick 200 (a few milliseconds).
- **Smooth motion:** units are drawn between their positions at the last two ticks (interpolated by how far into the next tick real time is), so 20 ticks a second looks like 60 frames. Pushes, pulls, leaps, charges, and hops are tweened over a few frames from the log's from and to points instead, since the sim moves them instantly.
- **Time is only ever given to the player by `FightPlayer.advance(real_seconds)`** (as in the old player), so tests drive a fight with fake time and no frame timing.
- **Skip to the end** runs the rest of the fight at once and shows the end state without animating the entries it skipped (the old screen skipped animation for large batches the same way).
- **The UI never writes to the sim.** `FightPlayer` is the only thing that calls `step()`.

## 5. What the fight shows

Each item names the sim state or log entries it comes from. Anything a player could ask "why?" about has a log line behind it.

| On the board | From |
| --- | --- |
| Unit tokens moving, facing their target | `UnitState.pos`, `target` |
| **Target lines** (thin, faint; brighter for Taunt) on hover, or for all units with a toggle | `UnitState.target`, Taunt status |
| HP bar and Shield overlay above each unit | `hp`, `max_hp`, `shield` |
| **Mana bar** under the HP bar, only for units with a mana signature | `mana`, `mana_cap` |
| Cast bar while a signature is being cast | `CAST`, `CAST_CANCELLED` |
| Signature name popping over the unit as it fires | `FIRE` of a signature |
| Status icons under the bars (Root, Stun, Slow, Taunt, Silence, Marked, Engaged, Undying, Burn, Poison, Bleed with stacks) | `UnitState.statuses` |
| Melee hits: a short swipe from attacker to target | `DAMAGE` from a basic attack in reach |
| **Shots in flight:** a dot or streak travelling to the target, landing at the logged tick | `SHOT`, `SHOT_FIZZLED` |
| **Area warnings:** the shape outlined and filling up until it lands, then a flash | `AREA_WARNING`, `AREA_LANDED` |
| Floating numbers: damage (crits bigger), heals, Shields | `DAMAGE`, `HEAL`, `SHIELD`, `STATUS_DAMAGE` |
| Pushes, pulls, leaps, charges, hops: tweened moves, with a stun star when a push is stopped | `PUSH`, `LEAP`, `CHARGE`, `HOP` |
| Engage: a small link between an engager and the unit it holds | Engaged status and its source |
| Auras: a faint ring on the holder while it's active | `AURA` |
| **Rift Collapse:** the next ring striped when warned, darkened when crumbled | `COLLAPSE_RING`, `sim.safe` |
| Summons appearing, deaths fading out | `SUMMON`, `DEATH` |
| Phases: the unit's name changes and a banner shows the phase | `PHASE` |
| The fight clock, and a banner at 45s ("The rift collapses") | `sim.tick`, `COLLAPSE_RING` |

- **Hover or click any unit** during the fight: its card (section 7) plus its live numbers and statuses, and its last few log lines.

## 6. The log panel and the fight chart

- **The log panel** is a side panel that can be hidden, showing `LogEntry.to_text()` lines as they happen. By default it hides the chatter (`MOVE`, `STOP`, `TARGET`) and shows everything else; a toggle shows all. Clicking a unit filters the panel to lines about it. Lines are colored by side.
- **The fight chart** shows, per hero, damage dealt, healing and Shield given, and damage taken, live during the fight and in full on the result screen.
- **Its numbers come from one place:** a small pure `FightTally` in `src/sim/` that reads a log (the same counting `tools/sim_report.gd` does now). The sim runner switches to it, so the chart and the runner can't disagree.

## 7. Unit info

The hover card for a unit shows its name, role or archetype, its threat line (enemies), its stats, and one line per ability: basic attack, signature (with its trigger: "at 80 mana", "at fight start"), passives, and traits.

**Where the ability text comes from (question 3).** Kits have names but no player-facing text today. Two options:

- **(a) Hand-written text in the data:** an optional `"text"` on each ability and passive in `heroes.json` and `enemies.json` ("Taunts enemies within 2 hexes for 3s; he has x1.5 DEF while any is taunted"). Reads best, and it's content, so it stays data (rule 3). It can drift from the numbers after tuning; a test can check that every kit has text, but not that it's right.
- **(b) Generated from the effect data:** a describer in `src/sim/` that writes "Deals 100% ATK" or "Taunts enemies in a 2-hex circle around him for 3s". Always true to the numbers, but stiffer, and it needs a describe function for every effect, trigger, and area shape.

I'd do **(a) for the sentence, plus a generated numbers line** under it from what's easy and exact (damage per hit with `ValueBreakdown`, the cooldown or mana cost, ranges). The sentence says what it's for; the numbers stay true.

## 8. Placeholder look

- Uses the existing `UiStyle` palette and theme, `HoverCard`, and `Toast`. No new art files; everything on the board is drawn shapes and text.
- Heroes in warm colors, enemies in cold ones; a unit's side is always readable from its color alone.
- The old `Figure` and `CharacterArt` are left alone (they belong to the old art and go in phase 7).

## 9. Files

**New:**

| File | What it holds |
| --- | --- |
| `src/sim/fight_tally.gd` | per-unit damage dealt, healing and Shield given, damage taken, from a log (the old `FightTally`, shared with the sim runner) |
| `src/ui/practice/practice_session.gd` | Practice's state: the chosen encounter, the formation, the seed, the remembered formation |
| `src/ui/screens/encounter_list_screen.gd` | the list of encounters |
| `src/ui/screens/arena_screen.gd` | placement and fight on one screen: the board, controls, side panels, result |
| `src/ui/arena/arena_view.gd` | the board: plane-to-pixels mapping, hexes, zones, rocks, ground |
| `src/ui/arena/unit_token.gd` | one unit's token, bars, and status icons |
| `src/ui/arena/fight_player.gd` | owns the sim, advances time, hands new log entries to the view (the old `FightPlayer`, plus rewind) |
| `src/ui/fight_names.gd` | display names and colored log lines (the old `FightNames`) |
| `src/ui/widgets/fight_banners.gd` | the banner queue (the old `FightBanners`) |
| `src/ui/arena/fight_fx.gd` | the momentary things: shots, swipes, area warnings, floating numbers, tweened pushes |
| `src/ui/widgets/log_panel.gd`, `src/ui/widgets/fight_chart.gd` | the side panels (the chart is the old `FightChart`) |
| `tests/ui/ui_test_kit.gd` | the old headless UI helpers, plus board clicks and drags |
| `src/ui/unit_info.gd` | builds a unit's hover card text |

**Changed:** `title_screen.gd` (a Practice button), `main.gd` (the new screens), `tools/sim_report.gd` (uses `FightTally`), `tools/ui_screenshots.gd` (the new screens), `heroes.json` and `enemies.json` (ability text, if question 3 is (a)), and their defs (reading `"text"`).

## 10. Tests

UI tests run headless and drive time by hand, so they're deterministic.

| Test file | Covers |
| --- | --- |
| `test_fight_tally.gd` | the tally's sums match the log on the chaos fight and a content fight; the runner's numbers are unchanged |
| `test_practice_flow.gd` | title → list → placement → fight → result → place again / rematch / back, driven headless |
| `test_placement.gd` | legal and illegal drops, swaps, the Fight button's state and error text, the remembered formation (and a now-illegal hex) |
| `test_arena_view.gd` | plane-to-pixel mapping both ways; hex centers land where `HexGrid` says; heroes at the bottom |
| `test_fight_player.gd` | fake time advances the right number of ticks at each speed; pause; restart; rewinding gives the same state as running straight there; the player never mutates the sim outside `step()` |
| `test_fight_view.gd` | in a small scripted fight: tokens sit where the sim says (scaled); bars match HP, Shield, mana; no mana bar without a mana signature; a shot, an area warning, a push, a summon, and a death each get their visual and lose it on time |
| `test_every_encounter_plays.gd` | each Act 1 encounter played to the end through `ArenaScreen` with fake time, no errors, and every log kind it produced was handed to a visual or the log panel |
| `test_unit_info.gd` | every hero and enemy kit gets a card with every ability; with (a), every ability has text |
| screenshots | `tools/ui_screenshots.gd` gains the list, placement, a fight mid-way (with an area warning up), and the result |

## 11. Order of work (each step: code, tests, green run, commit)

1. **`FightTally`** in the sim, and the runner switched to it (fingerprints and runner numbers unchanged).
2. **`ArenaView` and tokens:** the board and units drawn from a `FightSetup`, static. Screenshot.
3. **Placement:** moving heroes, legality from the sim, enemy hover with reach, the remembered formation.
4. **`FightPlayer`:** live stepping, speeds, pause, restart, rewind, interpolation.
5. **What the fight shows (section 5)**, in two passes: bars, statuses, shots, swipes, and numbers first; then areas, displacement tweens, collapse, summons, deaths, phases, target lines, and Engage links.
6. **Log panel and fight chart.**
7. **Unit info cards** (and the ability text, if (a)).
8. **Practice flow:** the title button, encounter list, result screen, place again, rematch.
9. **Every encounter plays headless;** screenshots; a playtest build (the "Playtest build" workflow) for gate 1.
10. **Docs:** CLAUDE.md gains "How the UI works"; the plans are updated with what the playtest says.

## 12. Proposals to confirm

1. **Playback:** step the sim live while you watch (recommended, section 4), or run the whole fight first and replay its log?
2. **Speed controls:** the old set (pause, 0.5×, 1×, 2×, 4×, skip to the end, and the keys), plus stepping one tick while paused? Should the fight start paused, so you can look at the board first? And should the speed be remembered (the old game saved it to `user://settings.json`)?
3. **Ability text:** hand-written text in the data plus a generated numbers line (recommended), or all generated?
4. **The remembered formation:** only for this session, or saved to disk (`user://practice.json`) so it survives a restart? Per encounter, or one for all?
5. **Enemy reach on hover** in placement (section 3): useful for "fair", or too much help?
6. **Target lines:** always on, on hover only, or a toggle (recommended: hover, plus a toggle for all)?
7. **Practice extras for playtesting:** should Practice also let you swap in any enemy or move enemies around (a free sandbox), or stay to the nine hand-placed encounters for gate 1? (Recommended: the nine only; a free sandbox later if playtests want it.)
