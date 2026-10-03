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
##   - Units walk through it, and areas aren't stopped. It stands until its
##     time runs out, even if its unit falls.
## Phase 8 part 2 (The Unbroken Gate, Warden of Thorns), each skipped by a
## wall that doesn't use it:
##   - blocks_movement: its enemies can't walk through it. It's a row of
##     barrier circles (BARRIER_RADIUS, every BARRIER_STEP along it) that
##     they treat as rocks while it stands: walking, sliding, landing,
##     pushes, and whether a target is walled off. A circle that would
##     overlap one of them as it rises is left out, so no one is trapped
##     inside it. Its allies and fliers in the air pass.
##   - HP (hp_bp_of_max_hp, of its unit's max HP as it rises): a shot it
##     stops hits it for the shot's damage, and an enemy with no way to its
##     target that has the wall in reach strikes it with its basic attack
##     instead of waiting (its attack's damage, before any DEF: a wall has
##     none). Each logged (WALL_HIT: the shot's or the attack's source,
##     `wall_of` the wall's unit, noted "shot" or "struck"); at 0 HP it
##     breaks ("broken" added) and falls at once. until_broken: no time.
##   - max_standing: raising one more than that from the same effect takes
##     down the oldest (WALL_HIT noted "gone", amount 0).
##   - at: "target": raised ahead of the target, across its way (toward its
##     own target, or else the wall's unit), rather than ahead of the unit;
##     a snare's wall (Snares) rises where the snare springs.
##   - effects: each second it stands, they land on every enemy touching
##     it (within TOUCH of its line), numbers fixed as it rises.
##   - A stopped shot's SHOT_FIZZLED line names the wall's unit (`wall_of`):
##     on_wall_block, and the deed count "blocked".

## Barrier circles: their radius and spacing along a wall that blocks
## movement (a unit 0.2 hex wide can't pass between two).
const BARRIER_RADIUS: int = 200
const BARRIER_STEP: int = 250
## How near its line an enemy's edge counts as touching a wall.
const TOUCH: int = 100
## A wall's effects land this often (ticks: a second).
const TOUCH_TICKS: int = 20


## One wall standing.
class Wall:
	var source: EffectSource
	var side: EffectSource.Team
	var a: Vector2i
	var b: Vector2i
	var until_tick: int
	## Where its raiser stood: its side of the wall's line is behind it
	## (phase 5c step 5d, The Watchtower Stone).
	var back: Vector2i
	## A stopped shot's share it sends back at the shooter (phase 5c step
	## 7d, Reflecting Wall; 0: none).
	var reflect_bp: int = 0
	## Phase 8 part 2 (see the top): its unit and effect, its HP (max_hp 0:
	## none), the barrier circles that block its enemies (empty: none), its
	## effects' numbers, and when they next land.
	var unit: UnitState
	var effect: EffectDef
	var hp: int = 0
	var max_hp: int = 0
	var circles: Array[ArenaPlane.Circle] = []
	var touch_amounts: Array[int] = []
	var touch_powers: Array[int] = []
	var next_touch: int = 0


## True if `unit` stands behind one of its side's standing walls (phase 5c
## step 5d): on its raiser's side of the wall's line, between its ends (half
## a hex either way), and within `reach` of the line.
static func behind(sim: CombatSim, unit: UnitState, reach: int) -> bool:
	for wall: Wall in sim.walls:
		if wall.side != unit.side or sim.tick >= wall.until_tick:
			continue
		var along: Vector2i = wall.b - wall.a
		var length_sq: int = ArenaPlane.length_sq(along)
		if length_sq == 0:
			continue
		var offset: Vector2i = unit.pos - wall.a
		var back_cross: int = along.x * (wall.back.y - wall.a.y) - along.y * (wall.back.x - wall.a.x)
		var cross: int = along.x * offset.y - along.y * offset.x
		if cross == 0 or (cross > 0) != (back_cross > 0):
			continue
		var length: int = FixedMath.isqrt(length_sq)
		@warning_ignore("integer_division")
		var t: int = (offset.x * along.x + offset.y * along.y) / length
		@warning_ignore("integer_division")
		var away: int = absi(cross) / length
		if t >= -HexGrid.HEX / 2 and t <= length + HexGrid.HEX / 2 and away <= reach:
			return true
	return false


