extends RefCounted
## Helpers for building tiny arena fights in tests
## (docs/plans/rebuild-phase1-arena-sim.md, section 13):
##   K.kit("hound", {"stats": {"hp": 100, "atk": 10, "speed": 2}})
##   K.at(kit, col, row)             a hero on a hex
##   K.foe(kit, col, row)            an enemy on a hex
##   K.fight(heroes, enemies, rocks, seed)
## Kits default to a melee unit with speed 2 and a 1s attack for 10 damage.

const HEROES: EffectSource.Team = EffectSource.Team.HEROES
const ENEMIES: EffectSource.Team = EffectSource.Team.ENEMIES

## The real content (tuning and statuses). It's small, so it's loaded fresh
## each time (a static cache would outlive the test run).
static func content() -> ContentDb:
	var loaded: ContentDb = ContentDb.load_dir("res://data")
	assert(loaded.is_valid(), str(loaded.errors))
	return loaded


## A kit read from data, with defaults for anything left out. `overrides`
## replaces top-level keys; "stats" and "basic_attack" merge key by key.
static func kit(kit_id: String, overrides: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {
		"id": kit_id, "name": kit_id.capitalize(),
		"stats": {"hp": 100, "atk": 10, "speed": 2, "range": 1},
		"basic_attack": {"id": kit_id + "_attack", "name": "Strike", "cooldown_ms": 1000,
			"effects": [{"type": "damage", "amount": 10, "target": "target"}]},
	}
	for key: String in overrides:
		if (key == "stats" or key == "basic_attack") and overrides[key] is Dictionary:
			(data[key] as Dictionary).merge(overrides[key], true)
		else:
			data[key] = overrides[key]
	var errors: Array[String] = []
	var def: UnitDef = UnitDef.read(DataReader.new(data, kit_id, errors))
	assert(errors.is_empty(), str(errors))
	return def


static func at(unit_def: UnitDef, col: int, row: int, unit_id: String = "") -> UnitSetup:
	return UnitSetup.make(unit_def, HEROES, col, row, unit_id)


static func foe(unit_def: UnitDef, col: int, row: int, unit_id: String = "") -> UnitSetup:
	return UnitSetup.make(unit_def, ENEMIES, col, row, unit_id)


static func fight(heroes: Array[UnitSetup], enemies: Array[UnitSetup], rocks: Array[Vector2i] = [], fight_seed: int = 1) -> FightSetup:
	return FightSetup.make(heroes, enemies, rocks, fight_seed)


## A fight ready to step tick by tick.
static func sim(setup: FightSetup) -> CombatSim:
	var errors: Array[String] = setup.validate(content())
	assert(errors.is_empty(), str(errors))
	return CombatSim.new(setup, content())


static func run(setup: FightSetup) -> FightResult:
	return CombatSim.run(setup, content())


static func step(fight: CombatSim, ticks: int) -> void:
	for i: int in ticks:
		fight.step()


## The fight's log entries of one kind, optionally only from one unit.
static func entries(fight: CombatSim, kind: LogEntry.Kind, unit_id: String = "") -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in fight.combat_log.entries:
		if entry.kind == kind and (unit_id.is_empty() or entry.source_unit == unit_id):
			found.append(entry)
	return found


## True if no two standing units overlap and each fits in the arena.
static func no_overlaps(fight: CombatSim) -> bool:
	for unit: UnitState in fight.units:
		if not unit.alive:
			continue
		if not ArenaPlane.inside(fight.grid.bounds(), unit.pos, unit.radius):
			return false
		for circle: ArenaPlane.Circle in fight.obstacles_for(unit, null):
			if ArenaPlane.overlaps(unit.pos, unit.radius, circle.center, circle.radius):
				return false
	return true
