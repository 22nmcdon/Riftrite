class_name Displacement
extends RefCounted
## Knockback, pull, leap, and charge (docs/plans/rebuild-phase1-arena-sim.md,
## section 6, decided). Each moves a unit instantly in the sim and logs
## where from and where to (PUSH, LEAP, CHARGE); the UI animates it. A moved
## unit drops its path and plans again on the next tick, and an engagement
## it's moved out of ends at once.
##   knockback  the target goes straight away from the unit, `hexes` far
##   pull       the target comes straight toward the unit, `hexes` far,
##              stopping when it touches the unit; or (phase 8 part 3)
##              toward a point (the nearest water, an area's middle),
##              stopping on it
##   leap       the unit jumps to one of 12 spots touching its target (every
##              30 degrees round it): the free one closest to where it stands
##              (ties: the first), within max_hexes of it, ignoring anything
##              in between. Then it can't act while it lands (land_ms). With
##              no such spot, the leap fails (logged), and so does the whole
##              ability: nothing else in it happens
##   charge     the unit runs straight at its target, up to `hexes`, stopping
##              when it touches the first unit in the way (the target, if
##              nothing's before it). If that unit is an enemy, it's knocked
##              back `knockback` hexes. One that carries (phase 8 part 3)
##              first knocks every enemy in its line (its target included)
##              `knockback` hexes along it, farthest first, then runs
## Directions are exact, with no snapping; if two units stand on the same
## point, a push goes straight forward for the unit's side.
##
## A push (knockback, pull, or a charge's knockback) is swept in 50-unit steps
## and stops at the last clear point. A unit, a rock, or the arena's edge
## stops it; stopped early, the pushed unit is Stunned for collision_stun_ms,
## and so is a unit it hit. It may end on crumbled ground (that hurts). A
## leap or a charge is the unit's own move: it stays on safe ground, and a
## charge stopped short stuns no one. A flier is pushed over units and rocks
## (only the edge stops it); left over someone, it drops to the nearest free
## spot.
##
## hop_away (a trait): when an enemy is within a hex (hop_within: Light Feet
## makes it farther), the unit hops a hex
## straight away from the nearest one, stopping early at anything in the way
## (no stun: it's its own move), then waits hop_cooldown_ms. A unit an
## engager holds has to break free first. Logged as HOP.

## The 12 leap directions (length ArenaPlane.DIR), starting straight "down"
## the board and going round every 30 degrees.
const LEAP_DIRECTIONS: Array[Vector2i] = [
	Vector2i(0, 1000), Vector2i(500, 866), Vector2i(866, 500), Vector2i(1000, 0),
	Vector2i(866, -500), Vector2i(500, -866), Vector2i(0, -1000), Vector2i(-500, -866),
	Vector2i(-866, -500), Vector2i(-1000, 0), Vector2i(-866, 500), Vector2i(-500, 866),
]


## Knocks `target` back from `from` (the pushing unit's position).
static func knockback(sim: CombatSim, target: UnitState, from: Vector2i, forward: int, hexes: int, source: EffectSource) -> void:
	var dir: Vector2i = ArenaPlane.direction(from, target.pos, Vector2i(0, ArenaPlane.DIR * forward))
	push(sim, target, dir, hexes * HexGrid.HEX, source, "knocked back")


## Pulls `target` toward `puller`, no further than touching it.
static func pull(sim: CombatSim, target: UnitState, puller: UnitState, hexes: int, source: EffectSource) -> void:
	var dir: Vector2i = ArenaPlane.direction(target.pos, puller.pos, Vector2i(0, -ArenaPlane.DIR * puller.forward()))
	var room: int = maxi(ArenaPlane.distance(target.pos, puller.pos) - target.radius - puller.radius, 0)
	push(sim, target, dir, mini(hexes * HexGrid.HEX, room), source, "pulled")


## Pulls `target` toward `point` (phase 8 part 3: the nearest water, or an
## area's middle), `hexes` far, no further than the point.
static func pull_to(sim: CombatSim, target: UnitState, point: Vector2i, hexes: int, source: EffectSource) -> void:
	var distance: int = mini(hexes * HexGrid.HEX, ArenaPlane.distance(target.pos, point))
	if distance <= 0:
		return
	push(sim, target, ArenaPlane.direction(target.pos, point), distance, source, "pulled")