## `unit` puts up the wall `effect` toward `target`.
static func raise(sim: CombatSim, unit: UnitState, source: EffectSource, effect: EffectDef, target: UnitState) -> void:
	var from: Vector2i = unit.pos
	var dir: Vector2i
	if effect.at_target and target != null:
		# Ahead of the target, across its way (phase 8 part 2).
		var toward: UnitState = target.target if target.target != null and target.target.alive else unit
		from = target.pos
		dir = ArenaPlane.direction(target.pos, toward.pos, Vector2i(0, ArenaPlane.DIR * target.forward()))
	else:
		dir = ArenaPlane.direction(unit.pos, target.pos if target != null else unit.pos, Vector2i(0, ArenaPlane.DIR * unit.forward()))
	var center: Vector2i = ArenaPlane.along(from, dir, effect.ahead_range)
	var across: Vector2i = Vector2i(-dir.y, dir.x)
	@warning_ignore("integer_division")
	var half: int = effect.width_range / 2
	var wall := Wall.new()
	wall.source = source
	wall.side = unit.side
	wall.a = ArenaPlane.along(center, across, half)
	wall.b = ArenaPlane.along(center, -across, half)
	wall.until_tick = sim.tick + effect.zone_ticks if not effect.until_broken else CombatSim.NEVER
	wall.back = unit.pos
	wall.reflect_bp = effect.reflect_bp
	wall.unit = unit
	wall.effect = effect
	if effect.max_standing > 0:
		var mine: Array[Wall] = sim.walls.filter(func(other: Wall) -> bool: return other.effect == effect and other.unit == unit and sim.tick < other.until_tick)
		if mine.size() >= effect.max_standing:
			_fall(sim, mine[0])
			_log_hit(sim, mine[0], mine[0].source, 0, "gone")
	if effect.wall_hp_bp > 0:
		wall.max_hp = maxi(FixedMath.apply_bp(unit.max_hp, effect.wall_hp_bp), 1)
		wall.hp = wall.max_hp
	for nested: EffectDef in effect.area_effects:
		wall.touch_amounts.append(EffectRunner.amount_of(nested, unit, 0, sim))
		wall.touch_powers.append(EffectRunner.power_of(nested, unit))
	wall.next_touch = sim.tick + TOUCH_TICKS
	sim.walls.append(wall)
	if effect.blocks_movement:
		_raise_barrier(sim, wall)
	if not effect.area_effects.is_empty() or effect.blocks_movement:
		sim.active_walls.append(wall)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.WALL, source)
	entry.target = target.id if target != null else ""
	entry.from_pos = wall.a
	entry.to_pos = wall.b
	entry.end_tick = wall.until_tick
	sim.combat_log.add(entry)


## The barrier circles of a wall that blocks movement (see the top), but
## those that would overlap a standing enemy of it.
static func _raise_barrier(sim: CombatSim, wall: Wall) -> void:
	var length: int = ArenaPlane.distance(wall.a, wall.b)
	var dir: Vector2i = ArenaPlane.direction(wall.a, wall.b, Vector2i(1, 0))
	@warning_ignore("integer_division")
	var count: int = length / BARRIER_STEP + 1
	for i: int in count:
		var center: Vector2i = ArenaPlane.along(wall.a, dir, mini(i * BARRIER_STEP, length))
		var free: bool = true
		for other: UnitState in sim.units:
			if other.alive and other.side != wall.side and not other.airborne and ArenaPlane.overlaps(center, BARRIER_RADIUS, other.pos, other.radius):
				free = false
				break
		if free:
			wall.circles.append(ArenaPlane.Circle.make(center, BARRIER_RADIUS, "wall"))
	sim.rebuild_barriers()


## Each tick while a wall with barrier circles or effects stands
## (CombatSim.active_walls): walls whose time is up come down, and effects
## land on the enemies touching them each second.
static func tick(sim: CombatSim) -> void:
	var standing: Array[Wall] = []
	var fell: bool = false
	for wall: Wall in sim.active_walls:
		if sim.tick >= wall.until_tick:
			fell = fell or not wall.circles.is_empty()
			continue
		standing.append(wall)
		if wall.touch_amounts.is_empty() or sim.tick < wall.next_touch:
			continue
		wall.next_touch = sim.tick + TOUCH_TICKS
		for other: UnitState in sim.units:
			if other.alive and other.side != wall.side and not other.airborne and _touching(wall, other):
				for i: int in wall.effect.area_effects.size():
					EffectRunner.land(sim, wall.unit, null, wall.source, wall.effect.area_effects[i], other, wall.touch_amounts[i], false, EffectRunner.NO_POINT, wall.touch_powers[i])
	sim.active_walls = standing
	if fell:
		sim.rebuild_barriers()


