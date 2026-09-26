extends GutTest
## ContentDb loading and validation. Each "bad data" test starts from the real
## files in data/ and changes one thing, so it also proves that exact problem
## is what gets reported.


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


func _essences_with(index: int, entry: Dictionary) -> Array:
	var essences: Array = _real_json(ContentDb.ESSENCES_FILE)
	essences[index] = entry
	return essences


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


func test_real_data_contents() -> void:
	var db: ContentDb = ContentDb.load_dir("res://data")
	assert_eq(db.essence_ids, ["ember", "venom", "wrath", "stone", "verdant", "frost", "storm", "umbral"] as Array[String])
	assert_eq(db.status_ids, ["burn", "poison", "bleed", "golden_flame", "plasma", "blight", "slow", "freeze", "blind",
		"deathcap", "rime", "searfire", "caustic", "nightshade", "hemorrhage"] as Array[String])
	assert_eq(db.alloy_ids, ["inferno", "plasma", "blight", "bloom", "deathcap", "deep_freeze", "searfire", "caustic", "nightshade", "hemorrhage"] as Array[String])
	assert_eq([db.essences["ember"].adds, db.essences["venom"].adds, db.essences["wrath"].adds], ["burn", "poison", "damage"])
	assert_true(db.essences["umbral"].adds_on_crit_only)

	var frost: EssenceDef = db.essences["frost"]
	assert_eq(frost.effects[0].type, EffectDef.Type.APPLY_STATUS)
	assert_eq(frost.effects[0].status_id, "slow")
	assert_eq(db.statuses["slow"].slow_bp_per_stack, 1000)
	assert_eq(db.statuses["freeze"].duration_ticks, 20, "design: Freeze lasts 1s")

	var storm: EssenceDef = db.essences["storm"]
	assert_eq(db.statuses["poison"].vs_shield_bp, 0, "poison skips shields")
	assert_eq(db.statuses["bleed"].defense_shred_per_stack, 1)
	assert_eq(storm.modifiers[0].stat, ModifierDef.Stat.COOLDOWN_BP)
	assert_eq(storm.modifiers[0].value, -1500, "design: Storm cooldown -15%")


func test_real_tuning_converted_to_ticks() -> void:
	var tuning: TuningDef = ContentDb.load_dir("res://data").tuning
	assert_eq(tuning.collapse_start_ticks, 900, "45s")
	assert_eq(tuning.collapse_surge_ticks, 1800, "90s")
	assert_eq(tuning.tie_ticks, 3600, "180s")
	assert_eq(tuning.rush_end_ticks, 160, "8s")
	assert_eq(tuning.stall_start_ticks, 300, "15s")
	assert_eq(tuning.crit_damage_bp, 15000)
	var act1: CollapseDef = tuning.collapse_for_act(1)
	var act2: CollapseDef = tuning.collapse_for_act(2)
	assert_eq([act1.base, act1.growth, act1.accel], [10, 10, 2])
	assert_eq([act2.base, act2.growth, act2.accel], [20, 20, 4], "Act 2 doubles Act 1")
	assert_null(tuning.collapse_for_act(3), "Act 3 is not decided yet")


func test_loading_is_repeatable() -> void:
	var first: ContentDb = _load_with(ContentDb.ESSENCES_FILE, [{"id": "Bad"}, {"id": "x", "name": 5}])
	var second: ContentDb = _load_with(ContentDb.ESSENCES_FILE, [{"id": "Bad"}, {"id": "x", "name": 5}])
	assert_gt(first.errors.size(), 0)
	assert_eq(first.errors, second.errors, "same input, same errors, same order")


# --- numbers -----------------------------------------------------------------

func test_rejects_fractional_number() -> void:
	var db: ContentDb = _load_with(ContentDb.ESSENCES_FILE, _essences_with(0, {
		"id": "ember", "name": "Ember",
		"effects": [{"trigger": "on_hit", "type": "apply_status", "status": "burn", "stacks": 1.5, "target": "hit_target"}],
	}))
	_assert_error(db, "essences.json[0] (ember).effects[0].stacks: expected a whole number, got 1.5")


