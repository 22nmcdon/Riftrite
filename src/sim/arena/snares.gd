class_name Snares
extends RefCounted
## Snares (docs/plans/rebuild-phase4-paths.md, section 5, P8; Trapper Maren):
## a snare lies on the plane until the first enemy of its owner walks into it.
##   - Set by a snare effect (EffectDef: max_standing, and its own effects),
##     "in the path" of the ability's target: ahead of it toward whatever
##     it's going for (its own target, or else the unit that set the snare),
##     1 hex or half the way there, whichever is less (so one that has
##     arrived is snared where it stands), kept on safe ground. Or placed by the player before the
##     fight (UnitSetup.snares), from the first snare effect in the unit's
##     kit.
##   - Its effects' numbers are fixed as it's set, like a shot's.
##   - It springs on the first standing enemy (in the fight's order) whose
##     center comes within RADIUS (half a hex: the snare covers its hex) of
##     it, checked after every unit has acted
##     each tick; a unit in the air flies over it. It lands its effects on
##     that enemy and is gone.
##   - With max_standing, setting one more than that removes the oldest of
##     that unit's snares from the same effect.
##   - Logged (SNARE): "set" (to_pos: where), "sprung" (target: who), or
##     "gone" (replaced). It stays if its owner falls.
##   - Phase 5c step 7d: a snare that snags (Snag) also springs on an enemy
##     whose leap or charge passes over it, once it lands; a snare effect
##     "under" the front ally (Guarded Ground) sets one of the kit's placed
##     kind under its side's front-most unit.

## How close a unit's center must come (plane units).
const RADIUS: int = 500


## One snare on the ground.
class Snare:
	var unit: UnitState
	var ability: AbilityDef
	var source: EffectSource
	var effect: EffectDef
	var pos: Vector2i
	var amounts: Array[int] = []
	## Each effect's power bonus (EffectRunner.power_of), applied as it lands.
	var powers: Array[int] = []


## `unit`'s ability sets a snare with `effect` in `target`'s path.
static func set_ahead(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, target: UnitState) -> void:
	if target == null:
		return
	var toward: UnitState = target.target if target.target != null and target.target.alive else unit
	var dir: Vector2i = ArenaPlane.direction(target.pos, toward.pos, Vector2i(0, ArenaPlane.DIR * target.forward()))
	@warning_ignore("integer_division")
	var ahead: int = mini(HexGrid.HEX, ArenaPlane.distance(target.pos, toward.pos) / 2)
	var point: Vector2i = ArenaPlane.along(target.pos, dir, ahead)
	place(sim, unit, ability, source, effect, sim.nearest_safe_point(point, 0))


## Sets a snare at `point` (logged "set"), removing the oldest of the same
## kind first if that would go past max_standing.
static func place(sim: CombatSim, unit: UnitState, ability: AbilityDef, source: EffectSource, effect: EffectDef, point: Vector2i) -> void:
	if effect.max_standing > 0:
		var mine: Array[Snare] = sim.snares.filter(func(other: Snare) -> bool: return other.unit == unit and other.effect == effect)
		if mine.size() >= effect.max_standing:
			var oldest: Snare = mine[0]
			sim.snares.erase(oldest)
			_log(sim, oldest, "gone", "")
	var snare := Snare.new()
	snare.unit = unit
	snare.ability = ability
	snare.source = source
	snare.effect = effect
	snare.pos = point
	for nested: EffectDef in effect.area_effects:
		snare.amounts.append(EffectRunner.amount_of(nested, unit, 0, sim))
		snare.powers.append(EffectRunner.power_of(nested, unit))
	sim.snares.append(snare)
	_log(sim, snare, "set", "")


## Springs every snare an enemy has walked into, in the order they were set.
static func check(sim: CombatSim) -> void:
	var staying: Array[Snare] = []
	for snare: Snare in sim.snares:
		var caught: UnitState = null
		for other: UnitState in sim.units:
			if other.alive and other.side != snare.unit.side and not other.airborne \
					and ArenaPlane.length_sq(other.pos - snare.pos) <= RADIUS * RADIUS:
				caught = other
				break
		if caught == null:
			staying.append(snare)
			continue
		_spring(sim, snare, caught)
	sim.snares = staying


