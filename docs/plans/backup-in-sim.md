# Plan: backup heroes in the combat sim

Status: **approved and built.** Answers: backup-only items do what their own data says when fielded (often nothing); infusions work in backup mode; backup fires earn infusion XP; rarity rules as proposed.

Design (docs/design.md, docs/tiers-backup-specialization.md): with 6 heroes and at most 5 fielded, at least one sits in backup, and the player may bench more. A backup hero's **Backup effect** applies, and so do the **backup modes** of the items in their row. Backup-only items exist.

## How it works in a fight

- **Backup heroes aren't on the field.** They can't be targeted, don't take Rift Collapse damage, can't fall, and don't count for victory or defeat. Fewer fielded heroes means fewer bodies to absorb collapse, which is the intended trade-off.
- **Their stats still count:** backup effects scale from the backup hero's stats (and rank), like everything else.
- **What fires from backup:**
  - the hero's own Backup effect
  - each item's backup mode, if it has one
  - items without a backup mode do nothing while benched
- **Log lines say where it came from,** e.g. `[4.00s] vell · Old Lantern (backup) heals wren for 9`. A hero's own Backup effect uses the backup's `name` (`vell · Lantern Vigil (backup)`).

## Data shape

A `"backup"` block, on a hero (their Backup effect) or on an item (its backup mode):

```json
"backup": {
  "cooldown_ms": 5000,
  "effects": [ { "trigger": "on_fire", "type": "heal", "amount": 4, "scaling": {"mgk": 3000}, "target": "ally_lowest_hp" } ],
  "auras":   [ { "target": "all_allies", "stat": "def_bp", "value": 11000 } ]
}
```

- **effects:** fire every `cooldown_ms`, using the existing vocabulary. Targets that need a spot on the field don't work from backup and are rejected: `self`, the `linked_*` variants, `row_allies`, and `hit_target`. The rest are fine: all allies, lowest-HP ally, and any enemy target (enemy targeting treats the backup hero as standing at column 0).
- **auras:** continuous, using the existing aura vocabulary, but only `all_allies` makes sense from backup.
- **Backup-only items:** `"backup_only": true` marks an item that has only a backup mode. It needs no normal effects.

## Other rules

- **Limits:** the sim allows at most 5 fielded heroes and 6 heroes in total. It still allows fewer than 3 fielded, so tests can stay small; the run layer will enforce 3–5.
- **Rarity checks in the data checker:**
  - Common items can't have a backup mode (they only get one through Oathbinding, which doesn't exist yet).
  - Legendary items must have one.
  - Uncommon, Rare and Epic are free.

## Draft content

- **Hero Backup effects:**
  - Brannoc: all allies +10% DEF
  - Wren: every 4s, a strike on a random enemy
  - Vell: every 5s, heal the ally with the lowest HP %
  - Odo: every 6s, 1 Burn on every enemy
- **Items:** a few items get backup modes, and one backup-only item is added.
- **Parties:** a new party in `tools/sim_parties.json` uses a bench, and the balance report shows backup output.

## Tests

- Backup heroes can't be targeted and don't take collapse damage.
- Their Backup effect and item backup modes fire on cooldown and scale from their stats.
- Items without a backup mode do nothing from backup.
- Invalid targets are rejected.
- Roster limits are checked.
- Rarity rules are checked.
- The determinism fight includes a bench.
