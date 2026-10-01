class_name Targeting
extends RefCounted
## Who a unit attacks, and so where it walks (docs/plans/rebuild-phase1-arena-sim.md,
## section 4). A unit keeps its target until the target falls or it gives up
## on reaching it; then it picks again by its rule. Every pick is logged with
## its reason. Ties go to the earlier unit in the fight's order.
##
## The rules (ties always go to the earlier unit in the fight's order):
##   nearest            the enemy with the shortest path to a spot in range (a
##                      flier's, or a signature's, by straight line)
##   weakest_backliner  the lowest HP% among enemies that started in their
##                      side's back two rows; if none stand, the lowest HP%
##                      of all
##   largest_group      the enemy with the most of its own side within 2 hexes
##   farthest           the enemy farthest away (straight line)
##   lowest_hp_ally     the ally lowest on HP% (the unit itself included)
##   highest_mana       the enemy with the most mana (units with no mana bar
##                      are never picked)
##   self               the unit itself (signatures only)
## A signature picks among units within its reach (Signatures). "HP%" is
## compared exactly, by cross-multiplying, with no rounding.
## A hero with a prefer_target tactic (Tactics) picks the nearest enemy of
## its archetypes first, logged with the tactic's name; with none, its own
## rule. A kit's "prefer" (a kit mod's; phase 5c step 6b, Bloodhound) picks
## the nearest enemy that meets it next, logged with its label.

const RULES: Array[String] = ["nearest", "weakest_backliner", "largest_group", "farthest", "lowest_hp_ally", "highest_mana", "self"]
## How close a unit must be to count toward largest_group.
const GROUP_REACH: int = 2 * HexGrid.HEX


## Picks a new target for a unit whose target has fallen, or turned stealthed
## (or that has none yet): null if nothing can be reached, and then it looks
## again after repath_ms. A stealthed enemy is never picked.
static func update(sim: CombatSim, unit: UnitState) -> void:
	unit.target = null
	if sim.tick < unit.look_again_at:
		return
	if unit.tactic != null and (unit.tactic.kind == TacticDef.Kind.PREFER_TARGET or unit.tactic.kind == TacticDef.Kind.GUARD_ALLY):
		var preferred: UnitState = Tactics.preferred(sim, unit)
		if preferred != null:
			set_target(sim, unit, preferred, unit.tactic.name)
			return
	if unit.def.prefer != null:
		var wanted: Array[UnitState] = sim.targetable_enemies_of(unit).filter(func(enemy: UnitState) -> bool: return unit.def.prefer.holds(enemy))
		var preferred_kit: UnitState = nearest_of(sim, unit, wanted, false) if not wanted.is_empty() else null
		if preferred_kit != null:
			set_target(sim, unit, preferred_kit, unit.def.prefer_label)
			return
	var rule: String = unit.def.targeting
	var picked: UnitState = nearest(sim, unit) if rule == "nearest" else pick(sim, unit, rule, -1)
	if picked == null:
		unit.look_again_at = sim.tick + sim.tuning.repath_ticks
		return
	set_target(sim, unit, picked, unit.def.targeting)


