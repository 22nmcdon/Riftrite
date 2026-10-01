extends GutTest
## The run report (tools/run_report.gd, run by tools/run_runner.gd), run small.

const Report = preload("res://tools/run_report.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func test_every_combination_of_vows() -> void:
	var combos: Array[Dictionary] = Report.vow_combinations(_run.content)
	assert_eq(combos.size(), 27)
	assert_eq(combos[0], {"brannoc": "hearthwall", "maren": "deadeye", "vell": "lanternbearer"})
	assert_eq(combos[26], {"brannoc": "last_watch", "maren": "volley", "vell": "vigil_keeper"})


func test_a_small_report() -> void:
	var seeds: Array[int] = [1, 2, 3]
	var lines: Array = Report.play_many(_run, seeds, false)
	assert_eq(lines.size(), 3)
	for line: Report.RunLine in lines:
		assert_eq(line.errors, [] as Array[String], "seed %d" % line.seed_value)
		assert_ne(line.outcome, RunState.Outcome.NONE, "each run ends")
		assert_eq(line.vows, Report.vow_combinations(_run.content)[line.seed_value % 27])
		assert_false(line.fights.is_empty())
		assert_eq(line.transformed_on.size(), 3)
		assert_eq(line.nodes_shown.get("camp", 0), line.nodes_taken.values().reduce(func(sum: int, taken: int) -> int: return sum + taken, 0), "Camp shown every day a node was taken")
	var again: Report.RunLine = Report.play(_run, 2, false)
	assert_eq([again.outcome, again.day, again.fights], [lines[1].outcome, lines[1].day, lines[1].fights], "a run is its seed's")
	var text: String = Report.summary(_run, lines)
	assert_string_contains(text, "Runs: 3 (the simple bot")
	assert_string_contains(text, "First transformation")
	assert_string_contains(text, "Runs with errors: 0")
	assert_string_contains(text, "Picks per run by layer: hero")
	assert_string_contains(text, "Nodes per run: Camp shown")


func test_the_engine_report() -> void:
	var lines: Array[Report.RunLine] = []
	lines.assign(Report.play_many(_run, [4, 5] as Array[int], false))
	for line: Report.RunLine in lines:
		assert_false(line.engines.is_empty(), "seed %d's fights had engines" % line.seed_value)
		for name: String in line.engines:
			var stats: Array = line.engines[name]
			assert_lte(stats[4], stats[5], "%s added no more than its team" % name)
			assert_lte(stats[2], stats[1], "%s: chained fires are fires" % name)
	var text: String = Report.engines_summary(lines)
	assert_string_starts_with(text, "Engines (the heroes' sources")
	assert_string_contains(text, "Held but never fired")
