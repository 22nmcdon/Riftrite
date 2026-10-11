extends GutTest
## Edric's six apexes (phase 8 part 5, docs/plans/rebuild-phase8-severine-
## edric.md 8e-3c; apexes.md) in real fights: each loads on its path's
## transformed kit with its taste and deed, and what it does at apex: Bastion
## of Saints' growing Hallow on everyone and Hallowed Ground, Reforged Ward's
## new Shields, Golden Aegis's Shields for the shards held, Choir of Wards'
## mana and strength, and Evensong's Shields on every signature. Collector of
## Debts and Golden Aegis's run snowballs are the run's
## (tests/run/test_tithe.gd).

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"bastion_of_saints": "aegis", "reforged_ward": "aegis",
	"golden_aegis": "tithe_collector", "collector_of_debts": "tithe_collector",
	"choir_of_wards": "psalmist", "evensong": "psalmist",
}
const TEAM: Array[String] = ["brannoc", "maren", "edric"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Edric with Brannoc and Maren, Edric transformed on the path of
## `apex_id`, vowed to it, and at apex if `apexed`, holding `shards`.
func _fight(encounter_id: String, apex_id: String, apexed: bool, shards: int = 0) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("edric")
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, {"edric": APEXES[apex_id]} as Dictionary[String, String],
		["edric"] as Array[String], {}, {"edric": apex_id} as Dictionary[String, String], at_apex)
	assert_eq(errors, [] as Array[String])
	setup.shards = shards
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "edric" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _applied(sim: CombatSim, status_id: String) -> Array[LogEntry]:
	return sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "edric" and entry.status == status_id)


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("edric", apex_id)


func test_his_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		assert_true(_content.paths[APEXES[apex_id]].apexes.has(apex), apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), 11500), apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "edric").size(), 6)
	assert_not_null(_content.apexes["golden_aegis"].grows, "Golden Aegis grows the team's max HP")
	assert_true(_content.apexes["golden_aegis"].grows.team)
	assert_eq(_content.apexes["collector_of_debts"].apex_tithe.per_standing, 3)


func test_bastion_of_saints_wards_everyone_more_each_time() -> void:
	var vowed: CombatSim = _fight("the_pack", "bastion_of_saints", false)
	var hallows: Array[LogEntry] = _of(vowed, LogEntry.Kind.SHIELD, "hallow")
	assert_gt(_deed(vowed, "bastion_of_saints"), 0, "Hallow's Shield")
	var first: Array[LogEntry] = hallows.filter(func(entry: LogEntry) -> bool: return entry.tick == hallows[0].tick)
	assert_eq(first.size(), 2, "the taste reaches the 2 lowest")
	var sim: CombatSim = _fight("the_pack", "bastion_of_saints", true)
	var to_maren: Array[LogEntry] = _of(sim, LogEntry.Kind.SHIELD, "hallow").filter(func(entry: LogEntry) -> bool: return entry.target == "maren")
	assert_gt(to_maren.size(), 1, "every ally, every 3s")
	assert_gt(to_maren[1].amount, to_maren[0].amount, "each bigger than the last")
	assert_gt(_applied(sim, "hallowed_ground").size(), 0, "Hallowed Ground")
	assert_gt(_of(sim, LogEntry.Kind.SHIELD, "sanctuary").size(), 0, "Sanctuary is a habit")


func test_reforged_ward_wards_again() -> void:
	var vowed: CombatSim = _fight("the_pack", "reforged_ward", false)
	assert_gt(_deed(vowed, "reforged_ward"), 0, "Reforge's Shield")
	var sim: CombatSim = _fight("the_pack", "reforged_ward", true)
	assert_gt(_of(sim, LogEntry.Kind.SHIELD, "reforge").size(), _of(vowed, LogEntry.Kind.SHIELD, "reforge").size(), "more often at apex")


func test_golden_aegis_wards_with_the_shards_held() -> void:
	var poor: CombatSim = _fight("the_pack", "golden_aegis", false)
	assert_eq(_deed(poor, "golden_aegis"), 0, "no shards held, no gilding")
	var rich: CombatSim = _fight("the_pack", "golden_aegis", false, 30)
	var gilded: Array[LogEntry] = _of(rich, LogEntry.Kind.SHIELD, "gilded_ward")
	assert_true(gilded.size() > 0 and gilded.all(func(entry: LogEntry) -> bool: return entry.amount == 10), "1 for every 3 of 30 shards")
	assert_eq(_deed(rich, "golden_aegis"), gilded.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0))
	var apex: CombatSim = _fight("the_pack", "golden_aegis", true, 30)
	var shields: Array[LogEntry] = _of(apex, LogEntry.Kind.SHIELD, "collection").filter(func(entry: LogEntry) -> bool: return entry.target == "maren")
	assert_eq(shields[0].amount, FixedMath.apply_bp(apex.unit_by_id("maren").max_hp, 800) + 60, "8% and 2 a shard")


func test_choir_of_wards_sings_strength() -> void:
	var sim: CombatSim = _fight("cairn_road", "choir_of_wards", true)
	assert_gt(_of(sim, LogEntry.Kind.MANA_GIVEN, "offering").size(), 0, "a breaking Shield gives mana")
	assert_gt(_applied(sim, "choir").size(), 0, "and strength")


func test_evensong_answers_every_signature() -> void:
	var vowed: CombatSim = _fight("the_pack", "evensong", false)
	assert_gt(_deed(vowed, "evensong"), 0, "an ally's signature gives them a Shield")
	var sim: CombatSim = _fight("the_pack", "evensong", true)
	var songs: Array[LogEntry] = _of(sim, LogEntry.Kind.SHIELD, "evensong")
	assert_gt(songs.size(), _of(vowed, LogEntry.Kind.SHIELD, "evensong").size(), "every ally at apex")
