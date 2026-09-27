extends GutTest
## Loadouts (docs/plans/fun-redesign.md, section 2): items go in basic-attack,
## ability, and passive slots; "the holder's other items" replaces item
## adjacency; row_allies replaces linked allies. And every hero's innate
## (docs/plans/heroes-and-deeds.md).

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK
const BIG_HP: int = 10000000


func _idle() -> ItemDef:
	return K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)})


func _item_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var full: Dictionary = K.DEFAULT_ITEM.duplicate(true)
	full.merge(data, true)
	full["id"] = "x"
	for key: String in data:
		if data[key] == null:
			full.erase(key)
	ItemDef.read(DataReader.new(full, "x", errors))
	return errors


func _has(errors: Array[String], expected: String) -> bool:
	return errors.any(func(message: String) -> bool: return message.contains(expected))


# --- slot types -----------------------------------------------------------------------

func test_every_item_names_its_slot() -> void:
	assert_true(_has(_item_errors({"slot": null}), "missing required key \"slot\""))
	assert_true(_has(_item_errors({"slot": "trinket"}), "unknown value \"trinket\""))
	var aura: Array = [{"target": "holder", "stat": "def_bp", "value": 11000}]
	assert_true(_has(_item_errors({"slot": "passive", "auras": aura}), "a passive never fires, so its effects need event triggers"), "a passive's effects answer events")
	assert_true(_has(_item_errors({"slot": "passive", "effects": null, "cooldown_ms": null}), "a passive needs auras"))
	assert_eq(_item_errors({"slot": "passive", "effects": null, "cooldown_ms": null, "auras": aura}), [] as Array[String])
	assert_true(_has(_item_errors({"effects": null, "auras": aura}), "an ability needs effects"))
	assert_true(_has(_item_errors({"slot": "basic_attack", "effects": null, "auras": aura}), "a basic attack needs effects"))
	assert_true(K.item("bow", {"slot": "basic_attack"}).auto_attack, "a basic-attack item replaces the hero's own")
	assert_false(K.item("tome").auto_attack)
	assert_true(_has(_item_errors({"size": 2}), "unknown key \"size\""), "items have no size any more")
	assert_true(_has(_item_errors({"backup": {"auras": aura}}), "unknown key \"backup\""), "nor backup modes")


func test_the_real_items_sort_into_slots() -> void:
	var counts: Array[int] = [0, 0, 0]
	for item_id: String in K.content().item_ids:
		var def: ItemDef = K.content().items[item_id]
		counts[def.slot] += 1
		assert_eq(def.auto_attack, def.slot == ItemDef.Slot.BASIC_ATTACK, item_id)
	assert_eq(counts[ItemDef.Slot.BASIC_ATTACK], 20, "the weapons (17 the guild can get, 3 enemy-only)")
	assert_gte(counts[ItemDef.Slot.PASSIVE], 8, "enough passives to fill the passive slots")


func test_a_unit_holds_one_basic_attack_item() -> void:
	var bow: ItemDef = K.item("bow", {"slot": "basic_attack"})
	var errors: Array[String] = []
	K.unit("hero", 100, FRONT, [bow, K.item("bow2", {"slot": "basic_attack"})]).validate(K.content(), errors)
	assert_true(_has(errors, "has 2 basic-attack items; the limit is one"), str(errors))
	var sim := CombatSim.new(K.fight([K.unit("hero", 100, FRONT, [bow, K.item("tome")])], [K.dummy("foe", 100)]), K.content())
	var ids: Array[String] = []
	for item: ItemState in sim.heroes[0].items:
		ids.append(item.def.id)
	assert_eq(ids, ["bow", "tome"] as Array[String], "the bow replaces the built-in basic attack")
	assert_eq([sim.heroes[0].items[0].slot, sim.heroes[0].items[1].slot], [0, 1], "slots are loadout places")


# --- the holder's other items, and row allies --------------------------------------------

func test_holder_items_reach_the_holders_other_items_only() -> void:
	var drum: ItemDef = K.item("drum", {"slot": "passive", "effects": null, "cooldown_ms": null,
		"auras": [{"target": "holder_items", "stat": "damage_bp", "value": 20000}]})
	var sword: ItemDef = K.item("sword", {"effects": K.damage(10)})
	var other: ItemDef = K.item("other", {"effects": K.damage(10)})
	var sim := CombatSim.new(K.fight([K.unit("hero", 100, FRONT, [drum, sword], _idle()), K.unit("ally", 100, FRONT, [other], _idle())], [K.dummy("foe", 100)]), K.content())
	var hero: UnitState = sim.heroes[0]
	assert_eq(hero.items[2].effects[0].value.final, 20, "the holder's sword doubles")
	assert_eq(hero.items[0].effects[0].value.final, 2, "and their built-in basic attack (1 x2)")
	assert_eq(sim.heroes[1].items[1].effects[0].value.final, 10, "another hero's items don't")


func test_a_charge_reaches_the_holders_other_items() -> void:
	var whet: ItemDef = K.item("whet", {"name": "Whet", "cooldown_ms": 1000, "effects": [{"trigger": "on_fire", "type": "charge", "amount_ms": 500, "target": "holder_items"}]})
	var axe: ItemDef = K.item("axe", {"name": "Axe", "cooldown_ms": 5000, "effects": K.damage(1)})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [whet, axe], _idle())], [K.dummy("foe", BIG_HP)])
	var charged: Array[String] = []
	for entry: LogEntry in K.entries(result, LogEntry.Kind.CHARGE, "whet").slice(0, 2):
		charged.append(entry.note)
	assert_eq(charged, ["Basic Attack", "Axe"] as Array[String], "every other item the holder has, never itself")
	var first_axe: int = K.ticks_of(K.entries(result, LogEntry.Kind.FIRE, "axe"))[0]
	assert_lt(first_axe, 100, "the axe fires sooner than its 5s cooldown")


