extends GutTest
## The draft content in data/: it loads, every encounter builds a valid fight,
## and fights on real content replay identically.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _texts_with(file_name: String, data: Variant) -> ContentDb:
	var texts: Dictionary[String, String] = {}
	for name: String in ContentDb.FILES:
		texts[name] = FileAccess.get_file_as_string("res://data".path_join(name))
	texts[file_name] = JSON.stringify(data)
	return ContentDb.load_texts(texts)


func _has(errors: Array[String], expected: String) -> bool:
	return errors.any(func(message: String) -> bool: return message.contains(expected))


func test_draft_content_counts() -> void:
	var db: ContentDb = K.content()
	assert_eq([db.hero_ids.size(), db.enemy_ids.size(), db.encounter_ids.size()], [8, 11, 12])
	assert_gt(db.item_ids.size(), 20)


func test_every_encounter_builds_a_valid_fight() -> void:
	var db: ContentDb = K.content()
	for encounter_id: String in db.encounter_ids:
		var hero: UnitSetup = SetupBuilder.hero(db, "brannoc", 0, UnitSetup.Row.FRONT, [] as Array[LoadoutEntry])
		var setup: FightSetup = FightSetup.make([hero] as Array[UnitSetup], SetupBuilder.encounter_units(db, encounter_id))
		assert_eq(setup.validate(db), [] as Array[String], encounter_id)


func test_hero_slots_and_stats_follow_rank() -> void:
	var db: ContentDb = K.content()
	var at_b: UnitSetup = SetupBuilder.hero(db, "wren", 1, UnitSetup.Row.FRONT, [] as Array[LoadoutEntry])
	assert_eq([at_b.slots, at_b.rank], [5, 1], "4 slots at C, +1 per rank")
	var sim := CombatSim.new(FightSetup.make([at_b] as Array[UnitSetup], SetupBuilder.encounter_units(db, "hound_pack")), db)
	assert_eq(sim.units[0].max_hp, 350, "280 HP x1.25 at rank B")


func test_encounter_units_are_numbered() -> void:
	var ids: Array[String] = []
	for unit: UnitSetup in SetupBuilder.encounter_units(K.content(), "hound_pack"):
		ids.append(unit.id)
	assert_eq(ids, ["rift_hound_1", "rift_hound_2", "rift_hound_3"] as Array[String])


func test_enemy_layouts_are_checked() -> void:
	var enemies: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	enemies[0]["items"] = [{"item": "moon_blade"}, {"item": "hearth_knife", "essences": ["ember", "frost"]}, {"item": "rift_claw", "xp": 50}]
	var errors: Array[String] = _texts_with(ContentDb.ENEMIES_FILE, enemies).errors
	assert_true(_has(errors, "unknown item \"moon_blade\""), str(errors))
	assert_true(_has(errors, "\"hearth_knife\" has 2 essences but only 1 socket(s)"), str(errors))
	assert_true(_has(errors, "has 50 infusion XP but no infusion"), str(errors))


func test_encounters_are_checked() -> void:
	var encounters: Array = [{"id": "x", "name": "X", "act": 3, "units": [{"enemy": "dragon"}]}]
	var errors: Array[String] = _texts_with(ContentDb.ENCOUNTERS_FILE, encounters).errors
	assert_true(_has(errors, "unknown enemy \"dragon\""), str(errors))
	assert_true(_has(errors, "act 3 has no Rift Collapse numbers"), str(errors))


func test_real_content_fights_replay_identically() -> void:
	var db: ContentDb = K.content()
	var party: BalanceRun.Party = BalanceRun.load_parties(db).list[1]
	var logs: Array[String] = []
	for i: int in 2:
		var setup: FightSetup = FightSetup.make(BalanceRun.party_units(db, party), SetupBuilder.encounter_units(db, "witch_coven"), 3, 1)
		logs.append(CombatSim.run(setup, db).combat_log.to_text())
	assert_eq(logs[0], logs[1])


## The slice's item targets (docs/plans/slice-content.md): 60 items the
## guild can get, enemy-only items on top; more Small than Medium than
## Large; enough Epics for alloys; items for every hero's tags.
func test_slice_item_roster() -> void:
	var db: ContentDb = K.content()
	var guild: Array[ItemDef] = []
	for item_id: String in db.item_ids:
		if not db.items[item_id].enemy_only:
			guild.append(db.items[item_id])
	assert_eq(guild.size(), 60)
	var sizes: Array[int] = [0, 0, 0, 0]
	var epics: int = 0
	for item: ItemDef in guild:
		sizes[item.size] += 1
		if item.rarity == "epic":
			epics += 1
			assert_eq(db.tuning.socket_count(item), 2, "%s has two sockets" % item.id)
	assert_gt(sizes[1], sizes[2], "more Small than Medium")
	assert_gt(sizes[2], sizes[3], "more Medium than Large")
	assert_gte(epics, 6)
	for tag: String in ["ranged", "melee", "magic", "healing", "defense", "tool", "charm", "tome", "food", "weapon"]:
		assert_gte(guild.filter(func(item: ItemDef) -> bool: return item.tags.has(tag)).size(), 3, "at least 3 %s items" % tag)
