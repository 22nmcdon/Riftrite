extends GutTest
## ContentDb loading and validation of tuning and statuses
## (test_units_content has heroes, enemies, and encounters). Each "bad data"
## test starts from the real files and changes one thing, so it also proves
## that exact problem is what gets reported.


func _real_texts() -> Dictionary[String, String]:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	return texts


func _real_json(file_name: String) -> Variant:
	return JSON.parse_string(_real_texts()[file_name])


## Loads the real data with one file replaced by `data` (serialized to JSON).
func _load_with(file_name: String, data: Variant) -> ContentDb:
	var texts: Dictionary[String, String] = _real_texts()
	texts[file_name] = JSON.stringify(data)
	return ContentDb.load_texts(texts)


func _assert_error(db: ContentDb, expected: String) -> void:
	var found: bool = false
	for message: String in db.errors:
		if message.contains(expected):
			found = true
	assert_true(found, "expected an error containing '%s', got: %s" % [expected, db.errors])


# --- the real data ---------------------------------------------------------

func test_real_data_is_valid() -> void:
	var db: ContentDb = ContentDb.load_dir("res://data")
	assert_eq(db.errors, [] as Array[String])
	assert_true(db.is_valid())


func test_every_data_file_is_loaded() -> void:
	assert_eq(ContentDb.FILES, ["tuning.json", "statuses.json", "heroes.json", "enemies.json", "encounters.json", "tactics.json", "paths.json", "enemy_upgrades.json"] as Array[String])
	var files: PackedStringArray = DirAccess.get_files_at("res://data")
	files.sort()
	var expected: Array = ContentDb.FILES + RunContent.FILES + ["act2.json", "act3.json"]
	expected.sort()
	assert_eq(Array(files), expected, "every file in data/ is one ContentDb or RunContent loads")


func test_real_statuses() -> void:
	var db: ContentDb = ContentDb.load_dir("res://data")
	assert_eq(db.status_ids, ["burn", "poison", "bleed", "root", "stun", "slow", "taunt", "silence", "marked", "undying", "engaged", "stealth", "warded", "sunder", "veiled_haste", "storm_call", "frenzy", "quickened", "unbending", "long_watch", "surge", "surge_2", "last_breath", "purified",
		"grounded", "shadow_step", "shadow_step_2", "shadow_step_3", "bloodhound", "scavenged", "blood_frenzy", "vengeance", "festering", "ember_blind", "watched_over",
		"ambush", "ambush_2", "rear_guard", "late_surge", "hobbled", "weighed_down", "cowed", "parting_shot", "first_blood", "scarred", "hailstorm", "tailwind", "zeal", "morning_haste", "dawnlight", "first_light", "glare", "dazzled", "woven_thorns", "iron_loom", "briar_torn", "gatekeeper", "brand", "war_call", "rally", "oathbound", "gale", "first_light_more", "zeal_more", "shield_wall", "dawn_ward",
		"bulwark_layer", "shatter_echo", "grinder_feed", "undertow_tide", "deep_current", "thorn_crown", "hidden", "shadow_dance", "garroted", "garrote_veil", "assassins_haste", "swift_step", "death_mark",
		"phantom_veil", "phantom_edge", "phantom_edge_more", "veiled", "veil_haste", "veil_haste_more", "executioner_rush", "executioner_rush_more", "on_the_trail", "trailing", "blood_scent", "blood_scent_more", "strangle", "pinned_light", "pinned", "pin_rally", "pin_rally_more", "pealing",
		"iron_maiden"] as Array[String])
	assert_eq(db.statuses["burn"].interval_ticks, 10, "Burn ticks twice a second")
	assert_eq(db.statuses["burn"].stacks_lost_bp, 500)
	assert_eq(db.statuses["burn"].vs_shield_bp, 5000, "Burn is half as effective against shields")
	assert_eq(db.statuses["poison"].vs_shield_bp, 0, "Poison skips shields")
	assert_eq(db.statuses["bleed"].defense_shred_per_stack, 1)
	for id: String in ["burn", "poison", "bleed"]:
		assert_eq(db.statuses[id].kind, StatusDef.Kind.DAMAGE_OVER_TIME)
		assert_false(db.statuses[id].is_timed())
	var kinds: Array[StatusDef.Kind] = [StatusDef.Kind.ROOT, StatusDef.Kind.STUN, StatusDef.Kind.SLOW, StatusDef.Kind.TAUNT, StatusDef.Kind.SILENCE, StatusDef.Kind.MARKED, StatusDef.Kind.UNDYING]
	for i: int in kinds.size():
		var def: StatusDef = db.statuses[db.status_ids[3 + i]]
		assert_eq(def.kind, kinds[i])
		assert_true(def.is_timed())
	assert_eq(db.statuses["stun"].duration_ticks, 20, "1s")
	assert_eq(db.statuses["slow"].slow_bp, 3000)
	assert_eq([db.statuses["marked"].duration_ticks, db.statuses["marked"].damage_taken_bp], [80, 1500], "Marking Shot: +15% for 4s")


