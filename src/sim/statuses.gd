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
##   warded:  takes damage_reduced_bp less (phase 4); the strongest Ward
##            wins, and a Mark and a Ward add up.
##   undying: its HP can't drop below 1 (CombatSim's deaths step).
##   engaged: held by an engager (Engage sets and clears it with hold and
##            release; effects can't apply it).
## A timed status lasts its duration from the moment it lands; a new
## application refreshes it (and takes over as its source). Phase 5c step
## 5c: a stacking boost adds a stack with its own timer instead, and under
## the heroes' rule marks_stack (Hunter's Engine) a hero's Mark adds a
## stack as it refreshes.


## `marks_stack`: a Mark that stacks as it refreshes, as under Hunter's
## Engine (the effect's own, phase 5c step 6b: Hunter's Chalk).
static func apply(sim: CombatSim, target: UnitState, status_id: String, stacks: int, duration_ticks: int, source: EffectSource, marks_stack: bool = false) -> void:
	if not sim.content.statuses.has(status_id):
		push_error("Statuses: unknown status \"%s\"" % status_id)
		return
	var def: StatusDef = sim.content.statuses[status_id]
	if def.kind == StatusDef.Kind.ENGAGED:
		push_error("Statuses: \"%s\" is set only by the Engage trait" % status_id)
		return
	if not target.alive or (not def.is_timed() and stacks <= 0):
		return
	# The heroes' rules (phase 5c step 5c): The Unbending blocks what enemies
	# put on heroes; Crown of the Hollow King doubles the keywords heroes
	# apply; Everflame makes those on enemies last.
	var rules: SideRules = sim.hero_rules
	var lasting: bool = false
	if rules.any():
		var by_heroes: bool = _by_heroes(sim, source)
		if rules.unbending and target.side == EffectSource.Team.HEROES and not by_heroes:
			_resist(sim, target, def, source)
			return
		if by_heroes and not def.keyword.is_empty():
			if rules.keywords_twice:
				stacks *= 2
				duration_ticks = 2 * (duration_ticks if duration_ticks > 0 else def.duration_ticks)
			lasting = rules.keywords_last and target.side != EffectSource.Team.HEROES
	var state: StatusState = find(target, status_id)
	var fresh: bool = state == null
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
	if def.stacking:
		state.source = source
		var lasts: int = duration_ticks if duration_ticks > 0 else def.duration_ticks
		state.stack_ends.append(sim.tick + lasts if lasts > 0 else StatusState.NEVER)
		if def.max_stacks > 0 and state.stack_ends.size() > def.max_stacks:
			state.stack_ends.remove_at(0)
		state.ends_at = int(state.stack_ends.max())
		entry.end_tick = state.ends_at if state.ends_at < StatusState.NEVER else -1
		entry.stacks = state.stack_ends.size()
		entry.amount = 1
	elif def.is_timed():
		state.source = source
		state.lasting = state.lasting or lasting
		state.ends_at = StatusState.NEVER if state.lasting else sim.tick + (duration_ticks if duration_ticks > 0 else def.duration_ticks)
		entry.end_tick = state.ends_at if not state.lasting else -1
		if def.kind == StatusDef.Kind.MARKED and (marks_stack or sim.hero_rules.marks_stack and _by_heroes(sim, source)):
			var added: int = 2 if sim.hero_rules.keywords_twice else 1
			state.stacks = added if fresh else state.stacks + added
			entry.stacks = state.stacks
	else:
		state.lasting = state.lasting or lasting
		state.add_stacks(source, stacks)
		if def.max_stacks > 0 and state.total_stacks() > def.max_stacks:
			state.remove_oldest(state.total_stacks() - def.max_stacks)
		entry.amount = stacks
		entry.stacks = state.total_stacks()
	sim.combat_log.add(entry)
	if def.kind == StatusDef.Kind.TAUNT and sim.taunt_auras:
		sim.refold_auras()
	elif def.kind == StatusDef.Kind.BOOST and (fresh or def.stacking):
		sim.refold_auras()
		if def.until_attack:
			sim.listen()
	elif def.kind == StatusDef.Kind.GROUNDED and fresh and target.flying:
		_ground(sim, target, source)


