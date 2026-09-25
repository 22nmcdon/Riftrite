# Plan: the run state and actions (Phase 3, step 4)

Status: **proposed, awaiting approval and answers (end of file).** Nothing here is built yet.

This step builds everything a run *holds* between fights, the **actions** that change it, the bridge to and from the combat sim, and save/load. The day structure (Caravan, stops, fights, losses), prices, and offers are step 5. The UI (step 7) will only ever call these actions.

Same rules as the sim (CLAUDE.md rule 1):
- pure logic in `src/run/`, no nodes
- integers only
- deterministic from the run seed
- tested headless

## What a run holds

`src/run/run_state.gd`, with `RunState`:

| Field | What it is |
| --- | --- |
| `seed`, `rng` | The run seed and its `SimRng`, whose state is saved. Each fight gets its own seed from this RNG. |
| `act`, `day`, `step`, `attempt` | Where the run is (step 5 fills these in) |
| `gold`, `keys` | Currencies |
| `heroes` | The roster (up to 6), in formation order: `RunHero` |
| `stash` | Unequipped items, in order: 6 slots that work like a hero row (sizes count) |
| `pouch` | Essence ids waiting to be socketed (cap 8, from tuning) |
| `relics` | Relic ids held (any number, never removed) |
| `wins`, `losses` | Fight record |
| `discovered` | Synergy ids found this run (the Codex comes with meta, Phase 4) |
| `legendaries_seen` | Legendary item ids already offered or taken (at most once per run) |
| `next_uid` | Counter for item ids |

- **`RunHero`:**
  - `hero_id`, `rank` (0 = C to 3 = S), `specialization_id`, and `needs_specialization` (they just reached B and haven't picked yet)
  - `row` (front or back), `benched`
  - `items`: the row, left to right
- **`RunItem`:** `uid` (unique in the run, so two copies can be told apart), `item_id`, `tier`, `essence_ids` (socket order), and `xp`.
- **Formation:** within each row, heroes stand left to right in roster order. A hero's row holds items in order. Capacity is the sum of sizes against their slots (4 + rank), as in the sim.

## Actions

`src/run/run_actions.gd`:
- Each action checks it's allowed, applies it, and returns an `ActionResult` (`ok`, `error` in plain words for the UI, and a short `note` for a run log).
- A failed action changes nothing.

| Action | Rules |
| --- | --- |
| `move_item(uid, to, index)` | Between any hero's row and the stash, or within one. The destination needs the space, and a hero can hold only **one auto-attack item**. |
| `set_formation(hero, row, index)` | Moves a hero to a row and position |
| `set_benched(hero, benched)` | Keeps **1–5 fielded** |
| `infuse(uid, pouch_index)` | Takes an essence from the pouch into the item's next socket. Sockets come from rarity (2 for Epic/Legendary, else 1). A second essence **resets XP** (single → alloy or pure double). |
| `reforge(uid)` | Removes the item's infusion and resets its XP; costs gold (the price is step 5's economy data; step 5 also limits it to the Forge stop) |
| `combine_items(keep_uid, new_uid)` | Same item, same tier, below S, not Legendary. The result sits where `keep` was, one tier up. If `new` has an infusion, it replaces `keep`'s (XP and all); if not, `keep`'s stays. |
| `add_hero(hero_id, rank)` | For the Caravan and the run start. If the same hero is already held **at the same rank**, they combine: rank +1, and the one you have keeps their specialization and items. A different rank is refused (the Caravan never offers one). Otherwise it's a new hero, up to 6, fielded if fewer than 5 are fielded. Reaching B sets `needs_specialization`. |
| `choose_specialization(hero, spec_id)` | Only when `needs_specialization`, and only one of that hero's three |
| `add_item(item_id, tier)` | Into the stash (see question 2 when it's full). Records Legendaries seen. |
| `add_essence(essence_id)` | Into the pouch (see question 2 when it's full) |
| `add_relic(relic_id)` | Taken for good (turning one down just means not calling this) |

Gold is added and spent through two helpers, which refuse to go below 0.

## To and from the sim

`src/run/run_fight.gd`:
- **`setup_for(state, content, encounter_id) -> FightSetup`:**
  - fielded heroes in formation order, benched heroes on the bench
  - each hero's rank, specialization, and items (tiers, essences, XP)
  - the guild's relics and the encounter's relics
  - a fight seed drawn from the run RNG
- **`apply_result(state, result)`:**
  - writes infusion XP back to each item (matched by hero and slot, then uid)
  - adds newly active synergies to `discovered`
  - records a win (a tie counts) or a loss

  Rewards, drops, and replays are step 5.

## Save and load

- **Format:** `RunState.to_dict()` and `RunState.from_dict(data, content)` give plain JSON, with a `version` field.
- **Loading:** it checks every reference (heroes, items, essences, relics, specializations) and the invariants (capacities, sockets, 1–5 fielded, one auto-attack item). It reports errors instead of loading a broken run.
- **Files:** `src/run/run_save.gd` writes `user://run.json` after each action (the only file I/O). Tests use the dictionaries directly.
- **The promise:** save, load, and continue gives exactly what continuing without saving would. The RNG state is saved, so the next fight seed matches.

## Tests (`tests/run/`)

- **Moving:** between rows and the stash; capacity; one auto-attack item; formation; 1–5 fielded.
- **Infusing and reforging:**
  - sockets by rarity
  - an XP reset on the second essence
  - a full item refused
  - reforging costs gold and clears the infusion and XP
- **Combining items:** same id and tier; not at S; not Legendary; whose infusion stays; position kept; different tiers refused.
- **Heroes:**
  - combining at the same rank; a different rank refused
  - the roster cap
  - reaching B needs a specialization, and the pick is checked
- **Sim bridge:**
  - `setup_for` builds a valid `FightSetup` that matches the state
  - `apply_result` writes XP back and records discoveries
- **Save/load:**
  - a round trip gives an equal state
  - broken saves are rejected with clear errors
  - save/load/continue matches continue
- **Determinism:** the same seed and the same actions give the same fight seeds.

## Questions

1. **Reforging:** does removing an infusion **destroy** the essences, or return them to the pouch? I'd say destroyed. That's "the trade-off is commitment", and returning them would make reforging a free swap except for the gold.
2. **Full stash or pouch:** when an item or essence arrives (a drop, a reward, a purchase) and there's no room, what happens? My draft:
   - you choose what to discard: the new one or something you hold
   - buying at the Caravan simply isn't allowed without room
3. **New heroes:** a newly recruited hero joins **fielded** if fewer than 5 are fielded (back row, rightmost), otherwise **benched**. OK as a default the player then rearranges?
