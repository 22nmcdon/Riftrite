class_name Deeds
extends RefCounted
## Counts deeds as a fight runs (docs/plans/rebuild-phase4-paths.md,
## section 3; the rules for each kind and filter are DeedDef's). A unit
## counts the deeds of its setup's deed_paths: a hero's three, whatever path
## it's on, since the deeds count what it does with no bonus for the vow.
##   - At the end of each tick CombatSim hands over the entries logged since
##     the last read (the deaths step's included), so "as the tick ends" is
##     when the hero's HP is read for while_below_pct, and its statuses for
##     while_undying.
##   - A shot's distance is taken as it's fired (its SHOT entry: from the
##     shooter to where the target stood), and looked up when its hit lands.
##   - Only the unit's own entries count: not its summons', a relic's, or
##     Rift Collapse's.
## Counting never writes to the log or changes the fight: a fight is the same
## with or without it (the bench's fingerprints).
## Tallies (phase 5c step 4, docs/plans/rebuild-phase5c-combos.md, section
## 9.4): a hero's growing cards count the same way, each under its key
## (UnitSetup.tallies), after its deeds in the same arrays.


## The deeds `unit` counts, and what each has added up to (same order).
class Counter:
	var deeds: Array[DeedDef] = []
	## A deed's path id, or a tally's key.
	var paths: Array[String] = []
	var amounts: Array[int] = []
	## Where the tallies start in the arrays above (the deeds come first).
	var tallies_from: int = 0
	## Some count reads the hero as the target (taken), the falls (kills),
	## or its HP each tick (ms_below).
	var needs_taken: bool = false
	var needs_kills: bool = false
	var needs_time: bool = false
	## Some count reads its signature's fires (casts).
	var needs_casts: bool = false
	## Some deed filters on distance, so its shots' are kept.
	var needs_shots: bool = false
	## Each shot's distance when fired, by "target@land tick@ability"
	## (lookup only; never iterated).
	var shot_range_sq: Dictionary[String, int] = {}
	## Each ability's latest fire's target, for extra_hits (lookup only).
	var fired_at: Dictionary[String, String] = {}


static func make_counter(deed_paths: Array[PathDef], tally_keys: Array[String] = [], tally_counts: Array[DeedDef] = []) -> Counter:
	if deed_paths.is_empty() and tally_keys.is_empty():
		return null
	var counter := Counter.new()
	for path: PathDef in deed_paths:
		_add(counter, path.id, path.deed)
	counter.tallies_from = counter.deeds.size()
	for i: int in tally_keys.size():
		_add(counter, tally_keys[i], tally_counts[i])
	return counter


static func _add(counter: Counter, key: String, deed: DeedDef) -> void:
	counter.deeds.append(deed)
	counter.paths.append(key)
	counter.amounts.append(0)
	counter.needs_shots = counter.needs_shots or deed.from_range > 0
	counter.needs_taken = counter.needs_taken or deed.counts == DeedDef.Counts.TAKEN
	counter.needs_kills = counter.needs_kills or deed.counts == DeedDef.Counts.KILLS
	counter.needs_time = counter.needs_time or deed.counts == DeedDef.Counts.MS_BELOW or deed.counts == DeedDef.Counts.MS_STANDING
	counter.needs_casts = counter.needs_casts or deed.counts == DeedDef.Counts.CASTS


