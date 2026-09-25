extends SceneTree
## The run-level balance runner: the run bot plays whole runs and this
## reports how they go.
## Usage: godot --headless --path . -s tools/run_runner.gd -- --runs=200 --seed=1


func _init() -> void:
	var runs: int = 100
	var first_seed: int = 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = arg.trim_prefix("--runs=").to_int()
		elif arg.begins_with("--seed="):
			first_seed = arg.trim_prefix("--seed=").to_int()
	var content: ContentDb = ContentDb.load_dir("res://data")
	var run: RunContent = RunContent.load_dir("res://data", content) if content.is_valid() else null
	if run == null or not run.is_valid():
		for message: String in content.errors + (run.errors if run != null else [] as Array[String]):
			printerr(message)
		quit(1)
		return
	var started: int = Time.get_ticks_msec()
	var reports: Array[RunBot.Report] = []
	for i: int in runs:
		reports.append(RunBot.play(first_seed + i, content, run))
	for line: String in RunReport.lines(reports, first_seed):
		print(line)
	print("\nDone in %.1fs" % ((Time.get_ticks_msec() - started) / 1000.0))
	quit(0)
