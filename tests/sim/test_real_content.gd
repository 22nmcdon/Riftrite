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
	assert_eq([db.hero_ids.size(), db.enemy_ids.size(), db.encounter_ids.size()], [8, 12, 12])
	assert_gt(db.item_ids.size(), 20)


func test_every_encounter_builds_a_valid_fight() -> void:
	var db: ContentDb = K.content()
	for encounter_id: String in db.encounter_ids:
		var hero: UnitSetup = SetupBuilder.hero(db, "brannoc", 0, UnitSetup.Row.FRONT, [] as Array[LoadoutEntry])
		var setup: FightSetup = FightSetup.make([hero] as Array[UnitSetup], SetupBuilder.encounter_units(db, encounter_id))
		assert_eq(setup.validate(db), [] as Array[String], encounter_id)


func test_hero_slots_and_stats_follow_rank() -> void:
	var db: ContentDb = K.content()
	assert_eq(db.tuning.ability_slots, [2, 3, 3, 4] as Array[int], "abilities by rank C to S")
	assert_eq(db.tuning.passive_slots, [1, 1, 2, 3] as Array[int], "passives by rank C to S")
	var at_b: UnitSetup = SetupBuilder.hero(db, "wren", 1, UnitSetup.Row.FRONT, [] as Array[LoadoutEntry])
	assert_eq(at_b.rank, 1)
	var sim := CombatSim.new(FightSetup.make([at_b] as Array[UnitSetup], SetupBuilder.encounter_units(db, "hound_pack")), db)
	assert_eq(sim.units[0].max_hp, 350, "280 HP x1.25 at rank B")


func test_encounter_units_are_numbered() -> void:
	var ids: Array[String] = []
	for unit: UnitSetup in SetupBuilder.encounter_units(K.content(), "hound_pack"):
		ids.append(unit.id)
	assert_eq(ids, ["rift_hound_1", "rift_hound_2", "rift_hound_3"] as Array[String])


func test_enemy_layouts_are_checked() -> void:
	var enemies: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	enemies[0]["items"] = [{"item": "moon_blade"}, {"item": "longspear", "essences": ["ember", "frost", "storm"]}, {"item": "rift_claw", "xp": 50}]
	var errors: Array[String] = _texts_with(ContentDb.ENEMIES_FILE, enemies).errors
	assert_true(_has(errors, "unknown item \"moon_blade\""), str(errors))
	assert_true(_has(errors, "\"longspear\" has 3 essences; an infusion holds at most 2"), str(errors))
	assert_true(_has(errors, "has 50 infusion XP but no infusion"), str(errors))


func test_encounters_are_checked() -> void:
	var encounters: Array = [{"id": "x", "name": "X", "act": 3, "units": [{"enemy": "dragon"}]}]
	var errors: Array[String] = _texts_with(ContentDb.ENCOUNTERS_FILE, encounters).errors
	assert_true(_has(errors, "unknown enemy \"dragon\""), str(errors))
	assert_true(_has(errors, "act 3 has no Rift Collapse numbers"), str(errors))
	var elite: Array = [{"id": "x", "name": "X", "kind": "elite", "units": [{"enemy": "rift_pup"}]}]
	assert_true(_has(_texts_with(ContentDb.ENCOUNTERS_FILE, elite).errors, "an elite encounter needs a mechanic (name, text, counter)"))
	elite[0]["mechanic"] = {"name": "Nips", "text": "It nips."}
	assert_true(_has(_texts_with(ContentDb.ENCOUNTERS_FILE, elite).errors, "missing required key \"counter\""))
	elite[0]["mechanic"]["counter"] = "Don't be nipped."
	assert_false(_has(_texts_with(ContentDb.ENCOUNTERS_FILE, elite).errors, "mechanic"), "a full mechanic is fine")
	elite[0]["kind"] = "boss"
	elite[0].erase("mechanic")
	assert_true(_has(_texts_with(ContentDb.ENCOUNTERS_FILE, elite).errors, "a boss encounter needs a mechanic"))


## Every elite and boss says what it asks of the player
## (docs/plans/fight-questions-and-readability.md, section 2).
func test_every_elite_and_boss_has_a_mechanic() -> void:
	var db: ContentDb = K.content()
	var found: int = 0
	for encounter_id: String in db.encounter_ids:
		var encounter: EncounterDef = db.encounters[encounter_id]
		if encounter.kind == "normal":
			continue
		found += 1
		for text: String in [encounter.mechanic_name, encounter.mechanic_text, encounter.mechanic_counter]:
			assert_false(text.is_empty(), encounter_id)
	assert_eq(found, 4, "three elites and the boss")
	assert_eq(db.encounters["hound_alpha"].mechanic_name, "The Hunt")


