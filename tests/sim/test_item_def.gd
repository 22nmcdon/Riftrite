extends GutTest


func _read(data: Dictionary, basic_attack: bool = false) -> Array:
	var errors: Array[String] = []
	var reader := DataReader.new(data, "item", errors)
	var def: ItemDef = ItemDef.read_basic_attack(reader) if basic_attack else ItemDef.read(reader)
	return [def, errors]


func _assert_error(errors: Array[String], expected: String) -> void:
	var found: bool = false
	for message: String in errors:
		found = found or message.contains(expected)
	assert_true(found, "expected an error containing '%s', got: %s" % [expected, errors])


func test_reads_item() -> void:
	var data: Dictionary = SimTestKit.DEFAULT_ITEM.duplicate(true)
	data.merge({"id": "rust_hook", "size": 2, "tags": ["weapon", "tool"], "auto_attack": true, "cooldown_ms": 3000, "crit_chance_bp": 500, "timing": "rush"}, true)
	var result: Array = _read(data)
	var def: ItemDef = result[0]
	assert_eq(result[1], [] as Array[String])
	assert_eq(def.size, 2)
	assert_eq(def.tags, ["weapon", "tool"] as Array[String])
	assert_true(def.auto_attack)
	assert_eq(def.cooldown_ticks, 60)
	assert_eq(def.crit_chance_bp, 500)
	assert_eq(def.timing, ItemDef.Timing.RUSH)
	assert_false(def.is_basic_attack)


func test_crit_chance_defaults_to_zero() -> void:
	var data: Dictionary = SimTestKit.DEFAULT_ITEM.duplicate(true)
	data["id"] = "plain"
	assert_eq((_read(data)[0] as ItemDef).crit_chance_bp, 0)


func test_reads_basic_attack() -> void:
	var data: Dictionary = SimTestKit.DEFAULT_BASIC.duplicate(true)
	data["id"] = "warden_swing"
	var result: Array = _read(data, true)
	assert_eq(result[1], [] as Array[String])
	assert_true((result[0] as ItemDef).is_basic_attack)
	assert_eq((result[0] as ItemDef).size, 0)


func test_basic_attack_rejects_upgrade_fields() -> void:
	var data: Dictionary = SimTestKit.DEFAULT_BASIC.duplicate(true)
	data.merge({"id": "warden_swing", "size": 1, "rarity": "rare"}, true)
	var errors: Array[String] = _read(data, true)[1]
	_assert_error(errors, "unknown key \"rarity\"")
	_assert_error(errors, "unknown key \"size\"")


func test_rejects_bad_fields() -> void:
	var data: Dictionary = SimTestKit.DEFAULT_ITEM.duplicate(true)
	data.merge({"id": "bad", "size": 4, "tags": ["weapon", "hat"], "rarity": "mythic", "cooldown_ms": 0}, true)
	var errors: Array[String] = _read(data)[1]
	_assert_error(errors, "size: 4 is out of range")
	_assert_error(errors, "tags[1]: unknown value \"hat\"")
	_assert_error(errors, "rarity: unknown value \"mythic\"")
	_assert_error(errors, "cooldown_ms: 0 is out of range")


func test_rejects_item_without_effects() -> void:
	var data: Dictionary = SimTestKit.DEFAULT_ITEM.duplicate(true)
	data["id"] = "empty"
	data.erase("effects")
	_assert_error(_read(data)[1], "an item needs effects, auras, or a backup mode")
