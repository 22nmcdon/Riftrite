class_name Water
extends RefCounted
## Shallow water, Act 2's board rule (docs/plans/rebuild-phase8-act2.md,
## section 3; docs/plans/act2-glassmere.md, section 2). An encounter lists
## its water hexes the way it lists rocks (FightSetup.water); a fight
## without any never makes one of these, so nothing below runs.
##
##   - A unit is on water when its center is on a water hex. That's looked
##     up on the nav grid's cells (each cell is water when its center's hex
##     is: HexGrid.hex_at), so it costs one read.
##   - A walker on water steps half as far (CombatSim.step_of), unless it
##     swims (the trait) or flies (a flier is never on water); the leg is
##     noted "in water".
##   - A route costs ROUTE_COST_BP as much across water for a walker that
##     doesn't swim (NavGrid), beside crumbled ground's cost; both apply to
##     crumbled water (Decision 2).
##   - A Burn tick on a unit on water deals BURN_BP of itself (Statuses;
##     noted "in water"), and lasts as long as anywhere else.
##   - UnitState.on_water is marked (mark) as the tick starts and again once
##     every unit has acted, for conditions ("on_water", UnitCondition), so a
##     condition reads where the unit stood at the last mark.
## Shots, areas, leaps, pulls, and knockbacks ignore water. Heroes may start
## on it (Decision 1).

## A walker on water steps this much of its step.
const SPEED_BP: int = 5000
## A Burn tick on water deals this much of itself.
const BURN_BP: int = 5000
## A route's step onto water costs this much more (2x), for a walker that
## doesn't swim.
const ROUTE_COST_BP: int = 20000

## The water hexes, in the order they were listed, and each by its index
## (lookup only).
var hexes: Array[Vector2i] = []
var _by_index: Dictionary[int, bool] = {}
## Per nav cell: 1 if its center is on a water hex.
var cells: PackedByteArray = PackedByteArray()


static func make(grid: HexGrid, nav: NavGrid, water_hexes: Array[Vector2i]) -> Water:
	var water := Water.new()
	water.set_hexes(grid, nav, water_hexes)
	return water


## Sets the water to `water_hexes` and works out which nav cells are on it.
func set_hexes(grid: HexGrid, nav: NavGrid, water_hexes: Array[Vector2i]) -> void:
	hexes = water_hexes.duplicate()
	_by_index.clear()
	for hex: Vector2i in hexes:
		_by_index[grid.index(hex.x, hex.y)] = true
	cells = PackedByteArray()
	cells.resize(nav.size())
	# Only the cells near a water hex can be on one.
	var reach: int = HexGrid.HEX
	for hex: Vector2i in hexes:
		var middle: Vector2i = grid.center(hex.x, hex.y)
		var low: int = nav.cell_at(middle - Vector2i(reach, reach))
		var high: int = nav.cell_at(middle + Vector2i(reach, reach))
		var wanted: int = grid.index(hex.x, hex.y)
		@warning_ignore("integer_division")
		var first_row: int = low / nav.cols
		@warning_ignore("integer_division")
		var last_row: int = high / nav.cols
		for row: int in range(first_row, last_row + 1):
			for col: int in range(low % nav.cols, high % nav.cols + 1):
				var at: int = row * nav.cols + col
				if grid.hex_at(nav.center(at)) == wanted:
					cells[at] = 1
	nav.water = cells


## True if the straight line from `from` to `to` passes over water (looked
## at every nav cell's width along it, ends included).
func crosses(sim: CombatSim, from: Vector2i, to: Vector2i) -> bool:
	var length: int = ArenaPlane.distance(from, to)
	var step: int = sim.tuning.nav_cell
	var along: int = 0
	while true:
		var point: Vector2i = ArenaPlane.step_toward(from, to, along) if along < length else to
		if sim.on_water(point):
			return true
		if along >= length:
			return false
		along += step
	return false


## True if the hex (col, row) is water.
func has_hex(grid: HexGrid, col: int, row: int) -> bool:
	return _by_index.has(grid.index(col, row))


## Marks each standing unit on water or not (see the top).
static func mark(sim: CombatSim) -> void:
	for unit: UnitState in sim.units:
		if unit.alive:
			unit.on_water = not unit.flying and sim.on_water(unit.pos)
