class_name Movement
extends RefCounted
## Walking on the plane (docs/plans/rebuild-phase1-arena-sim.md, section 4).
##
## A unit that has a target out of reach walks toward it:
##   - straight at the target when nothing stands in the way (checked with a
##     sweep, only when it plans), otherwise along a route around, straight
##     from corner to corner (NavGrid);
##   - it plans again when its target changes, when it's blocked, when its
##     route runs out, and every repath_ms, since the board keeps changing;
##   - each tick it steps `speed x 1000 / 20` toward its next corner. A step
##     that would overlap anything is tried again sliding along what it hit;
##     if that fails too, it waits and plans again next tick;
##   - with no way to its target, it waits and looks again every repath_ms.
##     After repath_give_up_ms it gives up on it only if the target is walled
##     off (no way even with every unit out of the way: rocks or crumbled
##     ground). Blocked only by units, it keeps its target and waits for an
##     opening (playtest gate 1, decided 2026-09-28);
##   - Rooted, it stands where it is; Slowed, its steps are shorter.
## A flier (the flying trait) goes straight at its target over units and
## rocks, in the air (UnitState.airborne), where others move as if it weren't
## there. In reach, it lands on a free spot before it attacks: where it is,
## or else the nearest free spot still in reach, which it flies on to
## (settle). Landed, it blocks like anyone.
## Units move one at a time, in the fight's order, each against where the
## others already stand, so no two ever overlap.
## Nobody walks onto crumbled ground (Collapse). A unit whose center is on
## it walks back to safe ground before anything else (escape), and so does
## one only partly on it that's about to walk: straight to the nearest safe
## spot when the way is clear, otherwise the shortest way round
## (NavGrid.find_safe). On the way, a step may cross crumbled ground but
## never reach further past the safe ground than it did (fits_leaving).
## A flier takes off and flies straight back.
##
## Every leg goes in the log (MOVE), and so does every stop (STOP), so the
## board can be replayed from the log alone: while a leg is active, the unit
## moves ArenaPlane.step_toward(its position, leg_to, leg_amount) each tick.


## One tick of walking toward the unit's target.
static func walk(sim: CombatSim, unit: UnitState) -> void:
	if not unit.statuses.is_empty() and Statuses.has_kind(unit, StatusDef.Kind.ROOT):
		halt(sim, unit, "rooted")
		return
	if not unit.airborne and sim.collapse_rings > 0 and not ArenaPlane.inside(sim.safe, unit.pos, unit.radius):
		escape(sim, unit)
		return
	var target: UnitState = unit.target
	if unit.flying:
		unit.airborne = true
		unit.has_settle_spot = false
	# With no way to its target, it looks again only every repath_ms.
	if (unit.route.is_empty() and unit.no_path_since < 0) or unit.route_for != target or sim.tick >= unit.replan_at:
		_plan(sim, unit)
	if unit.route.is_empty():
		halt(sim, unit, "no way through")
		if unit.no_path_since < 0:
			unit.no_path_since = sim.tick
		elif sim.tick - unit.no_path_since >= sim.tuning.repath_give_up_ticks:
			if walled_off(sim, unit, target):
				Targeting.give_up(sim, unit)
			else:
				unit.no_path_since = sim.tick
		return
	unit.no_path_since = -1
	_follow(sim, unit, false)


## One tick of walking back to safe ground, for a unit not wholly on it (see
## the top). Waits where it is if there's no way back.
static func escape(sim: CombatSim, unit: UnitState) -> void:
	if not unit.statuses.is_empty() and Statuses.has_kind(unit, StatusDef.Kind.ROOT):
		halt(sim, unit, "rooted")
		return
	if unit.flying:
		unit.airborne = true
		unit.has_settle_spot = false
	# A route with a target leads there, not back.
	if unit.route_for != null or sim.tick >= unit.replan_at:
		_plan_escape(sim, unit)
	if unit.route.is_empty():
		halt(sim, unit, "no way off crumbled ground")
		return
	_follow(sim, unit, true)


## Steps along the unit's route. `leaving`: it's walking back to safe ground
## (CombatSim.fits_leaving).
static func _follow(sim: CombatSim, unit: UnitState, leaving: bool) -> void:
	var corner: Vector2i = unit.route[0]
	var amount: int = unit.step_length()
	if amount <= 0:
		return
	var next: Vector2i = ArenaPlane.step_toward(unit.pos, corner, amount)
	if not unit.flying and not _fits(sim, unit, next, leaving):
		next = _slide(sim, unit, next, leaving)
		if next == unit.pos:
			halt(sim, unit, "blocked")
			unit.replan_at = sim.tick + 1
			return
		# A slide is a leg of its own, one tick long.
		_log_leg(sim, unit, next, ArenaPlane.distance(unit.pos, next) + 1)
		unit.pos = next
		unit.moved_at = sim.tick
		unit.leg_active = false
		return
	if not unit.leg_active or unit.leg_to != corner or unit.leg_amount != amount:
		_log_leg(sim, unit, corner, amount)
	unit.pos = next
	unit.moved_at = sim.tick
	if unit.pos == corner:
		unit.route.remove_at(0)
		unit.leg_active = false


## The unit stands still this tick. If it was walking a leg, the log says
## where it stopped.
static func halt(sim: CombatSim, unit: UnitState, reason: String = "") -> void:
	if not unit.leg_active:
		return
	unit.leg_active = false
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.STOP, unit.own_source)
	entry.to_pos = unit.pos
	entry.note = reason
	sim.combat_log.add(entry)


## True if nothing but rocks and crumbled ground keeps `unit` from reaching
## `target`: no way to its reach even with every unit out of the way.
static func walled_off(sim: CombatSim, unit: UnitState, target: UnitState) -> bool:
	return sim.ground_nav_for(unit).find_path(unit.pos, unit.forward(), target.pos, unit.reach()) < 0


