class_name SimDeaths
extends RefCounted
## The tick's deaths step and the fight's end, for CombatSim.step
## (docs/plans/phases/rebuild-phase1-arena-sim.md, sections 3 and 11): who falls this
## tick and what catches them (Undying, a would-fall save, on_fall, rising,
## Second Dawn), companions returning, thralls going, The Long Watch, and
## whether the fight is over. Every function takes the fight it acts on
## (the clean-up, docs/plans/phases/cleanup-and-layout.md).


## Settles who falls. A would_fall signature fires at once and may fell
## others, so it goes round again until nobody new is at 0 HP.
static func process_deaths(sim: CombatSim) -> void:
	var aura_lost: bool = false
	var again: bool = true
	while again:
		again = false
		for unit: UnitState in sim.units:
			if not unit.alive or (unit.hp > 0 and not unit.fell):
				continue
			# A fall into the void (Islands): nothing catches it, and nothing
			# runs as it goes (Decision 1).
			if unit.fell:
				unit.hp = 0
				_fall(sim, unit)
				if sim.ally_fall_listeners and unit.owner == null:
					Signatures.ally_fell(sim, unit)
				aura_lost = aura_lost or Passives.has_aura(unit) or (sim.taunt_auras and Statuses.has_kind(unit, StatusDef.Kind.TAUNT))
				Events.kill(sim, unit)
				if sim.enemy_fell_listeners:
					Events.enemy_fell(sim, unit)
				if sim.summon_fell_listeners and unit.summoned:
					Events.summon_fell(sim, unit)
				continue
			# A thrall (phase 8 part 5) goes quietly: nothing catches it or
			# runs as it goes, and it's nobody's kill or fallen ally (Decision 2).
			# So does a summon whose time is up (phase 8 part 6).
			if unit.raised or unit.time_up:
				unit.hp = 0
				_fall(sim, unit)
				aura_lost = aura_lost or Passives.has_aura(unit) or (sim.taunt_auras and Statuses.has_kind(unit, StatusDef.Kind.TAUNT))
				continue
			var undying: StatusState = _undying(sim, unit)
			if undying != null:
				unit.hp = 1
				var held: LogEntry = sim.new_entry(LogEntry.Kind.SAVED, undying.source)
				held.target = unit.id
				held.note = undying.def.name
				sim.combat_log.add(held)
				continue
			if Signatures.would_fall(sim, unit) or (not unit.listeners.is_empty() and Passives.would_fall(sim, unit)):
				again = true
				continue
			_fall(sim, unit)
			# A companion returns, so it's nobody's fallen ally (phase 8 part 6).
			if sim.ally_fall_listeners and unit.owner == null:
				Signatures.ally_fell(sim, unit)
			aura_lost = aura_lost or Passives.has_aura(unit) or (sim.taunt_auras and Statuses.has_kind(unit, StatusDef.Kind.TAUNT))
			Events.kill(sim, unit)
			if sim.enemy_fell_listeners:
				Events.enemy_fell(sim, unit)
			if sim.summon_fell_listeners and unit.summoned:
				Events.summon_fell(sim, unit)
			if unit.controlled:
				Events.controlled_fell(sim, unit)
			if Passives.on_fall(sim, unit):
				again = true
	if aura_lost:
		sim._active_auras = Passives.rederive(sim, sim._active_auras)


## Second Dawn (phase 5c step 5c): each fallen hero whose rise is due stands
## again where it fell (or the nearest free safe spot), at a share of its max
## HP, its statuses and Shield gone, logged as RISE. A unit with a rise
## passive (phase 8 part 2) rises the same way at its own share, sourced to
## the passive, keeping that passive's boost and gaining a stack of it.
static func rise_due(sim: CombatSim) -> void:
	var rose_any: bool = false
	for unit: UnitState in sim.units:
		if unit.alive or unit.rise_at < 0 or sim.tick < unit.rise_at:
			continue
		unit.rise_at = -1
		if unit.companion != null:
			rose_any = _companion_returns(sim, unit) or rose_any
			continue
		var part: PartDef = unit.rise_part
		if part != null:
			unit.rises_done += 1
		else:
			unit.rose = true
		if part != null and not part.rise_as.is_empty():
			# A fresh one of another kit stands where it fell (phase 8 part 3).
			Summons.rise_as(sim, unit, part)
			continue
		var spot: Vector2i = Displacement.free_spot_near(sim, unit, sim.nearest_safe_point(unit.pos, unit.radius), null, 0)
		if spot.x < 0:
			continue
		unit.alive = true
		unit.pos = spot
		unit.hp = maxi(FixedMath.apply_bp(unit.max_hp, part.rise_hp_bp if part != null else sim.hero_rules.rise_hp_bp), 1)
		unit.shield = 0
		if part != null and not part.rise_status.is_empty():
			unit.statuses = unit.statuses.filter(func(state: StatusState) -> bool: return state.def.id == part.rise_status)
		else:
			unit.statuses.clear()
		unit.target = null
		unit.last_attacker = ""
		unit.moved_at = sim.tick
		unit.route.clear()
		unit.leg_active = false
		unit.replan_at = sim.tick + 1
		var source: EffectSource = EffectSource.make(unit.id, part.id, part.name) if part != null \
			else EffectSource.relic("second_dawn", "Second Dawn", EffectSource.Team.HEROES)
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.RISE, source)
		entry.target = unit.id
		entry.to_pos = spot
		entry.amount = unit.hp
		sim.combat_log.add(entry)
		if part != null and not part.rise_status.is_empty():
			Statuses.apply(sim, unit, part.rise_status, 1, 0, source)
		rose_any = true
	if rose_any:
		sim.refold_auras()


