extends GutTest
## Shallow water, Act 2's board rule (docs/plans/rebuild-phase8-act2.md,
## section 3; Water): half speed unless a unit swims or flies, routes round
## it when that's shorter, Burn halved on it, the on_water condition, the
## Steaming Ashling, and the setup's checks.

const K = preload("res://tests/sim/sim_test_kit.gd")


static func still(unit_id: String, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 5000, "atk": 10, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	for key: String in extra:
		if key == "stats":
			(data["stats"] as Dictionary).merge(extra["stats"], true)
		else:
			data[key] = extra[key]
	return K.kit(unit_id, data)


static func walker(unit_id: String, extra: Dictionary = {}) -> UnitDef:
	var merged: Dictionary = {"stats": {"speed": 2}}
	merged.merge(extra, true)
	if extra.has("stats"):
		merged["stats"] = {"speed": 2}
		(merged["stats"] as Dictionary).merge(extra["stats"], true)
	return still(unit_id, merged)


## A walker at (3, 0) heading for a still enemy at (3, 6), with `water`.
func walk_fight(kit: UnitDef, water: Array[Vector2i]) -> CombatSim:
	var setup: FightSetup = K.fight([K.at(kit, 3, 0, "walker")] as Array[UnitSetup], [K.foe(still("target"), 3, 6)] as Array[UnitSetup])
	setup.water = water
	return K.sim(setup)


## Water over the heroes' whole zone: nowhere to step out of it.
static func lake() -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for row: int in 3:
		for col: int in 8:
			hexes.append(Vector2i(col, row))
	return hexes


func test_hex_at_finds_the_nearest_center_everywhere() -> void:
	var grid: HexGrid = K.content().tuning.make_grid()
	var bounds: Rect2i = grid.bounds()
	var wrong: Array[String] = []
	for y: int in range(bounds.position.y - 300, bounds.end.y + 300, 137):
		for x: int in range(bounds.position.x - 300, bounds.end.x + 300, 131):
			var point := Vector2i(x, y)
			if grid.hex_at(point) != grid.nearest_hex(point):
				wrong.append(str(point))
	assert_eq(wrong, [] as Array[String])


func test_a_walker_on_water_steps_half_as_far_and_says_so() -> void:
	var column: Array[Vector2i] = lake()
	var dry: CombatSim = walk_fight(walker("hero"), [] as Array[Vector2i])
	var wet: CombatSim = walk_fight(walker("hero"), column)
	var start: Vector2i = dry.unit_by_id("walker").pos
	K.step(dry, 10)
	K.step(wet, 10)
	var dry_moved: int = ArenaPlane.distance(start, dry.unit_by_id("walker").pos)
	var wet_moved: int = ArenaPlane.distance(start, wet.unit_by_id("walker").pos)
	assert_gt(dry_moved, 0)
	assert_eq(wet_moved * 2, dry_moved, "half as far on water")
	assert_true(wet.unit_by_id("walker").on_water)
	var legs: Array[LogEntry] = K.entries(wet, LogEntry.Kind.MOVE, "walker")
	assert_eq(legs[0].note, "in water")
	assert_string_contains(legs[0].to_text(), "(in water)")
	assert_eq(K.entries(dry, LogEntry.Kind.MOVE, "walker")[0].note, "", "dry legs say nothing")


func test_swimmers_and_fliers_are_not_slowed() -> void:
	var column: Array[Vector2i] = lake()
	var dry: CombatSim = walk_fight(walker("hero"), [] as Array[Vector2i])
	var swimmer: CombatSim = walk_fight(walker("hero", {"traits": ["swims"]}), column)
	var flier: CombatSim = walk_fight(walker("hero", {"traits": ["flying"]}), column)
	var start: Vector2i = dry.unit_by_id("walker").pos
	for fight: CombatSim in [dry, swimmer, flier]:
		K.step(fight, 10)
	var dry_moved: int = ArenaPlane.distance(start, dry.unit_by_id("walker").pos)
	assert_eq(ArenaPlane.distance(start, swimmer.unit_by_id("walker").pos), dry_moved, "a swimmer")
	assert_eq(ArenaPlane.distance(start, flier.unit_by_id("walker").pos), dry_moved, "a flier")
	assert_true(swimmer.unit_by_id("walker").on_water, "a swimmer is on water all the same")
	assert_false(flier.unit_by_id("walker").on_water, "a flier never is")


func test_a_route_goes_round_a_pool_but_crosses_a_river() -> void:
	# One hex of water on the straight line: the way round is shorter.
	var pool: CombatSim = walk_fight(walker("hero"), [Vector2i(3, 3)] as Array[Vector2i])
	var wet_ticks: int = 0
	for i: int in 200:
		pool.step()
		if pool.unit_by_id("walker").on_water:
			wet_ticks += 1
	assert_eq(wet_ticks, 0, "round the pool")
	assert_lt(ArenaPlane.distance(pool.unit_by_id("walker").pos, pool.unit_by_id("target").pos), 1000, "and on to its target")
	# A river across the whole board: no way round, so it wades.
	var row: Array[Vector2i] = []
	for col: int in 8:
		row.append(Vector2i(col, 3))
	var river: CombatSim = walk_fight(walker("hero"), row)
	wet_ticks = 0
	for i: int in 300:
		river.step()
		if river.unit_by_id("walker").on_water:
			wet_ticks += 1
	assert_gt(wet_ticks, 0, "across the river")
	assert_lt(ArenaPlane.distance(river.unit_by_id("walker").pos, river.unit_by_id("target").pos), 1000, "and on to its target")
	# A swimmer doesn't go round.
	var swimmer: CombatSim = walk_fight(walker("hero", {"traits": ["swims"]}), [Vector2i(3, 3)] as Array[Vector2i])
	wet_ticks = 0
	for i: int in 200:
		swimmer.step()
		if swimmer.unit_by_id("walker").on_water:
			wet_ticks += 1
	assert_gt(wet_ticks, 0, "a swimmer swims straight through")


func test_burn_on_water_ticks_at_half_and_says_so() -> void:
	var burn: Dictionary = {"cooldown_ms": 500, "effects": [{"type": "apply_status", "status": "burn", "stacks": 10, "target": "target"}]}
	var burner: UnitDef = still("burner", {"stats": {"range": 6}, "basic_attack": burn})
	var setup: FightSetup = K.fight([K.at(still("wet"), 2, 0), K.at(still("dry"), 5, 0)] as Array[UnitSetup],
		[K.foe(burner, 2, 5), K.foe(burner, 5, 5, "burner#2")] as Array[UnitSetup])
	setup.water = [Vector2i(2, 0)] as Array[Vector2i]
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 60)
	var wet: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.target == "wet")
	var dry: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.target == "dry")
	assert_false(wet.is_empty())
	assert_eq(wet.size(), dry.size(), "it lasts as long")
	assert_eq(wet[0].amount * 2, dry[0].amount, "at half")
	assert_eq([wet[0].note, dry[0].note], ["in water", ""])
	assert_string_contains(wet[0].to_text(), "in water")


