class_name Targeting
extends RefCounted
## Picks who an effect lands on. Only standing units (hp > 0) are picked.
##
## Row rules (confirmed design, see docs/plans/phase2-combat-sim.md):
##   enemy_front: the enemy front row; the back row only once the front is empty.
##   enemy_back:  items that reach the back row; the front row once the back is empty.
##   Within a row: the unit directly across (same column), else the nearest
##   one, with ties going to the left.


static func pick(target: EffectDef.Target, source: UnitState, hit_target: UnitState, sim: CombatSim) -> Array[UnitState]:
	return _pick(target, sim.allies_of(source), sim.enemies_of(source), source.column, source, hit_target, sim)


## Targets for a relic's effect. A relic stands nowhere, so enemy_front and
## enemy_back aim from column 0. `trigger_ally` is the
## ally that set off on_ally_below_hp, or null.
static func for_relic(target: EffectDef.Target, side: UnitSetup.Side, trigger_ally: UnitState, sim: CombatSim) -> Array[UnitState]:
	var foe_side: UnitSetup.Side = UnitSetup.Side.ENEMIES if side == UnitSetup.Side.HEROES else UnitSetup.Side.HEROES
	return _pick(target, sim.side_units(side), sim.side_units(foe_side), 0, null, trigger_ally, sim)


## `source` is null for relics (which can't use self or row targets);
## `hit_target` is the hit's target, or the trigger ally for trigger_ally.
static func _pick(target: EffectDef.Target, allies: Array[UnitState], foes: Array[UnitState], column: int, source: UnitState, hit_target: UnitState, sim: CombatSim) -> Array[UnitState]:
	var picked: UnitState = null
	match target:
		EffectDef.Target.ALL_ENEMIES:
			return _standing(foes)
		EffectDef.Target.ALL_ALLIES:
			return _standing(allies)
		EffectDef.Target.ROW_ALLIES:
			return row_allies(source, allies)
		EffectDef.Target.HIT_TARGET, EffectDef.Target.TRIGGER_ALLY:
			picked = hit_target
		EffectDef.Target.SELF:
			picked = source
		EffectDef.Target.ENEMY_FRONT:
			picked = _nearest_in_row(foes, UnitSetup.Row.FRONT, column)
			if picked == null:
				picked = _nearest_in_row(foes, UnitSetup.Row.BACK, column)
		EffectDef.Target.ENEMY_BACK:
			picked = _nearest_in_row(foes, UnitSetup.Row.BACK, column)
			if picked == null:
				picked = _nearest_in_row(foes, UnitSetup.Row.FRONT, column)
		EffectDef.Target.ENEMY_RANDOM:
			var standing: Array[UnitState] = _standing(foes)
			if not standing.is_empty():
				picked = standing[sim.rng.range_int(standing.size())]
		EffectDef.Target.ENEMY_LOWEST_HP:
			picked = _lowest_hp(foes)
		EffectDef.Target.ALLY_LOWEST_HP:
			picked = _lowest_hp(allies)
	var result: Array[UnitState] = []
	if picked != null and picked.is_standing():
		result.append(picked)
	return result


## The other standing allies in `source`'s row.
static func row_allies(source: UnitState, allies: Array[UnitState]) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for ally: UnitState in allies:
		if ally != source and ally.row == source.row and ally.is_standing():
			result.append(ally)
	return result


static func _standing(units: Array[UnitState]) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit: UnitState in units:
		if unit.is_standing():
			result.append(unit)
	return result


static func _nearest_in_row(units: Array[UnitState], row: UnitSetup.Row, column: int) -> UnitState:
	var best: UnitState = null
	var best_distance: int = 0
	for unit: UnitState in units:
		if unit.row != row or not unit.is_standing():
			continue
		var distance: int = absi(unit.column - column)
		if best == null or distance < best_distance or (distance == best_distance and unit.column < best.column):
			best = unit
			best_distance = distance
	return best


## Lowest HP *percentage* (design decision); ties go to the first in
## resolution order. Compares hp/max_hp by cross-multiplying, so no division.
static func _lowest_hp(units: Array[UnitState]) -> UnitState:
	var best: UnitState = null
	for unit: UnitState in units:
		if unit.is_standing() and (best == null or unit.hp * best.max_hp < best.hp * unit.max_hp):
			best = unit
	return best
