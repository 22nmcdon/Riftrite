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
