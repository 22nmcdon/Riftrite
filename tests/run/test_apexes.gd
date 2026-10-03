extends GutTest
## Apexes in the run (docs/plans/rebuild-phase8-apexes.md, section 4): the
## apex vow opens going deeper (not on ending the run), only for transformed
## heroes whose path has apexes, and later for a late transformer; switching
## is free until the apex is earned; the apex deed fills and raises the hero;
## the fight takes the apex's kit; and the save keeps it (a version 5 save
## still loads).

const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _vows() -> Dictionary[String, String]:
	return {"brannoc": "hearthwall", "maren": "volley", "vell": "lanternbearer"}


func _result(outcome: FightResult.Outcome, deeds: Dictionary = {}) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	result.end_tick = 600
	for key: String in deeds:
		result.deeds.append(FightResult.Deed.make("maren", key, int(deeds[key])))
	return result


func _win_today(flow: RunFlow, deeds: Dictionary = {}) -> void:
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY, deeds))
	if not flow.state.pick.is_empty():
		flow.take_shards()
	if not flow.state.relic_choice.is_empty():
		flow.decline_relic()


## The act played through its boss shop to endless's choice, with Maren
## transformed (`transformed`) and the others not.
func _to_choice(transformed: bool = true) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, _vows(), errors, true)
	assert_eq(errors, [] as Array[String])
	flow.state.hero("maren").transformed = transformed
	for day: int in range(1, _run.acts[0].days.size()):
		_win_today(flow)
		flow.finish_day()
		flow.leave_shop()
		flow.choose_node(flow.state.nodes.find("camp"))
		flow.leave_node()
	_win_today(flow)
	flow.finish_day()
	assert_false(flow.state.apex_open, "not before the act's boss shop is left")
	assert_eq(flow.vow_apex("maren", "hailstorm"), "the apex vow opens after the act's boss")
	flow.leave_shop()
	assert_eq(flow.state.phase, RunState.Phase.CHOICE)
	return flow


## Phase 8 part 3 (rebuild-phase8-acts.md, Decision 2): the vow opens as
## Act 1's boss shop is left, before the choice (and before Act 2).
func test_the_apex_vow_opens_after_the_acts_boss_for_transformed_heroes() -> void:
	var flow: RunFlow = _to_choice()
	var maren: RunState.Hero = flow.state.hero("maren")
	assert_true(flow.state.apex_open)
	assert_eq(flow.go_deeper(), "")
	assert_eq(flow.apex_waiting(), ["maren"] as Array[String], "Brannoc and Vell haven't transformed (and their paths have no apexes yet)")
	assert_eq(maren.deeds.get("hailstorm", -1), 0, "its path's apexes' deeds count from now")
	assert_false(flow.state.hero("brannoc").deeds.has("hailstorm"))
	assert_eq(flow.vow_apex("vell", "hailstorm"), "vell must transform first")
	assert_eq(flow.vow_apex("maren", "eagle_eye"), "maren can't vow to the apex \"eagle_eye\"")
	assert_eq(flow.vow_apex("maren", "hailstorm"), "")
	assert_eq(flow.vow_apex("maren", "hailstorm"), "maren is already vowed to hailstorm")
	assert_eq(flow.apex_waiting(), [] as Array[String])
	assert_eq(_run.hero_kit(maren), _run.content.apexes["hailstorm"].vowed_kit, "its taste from the next fight")


func test_an_ended_run_has_no_apex_vow_waiting() -> void:
	var flow: RunFlow = _to_choice()
	assert_eq(flow.apex_waiting(), ["maren"] as Array[String])
	assert_eq(flow.end_run(), "")
	assert_eq(flow.apex_waiting(), [] as Array[String])


func test_the_apex_deed_fills_and_raises_the_hero() -> void:
	var flow: RunFlow = _to_choice()
	flow.go_deeper()
	flow.vow_apex("maren", "hailstorm")
	var maren: RunState.Hero = flow.state.hero("maren")
	var threshold: int = _run.content.apexes["hailstorm"].deed.threshold
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	var unit: UnitSetup = setup.heroes.filter(func(hero: UnitSetup) -> bool: return hero.def.id == "maren")[0]
	assert_eq([unit.stage, unit.apex.id], [PathDef.Stage.APEX_VOWED, "hailstorm"])
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY, {"hailstorm": threshold - 1}))
	assert_eq([maren.deeds["hailstorm"], maren.apex_earned, flow.state.just_apexed], [threshold - 1, false, [] as Array[String]])
	if not flow.state.pick.is_empty():
		flow.take_shards()
	flow.finish_day()
	flow.leave_shop()
	flow.choose_node(flow.state.nodes.find("camp"))
	flow.leave_node()
	_win_today(flow, {"hailstorm": 1})
	assert_true(maren.apex_earned)
	assert_eq(flow.state.just_apexed, ["maren"] as Array[String])
	assert_eq(flow.vow_apex("maren", "hailstorm"), "maren has earned its apex, so the vow is set")
	assert_eq(_run.hero_kit(maren), _run.content.apexes["hailstorm"].apex_kit)
	flow.finish_day()
	assert_eq(flow.state.just_apexed, [] as Array[String], "shown once")


func test_a_late_transformer_gets_the_vow_when_it_transforms() -> void:
	var flow: RunFlow = _to_choice(false)
	flow.go_deeper()
	var maren: RunState.Hero = flow.state.hero("maren")
	assert_eq(flow.apex_waiting(), [] as Array[String])
	assert_false(maren.deeds.has("hailstorm"))
	_win_today(flow, {"volley": _run.content.paths["volley"].deed.threshold})
	assert_true(maren.transformed)
	assert_eq(maren.deeds.get("hailstorm", -1), 0, "the same deed, from now (Decision 4)")
	assert_eq(flow.apex_waiting(), ["maren"] as Array[String])


func test_the_save_keeps_the_apex_and_an_older_save_still_loads() -> void:
	var flow: RunFlow = _to_choice()
	flow.go_deeper()
	flow.vow_apex("maren", "hailstorm")
	var data: Dictionary = JSON.parse_string(JSON.stringify(flow.state.to_dict()))
	assert_eq(int(data["version"]), RunState.VERSION)
	var loaded: RunState = RunState.from_dict(data)
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(flow.state.to_dict()))
	assert_eq([loaded.apex_open, loaded.hero("maren").apex, loaded.hero("maren").apex_earned], [true, "hailstorm", false])
	data["version"] = 5
	data.erase("apex_open")
	for hero: Dictionary in data["heroes"]:
		hero.erase("apex")
		hero.erase("apex_earned")
	var older: RunState = RunState.from_dict(data)
	assert_not_null(older, "a version 5 save loads")
	assert_eq([older.apex_open, older.hero("maren").apex], [false, ""])