static func _spring(sim: CombatSim, snare: Snare, caught: UnitState) -> void:
	_log(sim, snare, "sprung", caught.id)
	for i: int in snare.effect.area_effects.size():
		var nested: EffectDef = snare.effect.area_effects[i]
		var crit: bool = nested.type == EffectDef.Type.DAMAGE and sim.rng.roll_bp(EffectRunner.crit_chance_bp(sim, snare.unit, snare.ability))
		EffectRunner.land(sim, snare.unit, snare.ability, snare.source, nested, caught, snare.amounts[i], crit, snare.pos, snare.powers[i])


## `unit` leapt or charged from `from` to `to` (phase 5c step 7d, Snag):
## each enemy snare that snags whose spot the way passed over springs on it.
static func snag(sim: CombatSim, unit: UnitState, from: Vector2i, to: Vector2i) -> void:
	for snare: Snare in sim.snares.duplicate():
		if snare.effect.snags and snare.unit.side != unit.side and unit.alive and _over(snare.pos, from, to):
			sim.snares.erase(snare)
			_spring(sim, snare, unit)


## True if `point` is within RADIUS of the way from `from` to `to`.
static func _over(point: Vector2i, from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return ArenaPlane.length_sq(point - from) <= RADIUS * RADIUS
	var dir: Vector2i = ArenaPlane.direction(from, to, Vector2i(0, ArenaPlane.DIR))
	var along: int = ArenaPlane.dot(point - from, dir)
	if along <= 0:
		return ArenaPlane.length_sq(point - from) <= RADIUS * RADIUS
	if along >= ArenaPlane.distance(from, to) * ArenaPlane.DIR:
		return ArenaPlane.length_sq(point - to) <= RADIUS * RADIUS
	return absi(ArenaPlane.cross(dir, point - from)) <= RADIUS * ArenaPlane.DIR


## Guarded Ground (phase 5c step 7d): one of `unit`'s placed snares, set
## under its side's front-most standing unit (it counts toward their most
## standing).
static func under_front(sim: CombatSim, unit: UnitState) -> void:
	var effect: EffectDef = placed_effect(unit.def)
	var ability: AbilityDef = placed_ability(unit.def)
	var front: UnitState = sim.front_of(sim.heroes if unit.side == EffectSource.Team.HEROES else sim.enemies)
	if effect == null or ability == null or front == null:
		return
	place(sim, unit, ability, EffectSource.make(unit.id, ability.id, ability.name), effect, front.pos)


## The snares the player placed for `unit` before the fight, from the first
## snare effect in its kit, one on each hex's center.
static func place_setup(sim: CombatSim, unit: UnitState, hexes: Array[Vector2i]) -> void:
	var effect: EffectDef = placed_effect(unit.def)
	var ability: AbilityDef = placed_ability(unit.def)
	if effect == null or ability == null:
		return
	var source: EffectSource = EffectSource.make(unit.id, ability.id, ability.name)
	for hex: Vector2i in hexes:
		place(sim, unit, ability, source, effect, sim.grid.center(hex.x, hex.y))


## The first snare effect in `kit` (for the snares the player places), or null.
static func placed_effect(kit: UnitDef) -> EffectDef:
	for effect: EffectDef in kit.all_effects():
		if effect.type == EffectDef.Type.SNARE and not effect.under_front:
			return effect
	return null


## The ability `kit`'s placed snares are credited to: the one holding its
## first snare effect.
static func placed_ability(kit: UnitDef) -> AbilityDef:
	var abilities: Array[AbilityDef] = [kit.signature, kit.basic_attack]
	for part: PartDef in kit.passives:
		abilities.append(part.ability)
	for ability: AbilityDef in abilities:
		if ability == null:
			continue
		for effect: EffectDef in ability.effects:
			if effect.type == EffectDef.Type.SNARE and not effect.under_front:
				return ability
	return null


static func _log(sim: CombatSim, snare: Snare, note: String, target_id: String) -> void:
	var entry: LogEntry = sim.new_entry(LogEntry.Kind.SNARE, snare.source)
	entry.note = note
	entry.target = target_id
	entry.from_pos = snare.pos
	entry.to_pos = snare.pos
	sim.combat_log.add(entry)
