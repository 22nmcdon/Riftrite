class_name Gambits
extends RefCounted
## Gambits in a fight (docs/plans/rebuild-phase5c-combos.md, step 6d,
## section 14.7): placement and fight-start rules, read from the kit
## (UnitDef's gambit fields, set by a gambit's kit mod). A fight with none
## never reaches this code.
##   place "neutral"  it may also start on the neutral row (Infiltrate)
##   place "front"    and on the enemies' front row too (Infiltrate II)
##   place "edge"     and on any hex of the board's edge (Late Arrival)
##   place "share"    it may share its hex with another hero; the two start
##                    side by side across it (Stand Together)
##   arrive_ms        it starts away and enters then, where it was placed
##                    or on the nearest free safe spot (ARRIVE; Late
##                    Arrival); until then it isn't on the board, can't be
##                    targeted, and isn't down
##   swap_ms          then it swaps places with its ally farthest from it,
##                    each Shielded by swap_shield_bp of its max HP (two
##                    PUSH lines noted "swapped places"; Switch Places)
## Phase 8 part 3 (the Burrowing Pup): any unit may arrive late, enemies
## too, and "arrive_at": "back_line" brings it up at the free spot nearest
## the other side's hindmost standing unit (the one nearest its own back
## edge; ties to the first in the fight's order).
## Its other parts (Stealth at the start, a boost on arriving, a first
## hit's Mark) are its kit mod's passives: on_fight_start and on_arrive.

const PLACES: Array[String] = ["", "neutral", "front", "edge", "share"]
const ARRIVE_AT: Array[String] = ["", "back_line"]
## How far apart two heroes sharing a hex start, along the row (plane units).
const SHARED_GAP: int = 666


## True if a hero whose kit places by `place` may start on (col, row), its
## own zone aside.
static func may_place(grid: HexGrid, place: String, col: int, row: int) -> bool:
	match place:
		"neutral":
			return grid.zone(row) == HexGrid.Zone.NEUTRAL
		"front":
			return grid.zone(row) == HexGrid.Zone.NEUTRAL or row == grid.height - grid.zone_rows
		"edge":
			return col == 0 or col == grid.width - 1 or row == 0 or row == grid.height - 1
	return false


## As the fight is built: heroes sharing a hex stand apart across it, and a
## hero arriving later starts away.
static func set_up(sim: CombatSim) -> void:
	var by_hex: Dictionary[Vector2i, UnitState] = {}
	for unit: UnitState in sim.heroes:
		var hex := Vector2i(unit.start_col, unit.start_row)
		if by_hex.has(hex):
			var first: UnitState = by_hex[hex]
			first.pos = first.pos - Vector2i(SHARED_GAP >> 1, 0)
			unit.pos = unit.pos + Vector2i(SHARED_GAP >> 1, 0)
		else:
			by_hex[hex] = unit
		if unit.def.swap_ticks > 0 or unit.swap_at > 0:
			sim.swaps = true
	for unit: UnitState in sim.units:
		if unit.def.arrive_ticks > 0:
			unit.alive = false
			unit.arriving = true
			sim.arrivals = true


## Each tick: those due arrive, and those due swap.
static func tick(sim: CombatSim) -> void:
	if sim.arrivals:
		for unit: UnitState in sim.units:
			if unit.arriving and sim.tick >= unit.def.arrive_ticks:
				_arrive(sim, unit)
	for unit: UnitState in sim.heroes:
		var swap_at: int = unit.swap_at if unit.swap_at > 0 else unit.def.swap_ticks
		if swap_at > 0 and sim.tick == swap_at and unit.alive:
			_swap(sim, unit)


static func _source(unit: UnitState) -> EffectSource:
	return EffectSource.make(unit.id, "gambit", unit.def.gambit_label)


static func _arrive(sim: CombatSim, unit: UnitState) -> void:
	unit.arriving = false
	var at: Vector2i = unit.pos
	if unit.def.arrive_at == "back_line":
		var hindmost: UnitState = _hindmost(sim, unit)
		if hindmost != null:
			at = hindmost.pos
	var spot: Vector2i = at if sim.fits(unit, at) else Displacement.free_spot_near(sim, unit, sim.nearest_safe_point(at, unit.radius), null, 0)
	if spot.x < 0:
		return
	unit.alive = true
	unit.pos = spot
	unit.moved_at = sim.tick
	unit.replan_at = sim.tick + 1
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.ARRIVE, _source(unit))
	entry.target = unit.id
	entry.to_pos = spot
	sim.combat_log.add(entry)
	sim.listen()
	sim.refold_auras()


## The other side's standing unit nearest its own back edge (see the top).
static func _hindmost(sim: CombatSim, unit: UnitState) -> UnitState:
	var found: UnitState = null
	for other: UnitState in sim.standing_enemies_of(unit):
		# A hero's back is low y, an enemy's high: forward() is +1 for heroes.
		if found == null or other.pos.y * other.forward() < found.pos.y * found.forward():
			found = other
	return found


static func _swap(sim: CombatSim, unit: UnitState) -> void:
	var other: UnitState = null
	var best_sq: int = -1
	for ally: UnitState in sim.standing_allies_of(unit):
		var distance_sq: int = ArenaPlane.length_sq(ally.pos - unit.pos)
		if ally != unit and distance_sq > best_sq:
			other = ally
			best_sq = distance_sq
	if other == null:
		return
	var source: EffectSource = _source(unit)
	var here: Vector2i = unit.pos
	var there: Vector2i = other.pos
	for pair: Array in [[unit, here, there], [other, there, here]]:
		var mover: UnitState = pair[0]
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.PUSH, source)
		entry.target = mover.id
		entry.from_pos = pair[1]
		entry.to_pos = pair[2]
		entry.note = "swapped places"
		sim.combat_log.add(entry)
	Displacement.place(sim, unit, there)
	Displacement.place(sim, other, here)
	if unit.def.swap_shield_bp > 0:
		for shielded: UnitState in [unit, other]:
			EffectRunner.give_shield(sim, shielded, FixedMath.apply_bp(shielded.max_hp, unit.def.swap_shield_bp), source)