func test_row_allies_reach_the_others_in_the_holders_row() -> void:
	var chalk: ItemDef = K.item("chalk", {"effects": [{"trigger": "on_fire", "type": "shield", "amount": 7, "target": "row_allies"}]})
	var result: FightResult = K.run([K.unit("hero", BIG_HP, FRONT, [chalk], _idle()), K.unit("left", BIG_HP, FRONT, [], _idle()),
		K.unit("behind", BIG_HP, BACK, [], _idle())], [K.dummy("foe", BIG_HP)])
	var shielded: Array[String] = K.targets_of(K.entries(result, LogEntry.Kind.SHIELD, "chalk").slice(0, 1))
	assert_eq(shielded, ["left"] as Array[String], "the same row, not the holder, not the back row")
	var errors: Array[String] = []
	EffectDef.read(DataReader.new({"trigger": "on_fire", "type": "heal", "amount": 1, "target": "linked_allies"}, "e", errors))
	assert_true(_has(errors, "unknown value \"linked_allies\""), "linked targets are gone")


# --- innates ------------------------------------------------------------------------

func test_every_hero_has_an_innate() -> void:
	for hero_id: String in K.content().hero_ids:
		var def: HeroDef = K.content().heroes[hero_id]
		assert_false(def.innate_name.is_empty(), hero_id)
		assert_false(def.innate_text.is_empty(), hero_id)
		assert_gt(def.innate.size(), 0, hero_id)


func test_innate_data_is_checked() -> void:
	var hero: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/heroes.json"))[0]
	hero["innate"] = {"name": "X", "text": "?", "parts": [{"key": "a", "kind": "basic_attack", "basic_attack": K.DEFAULT_BASIC.merged({"id": "b"})}]}
	var errors: Array[String] = []
	HeroDef.read(DataReader.new(hero, "hero", errors))
	assert_true(_has(errors, "an innate can't replace the basic attack"), str(errors))
	hero["innate"] = {"name": "X", "text": "?", "parts": []}
	errors.clear()
	HeroDef.read(DataReader.new(hero, "hero", errors))
	assert_true(_has(errors, "an innate needs parts"), str(errors))


func _real_fight(hero_id: String, foes: Array[UnitSetup]) -> FightResult:
	var hero: UnitSetup = SetupBuilder.hero(K.content(), hero_id, 0, FRONT, [] as Array[LoadoutEntry])
	var ally: UnitSetup = K.unit("ally", 300, FRONT, [], _idle())
	return CombatSim.run(FightSetup.make([hero, ally], foes, 3, 1), K.content())


func test_innates_act_in_the_fight_credited_by_name() -> void:
	var lantern: Array[LogEntry] = K.entries(_real_fight("vell", [K.unit("foe", BIG_HP, FRONT, [K.item("claw", {"cooldown_ms": 2000, "effects": K.damage(20, "enemy_random")})], _idle())]), LogEntry.Kind.HEAL)
	assert_true(lantern.any(func(e: LogEntry) -> bool: return e.source_item_name == "Lantern Vigil"), "Vell heals every 5s")
	var toll: Array[LogEntry] = _real_fight("hesk", [K.dummy("foe", BIG_HP)]).combat_log.of_kind(LogEntry.Kind.SHIELD)
	assert_eq(K.targets_of(toll.slice(0, 2)), ["hesk", "ally"] as Array[String], "Hesk shields everyone as the fight begins")
	assert_eq(K.ticks_of(toll.slice(0, 1)), [0] as Array[int])
	var flash: Array[LogEntry] = _real_fight("ysolde", [K.dummy("foe", BIG_HP), K.dummy("foe2", BIG_HP)]).combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED)
	var at_ten: Array[LogEntry] = flash.filter(func(e: LogEntry) -> bool: return e.source_item_name == "Flashpoint")
	assert_eq(K.ticks_of(at_ten), [200, 200] as Array[int], "Ysolde's Flashpoint: once, at 10s, on every enemy")


func test_brannocs_hearthguard_catches_a_falling_ally() -> void:
	var claw: ItemDef = K.item("claw", {"cooldown_ms": 1000, "effects": K.damage(40, "enemy_lowest_hp")})
	var result: FightResult = _real_fight("brannoc", [K.unit("foe", BIG_HP, FRONT, [claw], _idle())])
	var caught: Array[LogEntry] = K.entries(result, LogEntry.Kind.SHIELD).filter(func(e: LogEntry) -> bool: return e.source_item_name == "Hearthguard")
	assert_gt(caught.size(), 0, "a Shield when someone drops below 40%")
	assert_lte(caught.size(), 2, "once per ally")


func test_wrens_opening_flurry_speeds_her_basic_attack_early() -> void:
	var sim := CombatSim.new(FightSetup.make([SetupBuilder.hero(K.content(), "wren", 0, FRONT, [] as Array[LoadoutEntry])], [K.dummy("foe", BIG_HP)], 1, 1), K.content())
	var attack: ItemState = sim.heroes[0].items[0]
	assert_true(attack.def.is_basic_attack)
	assert_lt(attack.cooldown_ticks, sim.heroes[0].items[0].def.cooldown_ticks, "faster during the first 6 seconds")
	for i: int in 130:
		sim.step()
	assert_eq(attack.cooldown_ticks, attack.def.cooldown_ticks, "back to normal after")
