class_name Walls
extends RefCounted
## Walls that stop shots (docs/plans/rebuild-phase4-paths.md, section 5, P10;
## Hearthwall Brannoc's signature):
##   - A wall effect (EffectDef: width_hexes, ahead_hexes, duration_ms) puts
##     up a straight wall across the way from the unit to the ability's
##     target: centered ahead_hexes toward it, width_hexes wide, square to
##     that line. Logged (WALL: from_pos and to_pos are its ends, end_tick
##     when it falls).
##   - While it stands, a shot from the wall's enemies whose line (from where
##     it was fired to where its target is as it lands) crosses the wall is
##     stopped as it would land: SHOT_FIZZLED, noting the wall.
##   - Units walk through it (blocking movement is an apex's, later), and
##     areas aren't stopped. It stands until its time runs out, even if its
##     unit falls.


## One wall standing.
class Wall:
	var source: EffectSource
	var side: EffectSource.Team
	var a: Vector2i
	var b: Vector2i
	var until_tick: int


## `unit` puts up the wall `effect` toward `target`.
static func raise(sim: CombatSim, unit: UnitState, source: EffectSource, effect: EffectDef, target: UnitState) -> void:
	var dir: Vector2i = ArenaPlane.direction(unit.pos, target.pos if target != null else unit.pos, Vector2i(0, ArenaPlane.DIR * unit.forward()))
	var center: Vector2i = ArenaPlane.along(unit.pos, dir, effect.ahead_range)
	var across: Vector2i = Vector2i(-dir.y, dir.x)
	@warning_ignore("integer_division")
	var half: int = effect.width_range / 2
	var wall := Wall.new()
	wall.source = source
	wall.side = unit.side
	wall.a = ArenaPlane.along(center, across, half)
	wall.b = ArenaPlane.along(center, -across, half)
	wall.until_tick = sim.tick + effect.zone_ticks
	sim.walls.append(wall)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.WALL, source)
	entry.target = target.id if target != null else ""
	entry.from_pos = wall.a
	entry.to_pos = wall.b
	entry.end_tick = wall.until_tick
	sim.combat_log.add(entry)


## The standing wall that stops a shot from `from` to `to` fired by a unit of
## `shooter_side`, or null. Walls whose time is up are cleared first.
static func blocking(sim: CombatSim, shooter_side: EffectSource.Team, from: Vector2i, to: Vector2i) -> Wall:
	sim.walls = sim.walls.filter(func(wall: Wall) -> bool: return sim.tick < wall.until_tick)
	for wall: Wall in sim.walls:
		if wall.side != shooter_side and crosses(from, to, wall.a, wall.b):
			return wall
	return null


## True if segment p1-p2 crosses segment q1-q2 (touching counts).
static func crosses(p1: Vector2i, p2: Vector2i, q1: Vector2i, q2: Vector2i) -> bool:
	var d1: int = _side(q1, q2, p1)
	var d2: int = _side(q1, q2, p2)
	var d3: int = _side(p1, p2, q1)
	var d4: int = _side(p1, p2, q2)
	if d1 * d2 < 0 and d3 * d4 < 0:
		return true
	return (d1 == 0 and _on(q1, q2, p1)) or (d2 == 0 and _on(q1, q2, p2)) or (d3 == 0 and _on(p1, p2, q1)) or (d4 == 0 and _on(p1, p2, q2))


## -1, 0, or 1: which side of line a-b point p is on.
static func _side(a: Vector2i, b: Vector2i, p: Vector2i) -> int:
	var cross: int = (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x)
	return signi(cross)


## True if p (on the line a-b) is within the segment's box.
static func _on(a: Vector2i, b: Vector2i, p: Vector2i) -> bool:
	return mini(a.x, b.x) <= p.x and p.x <= maxi(a.x, b.x) and mini(a.y, b.y) <= p.y and p.y <= maxi(a.y, b.y)
