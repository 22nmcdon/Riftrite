class_name Islands
extends RefCounted
## The void, Act 3's board rule (docs/plans/rebuild-phase8-act3.md, section
## 3; docs/plans/act3-shattered-crown.md, section 2). An encounter lists its
## void hexes the way it lists water (FightSetup.void); a fight without any
## never makes one of these, so nothing below runs.
##
##   - A point is over the void when its nav cell's center is on a void hex
##     (HexGrid.hex_at), so it costs one read (CombatSim.on_void).
##   - Walkers can't cross it: a void cell is blocked in their route
##     (NavGrid.void_cells), a step onto it doesn't fit (CombatSim.
##     fits_ground), and a walker plans a route whenever the void lies on its
##     straight line (crosses). Fliers ignore it; shots and areas fly over.
##   - Spots picked to land on (leaps, hops, summons, a flier dropped clear,
##     a rise) stay off it (CombatSim.fits). A charge or a hop stops short of
##     it (solid_until).
##   - Falling: a unit that doesn't fly whose center ends a push, a pull, or
##     a charge's carry over the void falls (fall): logged as FELL, sourced to
##     what moved it, and it goes in the deaths step as a fall that nothing
##     catches or follows (Decision 1): no Undying, no would-fall save, no
##     on_fall effects, no rise. It's a kill for whoever moved it (on_kill,
##     Decision 1 of the design), and a hero who falls is down.
##   - Islands: the hexes that aren't void, joined into groups (each hex to
##     its neighbors, never through a rock, which walkers can't cross; a
##     rock's hex takes the island of its first neighbor that has one). UnitState.island is marked (mark) as the tick starts
##     and again once every unit has acted, for the condition "same_island"
##     (UnitCondition); -1 over the void.
## The board's outer edge stays a wall (Decision 2): only void hexes drop a
## unit. Rift Collapse never turns ground into void (Decision 10 of the
## design).

## Per board hex: its island (0 up), or -1 for the void.
var island_of_hex: PackedInt32Array = PackedInt32Array()
## How many islands there are.
var count: int = 0
## Per nav cell: 1 if its center is on a void hex.
var cells: PackedByteArray = PackedByteArray()
var hexes: Array[Vector2i] = []
## Per board hex: 1 if it's void.
var _is_void: PackedByteArray = PackedByteArray()


## The rocks' hexes (islands are joined round them).
var rocks: Array[Vector2i] = []


static func make(grid: HexGrid, nav: NavGrid, void_hexes: Array[Vector2i], rock_hexes: Array[Vector2i]) -> Islands:
	var islands := Islands.new()
	islands.rocks = rock_hexes.duplicate()
	islands.set_void(grid, nav, void_hexes)
	return islands


## Sets the void to `void_hexes`: the nav cells over it, and the islands.
func set_void(grid: HexGrid, nav: NavGrid, void_hexes: Array[Vector2i]) -> void:
	hexes = void_hexes.duplicate()
	island_of_hex = groups(grid, void_hexes, rocks)
	count = 0
	for island: int in island_of_hex:
		count = maxi(count, island + 1)
	_is_void = PackedByteArray()
	_is_void.resize(grid.size())
	for hex: Vector2i in hexes:
		_is_void[grid.index(hex.x, hex.y)] = 1
	cells = PackedByteArray()
	cells.resize(nav.size())
	for at: int in nav.size():
		cells[at] = _is_void[grid.hex_at(nav.center(at))]
	nav.void_cells = cells


## Per board hex, its island (numbered in the board's order of their first
## hex), or -1 for a void hex (see the top for rocks).
static func groups(grid: HexGrid, void_hexes: Array[Vector2i], rock_hexes: Array[Vector2i] = []) -> PackedInt32Array:
	const ROCK: int = -3
	var found := PackedInt32Array()
	found.resize(grid.size())
	found.fill(-2)
	for hex: Vector2i in void_hexes:
		if grid.has(hex.x, hex.y):
			found[grid.index(hex.x, hex.y)] = -1
	for hex: Vector2i in rock_hexes:
		if grid.has(hex.x, hex.y) and found[grid.index(hex.x, hex.y)] == -2:
			found[grid.index(hex.x, hex.y)] = ROCK
	var next: int = 0
	for start: int in grid.size():
		if found[start] != -2:
			continue
		found[start] = next
		var queue: Array[int] = [start]
		while not queue.is_empty():
			var at: int = queue.pop_back()
			for near: Vector2i in grid.neighbors(grid.col_of(at), grid.row_of(at)):
				var index: int = grid.index(near.x, near.y)
				if found[index] == -2:
					found[index] = next
					queue.append(index)
		next += 1
	for at: int in grid.size():
		if found[at] != ROCK:
			continue
		found[at] = -1
		for near: Vector2i in grid.neighbors(grid.col_of(at), grid.row_of(at)):
			var island: int = found[grid.index(near.x, near.y)]
			if island >= 0:
				found[at] = island
				break
	return found


