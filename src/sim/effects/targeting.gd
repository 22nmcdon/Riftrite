class_name Targeting
extends RefCounted
## Who a unit attacks, and so where it walks (docs/plans/rebuild-phase1-arena-sim.md,
## section 4). A unit keeps its target until the target falls or it gives up
## on reaching it; then it picks again by its rule. Every pick is logged with
## its reason. Ties go to the earlier unit in the fight's order.
##
## Rules built so far: nearest (the enemy with the shortest path to a spot in
## range). The rest come with later steps.


## Picks a new target for a unit whose target has fallen (or that has none
## yet): null if nothing can be reached, and then it looks again after
## repath_ms.
static func update(sim: CombatSim, unit: UnitState) -> void:
	unit.target = null
	if sim.tick < unit.look_again_at:
		return
	var picked: UnitState = nearest(sim, unit)
	if picked == null:
		unit.look_again_at = sim.tick + sim.tuning.repath_ticks
		return
	set_target(sim, unit, picked, unit.def.targeting)


static func set_target(sim: CombatSim, unit: UnitState, picked: UnitState, reason: String) -> void:
	unit.target = picked
	unit.no_path_since = -1
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.TARGET, EffectSource.make(unit.id, "", ""))
	entry.target = picked.id
	entry.note = reason
	sim.combat_log.add(entry)


## Drops the unit's target (it couldn't get there), and logs why.
static func give_up(sim: CombatSim, unit: UnitState) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.TARGET, EffectSource.make(unit.id, "", ""))
	entry.note = "no way to reach %s" % unit.target.id
	sim.combat_log.add(entry)
	unit.target = null
	unit.no_path_since = -1


## The enemy with the shortest path to a spot in the unit's reach, or null.
## An enemy already in reach is nearest (the earliest such one).
static func nearest(sim: CombatSim, unit: UnitState) -> UnitState:
	var candidates: Array[UnitState] = sim.standing_enemies_of(unit)
	for enemy: UnitState in candidates:
		if unit.in_reach_of(enemy):
			return enemy
	if candidates.is_empty():
		return null
	var points: Array[Vector2i] = []
	for enemy: UnitState in candidates:
		points.append(enemy.pos)
	var nav: NavGrid = sim.nav_for(unit, null)
	var found: int = nav.find_nearest(unit.pos, unit.forward(), points, unit.reach())
	return candidates[found] if found >= 0 else null
