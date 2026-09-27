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
	assert_eq([act.days, act.elite_days, act.boss], [8, [3, 6] as Array[int], "the_ash_mother"])
	assert_eq(act.encounters_for(act.normal, 1), ["pup_litter", "ash_swarm", "hound_scout", "moth_cloud"] as Array[String])
	assert_eq([act.is_hard("pup_litter", 1), act.is_hard("hound_scout", 1), act.is_hard("hound_scout", 4)], [false, true, false], "harder by day")
	assert_eq(act.hp_bp("hound_scout", 1), 12000)
	assert_eq(act.hp_bp("hound_scout", 3), FixedMath.BP_ONE, "not a day-3 fight")
	assert_true(act.is_boss_day(8))
	assert_eq(run.economy.sell_price(9), 4, "half, rounded down")


func test_acts_are_checked() -> void:
	var acts: Array = JSON.parse_string(_texts()[RunContent.ACTS_FILE])
	acts[0]["normal"].append({"encounter": "dragon_nest"})
	acts[0]["normal"].append({"encounter": "witch_coven"})
	acts[0]["boss"] = "hound_pack"
	acts[0]["elite_days"] = [3, 6, 8]
	var errors: Array[String] = _errors_with(RunContent.ACTS_FILE, acts)
	_assert_error(errors, "unknown encounter \"dragon_nest\"")
	_assert_error(errors, "\"witch_coven\" is a elite encounter, not normal")
	_assert_error(errors, "\"hound_pack\" is a normal encounter, not boss")
	_assert_error(errors, "elite day 8 must be between 1 and 7")


func test_every_day_needs_two_fights() -> void:
	var acts: Array = JSON.parse_string(_texts()[RunContent.ACTS_FILE])
	acts[0]["normal"] = acts[0]["normal"].filter(func(pool: Dictionary) -> bool: return pool["days"][0] != 7 and pool["encounter"] != "archer_nest")
	var errors: Array[String] = _errors_with(RunContent.ACTS_FILE, acts)
	_assert_error(errors, "day 7 needs at least 2 normal encounters (a pick of 2)")
	acts = JSON.parse_string(_texts()[RunContent.ACTS_FILE])
	acts[0]["normal"][0]["hp_bp"] = 0
	_assert_error(_errors_with(RunContent.ACTS_FILE, acts), "hp_bp: 0 is out of range")


func test_kits_are_checked() -> void:
	var cases: Dictionary = {
		"unknown keyword \"sling\"": {"keyword": "sling", "name": "x", "item": "flint_arrows", "essence": "wrath"},
		"unknown essence \"mud\"": {"keyword": "bow", "name": "x", "item": "flint_arrows", "essence": "mud"},
		"unknown item \"stick\"": {"keyword": "bow", "name": "x", "item": "stick", "essence": "wrath"},
		"hatchet doesn't have the bow keyword": {"keyword": "bow", "name": "x", "item": "hatchet", "essence": "wrath"},
		"rift_claw can't be in a kit": {"keyword": "blade", "name": "x", "item": "rift_claw", "essence": "wrath"},
		"last_hearth_lantern can't be in a kit": {"keyword": "mend", "name": "x", "item": "last_hearth_lantern", "essence": "verdant"},
	}
	var ward: Dictionary = {"keyword": "ward", "name": "y", "item": "oak_buckler", "essence": "stone"}
	for expected: String in cases:
		var economy: Dictionary = JSON.parse_string(_texts()[RunContent.ECONOMY_FILE])
		economy["kits"] = [cases[expected], ward]
		_assert_error(_errors_with(RunContent.ECONOMY_FILE, economy), expected)
	var economy: Dictionary = JSON.parse_string(_texts()[RunContent.ECONOMY_FILE])
	economy["kits"] = [ward]
	_assert_error(_errors_with(RunContent.ECONOMY_FILE, economy), "needs at least 2 kits (kit_offers)")
	economy["kits"] = [ward, ward.duplicate()]
	_assert_error(_errors_with(RunContent.ECONOMY_FILE, economy), "two kits for \"ward\"")
	economy["kits"] = [ward, {"keyword": "bow", "name": "x", "item": "flint_arrows", "essence": "wrath"}]
	assert_eq(_errors_with(RunContent.ECONOMY_FILE, economy), [] as Array[String], "two good kits are fine")


func test_economy_and_events_are_checked() -> void:
	var economy: Dictionary = JSON.parse_string(_texts()[RunContent.ECONOMY_FILE])
	economy.erase("base_gold")
	economy["item_price"].erase("epic")
	economy["tier_price_bp"].erase("s")
	economy.erase("shards_per_essence")
	economy["shards_per_essence"] = 3
	var errors: Array[String] = _errors_with(RunContent.ECONOMY_FILE, economy)
	_assert_error(errors, "missing required key \"base_gold\"")
	_assert_error(errors, "item_price: missing required key \"epic\"")
	_assert_error(errors, "tier_price_bp: missing required key \"s\"")
	_assert_error(errors, "unknown key \"shards_per_essence\"")
	_assert_error(_errors_with(RunContent.EVENTS_FILE, [{"id": "x", "name": "X", "text": "?", "kind": "wish"}]), "kind: unknown value \"wish\"")
	_assert_error(_errors_with(RunContent.EVENTS_FILE, [{"id": "x", "name": "X", "text": "?", "kind": "tier_shop"}]), "kind: unknown value \"tier_shop\"")
	var shops: Array = JSON.parse_string(_texts()[RunContent.NODES_FILE])
	shops.append({"id": "t", "name": "T", "text": "?", "kind": "shop", "shop": {"tier": "z", "count": 0}, "weight": 1})
	shops.append({"id": "u", "name": "U", "text": "?", "kind": "shop", "weight": 1})
	var shop_errors: Array[String] = _errors_with(RunContent.NODES_FILE, shops)
	_assert_error(shop_errors, "tier: unknown value \"z\"")
	_assert_error(shop_errors, "count: 0 is out of range")
	_assert_error(shop_errors, "missing required key \"shop\"")