## A companion that fell comes back beside its owner, if she stands (phase 8
## part 6, Kestra): at full HP, its statuses and Shield gone, logged as a
## SUMMON noted "returns" sourced to her. True if it came back.
static func _companion_returns(sim: CombatSim, unit: UnitState) -> bool:
	var owner: UnitState = unit.owner
	if owner == null or not owner.alive:
		return false
	var spot: Vector2i = Summons.beside(sim, owner, unit)
	if spot.x < 0:
		return false
	unit.alive = true
	unit.pos = spot
	unit.hp = unit.max_hp
	unit.shield = 0
	unit.statuses.clear()
	unit.target = null
	unit.last_attacker = ""
	unit.moved_at = sim.tick
	unit.route.clear()
	unit.leg_active = false
	unit.replan_at = sim.tick + 1
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, EffectSource.make(owner.id, unit.companion.kit.id, unit.companion.kit.name))
	entry.target = unit.id
	entry.to_pos = spot
	entry.amount = unit.hp
	entry.note = "returns"
	sim.combat_log.add(entry)
	return true


## Thralls whose time is up go (phase 8 part 5, Gravecaller): they fall in
## the deaths step that follows, noted "its time is up". So do summons whose
## lasts_ms is up (phase 8 part 6, Nest).
static func thralls_go(sim: CombatSim) -> void:
	var any: bool = false
	for unit: UnitState in sim.units:
		if unit.expires_at < 0 or not unit.alive:
			continue
		any = true
		if sim.tick >= unit.expires_at:
			unit.time_up = true
			unit.hp = 0
			unit.last_attacker = ""
			unit.last_hit_source = null
			unit.last_hit_status = "its time is up"
	sim.thralls = any


## The Long Watch: every standing hero gains a stack of `long_watch`.
static func keep_watch(sim: CombatSim) -> void:
	var source: EffectSource = EffectSource.relic("the_long_watch", "The Long Watch", EffectSource.Team.HEROES)
	for unit: UnitState in sim.heroes:
		if unit.alive and sim.content.statuses.has("long_watch"):
			Statuses.apply(sim, unit, "long_watch", 1, 0, source)


static func _undying(sim: CombatSim, unit: UnitState) -> StatusState:
	for state: StatusState in unit.statuses:
		if state.def.kind == StatusDef.Kind.UNDYING:
			return state
	return null


static func _fall(sim: CombatSim, unit: UnitState) -> void:
	unit.alive = false
	if unit.fell or unit.time_up:
		pass
	elif unit.companion != null:
		# It returns beside its owner (phase 8 part 6; _companion_returns).
		if unit.companion.return_ticks > 0:
			unit.rise_at = sim.tick + unit.companion.return_ticks
	elif unit.rise_part != null:
		# Its own rises (phase 8 part 2); Second Dawn's counts toward them.
		# Phase 8 part 3: only if it fell meeting the rise's "if".
		var meets: bool = unit.rise_part.rise_if == null or unit.rise_part.rise_if.holds(unit, unit)
		if unit.rises_done < unit.rise_part.rise_times and meets:
			unit.rise_at = sim.tick + unit.rise_part.rise_ticks
	elif sim.hero_rules.rise_ticks > 0 and unit.side == EffectSource.Team.HEROES and not unit.rose and unit.index < sim.setup.heroes.size():
		unit.rise_at = sim.tick + sim.hero_rules.rise_ticks
	unit.target = null
	unit.route.clear()
	unit.leg_active = false
	var entry := LogEntry.new()
	entry.tick = sim.tick
	entry.kind = LogEntry.Kind.DEATH
	entry.target = unit.id
	entry.to_pos = unit.pos
	entry.note = "fell into the void" if unit.fell else "its time is up" if (unit.raised or unit.time_up) and unit.last_hit_source == null else "last hit: %s" % unit.last_hit_text()
	sim.combat_log.add(entry)


static func check_end(sim: CombatSim) -> void:
	var heroes_up: bool = CombatSim._any_standing(sim.heroes)
	var enemies_up: bool = CombatSim._any_standing(sim.enemies)
	# The Long Watch (phase 5c step 5c): no tie until its own limit.
	var tie_at: int = sim.hero_rules.watch_tie_ticks if sim.hero_rules.watch_every_ticks > 0 else sim.tuning.tie_ticks
	if heroes_up and enemies_up and sim.tick < tie_at:
		return
	sim.finished = true
	var note: String
	if not heroes_up and not enemies_up:
		sim.outcome = FightResult.Outcome.TIE
		note = "Tie: both sides fell together (counts as a victory)"
	elif not enemies_up:
		sim.outcome = FightResult.Outcome.VICTORY
		note = "Victory"
	elif not heroes_up:
		sim.outcome = FightResult.Outcome.DEFEAT
		note = "Defeat"
	else:
		sim.outcome = FightResult.Outcome.TIE
		note = "Tie: both sides outlasted the rift (counts as a victory)"
	var entry := LogEntry.new()
	entry.tick = sim.tick
	entry.kind = LogEntry.Kind.FIGHT_END
	entry.note = note
	sim.combat_log.add(entry)
