extends SceneTree
## The run report (docs/plans/rebuild-phase5-run.md, section 12): plays many
## runs with the simple run bot and prints how they pace (tools/run_report.gd
## does the work). A report, not a gate: it exits 0 unless a run hit an
## error.
## Usage: godot --headless --path . -s tools/run_runner.gd -- [--runs=54] [--first-seed=1]

const Report = preload("res://tools/run_report.gd")


func _init() -> void:
	var options: Dictionary[String, String] = {"runs": "54", "first-seed": "1"}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			if options.has(pair[0]):
				options[pair[0]] = pair[1]
	var run: RunContent = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))
	if not run.is_valid():
		printerr("\n".join(run.errors))
		quit(1)
		return
	var seeds: Array[int] = []
	for i: int in options["runs"].to_int():
		seeds.append(options["first-seed"].to_int() + i)
	var lines: Array = Report.play_many(run, seeds)
	print(Report.summary(run, lines))
	for line: Report.RunLine in lines:
		if not line.errors.is_empty():
			printerr("seed %d: %s" % [line.seed_value, "; ".join(line.errors)])
	quit(1 if lines.any(func(line: Report.RunLine) -> bool: return not line.errors.is_empty()) else 0)
