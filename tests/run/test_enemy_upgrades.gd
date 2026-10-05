extends GutTest
## Enemy upgrades in the run (docs/plans/rebuild-phase8-act3.md, part 8c-5a):
## each elite day fight draws 1–2 when the day starts (from the act's
## elite_upgrades, fresh on each attempt), carried by every enemy in it they
## change; the fight's kits and names, the save (version 9), and the fight
## card's line. On stand-in acts (tests/run/test_acts.gd) whose Act 2 draws
## upgrades.

const Bot = preload("res://tools/run_bot.gd")
const ActsTest = preload("res://tests/run/test_acts.gd")

var _run: RunContent


func before_all() -> void:
	_run = ActsTest.stand_in_acts()
	_run.acts[1].elite_upgrades_min = 1
	_run.acts[1].elite_upgrades_max = 2


## A flow on Act 2's day `day`, its fights drawn and the day started.
func _on_day(day: int, run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	flow.state.act = 2
	flow.state.day = day
	flow.state.options = ActDraw.draw(_run, run_seed, _run.acts[1])
	flow._start_day()
	return flow


func _tier(flow: RunFlow, index: int) -> String:
	return _run.content.encounters[flow.state.today()[index]].tier


func test_the_built_acts_draw_none() -> void:
	var real: RunContent = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))
	for act_def: ActDef in real.acts:
		assert_eq([act_def.elite_upgrades_min, act_def.elite_upgrades_max], [1, 2] if act_def.act == 3 else [0, 0], "Act %d's elites" % act_def.act)
	var flow: RunFlow = RunFlow.start(real, 7, Bot.first_vows(real.content), [] as Array[String])
	assert_true(flow.state.today_upgrades.all(func(drawn: Array) -> bool: return drawn.is_empty()))


func test_only_elites_carry_one_or_two() -> void:
	var elites: int = 0
	for run_seed: int in range(1, 8):
		for day: int in [1, 2, 3, 4, 5, 6]:
			var flow: RunFlow = _on_day(day, run_seed)
			assert_eq(flow.state.today_upgrades.size(), flow.state.today().size())
			for i: int in flow.state.today().size():
				var drawn: Array = flow.state.today_upgrades[i]
				if _tier(flow, i) != "elite":
					assert_eq(drawn, [], "a %s fight carries none" % _tier(flow, i))
					continue
				elites += 1
				assert_between(drawn.size(), 1, 2, "an elite carries 1 or 2")
				assert_false(drawn.size() == 2 and drawn[0] == drawn[1], "different ones")
				var encounter: EncounterDef = _run.content.encounters[flow.state.today()[i]]
				for id: Variant in drawn:
					var upgrade: EnemyUpgradeDef = _run.content.enemy_upgrades[str(id)]
					assert_true(encounter.enemies.any(func(placed: EncounterDef.Placed) -> bool: return upgrade.changes(_run.content.enemies[placed.enemy].kit)),
						"%s changes one of %s's enemies" % [id, encounter.id])
	assert_gt(elites, 0, "some elites drawn")


func test_the_draw_repeats_and_is_fresh_on_a_replay() -> void:
	var day: int = 3
	var first: RunFlow = _on_day(day)
	assert_eq(_on_day(day).state.today_upgrades, first.state.today_upgrades, "the same seed and day, the same draw")
	var changed: bool = false
	for run_seed: int in range(1, 12):
		var flow: RunFlow = _on_day(day, run_seed)
		var before: Array = flow.state.today_upgrades.duplicate(true)
		flow.state.attempt = 1
		flow._start_day()
		changed = changed or flow.state.today_upgrades != before
	assert_true(changed, "a replay after a loss draws afresh")


