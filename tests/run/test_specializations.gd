extends GutTest
## Enemy specializations (docs/plans/rebuild-phase8-act2.md, part 8c-3a):
## the data, the draw (half of a day fight's enemies from the act's day, fresh
## on each attempt), the fight's kits and names, the save, and the fight
## card's line. On stand-in acts (tests/run/test_acts.gd) whose Act 2
## specializes from day 3.

const Bot = preload("res://tools/run_bot.gd")
const ActsTest = preload("res://tests/run/test_acts.gd")

var _run: RunContent


static func specialized_acts() -> RunContent:
	var run: RunContent = ActsTest.stand_in_acts()
	run.acts[1].specialized_from_day = 3
	return run


func before_all() -> void:
	_run = specialized_acts()


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


func test_the_data() -> void:
	var content: ContentDb = _run.content
	assert_eq(content.errors, [] as Array[String])
	for id: String in ["gnawing_pup", "smoldering_ashling", "bulwark_guardian", "deep_lurker", "rot_lurker", "hex_witch"]:
		assert_true(content.specializations.has(id), id)
	for enemy_id: String in content.enemy_ids:
		assert_lte(content.enemies[enemy_id].specializations.size(), SpecializationDef.PER_ENEMY)
	var pup: UnitDef = content.enemies["rift_pup"].kit
	var gnawing: UnitDef = content.specializations["gnawing_pup"].apply(pup)
	assert_eq(gnawing.name, "Gnawing Rift Pup")
	assert_eq(gnawing.specialization, "gnawing_pup")
	assert_eq(gnawing.basic_attack.effects.size(), pup.basic_attack.effects.size() + 1, "its bite adds Bleed")
	assert_eq([pup.name, pup.specialization], ["Rift Pup", ""], "the enemy's own kit is untouched")


func test_a_specialization_must_change_something() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var enemies: Array = JSON.parse_string(texts[ContentDb.ENEMIES_FILE])
	for entry: Variant in enemies:
		if entry is Dictionary and (entry as Dictionary).get("id", "") == "rift_pup":
			(entry["specializations"] as Array).append({"id": "idle_pup", "name": "Idle", "text": "It does nothing new.", "mod": {}})
	texts[ContentDb.ENEMIES_FILE] = JSON.stringify(enemies)
	var content: ContentDb = ContentDb.load_texts(texts)
	assert_true(content.errors.any(func(error: String) -> bool: return error.contains("idle_pup") and error.contains("changes something")), str(content.errors))


func test_none_before_the_acts_day_or_in_act_1() -> void:
	var flow: RunFlow = RunFlow.start(_run, 7, Bot.first_vows(_run.content), [] as Array[String])
	assert_true(flow.state.today_specs.all(func(specs: Array) -> bool: return specs.all(func(id: Variant) -> bool: return str(id).is_empty())), "Act 1 specializes none")
	var early: RunFlow = _on_day(2)
	assert_true(early.state.today_specs.all(func(specs: Array) -> bool: return specs.all(func(id: Variant) -> bool: return str(id).is_empty())), "Act 2 from day 3")


func test_half_of_a_fights_enemies_from_day_3() -> void:
	for day: int in [3, 4, 6]:
		var flow: RunFlow = _on_day(day)
		var today: Array[String] = flow.state.today()
		assert_eq(flow.state.today_specs.size(), today.size())
		for i: int in today.size():
			var encounter: EncounterDef = _run.content.encounters[today[i]]
			var eligible: int = encounter.enemies.filter(func(placed: EncounterDef.Placed) -> bool: return not _run.content.enemies[placed.enemy].specializations.is_empty()).size()
			var drawn: Array = flow.state.today_specs[i]
			assert_eq(drawn.size(), encounter.enemies.size())
			assert_eq(drawn.filter(func(id: Variant) -> bool: return not str(id).is_empty()).size(), mini(encounter.enemies.size() / 2, eligible), "day %d, %s" % [day, encounter.id])
			for j: int in drawn.size():
				if not str(drawn[j]).is_empty():
					assert_eq(_run.content.specializations[str(drawn[j])].enemy, encounter.enemies[j].enemy, "its own enemy's")


func test_the_draw_repeats_and_is_fresh_on_a_replay() -> void:
	var first: RunFlow = _on_day(4)
	assert_eq(_on_day(4).state.today_specs, first.state.today_specs, "the same seed and day, the same draw")
	var changed: bool = false
	for run_seed: int in range(1, 10):
		for day: int in [4, 6]:
			var flow: RunFlow = _on_day(day, run_seed)
			var before: Array = flow.state.today_specs.duplicate(true)
			flow.state.attempt = 1
			flow._start_day()
			changed = changed or flow.state.today_specs != before
	assert_true(changed, "a replay after a loss draws afresh")


func test_the_fight_has_the_specialized_kits() -> void:
	var flow: RunFlow = null
	for run_seed: int in range(1, 30):
		flow = _on_day(4, run_seed)
		if flow.state.today_specs[0].any(func(id: Variant) -> bool: return not str(id).is_empty()):
			break
	var drawn: Array = flow.state.today_specs[0]
	assert_true(drawn.any(func(id: Variant) -> bool: return not str(id).is_empty()), "a seed with one")
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	for i: int in drawn.size():
		var spec_id: String = str(drawn[i])
		assert_eq(setup.enemies[i].def.specialization, spec_id)
		if not spec_id.is_empty():
			var spec: SpecializationDef = _run.content.specializations[spec_id]
			assert_eq(setup.enemies[i].def.name, "%s %s" % [spec.name, _run.content.enemies[spec.enemy].name])
	var refused: Array[String] = []
	var encounter: String = flow.state.chosen
	Encounters.setup(_run.content, encounter, Bot.formation(), 1, refused, {}, {}, [], {}, {}, [], {0: "no_such"} as Dictionary[int, String])
	assert_false(refused.is_empty(), "an unknown specialization is refused")


func test_the_save_keeps_them() -> void:
	var flow: RunFlow = _on_day(4)
	var data: Dictionary = JSON.parse_string(JSON.stringify(flow.state.to_dict()))
	assert_eq(int(data["version"]), RunState.VERSION)
	var loaded: RunState = RunState.from_dict(data)
	assert_eq(loaded.today_specs, flow.state.today_specs)
	data["version"] = 7
	data.erase("today_specs")
	assert_eq(RunState.from_dict(data).today_specs, [] as Array[Array], "a version 7 save has none")


func test_the_fight_cards_line() -> void:
	var encounter: EncounterDef = _run.content.encounters["pup_warren"]
	var drawn: Array = ["gnawing_pup", "", "gnawing_pup", "", "", ""]
	assert_eq(RunDayScreen.specs_line(_run.content, encounter, drawn), "Specialized: 2 Gnawing Rift Pups: Its bites make you Bleed, and the Bleed stacks.")
	assert_eq(RunDayScreen.specs_line(_run.content, encounter, ["", "", "", "", "", ""]), "")
