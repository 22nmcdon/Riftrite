class_name Statuses
extends RefCounted
## Applies and ticks statuses. How each kind behaves (numbers come from
## data/statuses.json):
##   damage_over_time: every interval, each stack group deals
##       stacks * damage_per_stack (credited to whoever applied those stacks;
##       shield first, like all damage), then the oldest
##       stacks_lost_per_interval stacks fall off. The interval starts when
##       the status first lands; later stacks join the running interval.
##   slow:   each stack slows the unit's cooldowns by slow_bp_per_stack. Each
##       application refreshes the timer; when it runs out, all stacks drop.
##       At `threshold` stacks it turns into another status (Frost -> Freeze).
##   freeze: the unit's cooldowns stop until the timer runs out.
##   blind:  each stack makes one of the unit's hits miss.
## Stacks over max_stacks drop the oldest stacks.


static func apply(sim: CombatSim, target: UnitState, status_id: String, count: int, source: EffectSource, note: String = "") -> void:
	if count <= 0 or not target.is_standing():
		return
	var def: StatusDef = sim.content.statuses[status_id]
	var state: StatusState = target.find_status(status_id)
	if state == null:
		state = StatusState.new()
		state.def = def
		state.order = sim.content.status_ids.find(status_id)
		state.interval_left = def.interval_ticks
		_insert_in_order(target, state)
	state.add_stacks(source, count)
	if def.max_stacks > 0 and state.total_stacks() > def.max_stacks:
		state.remove_oldest(state.total_stacks() - def.max_stacks)
	if def.duration_ticks > 0:
		state.timer_ticks = def.duration_ticks

	var entry: LogEntry = sim.new_entry(LogEntry.Kind.STATUS_APPLIED, source)
	entry.target = target.id
	entry.status = def.id
	entry.status_name = def.name
	entry.amount = count
	entry.stacks = state.total_stacks()
	entry.note = note
	sim.combat_log.add(entry)

	if def.has_threshold and state.total_stacks() >= def.threshold_stacks:
		if def.threshold_consume:
			_end(sim, target, state)
		var threshold_def: StatusDef = sim.content.statuses[def.threshold_status_id]
		apply(sim, target, threshold_def.id, def.threshold_apply_stacks, source, "(from %d %s)" % [def.threshold_stacks, def.name])


## Runs one tick of every status on every living unit, in resolution order.
static func tick_all(sim: CombatSim) -> void:
	for unit: UnitState in sim.units:
		if not unit.alive:
			continue
		for state: StatusState in unit.statuses.duplicate():
			match state.def.kind:
				StatusDef.Kind.DAMAGE_OVER_TIME:
					state.interval_left -= 1
					if state.interval_left <= 0:
						state.interval_left = state.def.interval_ticks
						_deal_damage_over_time(sim, unit, state)
				StatusDef.Kind.SLOW, StatusDef.Kind.FREEZE:
					if state.timer_ticks > 0:
						state.timer_ticks -= 1
						if state.timer_ticks == 0:
							_end(sim, unit, state)
				StatusDef.Kind.BLIND:
					pass


## If the unit is blinded, uses up one stack and returns true (the hit misses).
static func consume_blind(sim: CombatSim, unit: UnitState) -> bool:
	for state: StatusState in unit.statuses:
		if state.def.kind == StatusDef.Kind.BLIND:
			state.remove_oldest(1)
			if state.total_stacks() == 0:
				_end(sim, unit, state)
			return true
	return false


static func _deal_damage_over_time(sim: CombatSim, unit: UnitState, state: StatusState) -> void:
	for group: StatusState.StackGroup in state.groups:
		var damage: int = group.stacks * state.def.damage_per_stack
		if damage <= 0:
			continue
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.STATUS_DAMAGE, group.source)
		entry.target = unit.id
		entry.status = state.def.id
		entry.status_name = state.def.name
		entry.amount = damage
		entry.absorbed = sim.apply_damage(unit, damage)
		unit.last_hit_by = "%s from %s" % [state.def.name, group.source.describe()]
		sim.combat_log.add(entry)
	state.remove_oldest(state.def.stacks_lost_per_interval)
	if state.total_stacks() == 0:
		_end(sim, unit, state)


static func _end(sim: CombatSim, unit: UnitState, state: StatusState) -> void:
	unit.statuses.erase(state)
	var entry := LogEntry.new()
	entry.tick = sim.tick
	entry.kind = LogEntry.Kind.STATUS_ENDED
	entry.target = unit.id
	entry.status = state.def.id
	entry.status_name = state.def.name
	sim.combat_log.add(entry)


static func _insert_in_order(unit: UnitState, state: StatusState) -> void:
	var index: int = 0
	while index < unit.statuses.size() and unit.statuses[index].order < state.order:
		index += 1
	unit.statuses.insert(index, state)
