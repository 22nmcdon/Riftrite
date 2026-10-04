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
##       water     (phase 8 part 3) each on the water hex nearest any of
##                 its enemies, at the free spot nearest its center; none
##                 without water (dropped: "no water")
##   - A rise as another kit (phase 8 part 3; PartDef's rise "as") stands a
##     fresh unit of that kit where the fallen one fell (rise_as), logged as
##     a SUMMON sourced to the rise.
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
		if effect.placement == EffectDef.Placement.WATER and (not sim.has_water or sim.water.hexes.is_empty()):
			_log_dropped(sim, source, kit, "no water")
			continue
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
		EffectDef.Placement.WATER:
			return Displacement.free_spot_near(sim, summoned, _water_near_enemy(sim, unit), null, 0)
	return Vector2i(-1, -1)


## The center of the water hex nearest any standing enemy of `unit` (ties to
## the first water hex, then the first enemy).
static func _water_near_enemy(sim: CombatSim, unit: UnitState) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_sq: int = -1
	for hex: Vector2i in sim.water.hexes:
		var middle: Vector2i = sim.grid.center(hex.x, hex.y)
		for enemy: UnitState in sim.standing_enemies_of(unit):
			var distance_sq: int = ArenaPlane.length_sq(enemy.pos - middle)
			if best_sq < 0 or distance_sq < best_sq:
				best = middle
				best_sq = distance_sq
	return best if best.x >= 0 else sim.grid.center(sim.water.hexes[0].x, sim.water.hexes[0].y)


## A fallen unit rises as another kit (see the top): a fresh one at the
## free spot nearest where it fell, at the rise's share of its max HP. With
## no room, or its side full, none (dropped).
static func rise_as(sim: CombatSim, fallen: UnitState, part: PartDef) -> void:
	var kit: UnitDef = sim.setup.summon_kit(part.rise_as)
	var source: EffectSource = EffectSource.make(fallen.id, part.id, part.name)
	if sim.standing_count(fallen.side) >= sim.tuning.max_units_per_side:
		_log_dropped(sim, source, kit, "its side is full")
		return
	var risen: UnitState = UnitState.make_summon(kit, fallen.side, sim.next_unit_id(kit.id), sim.units.size(), sim.tuning.unit_radius)
	var spot: Vector2i = Displacement.free_spot_near(sim, risen, sim.nearest_safe_point(fallen.pos, risen.radius), null, 0)
	if spot.x < 0:
		_log_dropped(sim, source, kit, "no room")
		return
	risen.pos = spot
	risen.hp = maxi(FixedMath.apply_bp(risen.max_hp, part.rise_hp_bp), 1)
	sim.add_unit(risen)
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SUMMON, source)
	entry.target = risen.id
	entry.to_pos = spot
	entry.note = ""
	sim.combat_log.add(entry)
	sim.units_joined()


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
