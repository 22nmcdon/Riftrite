# Plan: rank-B specializations (Phase 3, step 3)

Status: **proposed, awaiting approval and answers (end of file).** Nothing here is built yet.

Design (`docs/design.md`, `docs/tiers-backup-specialization.md`):
- **The pick:** each class has three specializations, and a hero picks one on reaching rank B.
- **Recruits:** a hero recruited at B or above comes with a preset one.
- **Changing it:** only through an event that offers retraining.
- **What this step covers:** what a specialization does *in a fight*. Picking one, presets, and retraining are run-layer work (steps 4 and 5).

## What a specialization can do

A specialization is data in `data/specializations.json`, applied at fight start to the hero who has it. It adds to the hero; it never replaces their class or signature passive. It can have any of these:

1. **Auras** from the hero, using the existing aura vocabulary. That means stat boosts on the hero (`holder`), boosts to linked or all allies, and a new `holder_items` target: every item the hero holds, optionally with a filter (tag, size, applies, essence).

   ```json
   "auras": [ {"target": "holder", "stat": "def_bp", "value": 12500},
              {"target": "holder_items", "filter": {"tag": "defense"}, "stat": "shield_bp", "value": 12000} ]
   ```
2. **An ability:** a slotless effect that fires on its own cooldown, like a Backup effect but while fielded. It's numbered like an item: base + the hero's stats, no tier. It can't be infused.

   ```json
   "ability": { "name": "Stand Fast", "cooldown_ms": 6000,
                "effects": [ {"trigger": "on_fire", "type": "shield", "amount": 10, "scaling": {"def": 6000}, "target": "self"} ] }
   ```
3. **A new basic attack,** replacing the hero's own (still unupgradable, and still replaced by an auto-attack item).

**Why not relic-style flat numbers:** a specialization belongs to one hero, so its numbers scale from that hero's stats like the hero's items do. Relic and synergy numbers stay flat.

**The log names it:** `brannoc · Stand Fast (Bulwark) gives brannoc 28 shield`, and `brannoc · Bulwark aura starts: ...`.

## Code shape

- **Definition:** `src/sim/defs/specialization_def.gd`, holding its id, name, class, auras, an optional ability (read like a `BackupDef` and turned into a slotless item), and an optional basic attack.
- **Setup:** `UnitSetup.specialization` (or null). `SetupBuilder.hero()` takes a specialization id. Balance parties can name one with `"specialization": "bulwark"`.
- **Checks:**
  - **Content (`ContentDb`):** a specialization's class exists, its ability's targets are valid, and its statuses exist.
  - **Fight setup (`FightSetup.validate`):** the specialization's class matches the hero's class, and a rank-C hero has none. (The sim allows a B+ hero with no specialization, so tests stay small; the run layer will require the pick.)
- **In the fight:**
  - The ability becomes an item in the unit's `items` (after the basic attack, before the row), firing on its cooldown.
  - Its auras run through the same aura code as items, with the hero as holder.
  - `holder_items` joins the aura targets.

## Draft content (placeholders)

There are 3 per class for the four current classes, so 12 in all. The other classes come with the content step.

| Class | Specialization | Does |
| --- | --- | --- |
| Warden | Bulwark | ×1.25 DEF; every 6s shields self |
| Warden | Oathwall | Linked allies ×1.15 DEF; Defense items' shields ×1.2 |
| Warden | Emberguard | New basic attack that also applies 1 Burn |
| Striker | Duelist | Weapons +10% crit chance |
| Striker | Skirmisher | ×1.2 ATSP; Small items fire 10% faster |
| Striker | Reaver | Every 5s, strikes the lowest-HP enemy |
| Mender | Hearthkeeper | Healing items heal ×1.2 |
| Mender | Wardweaver | Every 5s, shields the lowest-HP ally |
| Mender | Plaguedoctor | Items that apply Poison: ×1.25 damage over time |
| Arcanist | Pyromancer | Items that apply Burn: ×1.25 damage over time |
| Arcanist | Hexer | New basic attack that hits every enemy for less |
| Arcanist | Stormcaller | Magic items fire 15% faster |

## Tests

- **Data:** reading, and rejecting a bad class, a bad ability, unknown keys, and a `holder_items` aura anywhere but a specialization.
- **Setup checks:** a class mismatch and a rank-C specialization are rejected.
- **Auras:** they reach the holder, the holder's (filtered) items, and allies, and stop when the hero falls.
- **Ability:** it fires on its cooldown, scales from the hero's stats, takes no slot, and is logged with the specialization's name.
- **Basic attack:** a new basic attack replaces the hero's, and an auto-attack item still replaces that.
- **Backup:** covered by question 2.
- **Determinism and balance:** the determinism fight includes a specialization, and balance parties can name one.

## Questions

1. **What a specialization changes:** are auras, an ability, and/or a new basic attack the right toolbox? Or should specializations also be able to change the hero's **Backup** effect, or their base stats directly?
2. **In backup:** does a benched hero's specialization do anything? I'd say its **ally-wide auras apply from the bench** (like a Backup aura), and the rest (self auras, the ability, the basic attack) doesn't.
3. **Ranks above B:** does a specialization stay the same at A and S, or should it grow (for example, stronger numbers per rank, or a second perk at S)? I'd keep it the same for now; rank already boosts the hero's stats by 25% each.