func test_on_water_is_a_condition() -> void:
	var cond: Dictionary = {"id": "tide_skin", "name": "Tide Skin", "kind": "aura",
		"aura": {"target": "holder", "stat": "def_bp", "value": 20000, "while": "state", "state": {"on_water": true}}}
	var setup: FightSetup = K.fight([K.at(walker("hero", {"stats": {"def": 10}, "passives": [cond]}), 3, 0)] as Array[UnitSetup],
		[K.foe(still("target"), 3, 6)] as Array[UnitSetup])
	setup.water = [Vector2i(3, 0)] as Array[Vector2i]
	var fight: CombatSim = K.sim(setup)
	var hero: UnitState = fight.unit_by_id("hero")
	K.step(fight, 1)
	assert_eq(hero.defense(), 20, "on water")
	for i: int in 80:
		fight.step()
	assert_false(hero.on_water)
	assert_eq(hero.defense(), 10, "off it")
	var errors: Array[String] = []
	var condition: UnitCondition = UnitCondition.read(DataReader.new({"on_water": false}, "test", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq(condition.describe(), "not on water")
	assert_true(condition.holds(hero))


func test_the_steaming_ashling_steams_on_water_and_burns_off_it() -> void:
	var content: ContentDb = K.content()
	var steaming: UnitDef = content.specializations["steaming_ashling"].apply(content.enemies["ashling"].kit)
	assert_eq(steaming.name, "Steaming Ashling")
	for wet: bool in [true, false]:
		var setup: FightSetup = K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(steaming, 3, 3, "ashling")] as Array[UnitSetup])
		if wet:
			setup.water = [Vector2i(3, 3)] as Array[Vector2i]
		# Side by side across the middle (the sim doesn't mind zones).
		var fight := CombatSim.new(setup, content)
		K.step(fight, 2)
		fight.unit_by_id("ashling").hp = 0
		K.step(fight, 2)
		var hero: UnitState = fight.unit_by_id("hero")
		var statuses: Array = hero.statuses.map(func(state: StatusState) -> String: return state.def.id)
		assert_eq(statuses, ["slow"] if wet else ["burn"], "on water: steam" if wet else "off water: burn")