func test_the_fight_has_the_upgraded_kits() -> void:
	var flow: RunFlow = null
	var index: int = -1
	for run_seed: int in range(1, 30):
		flow = _on_day(3, run_seed)
		for i: int in flow.state.today().size():
			if _tier(flow, i) == "elite":
				index = i
		if index >= 0:
			break
	assert_true(index >= 0, "a day with an elite")
	var drawn: Array = flow.state.today_upgrades[index]
	assert_eq(flow.choose_fight(index), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	var encounter: EncounterDef = _run.content.encounters[flow.state.chosen]
	var carried: int = 0
	for i: int in encounter.enemies.size():
		var enemy: EnemyDef = _run.content.enemies[encounter.enemies[i].enemy]
		var expected: Array[String] = []
		for id: Variant in drawn:
			if _run.content.enemy_upgrades[str(id)].changes(enemy.kit):
				expected.append(str(id))
		assert_eq(setup.enemies[i].def.upgrades, expected, "%s carries those that change it" % enemy.id)
		carried += expected.size()
		if not expected.is_empty():
			assert_true(setup.enemies[i].def.name.begins_with(_run.content.enemy_upgrades[expected[-1]].name + " "), setup.enemies[i].def.name)
	assert_gt(carried, 0)


func test_each_enemy_carries_only_those_that_change_it() -> void:
	var flow: RunFlow = _on_day(3)
	flow.state.options[2] = ["witch_coven"]
	flow.state.today_upgrades = [["rift_touched", "swift"]] as Array[Array]
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	var carried: Array = setup.enemies.map(func(enemy: UnitSetup) -> Array[String]: return enemy.def.upgrades)
	assert_eq(carried, [["swift"], ["rift_touched", "swift"], ["rift_touched", "swift"], ["rift_touched", "swift"]],
		"the Gloam Totem has no mana bar, so no Rift-Touched")


func test_setup_refuses_what_cant_be_carried() -> void:
	var formation: Dictionary[String, Vector2i] = Bot.formation()
	var cases: Array = [PackedStringArray(["no_such"]), PackedStringArray(["swift", "swift"]), PackedStringArray(["frenzied", "warded", "swift"])]
	for upgrades: PackedStringArray in cases:
		var refused: Array[String] = []
		var setup: FightSetup = Encounters.setup(_run.content, "pup_warren", formation, 1, refused, {}, {}, [], {}, {}, [], {} as Dictionary[int, String],
			{0: upgrades} as Dictionary[int, PackedStringArray])
		assert_null(setup, str(upgrades))
		assert_false(refused.is_empty(), str(upgrades))
	var errors: Array[String] = []
	var fine: FightSetup = Encounters.setup(_run.content, "pup_warren", formation, 1, errors, {}, {}, [], {}, {}, [], {} as Dictionary[int, String],
		{1: PackedStringArray(["swift", "warded"])} as Dictionary[int, PackedStringArray])
	assert_eq(errors, [] as Array[String])
	assert_eq(fine.enemies[1].def.upgrades, ["swift", "warded"] as Array[String])
	assert_eq(fine.enemies[1].def.name, "Warded Swift Rift Pup")
	assert_eq(fine.enemies[0].def.upgrades, [] as Array[String])


func test_the_save_keeps_them() -> void:
	var flow: RunFlow = _on_day(3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(flow.state.to_dict()))
	assert_eq(int(data["version"]), 10)
	assert_eq(RunState.from_dict(data).today_upgrades, flow.state.today_upgrades)
	data["version"] = 8
	data.erase("today_upgrades")
	assert_eq(RunState.from_dict(data).today_upgrades, [] as Array[Array], "a version 8 save has none")


func test_the_act_reads_its_elite_upgrades() -> void:
	for bad: Variant in [[2, 1], [0, 3], [1], [-1, 1]]:
		var errors: Array[String] = []
		ActDef.read(DataReader.new(_act_data({"elite_upgrades": bad}), "act", errors))
		assert_true(errors.any(func(error: String) -> bool: return error.contains("elite_upgrades")), "%s: %s" % [bad, errors])
	var errors: Array[String] = []
	var act_def: ActDef = ActDef.read(DataReader.new(_act_data({"elite_upgrades": [1, 2]}), "act", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([act_def.elite_upgrades_min, act_def.elite_upgrades_max], [1, 2])


func _act_data(extra: Dictionary) -> Dictionary:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/act1.json"))
	data.merge(extra, true)
	return data


func test_the_fight_cards_line() -> void:
	assert_eq(RunDayScreen.upgrades_line(_run.content, []), "")
	assert_eq(RunDayScreen.upgrades_line(_run.content, ["frenzied", "warded"]),
		"Upgraded: Frenzied: It attacks faster once it's below half its HP.\nWarded: It starts the fight behind a Shield.")
