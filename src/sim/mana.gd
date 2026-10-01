class_name Mana
extends RefCounted
## Mana (docs/plans/rebuild-phase1-arena-sim.md, section 5), for units with a
## mana bar (UnitDef.mana). It's kept in hundredths, so "1 per 10 damage
## taken" stays an integer; the data gives whole mana.
##   - It comes from each basic attack that fires (per_attack, or
##     per_far_attack at a far enough target: phase 4), damage taken,
##     Shield included (per_10_damage_taken), regen (regen_per_s), and start.
##   - Silence blocks every source; Stun doesn't.
##   - The bar stops at max; a full bar fires the mana signature and empties.
##   - mana_drain takes it away (logged). A unit without a bar ignores both
##     Silence and drains.
## Regen runs in CombatSim's unit update: it's every tick, so it's inlined
## there (UnitState.mana_regen). Gains aren't logged: each comes from something that is (an attack firing,
## a hit landing, time passing), so the bar can be rebuilt from the log.

const SCALE: int = 100


static func on_attack(sim: CombatSim, unit: UnitState) -> void:
	var mana: ManaDef = unit.def.mana
	if mana == null:
		return
	var per: int = mana.per_attack
	if mana.far_hexes > 0 and unit.target != null:
		var far: int = mana.far_hexes * HexGrid.HEX
		if ArenaPlane.length_sq(unit.target.pos - unit.pos) >= far * far:
			per = mana.per_far_attack
	gain(sim, unit, per * SCALE)


static func on_damage_taken(sim: CombatSim, unit: UnitState, damage: int) -> void:
	if unit.def.mana != null and unit.def.mana.per_10_damage_taken > 0:
		@warning_ignore("integer_division")
		gain(sim, unit, FixedMath.apply_bp(damage * unit.def.mana.per_10_damage_taken * SCALE / 10, unit.def.mana.taken_bp))


## Adds `hundredths` of mana, up to a full bar, unless the unit is Silenced.
static func gain(sim: CombatSim, unit: UnitState, hundredths: int) -> void:
	if unit.def.mana == null or hundredths <= 0:
		return
	if not unit.statuses.is_empty() and Statuses.has_kind(unit, StatusDef.Kind.SILENCE):
		return
	unit.mana = mini(unit.mana + hundredths, maxi(unit.def.mana.max * SCALE, unit.mana_store))


## Gives the unit the bar `mana` describes, at its start (null: no bar).
static func set_bar(unit: UnitState, mana: ManaDef) -> void:
	if mana == null:
		unit.mana = 0
		unit.mana_cap = 0
		unit.mana_regen = 0
		return
	unit.mana = mana.start * SCALE
	unit.mana_cap = mana.max * SCALE
	@warning_ignore("integer_division")
	unit.mana_regen = mana.regen_per_s * SCALE / FixedMath.TICKS_PER_SECOND


static func is_full(unit: UnitState) -> bool:
	return unit.def.mana != null and unit.mana >= unit.def.mana.max * SCALE


## A mana_drain effect: takes `amount` whole mana (as much as there is).
static func drain(sim: CombatSim, unit: UnitState, amount: int, source: EffectSource) -> void:
	var drained: int = mini(amount * SCALE, unit.mana)
	unit.mana -= drained
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.MANA_DRAIN, source)
	entry.target = unit.id
	entry.amount = drained
	if unit.def.mana == null:
		entry.note = "no mana"
	sim.combat_log.add(entry)


## "12.5" for 1250 hundredths, "12" for 1200.
static func text(hundredths: int) -> String:
	@warning_ignore("integer_division")
	var whole: String = str(hundredths / SCALE)
	var rest: int = hundredths % SCALE
	if rest == 0:
		return whole
	return "%s.%s" % [whole, ("%02d" % rest).rstrip("0")]
