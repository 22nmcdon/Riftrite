class_name Engage
extends RefCounted
## The Engage trait (docs/plans/rebuild-phase1-arena-sim.md, section 4,
## decided): a tank that holds enemies in place.
##   - An enemy whose center is within engage_reach (1 hex) of an engager is
##     next to it.
##   - Next to an engager while its target is someone else, it's held: it
##     can't move until it has spent break_free_ms breaking free (the timer
##     starts the first tick it's held). It can still attack a target already
##     in reach. It carries the Engaged status, credited to the engager's
##     Engage, while it's held.
##   - A unit whose target is the engager isn't held; it just fights.
##   - Once free (BREAK_FREE), it can move until it's no longer next to that
##     engager; then the engagement ends. Coming back into contact engages it
##     again.
## Each engager a unit is next to holds it separately. It's all worked out in
## the unit's own update: as it's about to walk (a unit standing to attack
## isn't trying to get past anyone), and every tick while it has an
## engagement, so contact ending is noticed.

## One engager a unit is next to.
class Engagement:
	var engager: UnitState:
		get:
			return _engager.get_ref() as UnitState if _engager != null else null
		set(value):
			_engager = weakref(value) if value != null else null
	var _engager: WeakRef = null
	## The tick it breaks free (-1: not held yet).
	var free_at: int = -1
	var free: bool = false


## Brings the unit's engagements up to date: those out of contact (or whose
## engager fell) end, new contacts begin, and held ones run toward breaking
## free. `engagers` are the standing engagers on the unit's other side.
static func update(sim: CombatSim, unit: UnitState, engagers: Array[UnitState]) -> void:
	var reach_sq: int = sim.tuning.engage_reach * sim.tuning.engage_reach
	var i: int = unit.engagements.size() - 1
	while i >= 0:
		var engagement: Engagement = unit.engagements[i]
		var engager: UnitState = engagement.engager
		if engager == null or not engager.alive:
			_end(sim, unit, engagement, "%s fell" % (engager.id if engager != null else "its engager"))
		elif _distance_sq(unit, engager) > reach_sq:
			_end(sim, unit, engagement, "out of reach of %s" % engager.id)
		i -= 1
	for engager: UnitState in engagers:
		if not engager.alive or _distance_sq(unit, engager) > reach_sq or _find(unit, engager) != null:
			continue
		var engagement := Engagement.new()
		engagement.engager = engager
		unit.engagements.append(engagement)
	for engagement: Engagement in unit.engagements:
		if engagement.free:
			continue
		var engager: UnitState = engagement.engager
		if engagement.free_at < 0:
			if unit.target == engager:
				continue
			engagement.free_at = sim.tick + sim.tuning.break_free_ticks + engager.def.break_free_add_ticks
			Statuses.hold(sim, unit, EffectSource.make(engager.id, "engage", "Engage"))
		if sim.tick >= engagement.free_at:
			engagement.free = true
			var entry: LogEntry = sim.new_entry(LogEntry.Kind.BREAK_FREE, unit.own_source)
			entry.target = engager.id
			sim.combat_log.add(entry)
			if not _still_held(unit):
				Statuses.release(sim, unit, "broke free")


## True if an engager holds the unit: it's breaking free of one, and its
## target is someone else.
static func holds(unit: UnitState) -> bool:
	for engagement: Engagement in unit.engagements:
		if not engagement.free and engagement.free_at >= 0 and unit.target != engagement.engager:
			return true
	return false


## Ends the unit's engagements it's no longer next to (it was moved).
static func drop_out_of_reach(sim: CombatSim, unit: UnitState) -> void:
	var reach_sq: int = sim.tuning.engage_reach * sim.tuning.engage_reach
	var i: int = unit.engagements.size() - 1
	while i >= 0:
		var engagement: Engagement = unit.engagements[i]
		var engager: UnitState = engagement.engager
		if engager != null and _distance_sq(unit, engager) > reach_sq:
			_end(sim, unit, engagement, "moved out of reach of %s" % engager.id)
		i -= 1


static func _end(sim: CombatSim, unit: UnitState, engagement: Engagement, why: String) -> void:
	unit.engagements.erase(engagement)
	if not engagement.free and engagement.free_at >= 0 and not _still_held(unit):
		Statuses.release(sim, unit, why)


static func _still_held(unit: UnitState) -> bool:
	for engagement: Engagement in unit.engagements:
		if not engagement.free and engagement.free_at >= 0:
			return true
	return false


static func _find(unit: UnitState, engager: UnitState) -> Engagement:
	for engagement: Engagement in unit.engagements:
		if engagement.engager == engager:
			return engagement
	return null


static func _distance_sq(unit: UnitState, other: UnitState) -> int:
	var dx: int = other.pos.x - unit.pos.x
	var dy: int = other.pos.y - unit.pos.y
	return dx * dx + dy * dy
