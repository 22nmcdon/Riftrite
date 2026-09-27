extends GutTest
## The effect vocabulary that survived the rebuild's gut: EffectDef and
## AuraDef read from data. Item targets, charges, row targets, keywords, and
## multi-strike effects are gone and are now rejected like any unknown value.


func _effect(data: Dictionary, relic: bool = false) -> Array:
	var errors: Array[String] = []
	var def: EffectDef = EffectDef.read(DataReader.new(data, "effect", errors), relic)
	return [def, errors]


func _errors(data: Dictionary, relic: bool = false) -> Array[String]:
	var errors: Array[String] = _effect(data, relic)[1]
	return errors


func _assert_error(errors: Array[String], expected: String) -> void:
	assert_true(errors.any(func(message: String) -> bool: return message.contains(expected)), "expected '%s' in %s" % [expected, errors])


func test_reads_each_type() -> void:
	var damage: EffectDef = _effect({"type": "damage", "amount": 8, "target": "target", "scaling": {"atk": 6000}})[0]
	assert_eq([damage.trigger, damage.type, damage.amount, damage.target, damage.scaling[UnitStats.Stat.ATK]],
		[EffectDef.Trigger.ON_FIRE, EffectDef.Type.DAMAGE, 8, EffectDef.Target.TARGET, 6000], "the trigger defaults to on_fire")
	var heal: EffectDef = _effect({"trigger": "on_fire", "type": "heal", "amount": 12, "target": "all_allies"})[0]
	assert_eq([heal.type, heal.amount], [EffectDef.Type.HEAL, 12])
	var shield: EffectDef = _effect({"trigger": "on_hit", "type": "shield", "amount_bp_of_damage": 3000, "target": "self"})[0]
	assert_eq([shield.type, shield.amount_bp_of_damage], [EffectDef.Type.SHIELD, 3000])
	var status: EffectDef = _effect({"trigger": "on_hit", "type": "apply_status", "status": "bleed", "stacks": 2, "target": "hit_target"})[0]
	assert_eq([status.status_id, status.stacks, status.base_value()], ["bleed", 2, 2])
	var cleanse: EffectDef = _effect({"trigger": "on_fire", "type": "cleanse", "amount_bp": 5000, "target": "all_allies"})[0]
	assert_eq([cleanse.type, cleanse.amount], [EffectDef.Type.CLEANSE, 5000])
	var drain: EffectDef = _effect({"type": "mana_drain", "amount": 20, "target": "target"})[0]
	assert_eq([drain.type, drain.amount], [EffectDef.Type.MANA_DRAIN, 20])
	_assert_error(_errors({"type": "mana_drain", "amount": 0, "target": "target"}), "amount: 0 is out of range")


func test_good_effects_have_no_errors() -> void:
	for data: Dictionary in [
		{"trigger": "on_fire", "type": "damage", "amount": 8, "target": "all_enemies"},
		{"trigger": "on_hit_taken", "type": "damage", "amount": 3, "target": "hit_target", "every": 3},
		{"trigger": "on_status", "type": "heal", "amount": 3, "target": "self", "statuses": ["burn"]},
		{"trigger": "on_fire", "type": "damage", "amount": 8, "target": "target", "window": {"from_ms": 0, "until_ms": 8000}},
	]:
		assert_eq(_errors(data), [] as Array[String], str(data))


func test_the_removed_vocabulary_is_rejected() -> void:
	_assert_error(_errors({"trigger": "on_fire", "type": "charge", "amount_ms": 500, "target": "holder_items"}), "type: unknown value \"charge\"")
	for gone: String in ["enemy_front", "enemy_back", "row_allies", "enemy_front_row", "enemy_back_row", "enemy_random", "enemy_lowest_hp", "ally_lowest_hp"]:
		_assert_error(_errors({"trigger": "on_fire", "type": "damage", "amount": 5, "target": gone}), "target: unknown value \"%s\"" % gone)
	_assert_error(_errors({"trigger": "on_fire", "type": "damage", "amount": 5, "target": "all_enemies", "hits": 3, "hit_interval_ms": 100}), "unknown key \"hits\"")
	_assert_error(_errors({"trigger": "on_ability", "type": "damage", "amount": 5, "target": "all_enemies", "keyword": "blade"}), "unknown key \"keyword\"")


func test_scaling_is_from_the_six_power_stats() -> void:
	assert_eq(_errors({"type": "damage", "amount": 5, "target": "target", "scaling": {"hp": 100, "atsp": 500}}), [] as Array[String])
	for positional: String in ["speed", "range"]:
		_assert_error(_errors({"type": "damage", "amount": 5, "target": "target", "scaling": {positional: 100}}), "can't scale from \"%s\"" % positional)