## Pushes `unit` `distance` along `dir` (length ArenaPlane.DIR), stopping at
## the last clear point; stopped early, it (and a unit it hit) is Stunned.
## `how` goes in the log ("knocked back", "pulled").
static func push(sim: CombatSim, unit: UnitState, dir: Vector2i, distance: int, source: EffectSource, how: String) -> void:
	# Braced (phase 5c step 6b): an unpushable unit isn't moved, and says so.
	if unit.aura_bp[AuraDef.Stat.UNPUSHABLE] > 0:
		var resisted: LogEntry = sim.new_entry(LogEntry.Kind.RESISTED, source)
		resisted.target = unit.id
		resisted.status = "push"
		resisted.status_name = "being " + how
		resisted.note = "can't be moved"
		sim.combat_log.add(resisted)
		return
	var from: Vector2i = unit.pos
	var circles: Array[ArenaPlane.Circle] = []
	if not unit.flying:
		circles = sim.obstacles_for(unit, null)
	var sweep: ArenaPlane.Sweep = ArenaPlane.sweep(from, ArenaPlane.along(from, dir, distance), unit.radius, circles, sim.grid.bounds())
	var hit_unit: UnitState = null
	var note: String = how
	match sweep.hit:
		ArenaPlane.Hit.EDGE:
			note += ", stopped by the arena's edge"
		ArenaPlane.Hit.CIRCLE:
			hit_unit = sim.unit_by_id(circles[sweep.circle].tag)
			note += ", stopped by %s" % (hit_unit.id if hit_unit != null else "a rock")
	var to: Vector2i = sweep.point
	if unit.flying:
		unit.airborne = false
		if not sim.fits(unit, to):
			var spot: Vector2i = free_spot_near(sim, unit, to, null, 0)
			if spot.x >= 0:
				to = spot
				note += ", dropped clear"
	_log(sim, LogEntry.Kind.PUSH, source, unit, from, to, note)
	_place(sim, unit, to)
	if sweep.hit != ArenaPlane.Hit.NONE:
		stun(sim, unit, source)
		if hit_unit != null:
			stun(sim, hit_unit, source)


## The collision stun.
static func stun(sim: CombatSim, unit: UnitState, source: EffectSource) -> void:
	Statuses.apply(sim, unit, sim.content.stun_status.id, 1, sim.tuning.collision_stun_ticks, source)


## Where `unit` would land leaping at `target` (see the top), or -1 in x if
## there's no free spot within `max_hexes`.
static func leap_spot(sim: CombatSim, unit: UnitState, target: UnitState, max_hexes: int) -> Vector2i:
	var reach: int = max_hexes * HexGrid.HEX
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: int = -1
	for dir: Vector2i in LEAP_DIRECTIONS:
		var spot: Vector2i = ArenaPlane.along(target.pos, dir, unit.radius + target.radius)
		var distance_sq: int = ArenaPlane.length_sq(spot - unit.pos)
		if distance_sq > reach * reach or not sim.fits(unit, spot):
			continue
		if best_distance < 0 or distance_sq < best_distance:
			best = spot
			best_distance = distance_sq
	return best


## `unit` leaps at `target`. Returns false (and logs it) if there's no spot.
static func leap(sim: CombatSim, unit: UnitState, target: UnitState, effect: EffectDef, source: EffectSource) -> bool:
	var spot: Vector2i = leap_spot(sim, unit, target, effect.hexes)
	if spot.x < 0:
		leap_failed(sim, unit, target, source)
		return false
	var from: Vector2i = unit.pos
	var land_ticks: int = effect.land_ticks if effect.land_ticks >= 0 else sim.tuning.leap_land_ticks
	var entry: LogEntry = _log(sim, LogEntry.Kind.LEAP, source, target, from, spot, "")
	entry.end_tick = sim.tick + land_ticks
	_place(sim, unit, spot)
	unit.landing_until = sim.tick + land_ticks
	if not sim.snares.is_empty():
		Snares.snag(sim, unit, from, spot)
	return true


