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
##   - Submerge (a trait, the Mire Eel): a unit that submerges is under
##     while it's on water (UnitState.submerged, marked with on_water), but
##     for SURFACE_TICKS after each basic attack. Under, it's as if Stealthed
##     (Statuses.is_stealthed, the keyword): it can't be picked, and a unit
##     targeting it picks again ("... is submerged").
##   - UnitState.on_water is marked (mark) as the tick starts and again once
##     every unit has acted, for conditions ("on_water", UnitCondition), so a
##     condition reads where the unit stood at the last mark.
## Shots, areas, leaps, pulls, and knockbacks ignore water. Heroes may start
## on it (Decision 1).
##
## Water that changes (8c-3c; the flood effect, EffectDef's header): a flood
## in a fight that had none makes the Water then. The water is the lasting
## hexes plus each flood that lasts a while (a Layer, gone at its tick:
## tick). Each change is logged as WATER (the flood's source; a layer going
## is noted "recedes"), every walker plans its way again, and the cells are
## worked out afresh. Floods never cover a rock.

## A walker on water steps this much of its step.
const SPEED_BP: int = 5000
## A Burn tick on water deals this much of itself.
const BURN_BP: int = 5000
## A unit that submerges stays up this long after each basic attack (2s).
const SURFACE_TICKS: int = 40
## A route's step onto water costs this much more (2x), for a walker that
## doesn't swim.
const ROUTE_COST_BP: int = 20000

## A flood that lasts a while: its hexes, the tick it goes, and its source.
class Layer:
	var hexes: Array[Vector2i] = []
	var until_tick: int
	var source: EffectSource
	var at: Vector2i


## The water hexes now (the lasting ones, then each layer's new ones, in
## the order they came), and each by its index (lookup only).
var hexes: Array[Vector2i] = []
var _by_index: Dictionary[int, bool] = {}
## The hexes that stay, and the floods that go in time (in the order cast).
var lasting: Array[Vector2i] = []
var layers: Array[Layer] = []
## Per nav cell: 1 if its center is on a water hex.
var cells: PackedByteArray = PackedByteArray()


static func make(grid: HexGrid, nav: NavGrid, water_hexes: Array[Vector2i]) -> Water:
	var water := Water.new()
	water.lasting = water_hexes.duplicate()
	water.set_hexes(grid, nav, water_hexes)
	return water


## Works out the water from the lasting hexes and the layers.
func rebuild(grid: HexGrid, nav: NavGrid) -> void:
	var all: Array[Vector2i] = lasting.duplicate()
	var seen: Dictionary[Vector2i, bool] = {}
	for hex: Vector2i in all:
		seen[hex] = true
	for layer: Layer in layers:
		for hex: Vector2i in layer.hexes:
			if not seen.has(hex):
				seen[hex] = true
				all.append(hex)
	set_hexes(grid, nav, all)


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
			if unit.submerges:
				unit.submerged = unit.on_water and sim.tick >= unit.surfaced_until


## The center of the water hex nearest `point` (ties to the first listed).
func nearest_center(grid: HexGrid, point: Vector2i) -> Vector2i:
	var best: Vector2i = point
	var best_sq: int = -1
	for hex: Vector2i in hexes:
		var middle: Vector2i = grid.center(hex.x, hex.y)
		var distance_sq: int = ArenaPlane.length_sq(middle - point)
		if best_sq < 0 or distance_sq < best_sq:
			best = middle
			best_sq = distance_sq
	return best