## True if `other`'s edge is within TOUCH of the wall's line.
static func _touching(wall: Wall, other: UnitState) -> bool:
	var reach: int = other.radius + TOUCH
	return segment_distance_sq(other.pos, wall.a, wall.b) <= reach * reach


## The squared distance from `p` to the segment a-b.
static func segment_distance_sq(p: Vector2i, a: Vector2i, b: Vector2i) -> int:
	var along: Vector2i = b - a
	var length_sq: int = ArenaPlane.length_sq(along)
	if length_sq == 0:
		return ArenaPlane.length_sq(p - a)
	var t: int = clampi((p.x - a.x) * along.x + (p.y - a.y) * along.y, 0, length_sq)
	var closest: Vector2i = a + Vector2i(FixedMath.mul_div(along.x, t, length_sq), FixedMath.mul_div(along.y, t, length_sq))
	return ArenaPlane.length_sq(p - closest)


## A stopped shot's damage (its effects' amounts with their power) wears
## down the wall, if it has HP.
static func take_shot(sim: CombatSim, wall: Wall, shot: Shots.Shot) -> void:
	if wall.max_hp == 0:
		return
	var total: int = 0
	for i: int in shot.effects.size():
		if shot.effects[i].type == EffectDef.Type.DAMAGE:
			total += DamageRule.apply(shot.amounts[i], shot.powers[i])
	_wear(sim, wall, shot.source, total, "shot")


## `unit` has no way to its target (Movement.walk): if its basic attack is
## ready and a wall with HP that blocks it is in its reach, it strikes the
## wall (true) instead of waiting.
static func strike(sim: CombatSim, unit: UnitState) -> bool:
	var attack: AbilityState = unit.attack
	if attack.progress_bp < attack.needed:
		return false
	var reach: int = unit.reach() + unit.radius + BARRIER_RADIUS
	for wall: Wall in sim.walls:
		if wall.max_hp == 0 or wall.circles.is_empty() or wall.side == unit.side or sim.tick >= wall.until_tick:
			continue
		if segment_distance_sq(unit.pos, wall.a, wall.b) > reach * reach:
			continue
		var total: int = 0
		for effect: EffectDef in unit.def.basic_attack.effects:
			if effect.type == EffectDef.Type.DAMAGE and effect.trigger == EffectDef.Trigger.ON_FIRE and effect.target == EffectDef.Target.TARGET:
				total += DamageRule.apply(EffectRunner.amount_of(effect, unit, 0, sim), EffectRunner.power_of(effect, unit))
		Movement.halt(sim, unit, "strikes a wall")
		attack.spend()
		Mana.on_attack(sim, unit)
		_wear(sim, wall, unit.own_source if unit.def.basic_attack == null else EffectSource.make(unit.id, unit.def.basic_attack.id, unit.def.basic_attack.name), total, "struck")
		return true
	return false


## The wall takes `amount` from `source` (logged); at 0 HP it breaks.
static func _wear(sim: CombatSim, wall: Wall, source: EffectSource, amount: int, note: String) -> void:
	wall.hp = maxi(wall.hp - amount, 0)
	if wall.hp == 0:
		_fall(sim, wall)
		note += ", broken"
	_log_hit(sim, wall, source, amount, note)


## The wall comes down now.
static func _fall(sim: CombatSim, wall: Wall) -> void:
	wall.until_tick = sim.tick
	if not wall.circles.is_empty():
		wall.circles.clear()
		sim.rebuild_barriers()


static func _log_hit(sim: CombatSim, wall: Wall, source: EffectSource, amount: int, note: String) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.WALL_HIT, source)
	entry.wall_of = wall.source.unit_id
	entry.amount = amount
	entry.from_pos = wall.a
	entry.to_pos = wall.b
	entry.note = note
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