func test_rejects_number_as_string() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["xp_per_battle"] = "10"
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "tuning.json.xp_per_battle: expected a whole number, got \"10\"")


func test_rejects_out_of_range() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["spill_single_bp"] = 12000
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "spill_single_bp: 12000 is out of range")


func test_rejects_duration_between_ticks() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["rush_end_ms"] = 8025
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "rush_end_ms: 8025 ms is not a whole number of ticks")


# --- structure -----------------------------------------------------------------

func test_rejects_unknown_key() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["spill_singel_bp"] = 3000
	_assert_error(_load_with(ContentDb.TUNING_FILE, tuning), "tuning.json: unknown key \"spill_singel_bp\"")


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
	assert_false(db.is_valid())


func test_rejects_duplicate_id() -> void:
	var essences: Array = _real_json(ContentDb.ESSENCES_FILE)
	essences.append(essences[0])
	_assert_error(_load_with(ContentDb.ESSENCES_FILE, essences), "duplicate id \"ember\"")


func test_rejects_badly_formed_id() -> void:
	var essences: Array = _real_json(ContentDb.ESSENCES_FILE)
	essences[0]["id"] = "Ember Stone"
	_assert_error(_load_with(ContentDb.ESSENCES_FILE, essences), "id \"Ember Stone\" must be lowercase")


# --- effects and references ---------------------------------------------------

func test_rejects_unknown_status_reference() -> void:
	var db: ContentDb = _load_with(ContentDb.ESSENCES_FILE, _essences_with(0, {
		"id": "ember", "name": "Ember",
		"effects": [{"trigger": "on_hit", "type": "apply_status", "status": "scorch", "stacks": 1, "target": "hit_target"}],
	}))
	_assert_error(db, "essences.json (ember).effects[0]: unknown status \"scorch\"")


func test_rejects_unknown_vocabulary() -> void:
	var db: ContentDb = _load_with(ContentDb.ESSENCES_FILE, _essences_with(0, {
		"id": "ember", "name": "Ember",
		"effects": [{"trigger": "on_kill", "type": "apply_status", "status": "burn", "stacks": 1, "target": "hit_target"}],
	}))
	_assert_error(db, "trigger: unknown value \"on_kill\"")


func test_rejects_hit_target_on_fire() -> void:
	var db: ContentDb = _load_with(ContentDb.ESSENCES_FILE, _essences_with(0, {
		"id": "ember", "name": "Ember",
		"effects": [{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 1, "target": "hit_target"}],
	}))
	_assert_error(db, "trigger must be on_hit or on_crit")


func test_shield_needs_exactly_one_amount() -> void:
	var db: ContentDb = _load_with(ContentDb.ESSENCES_FILE, _essences_with(3, {
		"id": "stone", "name": "Stone",
		"effects": [{"trigger": "on_hit", "type": "shield", "amount": 5, "amount_bp_of_damage": 3000, "target": "self"}],
	}))
	_assert_error(db, "shield needs exactly one of")


func test_rejects_empty_essence() -> void:
	var db: ContentDb = _load_with(ContentDb.ESSENCES_FILE, _essences_with(0, {"id": "ember", "name": "Ember"}))
	_assert_error(db, "an essence needs \"adds\", an effect, or a modifier")


func test_rejects_essence_adding_a_non_output() -> void:
	var db: ContentDb = _load_with(ContentDb.ESSENCES_FILE, _essences_with(0, {"id": "ember", "name": "Ember", "adds": "slow"}))
	_assert_error(db, "adds \"slow\", which is not damage, shield, heal, or a damage-over-time status")


func test_tuning_cross_checks() -> void:
	var tuning: Dictionary = _real_json(ContentDb.TUNING_FILE)
	tuning["xp_to_resonant"] = 50
	tuning["collapse_by_act"].erase("1")
	var db: ContentDb = _load_with(ContentDb.TUNING_FILE, tuning)
	_assert_error(db, "xp_to_resonant (50) must be greater than xp_to_attuned (100)")
	_assert_error(db, "collapse_by_act: must define act \"1\"")
