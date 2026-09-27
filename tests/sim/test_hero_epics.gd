extends GutTest
## Hero Epics (docs/plans/items-and-clarity.md, section 3): anyone can hold
## one, but on its own hero it adds its parts, credited "<hero>'s own".

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT: UnitSetup.Row = UnitSetup.Row.FRONT


func _entry(item_id: String) -> LoadoutEntry:
	var entry := LoadoutEntry.new()
	entry.item_id = item_id
	return entry


func _sim_with(hero_id: String, item_ids: Array[String]) -> CombatSim:
	var entries: Array[LoadoutEntry] = []
	for item_id: String in item_ids:
		entries.append(_entry(item_id))
	var hero: UnitSetup = SetupBuilder.hero(K.content(), hero_id, 1, FRONT, entries)
	return CombatSim.new(FightSetup.make([hero] as Array[UnitSetup], [K.dummy("foe", 100000)], 1, 1), K.content())


func _item(sim: CombatSim, hero_id: String, item_id: String) -> ItemState:
	for item: ItemState in sim.unit_by_id(hero_id).items:
		if item.def.id == item_id:
			return item
	return null


func test_an_epics_aura_works_only_on_its_hero() -> void:
	var own: ItemState = _item(_sim_with("brannoc", ["tower_shield"] as Array[String]), "brannoc", "tower_shield")
	var other: ItemState = _item(_sim_with("hesk", ["tower_shield"] as Array[String]), "hesk", "tower_shield")
	assert_true(own.describe_values()[0].contains("x1.3 Brannoc's own"), str(own.describe_values()))
	assert_false(other.describe_values()[0].contains("own"), "on Hesk it's a plain Tower Shield")


func test_an_epics_grant_and_ability_come_with_their_hero() -> void:
	var odo: CombatSim = _sim_with("odo", ["wyrdglass_orb"] as Array[String])
	var maren: CombatSim = _sim_with("maren", ["wyrdglass_orb"] as Array[String])
	assert_eq(_item(odo, "odo", "wyrdglass_orb").effects.size(), _item(maren, "maren", "wyrdglass_orb").effects.size() + 1, "the storm strikes twice on Odo")
	var granted: Array[String] = []
	for sourced: SourcedEffect in _item(odo, "odo", "wyrdglass_orb").effects:
		granted.append(sourced.granted_by)
	assert_true(granted.has("Odo's own"), str(granted))
	var brannoc: CombatSim = _sim_with("brannoc", ["watchmans_horn"] as Array[String])
	var names: Array[String] = []
	for item: ItemState in brannoc.unit_by_id("brannoc").items:
		names.append(item.def.name)
	assert_true(names.has("Alarm (Brannoc's own)"), str(names))
	var hesk: CombatSim = _sim_with("hesk", ["watchmans_horn"] as Array[String])
	for item: ItemState in hesk.unit_by_id("hesk").items:
		assert_false(item.def.name.contains("Alarm"), "no alarm on Hesk")


func test_two_copies_add_their_parts_once() -> void:
	var sim: CombatSim = _sim_with("wren", ["gale_blades", "gale_blades"] as Array[String])
	var parts: int = 0
	for part: SpecializationDef.Part in sim.unit_by_id("wren").spec_parts:
		if part.key == "own_gale_blades":
			parts += 1
	assert_eq(parts, 1)


func test_an_epics_bonus_is_logged_with_its_hero() -> void:
	var result: FightResult = CombatSim.run(_sim_with("brannoc", ["tower_shield"] as Array[String]).setup, K.content())
	assert_string_contains(result.combat_log.to_text(), "Brannoc's own aura starts")


func test_hero_epic_fields_are_checked() -> void:
	var base: Dictionary = {"id": "x", "name": "X", "slot": "ability", "keywords": ["ward"], "rarity": "epic", "xp_per_fire": 1, "cooldown_ms": 8000,
		"effects": [{"trigger": "on_fire", "type": "shield", "amount": 5, "target": "self"}]}
	var parts: Array = [{"key": "own_x", "kind": "aura", "target": "holder", "stat": "def_bp", "value": 11000}]
	var cases: Dictionary = {
		"a hero's Epic needs \"hero_parts\"": {"hero": "brannoc"},
		"only Epics belong to a hero": {"hero": "brannoc", "hero_parts": parts, "rarity": "rare"},
		"\"hero_parts\" needs a \"hero\"": {"hero_parts": parts},
		"a hero's Epic can't replace the basic attack": {"hero": "brannoc", "hero_parts": [{"key": "own_x", "kind": "basic_attack",
			"basic_attack": {"id": "y", "name": "Y", "cooldown_ms": 1000, "effects": [{"trigger": "on_fire", "type": "damage", "amount": 1, "target": "enemy_front"}]}}]},
	}
	for expected: String in cases:
		var data: Dictionary = base.duplicate(true)
		data.merge(cases[expected], true)
		var errors: Array[String] = []
		ItemDef.read(DataReader.new(data, "x", errors))
		assert_true(errors.any(func(message: String) -> bool: return message.contains(expected)), "%s: %s" % [expected, str(errors)])
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var items: Array = JSON.parse_string(texts[ContentDb.ITEMS_FILE])
	var stray: Dictionary = base.duplicate(true)
	stray.merge({"hero": "nobody", "hero_parts": parts}, true)
	items.append(stray)
	texts[ContentDb.ITEMS_FILE] = JSON.stringify(items)
	assert_true(ContentDb.load_texts(texts).errors.any(func(message: String) -> bool: return message.contains("unknown hero \"nobody\"")))
