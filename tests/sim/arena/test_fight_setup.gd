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
	_assert_error(_kit_errors(event), "an ability's effects can only use on_fire, on_hit, or on_crit")
	var rule: Dictionary = _base()
	rule["targeting"] = "self"
	_assert_error(_kit_errors(rule), "targeting: unknown value \"self\"")
	var later: Dictionary = _base()
	later["traits"] = ["burrowing"]
	_assert_error(_kit_errors(later), "traits[0]: unknown value \"burrowing\" (expected one of: engage, flying, hop_away, fires_moving, inert)")
	var hopper: Dictionary = _base()
	hopper["traits"] = ["hop_away"]
	_assert_error(_kit_errors(hopper), "missing required key \"hop_cooldown_ms\"")
	var stray: Dictionary = _base()
	stray["hop_cooldown_ms"] = 6000
	_assert_error(_kit_errors(stray), "hop_cooldown_ms: only a unit with the hop_away trait hops")
	var no_attack: Dictionary = _base()
	no_attack.erase("basic_attack")
	_assert_error(_kit_errors(no_attack), "missing required key \"basic_attack\"")
	var beam: Dictionary = _base()
	beam["basic_attack"]["shot"] = false
	var errors: Array[String] = []
	assert_false(UnitDef.read(DataReader.new(beam, "kit", errors)).basic_attack.is_shot(5), "\"shot\": false lands at once from any range")


func test_a_kit_with_mana_and_a_signature() -> void:
	var data: Dictionary = _base()
	data["mana"] = {"max": 60, "start": 20, "per_attack": 12, "per_10_damage_taken": 1, "regen_per_s": 2}
	data["signature"] = {"id": "mend", "name": "Mend", "trigger": {"kind": "mana"}, "targeting": "self", "max_range": 3, "cast_ms": 500,
		"effects": [{"type": "heal", "amount": 20, "target": "target"}]}
	var errors: Array[String] = []
	var def: UnitDef = UnitDef.read(DataReader.new(data, "kit", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([def.mana.max, def.mana.start, def.mana.per_attack, def.mana.per_10_damage_taken, def.mana.regen_per_s], [60, 20, 12, 1, 2])
	var mend: AbilityDef = def.signature
	assert_eq([mend.trigger.kind, mend.targeting, mend.max_range, mend.cast_ticks, mend.is_signature()], [TriggerDef.Kind.MANA, "self", 3, 10, true])
	assert_eq([mend.reach_for(1), def.basic_attack.reach_for(4)], [3, 4], "max_range, or the unit's own range")
	assert_false(def.basic_attack.is_signature())
	var count: Dictionary = _base()
	count["signature"] = {"id": "rage", "name": "Rage", "trigger": {"kind": "count", "event": "on_hit_taken", "every": 5}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}
	var counted: TriggerDef = UnitDef.read(DataReader.new(count, "kit", errors)).signature.trigger
	assert_eq([counted.kind, counted.event, counted.every, counted.is_once()], [TriggerDef.Kind.COUNT, EffectDef.Trigger.ON_HIT_TAKEN, 5, false])
	var timed: Dictionary = _base()
	timed["signature"] = {"id": "howl", "name": "Howl", "trigger": {"kind": "at_time", "at_ms": 8000}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}
	var at_time: TriggerDef = UnitDef.read(DataReader.new(timed, "kit", errors)).signature.trigger
	assert_eq([at_time.at_ticks, at_time.is_once()], [160, true])
	assert_eq(errors, [] as Array[String])


func test_bad_signatures() -> void:
	var effects: Array = [{"type": "damage", "amount": 1, "target": "target"}]
	var no_mana: Dictionary = _base()
	no_mana["signature"] = {"id": "burst", "name": "Burst", "trigger": {"kind": "mana"}, "effects": effects}
	_assert_error(_kit_errors(no_mana), "a mana signature needs \"mana\"")
	var idle_bar: Dictionary = _base()
	idle_bar["mana"] = {"max": 60}
	_assert_error(_kit_errors(idle_bar), "only a unit whose signature fires on mana has a mana bar")
	idle_bar["signature"] = {"id": "stand", "name": "Stand", "trigger": {"kind": "hp_below", "threshold_bp": 3000}, "effects": effects}
	_assert_error(_kit_errors(idle_bar), "only a unit whose signature fires on mana has a mana bar")
	var cast: Dictionary = _base()
	cast["signature"] = {"id": "stand", "name": "Stand", "trigger": {"kind": "hp_below", "threshold_bp": 3000}, "cast_ms": 500, "effects": effects}
	_assert_error(_kit_errors(cast), "cast_ms: only a mana signature can have a cast")
	var same: Dictionary = _base()
	same["signature"] = {"id": "bite", "name": "Big Bite", "trigger": {"kind": "fight_start"}, "effects": effects}
	_assert_error(_kit_errors(same), "its abilities and passives need different ids (\"bite\" twice)")
	var event: Dictionary = _base()
	event["signature"] = {"id": "count", "name": "Count", "trigger": {"kind": "count", "event": "on_fire"}, "effects": effects}
	_assert_error(_kit_errors(event), "event: unknown value \"on_fire\"")
	var itself: Dictionary = _base()
	itself["signature"] = {"id": "count", "name": "Count", "trigger": {"kind": "count", "event": "on_ability"}, "effects": effects}
	_assert_error(_kit_errors(itself), "a signature can't count on_ability")
	var threshold: Dictionary = _base()
	threshold["signature"] = {"id": "stand", "name": "Stand", "trigger": {"kind": "hp_below", "threshold_bp": 10000}, "effects": effects}
	_assert_error(_kit_errors(threshold), "threshold_bp: 10000 is out of range")
	var rule: Dictionary = _base()
	rule["signature"] = {"id": "stand", "name": "Stand", "trigger": {"kind": "fight_start"}, "targeting": "sneakiest", "cooldown_ms": 1000, "effects": effects}
	var errors: Array[String] = _kit_errors(rule)
	_assert_error(errors, "targeting: unknown value \"sneakiest\"")
	_assert_error(errors, "unknown key \"cooldown_ms\"")
	var start: Dictionary = _base()
	start["mana"] = {"max": 60, "start": 70}
	start["signature"] = {"id": "burst", "name": "Burst", "trigger": {"kind": "mana"}, "effects": effects}
	_assert_error(_kit_errors(start), "start: 70 is out of range")


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
	assert_eq([tuning.unit_radius, tuning.rock_radius, tuning.nav_cell, tuning.melee_reach], [100, 500, 125, 500], "units 0.2 hex wide, melee reaching half a hex (playtest gate 1)")
	assert_eq([tuning.repath_ticks, tuning.repath_give_up_ticks, tuning.max_units_per_side], [10, 20, 30])
