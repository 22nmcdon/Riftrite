extends GutTest
## Infusion XP, levels (Base x1, Attuned x1.5, Resonant x2), and spill.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _blade(item_id: String, xp_per_fire: int = 0) -> ItemDef:
	return K.item(item_id, {"name": item_id.capitalize(), "xp_per_fire": xp_per_fire, "effects": K.damage(100)})


func _hero(items: Array) -> UnitSetup:
	return K.unit("hero", BIG_HP, FRONT, items, _idle())


func _infused(item: ItemDef, essence: String, xp: int) -> ItemSetup:
	return K.equip(item, [essence] as Array[String], 0, xp)


func _values(items: Array, index: int) -> PackedStringArray:
	var sim := CombatSim.new(K.fight([_hero(items)], [K.dummy("foe", BIG_HP)]), K.content())
	return sim.units[0].items[index].describe_values()


func _applied(result: FightResult, item_id: String) -> Array[LogEntry]:
	return result.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(
		func(entry: LogEntry) -> bool: return entry.source_item == item_id)


# --- levels ------------------------------------------------------------------------------

func test_level_thresholds() -> void:
	var levels: Array[int] = []
	for xp: int in [0, 99, 100, 299, 300, 5000]:
		levels.append(Infusions.level_for(xp, K.tuning()))
	assert_eq(levels, [0, 0, 1, 1, 2, 2] as Array[int])


func test_levels_strengthen_the_same_kind_bonus() -> void:
	assert_eq(_values([_infused(_blade("sword"), "wrath", 100)], 1), PackedStringArray(["damage: 175 (base 100, x1.75 Wrath, Attuned)"]))
	assert_eq(_values([_infused(_blade("sword"), "wrath", 300)], 1), PackedStringArray(["damage: 200 (base 100, x2 Wrath, Resonant)"]))


func test_attuned_conversion_is_half_again_stronger() -> void:
	var result: FightResult = K.run([_hero([_infused(_blade("sword"), "ember", 100)])], [K.dummy("foe", BIG_HP)])
	var burns: Array[LogEntry] = _applied(result, "sword")
	assert_eq([burns[0].amount, burns[1].amount], [7, 8], "7.5% of 100 per hit")
	assert_eq(burns[0].to_text(), "[1.00s] hero · Sword [Ember, Attuned] applies 7 Burn to foe (7 total)")


func test_attuned_modifiers_are_stronger() -> void:
	var sim := CombatSim.new(K.fight([_hero([_infused(_blade("sword"), "storm", 100), _infused(_blade("knife"), "umbral", 300)])], [K.dummy("foe", BIG_HP)]), K.content())
	assert_eq(sim.units[0].items[1].cooldown_ticks, 16, "-22.5% of 20 ticks = 15.5, rounds to 16")
	assert_eq(sim.units[0].items[2].crit_chance_bp, 3000, "Umbral +15% x2 at Resonant")


func test_attuned_frost_lands_one_and_a_half_slows() -> void:
	var result: FightResult = K.run([_hero([_infused(_blade("icicle"), "frost", 100)])], [K.dummy("foe", BIG_HP)])
	var slows: Array[int] = []
	for entry: LogEntry in _applied(result, "icicle"):
		slows.append(entry.amount)
	assert_eq(slows.slice(0, 4), [1, 2, 1, 2] as Array[int])


# --- XP ------------------------------------------------------------------------------------

func test_fires_earn_xp_and_level_up_mid_fight() -> void:
	var result: FightResult = K.run([_hero([_infused(_blade("sword", 4), "ember", 92)])], [K.dummy("foe", BIG_HP)])
	var level_up: LogEntry = result.combat_log.of_kind(LogEntry.Kind.INFUSION_LEVEL)[0]
	assert_eq(level_up.to_text(), "[2.00s] hero · Sword [Ember] becomes Attuned (100 XP)")
	var burns: Array[int] = []
	for entry: LogEntry in _applied(result, "sword").slice(0, 3):
		burns.append(entry.amount)
	assert_eq(burns, [5, 5, 7] as Array[int], "the hit at 2s lands before the XP; from 3s on it's Attuned")


