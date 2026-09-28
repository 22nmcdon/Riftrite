class_name Summons
extends RefCounted
## Summons (docs/plans/rebuild-phase1-arena-sim.md, section 10): the summon
## effect brings new units of a kit the fight's setup lists
## (FightSetup.summon_kits) onto the caster's side.
##
##   - Where (EffectDef.placement), each on a spot where it fits (safe
##     ground, touching nobody):
##       edges     along the edge of the safe ground, a radius in, every
##                 nav cell; the spot nearest the caster (or its target,
##                 "near": "target") first, ties going round clockwise from
##                 the heroes' left corner
##       adjacent  touching the caster, from the 12 points leaps use, the
##                 one straight ahead of it first and then clockwise
##       hexes     each on its hex's center, or else the free spot nearest
##                 it (Displacement.free_spot_near)
##   - A summoned unit joins at the end of the fight's order, so it acts
##     this tick if the order hasn't reached the end yet. It has a unique id
##     (the kit's id, then "#2", "#3", ...), no target, the kit's starting
##     mana, and never counts as a back-liner. Logged as SUMMON.
##   - No side has more than max_units_per_side standing units: extra
##     summons are dropped, and so are those with no room. Both are logged.


## `unit` summons as `effect` says (`aimed_at`: its ability's target, for
## "near": "target").
static func summon(sim: CombatSim, unit: UnitState, source: EffectSource, effect: EffectDef, aimed_at: UnitState) -> void:
	var kit: UnitDef = sim.setup.summon_kit(effect.summon_kit)
	var edges: Array[Vector2i] = []
	if effect.placement == EffectDef.Placement.EDGES:
		var near: Vector2i = aimed_at.pos if effect.near_target and aimed_at != null else unit.pos
		edges = _edge_spots(sim, sim.tuning.unit_radius, near)
	var joined: bool = false
	for i: int in effect.count:
		if sim.standing_count(unit.side) >= sim.tuning.max_units_per_side:
			_log_dropped(sim, source, kit, "its side is full")
			continue
		var summoned: UnitState = UnitState.make_summon(kit, unit.side, sim.next_unit_id(kit.id), sim.units.size(), sim.tuning.unit_radius)
		var spot: Vector2i = _spot(sim, unit, summoned, effect, i, edges)
		if spot.x < 0:
			_log_dropped(sim, source, kit, "no room")
			continue
		summoned.pos = spot
		sim.add_unit(summoned)
		joined = true
		var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, source)
		entry.target = summoned.id
		entry.to_pos = spot
		sim.combat_log.add(entry)
	if joined:
		sim.units_joined()


static func _spot(sim: CombatSim, unit: UnitState, summoned: UnitState, effect: EffectDef, i: int, edges: Array[Vector2i]) -> Vector2i:
	match effect.placement:
		EffectDef.Placement.EDGES:
			for spot: Vector2i in edges:
				if sim.fits(summoned, spot):
					return spot
		EffectDef.Placement.ADJACENT:
			var forward: int = unit.forward()
			for dir: Vector2i in Displacement.LEAP_DIRECTIONS:
				var spot: Vector2i = ArenaPlane.along(unit.pos, dir * forward, unit.radius + summoned.radius)
				if sim.fits(summoned, spot):
					return spot
		EffectDef.Placement.HEXES:
			var hex: Vector2i = effect.summon_hexes[i]
			return Displacement.free_spot_near(sim, summoned, sim.grid.center(hex.x, hex.y), null, 0)
	return Vector2i(-1, -1)


## Spots along the safe ground's edge for a unit of `radius`, nearest `near`
## first (ties in the order they go round).
static func _edge_spots(sim: CombatSim, radius: int, near: Vector2i) -> Array[Vector2i]:
	var step: int = sim.tuning.nav_cell
	var x0: int = sim.safe.position.x + radius
	var y0: int = sim.safe.position.y + radius
	var x1: int = sim.safe.end.x - radius
	var y1: int = sim.safe.end.y - radius
	var round_spots: Array[Vector2i] = []
	for x: int in range(x0, x1, step):
		round_spots.append(Vector2i(x, y0))
	for y: int in range(y0, y1, step):
		round_spots.append(Vector2i(x1, y))
	for x: int in range(x1, x0, -step):
		round_spots.append(Vector2i(x, y1))
	for y: int in range(y1, y0, -step):
		round_spots.append(Vector2i(x0, y))
	# Sort by (distance, place in the round): the keys are unique.
	var keys: Array[int] = []
	for i: int in round_spots.size():
		keys.append(ArenaPlane.length_sq(round_spots[i] - near) * 65536 + i)
	keys.sort()
	var spots: Array[Vector2i] = []
	for key: int in keys:
		spots.append(round_spots[key % 65536])
	return spots


static func _log_dropped(sim: CombatSim, source: EffectSource, kit: UnitDef, why: String) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, source)
	entry.target = kit.id
	entry.note = why
	sim.combat_log.add(entry)
