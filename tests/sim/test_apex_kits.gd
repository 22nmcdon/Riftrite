extends GutTest
## Apexes in the sim (docs/plans/rebuild-phase8-apexes.md, part 8b-1): a
## path's apexes load and build their kits on the transformed kit, a hero
## takes one through Encounters.setup at the apex vowed or apex stage, the
## setup's checks, a transformed hero counts its path's apexes' deeds, and
## Hailstorm's pieces (on_holder_hit's from_ability, the hits count) in a
## fight.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FORMATION: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(4, 0), "vell": Vector2i(3, 1)}

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


func _setup(apex_vows: Dictionary[String, String], apexed: Array[String], errors: Array[String],
		transformed: Array[String] = ["maren"], encounter_id: String = "hollow_line") -> FightSetup:
	var vows: Dictionary[String, String] = {"maren": "volley"}
	return Encounters.setup(_content, encounter_id, FORMATION, 7, errors, {}, vows, transformed, {}, apex_vows, apexed)


func _maren(setup: FightSetup) -> UnitSetup:
	for hero: UnitSetup in setup.heroes:
		if hero.def.id == "maren":
			return hero
	return null


func test_a_paths_apexes_load_on_its_transformed_kit() -> void:
	var volley: PathDef = _content.paths["volley"]
	assert_eq(volley.apexes.map(func(apex: ApexDef) -> String: return apex.id), ["hailstorm", "windrunner"])
	var hailstorm: ApexDef = _content.apexes["hailstorm"]
	assert_eq(hailstorm.path, "volley")
	assert_true(_content.apex_ids.has("hailstorm"))
	assert_false(_content.path_ids.has("hailstorm"), "apexes and paths share one space of ids, but apart")
	# The taste: one more volley (3.5s), on the transformed kit (still splits).
	var storm: EffectDef = hailstorm.vowed_kit.signature.effects[0]
	assert_eq([storm.zone_ticks, storm.shape.size], [70, 1])
	assert_eq(hailstorm.vowed_kit.basic_attack.effects.size(), volley.transformed_kit.basic_attack.effects.size())
	assert_true(hailstorm.vowed_kit.has_trait("fires_moving"), "built on the transformed kit")
	# The apex: a wider storm, a volley every 4th shot, and its snowball.
	var apex_storm: EffectDef = hailstorm.apex_kit.signature.effects[0]
	assert_eq([apex_storm.zone_ticks, apex_storm.shape.size], [70, 2])
	var dropped: EffectDef = hailstorm.apex_kit.basic_attack.effects.back()
	assert_eq([dropped.type, dropped.every], [EffectDef.Type.AREA, 4])
	assert_true(hailstorm.apex_kit.passives.any(func(part: PartDef) -> bool: return part.id == "gathering_hail"))
	assert_eq(volley.kit(PathDef.Stage.APEX_VOWED, _content.heroes["maren"].kit, "hailstorm"), hailstorm.vowed_kit)
	assert_eq(volley.kit(PathDef.Stage.APEX, _content.heroes["maren"].kit, "hailstorm"), hailstorm.apex_kit)
	assert_eq(volley.apex_kits().slice(0, 2), [hailstorm.vowed_kit, hailstorm.apex_kit] as Array[UnitDef])
	assert_eq(PathDef.STAGE_NAMES[PathDef.Stage.APEX], "apex")


func test_a_hero_takes_an_apex_through_the_setup() -> void:
	var errors: Array[String] = []
	var setup: FightSetup = _setup({"maren": "hailstorm"} as Dictionary[String, String], [] as Array[String], errors)
	assert_eq(errors, [] as Array[String])
	var maren: UnitSetup = _maren(setup)
	assert_eq([maren.stage, maren.apex.id, maren.def], [PathDef.Stage.APEX_VOWED, "hailstorm", _content.apexes["hailstorm"].vowed_kit])
	assert_eq(maren.deed_apexes.map(func(apex: ApexDef) -> String: return apex.id), ["hailstorm", "windrunner"])
	assert_eq(setup.validate(_content), [] as Array[String])
	setup = _setup({"maren": "hailstorm"} as Dictionary[String, String], ["maren"] as Array[String], errors)
	assert_eq([_maren(setup).stage, _maren(setup).def], [PathDef.Stage.APEX, _content.apexes["hailstorm"].apex_kit])
	# A transformed hero without an apex vow still counts its path's apexes.
	setup = _setup({} as Dictionary[String, String], [] as Array[String], errors)
	assert_eq([_maren(setup).stage, _maren(setup).apex, _maren(setup).deed_apexes.size()], [PathDef.Stage.TRANSFORMED, null, 2])
	# Only vowed: no apex deeds yet.
	setup = _setup({} as Dictionary[String, String], [] as Array[String], errors, [] as Array[String])
	assert_eq(_maren(setup).deed_apexes.size(), 0)


