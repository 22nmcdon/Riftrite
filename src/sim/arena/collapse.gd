class_name Collapse
extends RefCounted
## Rift Collapse, the shrinking arena (docs/plans/rebuild-phase1-arena-sim.md,
## section 9). It runs first each tick.
##
##   - Rings follow the placement grid (HexGrid.ring): the border is ring 0,
##     and the middle ring never crumbles. The first ring crumbles at
##     collapse_start (45s), then one more inward every collapse_ring (10s).
##   - Each ring is warned collapse_warning (3s) before it crumbles. Both are
##     logged (COLLAPSE_RING, with the safe rectangle left afterward).
##   - Crumbling shrinks CombatSim.safe to HexGrid.safe_rect: whatever lies
##     outside it is crumbled ground, and every walker plans its way again.
##     It's walkable (phase 5c, Decision 7): routes cost more across it
##     (NavGrid), a unit with nothing else to do steps off it
##     (Movement.wait), and the spots a unit picks to land on (leaps, hops,
##     summons) stay on safe ground (CombatSim.fits).
##   - From the first crumble, once a second, everyone whose center is on
##     crumbled ground takes flat damage (Shield first, never DEF, never a
##     share of HP), logged as COLLAPSE. It starts at the act's `base` and
##     grows by `growth` each second; from the surge (collapse_surge -
##     collapse_start after the first crumble) the growth itself rises by
##     `accel` each second.
##   - start_collapse (an effect) starts it early: the first ring is warned
##     at once, credited to whoever started it, and everything after keeps
##     the same spacing. Once the first warning is out, it does nothing.


## The collapse's part of this tick: warnings, crumbling, then damage.
static func tick(sim: CombatSim) -> void:
	var tuning: TuningDef = sim.tuning
	if sim.tick < sim.collapse_start - tuning.collapse_warning_ticks:
		return
	var last: int = sim.grid.last_ring()
	while sim.collapse_warned < last and sim.tick >= crumble_tick(sim, sim.collapse_warned) - tuning.collapse_warning_ticks:
		_warn(sim, sim.collapse_source)
	while sim.collapse_rings < sim.collapse_warned and sim.tick >= crumble_tick(sim, sim.collapse_rings):
		_crumble(sim)
	if sim.collapse_rings > 0 and (sim.tick - sim.collapse_start) % FixedMath.TICKS_PER_SECOND == 0:
		_damage(sim, damage_at(sim, sim.tick))


## start_collapse: warns the first ring now, if it hasn't been yet.
static func start_now(sim: CombatSim, source: EffectSource) -> void:
	if sim.collapse_warned > 0:
		return
	sim.collapse_start = sim.tick + sim.tuning.collapse_warning_ticks
	_warn(sim, source)


## The tick ring `ring` crumbles on.
static func crumble_tick(sim: CombatSim, ring: int) -> int:
	return sim.collapse_start + ring * sim.tuning.collapse_ring_ticks


## The damage a second's hit does at `at_tick` (a whole second after the
## first crumble, or on it).
static func damage_at(sim: CombatSim, at_tick: int) -> int:
	var numbers: CollapseDef = sim.collapse
	@warning_ignore("integer_division")
	var seconds: int = (at_tick - sim.collapse_start) / FixedMath.TICKS_PER_SECOND
	var damage: int = numbers.base + numbers.growth * seconds
	@warning_ignore("integer_division")
	var surge_seconds: int = seconds - (sim.tuning.collapse_surge_ticks - sim.tuning.collapse_start_ticks) / FixedMath.TICKS_PER_SECOND
	if surge_seconds > 0:
		@warning_ignore("integer_division")
		damage += numbers.accel * surge_seconds * (surge_seconds + 1) / 2
	# Endless (phase 8 part 1): a floor's crumbled ground hits harder.
	if sim.setup.crumble_bp > 0:
		damage = FixedMath.apply_bp(damage, sim.setup.crumble_bp)
	return damage


static func _warn(sim: CombatSim, source: EffectSource) -> void:
	var ring: int = sim.collapse_warned
	sim.collapse_warned += 1
	var entry: LogEntry = _ring_entry(sim, source, ring, "warned")
	entry.end_tick = crumble_tick(sim, ring)
	sim.combat_log.add(entry)


static func _crumble(sim: CombatSim) -> void:
	var ring: int = sim.collapse_rings
	sim.collapse_rings += 1
	sim.safe = sim.grid.safe_rect(sim.collapse_rings)
	# The ground changed: every walker plans its way again.
	for unit: UnitState in sim.units:
		unit.replan_at = mini(unit.replan_at, sim.tick)
	var entry: LogEntry = _ring_entry(sim, sim.collapse_source, ring, "crumbled")
	entry.end_tick = sim.tick
	sim.combat_log.add(entry)


## A COLLAPSE_RING entry: which ring, and the safe rectangle it leaves
## (from_pos to to_pos, its corners).
static func _ring_entry(sim: CombatSim, source: EffectSource, ring: int, what: String) -> LogEntry:
	var left: Rect2i = sim.grid.safe_rect(ring + 1)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.COLLAPSE_RING, source)
	entry.amount = ring
	entry.note = what
	entry.from_pos = left.position
	entry.to_pos = left.end
	return entry


static func _damage(sim: CombatSim, amount: int) -> void:
	var source: EffectSource = sim.collapse_source
	for unit: UnitState in sim.units:
		if not unit.alive or not sim.on_crumbled(unit.pos):
			continue
		# Riftwalker's Soles (the heroes' rule collapse; phase 5c step 5c):
		# heroes take none, enemies a share of their max HP more.
		var hurt: int = amount
		var note: String = ""
		if sim.hero_rules.collapse_immune or sim.hero_rules.collapse_enemy_bp > 0:
			if unit.side == EffectSource.Team.HEROES:
				if sim.hero_rules.collapse_immune:
					continue
			elif sim.hero_rules.collapse_enemy_bp > 0:
				hurt += FixedMath.apply_bp(unit.max_hp, sim.hero_rules.collapse_enemy_bp)
				note = "Riftwalker's Soles"
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.COLLAPSE, source)
		entry.target = unit.id
		entry.amount = hurt
		entry.note = note
		entry.absorbed = sim.apply_damage(unit, hurt)
		unit.last_hit_source = source
		unit.last_hit_status = ""
		sim.combat_log.add(entry)
