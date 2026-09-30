class_name Areas
extends RefCounted
## Area effects (docs/plans/rebuild-phase1-arena-sim.md, section 7; the data
## is EffectDef's area and ShapeDef).
##   - Cast (as its ability fires, or on a passive's trigger): where it
##     goes is fixed now, so a warned area doesn't follow anyone: a circle
##     or ring on the target (or the unit), a line or cone from the unit's
##     edge aimed at the target. Its effects' numbers and crit chance are
##     fixed now too, like a shot's.
##   - Warned (warning_ms): AREA_WARNING is logged with the shape, where it
##     is, and the landing tick, and it lands then (the tick's step 4, after
##     shots, in the order they were cast). Without a warning, it lands at
##     once. It lands even if the unit fell meanwhile.
##   - Landing: AREA_LANDED, then each of its effects on every standing unit
##     it hits (by `hits`) whose center is inside, in the fight's order; a
##     damage effect rolls its crit then. A knockback goes straight away
##     from a circle's or ring's center, or from the unit for a line or
##     cone; a pull goes toward the unit.
##   - Sides (phase 4): a nested effect with a "side" lands only on units
##     of that side, relative to the caster (Sunfall harms enemies and heals
##     allies in one line).
##   - Zones (phase 4): an area with a duration stays where it was cast. It's
##     logged once (ZONE: the shape, where, and the tick it ends), then lands
##     at once and every pulse after (each an AREA_LANDED, like any area),
##     until it ends; its numbers were fixed as it was cast. It keeps going
##     if the unit falls. Zones pulse just before the warned areas land, in
##     the order they were cast.
## Heroes never step out of a warned area (decided): placement is the answer.


## One area on its way.
class Pending:
	var unit: UnitState
	var ability: AbilityDef
	var source: EffectSource
	var effect: EffectDef
	## A circle's or ring's center; a line's or cone's start.
	var origin: Vector2i
	var dir: Vector2i
	## Where knockbacks go away from.
	var push_from: Vector2i
	var land_tick: int
	var amounts: Array[int] = []
	## Each effect's power bonus (EffectRunner.power_of), applied as it lands.
	var powers: Array[int] = []
	var crit_bp: int = 0
	## A zone: the tick it ends (exclusive; -1: not a zone).
	var until_tick: int = -1


## `unit`'s ability casts the area `effect` at `target` (null for an area on
## the unit itself). `heal_boost_bp`: a Wait to heal payoff on its heals.
static func cast(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, target: UnitState, heal_boost_bp: int = 0) -> void:
	var area := Pending.new()
	area.unit = unit
	area.ability = ability
	area.source = source
	area.effect = effect
	area.dir = ArenaPlane.direction(unit.pos, target.pos if target != null else unit.pos, Vector2i(0, ArenaPlane.DIR * unit.forward()))
	match effect.anchor:
		EffectDef.Anchor.TARGET:
			area.origin = target.pos if target != null else unit.pos
			area.push_from = area.origin
		EffectDef.Anchor.SELF:
			area.origin = unit.pos
			area.push_from = area.origin
		EffectDef.Anchor.TARGET_DIRECTION:
			area.origin = ArenaPlane.along(unit.pos, area.dir, unit.radius)
			area.push_from = unit.pos
	for nested: EffectDef in effect.area_effects:
		area.amounts.append(EffectRunner.amount_of(nested, unit, 0, sim))
		area.powers.append(EffectRunner.power_of(nested, unit, heal_boost_bp))
	area.crit_bp = EffectRunner.crit_chance_bp(sim, unit, ability)
	area.land_tick = sim.tick + effect.warning_ticks
	if effect.zone_ticks > 0:
		area.until_tick = sim.tick + effect.zone_ticks
		var zone: LogEntry = _entry(sim, LogEntry.Kind.ZONE, area)
		zone.end_tick = area.until_tick
		sim.combat_log.add(zone)
		sim.zones.append(area)
		_land(sim, area)
		area.land_tick += effect.pulse_ticks
		return
	if effect.warning_ticks == 0:
		_land(sim, area)
		return
	var entry: LogEntry = _entry(sim, LogEntry.Kind.AREA_WARNING, area)
	entry.end_tick = area.land_tick
	sim.combat_log.add(entry)
	sim.areas.append(area)


## Lands every warned area that's due, in the order they were cast, then
## pulses every zone that's due.
static func land_due(sim: CombatSim) -> void:
	if not sim.zones.is_empty():
		_pulse_zones(sim)
	if sim.areas.is_empty():
		return
	var waiting: Array[Pending] = []
	for area: Pending in sim.areas:
		if area.land_tick > sim.tick:
			waiting.append(area)
		else:
			_land(sim, area)
	sim.areas = waiting


## Each zone lands again when its pulse is due, and goes once it ends.
## (Before the warned areas each tick: a zone cast this tick has already
## landed once.)
static func _pulse_zones(sim: CombatSim) -> void:
	var staying: Array[Pending] = []
	for zone: Pending in sim.zones:
		if sim.tick >= zone.until_tick:
			continue
		if sim.tick >= zone.land_tick:
			_land(sim, zone)
			zone.land_tick += zone.effect.pulse_ticks
		staying.append(zone)
	sim.zones = staying


static func _land(sim: CombatSim, area: Pending) -> void:
	var hit: Array[UnitState] = []
	for other: UnitState in sim.units:
		if other.alive and _counts(area, other) and area.effect.shape.contains(area.origin, area.dir, other.pos):
			hit.append(other)
	var landed: LogEntry = _entry(sim, LogEntry.Kind.AREA_LANDED, area)
	landed.amount = hit.size()
	sim.combat_log.add(landed)
	# (A unit knocked to 0 by one effect still takes the rest: it falls in
	# the tick's deaths step, like any other.)
	for victim: UnitState in hit:
		for i: int in area.effect.area_effects.size():
			var nested: EffectDef = area.effect.area_effects[i]
			if nested.side != EffectDef.AreaSide.BOTH and (victim.side == area.unit.side) != (nested.side == EffectDef.AreaSide.ALLIES):
				continue
			var crit: bool = nested.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(area.crit_bp)
			EffectRunner.land(sim, area.unit, area.ability, area.source, nested, victim, area.amounts[i], crit, area.push_from, area.powers[i])


static func _counts(area: Pending, other: UnitState) -> bool:
	match area.effect.hits:
		EffectDef.Hits.ENEMIES:
			return other.side != area.unit.side
		EffectDef.Hits.ALLIES:
			return other.side == area.unit.side
		EffectDef.Hits.OTHER_ALLIES:
			return other.side == area.unit.side and other != area.unit
	return true


static func _entry(sim: CombatSim, kind: LogEntry.Kind, area: Pending) -> LogEntry:
	var entry: LogEntry = sim.new_entry(kind, area.source)
	entry.shape = area.effect.shape.describe()
	entry.from_pos = area.origin
	entry.to_pos = area.origin
	if area.effect.shape.is_aimed():
		entry.to_pos = ArenaPlane.along(area.origin, area.dir, area.effect.shape.size * HexGrid.HEX)
	entry.end_tick = area.land_tick
	return entry