static func leap_failed(sim: CombatSim, unit: UnitState, target: UnitState, source: EffectSource) -> void:
	var entry: LogEntry = _log(sim, LogEntry.Kind.LEAP, source, target, unit.pos, unit.pos, "no room to land")
	entry.end_tick = sim.tick


## `unit` charges at `target` (see the top).
static func charge(sim: CombatSim, unit: UnitState, target: UnitState, effect: EffectDef, source: EffectSource) -> void:
	var from: Vector2i = unit.pos
	var dir: Vector2i = ArenaPlane.direction(from, target.pos, Vector2i(0, ArenaPlane.DIR * unit.forward()))
	var room: int = maxi(ArenaPlane.distance(from, target.pos) - unit.radius - target.radius, 0)
	var distance: int = mini(effect.hexes * HexGrid.HEX, room)
	var carried: bool = false
	if effect.carries:
		carried = _carry(sim, unit, target, from, dir, distance, effect.knockback_hexes, source)
	var circles: Array[ArenaPlane.Circle] = sim.obstacles_for(unit, null)
	var sweep: ArenaPlane.Sweep = ArenaPlane.sweep(from, ArenaPlane.along(from, dir, distance), unit.radius, circles, sim.safe)
	var hit_unit: UnitState = null
	var note: String = ""
	match sweep.hit:
		ArenaPlane.Hit.EDGE:
			note = "stopped by the edge"
		ArenaPlane.Hit.CIRCLE:
			hit_unit = sim.unit_by_id(circles[sweep.circle].tag)
			note = "stopped by %s" % (hit_unit.id if hit_unit != null else "a rock")
		ArenaPlane.Hit.NONE:
			if distance == room:
				hit_unit = target
				note = "reached %s" % target.id
	_log(sim, LogEntry.Kind.CHARGE, source, target, from, sweep.point, note)
	_place(sim, unit, sweep.point)
	if not sim.snares.is_empty():
		Snares.snag(sim, unit, from, sweep.point)
	if hit_unit != null and hit_unit.side != unit.side and effect.knockback_hexes > 0 and not carried:
		knockback(sim, hit_unit, unit.pos, unit.forward(), effect.knockback_hexes, source)


## A charge that carries (see the top): every standing enemy whose circle
## its path from `from` along `dir` for `distance` (and on to touch) would
## cross, the target always among them, is knocked `hexes` along `dir`,
## farthest along first. True if it moved any.
static func _carry(sim: CombatSim, unit: UnitState, target: UnitState, from: Vector2i, dir: Vector2i, distance: int, hexes: int, source: EffectSource) -> bool:
	var keys: Array[int] = []
	var line: Array[UnitState] = []
	for enemy: UnitState in sim.standing_enemies_of(unit):
		if enemy.airborne:
			continue
		var offset: Vector2i = enemy.pos - from
		@warning_ignore("integer_division")
		var along: int = ArenaPlane.dot(offset, dir) / ArenaPlane.DIR
		@warning_ignore("integer_division")
		var across: int = absi(offset.x * dir.y - offset.y * dir.x) / ArenaPlane.DIR
		var in_line: bool = along > 0 and along <= distance + unit.radius + enemy.radius and across < unit.radius + enemy.radius
		if enemy == target or in_line:
			keys.append(maxi(along, 0) * 64 + line.size())
			line.append(enemy)
	if line.is_empty():
		return false
	keys.sort()
	keys.reverse()
	for key: int in keys:
		push(sim, line[key % 64], dir, hexes * HexGrid.HEX, source, "knocked back")
	return true


