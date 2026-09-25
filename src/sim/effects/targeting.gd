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
	var allies: Array[UnitState] = sim.allies_of(source)
	var foes: Array[UnitState] = sim.enemies_of(source)
	var picked: UnitState = null
	match target:
		EffectDef.Target.ALL_ENEMIES:
			return _standing(foes)
		EffectDef.Target.ALL_ALLIES:
			return _standing(allies)
		EffectDef.Target.LINKED_ALLY, EffectDef.Target.LINKED_LEFT_ALLY, EffectDef.Target.LINKED_RIGHT_ALLY, EffectDef.Target.LINKED_ALLIES, EffectDef.Target.ROW_ALLIES:
			return linked(target, source, allies)
		EffectDef.Target.HIT_TARGET:
			picked = hit_target
		EffectDef.Target.SELF:
			picked = source
		EffectDef.Target.ENEMY_FRONT:
			picked = _nearest_in_row(foes, UnitSetup.Row.FRONT, source.column)
			if picked == null:
				picked = _nearest_in_row(foes, UnitSetup.Row.BACK, source.column)
		EffectDef.Target.ENEMY_BACK:
			picked = _nearest_in_row(foes, UnitSetup.Row.BACK, source.column)
			if picked == null:
				picked = _nearest_in_row(foes, UnitSetup.Row.FRONT, source.column)
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


## Linked targets: allies standing next to `source` in its row (columns are
## fixed at fight start, so a fallen neighbor leaves a gap, not a new link).
static func linked(target: EffectDef.Target, source: UnitState, allies: Array[UnitState]) -> Array[UnitState]:
	var left: UnitState = null
	var right: UnitState = null
	var row_mates: Array[UnitState] = []
	for ally: UnitState in allies:
		if ally == source or ally.row != source.row or not ally.is_standing():
			continue
		row_mates.append(ally)
		if ally.column == source.column - 1:
			left = ally
		elif ally.column == source.column + 1:
			right = ally
	var result: Array[UnitState] = []
	match target:
		EffectDef.Target.LINKED_ALLY:
			if left != null:
				result.append(left)
			elif right != null:
				result.append(right)
		EffectDef.Target.LINKED_LEFT_ALLY:
			if left != null:
				result.append(left)
		EffectDef.Target.LINKED_RIGHT_ALLY:
			if right != null:
				result.append(right)
		EffectDef.Target.LINKED_ALLIES:
			if left != null:
				result.append(left)
			if right != null:
				result.append(right)
		EffectDef.Target.ROW_ALLIES:
			result = row_mates
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
