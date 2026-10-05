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
##     (UnitCondition); -1 over the void, and on a bridge (8c-6a: islands are
##     what bridges join, so a bridge's hexes are no island's, and a unit on
##     one is on no island; the placement check still walks over them).
## The board's outer edge stays a wall (Decision 2): only void hexes drop a
## unit. Rift Collapse never turns ground into void (Decision 10 of the
## design).
##
## Bridges that break (8c-5c; the sever effect, EffectDef's header): an
## encounter names its bridges (FightSetup.bridges, each a list of hexes).
## A sever takes the next bridge in turn that isn't already breaking: it's
## warned (VOID, "warned"), turns to void at the warning's end (VOID,
## "breaks"; every unit over it that doesn't fly falls, sourced to the
## sever), and comes back after its time (VOID, "reforms"). Each change
## works the islands out afresh, and every walker plans its way again. A
## fight without void gets its Islands at its first sever.

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
## The encounter's void (that never changes), its bridges, the bridges
## breaking or broken now (in the order severed), and the next to sever.
var base: Array[Vector2i] = []
var bridges: Array[Array] = []
var severs: Array[Sever] = []
var next_bridge: int = 0


## A bridge breaking: which, its hexes, when it breaks and comes back, and
## the sever's source.
class Sever:
	var bridge: int
	var hexes: Array[Vector2i] = []
	var breaks_at: int
	var reforms_at: int
	var broken: bool = false
	var source: EffectSource


static func make(grid: HexGrid, nav: NavGrid, void_hexes: Array[Vector2i], rock_hexes: Array[Vector2i], bridge_hexes: Array[Array] = []) -> Islands:
	var islands := Islands.new()
	islands.rocks = rock_hexes.duplicate()
	islands.base = void_hexes.duplicate()
	islands.bridges = bridge_hexes.duplicate(true)
	islands.set_void(grid, nav, void_hexes)
	return islands


## Sets the void to `void_hexes`: the nav cells over it, and the islands.
func set_void(grid: HexGrid, nav: NavGrid, void_hexes: Array[Vector2i]) -> void:
	hexes = void_hexes.duplicate()
	# A bridge's hexes are no island's (8c-6a: the Spire Chanter's "its
	# island" stops at the bridge), though walkers cross them.
	var cut: Array[Vector2i] = void_hexes.duplicate()
	for bridge: Array in bridges:
		for hex: Vector2i in bridge:
			if not cut.has(hex):
				cut.append(hex)
	island_of_hex = groups(grid, cut, rocks)
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
static func problems(grid: HexGrid, void_hexes: Array[Vector2i], rocks: Array[Vector2i], water: Array[Vector2i], enemy_hexes: Array[Vector2i], where: String,
		bridge_hexes: Array[Array] = []) -> Array[String]:
	var found: Array[String] = []
	var bridged: Array[Vector2i] = []
	for b: int in bridge_hexes.size():
		var bridge: Array = bridge_hexes[b]
		if bridge.is_empty():
			found.append("%sbridge %d has no hexes" % [where, b + 1])
		for hex: Vector2i in bridge:
			var at: String = "%sbridge %d's hex (%d, %d)" % [where, b + 1, hex.x, hex.y]
			if not grid.has(hex.x, hex.y):
				found.append("%s is off the board" % at)
			elif rocks.has(hex) or water.has(hex) or void_hexes.has(hex):
				found.append("%s is on a rock, water, or the void" % at)
			elif bridged.has(hex):
				found.append("%s is in another bridge too" % at)
			else:
				bridged.append(hex)
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


## The island under `point` (-1 over the void or a bridge).
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


## A sever (see the top), from `source`: the next bridge in turn that isn't
## breaking is warned, to break after `effect`'s warning.
static func sever(sim: CombatSim, source: EffectSource, effect: EffectDef) -> void:
	if sim.setup.bridges.is_empty():
		_log(sim, source, "finds no bridge to break", Vector2i.ZERO, 0)
		return
	if sim.islands == null:
		sim.islands = Islands.make(sim.grid, sim.nav(), [] as Array[Vector2i], sim.setup.rocks, sim.setup.bridges)
		sim.has_void = true
	var islands: Islands = sim.islands
	var count: int = islands.bridges.size()
	var picked: int = -1
	for n: int in count:
		var b: int = (islands.next_bridge + n) % count
		if not islands.severs.any(func(other: Sever) -> bool: return other.bridge == b):
			picked = b
			break
	if picked < 0:
		_log(sim, source, "finds every bridge already breaking", Vector2i.ZERO, 0)
		return
	islands.next_bridge = (picked + 1) % count
	var breaking := Sever.new()
	breaking.bridge = picked
	breaking.hexes.assign(islands.bridges[picked])
	breaking.breaks_at = sim.tick + effect.warning_ticks
	breaking.reforms_at = breaking.breaks_at + effect.zone_ticks
	breaking.source = source
	islands.severs.append(breaking)
	var entry: LogEntry = _log(sim, source, "warns bridge %d" % (picked + 1), sim.grid.center(breaking.hexes[0].x, breaking.hexes[0].y), breaking.hexes.size())
	entry.end_tick = breaking.breaks_at


## The hexes of the bridges warned and not yet broken (for the board).
func warned_hexes() -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	for breaking: Sever in severs:
		if not breaking.broken:
			found.append_array(breaking.hexes)
	return found


## Bridges whose time has come break or come back (see the top).
func tick(sim: CombatSim) -> void:
	var broke: Array[Sever] = []
	var reformed: Array[Sever] = []
	for breaking: Sever in severs:
		if not breaking.broken and sim.tick >= breaking.breaks_at:
			breaking.broken = true
			broke.append(breaking)
		elif breaking.broken and sim.tick >= breaking.reforms_at:
			reformed.append(breaking)
	if broke.is_empty() and reformed.is_empty():
		return
	severs = severs.filter(func(breaking: Sever) -> bool: return not reformed.has(breaking))
	var now: Array[Vector2i] = base.duplicate()
	for breaking: Sever in severs:
		if breaking.broken:
			for hex: Vector2i in breaking.hexes:
				if not now.has(hex):
					now.append(hex)
	set_void(sim.grid, sim.nav(), now)
	for unit: UnitState in sim.units:
		unit.replan_at = mini(unit.replan_at, sim.tick)
	for breaking: Sever in reformed:
		_log(sim, breaking.source, "reforms bridge %d" % (breaking.bridge + 1), sim.grid.center(breaking.hexes[0].x, breaking.hexes[0].y), breaking.hexes.size())
	for breaking: Sever in broke:
		_log(sim, breaking.source, "breaks bridge %d" % (breaking.bridge + 1), sim.grid.center(breaking.hexes[0].x, breaking.hexes[0].y), breaking.hexes.size())
		for unit: UnitState in sim.units:
			check_fall(sim, unit, breaking.source)


## A VOID line: what changed (note), where (to_pos), and how many hexes.
static func _log(sim: CombatSim, source: EffectSource, note: String, at: Vector2i, hexes_count: int) -> LogEntry:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.VOID, source)
	entry.note = note
	entry.to_pos = at
	entry.amount = hexes_count
	sim.combat_log.add(entry)
	return entry


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
