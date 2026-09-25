extends GutTest
## Unit stats, stat-scaled item numbers, and multiplicative boosts.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _dagger(rarity: String = "common") -> ItemDef:
	return K.item("dagger", {"name": "Dagger", "rarity": rarity, "effects": [
		{"trigger": "on_fire", "type": "damage", "amount": 4, "scaling": {"atk": 6000}, "target": "enemy_front"},
	]})


func _item_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var full: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	full.merge(data, true)
	full["id"] = "x"
	ItemDef.read(DataReader.new(full, "x", errors))
	return errors


func _has(errors: Array[String], expected: String) -> bool:
	return errors.any(func(message: String) -> bool: return message.contains(expected))


# --- numbers -------------------------------------------------------------------

func test_breakdown_scales_then_multiplies() -> void:
	var value: ValueBreakdown = ValueBreakdown.compute(4, [0, 6000, 0, 0, 0, 0] as Array[int], UnitStats.make(300, 35),
		[ValueBreakdown.multiplier("B tier", 15000)] as Array[ValueBreakdown.Multiplier])
	assert_eq([value.base, value.scaled, value.final], [4, 25, 38], "4 + 60% of 35 = 25; x1.5 = 37.5, rounds to 38")
	assert_eq(value.to_text(), "38 (base 4 + 60% ATK 21 = 25, x1.5 B tier)")


func test_boosts_multiply() -> void:
	var value: ValueBreakdown = ValueBreakdown.compute(100, [0, 0, 0, 0, 0, 0] as Array[int], UnitStats.make(1),
		[ValueBreakdown.multiplier("B tier", 15000), ValueBreakdown.multiplier("bonus", 12000)] as Array[ValueBreakdown.Multiplier])
	assert_eq(value.final, 180, "x1.5 then x1.2 = x1.8, not +70%")


func test_plain_value_reads_as_a_number() -> void:
	var value: ValueBreakdown = ValueBreakdown.compute(10, [0, 0, 0, 0, 0, 0] as Array[int], UnitStats.make(1), [] as Array[ValueBreakdown.Multiplier])
	assert_eq(value.to_text(), "10")


func test_item_numbers_in_a_fight() -> void:
	var hero: UnitSetup = K.unit_with("hero", UnitStats.make(BIG_HP, 35), FRONT, [K.equip(_dagger(), [] as Array[String], 1)], _idle())
	var sim := CombatSim.new(K.fight([hero], [K.dummy("foe", BIG_HP)]), K.content())
	assert_eq(sim.units[0].items[1].describe_values(), PackedStringArray(["damage: 38 (base 4 + 60% ATK 21 = 25, x1.5 B tier)"]))
	var result: FightResult = K.run([hero], [K.dummy("foe", BIG_HP)])
	assert_eq(K.entries(result, LogEntry.Kind.DAMAGE, "dagger")[0].amount, 38)


func test_basic_attacks_scale_but_have_no_tier() -> void:
	var swing: ItemDef = K.basic("swing", {"effects": [{"trigger": "on_fire", "type": "damage", "amount": 2, "scaling": {"atk": 10000}, "target": "enemy_front"}]})
	var sim := CombatSim.new(K.fight([K.unit_with("hero", UnitStats.make(BIG_HP, 20), FRONT, [], swing)], [K.dummy("foe", BIG_HP)]), K.content())
	assert_eq(sim.units[0].items[0].describe_values(), PackedStringArray(["damage: 22 (base 2 + 100% ATK 20 = 22)"]))


func test_rank_boosts_every_stat() -> void:
	var hero: UnitSetup = K.unit_with("hero", UnitStats.make(300, 20, 8, 4, 2, 10), FRONT, [], _idle(), 1)
	var sim := CombatSim.new(K.fight([hero], [K.dummy("foe", BIG_HP)]), K.content())
	assert_eq(sim.units[0].max_hp, 375, "+25% at rank B")
	assert_eq(sim.units[0].stats.values, [375, 25, 10, 5, 3, 13] as Array[int])