## The hexes whose centers lie within `radius` hexes of `point`, and the
## hex under it, but no rock (in the board's order).
static func hexes_near(sim: CombatSim, point: Vector2i, radius: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var under: int = sim.grid.hex_at(point)
	var reach: int = radius * HexGrid.HEX
	for index: int in sim.grid.size():
		var hex := Vector2i(sim.grid.col_of(index), sim.grid.row_of(index))
		if sim.setup.rocks.has(hex):
			continue
		if index == under or ArenaPlane.length_sq(sim.grid.center(hex.x, hex.y) - point) <= reach * reach:
			found.append(hex)
	return found


## A flood (see the top): changes the water by its mode, from `unit` (aimed
## at `target`, for a circle anchored on it), and logs it.
static func flood(sim: CombatSim, unit: UnitState, source: EffectSource, effect: EffectDef, target: UnitState) -> void:
	if sim.water == null:
		sim.water = Water.make(sim.grid, sim.nav(), [] as Array[Vector2i])
		sim.has_water = true
	var water: Water = sim.water
	var before: int = water.hexes.size()
	var at: Vector2i = unit.pos
	var note: String = ""
	match effect.flood_mode:
		EffectDef.FloodMode.CIRCLE:
			if effect.anchor == EffectDef.Anchor.TARGET and target != null:
				at = target.pos
			var circle: Array[Vector2i] = hexes_near(sim, at, effect.flood_radius)
			if effect.zone_ticks > 0:
				var layer := Layer.new()
				layer.hexes = circle
				layer.until_tick = sim.tick + effect.zone_ticks
				layer.source = source
				layer.at = at
				water.layers.append(layer)
			else:
				for hex: Vector2i in circle:
					if not water.lasting.has(hex):
						water.lasting.append(hex)
			water.rebuild(sim.grid, sim.nav())
			note = "floods %d hexes%s" % [circle.size(), " for %s" % _seconds(effect.zone_ticks) if effect.zone_ticks > 0 else ""]
		EffectDef.FloodMode.SPREAD:
			var wider: Array[Vector2i] = water.lasting.duplicate()
			for hex: Vector2i in water.hexes:
				for next: Vector2i in [hex] + sim.grid.neighbors(hex.x, hex.y):
					if not wider.has(next) and not sim.setup.rocks.has(next):
						wider.append(next)
			water.lasting = wider
			water.rebuild(sim.grid, sim.nav())
			note = "spreads to %d more hexes" % (water.hexes.size() - before)
		EffectDef.FloodMode.DRAIN:
			water.lasting = hexes_near(sim, unit.pos, effect.flood_radius)
			water.layers.clear()
			water.rebuild(sim.grid, sim.nav())
			note = "drains to %d hexes" % water.hexes.size()
		EffectDef.FloodMode.ALL:
			water.lasting = hexes_near(sim, unit.pos, sim.grid.width + sim.grid.height)
			water.layers.clear()
			water.rebuild(sim.grid, sim.nav())
			note = "floods the whole board"
	_log(sim, source, at, note, water.hexes.size())


## `ticks` in seconds for the log ("6s", "2.5s").
static func _seconds(ticks: int) -> String:
	@warning_ignore("integer_division")
	var whole: int = ticks / FixedMath.TICKS_PER_SECOND
	@warning_ignore("integer_division")
	var tenths: int = (ticks % FixedMath.TICKS_PER_SECOND) * 10 / FixedMath.TICKS_PER_SECOND
	return "%ds" % whole if tenths == 0 else "%d.%ds" % [whole, tenths]


## Floods that run out this tick recede (see the top).
func tick(sim: CombatSim) -> void:
	var gone: Array[Layer] = layers.filter(func(layer: Layer) -> bool: return sim.tick >= layer.until_tick)
	if gone.is_empty():
		return
	layers = layers.filter(func(layer: Layer) -> bool: return sim.tick < layer.until_tick)
	rebuild(sim.grid, sim.nav())
	for layer: Layer in gone:
		_log(sim, layer.source, layer.at, "recedes", hexes.size())


## A WATER line (amount: how many hexes are water now; to_pos: where it
## happened), and every walker plans again.
static func _log(sim: CombatSim, source: EffectSource, at: Vector2i, note: String, now: int) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.WATER, source)
	entry.note = note
	entry.amount = now
	entry.to_pos = at
	sim.combat_log.add(entry)
	for unit: UnitState in sim.units:
		unit.replan_at = mini(unit.replan_at, sim.tick)