## The nearest free spot to `around` for `unit` (the point itself, then rings
## 100 apart, 12 spots each, starting straight down the board): within
## `reach_sq` of `target` if one's given. -1 in x if there's none within 3
## hexes.
static func free_spot_near(sim: CombatSim, unit: UnitState, around: Vector2i, target: UnitState, reach_sq: int) -> Vector2i:
	for ring: int in range(0, 3001, 100):
		for dir: Vector2i in (LEAP_DIRECTIONS if ring > 0 else [Vector2i.ZERO] as Array[Vector2i]):
			var spot: Vector2i = ArenaPlane.along(around, dir, ring)
			if target != null and ArenaPlane.length_sq(target.pos - spot) > reach_sq:
				continue
			if sim.fits(unit, spot):
				return spot
	return Vector2i(-1, -1)


## The hop_away trait (see the top). Returns true if it hopped.
static func hop_away(sim: CombatSim, unit: UnitState, engagers: Array[UnitState]) -> bool:
	var hex_sq: int = unit.def.hop_within * unit.def.hop_within
	var near: UnitState = null
	var near_distance: int = 0
	for enemy: UnitState in sim.standing_enemies_of(unit):
		var distance: int = ArenaPlane.length_sq(enemy.pos - unit.pos)
		if distance <= hex_sq and (near == null or distance < near_distance):
			near = enemy
			near_distance = distance
	if near == null:
		return false
	if not engagers.is_empty():
		Engage.update(sim, unit, engagers)
	if not unit.engagements.is_empty() and Engage.holds(unit):
		return false
	if not _hop_from(sim, unit, near, EffectSource.make(unit.id, "hop_away", "Hop Away")):
		return false
	unit.hop_ready_at = sim.tick + unit.def.hop_cooldown_ticks
	return true


## A hop effect (phase 8 part 2, Windrunner): a hex away from the nearest
## standing enemy, wherever it is, unless an engagement holds the unit;
## logged as HOP from `source`. It doesn't touch the hop_away trait's
## cooldown. Returns true if it hopped.
static func hop(sim: CombatSim, unit: UnitState, source: EffectSource) -> bool:
	var near: UnitState = null
	var near_distance: int = 0
	for enemy: UnitState in sim.standing_enemies_of(unit):
		var distance: int = ArenaPlane.length_sq(enemy.pos - unit.pos)
		if near == null or distance < near_distance:
			near = enemy
			near_distance = distance
	if near == null or (not unit.engagements.is_empty() and Engage.holds(unit)):
		return false
	return _hop_from(sim, unit, near, source)


## Hops `unit` a hex straight away from `near` (as far as it fits), logged.
static func _hop_from(sim: CombatSim, unit: UnitState, near: UnitState, source: EffectSource) -> bool:
	var dir: Vector2i = ArenaPlane.direction(near.pos, unit.pos, Vector2i(0, -ArenaPlane.DIR * unit.forward()))
	var sweep: ArenaPlane.Sweep = ArenaPlane.sweep(unit.pos, ArenaPlane.along(unit.pos, dir, HexGrid.HEX), unit.radius, sim.obstacles_for(unit, null), sim.safe)
	if sweep.point == unit.pos:
		return false
	var entry: LogEntry = _log(sim, LogEntry.Kind.HOP, source, near, unit.pos, sweep.point, "")
	if sweep.hit != ArenaPlane.Hit.NONE:
		entry.note = "cut short"
	_place(sim, unit, sweep.point)
	return true


## Moves `unit` to `point` (Gambits' swap; phase 5c step 6d).
static func place(sim: CombatSim, unit: UnitState, point: Vector2i) -> void:
	_place(sim, unit, point)


## Moves `unit` to `point`: its path is dropped, and an engagement it's been
## moved out of ends.
static func _place(sim: CombatSim, unit: UnitState, point: Vector2i) -> void:
	unit.pos = point
	unit.moved_at = sim.tick
	unit.route.clear()
	unit.leg_active = false
	unit.replan_at = sim.tick + 1
	if not unit.engagements.is_empty():
		Engage.drop_out_of_reach(sim, unit)


static func _log(sim: CombatSim, kind: LogEntry.Kind, source: EffectSource, target: UnitState, from: Vector2i, to: Vector2i, note: String) -> LogEntry:
	var entry: LogEntry = sim.new_entry(kind, source)
	entry.target = target.id
	entry.from_pos = from
	entry.to_pos = to
	entry.note = note
	sim.combat_log.add(entry)
	return entry