func test_tuning_tables() -> void:
	assert_eq(K.tuning().tier_multiplier_bp, [10000, 15000, 20000, 30000] as Array[int])
	assert_eq(K.tuning().rank_multiplier_bp, [10000, 12500, 15625, 19531] as Array[int])


# --- DEF, CRIT, ATSP -------------------------------------------------------------

func test_defense_reduces_hits() -> void:
	var foe: UnitSetup = K.unit_with("foe", UnitStats.make(BIG_HP, 0, 0, 100), FRONT, [], _idle())
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [K.item("club", {"name": "Club", "effects": K.damage(100)})], _idle())], [foe])
	var hit: LogEntry = K.entries(result, LogEntry.Kind.DAMAGE, "club")[0]
	assert_eq([hit.amount, hit.mitigated], [50, 50], "DEF 100 halves hits")
	assert_eq(hit.to_text(), "[1.00s] hero · Club hits foe for 50 (50 blocked by defense)")


func test_collapse_ignores_defense() -> void:
	var foe: UnitSetup = K.unit_with("foe", UnitStats.make(BIG_HP, 0, 0, 100), FRONT, [], _idle())
	var result: FightResult = K.run([K.dummy("hero", BIG_HP)], [foe])
	var hits: Array[LogEntry] = result.combat_log.of_kind(LogEntry.Kind.COLLAPSE).filter(
		func(entry: LogEntry) -> bool: return entry.target == "foe")
	assert_eq(hits[0].amount, 10)


func test_crit_stat_adds_crit_chance() -> void:
	var hero: UnitSetup = K.unit_with("hero", UnitStats.make(BIG_HP, 0, 0, 0, 100), FRONT, [K.item("club", {"effects": K.damage(10)})], _idle())
	var result: FightResult = K.run([hero], [K.dummy("foe", BIG_HP)])
	var hit: LogEntry = K.entries(result, LogEntry.Kind.DAMAGE, "club")[0]
	assert_true(hit.crit, "100 CRIT = +100% crit chance")
	assert_eq(hit.amount, 15)


func test_attack_speed_speeds_only_the_auto_attack() -> void:
	var hero: UnitSetup = K.unit_with("hero", UnitStats.make(BIG_HP, 0, 0, 0, 0, 100), FRONT, [K.item("charm", {"effects": K.damage(1)})])
	var result: FightResult = K.run([hero], [K.dummy("foe", BIG_HP)])
	assert_eq(K.ticks_of(K.entries(result, LogEntry.Kind.FIRE, "basic")).slice(0, 3), [10, 20, 30] as Array[int], "100 ATSP = twice as fast")
	assert_eq(K.ticks_of(K.entries(result, LogEntry.Kind.FIRE, "charm")).slice(0, 2), [20, 40] as Array[int], "other items unchanged")


# --- data rules --------------------------------------------------------------------

func test_common_items_cannot_scale_from_rate_stats() -> void:
	var effects: Array = [{"trigger": "on_fire", "type": "damage", "amount": 1, "scaling": {"atsp": 2000}, "target": "enemy_front"}]
	assert_true(_has(_item_errors({"rarity": "rare", "effects": effects}), "only Epic and Legendary items can scale from crit or atsp"))
	assert_eq(_item_errors({"rarity": "epic", "effects": effects}), [] as Array[String])


func test_basic_attacks_cannot_scale_from_rate_stats() -> void:
	var errors: Array[String] = []
	ItemDef.read_basic_attack(DataReader.new({"id": "b", "name": "B", "cooldown_ms": 1000, "effects": [
		{"trigger": "on_fire", "type": "damage", "amount": 1, "scaling": {"crit": 100}, "target": "enemy_front"}]}, "b", errors))
	assert_true(_has(errors, "only Epic and Legendary items can scale from crit or atsp"), str(errors))


func test_scaling_rejects_unknown_stats() -> void:
	var effects: Array = [{"trigger": "on_fire", "type": "damage", "amount": 1, "scaling": {"luck": 100}, "target": "enemy_front"}]
	assert_true(_has(_item_errors({"effects": effects}), "unknown stat \"luck\""))
