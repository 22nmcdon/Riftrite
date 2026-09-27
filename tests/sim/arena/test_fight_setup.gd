extends GutTest
## Kits (UnitDef, AbilityDef) and fight setups (docs/plans/rebuild-phase1-arena-sim.md,
## sections 1 and 2).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _kit_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	UnitDef.read(DataReader.new(data, "kit", errors))
	return errors


func _base() -> Dictionary:
	return {"id": "hound", "name": "Hound", "stats": {"hp": 100, "speed": 3},
		"basic_attack": {"id": "bite", "name": "Bite", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}}


func _assert_error(errors: Array[String], expected: String) -> void:
	assert_true(errors.any(func(message: String) -> bool: return message.contains(expected)), "expected '%s' in %s" % [expected, errors])


func test_a_kit_reads_its_stats_and_attack() -> void:
	var errors: Array[String] = []
	var def: UnitDef = UnitDef.read(DataReader.new(_base(), "kit", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([def.id, def.targeting, def.stats.get_stat(UnitStats.Stat.SPEED), def.stats.get_stat(UnitStats.Stat.RANGE)], ["hound", "nearest", 3, 1], "range defaults to melee")
	assert_eq([def.basic_attack.id, def.basic_attack.cooldown_ticks, def.basic_attack.effects.size()], ["bite", 20, 1])
	assert_false(def.basic_attack.is_shot(1), "melee lands at once")
	assert_true(def.basic_attack.is_shot(2), "from 2 hexes it's a shot")


func test_bad_kits() -> void:
	var no_fire: Dictionary = _base()
	no_fire["basic_attack"]["effects"] = [{"trigger": "on_hit", "type": "damage", "amount": 5, "target": "hit_target"}]
	_assert_error(_kit_errors(no_fire), "an ability needs at least one on_fire effect")
	var event: Dictionary = _base()
	event["basic_attack"]["effects"].append({"trigger": "on_kill", "type": "heal", "amount": 5, "target": "self"})
	_assert_error(_kit_errors(event), "an attack's effects can only use on_fire, on_hit, or on_crit")
	var rule: Dictionary = _base()
	rule["targeting"] = "weakest_backliner"
	_assert_error(_kit_errors(rule), "targeting: unknown value \"weakest_backliner\"")
	var later: Dictionary = _base()
	later["mana"] = {"max": 60}
	_assert_error(_kit_errors(later), "unknown key \"mana\"")
	var no_attack: Dictionary = _base()
	no_attack.erase("basic_attack")
	_assert_error(_kit_errors(no_attack), "missing required key \"basic_attack\"")
	var beam: Dictionary = _base()
	beam["basic_attack"]["shot"] = false
	var errors: Array[String] = []
	assert_false(UnitDef.read(DataReader.new(beam, "kit", errors)).basic_attack.is_shot(5), "\"shot\": false lands at once from any range")


func test_a_valid_fight() -> void:
	var hound: UnitDef = K.kit("hound")
	var setup: FightSetup = K.fight([K.at(K.kit("brannoc"), 3, 2)] as Array[UnitSetup], [K.foe(hound, 3, 4), K.foe(hound, 4, 4), K.foe(hound, 5, 5)] as Array[UnitSetup], [Vector2i(0, 3)] as Array[Vector2i])
	assert_eq(setup.validate(K.content()), [] as Array[String])
	var ids: Array[String] = []
	for unit: UnitSetup in setup.units():
		ids.append(unit.id)
	assert_eq(ids, ["brannoc", "hound", "hound#2", "hound#3"] as Array[String], "copies of a kit are numbered")


func test_setups_are_checked() -> void:
	var kit: UnitDef = K.kit("u")
	var cases: Dictionary = {
		"both sides need at least one unit": K.fight([K.at(kit, 0, 0)] as Array[UnitSetup], [] as Array[UnitSetup]),
		"is outside its side's zone": K.fight([K.at(kit, 0, 3)] as Array[UnitSetup], [K.foe(kit, 0, 6, "e")] as Array[UnitSetup]),
		"shares its hex with": K.fight([K.at(kit, 2, 1), K.at(kit, 2, 1, "b")] as Array[UnitSetup], [K.foe(kit, 0, 6, "e")] as Array[UnitSetup]),
		"shares its hex with a rock": K.fight([K.at(kit, 2, 1)] as Array[UnitSetup], [K.foe(kit, 0, 6, "e")] as Array[UnitSetup], [Vector2i(2, 1)] as Array[Vector2i]),
		"is off the board": K.fight([K.at(kit, 8, 1)] as Array[UnitSetup], [K.foe(kit, 0, 6, "e")] as Array[UnitSetup]),
		"a rock at (9, 3) is off the board": K.fight([K.at(kit, 1, 1)] as Array[UnitSetup], [K.foe(kit, 0, 6, "e")] as Array[UnitSetup], [Vector2i(9, 3)] as Array[Vector2i]),
	}
	for expected: String in cases:
		_assert_error((cases[expected] as FightSetup).validate(K.content()), expected)
	# make() numbers copies; a setup built by hand is still checked.
	var twins := FightSetup.new()
	twins.heroes = [K.at(kit, 1, 1, "x")] as Array[UnitSetup]
	twins.enemies = [K.foe(kit, 0, 6, "x")] as Array[UnitSetup]
	_assert_error(twins.validate(K.content()), "two units are called x")
	var crowd: Array[UnitSetup] = []
	for i: int in 31:
		crowd.append(K.at(kit, 0, 0, "u%d" % i))
	_assert_error(K.fight(crowd, [K.foe(kit, 0, 6, "e")] as Array[UnitSetup]).validate(K.content()), "at most 30 units per side")
	assert_false(K.run(K.fight([K.at(kit, 0, 3)] as Array[UnitSetup], [K.foe(kit, 0, 6, "e")] as Array[UnitSetup])).errors.is_empty(), "a bad setup doesn't run")


func test_units_start_on_their_hex_centers() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(K.kit("a"), 1, 2)] as Array[UnitSetup], [K.foe(K.kit("b"), 6, 5)] as Array[UnitSetup]))
	assert_eq(fight.units[0].pos, fight.grid.center(1, 2))
	assert_eq(fight.units[1].pos, fight.grid.center(6, 5))
	assert_eq([fight.units[0].start_row, fight.units[1].start_row], [2, 5])
	fight.units[0].stats.values[UnitStats.Stat.ATK] = 999
	assert_ne(fight.units[0].def.stats.get_stat(UnitStats.Stat.ATK), 999, "each unit has its own copy of its stats")


func test_the_arena_tuning() -> void:
	var tuning: TuningDef = K.content().tuning
	assert_eq([tuning.grid_width, tuning.grid_height, tuning.zone_rows], [8, 7, 3])
	assert_eq([tuning.unit_radius, tuning.rock_radius, tuning.nav_cell], [400, 500, 125])
	assert_eq([tuning.repath_ticks, tuning.repath_give_up_ticks, tuning.max_units_per_side], [10, 20, 30])