## Plans a route to the unit's target: straight at it when the way to its
## reach is clear, otherwise the shortest way around (empty if there's none).
static func _plan(sim: CombatSim, unit: UnitState) -> void:
	var target: UnitState = unit.target
	unit.route_for = target
	unit.replan_at = sim.tick + sim.tuning.repath_ticks
	unit.route.clear()
	if unit.flying:
		# Over everything, straight at it.
		unit.route.append(target.pos)
		return
	var gap: int = ArenaPlane.distance(unit.pos, target.pos) - unit.reach()
	var reach_point: Vector2i = ArenaPlane.along(unit.pos, ArenaPlane.direction(unit.pos, target.pos), maxi(gap, 0))
	var sweep: ArenaPlane.Sweep = ArenaPlane.sweep(unit.pos, reach_point, unit.radius, sim.obstacles_for(unit, target), sim.safe)
	if sweep.hit == ArenaPlane.Hit.NONE:
		unit.route.append(target.pos)
		return
	var nav: NavGrid = sim.nav_for(unit, target)
	var goal: int = nav.find_path(unit.pos, unit.forward(), target.pos, unit.reach(), unit.no_path_since >= 0)
	if goal < 0:
		return
	unit.route = nav.corners(nav.path_to(goal))
	if unit.route.is_empty():
		# The cell it stands in already counts as in reach: close the gap.
		unit.route.append(target.pos)


## Plans the way back to safe ground: straight to the nearest spot where the
## unit is wholly on it if nothing's in the way (always, for a flier),
## otherwise the shortest way round (empty if there's none).
static func _plan_escape(sim: CombatSim, unit: UnitState) -> void:
	unit.route_for = null
	unit.replan_at = sim.tick + sim.tuning.repath_ticks
	unit.route.clear()
	var spot: Vector2i = sim.nearest_safe_point(unit.pos, unit.radius)
	if unit.flying or ArenaPlane.sweep(unit.pos, spot, unit.radius, sim.obstacles_for(unit, null), sim.grid.bounds()).hit == ArenaPlane.Hit.NONE:
		unit.route.append(spot)
		return
	var nav: NavGrid = sim.nav_for(unit, null)
	var goal: int = nav.find_safe(unit.pos, unit.forward())
	if goal < 0:
		return
	unit.route = nav.corners(nav.path_to(goal))


static func _fits(sim: CombatSim, unit: UnitState, point: Vector2i, leaving: bool) -> bool:
	return sim.fits_leaving(unit, point) if leaving else sim.fits(unit, point)


## A flier in the air, in reach of `target`: it lands where it is if that's
## free, or flies on toward the nearest free spot still in reach. Returns true
## once it has landed (it may attack); with no free spot anywhere in reach, it
## attacks from the air (true, still in the air).
static func settle(sim: CombatSim, unit: UnitState, target: UnitState) -> bool:
	if sim.fits(unit, unit.pos):
		unit.airborne = false
		unit.has_settle_spot = false
		halt(sim, unit, "lands")
		return true
	if not unit.has_settle_spot or not sim.fits(unit, unit.settle_spot) \
			or ArenaPlane.length_sq(target.pos - unit.settle_spot) > unit.reach_sq:
		var spot: Vector2i = Displacement.free_spot_near(sim, unit, unit.pos, target, unit.reach_sq)
		if spot.x < 0:
			return true
		unit.settle_spot = spot
		unit.has_settle_spot = true
	var amount: int = unit.step_length()
	if amount <= 0:
		return false
	if not unit.leg_active or unit.leg_to != unit.settle_spot or unit.leg_amount != amount:
		_log_leg(sim, unit, unit.settle_spot, amount)
	unit.pos = ArenaPlane.step_toward(unit.pos, unit.settle_spot, amount)
	unit.moved_at = sim.tick
	if unit.pos == unit.settle_spot:
		unit.leg_active = false
	return false


## A step that would overlap something, tried again along the edge of the
## first circle it hits: the part of the step heading into that circle is
## dropped. Returns the unit's own position if that doesn't fit either.
static func _slide(sim: CombatSim, unit: UnitState, wanted: Vector2i, leaving: bool) -> Vector2i:
	var step: Vector2i = wanted - unit.pos
	for circle: ArenaPlane.Circle in sim.obstacles_for(unit, null):
		if not ArenaPlane.overlaps(wanted, unit.radius, circle.center, circle.radius):
			continue
		# The unit fits where it stands and not where it wants to go, so the
		# step heads into this circle: `into` is negative.
		var away: Vector2i = ArenaPlane.direction(circle.center, unit.pos)
		var into: int = ArenaPlane.dot(step, away)
		# Remove the part of the step along `away`.
		var sq: int = ArenaPlane.DIR * ArenaPlane.DIR
		var along: Vector2i = step - Vector2i(FixedMath.mul_div(away.x, into, sq), FixedMath.mul_div(away.y, into, sq))
		var slid: Vector2i = unit.pos + along
		if along != Vector2i.ZERO and _fits(sim, unit, slid, leaving):
			return slid
		return unit.pos
	return unit.pos


static func _log_leg(sim: CombatSim, unit: UnitState, to: Vector2i, amount: int) -> void:
	unit.leg_active = true
	unit.leg_to = to
	unit.leg_amount = amount
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.MOVE, unit.own_source)
	entry.from_pos = unit.pos
	entry.to_pos = to
	entry.amount = amount
	@warning_ignore("integer_division")
	entry.end_tick = sim.tick + (ArenaPlane.distance(unit.pos, to) + amount - 1) / amount - 1
	sim.combat_log.add(entry)
