extends GutTest
## Building fights from encounters and formations (Encounters;
## docs/plans/rebuild-phase2-heroes-enemies.md, section 2).

const Units = preload("res://tests/sim/test_units_content.gd")

const FORMATION: Dictionary[String, Vector2i] = {"ranger": Vector2i(3, 0), "warden": Vector2i(3, 2)}


func _content(scale_bp: int = 10000) -> ContentDb:
	var texts: Dictionary[String, String] = {}
	for file_name: String in [ContentDb.TUNING_FILE, ContentDb.STATUSES_FILE]:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var caller: Dictionary = Units.kit({"signature": {"id": "call", "name": "Call", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "brood", "placement": "adjacent"}]}})
	var brood: Dictionary = Units.kit({"signature": {"id": "split", "name": "Split", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "pup", "placement": "adjacent"}]}})
	texts[ContentDb.HEROES_FILE] = JSON.stringify([Units.hero("warden"), Units.hero("ranger"), Units.hero("mender")])
	texts[ContentDb.ENEMIES_FILE] = JSON.stringify([Units.enemy("pup"), Units.enemy("caller", {"kit": caller}), Units.enemy("brood", {"kit": brood}), Units.enemy("idle")])
	texts[ContentDb.ENCOUNTERS_FILE] = JSON.stringify([
		Units.encounter("den", [{"enemy": "caller", "hex": [3, 5]}, {"enemy": "pup", "hex": [2, 4]}], {"rocks": [[4, 3]], "scale_bp": scale_bp}),
		Units.encounter("nest", [{"enemy": "caller", "hex": [2, 5]}, {"enemy": "caller", "hex": [5, 5]}, {"enemy": "brood", "hex": [4, 6]}]),
	])
	var db: ContentDb = ContentDb.load_texts(texts)
	assert(db.is_valid(), str(db.errors))
	return db


func test_a_fight_from_an_encounter_and_a_formation() -> void:
	var errors: Array[String] = []
	var content: ContentDb = _content()
	var fight: FightSetup = Encounters.setup(content, "den", FORMATION, 7, errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(fight.validate(content), [] as Array[String])
	assert_eq(fight.units().map(func(unit: UnitSetup) -> Array: return [unit.id, unit.side, Vector2i(unit.col, unit.row)]), [
		["warden", EffectSource.Team.HEROES, Vector2i(3, 2)], ["ranger", EffectSource.Team.HEROES, Vector2i(3, 0)],
		["caller", EffectSource.Team.ENEMIES, Vector2i(3, 5)], ["pup", EffectSource.Team.ENEMIES, Vector2i(2, 4)],
	], "heroes in heroes.json's order, whatever the formation's; the encounter's enemies in its order")
	assert_eq([fight.rocks, fight.seed_value, fight.act], [[Vector2i(4, 3)], 7, 1])
	assert_eq(fight.summon_kits.map(func(unit: UnitDef) -> String: return unit.id), ["brood", "pup"], "summons, and their summons")
	assert_eq(fight.units()[2].def, content.enemies["caller"].kit, "unscaled, the kit itself")
	var result: FightResult = CombatSim.run(fight, content)
	assert_eq(result.errors, [] as Array[String])
	assert_true(result.combat_log.of_kind(LogEntry.Kind.SUMMON).any(func(entry: LogEntry) -> bool: return entry.target.begins_with("pup")), "the brood's own summons work")


func test_a_kit_summoned_by_several_units_is_listed_once() -> void:
	var errors: Array[String] = []
	var content: ContentDb = _content()
	var fight: FightSetup = Encounters.setup(content, "nest", FORMATION, 1, errors)
	assert_eq(fight.summon_kits.map(func(unit: UnitDef) -> String: return unit.id), ["brood", "pup"])
	assert_eq(fight.validate(content), [] as Array[String])


func test_scale_multiplies_enemy_hp_and_atk() -> void:
	var errors: Array[String] = []
	var content: ContentDb = _content(15000)
	var fight: FightSetup = Encounters.setup(content, "den", FORMATION, 1, errors)
	var caller: UnitDef = fight.units()[2].def
	assert_eq([caller.stats.get_stat(UnitStats.Stat.HP), caller.stats.get_stat(UnitStats.Stat.ATK), caller.stats.get_stat(UnitStats.Stat.SPEED)], [150, 15, 2])
	assert_eq(content.enemies["caller"].kit.stats.get_stat(UnitStats.Stat.HP), 100, "the content's kit is untouched")
	assert_eq(fight.summon_kits[0].stats.get_stat(UnitStats.Stat.HP), 150, "summons are scaled too")
	assert_eq(fight.units()[0].def.stats.get_stat(UnitStats.Stat.HP), 100, "heroes aren't")
	assert_eq(caller.signature, content.enemies["caller"].kit.signature)


func test_scaling_keeps_phases() -> void:
	var kit: UnitDef = K_kit()
	var scaled: UnitDef = Encounters.scaled(kit, 20000)
	assert_eq(scaled.phases, kit.phases)
	assert_eq(scaled.stats.get_stat(UnitStats.Stat.HP), 200)


func K_kit() -> UnitDef:
	var errors: Array[String] = []
	var data: Dictionary = Units.kit({"phases": [{"id": "molt", "name": "Molt", "below_hp_bp": 5000, "targeting": "farthest"}]})
	var kit: UnitDef = UnitDef.read(DataReader.new(data, "kit", errors), "boss", "Boss")
	assert(errors.is_empty(), str(errors))
	return kit


func test_unknown_encounters_and_heroes_are_refused() -> void:
	var errors: Array[String] = []
	var content: ContentDb = _content()
	assert_null(Encounters.setup(content, "lair", FORMATION, 1, errors))
	assert_eq(errors, ["unknown encounter \"lair\""] as Array[String])
	errors.clear()
	var formation: Dictionary[String, Vector2i] = {"warden": Vector2i(3, 2), "stranger": Vector2i(4, 1)}
	assert_null(Encounters.setup(content, "den", formation, 1, errors))
	assert_eq(errors, ["unknown hero \"stranger\""] as Array[String])


func test_the_setup_checks_the_formation() -> void:
	var errors: Array[String] = []
	var content: ContentDb = _content()
	var formation: Dictionary[String, Vector2i] = {"warden": Vector2i(3, 4), "ranger": Vector2i(2, 4)}
	var fight: FightSetup = Encounters.setup(content, "den", formation, 1, errors)
	assert_eq(fight.validate(content), ["warden at (3, 4) is outside its side's zone", "ranger at (2, 4) is outside its side's zone", "pup at (2, 4) shares its hex with ranger"] as Array[String])
