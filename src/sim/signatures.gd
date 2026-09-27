class_name Signatures
extends RefCounted
## Signatures and their triggers (docs/plans/rebuild-phase1-arena-sim.md,
## section 5; the data is AbilityDef and TriggerDef).
##
## In each unit's turn, right after its mana regen (act):
##   - mana: a full bar fires it, and the bar empties. Not while Stunned: the
##     bar waits, full. With cast_ms, the unit first stands still for the cast
##     (CAST); a Stun cancels it (CAST_CANCELLED) and the bar stays full.
##   - hp_below, fight_start, at_time: once a fight, when the condition first
##     holds.
##   - count: every Nth event (Events) queues a fire for the unit's next turn.
## Everything but mana fires even while the unit is Stunned. A signature
## picks a fresh target each time it fires; with none in reach, it waits
## (a mana bar stays full, and other fires stay queued).
##   - would_fall runs in the deaths step instead: the first time the unit
##     would fall, it's left at 1 HP (SAVED) and the signature fires at once.


## The signature's part of the unit's turn. Returns true if the unit is
## casting, so it does nothing else this turn.
static func act(sim: CombatSim, unit: UnitState) -> bool:
	var signature: AbilityState = unit.signature
	if signature == null:
		return false
	var stunned: bool = not unit.statuses.is_empty() and Statuses.has_kind(unit, StatusDef.Kind.STUN)
	if signature.casting():
		if stunned:
			_cancel_cast(sim, unit, "stunned")
			return false
		if sim.tick < signature.cast_ends_at:
			return true
		_land_cast(sim, unit)
		return false
	var trigger: TriggerDef = signature.def.trigger
	match trigger.kind:
		TriggerDef.Kind.MANA:
			if not stunned and Mana.is_full(unit):
				var target: UnitState = pick_target(sim, unit)
				if target == null:
					return false
				if signature.def.cast_ticks > 0:
					_start_cast(sim, unit, target)
					return true
				unit.mana = 0
				_fire(sim, unit, target)
			return false
		TriggerDef.Kind.HP_BELOW:
			if not signature.fired and unit.hp > 0 and unit.hp * FixedMath.BP_ONE < unit.max_hp * trigger.threshold_bp:
				_queue_once(signature)
		TriggerDef.Kind.FIGHT_START:
			_queue_once(signature)
		TriggerDef.Kind.AT_TIME:
			if sim.tick >= trigger.at_ticks:
				_queue_once(signature)
	while signature.pending > 0:
		var target: UnitState = pick_target(sim, unit)
		if target == null:
			break
		signature.pending -= 1
		_fire(sim, unit, target)
	return false


## Events counts toward a count signature. A count that reaches its "every"
## queues a fire for the unit's next turn.
static func on_event(unit: UnitState, event: EffectDef.Trigger) -> void:
	var signature: AbilityState = unit.signature
	if signature == null or signature.def.trigger.kind != TriggerDef.Kind.COUNT or signature.def.trigger.event != event:
		return
	signature.count += 1
	if signature.count % signature.def.trigger.every == 0:
		signature.pending += 1


## The deaths step: a unit at 0 HP with an unspent would_fall signature is
## left at 1 HP, and the signature fires. Returns true if it was saved.
static func would_fall(sim: CombatSim, unit: UnitState) -> bool:
	var signature: AbilityState = unit.signature
	if signature == null or signature.fired or signature.def.trigger.kind != TriggerDef.Kind.WOULD_FALL:
		return false
	signature.fired = true
	unit.hp = 1
	var source := EffectSource.make(unit.id, signature.def.id, signature.def.name)
	var saved: LogEntry = sim.new_entry(LogEntry.Kind.SAVED, source)
	saved.target = unit.id
	saved.note = "would fall"
	sim.combat_log.add(saved)
	var target: UnitState = pick_target(sim, unit)
	if target != null:
		_fire(sim, unit, target)
	else:
		signature.pending += 1
	return true


## A fresh target for the signature by its rule, within its reach; null if
## nothing fits.
static func pick_target(sim: CombatSim, unit: UnitState) -> UnitState:
	var ability: AbilityDef = unit.signature.def
	if ability.targeting == "self":
		return unit
	var best: UnitState = null
	var best_distance: int = 0
	for enemy: UnitState in sim.standing_enemies_of(unit):
		if not _in_reach(unit, enemy):
			continue
		var distance: int = _distance_squared(unit, enemy)
		if best == null or distance < best_distance:
			best = enemy
			best_distance = distance
	return best


static func _queue_once(signature: AbilityState) -> void:
	if not signature.fired:
		signature.fired = true
		signature.pending += 1


static func _fire(sim: CombatSim, unit: UnitState, target: UnitState) -> void:
	var ability: AbilityDef = unit.signature.def
	EffectRunner.fire(sim, unit, ability, target, ability.reach_for(unit.stats.get_stat(UnitStats.Stat.RANGE)))


static func _start_cast(sim: CombatSim, unit: UnitState, target: UnitState) -> void:
	var signature: AbilityState = unit.signature
	signature.cast_ends_at = sim.tick + signature.def.cast_ticks
	signature.cast_target = target
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.CAST, EffectSource.make(unit.id, signature.def.id, signature.def.name))
	entry.target = target.id
	entry.end_tick = signature.cast_ends_at
	sim.combat_log.add(entry)


## The cast is done: it lands on its target, or (if that one fell or left its
## reach) a fresh one. With none, it's cancelled and the bar stays full.
static func _land_cast(sim: CombatSim, unit: UnitState) -> void:
	var signature: AbilityState = unit.signature
	var target: UnitState = signature.cast_target
	if target == null or not target.alive or (target != unit and not _in_reach(unit, target)):
		target = pick_target(sim, unit)
	if target == null:
		_cancel_cast(sim, unit, "no target")
		return
	signature.cast_ends_at = -1
	signature.cast_target = null
	unit.mana = 0
	_fire(sim, unit, target)


static func _cancel_cast(sim: CombatSim, unit: UnitState, reason: String) -> void:
	var signature: AbilityState = unit.signature
	signature.cast_ends_at = -1
	signature.cast_target = null
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.CAST_CANCELLED, EffectSource.make(unit.id, signature.def.id, signature.def.name))
	entry.note = reason
	sim.combat_log.add(entry)


static func _in_reach(unit: UnitState, target: UnitState) -> bool:
	var reach: int = unit.signature.def.reach_for(unit.stats.get_stat(UnitStats.Stat.RANGE)) * HexGrid.HEX
	return _distance_squared(unit, target) <= reach * reach


static func _distance_squared(unit: UnitState, other: UnitState) -> int:
	var dx: int = other.pos.x - unit.pos.x
	var dy: int = other.pos.y - unit.pos.y
	return dx * dx + dy * dy
