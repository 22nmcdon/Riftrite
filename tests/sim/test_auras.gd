extends GutTest
## Auras: continuous boosts from items, with windows, on items or units.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _plain(item_id: String, amount: int = 10) -> ItemDef:
	return K.item(item_id, {"name": item_id.capitalize(), "effects": K.damage(amount)})


func _with_aura(item_id: String, auras: Array, amount: int = 10) -> ItemDef:
	return K.item(item_id, {"name": item_id.capitalize(), "effects": K.damage(amount), "auras": auras})


func _values(heroes: Array[UnitSetup], unit_index: int, item_index: int, until_tick: int = 0) -> PackedStringArray:
	var sim := CombatSim.new(K.fight(heroes, [K.dummy("foe", BIG_HP)]), K.content())
	while sim.tick < until_tick:
		sim.step()
	return sim.units[unit_index].items[item_index].describe_values()


func _hit_amounts(result: FightResult, item_id: String, count: int) -> Array[int]:
	var amounts: Array[int] = []
	for entry: LogEntry in K.entries(result, LogEntry.Kind.DAMAGE, item_id).slice(0, count):
		amounts.append(entry.amount)
	return amounts


# --- item targets --------------------------------------------------------------------

func test_adjacent_items_get_crit() -> void:
	var drum: ItemDef = _with_aura("drum", [{"target": "adjacent_items", "stat": "crit_chance_bp", "value": 10000}])
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [_plain("left"), drum, _plain("right"), _plain("far")], _idle())], [K.dummy("foe", BIG_HP)])
	var first: Array[String] = []
	for item_id: String in ["left", "drum", "right", "far"]:
		first.append("%s %d" % [item_id, K.entries(result, LogEntry.Kind.DAMAGE, item_id)[0].amount])
	assert_eq(first, ["left 15", "drum 10", "right 15", "far 10"] as Array[String], "+100% crit on the neighbors only")


func test_rush_self_boost_shows_in_the_breakdown_and_ends() -> void:
	var dagger: ItemDef = _with_aura("dagger", [{"target": "self_item", "stat": "damage_bp", "value": 20000, "label": "Rush", "window": {"until_ms": 8000}}])
	var heroes: Array[UnitSetup] = [K.unit("hero", BIG_HP, FRONT, [dagger], _idle())]
	assert_eq(_values(heroes, 0, 1), PackedStringArray(["damage: 20 (base 10, x2 Rush (Dagger))"]))
	assert_eq(_values(heroes, 0, 1, 160), PackedStringArray(["damage: 10"]), "gone at 8s")


# --- unit targets --------------------------------------------------------------------

func test_holder_defense_doubles_for_8_seconds() -> void:
	var bulwark: ItemDef = _with_aura("bulwark", [{"target": "holder", "stat": "def_bp", "value": 20000, "window": {"until_ms": 8000}}])
	var hero: UnitSetup = K.unit_with("hero", UnitStats.make(BIG_HP, 0, 0, 50), FRONT, [bulwark], _idle())
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, [_plain("club", 100)], _idle())
	var result: FightResult = K.run([hero], [foe])
	var hits: Array[LogEntry] = K.entries(result, LogEntry.Kind.DAMAGE, "club")
	assert_eq([hits[0].tick, hits[0].amount], [20, 50], "DEF 100 while the aura lasts")
	assert_eq([hits[8].tick, hits[8].amount], [180, 67], "DEF 50 after")


func test_stat_aura_rescales_the_holders_items() -> void:
	var fist: ItemDef = K.item("fist", {"effects": [{"trigger": "on_fire", "type": "damage", "amount": 0, "scaling": {"atk": 10000}, "target": "enemy_front"}],
		"auras": [{"target": "holder", "stat": "atk_bp", "value": 20000}]})
	var heroes: Array[UnitSetup] = [K.unit_with("hero", UnitStats.make(BIG_HP, 10), FRONT, [fist], _idle())]
	assert_eq(_values(heroes, 0, 1), PackedStringArray(["damage: 20 (base 0 + 100% ATK 20 = 20)"]))


func test_item_stat_on_a_unit_boosts_all_its_items() -> void:
	var horn: ItemDef = _with_aura("horn", [{"target": "holder", "stat": "damage_bp", "value": 15000}])
	var heroes: Array[UnitSetup] = [K.unit("hero", BIG_HP, FRONT, [horn])]
	assert_eq(_values(heroes, 0, 0), PackedStringArray(["damage: 8 (base 5, x1.5 Horn)"]), "the basic attack too")


func test_unit_stats_need_a_unit_target() -> void:
	var errors: Array[String] = []
	var data: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	data.merge({"id": "x", "auras": [{"target": "left_item", "stat": "atk_bp", "value": 20000}]}, true)
	ItemDef.read(DataReader.new(data, "x", errors))
	assert_true(errors.any(func(e: String) -> bool: return e.contains("\"atk_bp\" boosts a unit, so its target must be a unit")), str(errors))


# --- linked, holder falling, logging ---------------------------------------------------

func test_linked_aura_stops_when_its_holder_falls() -> void:
	var banner: ItemDef = _with_aura("banner", [{"target": "linked_allies", "stat": "damage_bp", "value": 20000}], 0)
	var bearer: UnitSetup = K.unit("bearer", 5, FRONT, [banner], _idle())
	var ally: UnitSetup = K.unit("ally", BIG_HP, FRONT, [_plain("sword")], _idle())
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, [_plain("spear", 5)], _idle())
	var result: FightResult = K.run([bearer, ally], [foe])
	assert_eq(_hit_amounts(result, "sword", 2), [20, 10] as Array[int], "boosted at 1s; the bearer falls that tick")
	var auras: Array[String] = []
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.AURA):
		auras.append(entry.to_text())
	assert_eq(auras, ["[0.00s] bearer · Banner aura starts: x2 damage for linked allies", "[1.00s] bearer · Banner aura ends: x2 damage for linked allies"] as Array[String])


func test_auras_survive_an_infusion_level_up() -> void:
	var drum: ItemDef = _with_aura("drum", [{"target": "adjacent_items", "stat": "crit_chance_bp", "value": 10000}])
	var sword: ItemDef = K.item("sword", {"xp_per_fire": 4, "effects": K.damage(10)})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [drum, K.equip(sword, ["stone"] as Array[String], 0, 96)], _idle())], [K.dummy("foe", BIG_HP)])
	assert_eq(result.combat_log.of_kind(LogEntry.Kind.INFUSION_LEVEL)[0].tick, 20)
	assert_true(K.entries(result, LogEntry.Kind.DAMAGE, "sword")[1].crit, "still critting after the level-up at 1s")