func test_fight_reports_infusion_xp() -> void:
	var result: FightResult = K.run([_hero([_infused(_blade("sword", 4), "ember", 92), _blade("plain", 4)])], [K.dummy("foe", BIG_HP)])
	assert_eq(result.infusions.size(), 1, "only infused items")
	var infusion: FightResult.InfusionResult = result.infusions[0]
	var fires: int = K.entries(result, LogEntry.Kind.FIRE, "sword").size()
	assert_eq([infusion.unit_id, infusion.item_id, infusion.slot], ["hero", "sword", 0])
	assert_eq([infusion.xp_before, infusion.xp_after], [92, 92 + 4 * fires + 10], "fires plus 10 for the battle")
	assert_eq([infusion.level_before, infusion.level_after], [0, 2])


func test_battle_xp_can_level_up_after_the_fight() -> void:
	var result: FightResult = K.run([_hero([_infused(_blade("sword"), "ember", 95)])], [K.dummy("foe", 50)])
	var last: LogEntry = result.combat_log.entries[-1]
	assert_eq(last.to_text(), "[1.00s] hero · Sword [Ember] becomes Attuned (105 XP, after the fight)")


func test_xp_without_an_infusion_is_rejected() -> void:
	var result: FightResult = K.run([_hero([K.equip(_blade("sword"), [] as Array[String], 0, 50)])], [K.dummy("foe", 50)])
	assert_true(result.errors.any(func(e: String) -> bool: return e.contains("has 50 infusion XP but no infusion")), str(result.errors))


# --- spill ---------------------------------------------------------------------------------

func _row(middle_essence: String, middle_xp: int, middle_xp_per_fire: int = 0) -> Array:
	return [_blade("left"), _infused(_blade("mid", middle_xp_per_fire), middle_essence, middle_xp), _blade("right")]


func test_resonant_single_essence_spills_to_both_neighbors() -> void:
	var result: FightResult = K.run([_hero(_row("ember", 300))], [K.dummy("foe", BIG_HP)])
	var first: Array[String] = []
	for item_id: String in ["left", "mid", "right"]:
		var entry: LogEntry = _applied(result, item_id)[0]
		first.append("%s: %d [%s]" % [item_id, entry.amount, entry.source_infusion_name])
	assert_eq(first, ["left: 3 [Ember spill from Mid]", "mid: 10 [Ember, Resonant]", "right: 3 [Ember spill from Mid]"] as Array[String],
		"Resonant x2; spill is 30% of that: 5% x 0.6 = 3% of 100")


func test_spill_carries_the_same_kind_bonus() -> void:
	assert_eq(_values(_row("wrath", 300), 1), PackedStringArray(["damage: 130 (base 100, x1.3 Wrath spill from Mid)"]))


func test_only_resonant_infusions_spill() -> void:
	assert_eq(_values(_row("wrath", 299), 1), PackedStringArray(["damage: 100"]))


func test_spill_stays_in_the_row_and_skips_the_basic_attack() -> void:
	var swing: ItemDef = K.basic("swing", {"effects": K.damage(100)})
	var hero: UnitSetup = K.unit("hero", BIG_HP, FRONT, [_infused(_blade("mid"), "wrath", 300)], swing)
	var ally: UnitSetup = K.unit("ally", BIG_HP, FRONT, [_blade("other")], _idle())
	var sim := CombatSim.new(K.fight([hero, ally], [K.dummy("foe", BIG_HP)]), K.content())
	assert_eq(sim.units[0].items[0].describe_values(), PackedStringArray(["damage: 100"]), "basic attack gets no spill")
	assert_eq(sim.units[1].items[1].describe_values(), PackedStringArray(["damage: 100"]), "another hero's row gets no spill")


func test_reaching_resonant_mid_fight_starts_the_spill() -> void:
	var result: FightResult = K.run([_hero(_row("ember", 296, 4))], [K.dummy("foe", BIG_HP)])
	# At 1s: left fires first (no spill yet), then mid reaches Resonant, then right fires with the spill.
	var at_20: Array[String] = []
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED):
		if entry.tick == 20:
			at_20.append("%s [%s]" % [entry.source_item, entry.source_infusion_name])
	assert_eq(at_20, ["mid [Ember, Attuned]", "right [Ember spill from Mid]"] as Array[String])
	assert_eq(_applied(result, "left")[0].tick, 40)
