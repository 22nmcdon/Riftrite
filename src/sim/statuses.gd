class_name Statuses
extends RefCounted
## Applies and ticks statuses. How each kind behaves (numbers come from
## data/statuses.json):
##   damage_over_time: every interval, each stack group deals
##       stacks * damage_per_stack (credited to whoever applied those stacks;
##       vs_shield_bp sets how hard it hits shields, and 0 skips them), then
##       the oldest stacks fall off (stacks_lost_per_interval, plus
##       stacks_lost_bp of the total, rounded up). The interval starts when the
##       status first lands; later stacks join the running interval.
##       defense_shred_per_stack lowers the unit's DEF while it lasts.
##       Heals remove a share of these stacks (see cleanse_over_time).
##   slow:   sits on items, not units. Each application lands on one random
##       item of the target (chosen by the sim's RNG, from items that aren't
##       the auto-attack) plus the target's auto-attack. Each stack slows that
##       item's cooldown by slow_bp_per_stack. Each application refreshes the
##       item's timer; when it runs out, all its stacks drop.
##   freeze: the unit's cooldowns stop until the timer runs out.
##   blind:  each stack makes one of the unit's hits miss.
## Stacks over max_stacks drop the oldest stacks.


static func apply(sim: CombatSim, target: UnitState, status_id: String, count: int, source: EffectSource, note: String = "") -> void:
	if count <= 0 or not target.is_standing():
		return
	var def: StatusDef = sim.content.statuses[status_id]
	if def.kind == StatusDef.Kind.SLOW:
		_apply_slow(sim, target, def, count, source)
		return
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


## Slow: one random non-auto-attack item, plus the auto-attack.
static func _apply_slow(sim: CombatSim, target: UnitState, def: StatusDef, count: int, source: EffectSource) -> void:
	var others: Array[ItemState] = []
	var chosen: Array[ItemState] = []
	for item: ItemState in target.items:
		if item.is_auto_attack:
			chosen.append(item)
		else:
			others.append(item)
	if not others.is_empty():
		chosen.insert(0, others[sim.rng.range_int(others.size())])
	for item: ItemState in chosen:
		if item.slow == null:
			item.slow = StatusState.new()
			item.slow.def = def
		item.slow.add_stacks(source, count)
		if def.max_stacks > 0 and item.slow.total_stacks() > def.max_stacks:
			item.slow.remove_oldest(item.slow.total_stacks() - def.max_stacks)
		item.slow.timer_ticks = def.duration_ticks
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.STATUS_APPLIED, source)
		entry.target = target.id
		entry.status = def.id
		entry.status_name = def.name
		entry.amount = count
		entry.stacks = item.slow.total_stacks()
		entry.note = "on %s" % _item_label(item)
		sim.combat_log.add(entry)


static func _item_label(item: ItemState) -> String:
	return "auto-attack (%s)" % item.def.name if item.is_auto_attack else item.def.name


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
		for item: ItemState in unit.items:
			if item.slow != null:
				item.slow.timer_ticks -= 1
				if item.slow.timer_ticks <= 0:
					var def: StatusDef = item.slow.def
					item.slow = null
					var entry := LogEntry.new()
					entry.tick = sim.tick
					entry.kind = LogEntry.Kind.STATUS_ENDED
					entry.target = unit.id
					entry.status = def.id
					entry.status_name = def.name
					entry.note = _item_label(item)
					sim.combat_log.add(entry)


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
		entry.absorbed = sim.apply_damage_vs_shield(unit, damage, state.def.vs_shield_bp)
		unit.last_hit_by = "%s from %s" % [state.def.name, group.source.describe()]
		sim.combat_log.add(entry)
		if state.def.heal_team_bp > 0:
			_heal_team(sim, group.source, FixedMath.apply_bp(damage, state.def.heal_team_bp))
	var lost: int = state.def.stacks_lost_per_interval
	if state.def.stacks_lost_bp > 0:
		@warning_ignore("integer_division")
		lost += (state.total_stacks() * state.def.stacks_lost_bp + FixedMath.BP_ONE - 1) / FixedMath.BP_ONE
	state.remove_oldest(lost)
	if state.total_stacks() == 0:
		_end(sim, unit, state)
	elif state.def.jumps:
		_jump(sim, unit, state)


## Blight: `amount` heals the applier's living team, split evenly (the first
## allies in resolution order get the remainder).
static func _heal_team(sim: CombatSim, source: EffectSource, amount: int) -> void:
	var applier: UnitState = sim.unit_by_id(source.unit_id)
	if applier == null or amount <= 0:
		return
	var team: Array[UnitState] = []
	for ally: UnitState in sim.allies_of(applier):
		if ally.is_standing():
			team.append(ally)
	if team.is_empty():
		return
	@warning_ignore("integer_division")
	var each: int = amount / team.size()
	var remainder: int = amount % team.size()
	for i: int in team.size():
		var share: int = each + (1 if i < remainder else 0)
		if share > 0:
			EffectRunner.heal(sim, team[i], share, source)


## Plasma: moves the stacks to the nearest other standing unit on the host's
## side (column distance, +1 for a different row; ties go to resolution
## order). Stays put if there's nobody else.
static func _jump(sim: CombatSim, host: UnitState, state: StatusState) -> void:
	var best: UnitState = null
	var best_distance: int = 0
	for other: UnitState in sim.allies_of(host):
		if other == host or not other.is_standing():
			continue
		var distance: int = absi(other.column - host.column) + (0 if other.row == host.row else 1)
		if best == null or distance < best_distance:
			best = other
			best_distance = distance
	if best == null:
		return
	host.statuses.erase(state)
	var landing: StatusState = best.find_status(state.def.id)
	if landing == null:
		landing = StatusState.new()
		landing.def = state.def
		landing.order = state.order
		landing.interval_left = state.def.interval_ticks
		_insert_in_order(best, landing)
	for group: StatusState.StackGroup in state.groups:
		landing.add_stacks(group.source, group.stacks)
	var entry := LogEntry.new()
	entry.tick = sim.tick
	entry.kind = LogEntry.Kind.STATUS_JUMPED
	entry.target = best.id
	entry.note = host.id
	entry.status = state.def.id
	entry.status_name = state.def.name
	entry.stacks = landing.total_stacks()
	sim.combat_log.add(entry)


## A heal weakens damage over time: each damage-over-time status on `unit`
## loses `share_bp` of its stacks (rounded, oldest first).
static func cleanse_over_time(sim: CombatSim, unit: UnitState, share_bp: int) -> void:
	for state: StatusState in unit.statuses.duplicate():
		if state.def.kind != StatusDef.Kind.DAMAGE_OVER_TIME:
			continue
		var removed: int = FixedMath.apply_bp(state.total_stacks(), FixedMath.apply_bp(share_bp, state.def.cleanse_effectiveness_bp))
		if removed <= 0:
			continue
		state.remove_oldest(removed)
		var entry := LogEntry.new()
		entry.tick = sim.tick
		entry.kind = LogEntry.Kind.STATUS_REDUCED
		entry.target = unit.id
		entry.status = state.def.id
		entry.status_name = state.def.name
		entry.amount = removed
		entry.note = "healed"
		sim.combat_log.add(entry)
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
