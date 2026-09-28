class_name Statuses
extends RefCounted
## Applies, ticks, and reads statuses (docs/plans/rebuild-phase1-arena-sim.md,
## section 8; the numbers are in data/statuses.json):
##   damage_over_time: every interval, each stack group deals
##       stacks x damage_per_stack (credited to whoever applied those stacks;
##       vs_shield_bp sets how hard it hits shields, and 0 skips them), then
##       the oldest stacks fall off (stacks_lost_per_interval, plus
##       stacks_lost_bp of the total, rounded up). The interval starts when
##       the status first lands; later stacks join the running interval.
##       defense_shred_per_stack lowers the unit's DEF while it lasts. Heals
##       remove a share of these stacks (cleanse_over_time).
##   root:    can't move (can still attack).
##   stun:    can't move or attack, and its cooldowns wait.
##   slow:    moves and attacks slow_bp slower; the strongest Slow wins.
##   taunt:   its target is whoever taunted it; a newer Taunt wins.
##   silence: no mana gain (mana comes in step 4).
##   marked:  takes damage_taken_bp more damage from hits and damage over
##            time; the strongest Mark wins.
## A timed status lasts its duration from the moment it lands; a new
## application refreshes it (and takes over as its source).


static func apply(sim: CombatSim, target: UnitState, status_id: String, stacks: int, duration_ticks: int, source: EffectSource) -> void:
	if not sim.content.statuses.has(status_id):
		push_error("Statuses: unknown status \"%s\"" % status_id)
		return
	var def: StatusDef = sim.content.statuses[status_id]
	if not target.alive or (not def.is_timed() and stacks <= 0):
		return
	var state: StatusState = find(target, status_id)
	if state == null:
		state = StatusState.new()
		state.def = def
		state.order = sim.content.status_ids.find(status_id)
		state.interval_left = def.interval_ticks
		_insert_in_order(target, state)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.STATUS_APPLIED, source)
	entry.target = target.id
	entry.status = def.id
	entry.status_name = def.name
	if def.is_timed():
		state.source = source
		state.ends_at = sim.tick + (duration_ticks if duration_ticks > 0 else def.duration_ticks)
		entry.end_tick = state.ends_at
	else:
		state.add_stacks(source, stacks)
		if def.max_stacks > 0 and state.total_stacks() > def.max_stacks:
			state.remove_oldest(state.total_stacks() - def.max_stacks)
		entry.amount = stacks
		entry.stacks = state.total_stacks()
	sim.combat_log.add(entry)


## Runs one tick of every status on every standing unit, in the fight's
## order: damage over time deals its damage, and timed statuses run out.
static func tick_all(sim: CombatSim) -> void:
	for unit: UnitState in sim.units:
		if not unit.alive or unit.statuses.is_empty():
			continue
		for state: StatusState in unit.statuses.duplicate():
			if state.def.is_timed():
				if sim.tick >= state.ends_at:
					_end(sim, unit, state)
				continue
			state.interval_left -= 1
			if state.interval_left <= 0:
				state.interval_left = state.def.interval_ticks
				_deal_damage_over_time(sim, unit, state)


static func find(unit: UnitState, status_id: String) -> StatusState:
	for state: StatusState in unit.statuses:
		if state.def.id == status_id:
			return state
	return null


static func has_kind(unit: UnitState, kind: StatusDef.Kind) -> bool:
	for state: StatusState in unit.statuses:
		if state.def.kind == kind:
			return true
	return false


## How much slower the unit moves and attacks (the strongest Slow).
static func slow_bp(unit: UnitState) -> int:
	var strongest: int = 0
	for state: StatusState in unit.statuses:
		if state.def.kind == StatusDef.Kind.SLOW:
			strongest = maxi(strongest, state.def.slow_bp)
	return strongest


## How much more damage the unit takes (the strongest Mark).
static func damage_taken_bp(unit: UnitState) -> int:
	var strongest: int = 0
	for state: StatusState in unit.statuses:
		if state.def.kind == StatusDef.Kind.MARKED:
			strongest = maxi(strongest, state.def.damage_taken_bp)
	return strongest


## DEF lost to damage over time (defense_shred_per_stack).
static func defense_shred(unit: UnitState) -> int:
	var shred: int = 0
	for state: StatusState in unit.statuses:
		if state.def.defense_shred_per_stack > 0:
			shred += state.total_stacks() * state.def.defense_shred_per_stack
	return shred


## Whoever taunted the unit, if a Taunt is on it and they still stand.
static func taunter(sim: CombatSim, unit: UnitState) -> UnitState:
	for state: StatusState in unit.statuses:
		if state.def.kind == StatusDef.Kind.TAUNT and state.source != null:
			var by: UnitState = sim.unit_by_id(state.source.unit_id)
			return by if by != null and by.alive else null
	return null


static func _deal_damage_over_time(sim: CombatSim, unit: UnitState, state: StatusState) -> void:
	for group: StatusState.StackGroup in state.groups:
		var damage: int = FixedMath.apply_bp(group.stacks * state.def.damage_per_stack, FixedMath.BP_ONE + damage_taken_bp(unit))
		if damage <= 0:
			continue
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.STATUS_DAMAGE, group.source)
		entry.target = unit.id
		entry.status = state.def.id
		entry.status_name = state.def.name
		entry.amount = damage
		entry.absorbed = sim.apply_damage_vs_shield(unit, damage, state.def.vs_shield_bp)
		unit.last_hit_source = group.source
		unit.last_hit_status = state.def.name
		if group.source.relic_side < 0 and group.source.unit_id != unit.id:
			unit.last_attacker = group.source.unit_id
		sim.combat_log.add(entry)
	var lost: int = state.def.stacks_lost_per_interval
	if state.def.stacks_lost_bp > 0:
		@warning_ignore("integer_division")
		lost += (state.total_stacks() * state.def.stacks_lost_bp + FixedMath.BP_ONE - 1) / FixedMath.BP_ONE
	state.remove_oldest(lost)
	if state.total_stacks() == 0:
		_end(sim, unit, state)


## Each damage-over-time status on `unit` loses `share_bp` of its stacks
## (times its cleanse_effectiveness_bp; rounded; oldest first). A heal does
## this (source null), and so does a cleanse effect. Timed statuses have no
## stacks, so they're never touched.
static func cleanse_over_time(sim: CombatSim, unit: UnitState, share_bp: int, source: EffectSource = null) -> void:
	for state: StatusState in unit.statuses.duplicate():
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
		if source != null:
			entry.set_source(source)
			entry.note = "cleansed by %s" % source.describe()
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