func test_the_holder_knob_sets_a_passives_condition() -> void:
	var content: ContentDb = K.content()
	var mod: KitMod = content.specializations["steaming_ashling"].mod
	assert_true(mod.affects(content.enemies["ashling"].kit))
	assert_string_contains(ModInfo.mod_numbers(mod, content.enemies["ashling"].kit, content), "only while it's not on water")


func test_the_setup_checks_its_water() -> void:
	var content: ContentDb = K.content()
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 1)] as Array[UnitSetup], [K.foe(still("target"), 3, 6)] as Array[UnitSetup], [Vector2i(4, 3)] as Array[Vector2i])
	setup.water = [Vector2i(9, 1), Vector2i(4, 3), Vector2i(3, 1), Vector2i(3, 1)] as Array[Vector2i]
	assert_eq(setup.validate(content), ["water at (9, 1) is off the board", "water at (4, 3) is on a rock", "water at (3, 1) is listed twice"] as Array[String])


func test_water_comes_from_the_encounter() -> void:
	var content: ContentDb = K.content()
	var encounter: EncounterDef = content.encounters.values()[0]
	encounter.water = [Vector2i(0, 3)] as Array[Vector2i]
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
	var setup: FightSetup = Encounters.setup(content, encounter.id, formation, 1, errors)
	assert_eq(setup.water, [Vector2i(0, 3)] as Array[Vector2i])
	var fight := CombatSim.new(setup, content)
	assert_true(fight.has_water)


func test_a_fight_without_water_has_none() -> void:
	var fight: CombatSim = walk_fight(walker("hero"), [] as Array[Vector2i])
	assert_false(fight.has_water)
	assert_null(fight.water)
	assert_false(fight.on_water(fight.unit_by_id("walker").pos))


func test_crumbled_water_both_hurts_and_slows() -> void:
	var column: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	var setup: FightSetup = K.fight([K.at(walker("hero"), 0, 1, "walker")] as Array[UnitSetup], [K.foe(still("target"), 0, 6)] as Array[UnitSetup])
	setup.water = column
	var fight: CombatSim = K.sim(setup)
	fight.safe = fight.grid.safe_rect(1)
	var unit: UnitState = fight.unit_by_id("walker")
	assert_true(fight.on_crumbled(unit.pos))
	assert_true(fight.on_water(unit.pos))
	assert_eq(fight.step_of(unit) * 2, unit.step_length())


# --- water that changes (8c-3c) -------------------------------------------------

## A still enemy at (3, 5) whose signature fires once at the fight's start
## with `effects`, aimed at the nearest hero.
static func caster(effects: Array, trigger: Dictionary = {"kind": "fight_start"}) -> UnitDef:
	return still("caster", {"stats": {"range": 8}, "signature": {"id": "tide", "name": "Tide", "trigger": trigger, "targeting": "nearest", "max_range": 8, "effects": effects}})