func test_real_tuning_converted_to_ticks() -> void:
	var tuning: TuningDef = ContentDb.load_dir("res://data").tuning
	assert_eq(tuning.collapse_start_ticks, 900, "45s")
	assert_eq(tuning.collapse_surge_ticks, 1800, "90s")
	assert_eq(tuning.tie_ticks, 3600, "180s")
	assert_eq(tuning.heal_cleanse_window_ticks, 20, "1s")
	assert_eq(tuning.crit_damage_bp, 15000)
	var act1: CollapseDef = tuning.collapse_for_act(1)
	var act2: CollapseDef = tuning.collapse_for_act(2)
	assert_eq([act1.base, act1.growth, act1.accel], [15, 10, 2], "Act 1 starts at 15 (phase 5c, Decision 8)")
	assert_eq([act2.base, act2.growth, act2.accel], [20, 20, 4], "Act 2 doubles Act 1")
	var act3: CollapseDef = tuning.collapse_for_act(3)
	assert_eq([act3.base, act3.growth, act3.accel], [25, 30, 6], "Act 3 (Decision 14 of the acts plan)")
	assert_null(tuning.collapse_for_act(4), "no Act 4")


func test_loading_is_repeatable() -> void:
	var first: ContentDb = _load_with(ContentDb.STATUSES_FILE, [{"id": "Bad"}, {"id": "x", "name": 5}])
	var second: ContentDb = _load_with(ContentDb.STATUSES_FILE, [{"id": "Bad"}, {"id": "x", "name": 5}])
	assert_gt(first.errors.size(), 0)
	assert_eq(first.errors, second.errors, "same input, same errors, same order")


# --- numbers -----------------------------------------------------------------

func test_rejects_fractional_number() -> void:
	var statuses: Array = _real_json(ContentDb.STATUSES_FILE)
	statuses[0]["damage_per_stack"] = 1.5
	_assert_error(_load_with(ContentDb.STATUSES_FILE, statuses), "statuses.json[0] (burn).damage_per_stack: expected a whole number, got 1.5")


func test_rejects_number_as_string() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["crit_damage_bp"] = "15000"
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "tuning.json.crit_damage_bp: expected a whole number, got \"15000\"")


func test_rejects_out_of_range() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["heal_cleanse_bp"] = 12000
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "heal_cleanse_bp: 12000 is out of range")


func test_rejects_duration_between_ticks() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["collapse_start_ms"] = 45025
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "collapse_start_ms: 45025 ms is not a whole number of ticks")


# --- structure -----------------------------------------------------------------

func test_rejects_unknown_key() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["spill_single_bp"] = 3000
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "tuning.json: unknown key \"spill_single_bp\"")


func test_allows_note_keys() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["_anything"] = "designer note"
	assert_true(_load_with(ContentDb.TUNING_FILE, tuning).is_valid())


func test_rejects_missing_key() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning.erase("tie_ms")
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "tuning.json: missing required key \"tie_ms\"")


func test_rejects_invalid_json() -> void:
	var texts: Dictionary[String, String] = _real_texts()
	texts[ContentDb.STATUSES_FILE] = "[ { \"id\": \"burn\", } "
	_assert_error(ContentDb.load_texts(texts), "statuses.json: invalid JSON on line")


func test_reports_missing_file() -> void:
	var db: ContentDb = ContentDb.load_dir("res://tests/does_not_exist")
	_assert_error(db, "tuning.json: file not found")
	_assert_error(db, "statuses.json: file not found")
	assert_false(db.is_valid())


