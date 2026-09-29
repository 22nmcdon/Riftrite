extends GutTest
## The sim runner (tools/sim_runner.gd, tools/sim_report.gd;
## docs/plans/rebuild-phase2-heroes-enemies.md, section 7): its formations,
## drawn formations, a small run, and the gate.

const Report = preload("res://tools/sim_report.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _named() -> Dictionary[String, Dictionary]:
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = Report.read_formations(FileAccess.get_file_as_string("res://tools/sim_formations.json"), errors)
	assert_eq(errors, [] as Array[String])
	return named


func test_the_named_formations_place_every_hero_on_the_heroes_rows() -> void:
	var named: Dictionary[String, Dictionary] = _named()
	assert_eq(named.keys(), ["guarded", "exposed", "spread", "clumped"])
	for name: String in named:
		var formation: Dictionary = named[name]
		assert_eq(formation.keys(), ["brannoc", "maren", "vell"], name)
		var hexes: Array = formation.values()
		for hex: Vector2i in hexes:
			assert_true(hex.y >= 0 and hex.y < 3 and hex.x >= 0 and hex.x < 8, "%s: %s" % [name, hex])
			assert_eq(hexes.count(hex), 1, "%s: one hero a hex" % name)


func test_formations_that_cant_be_read_are_refused() -> void:
	var errors: Array[String] = []
	Report.read_formations("[]", errors)
	Report.read_formations('{"a": {"brannoc": [3]}, "b": 4}', errors)
	assert_eq(errors, ["sim_formations.json: expected an object", "sim_formations.json (a).brannoc: expected [col, row]",
		"sim_formations.json (b): expected hero id -> [col, row]"])


func test_drawn_formations_are_legal_and_repeat_from_their_seed() -> void:
	var rocks: Array[Vector2i] = [Vector2i(3, 1)]
	var drawn: Array[Dictionary] = Report.drawn_formations(_content, rocks, 30, 4)
	assert_eq(drawn.size(), 30)
	for formation: Dictionary in drawn:
		assert_eq(formation.keys(), ["brannoc", "maren", "vell"])
		var hexes: Array = formation.values()
		for hex: Vector2i in hexes:
			assert_true(hex.y >= 0 and hex.y < 3 and hex.x >= 0 and hex.x < 8, str(hex))
			assert_eq(hexes.count(hex), 1)
			assert_ne(hex, Vector2i(3, 1), "never on a rock")
	assert_eq(Report.drawn_formations(_content, rocks, 30, 4), drawn, "the same seed draws the same")
	assert_ne(Report.drawn_formations(_content, rocks, 30, 5), drawn)


func test_a_small_run_reports_every_formation() -> void:
	var named: Dictionary[String, Dictionary] = _named()
	var report: Report.Report = Report.run_encounter(_content, "the_pack", named, 3, 2)
	assert_eq(report.rows.map(func(row: Report.Row) -> String: return row.name), ["guarded", "exposed", "spread", "clumped", "drawn #1", "drawn #2", "drawn #3"])
	assert_eq(report.named, 4)
	for row: Report.Row in report.rows:
		assert_eq([row.fights, row.lengths.size()], [2, 2], row.name)
		assert_between(row.wins, 0, 2)
		assert_eq(row.dealt.keys().size() + row.taken.keys().size() > 0, true, "%s: damage is counted" % row.name)
	var guarded: Report.Row = report.rows[0]
	var result: FightResult = CombatSim.run(Encounters.setup(_content, "the_pack", guarded.formation, 1, [] as Array[String]), _content)
	assert_eq(guarded.lengths[0], result.end_tick, "seed 1 is the first fight")
	var text: String = Report.text(_content, report)
	for expected: String in ["The Pack (the_pack): protecting the back line. 2 seeds, 4 named + 3 drawn formations", "  guarded ", "  drawn: worst",
		"  gate: ", "formations win. Median fight", "  best (", "  worst ("]:
		assert_string_contains(text, expected)


func test_the_gate_needs_a_30_point_gap() -> void:
	var report := Report.Report.new()
	for wins: int in [8, 5]:
		var row := Report.Row.new()
		row.fights = 10
		row.wins = wins
		report.rows.append(row)
	assert_eq([report.gap_points(), report.passes()], [30, true])
	report.rows[1].wins = 6
	assert_eq([report.gap_points(), report.passes()], [20, false])
	assert_eq(report.winning(), 2, "8 and 6 of 10 are at least half")
	report.rows[1].wins = 4
	assert_eq(report.winning(), 1)
	assert_eq(Report.Report.median([5, 1, 3] as Array[int]), 3)
	assert_eq(Report.seconds(551), "27.5s")


# --- the tactics report (phase 3b) ----------------------------------------------

func test_the_tactic_variants() -> void:
	var names: Array = Report.tactic_variants(_content).map(func(row: Report.TacticRow) -> String: return Report.variant_name(_content, row))
	assert_eq(names, ["no tactics", "Brannoc on Casters first", "Maren on Casters first", "Vell on Casters first", "Brannoc on Hold your ground",
		"Maren on Hold your ground", "Vell on Hold your ground", "Vell on Wait to heal"])


func test_a_small_tactics_run() -> void:
	var named: Dictionary[String, Dictionary] = _named()
	var report: Report.TacticReport = Report.run_tactics(_content, "witch_circle", named, 1, 2)
	assert_eq([report.formations, report.seeds, report.rows.size()], [5, 2, 8])
	for row: Report.TacticRow in report.rows:
		assert_eq(row.fights, 10)
		assert_eq(row.formation_wins.size(), 5)
		assert_eq(row.formation_wins.reduce(func(sum: int, wins: int) -> int: return sum + wins, 0), row.wins)
	var plain: Report.Report = Report.run_encounter(_content, "witch_circle", named, 1, 2)
	assert_eq(report.base().formation_wins, plain.rows.map(func(row: Report.Row) -> int: return row.wins), "no tactics is the placement report's own fights")
	var maren_holds: Report.TacticRow = report.rows[5]
	var guarded: Dictionary[String, Vector2i] = {}
	guarded.assign(named["guarded"])
	var errors: Array[String] = []
	var result: FightResult = CombatSim.run(Encounters.setup(_content, "witch_circle", guarded, 1, errors, {"maren": "hold_ground"} as Dictionary[String, String]), _content)
	var won: int = 0 if result.outcome == FightResult.Outcome.DEFEAT else 1
	result = CombatSim.run(Encounters.setup(_content, "witch_circle", guarded, 2, errors, {"maren": "hold_ground"} as Dictionary[String, String]), _content)
	won += 0 if result.outcome == FightResult.Outcome.DEFEAT else 1
	assert_eq(maren_holds.formation_wins[0], won, "a variant fights with its tactic")
	var text: String = Report.tactics_text(_content, report)
	for expected: String in ["Witch Circle (witch_circle), tactics: 5 formations x 2 seeds. No tactics win", "  Maren on Hold your ground ", "formations"]:
		assert_string_contains(text, expected)


func _tactic_row(formation_wins: Array[int], hero_id: String = "maren", tactic_id: String = "hold_ground") -> Report.TacticRow:
	var row := Report.TacticRow.new()
	row.hero_id = hero_id
	row.tactic_id = tactic_id
	row.formation_wins = formation_wins
	row.wins = formation_wins.reduce(func(sum: int, wins: int) -> int: return sum + wins, 0)
	row.fights = formation_wins.size() * 2
	return row


func test_helping_and_hurting_count_formations() -> void:
	var base: Report.TacticRow = _tactic_row([2, 0, 1, 2] as Array[int], "", "")
	var row: Report.TacticRow = _tactic_row([2, 2, 0, 1] as Array[int])
	assert_eq([row.helps(base), row.hurts(base)], [1, 2])
	assert_eq([base.helps(base), base.hurts(base)], [0, 0])


## Two encounters: Maren's hold helps in both; Brannoc's casters-first helps
## in one and hurts in the other; Vell's wait changes nothing.
func test_the_summary_answers_the_plans_two_questions() -> void:
	var reports: Array[Report.TacticReport] = []
	for e: int in 2:
		var report := Report.TacticReport.new()
		report.encounter = _content.encounters[_content.encounter_ids[e]]
		report.rows = [_tactic_row([1, 0] as Array[int], "", ""), _tactic_row([2, 1] as Array[int]), _tactic_row([1, 0] as Array[int], "vell", "wait_to_heal"),
			_tactic_row(([2, 0] as Array[int]) if e == 0 else ([0, 0] as Array[int]), "brannoc", "casters_first")] as Array[Report.TacticRow]
		reports.append(report)
	var text: String = Report.tactics_summary(_content, reports)
	assert_string_contains(text, "%-30s helps in 2, hurts in 0, no change in 0; changes 4 formation outcomes" % "Maren on Hold your ground")
	assert_string_contains(text, "%-30s helps in 0, hurts in 0, no change in 2; changes 0 formation outcomes" % "Vell on Wait to heal")
	assert_string_contains(text, "Every tactic changes an outcome: no (Wait to heal)")
	assert_string_contains(text, "%-30s helps in 1, hurts in 1, no change in 0" % "Brannoc on Casters first")
	assert_true(text.ends_with("None is right everywhere: no (Maren on Hold your ground)"), "only the one that helps in both")
