extends GutTest
## The run report (tools/run_report.gd, run by tools/run_runner.gd), run small.

const Report = preload("res://tools/run_report.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func test_every_combination_of_vows() -> void:
	var combos: Array[Dictionary] = Report.vow_combinations(_run.content)
	assert_eq(Report.teams(_run.content).size(), 20, "every three of six heroes (phase 8 part 4)")
	assert_eq(combos.size(), 20 * 27)
	assert_eq(combos[0], {"brannoc": "hearthwall", "maren": "deadeye", "vell": "lanternbearer"}, "the old three first, in the old order")
	assert_eq(combos[1], {"brannoc": "hearthwall", "maren": "deadeye", "garrow": "aegisfang"}, "the teams take turns")
	assert_eq(combos[19], {"garrow": "aegisfang", "tamsin": "nightblade", "aldous": "chorister"})
	assert_eq(combos[20], {"brannoc": "ironbrand", "maren": "trapper", "vell": "wardweaver"}, "then each team's next vows, 13 on")
	assert_eq(combos[40], {"brannoc": "last_watch", "maren": "volley", "vell": "vigil_keeper"}, "so 3 turns give each hero each path")
	var seen: Dictionary = {}
	for turn: int in 27:
		seen[combos[turn * 20]] = true
	assert_eq(seen.size(), 27, "a team's 27 turns are all its vows")
	assert_eq(Report.vow_combinations(_run.content, HeroTeam.DEFAULT).size(), 27, "one team's")


func test_a_small_report() -> void:
	var seeds: Array[int] = [1, 2, 3]
	var lines: Array = Report.play_many(_run, seeds, "simple")
	assert_eq(lines.size(), 3)
	for line: Report.RunLine in lines:
		assert_eq(line.errors, [] as Array[String], "seed %d" % line.seed_value)
		assert_ne(line.outcome, RunState.Outcome.NONE, "each run ends")
		assert_eq(line.vows, Report.vow_combinations(_run.content)[line.seed_value % (20 * 27)])
		assert_false(line.fights.is_empty())
		assert_eq(line.transformed_on.size(), 3)
		assert_eq(line.nodes_shown.get("camp", 0), line.nodes_taken.values().reduce(func(sum: int, taken: int) -> int: return sum + taken, 0), "Camp shown every day a node was taken")
	var again: Report.RunLine = Report.play(_run, 2, "simple")
	assert_eq([again.outcome, again.day, again.fights], [lines[1].outcome, lines[1].day, lines[1].fights], "a run is its seed's")
	var text: String = Report.summary(_run, lines)
	assert_string_contains(text, "Runs: 3 (the simple bot")
	assert_string_contains(text, "First transformation")
	assert_string_contains(text, "By hero (runs on the team, won")
	assert_string_contains(text, "Runs with errors: 0")
	assert_string_contains(text, "Picks per run by layer: hero")
	assert_string_contains(text, "Nodes per run: Camp shown")
	# Every fight's habits, for sizing the rift learns (8c-6c).
	for line: Report.RunLine in lines:
		var counted: int = line.fights.filter(func(fight: Array) -> bool: return _run.content.encounters[fight[0]].tier != "hunt").size()
		assert_eq(line.habits.get("casts", []).size(), counted, "each fight's measures")
	assert_string_contains(text, "The rift learns (each habit's measure")
	assert_string_contains(text, "Mana and signatures      casts")


func test_a_drafted_team_and_the_by_hero_lines() -> void:
	# Phase 8 part 4 (8d-5): with --team=draft the bot drafts, and the vows
	# still cycle by seed within its team.
	var line: Report.RunLine = Report.play(_run, 5, "random", false, false, Report.DRAFT)
	assert_eq(line.errors, [] as Array[String])
	assert_true(line.drafted)
	var team: Array[String] = []
	team.assign(line.vows.keys())
	assert_eq(HeroTeam.problem(_run.content, team), "", "a team the draft offers")
	assert_eq(line.vows, Report.seed_vows(_run.content, HeroTeam.ordered(_run.content, team), 5))
	var text: String = Report.heroes_summary(_run, [line] as Array[Report.RunLine])
	assert_string_starts_with(text, "By hero (runs on the team, drafted")
	for hero_id: String in team:
		assert_string_contains(text, _run.content.heroes[hero_id].name)
	assert_eq(text.split("\n").size(), 4, "a line for each hero on a team")


func test_the_engine_report() -> void:
	var lines: Array[Report.RunLine] = []
	lines.assign(Report.play_many(_run, [4, 5] as Array[int], "simple"))
	for line: Report.RunLine in lines:
		assert_false(line.engines.is_empty(), "seed %d's fights had engines" % line.seed_value)
		for name: String in line.engines:
			var stats: Array = line.engines[name]
			assert_lte(stats[4], stats[5], "%s added no more than its team" % name)
			assert_lte(stats[2], stats[1], "%s: chained fires are fires" % name)
	var text: String = Report.engines_summary(lines)
	assert_string_starts_with(text, "Engines (the heroes' sources")
	assert_string_contains(text, "Held but never fired")
