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
##   - with no way to its target for repath_give_up_ms, it gives up on it;
##   - Rooted, it stands where it is; Slowed, its steps are shorter.
## A flier (the flying trait) goes straight at its target over units and
## rocks, in the air (UnitState.airborne), where others move as if it weren't
## there. In reach, it lands on a free spot before it attacks: where it is,
## or else the nearest free spot still in reach, which it flies on to
## (settle). Landed, it blocks like anyone.
## Units move one at a time, in the fight's order, each against where the
## others already stand, so no two ever overlap.
##
## Every leg goes in the log (MOVE), and so does every stop (STOP), so the
## board can be replayed from the log alone: while a leg is active, the unit
## moves ArenaPlane.step_toward(its position, leg_to, leg_amount) each tick.


## One tick of walking toward the unit's target.
static func walk(sim: CombatSim, unit: UnitState) -> void:
	if not unit.statuses.is_empty() and Statuses.has_kind(unit, StatusDef.Kind.ROOT):
		halt(sim, unit, "rooted")
		return
	var target: UnitState = unit.target
	if unit.flying:
		unit.airborne = true
		unit.has_settle_spot = false
	if unit.route.is_empty() or unit.route_for != target or sim.tick >= unit.replan_at:
		_plan(sim, unit)
	if unit.route.is_empty():
		halt(sim, unit, "no way through")
		if unit.no_path_since < 0:
			unit.no_path_since = sim.tick
		elif sim.tick - unit.no_path_since >= sim.tuning.repath_give_up_ticks:
			Targeting.give_up(sim, unit)
		return
	unit.no_path_since = -1
	var corner: Vector2i = unit.route[0]
	var amount: int = unit.step_length()
	if amount <= 0:
		return
	var next: Vector2i = ArenaPlane.step_toward(unit.pos, corner, amount)
	if not unit.flying and not sim.fits(unit, next):
		next = _slide(sim, unit, next)
		if next == unit.pos:
			halt(sim, unit, "blocked")
			unit.replan_at = sim.tick + 1
			return
		# A slide is a leg of its own, one tick long.
		_log_leg(sim, unit, next, ArenaPlane.distance(unit.pos, next) + 1)
		unit.pos = next
		unit.leg_active = false
		return
	if not unit.leg_active or unit.leg_to != corner or unit.leg_amount != amount:
		_log_leg(sim, unit, corner, amount)
	unit.pos = next
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
	var goal: int = nav.find_path(unit.pos, unit.forward(), target.pos, unit.reach())
	if goal < 0:
		return
	unit.route = nav.corners(nav.path_to(goal))
	if unit.route.is_empty():
		# The cell it stands in already counts as in reach: close the gap.
		unit.route.append(target.pos)


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
	if unit.pos == unit.settle_spot:
		unit.leg_active = false
	return false


## A step that would overlap something, tried again along the edge of the
## first circle it hits: the part of the step heading into that circle is
## dropped. Returns the unit's own position if that doesn't fit either.
static func _slide(sim: CombatSim, unit: UnitState, wanted: Vector2i) -> Vector2i:
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
		if along != Vector2i.ZERO and sim.fits(unit, slid):
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
