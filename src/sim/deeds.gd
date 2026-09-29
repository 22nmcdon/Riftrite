class_name Deeds
extends RefCounted
## Counts deeds as a fight runs (docs/plans/rebuild-phase4-paths.md,
## section 3; the rules for each kind and filter are DeedDef's). A unit
## counts the deeds of its setup's deed_paths: a hero's three, whatever path
## it's on, since the deeds count what it does with no bonus for the vow.
##   - At the end of each tick CombatSim hands over the entries logged since
##     the last read (the deaths step's included), so "as the tick ends" is
##     when the hero's HP is read for while_below_pct.
##   - A shot's distance is taken as it's fired (its SHOT entry: from the
##     shooter to where the target stood), and looked up when its hit lands.
##   - Only the unit's own entries count: not its summons', a relic's, or
##     Rift Collapse's.
## Counting never writes to the log or changes the fight: a fight is the same
## with or without it (the bench's fingerprints).


## The deeds `unit` counts, and what each has added up to (same order).
class Counter:
	var deeds: Array[DeedDef] = []
	var paths: Array[String] = []
	var amounts: Array[int] = []
	## Some deed filters on distance, so its shots' are kept.
	var needs_shots: bool = false
	## Each shot's distance when fired, by "target@land tick@ability"
	## (lookup only; never iterated).
	var shot_range_sq: Dictionary[String, int] = {}
	## Each ability's latest fire's target, for extra_hits (lookup only).
	var fired_at: Dictionary[String, String] = {}


static func make_counter(deed_paths: Array[PathDef]) -> Counter:
	if deed_paths.is_empty():
		return null
	var counter := Counter.new()
	for path: PathDef in deed_paths:
		counter.deeds.append(path.deed)
		counter.paths.append(path.id)
		counter.amounts.append(0)
		counter.needs_shots = counter.needs_shots or path.deed.from_range > 0
	return counter


## Counts log entries [from, to).
static func count(sim: CombatSim, from: int, to: int) -> void:
	for i: int in range(from, to):
		var entry: LogEntry = sim.combat_log.entries[i]
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
			continue
		for d: int in counter.deeds.size():
			var deed: DeedDef = counter.deeds[d]
			if not deed.counts_kind(kind, entry.source_ability):
				continue
			if deed.from_range > 0 and _range_sq(sim, unit, counter, entry) <= deed.from_range * deed.from_range:
				continue
			if deed.while_below_bp > 0 and unit.hp * FixedMath.BP_ONE >= deed.while_below_bp * unit.max_hp:
				continue
			if deed.off_target and counter.fired_at.get(entry.source_ability, "") == entry.target:
				continue
			match deed.counts:
				DeedDef.Counts.EXTRA_HITS:
					if counter.fired_at.get(entry.source_ability, "") != entry.target:
						counter.amounts[d] += 1
				DeedDef.Counts.ROOTED_MS:
					if entry.end_tick > entry.tick and sim.content.statuses.has(entry.status) \
							and sim.content.statuses[entry.status].kind == StatusDef.Kind.ROOT:
						counter.amounts[d] += (entry.end_tick - entry.tick) * FixedMath.MS_PER_TICK
				_:
					counter.amounts[d] += entry.amount


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