## What's wrong with an encounter's void (`where` starts each line): a hex
## off the board, on a rock or water, or listed twice; a unit placed on it;
## and enemies on an island no hex of the heroes' zone is on (a fight that
## couldn't meet).
static func problems(grid: HexGrid, void_hexes: Array[Vector2i], rocks: Array[Vector2i], water: Array[Vector2i], enemy_hexes: Array[Vector2i], where: String) -> Array[String]:
	var found: Array[String] = []
	for i: int in void_hexes.size():
		var hex: Vector2i = void_hexes[i]
		var at: String = "%svoid at (%d, %d)" % [where, hex.x, hex.y]
		if not grid.has(hex.x, hex.y):
			found.append("%s is off the board" % at)
		elif rocks.has(hex):
			found.append("%s is on a rock" % at)
		elif water.has(hex):
			found.append("%s is on water" % at)
		elif void_hexes.find(hex) < i:
			found.append("%s is listed twice" % at)
	if void_hexes.is_empty():
		return found
	var islands: PackedInt32Array = groups(grid, void_hexes, rocks)
	var heroes_reach: Dictionary[int, bool] = {}
	for index: int in grid.size():
		if grid.zone(grid.row_of(index)) == HexGrid.Zone.HEROES and islands[index] >= 0:
			heroes_reach[islands[index]] = true
	for hex: Vector2i in enemy_hexes:
		if not grid.has(hex.x, hex.y):
			continue
		var island: int = islands[grid.index(hex.x, hex.y)]
		if island < 0:
			found.append("%san enemy at (%d, %d) is on the void" % [where, hex.x, hex.y])
		elif not heroes_reach.has(island):
			found.append("%san enemy at (%d, %d) stands on an island the heroes' rows don't reach" % [where, hex.x, hex.y])
	return found


## True if the hex (col, row) is void.
func has_hex(grid: HexGrid, col: int, row: int) -> bool:
	return _is_void[grid.index(col, row)] != 0


## The island under `point` (-1 over the void).
func island_at(grid: HexGrid, point: Vector2i) -> int:
	return island_of_hex[grid.hex_at(point)]


## True if the straight line from `from` to `to` passes over the void
## (looked at every nav cell's width along it, ends included).
static func crosses(sim: CombatSim, from: Vector2i, to: Vector2i) -> bool:
	return solid_until(sim, from, to) != to


## How far along the straight line from `from` to `to` stays off the void:
## `to` if it all does, otherwise the last point (every nav cell's width
## along it) before the first one over it, `from` at the least.
static func solid_until(sim: CombatSim, from: Vector2i, to: Vector2i) -> Vector2i:
	var length: int = ArenaPlane.distance(from, to)
	var step: int = sim.tuning.nav_cell
	var last: Vector2i = from
	var along: int = 0
	while true:
		var point: Vector2i = ArenaPlane.step_toward(from, to, along) if along < length else to
		if sim.on_void(point):
			return last
		last = point
		if along >= length:
			return to
		along += step
	return to


## Marks each standing unit's island (see the top).
static func mark(sim: CombatSim) -> void:
	for unit: UnitState in sim.units:
		if unit.alive:
			unit.island = sim.islands.island_at(sim.grid, unit.pos)


## A unit moved by `source` (a push, pull, or carry) and now over the void
## falls if it doesn't fly (see the top). True if it fell.
static func check_fall(sim: CombatSim, unit: UnitState, source: EffectSource) -> bool:
	if not sim.has_void or unit.flying or not unit.alive or unit.fell or not sim.on_void(unit.pos):
		return false
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.FELL, source)
	entry.target = unit.id
	entry.to_pos = unit.pos
	entry.note = "into the void"
	sim.combat_log.add(entry)
	unit.fell = true
	unit.hp = 0
	# A kill for whoever moved it (Decision 1 of the design): the one who
	# pushed is its last attacker, with the ability that moved it.
	var mover: UnitState = sim.unit_by_id(source.unit_id) if source != null and not source.unit_id.is_empty() else null
	if mover != null and mover.side != unit.side:
		unit.last_attacker = mover.id
		unit.last_hit_source = source
		unit.last_hit_status = ""
		unit.last_hit_chain = entry.chain
	unit.target = null
	unit.route.clear()
	unit.leg_active = false
	return true
