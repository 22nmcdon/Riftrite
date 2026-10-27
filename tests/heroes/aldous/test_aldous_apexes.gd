extends GutTest
## Aldous's six apexes (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md
## 8d-4c; apexes.md) in real fights: each loads on its path's transformed
## kit with its taste and deed, and its snowball grows at apex: Grand
## Chorus's stronger next signatures and mana for every signature, Wellspring's
## bars past full, Long Wind's damage by distance, Singing Arrows' carried
## Tolls, The Great Bell's field of Marks, and Requiem's tolls for the fallen.

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"grand_chorus": "chorister", "wellspring": "chorister",
	"long_wind": "windcaller", "singing_arrows": "windcaller",
	"the_great_bell": "bellwarden", "requiem": "bellwarden",
}
const TEAM: Array[String] = ["brannoc", "maren", "aldous"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Aldous with Brannoc and Maren, Aldous transformed on the path of
## `apex_id`, vowed to it, and at apex if `apexed`.
func _fight(encounter_id: String, apex_id: String, apexed: bool) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("aldous")
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, {"aldous": APEXES[apex_id]} as Dictionary[String, String],
		["aldous"] as Array[String], {}, {"aldous": apex_id} as Dictionary[String, String], at_apex)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "aldous" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _applied(sim: CombatSim, status_id: String) -> Array[LogEntry]:
	return sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "aldous" and entry.status == status_id)


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("aldous", apex_id)


func test_his_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		assert_true(_content.paths[APEXES[apex_id]].apexes.has(apex), apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), 11500), "%s: +15%% HP" % apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "aldous").size(), 6)


func test_grand_chorus_lifts_every_signature() -> void:
	var vowed: CombatSim = _fight("the_pack", "grand_chorus", false)
	assert_gt(_deed(vowed, "grand_chorus"), 0, "his allies fire signatures near him")
	var sim: CombatSim = _fight("the_pack", "grand_chorus", true)
	assert_gt(_applied(sim, "grand_note").size(), 0, "Crescendo readies their next signatures")
	var spent: Array = sim.combat_log.of_kind(LogEntry.Kind.STATUS_ENDED).filter(func(entry: LogEntry) -> bool: return entry.status == "grand_note" and entry.note.contains("spent"))
	assert_gt(spent.size(), 0, "a signature spends it")
	assert_gt(_of(sim, LogEntry.Kind.MANA_GIVEN, "grand_chorus").size(), 0, "each signature gives every hero mana")


func test_wellspring_lets_bars_run_past_full() -> void:
	var vowed: CombatSim = _fight("the_pack", "wellspring", false)
	assert_gt(_deed(vowed, "wellspring"), 0, "Crescendo pours past full")
	var sim: CombatSim = _fight("the_pack", "wellspring", true)
	assert_gt(_applied(sim, "wellspring_swell").size(), 0, "signatures from past full swell Chorus")


func test_long_wind_rewards_distance() -> void:
	var vowed: CombatSim = _fight("hollow_line", "long_wind", false)
	assert_gt(_deed(vowed, "long_wind"), 0, "Maren hits from afar")
	var sim: CombatSim = _fight("hollow_line", "long_wind", true)
	assert_gt(_applied(sim, "long_wind_gust").size(), 0, "a kill from afar gusts the ranged")
	for entry: LogEntry in _applied(sim, "long_wind_gust"):
		assert_ne(entry.target, "brannoc", "ranged heroes only")


func test_singing_arrows_carry_his_toll() -> void:
	var vowed: CombatSim = _fight("hollow_line", "singing_arrows", false)
	var tolls: Array[LogEntry] = _of(vowed, LogEntry.Kind.DAMAGE, "singing_arrows")
	assert_gt(tolls.size(), 0, "every 5th ranged hit carries a Toll")
	assert_eq(_deed(vowed, "singing_arrows"), tolls.size())
	var sim: CombatSim = _fight("hollow_line", "singing_arrows", true)
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "singing_arrows").size(), tolls.size(), "every ranged hit, at apex")
	assert_gt(_applied(sim, "rising_pitch").size(), 0, "the pitch rises on each enemy")


func test_the_great_bell_names_the_field() -> void:
	var vowed: CombatSim = _fight("the_pack", "the_great_bell", false)
	var knelled: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "death_knell")
	assert_gt(knelled.size(), 0)
	assert_eq(knelled[0].end_tick - knelled[0].tick, 120, "6s with the taste")
	assert_eq(_deed(vowed, "the_great_bell"), knelled.size())
	var sim: CombatSim = _fight("the_pack", "the_great_bell", true)
	assert_gt(_applied(sim, "great_bell").size(), 0, "each toll strengthens every hero")


func test_requiem_tolls_for_the_marked_dead() -> void:
	var vowed: CombatSim = _fight("the_pack", "requiem", false)
	assert_eq(_deed(vowed, "requiem"), _of(vowed, LogEntry.Kind.DAMAGE, "requiem").reduce(func(sum: int, entry: LogEntry) -> int: return sum + entry.amount, 0), "the deed is its damage")
	var sim: CombatSim = _fight("the_pack", "requiem", true)
	var tolls: Array[LogEntry] = _of(sim, LogEntry.Kind.DAMAGE, "requiem")
	assert_gt(tolls.size(), 0, "a Marked enemy's fall tolls")
	assert_gt(_applied(sim, "requiem_toll").size(), 0, "and each toll grows the next")
