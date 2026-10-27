extends GutTest
## Aldous's paths (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md 8d-4b;
## rebuild-heroes.md section 8e) in real fights: Chorister's Shared Breath,
## Chorus, and Crescendo, Windcaller's Tailwind, High Wind, and Gale,
## Bellwarden's Toll the Hour and Death Knell, Peal as each one's habit, and
## each deed moving only with its taste.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["brannoc", "maren", "aldous"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Aldous with Brannoc and Maren, Aldous on `path_id` ("" for his
## base kit; transformed if `transformed`).
func _fight(encounter_id: String, path_id: String, transformed: bool) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {}
	if not path_id.is_empty():
		vows["aldous"] = path_id
	var stages: Array[String] = []
	if transformed:
		stages.append("aldous")
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, stages)
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


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("aldous", path_id)


func test_aldous_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "aldous"), "his three paths are built")
	for path_id: String in ["chorister", "windcaller", "bellwarden"]:
		var kit: UnitDef = _content.paths[path_id].transformed_kit
		var habit: PartDef = null
		for part: PartDef in kit.passives:
			if part.id == "peal":
				habit = part
		assert_not_null(habit, "%s keeps Peal as a habit" % path_id)
		assert_eq(habit.ability.effects[0].every, 8, path_id)


func test_his_base_kit_fills_no_deed() -> void:
	var sim: CombatSim = _fight("the_pack", "", false)
	for path_id: String in ["chorister", "windcaller", "bellwarden"]:
		assert_eq(_deed(sim, path_id), 0, "%s needs its taste" % path_id)


func test_chorister_shares_his_breath() -> void:
	var vowed: CombatSim = _fight("the_pack", "chorister", false)
	var shared: Array[LogEntry] = _of(vowed, LogEntry.Kind.MANA_GIVEN, "shared_breath")
	assert_gt(shared.size(), 0, "each Peal gives the emptiest ally mana")
	var given: int = shared.reduce(func(sum: int, entry: LogEntry) -> int: return sum + entry.amount, 0)
	assert_eq(_deed(vowed, "chorister"), given / Mana.SCALE, "the deed counts it (up to 15 each, what fits in the bar)")
	var sim: CombatSim = _fight("the_pack", "chorister", true)
	assert_gt(_of(sim, LogEntry.Kind.MANA_GIVEN, "chorus").size(), 0, "his gains are shared")
	assert_gt(_of(sim, LogEntry.Kind.MANA_GIVEN, "crescendo").size(), 0, "Crescendo")
	assert_eq(_of(sim, LogEntry.Kind.FIRE, "peal").size(), 0, "Peal is a habit now")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "peal").size(), 0, "but it still peals, every 8th Toll")


func test_windcaller_carries_the_ranged() -> void:
	var vowed: CombatSim = _fight("hollow_line", "windcaller", false)
	assert_gt(_deed(vowed, "windcaller"), 0, "Maren shoots from afar under Tailwind")
	assert_eq(_deed(_fight("hollow_line", "", false), "windcaller"), 0, "not without it")
	var sim: CombatSim = _fight("hollow_line", "windcaller", true)
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "gale").size(), 0, "Gale")
	for entry: LogEntry in _of(sim, LogEntry.Kind.STATUS_APPLIED, "peal"):
		assert_ne(entry.target, "brannoc", "the habit reaches ranged allies only")


func test_bellwarden_marks_with_each_toll() -> void:
	var vowed: CombatSim = _fight("the_pack", "bellwarden", false)
	var marks: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "toll_the_hour")
	assert_gt(marks.size(), 0, "every 4th Toll Marks")
	assert_eq(marks[0].end_tick - marks[0].tick, 40, "for 2s")
	assert_eq(_deed(vowed, "bellwarden"), marks.size(), "the deed counts his Marks")
	var sim: CombatSim = _fight("the_pack", "bellwarden", true)
	var tolled: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "toll_the_hour")
	assert_eq(tolled[0].end_tick - tolled[0].tick, 60, "every Toll, for 3s")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "death_knell").size(), 0, "Death Knell")
	assert_gt(_deed(sim, "bellwarden"), _deed(vowed, "bellwarden"))
