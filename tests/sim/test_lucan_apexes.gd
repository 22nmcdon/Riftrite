extends GutTest
## Lucan's six apexes (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## 8f-4; apexes.md) in real fights: each loads on its path's transformed kit
## with its taste and deed, and what it does at apex: Thousand Faces' growing
## crowd of copies that burst, True Reflection's copies that cast, Unseen
## Host's sharper strikes from the dark, Night Veil's confusion, Grand
## Puppeteer's dance that never stops, and Marionette's borrowed enemies.

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"thousand_faces": "mirrorwright", "true_reflection": "mirrorwright",
	"unseen_host": "veilweaver", "night_veil": "veilweaver",
	"grand_puppeteer": "puppeteer", "marionette": "puppeteer",
}
const TEAM: Array[String] = ["brannoc", "maren", "lucan"]

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


## A fight of Lucan with `team`, transformed on the path of `apex_id`,
## vowed to it, and at apex if `apexed`; the enemies at `scale_bp` of their own.
func _fight(encounter_id: String, apex_id: String, apexed: bool, scale_bp: int = 10000, team: Array[String] = TEAM) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("lucan")
	var encounter: EncounterDef = _content.encounters[encounter_id]
	var keep: int = encounter.scale_bp
	encounter.scale_bp = FixedMath.apply_bp(keep, scale_bp)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, {"lucan": APEXES[apex_id]} as Dictionary[String, String],
		["lucan"] as Array[String], {}, {"lucan": apex_id} as Dictionary[String, String], at_apex)
	encounter.scale_bp = keep
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String, unit_id: String = "lucan") -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == unit_id and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("lucan", apex_id)


func test_his_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), 11500), apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "lucan").size(), 6)
	assert_eq(_content.apexes["marionette"].apex_kit.signature.id, "marionette")
	var habit: Array = _content.apexes["marionette"].apex_kit.passives.filter(func(part: PartDef) -> bool: return part.id == "dance_of_strings")
	assert_eq(habit.size(), 1, "Dance of Strings becomes a habit")


func test_thousand_faces() -> void:
	var vowed: CombatSim = _fight("cairn_road", "thousand_faces", false)
	var reflected: Array[LogEntry] = _of(vowed, LogEntry.Kind.SUMMON, "reflection")
	assert_eq(reflected[0].end_tick - reflected[0].tick, 13 * 20, "the taste: 1s longer")
	assert_gt(_deed(vowed, "thousand_faces"), 0, "his copies' damage")
	var sim: CombatSim = _fight("cairn_road", "thousand_faces", true, 15000)
	var shares: Array = sim.units.filter(func(unit: UnitState) -> bool: return unit.mirror_of == sim.unit_by_id("lucan") and unit.def.id == "lucan_copy") \
		.map(func(unit: UnitState) -> int: return unit.def.stats.get_stat(UnitStats.Stat.MGK))
	assert_gt(shares.max(), shares.min(), "later copies take more of his stats")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "shattering").size(), 0, "a destroyed copy bursts")


func test_true_reflection() -> void:
	var sim: CombatSim = _fight("cairn_road", "true_reflection", true, 15000, ["brannoc", "maren", "lucan"] as Array[String])
	var copies: Array[LogEntry] = _of(sim, LogEntry.Kind.SUMMON, "hall_of_mirrors")
	assert_eq(copies[0].end_tick - copies[0].tick, 10 * 20)
	var cast: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.FIRE).filter(func(entry: LogEntry) -> bool: return entry.source_unit.begins_with("maren_copy") and entry.source_ability == "volley_shot" or entry.source_unit.begins_with("brannoc_copy") and entry.source_ability == "hold_the_line")
	assert_gt(cast.size(), 0, "copies of allies cast their signature")
	assert_gt(_deed(sim, "true_reflection"), 0, "his copies of allies' damage")


func test_unseen_host() -> void:
	var sim: CombatSim = _fight("cairn_road", "unseen_host", true)
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "hush").filter(func(entry: LogEntry) -> bool: return entry.status == "unseen_host").size(), 0, "each strike from Stealth sharpens every ally's crits")
	assert_eq(_of(sim, LogEntry.Kind.STATUS_APPLIED, "hush").filter(func(entry: LogEntry) -> bool: return entry.status == "silence")[0].end_tick - _of(sim, LogEntry.Kind.STATUS_APPLIED, "hush")[0].tick, 20, "Silence for 1s")
	assert_gt(_deed(sim, "unseen_host"), 0)


func test_night_veil() -> void:
	var sim: CombatSim = _fight("cairn_road", "night_veil", true, 15000)
	var confused: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "night_veil")
	assert_gt(confused.size(), 0, "enemies that lose their target are confused")
	assert_true(sim.combat_log.of_kind(LogEntry.Kind.TARGET).any(func(entry: LogEntry) -> bool: return entry.note == "confused"), "and turn on their own")
	assert_eq(_deed(sim, "night_veil"), sim.combat_log.of_kind(LogEntry.Kind.TARGET).filter(func(entry: LogEntry) -> bool: return entry.lost_to_stealth).size())


func test_grand_puppeteer() -> void:
	var sim: CombatSim = _fight("cairn_road", "grand_puppeteer", true)
	var copy: UnitState = sim.units.filter(func(unit: UnitState) -> bool: return unit.def.id == "lucan_copy")[0]
	assert_true(sim.content.statuses.has("grand_dance"))
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "dance_of_strings").filter(func(entry: LogEntry) -> bool: return entry.status == "grand_dance").size(), 0, "Dance doubles it")
	assert_gt(sim.summons_joined[0], 0)
	assert_not_null(copy)
	assert_gt(_deed(sim, "grand_puppeteer"), 0, "attacks summons make in the dance")


func test_marionette() -> void:
	var vowed: CombatSim = _fight("cairn_road", "marionette", false)
	assert_eq(_of(vowed, LogEntry.Kind.STATUS_APPLIED, "puppet_thread").size(), 1, "the taste: once a fight, the first enemy below 30%")
	assert_eq(_deed(vowed, "marionette"), 3000, "seconds it fought for him")
	var sim: CombatSim = _fight("cairn_road", "marionette", true)
	var held: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "marionette")
	assert_gt(held.size(), 0, "Marionette takes an enemy")
	assert_true(sim.combat_log.of_kind(LogEntry.Kind.TARGET).any(func(entry: LogEntry) -> bool: return entry.note == "taken over"))
