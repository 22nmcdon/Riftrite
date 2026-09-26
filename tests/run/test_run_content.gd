extends GutTest
## The run layer's data (economy, acts, events) and its checks.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _texts() -> Dictionary[String, String]:
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	return texts


func _errors_with(file_name: String, data: Variant) -> Array[String]:
	var texts: Dictionary[String, String] = _texts()
	texts[file_name] = JSON.stringify(data)
	return RunContent.load_texts(texts, K.content()).errors


func _assert_error(errors: Array[String], expected: String) -> void:
	assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "%s in %s" % [expected, errors])


func test_real_run_data_loads() -> void:
	var run: RunContent = RunContent.load_dir("res://data", K.content())
	assert_eq(run.errors, [] as Array[String])
	var act: ActDef = run.act(1)
	assert_eq([act.days, act.elite_days, act.boss], [6, [3, 5] as Array[int], "the_ash_mother"])
	assert_eq(act.encounters_for(act.normal, 1), ["pup_litter", "ash_swarm"] as Array[String])
	assert_true(act.is_boss_day(6))
	assert_eq(run.economy.sell_price(9), 4, "half, rounded down")


func test_acts_are_checked() -> void:
	var acts: Array = JSON.parse_string(_texts()[RunContent.ACTS_FILE])
	acts[0]["normal"].append({"encounter": "dragon_nest"})
	acts[0]["normal"].append({"encounter": "witch_coven"})
	acts[0]["boss"] = "hound_pack"
	acts[0]["elite_days"] = [3, 5, 6]
	var errors: Array[String] = _errors_with(RunContent.ACTS_FILE, acts)
	_assert_error(errors, "unknown encounter \"dragon_nest\"")
	_assert_error(errors, "\"witch_coven\" is a elite encounter, not normal")
	_assert_error(errors, "\"hound_pack\" is a normal encounter, not boss")
	_assert_error(errors, "elite day 6 must be between 1 and 5")


func test_every_day_needs_an_encounter() -> void:
	var acts: Array = JSON.parse_string(_texts()[RunContent.ACTS_FILE])
	acts[0]["normal"] = [{"encounter": "pup_litter", "days": [1, 1]}]
	_assert_error(_errors_with(RunContent.ACTS_FILE, acts), "day 2 has no normal encounter")


func test_economy_and_events_are_checked() -> void:
	var economy: Dictionary = JSON.parse_string(_texts()[RunContent.ECONOMY_FILE])
	economy.erase("base_gold")
	economy["item_price"].erase("s")
	var errors: Array[String] = _errors_with(RunContent.ECONOMY_FILE, economy)
	_assert_error(errors, "missing required key \"base_gold\"")
	_assert_error(errors, "item_price: missing required key \"s\"")
	_assert_error(_errors_with(RunContent.EVENTS_FILE, [{"id": "x", "name": "X", "text": "?", "kind": "wish"}]), "kind: unknown value \"wish\"")
	var shops: Array = [{"id": "s", "name": "S", "text": "?", "kind": "tier_shop", "count": 3}, {"id": "t", "name": "T", "text": "?", "kind": "tier_shop", "tier": "z", "count": 9}]
	var shop_errors: Array[String] = _errors_with(RunContent.EVENTS_FILE, shops)
	_assert_error(shop_errors, "missing required key \"tier\"")
	_assert_error(shop_errors, "tier: unknown value \"z\"")
	_assert_error(shop_errors, "count: 9 is out of range")