## Grounded (phase 5c step 6b): a flier walks while it lasts. Over a rock
## or a unit, it's set down on the nearest free safe spot (logged as a PUSH
## noted "grounded").
static func _ground(sim: CombatSim, unit: UnitState, source: EffectSource) -> void:
	unit.flying = false
	unit.airborne = false
	if sim.fits_ground(unit, unit.pos):
		return
	var spot: Vector2i = Displacement.free_spot_near(sim, unit, sim.nearest_safe_point(unit.pos, unit.radius), null, 0)
	if spot.x < 0:
		return
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.PUSH, source)
	entry.target = unit.id
	entry.from_pos = unit.pos
	entry.to_pos = spot
	entry.note = "grounded, set down clear"
	sim.combat_log.add(entry)
	unit.pos = spot
	unit.moved_at = sim.tick
	unit.route.clear()
	unit.leg_active = false
	unit.replan_at = sim.tick + 1


## Ends `unit`'s boosts that last until it attacks (phase 5c step 6b): the
## attack that just fired had them.
static func end_on_attack(sim: CombatSim, unit: UnitState) -> void:
	for state: StatusState in unit.statuses.duplicate():
		if state.def.until_attack:
			_end(sim, unit, state, "it attacked")


## The Unbending: `def` from `source` doesn't land on the hero; it's logged
## (RESISTED) and the hero gains a stack of `unbending`.
static func _resist(sim: CombatSim, hero: UnitState, def: StatusDef, source: EffectSource) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.RESISTED, source)
	entry.target = hero.id
	entry.status = def.id
	entry.status_name = def.name
	entry.note = "The Unbending"
	sim.combat_log.add(entry)
	if sim.content.statuses.has("unbending"):
		apply(sim, hero, "unbending", 1, 0, EffectSource.relic("the_unbending", "The Unbending", EffectSource.Team.HEROES))


## True if `source` is the heroes' side: a hero (or its summon), or the
## heroes' relic.
static func _by_heroes(sim: CombatSim, source: EffectSource) -> bool:
	if source.relic_side >= 0:
		return source.relic_side == EffectSource.Team.HEROES
	var unit: UnitState = sim.unit_by_id(source.unit_id)
	return unit != null and unit.side == EffectSource.Team.HEROES


## The stacks of `status_id` on `unit`: damage over time's, a timed status's
## (1, or more when it stacks), or 0 if it isn't there.
static func stacks_on(unit: UnitState, status_id: String) -> int:
	var state: StatusState = find(unit, status_id)
	if state == null:
		return 0
	return state.timed_stacks() if state.def.is_timed() else state.total_stacks()


## A timed status already on `target` lasts `ticks` longer (phase 5c step 5b,
## extend_status): logged (STATUS_EXTENDED). Nothing if it isn't there.
static func extend(sim: CombatSim, target: UnitState, status_id: String, ticks: int, source: EffectSource) -> void:
	var state: StatusState = find(target, status_id)
	if state == null or not state.def.is_timed() or not target.alive or state.lasting:
		return
	state.ends_at += ticks
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.STATUS_EXTENDED, source)
	entry.target = target.id
	entry.status = state.def.id
	entry.status_name = state.def.name
	entry.end_tick = state.ends_at
	entry.amount = ticks
	sim.combat_log.add(entry)


## Runs one tick of every status on every standing unit, in the fight's
## order: damage over time deals its damage, and timed statuses run out.
static func tick_all(sim: CombatSim) -> void:
	for unit: UnitState in sim.units:
		if not unit.alive or unit.statuses.is_empty():
			continue
		for state: StatusState in unit.statuses.duplicate():
			if state.def.kind == StatusDef.Kind.ENGAGED:
				continue
			if state.def.stacking:
				_drop_stacks(sim, unit, state)
				continue
			if state.def.is_timed():
				if sim.tick >= state.ends_at:
					_end(sim, unit, state)
				continue
			state.interval_left -= 1
			if state.interval_left <= 0:
				state.interval_left = state.def.interval_ticks
				_deal_damage_over_time(sim, unit, state)


## A stacking boost's stacks whose time is up go; the last one ends it.
static func _drop_stacks(sim: CombatSim, unit: UnitState, state: StatusState) -> void:
	var before: int = state.stack_ends.size()
	state.stack_ends.assign(state.stack_ends.filter(func(end: int) -> bool: return sim.tick < end))
	if state.stack_ends.is_empty():
		_end(sim, unit, state)
	elif state.stack_ends.size() != before:
		sim.refold_auras()


## Puts the Engaged status on `unit`, credited to `source` (the engager's
## Engage), unless it's already there.
static func hold(sim: CombatSim, unit: UnitState, source: EffectSource) -> void:
	var def: StatusDef = sim.content.engaged_status
	if find(unit, def.id) != null:
		return
	var state := StatusState.new()
	state.def = def
	state.order = sim.content.status_ids.find(def.id)
	state.source = source
	_insert_in_order(unit, state)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.STATUS_APPLIED, source)
	entry.target = unit.id
	entry.status = def.id
	entry.status_name = def.name
	entry.end_tick = -1
	sim.combat_log.add(entry)