## A hero at (3, 1) and one at (6, 0) against the caster, with `water`.
static func flood_setup(effects: Array, water: Array[Vector2i] = [], rocks: Array[Vector2i] = []) -> FightSetup:
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 1), K.at(still("far"), 6, 0)] as Array[UnitSetup], [K.foe(caster(effects), 3, 5)] as Array[UnitSetup], rocks)
	setup.water = water
	return setup


static func waters(fight: CombatSim) -> Array[LogEntry]:
	return K.entries(fight, LogEntry.Kind.WATER)


func test_a_flood_covers_a_circle_for_a_while_then_recedes() -> void:
	var fight: CombatSim = K.sim(flood_setup([{"type": "flood", "mode": "circle", "radius": 1, "duration_ms": 2000}], [] as Array[Vector2i], [Vector2i(2, 1)] as Array[Vector2i]))
	assert_false(fight.has_water, "no water to start")
	K.step(fight, 2)
	assert_true(fight.has_water, "the flood makes some")
	var expected: Array[Vector2i] = [Vector2i(3, 1), Vector2i(3, 0), Vector2i(3, 2), Vector2i(2, 2), Vector2i(4, 2), Vector2i(4, 1)]
	for hex: Vector2i in fight.water.hexes:
		assert_true(expected.has(hex), "%s is in the circle" % hex)
	assert_eq(fight.water.hexes.size(), 6, "the hero's hex and its neighbors, but the rock")
	assert_false(fight.water.hexes.has(Vector2i(2, 1)), "never on a rock")
	assert_true(fight.unit_by_id("hero").on_water)
	assert_false(fight.unit_by_id("far").on_water)
	var entries: Array[LogEntry] = waters(fight)
	assert_eq(entries.size(), 1)
	assert_eq(entries[0].note, "floods 6 hexes for 2s")
	assert_eq([entries[0].source_unit, entries[0].source_ability], ["caster", "tide"])
	assert_string_contains(entries[0].to_text(), "caster · Tide floods 6 hexes for 2s (6 water hexes)")
	K.step(fight, 40)
	assert_eq(fight.water.hexes, [] as Array[Vector2i], "it recedes")
	assert_false(fight.unit_by_id("hero").on_water)
	assert_eq(waters(fight).map(func(entry: LogEntry) -> String: return entry.note), ["floods 6 hexes for 2s", "recedes"])
	assert_eq(waters(fight)[1].source_ability, "tide", "sourced to the flood")


func test_a_flood_without_a_duration_stays() -> void:
	var fight: CombatSim = K.sim(flood_setup([{"type": "flood", "mode": "circle", "radius": 0, "anchor": "self"}]))
	K.step(fight, 100)
	assert_eq(fight.water.hexes, [Vector2i(3, 5)] as Array[Vector2i], "under the caster, for good")


func test_the_water_spreads_drains_and_floods_everything() -> void:
	var spread: CombatSim = K.sim(flood_setup([{"type": "flood", "mode": "spread"}], [Vector2i(3, 3)] as Array[Vector2i], [Vector2i(4, 3)] as Array[Vector2i]))
	K.step(spread, 2)
	assert_eq(spread.water.hexes.size(), 6, "a hex wider, but the rock")
	assert_eq(waters(spread)[0].note, "spreads to 5 more hexes")
	var drain: CombatSim = K.sim(flood_setup([{"type": "flood", "mode": "drain", "radius": 1}], lake()))
	K.step(drain, 2)
	for hex: Vector2i in drain.water.hexes:
		assert_lte(ArenaPlane.distance(drain.grid.center(hex.x, hex.y), drain.unit_by_id("caster").pos), 1000, "only round the caster")
	assert_false(drain.unit_by_id("hero").on_water, "the lake is gone")
	assert_eq(waters(drain)[0].note, "drains to %d hexes" % drain.water.hexes.size())
	var everything: CombatSim = K.sim(flood_setup([{"type": "flood", "mode": "all"}], [] as Array[Vector2i], [Vector2i(4, 3)] as Array[Vector2i]))
	K.step(everything, 2)
	assert_eq(everything.water.hexes.size(), everything.grid.size() - 1, "every hex but the rock")
	assert_true(everything.unit_by_id("far").on_water)