## The Hound Alpha (The Hunt): its bite hunts the weakest foe, and it
## frenzies below half HP, which a real fight reaches and logs.
func test_the_hound_alpha_hunts_the_weakest_and_frenzies() -> void:
	var db: ContentDb = K.content()
	var alpha: EnemyDef = db.enemies["hound_alpha"]
	assert_eq(alpha.items[0].item_id, "alphas_bite")
	assert_eq(db.items["alphas_bite"].effects[0].target, EffectDef.Target.ENEMY_LOWEST_HP)
	assert_eq([alpha.phases.size(), alpha.phases[0].name, alpha.phases[0].below_hp_bp], [1, "Blood Frenzy", 5000])
	assert_eq(db.encounters["hound_alpha"].units[0].enemy_id, "hound_alpha")
	var party: BalanceRun.Party = BalanceRun.load_parties(db).list[1]
	var setup: FightSetup = FightSetup.make(BalanceRun.party_units(db, party), SetupBuilder.encounter_units(db, "hound_alpha"), 3, 1)
	var result: FightResult = CombatSim.run(setup, db)
	var bites: int = 0
	var frenzy: int = 0
	for entry: LogEntry in result.combat_log.entries:
		if entry.kind == LogEntry.Kind.FIRE and entry.source_item == "alphas_bite":
			bites += 1
		if entry.kind == LogEntry.Kind.PHASE and entry.note == "Blood Frenzy":
			frenzy += 1
	assert_gte(bites, 2, "the Alpha bites (every 4s)")
	assert_eq(frenzy, 1, "and frenzies once")


func test_real_content_fights_replay_identically() -> void:
	var db: ContentDb = K.content()
	var party: BalanceRun.Party = BalanceRun.load_parties(db).list[1]
	var logs: Array[String] = []
	for i: int in 2:
		var setup: FightSetup = FightSetup.make(BalanceRun.party_units(db, party), SetupBuilder.encounter_units(db, "witch_coven"), 3, 1)
		logs.append(CombatSim.run(setup, db).combat_log.to_text())
	assert_eq(logs[0], logs[1])


## The roster (docs/plans/items-and-clarity.md, section 3): 28 shared
## Commons, Uncommons, and Rares (8 weapons, 11 abilities, 9 passives), 24
## hero Epics (3 per hero, each hero's own), and 6 Legendaries (one per
## path), enemy-only items on top. Weapons fire every 1-2s; abilities are
## moves on 6-15s cooldowns. 1-3 keywords each, and every keyword has
## shared items.
func test_the_item_roster() -> void:
	var db: ContentDb = K.content()
	var guild: Array[ItemDef] = []
	for item_id: String in db.item_ids:
		if not db.items[item_id].enemy_only:
			guild.append(db.items[item_id])
	assert_eq(guild.size(), 58, "28 shared, 24 hero Epics, 6 Legendaries")
	var shared_slots: Array[int] = [0, 0, 0]
	var epics_by_hero: Dictionary[String, int] = {}
	var paths: Array[String] = []
	for item: ItemDef in guild:
		assert_between(item.keywords.size(), 1, ItemDef.MAX_KEYWORDS, "%s has keywords" % item.id)
		assert_eq(item.rarity == "epic", not item.hero.is_empty(), "%s: Epics, and only Epics, belong to a hero" % item.id)
		if item.legendary != null:
			paths.append(item.legendary.path)
		elif item.hero.is_empty():
			shared_slots[item.slot] += 1
		else:
			epics_by_hero[item.hero] = epics_by_hero.get(item.hero, 0) + 1
		if item.slot == ItemDef.Slot.BASIC_ATTACK:
			assert_between(item.cooldown_ticks, 20, 40, "%s: a weapon fires every 1-2s" % item.id)
		elif item.slot == ItemDef.Slot.ABILITY:
			assert_between(item.cooldown_ticks, 120, 300, "%s: an ability is a move on a 6-15s cooldown" % item.id)
	assert_eq(shared_slots, [8, 11, 9] as Array[int], "shared weapons, abilities, passives")
	for hero_id: String in db.hero_ids:
		assert_eq(epics_by_hero.get(hero_id, 0), 3, "%s has 3 Epics" % hero_id)
	paths.sort()
	assert_eq(paths, ["bonded", "boss", "devour", "essence", "hits", "martyr"] as Array[String], "one Legendary per path")
	for keyword_id: String in db.keyword_ids:
		var shared: int = guild.filter(func(item: ItemDef) -> bool: return item.hero.is_empty() and item.legendary == null and item.keywords.has(keyword_id)).size()
		assert_gte(shared, 2, "%s has shared items" % keyword_id)
	for tag: String in ["ranged", "melee", "magic", "healing", "defense", "tool", "charm", "tome", "food", "weapon"]:
		assert_gte(guild.filter(func(item: ItemDef) -> bool: return item.tags.has(tag)).size(), 2, "at least 2 %s items" % tag)