func test_hit_rules() -> void:
	_assert_error(_errors({"trigger": "on_fire", "type": "damage", "amount": 5, "target": "hit_target"}), "trigger must be on_hit or on_crit")
	_assert_error(_errors({"trigger": "on_kill", "type": "damage", "amount": 5, "target": "hit_target"}), "on_kill names no unit, so it can't use hit_target")
	_assert_error(_errors({"trigger": "on_heal", "type": "shield", "amount_bp_of_damage": 5000, "target": "self"}), "on_heal names no hit")
	_assert_error(_errors({"trigger": "on_hit", "type": "shield", "amount": 5, "amount_bp_of_damage": 3000, "target": "self"}), "shield needs exactly one of")
	_assert_error(_errors({"trigger": "on_hit", "type": "shield", "amount_bp_of_damage": 3000, "target": "self", "scaling": {"atk": 100}}), "\"scaling\" can't be combined with amount_bp_of_damage")


func test_relic_rules() -> void:
	assert_eq(_errors({"trigger": "on_fight_start", "type": "shield", "amount": 20, "target": "all_allies"}, true), [] as Array[String])
	assert_eq(_errors({"trigger": "on_ally_below_hp", "threshold_bp": 3000, "once": true, "type": "heal", "amount": 20, "target": "trigger_ally"}, true), [] as Array[String])
	_assert_error(_errors({"trigger": "on_hit", "type": "damage", "amount": 5, "target": "all_enemies"}, true), "relic effects can't use the trigger \"on_hit\"")
	_assert_error(_errors({"trigger": "on_fire", "type": "damage", "amount": 5, "target": "self"}, true), "\"self\" needs a unit on the field")
	_assert_error(_errors({"trigger": "on_fire", "type": "damage", "amount": 5, "target": "target"}, true), "\"target\" needs a unit on the field")
	_assert_error(_errors({"trigger": "on_fire", "type": "damage", "amount": 5, "target": "all_enemies", "scaling": {"atk": 5000}}, true), "relic numbers are flat")
	_assert_error(_errors({"trigger": "on_fight_start", "type": "damage", "amount": 5, "target": "all_enemies"}), "ability effects can't use the trigger \"on_fight_start\"")
	_assert_error(_errors({"trigger": "on_fire", "type": "heal", "amount": 5, "target": "trigger_ally"}), "\"trigger_ally\" only works with the on_ally_below_hp trigger")


func test_windows() -> void:
	var def: EffectDef = _effect({"trigger": "on_fire", "type": "damage", "amount": 5, "target": "all_enemies", "window": {"from_ms": 1000, "until_ms": 2000}})[0]
	assert_eq([def.window_from_ticks, def.window_until_ticks], [20, 40])
	assert_eq([def.active_at(19), def.active_at(20), def.active_at(39), def.active_at(40)], [false, true, true, false])
	_assert_error(_errors({"trigger": "on_fire", "type": "damage", "amount": 5, "target": "all_enemies", "window": {"from_ms": 2000, "until_ms": 1000}}), "until_ms must be later than from_ms")


func test_auras() -> void:
	var errors: Array[String] = []
	var aura: AuraDef = AuraDef.read(DataReader.new({"target": "holder", "stat": "def_bp", "value": 20000, "label": "Rush", "window": {"until_ms": 8000}}, "aura", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([aura.target, aura.stat, aura.value, aura.label, aura.window_until_ticks], [AuraDef.Target.HOLDER, AuraDef.Stat.DEF_BP, 20000, "Rush", 160])
	assert_true(aura.is_unit_stat())
	assert_eq(aura.describe(), "x2 DEF for its holder")
	var crit: AuraDef = AuraDef.read(DataReader.new({"target": "all_allies", "stat": "crit_chance_bp", "value": 1500}, "aura", errors))
	assert_true(crit.is_additive())
	assert_eq(crit.describe(), "+15% crit chance for all allies")
	for gone: String in ["self_item", "holder_items", "all_items", "matched_items", "row_allies"]:
		var bad: Array[String] = []
		AuraDef.read(DataReader.new({"target": gone, "stat": "damage_bp", "value": 12000}, "aura", bad))
		_assert_error(bad, "target: unknown value \"%s\"" % gone)
	var filtered: Array[String] = []
	AuraDef.read(DataReader.new({"target": "holder", "stat": "damage_bp", "value": 12000, "filter": {"tag": "weapon"}}, "aura", filtered))
	_assert_error(filtered, "unknown key \"filter\"")
