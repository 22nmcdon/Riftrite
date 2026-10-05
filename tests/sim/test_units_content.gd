extends GutTest
## heroes.json, enemies.json, and encounters.json: reading them, and the checks
## across files (docs/plans/rebuild-phase2-heroes-enemies.md, section 2).
## Each test loads the real tuning and statuses with made-up units.


func _texts(heroes: Array, enemies: Array, encounters: Array) -> Dictionary[String, String]:
	var texts: Dictionary[String, String] = {}
	for file_name: String in [ContentDb.TUNING_FILE, ContentDb.STATUSES_FILE]:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[ContentDb.HEROES_FILE] = JSON.stringify(heroes)
	texts[ContentDb.ENEMIES_FILE] = JSON.stringify(enemies)
	texts[ContentDb.ENCOUNTERS_FILE] = JSON.stringify(encounters)
	texts[ContentDb.TACTICS_FILE] = "[]"
	texts[ContentDb.PATHS_FILE] = "[]"
	texts[ContentDb.ENEMY_UPGRADES_FILE] = "[]"
	return texts


static func kit(extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"stats": {"hp": 100, "atk": 10, "speed": 2},
		"basic_attack": {"id": "strike", "name": "Strike", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}}
	data.merge(extra, true)
	return data


static func hero(id: String, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"id": id, "name": id.capitalize(), "title": "the test", "role": "damage", "kit": kit()}
	data.merge(extra, true)
	return data


static func enemy(id: String, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"id": id, "name": id.capitalize(), "archetype": "swarm", "threat": "Bites", "kit": kit()}
	data.merge(extra, true)
	return data


static func encounter(id: String, placed: Array, extra: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {"id": id, "name": id.capitalize(), "tests": "something", "act": 1, "days": [1], "enemies": placed}
	data.merge(extra, true)
	return data


func _load(heroes: Array, enemies: Array, encounters: Array) -> ContentDb:
	return ContentDb.load_texts(_texts(heroes, enemies, encounters))


func _assert_error(db: ContentDb, expected: String) -> void:
	assert_true(db.errors.any(func(message: String) -> bool: return message.contains(expected)), "expected '%s' in %s" % [expected, db.errors])


func test_units_and_encounters_load() -> void:
	var db: ContentDb = _load([hero("warden", {"role": "tank"}), hero("ranger")],
		[enemy("pup"), enemy("hound", {"archetype": "flanker", "threat": "Pounces"})],
		[encounter("pack", [{"enemy": "hound", "hex": [2, 4]}, {"enemy": "pup", "hex": [3, 5]}], {"rocks": [[3, 3]], "days": [2, 3], "scale_bp": 11000})])
	assert_eq(db.errors, [] as Array[String])
	assert_eq([db.hero_ids, db.enemy_ids, db.encounter_ids], [["warden", "ranger"], ["pup", "hound"], ["pack"]])
	var warden: HeroDef = db.heroes["warden"]
	assert_eq([warden.name, warden.title, warden.role, warden.kit.id, warden.kit.name], ["Warden", "the test", HeroDef.Role.TANK, "warden", "Warden"], "the kit takes the hero's id and name")
	var hound: EnemyDef = db.enemies["hound"]
	assert_eq([hound.archetype, hound.threat, hound.kit.id], [EnemyDef.Archetype.FLANKER, "Pounces", "hound"])
	var pack: EncounterDef = db.encounters["pack"]
	assert_eq([pack.tests, pack.act, pack.days, pack.rocks, pack.scale_bp], ["something", 1, [2, 3] as Array[int], [Vector2i(3, 3)] as Array[Vector2i], 11000])
	assert_eq(pack.enemies.map(func(placed: EncounterDef.Placed) -> Array: return [placed.enemy, placed.hex]), [["hound", Vector2i(2, 4)], ["pup", Vector2i(3, 5)]])


func test_entries_are_checked() -> void:
	var cases: Array = [
		[[hero("a", {"role": "healer"})], [], [], "role"],
		[[hero("a", {"kit": kit({"id": "a"})})], [], [], "unknown key \"id\""],
		[[], [enemy("a", {"archetype": "boss"})], [], "archetype"],
		[[], [enemy("a", {"threat": ""})], [], "threat"],
		[[hero("a")], [enemy("a")], [], "\"a\" is already a hero's id"],
		[[hero("a"), hero("a")], [], [], "duplicate id \"a\""],
		[[], [enemy("pup")], [encounter("e", [])], "an encounter needs enemies"],
		[[], [enemy("pup")], [encounter("e", [{"enemy": "pup", "hex": [2, 4]}], {"days": [0]})], "days count from 1"],
		[[], [enemy("pup")], [encounter("e", [{"enemy": "pup", "hex": [2]}])], "hex: expected [col, row]"],
		[[], [enemy("pup")], [encounter("e", [{"enemy": "pup", "hex": [2, 4]}], {"scale_bp": 0})], "scale_bp"],
	]
	for case: Array in cases:
		var db: ContentDb = _load(case[0], case[1], case[2])
		assert_eq(db.errors.size(), 1, "%s" % [db.errors])
		_assert_error(db, case[3])


func test_links_across_files_are_checked() -> void:
	var summoner: Dictionary = kit({"signature": {"id": "call", "name": "Call", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "imp", "placement": "hexes", "hexes": [[9, 6]]}]}})
	var poisoner: Dictionary = kit({"basic_attack": {"id": "strike", "name": "Strike", "cooldown_ms": 1000,
		"effects": [{"type": "apply_status", "status": "venom", "target": "target"}, {"type": "apply_status", "status": "engaged", "target": "target"}]}})
	var db: ContentDb = _load([hero("a", {"kit": poisoner})], [enemy("pup", {"kit": summoner})], [
		encounter("far", [{"enemy": "pup", "hex": [2, 4]}], {"act": 4}),
		encounter("wrong", [{"enemy": "wolf", "hex": [2, 4]}, {"enemy": "pup", "hex": [2, 2]}, {"enemy": "pup", "hex": [9, 5]}]),
		encounter("crowded", [{"enemy": "pup", "hex": [3, 3]}, {"enemy": "pup", "hex": [3, 4]}, {"enemy": "pup", "hex": [3, 4]}], {"rocks": [[3, 3], [8, 8]]}),
	])
	assert_eq(db.errors, [
		"heroes.json (a): unknown status \"venom\"",
		"heroes.json (a): names \"engaged\", which only the Engage trait sets",
		"enemies.json (pup): summons \"imp\", which isn't an enemy",
		"enemies.json (pup): summons onto (9, 6), off the board",
		"encounters.json (far): tuning has no Rift Collapse numbers for act 4",
		"encounters.json (wrong): unknown enemy \"wolf\"",
		"encounters.json (wrong): pup at (2, 2) is outside the enemies' zone",
		"encounters.json (wrong): pup at (9, 5) is off the board",
		"encounters.json (crowded): a rock at (8, 8) is off the board",
		"encounters.json (crowded): pup at (3, 3) is outside the enemies' zone",
		"encounters.json (crowded): pup at (3, 3) shares its hex with a rock",
		"encounters.json (crowded): pup at (3, 4) shares its hex with pup",
	] as Array[String])