## The unit `rule` picks for `unit`, among those within `reach_sq` of it
## (-1: anywhere), or null. Here nearest is by straight line.
static func pick(sim: CombatSim, unit: UnitState, rule: String, reach_sq: int, prefer: UnitCondition = null) -> UnitState:
	if rule == "self":
		return unit
	var pool: Array[UnitState] = sim.standing_allies_of(unit) if rule == "lowest_hp_ally" else sim.targetable_enemies_of(unit)
	if reach_sq >= 0:
		pool = pool.filter(func(other: UnitState) -> bool: return ArenaPlane.length_sq(other.pos - unit.pos) <= reach_sq)
	# A signature's "prefer" (phase 5c step 7b): its rule runs over those
	# that meet it, if any is in reach.
	if prefer != null:
		var wanted: Array[UnitState] = pool.filter(func(other: UnitState) -> bool: return prefer.holds(other))
		if not wanted.is_empty():
			pool = wanted
	var best: UnitState = null
	match rule:
		"nearest", "farthest":
			var best_distance: int = 0
			for other: UnitState in pool:
				var distance: int = ArenaPlane.length_sq(other.pos - unit.pos)
				if best == null or (distance < best_distance if rule == "nearest" else distance > best_distance):
					best = other
					best_distance = distance
		"weakest_backliner":
			for other: UnitState in pool:
				if other.back_liner and (best == null or _lower_share(other, best)):
					best = other
			if best == null:
				best = _lowest_share(pool)
		"lowest_hp_ally", "weakest_in_reach":
			best = _lowest_share(pool)
		"largest_group":
			var best_count: int = -1
			var side: Array[UnitState] = sim.standing_enemies_of(unit)
			for other: UnitState in pool:
				var count: int = 0
				for near: UnitState in side:
					if near != other and ArenaPlane.length_sq(near.pos - other.pos) <= GROUP_REACH * GROUP_REACH:
						count += 1
				if count > best_count:
					best = other
					best_count = count
		"highest_mana":
			for other: UnitState in pool:
				if other.def.mana != null and (best == null or other.mana > best.mana):
					best = other
	return best


static func _lowest_share(pool: Array[UnitState]) -> UnitState:
	var best: UnitState = null
	for other: UnitState in pool:
		if best == null or _lower_share(other, best):
			best = other
	return best


## True if `a` is on a lower share of its max HP than `b`.
static func _lower_share(a: UnitState, b: UnitState) -> bool:
	return a.hp * b.max_hp < b.hp * a.max_hp


static func set_target(sim: CombatSim, unit: UnitState, picked: UnitState, reason: String) -> void:
	unit.target = picked
	unit.no_path_since = -1
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.TARGET, unit.own_source)
	entry.target = picked.id
	entry.note = reason
	sim.combat_log.add(entry)


## Drops the unit's target because it can't be targeted now (`why`: "maren
## is stealthed"), and logs it; the unit picks again.
static func lose(sim: CombatSim, unit: UnitState, why: String) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.TARGET, unit.own_source)
	entry.note = why
	sim.combat_log.add(entry)
	unit.target = null
	unit.no_path_since = -1


## Drops the unit's target (it couldn't get there), and logs why.
static func give_up(sim: CombatSim, unit: UnitState) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.TARGET, unit.own_source)
	entry.note = "no way to reach %s" % unit.target.id
	sim.combat_log.add(entry)
	unit.target = null
	unit.no_path_since = -1


## The enemy with the shortest path to a spot in the unit's reach, or null.
## An enemy already in reach is nearest (the earliest such one).
## A flier goes over everything, so its nearest is by straight line.
static func nearest(sim: CombatSim, unit: UnitState) -> UnitState:
	return nearest_of(sim, unit, sim.targetable_enemies_of(unit), true)


## nearest among `candidates` (in the fight's order). `remember`: note in
## the unit whether the search failed, to make its next one fail faster
## (only for its own full searches, so a tactic's search never changes them).
static func nearest_of(sim: CombatSim, unit: UnitState, candidates: Array[UnitState], remember: bool) -> UnitState:
	for enemy: UnitState in candidates:
		if unit.in_reach_of(enemy):
			return enemy
	if candidates.is_empty():
		return null
	if unit.flying:
		var best: UnitState = null
		var best_distance: int = 0
		for enemy: UnitState in candidates:
			var distance: int = ArenaPlane.length_sq(enemy.pos - unit.pos)
			if best == null or distance < best_distance:
				best = enemy
				best_distance = distance
		return best
	var points: Array[Vector2i] = []
	for enemy: UnitState in candidates:
		points.append(enemy.pos)
	var nav: NavGrid = sim.nav_for(unit, null)
	var found: int = nav.find_nearest(unit.pos, unit.forward(), points, unit.reach(), unit.nearest_failed if remember else false)
	if remember:
		unit.nearest_failed = found < 0
	return candidates[found] if found >= 0 else null