## Counts log entries [from, to).
static func count(sim: CombatSim, from: int, to: int) -> void:
	for i: int in range(from, to):
		var entry: LogEntry = sim.combat_log.entries[i]
		if sim.tallies_on_target:
			_count_on_target(sim, entry)
		if entry.source_unit.is_empty() or entry.source_relic_side >= 0:
			continue
		var kind: LogEntry.Kind = entry.kind
		if kind != LogEntry.Kind.DAMAGE and kind != LogEntry.Kind.HEAL and kind != LogEntry.Kind.SHIELD and kind != LogEntry.Kind.SHOT \
				and kind != LogEntry.Kind.FIRE and kind != LogEntry.Kind.STATUS_APPLIED and kind != LogEntry.Kind.GUARD:
			continue
		var unit: UnitState = sim.unit_by_id(entry.source_unit)
		if unit == null or unit.deeds == null:
			continue
		var counter: Counter = unit.deeds
		if kind == LogEntry.Kind.SHOT:
			if counter.needs_shots:
				counter.shot_range_sq["%s@%d@%s" % [entry.target, entry.end_tick, entry.source_ability]] = ArenaPlane.length_sq(entry.to_pos - entry.from_pos)
			continue
		if kind == LogEntry.Kind.FIRE:
			counter.fired_at[entry.source_ability] = entry.target
			if counter.needs_casts and unit.def.signature != null and entry.source_ability == unit.def.signature.id:
				_add_to(counter, DeedDef.Counts.CASTS, 1)
			continue
		for d: int in counter.deeds.size():
			var deed: DeedDef = counter.deeds[d]
			if not deed.counts_kind(kind, entry.source_ability):
				continue
			if deed.from_range > 0 and _range_sq(sim, unit, counter, entry) <= deed.from_range * deed.from_range:
				continue
			if deed.while_below_bp > 0 and unit.hp * FixedMath.BP_ONE >= deed.while_below_bp * unit.max_hp:
				continue
			if deed.while_undying and not unit.statuses.any(func(state: StatusState) -> bool: return state.def.kind == StatusDef.Kind.UNDYING):
				continue
			if deed.off_target and counter.fired_at.get(entry.source_ability, "") == entry.target:
				continue
			if deed.from_basic and entry.source_ability != unit.def.basic_attack.id:
				continue
			match deed.counts:
				DeedDef.Counts.CRITS:
					if entry.crit:
						counter.amounts[d] += 1
				DeedDef.Counts.OVERKILL:
					counter.amounts[d] += entry.overkill
				DeedDef.Counts.APPLIED:
					var target: UnitState = sim.unit_by_id(entry.target)
					var status: StatusDef = sim.content.statuses.get(entry.status, null)
					if target != null and target.side != unit.side and status != null and status.kind != StatusDef.Kind.ENGAGED \
							and (deed.keywords.is_empty() or deed.keywords.has(status.keyword)):
						counter.amounts[d] += 1
				DeedDef.Counts.EXTRA_HITS:
					if counter.fired_at.get(entry.source_ability, "") != entry.target:
						counter.amounts[d] += 1
				DeedDef.Counts.ROOTED_MS:
					if entry.end_tick > entry.tick and sim.content.statuses.has(entry.status) \
							and sim.content.statuses[entry.status].kind == StatusDef.Kind.ROOT:
						counter.amounts[d] += (entry.end_tick - entry.tick) * FixedMath.MS_PER_TICK
				_:
					counter.amounts[d] += entry.amount


## The counts read from where the hero is the target: damage enemies deal
## it (taken), and the enemies it's credited with felling (kills; a DEATH
## entry names only the fallen, whose last attacker is still set).
static func _count_on_target(sim: CombatSim, entry: LogEntry) -> void:
	match entry.kind:
		LogEntry.Kind.DAMAGE, LogEntry.Kind.STATUS_DAMAGE:
			var hurt: UnitState = sim.unit_by_id(entry.target)
			if hurt == null or hurt.deeds == null or not hurt.deeds.needs_taken or entry.source_relic_side >= 0:
				return
			var by: UnitState = sim.unit_by_id(entry.source_unit)
			if by == null or by.side == hurt.side:
				return
			_add_to(hurt.deeds, DeedDef.Counts.TAKEN, entry.amount)
		LogEntry.Kind.DEATH:
			var fallen: UnitState = sim.unit_by_id(entry.target)
			if fallen == null or fallen.last_attacker.is_empty():
				return
			var killer: UnitState = sim.unit_by_id(fallen.last_attacker)
			if killer != null and killer.deeds != null and killer.deeds.needs_kills and killer.side != fallen.side:
				_add_to(killer.deeds, DeedDef.Counts.KILLS, 1)


static func _add_to(counter: Counter, counts: DeedDef.Counts, amount: int) -> void:
	for d: int in counter.deeds.size():
		if counter.deeds[d].counts == counts:
			counter.amounts[d] += amount


## As each tick ends: the time each counting unit spends below a share of
## its max HP (ms_below), or standing (ms_standing).
static func count_time(sim: CombatSim) -> void:
	for unit: UnitState in sim.units:
		if unit.deeds == null or not unit.deeds.needs_time or not unit.alive:
			continue
		for d: int in unit.deeds.deeds.size():
			var deed: DeedDef = unit.deeds.deeds[d]
			if deed.counts == DeedDef.Counts.MS_BELOW and unit.hp * FixedMath.BP_ONE < deed.while_below_bp * unit.max_hp:
				unit.deeds.amounts[d] += FixedMath.MS_PER_TICK
			elif deed.counts == DeedDef.Counts.MS_STANDING:
				unit.deeds.amounts[d] += FixedMath.MS_PER_TICK


## How far a hit left from, squared: its shot's distance if it was one,
## else where the two stand now.
static func _range_sq(sim: CombatSim, unit: UnitState, counter: Counter, entry: LogEntry) -> int:
	var key: String = "%s@%d@%s" % [entry.target, entry.tick, entry.source_ability]
	if counter.shot_range_sq.has(key):
		return counter.shot_range_sq[key]
	var target: UnitState = sim.unit_by_id(entry.target)
	if target == null:
		return 0
	return ArenaPlane.length_sq(target.pos - unit.pos)
