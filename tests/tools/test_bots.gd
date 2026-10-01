extends GutTest
## Phase 6's bots (docs/plans/rebuild-phase6-bot-tuning.md, section 2): each
## plays whole runs through RunPlayer without a refused action, and a run
## repeats from its seed; and the run report's run lines survive --jobs.

const RunPlayer = preload("res://tools/bots/run_player.gd")
const Report = preload("res://tools/run_report.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _vows(run_seed: int) -> Dictionary[String, String]:
	var vows: Dictionary[String, String] = {}
	vows.assign(Report.vow_combinations(_run.content)[run_seed % 27])
	return vows


func _play(bot_name: String, run_seed: int) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunPlayer.play(_run, run_seed, Report.make_bot(bot_name), _vows(run_seed), errors)
	assert_eq(errors, [] as Array[String], "%s, seed %d" % [bot_name, run_seed])
	assert_eq(flow.state.phase, RunState.Phase.ENDED, "%s, seed %d ends" % [bot_name, run_seed])
	return flow


func test_each_bot_plays_runs_to_their_end_and_repeats() -> void:
	for bot_name: String in Report.BOTS:
		for run_seed: int in [3, 8]:
			var first: RunFlow = _play(bot_name, run_seed)
			var again: RunFlow = _play(bot_name, run_seed)
			assert_eq(JSON.stringify(again.state.to_dict()), JSON.stringify(first.state.to_dict()), "%s, seed %d repeats" % [bot_name, run_seed])


func test_the_random_bot_does_what_the_simple_one_never_does() -> void:
	# The simple bot always takes today's first fight; the random one takes
	# the harder one now and then.
	var fights: Dictionary[String, bool] = {}
	for run_seed: int in range(1, 7):
		var flow: RunFlow = _play("random", run_seed)
		for fought: RunState.Fought in flow.state.fought:
			fights[fought.encounter] = true
	var harder: bool = fights.keys().any(func(id: String) -> bool: return _run.content.encounters[id].tier == "harder")
	assert_true(harder, "it takes the harder fight sometimes; the simple bot never does")


func test_a_run_line_survives_jobs() -> void:
	var line: Report.RunLine = Report.play(_run, 5, "random")
	var file: FileAccess = FileAccess.open("user://test_run_line.bin", FileAccess.WRITE)
	file.store_var([line.to_dict()])
	file.close()
	file = FileAccess.open("user://test_run_line.bin", FileAccess.READ)
	var back: Report.RunLine = Report.RunLine.from_dict(file.get_var()[0])
	file.close()
	DirAccess.remove_absolute("user://test_run_line.bin")
	var lines: Array[Report.RunLine] = [line]
	var read: Array[Report.RunLine] = [back]
	assert_eq(Report.summary(_run, read), Report.summary(_run, lines), "the report from a line read back is the same")
	assert_eq(Report.engines_summary(read), Report.engines_summary(lines))
	assert_eq(back.bot, "random")
