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
	texts[ContentDb.PATHS_FILE] = "[]"
	texts[ContentDb.TACTICS_FILE] = JSON.stringify([{"id": "stand", "name": "Stand", "text": "Stands.", "kind": "hold_ground", "release_hexes": 2, "heroes": ["warden", "ranger"]}])
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


# --- the Act 1 encounters in data/encounters.json ---------------------------------

## Brannoc in front of the other two (the sim runner's "guarded").
const GUARDED: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}


## Each encounter's enemies (section 6's table), as enemy id -> how many.
const ROSTERS: Dictionary = {
	"pup_warren": {"rift_pup": 6},
	"ash_nest": {"ashling": 3, "rift_pup": 2},
	"the_pack": {"rift_hound": 3},
	"moth_cloud": {"cinder_moth": 3, "rift_pup": 2},
	"hollow_line": {"hollow_archer": 3},
	"bog_crossing": {"bog_lurker": 1, "rift_pup": 3},
	"sentinel_gate": {"rift_worn_sentinel": 1, "hollow_archer": 2},
	"cairn_road": {"cairn_guardian": 1, "rift_hound": 2},
	"witch_circle": {"gloam_witch": 1, "rift_worn_sentinel": 1, "cinder_moth": 1},
	# Phase 5: a Hunt's packs, the harder fights, the elites, and the boss.
	"stray_pups": {"rift_pup": 4},
	"lone_hounds": {"rift_hound": 2},
	"hounds_and_archers": {"rift_hound": 2, "hollow_archer": 2},
	"lurker_and_ashlings": {"bog_lurker": 1, "ashling": 3},
	"sentinel_and_moths": {"rift_worn_sentinel": 1, "cinder_moth": 2},
	"witch_and_pups": {"gloam_witch": 1, "rift_pup": 4},
	"guardian_and_witch": {"cairn_guardian": 1, "gloam_witch": 1},
	"the_hunt": {"hound_alpha": 1, "hunt_hound": 2},
	"witch_coven": {"gloam_totem": 1, "gloam_witch": 2, "rift_worn_sentinel": 1},
	"cairn_watch": {"cairn_guardian": 1, "hollow_archer": 2},
	"old_mother_ash": {"old_mother_ash": 1, "ash_hound": 2},
}
## Phase 2's nine, tuned by their enemies' numbers rather than a scale.
## Phase 2's nine (the easier tier since phase 5; scaled since playtest
## gate 3, rebuild-phase5-run.md).
const BASIC: Array[String] = ["pup_warren", "ash_nest", "the_pack", "moth_cloud", "hollow_line", "bog_crossing", "sentinel_gate", "cairn_road", "witch_circle"]


func test_the_act_1_encounters_are_the_plans() -> void:
	var content: ContentDb = ContentDb.load_dir("res://data")
	assert_eq(content.encounter_ids, BASIC + ["stray_pups", "lone_hounds", "hounds_and_archers", "lurker_and_ashlings", "sentinel_and_moths", "witch_and_pups",
		"guardian_and_witch", "the_hunt", "witch_coven", "cairn_watch", "old_mother_ash"])
	for encounter_id: String in content.encounter_ids:
		var encounter: EncounterDef = content.encounters[encounter_id]
		var counts: Dictionary = {}
		for placed: EncounterDef.Placed in encounter.enemies:
			counts[placed.enemy] = counts.get(placed.enemy, 0) + 1
		assert_eq(counts, ROSTERS[encounter_id], encounter_id)
		assert_eq(encounter.act, 1, encounter_id)
		if BASIC.has(encounter_id):
			assert_eq(encounter.tier, "easier", encounter_id)
		assert_between(encounter.scale_bp, 5000, 35000, "%s: a scale the tuning set (phase 6 raised the later fights to x1.6 of phase 2's, and its second pass a little more)" % encounter_id)
		assert_false(encounter.tests.is_empty(), encounter_id)
	assert_eq((content.encounters["hollow_line"] as EncounterDef).rocks.size(), 2, "archers behind 2 rocks")


func test_every_day_before_the_boss_offers_at_least_two_encounters() -> void:
	var content: ContentDb = ContentDb.load_dir("res://data")
	for day: int in range(1, 7):
		var offered: Array = content.encounter_ids.filter(func(encounter_id: String) -> bool: return (content.encounters[encounter_id] as EncounterDef).days.has(day))
		assert_gte(offered.size(), 2, "day %d: %s" % [day, offered])
	for encounter_id: String in content.encounter_ids:
		var encounter: EncounterDef = content.encounters[encounter_id]
		assert_eq(encounter.days.has(7), encounter.tier == "boss", "day 7 is the boss's, and only hers: %s" % encounter_id)


func test_every_act_1_encounter_builds_a_fight_that_plays_out() -> void:
	var content: ContentDb = ContentDb.load_dir("res://data")
	for encounter_id: String in content.encounter_ids:
		var errors: Array[String] = []
		var fight: FightSetup = Encounters.setup(content, encounter_id, GUARDED, 1, errors)
		assert_eq(errors, [] as Array[String], encounter_id)
		assert_eq(fight.validate(content), [] as Array[String], encounter_id)
		var encounter: EncounterDef = content.encounters[encounter_id]
		var placed: Array = fight.enemies.map(func(unit: UnitSetup) -> Array: return [unit.def.id, Vector2i(unit.col, unit.row)])
		assert_eq(placed, encounter.enemies.map(func(enemy: EncounterDef.Placed) -> Array: return [enemy.enemy, enemy.hex]), "%s: its enemies stand where it says" % encounter_id)
		assert_eq(fight.rocks, encounter.rocks, encounter_id)
		var result: FightResult = CombatSim.run(fight, content)
		assert_eq(result.errors, [] as Array[String], encounter_id)
		assert_lt(result.combat_log.entries.back().tick, content.tuning.tie_ticks, "%s ends before 180s (a tie can still happen: both sides falling together)" % encounter_id)