func test_rejects_a_list_that_isnt_one() -> void:
	_assert_error(_load_with(ContentDb.STATUSES_FILE, {"id": "burn"}), "statuses.json: expected a list of entries")


func test_rejects_duplicate_id() -> void:
	var statuses: Array = _real_json(ContentDb.STATUSES_FILE)
	statuses.append(statuses[0])
	_assert_error(_load_with(ContentDb.STATUSES_FILE, statuses), "duplicate id \"burn\"")


func test_rejects_badly_formed_id() -> void:
	var statuses: Array = _real_json(ContentDb.STATUSES_FILE)
	statuses[0]["id"] = "Ember Burn"
	_assert_error(_load_with(ContentDb.STATUSES_FILE, statuses), "id \"Ember Burn\" must be lowercase")


func test_rejects_removed_status_kinds() -> void:
	var statuses: Array = _real_json(ContentDb.STATUSES_FILE)
	statuses.append({"id": "freeze", "name": "Freeze", "kind": "freeze", "duration_ms": 1000})
	_assert_error(_load_with(ContentDb.STATUSES_FILE, statuses), "kind: unknown value \"freeze\"")


func test_exactly_one_engaged_status() -> void:
	var db: ContentDb = ContentDb.load_dir("res://data")
	assert_eq(db.engaged_status.id, "engaged")
	assert_false(db.engaged_status.is_timed())
	var statuses: Array = _real_json(ContentDb.STATUSES_FILE)
	statuses.append({"id": "held", "name": "Held", "kind": "engaged"})
	_assert_error(_load_with(ContentDb.STATUSES_FILE, statuses), "needs exactly one status of kind \"engaged\" (the Engage trait sets it), found 2")
	var none: Array = _real_json(ContentDb.STATUSES_FILE).filter(func(entry: Dictionary) -> bool: return entry["kind"] != "engaged")
	_assert_error(_load_with(ContentDb.STATUSES_FILE, none), "found 0")


func test_the_collision_stun_is_the_first_stun() -> void:
	assert_eq(ContentDb.load_dir("res://data").stun_status.id, "stun")
	var statuses: Array = _real_json(ContentDb.STATUSES_FILE)
	statuses.append({"id": "daze", "name": "Daze", "kind": "stun", "duration_ms": 500})
	var db: ContentDb = _load_with(ContentDb.STATUSES_FILE, statuses)
	assert_eq(db.stun_status.id, "stun", "the first, not the last")
	var none: Array = _real_json(ContentDb.STATUSES_FILE).filter(func(entry: Dictionary) -> bool: return entry["kind"] != "stun")
	_assert_error(_load_with(ContentDb.STATUSES_FILE, none), "needs a status of kind \"stun\"")


func test_status_fields_by_kind() -> void:
	var statuses: Array = _real_json(ContentDb.STATUSES_FILE)
	statuses.append({"id": "slow_two", "name": "Slow", "kind": "slow", "duration_ms": 1000})
	statuses.append({"id": "mark_two", "name": "Mark", "kind": "marked", "damage_taken_bp": 1000})
	statuses.append({"id": "dot_two", "name": "Rot", "kind": "damage_over_time", "interval_ms": 1000, "damage_per_stack": 1, "duration_ms": 1000})
	var db: ContentDb = _load_with(ContentDb.STATUSES_FILE, statuses)
	_assert_error(db, "(slow_two): missing required key \"slow_bp\"")
	_assert_error(db, "(mark_two): missing required key \"duration_ms\"")
	_assert_error(db, "(dot_two): unknown key \"duration_ms\"")


func test_tuning_cross_checks() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["collapse_surge_ms"] = 40000
	tuning["collapse_by_act"].erase("1")
	var db: ContentDb = _load_with(ContentDb.TUNING_FILE, tuning)
	_assert_error(db, "collapse_surge_ms must not be earlier than collapse_start_ms")
	_assert_error(db, "collapse_by_act: must define act \"1\"")
	var late: Dictionary = _real_json(ContentDb.TUNING_FILE)
	late["tie_ms"] = 45000
	_assert_error(_load_with(ContentDb.TUNING_FILE, late), "tie_ms must be later than collapse_start_ms")