## Takes the Engaged status off `unit`, if it's there; `why` goes in the log.
static func release(sim: CombatSim, unit: UnitState, why: String) -> void:
	var state: StatusState = find(unit, sim.content.engaged_status.id)
	if state != null:
		_end(sim, unit, state, why)


static func find(unit: UnitState, status_id: String) -> StatusState:
	for state: StatusState in unit.statuses:
		if state.def.id == status_id:
			return state
	return null


## True if no enemy may pick `unit` as a target now (Stealth).
static func is_stealthed(unit: UnitState) -> bool:
	return not unit.statuses.is_empty() and has_kind(unit, StatusDef.Kind.STEALTH)


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


## How much more damage the unit takes (the strongest Mark, less the
## strongest Ward; negative: less).
static func damage_taken_bp(unit: UnitState) -> int:
	var strongest: int = 0
	var ward: int = 0
	for state: StatusState in unit.statuses:
		if state.def.kind == StatusDef.Kind.MARKED:
			strongest = maxi(strongest, state.def.damage_taken_bp)
		elif state.def.kind == StatusDef.Kind.WARDED:
			ward = maxi(ward, state.def.damage_reduced_bp)
	return strongest - ward - unit.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP]


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
		# The damage rule: a Mark is the target's side (vulnerability).
		var damage: int = DamageRule.apply(group.stacks * state.def.damage_per_stack, 0, 0, damage_taken_bp(unit))
		if damage <= 0:
			continue
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.STATUS_DAMAGE, group.source)
		entry.target = unit.id
		entry.status = state.def.id
		entry.status_name = state.def.name
		entry.amount = damage
		var had_shield: bool = unit.shield > 0
		entry.absorbed = sim.apply_damage_vs_shield(unit, damage, state.def.vs_shield_bp)
		entry.broke_shield = had_shield and unit.shield == 0
		unit.last_hit_chain = entry.chain
		unit.last_hit_source = group.source
		unit.last_hit_status = state.def.name
		if group.source.relic_side < 0 and group.source.unit_id != unit.id:
			unit.last_attacker = group.source.unit_id
		sim.combat_log.add(entry)
	if state.lasting:
		return
	var lost: int = state.def.stacks_lost_per_interval
	if state.def.stacks_lost_bp > 0:
		@warning_ignore("integer_division")
		lost += (state.total_stacks() * state.def.stacks_lost_bp + FixedMath.BP_ONE - 1) / FixedMath.BP_ONE
	state.remove_oldest(lost)
	if state.total_stacks() == 0:
		_end(sim, unit, state)


## Each damage-over-time status on `unit` loses `share_bp` of its stacks
## (times its cleanse_effectiveness_bp; rounded; oldest first). A heal does
## this (`by_heal`), and so does a cleanse effect; either way the line names
## its source (rule 4). Timed statuses have no stacks, so they're never
## touched.
static func cleanse_over_time(sim: CombatSim, unit: UnitState, share_bp: int, source: EffectSource, by_heal: bool = false, only: Array[String] = []) -> void:
	for state: StatusState in unit.statuses.duplicate():
		if state.lasting and not _by_heroes(sim, source):
			continue
		if not only.is_empty() and not only.has(state.def.id):
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
		entry.set_source(source)
		entry.note = ("healed by %s" if by_heal else "cleansed by %s") % source.describe()
		sim.combat_log.add(entry)
		if state.total_stacks() == 0:
			_end(sim, unit, state)


static func _end(sim: CombatSim, unit: UnitState, state: StatusState, why: String = "") -> void:
	unit.statuses.erase(state)
	var entry := LogEntry.new()
	entry.tick = sim.tick
	entry.kind = LogEntry.Kind.STATUS_ENDED
	entry.target = unit.id
	entry.status = state.def.id
	entry.status_name = state.def.name
	entry.note = why
	sim.combat_log.add(entry)
	if state.def.kind == StatusDef.Kind.TAUNT and sim.taunt_auras:
		sim.refold_auras()
	elif state.def.kind == StatusDef.Kind.BOOST:
		sim.refold_auras()
	elif state.def.kind == StatusDef.Kind.GROUNDED:
		unit.flying = unit.def.has_trait("flying") and not has_kind(unit, StatusDef.Kind.GROUNDED)


static func _insert_in_order(unit: UnitState, state: StatusState) -> void:
	var index: int = 0
	while index < unit.statuses.size() and unit.statuses[index].order < state.order:
		index += 1
	unit.statuses.insert(index, state)