func test_a_pull_toward_the_water_stops_on_it() -> void:
	var coil: Array = [{"type": "pull", "hexes": 3, "toward": "water", "target": "target"}]
	var fight: CombatSim = K.sim(flood_setup(coil, [Vector2i(1, 1)] as Array[Vector2i]))
	K.step(fight, 10)
	var pushes: Array[LogEntry] = K.entries(fight, LogEntry.Kind.PUSH)
	assert_eq(pushes.size(), 1)
	assert_eq(pushes[0].target, "hero")
	assert_eq(fight.unit_by_id("hero").pos, fight.grid.center(1, 1), "onto the water's middle, no further")
	assert_string_contains(pushes[0].note, "pulled")
	var dry: CombatSim = K.sim(flood_setup(coil))
	K.step(dry, 10)
	assert_eq(K.entries(dry, LogEntry.Kind.PUSH), [] as Array[LogEntry], "no water, no pull")


func test_an_areas_pull_goes_toward_its_middle() -> void:
	var undertow: Array = [{"type": "area", "shape": {"kind": "circle", "radius": 4}, "anchor": "self", "hits": "enemies",
		"effects": [{"type": "pull", "hexes": 1, "toward": "area", "target": "target"}]}]
	var fight: CombatSim = K.sim(flood_setup(undertow))
	var hero: UnitState = fight.unit_by_id("hero")
	var before: int = ArenaPlane.distance(hero.pos, fight.unit_by_id("caster").pos)
	K.step(fight, 2)
	assert_eq(ArenaPlane.distance(hero.pos, fight.unit_by_id("caster").pos), before - 1000, "a hex toward the area's middle")


func test_only_picks_the_units_that_meet_it() -> void:
	var pull: Array = [{"type": "pull", "hexes": 1, "target": "all_enemies", "only": {"on_water": true}}]
	var fight: CombatSim = K.sim(flood_setup(pull, [Vector2i(6, 0)] as Array[Vector2i]))
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH).map(func(entry: LogEntry) -> String: return entry.target), ["far"], "only the hero on water")


func test_the_new_pieces_have_numbers_lines() -> void:
	var content: ContentDb = K.content()
	var kit: UnitDef = caster([{"type": "flood", "mode": "circle", "radius": 2, "duration_ms": 6000},
		{"type": "pull", "hexes": 1, "target": "all_enemies", "only": {"on_water": true}},
		{"type": "pull", "hexes": 1, "toward": "water", "target": "target"}])
	var line: String = " · ".join(UnitInfo.effect_numbers(kit.signature.effects, kit, content))
	assert_string_contains(line, "floods a 2-hex circle at the target for 6s")
	assert_string_contains(line, "pulls 1 hex to all enemies on water")
	assert_string_contains(line, "pulls 1 hex toward the nearest water")


func test_the_new_keys_are_checked() -> void:
	for data: Dictionary in [
		{"type": "pull", "hexes": 1, "toward": "area", "target": "target"},
		{"type": "pull", "hexes": 1, "target": "target", "only": {"on_water": true}},
		{"type": "flood", "mode": "circle"},
		{"type": "flood", "mode": "river", "radius": 1},
	]:
		var errors: Array[String] = []
		EffectDef.read(DataReader.new(data, "test", errors))
		assert_false(errors.is_empty(), "refused: %s" % data)
	var errors: Array[String] = []
	var area: Dictionary = {"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "enemies",
		"effects": [{"type": "flood", "mode": "spread"}]}
	EffectDef.read(DataReader.new(area, "test", errors))
	assert_false(errors.is_empty(), "a flood isn't one of an area's effects")