func test_the_setup_refuses_an_apex_it_cant_take() -> void:
	var errors: Array[String] = []
	assert_null(_setup({"maren": "hailstorm"} as Dictionary[String, String], [] as Array[String], errors, [] as Array[String]))
	assert_eq(errors, ["\"maren\" takes an apex without transforming"] as Array[String])
	errors.clear()
	assert_null(_setup({"maren": "nowhere"} as Dictionary[String, String], [] as Array[String], errors))
	assert_eq(errors, ["unknown apex \"nowhere\""] as Array[String])
	errors.clear()
	assert_null(_setup({} as Dictionary[String, String], ["maren"] as Array[String], errors))
	assert_eq(errors, ["\"maren\" earns an apex without its vow"] as Array[String])
	errors.clear()
	var vows: Dictionary[String, String] = {"maren": "deadeye"}
	assert_null(Encounters.setup(_content, "hollow_line", FORMATION, 7, errors, {}, vows, ["maren"] as Array[String], {},
		{"maren": "hailstorm"} as Dictionary[String, String]))
	assert_eq(errors, ["maren's apex \"hailstorm\" isn't its path's"] as Array[String])
	# validate: an apex stage without an apex, and an apex off its stage.
	errors.clear()
	var setup: FightSetup = _setup({} as Dictionary[String, String], [] as Array[String], errors)
	_maren(setup).stage = PathDef.Stage.APEX
	assert_true(setup.validate(_content).any(func(problem: String) -> bool: return problem.contains("without one of its path's apexes")))
	_maren(setup).stage = PathDef.Stage.TRANSFORMED
	_maren(setup).apex = _content.apexes["hailstorm"]
	assert_true(setup.validate(_content).any(func(problem: String) -> bool: return problem.contains("isn't at an apex stage")))


func test_hailstorm_grows_with_each_enemy_its_storm_hits() -> void:
	var errors: Array[String] = []
	var setup: FightSetup = _setup({"maren": "hailstorm"} as Dictionary[String, String], ["maren"] as Array[String], errors)
	var sim := CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	var storm_hits: int = 0
	var stacks: int = 0
	var volleys: int = 0
	for entry: LogEntry in sim.combat_log.entries:
		if entry.source_unit != "maren":
			continue
		if entry.kind == LogEntry.Kind.DAMAGE and entry.source_ability == "arrow_storm":
			storm_hits += 1
		if entry.kind == LogEntry.Kind.STATUS_APPLIED and entry.status == "hailstorm":
			stacks += 1
		if entry.kind == LogEntry.Kind.AREA_LANDED and entry.source_ability == "longshot":
			volleys += 1
	assert_gt(storm_hits, 0, "Arrow Storm hit")
	assert_eq(stacks, storm_hits, "a stack for each enemy Arrow Storm hits, and none for her shots")
	assert_gt(volleys, 0, "every 4th shot drops a volley")
	var result: FightResult = CombatSim.result_of(sim)
	assert_eq(result.deed_amount("maren", "hailstorm"), storm_hits, "the deed counts Arrow Storm's hits on enemies")
	assert_gt(result.deed_amount("maren", "volley"), 0, "beside the path's own")


func test_the_taste_fills_the_apex_deed_faster() -> void:
	var errors: Array[String] = []
	var transformed: Array[String] = ["maren"]
	var plain: FightResult = CombatSim.run(_setup({} as Dictionary[String, String], [] as Array[String], errors, transformed, "the_pack"), _content)
	var tasted: FightResult = CombatSim.run(_setup({"maren": "hailstorm"} as Dictionary[String, String], [] as Array[String], errors, transformed, "the_pack"), _content)
	assert_gt(tasted.deed_amount("maren", "hailstorm"), plain.deed_amount("maren", "hailstorm"))


func test_hits_count_only_hits_on_enemies_from_its_abilities() -> void:
	var deed := DeedDef.new()
	deed.counts = DeedDef.Counts.HITS
	deed.from_ability = ["arrow_storm"]
	assert_true(deed.counts_kind(LogEntry.Kind.DAMAGE, "arrow_storm"))
	assert_false(deed.counts_kind(LogEntry.Kind.DAMAGE, "longshot"))
	assert_false(deed.counts_kind(LogEntry.Kind.HEAL, "arrow_storm"))
	assert_eq(DeedDef.COUNT_NAMES[DeedDef.Counts.HITS], "hits")
