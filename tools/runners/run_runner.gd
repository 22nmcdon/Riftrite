extends SceneTree
## The run report (docs/plans/phases/rebuild-phase5-run.md, section 12; phase 6's
## bots, docs/plans/phases/rebuild-phase6-bot-tuning.md): plays many runs with a
## bot and prints how they pace (tools/reports/run_report.gd does the work). A
## report, not a gate: it exits 0 unless a run hit an error.
## Usage: godot --headless --path . -s tools/runners/run_runner.gd -- [--runs=54] [--first-seed=1] [--bot=simple-peek] [--jobs=1] [--engines] [--endless] [--team=a,b,c|draft] [--test-teams=all|plan|bad|name,name] [--no-lean]
## --bot: one of run_report.gd's BOTS. --compare plays the random bot,
## the good bot, and the expert on the same seeds and prints them side by
## side before the --bot's report (phase 6 step 6d). --choices adds the
## choices report: each card, item, and relic offered, taken, and the runs
## won with it. --engines adds the engine report
## (phase 5c step 9b): every hero engine over the runs' day fights.
## --endless (phase 8 part 1): bots go deeper at the endless choice, and the
## endless report follows (how far runs get; not tuned). Since 8c-6c that's
## after Act 3, the real endless; --endless=testing plays testing runs, whose
## choice comes after Act 1.
## --test-teams (easy-start.md ES-4) plays tools/teams/test_teams.json's teams
## (all, a group, or names), seed n the nth in turn, each with its fixed vows
## and its shops leaning toward its items and relics (testing only;
## --no-lean turns that off).
## --jobs=N plays the seeds in N Godot processes, then merges them: the
## report is the same as one process's. The processes share the seeds: each
## claims the next unclaimed one (a folder made under --claims=dir, which only
## one can make) and plays it, so none sits idle while another still has a
## slice to go; each writes its runs with --part=k/N --out=file. A child given
## --part without --claims plays every Nth seed from the kth, as before.
## While it plays, each process writes its progress (tools/progress.gd: a
## unit is a run; --jobs children share a group, one part each);
## --no-progress turns that off.

const Report = preload("res://tools/reports/run_report.gd")
const Progress = preload("res://tools/progress.gd")
const PARTS_DIR: String = "user://run_parts"

## What --jobs lost (a process that wrote nothing, a seed no one finished):
## reported as errors, kept out of the report's numbers.
var _lost: Array[String] = []


func _init() -> void:
	var options: Dictionary[String, String] = {"runs": "54", "first-seed": "1", "bot": "simple-peek", "jobs": "1", "part": "", "out": "", "endless": "", "team": "", "test-teams": "", "progress-group": "", "claims": ""}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			if options.has(pair[0]):
				options[pair[0]] = pair[1]
	if OS.get_cmdline_user_args().has("--endless"):
		options["endless"] = "yes"
	if not Report.BOTS.has(options["bot"]):
		printerr("unknown bot \"%s\" (%s)" % [options["bot"], ", ".join(Report.BOTS)])
		quit(1)
		return
	var run: RunContent = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))
	if not run.is_valid():
		printerr("\n".join(run.errors))
		quit(1)
		return
	if not options["team"].is_empty() and options["team"] != "draft" and not HeroTeam.problem(run.content, _team(options)).is_empty():
		printerr("--team: " + HeroTeam.problem(run.content, _team(options)))
		quit(1)
		return
	var errors: Array[String] = []
	_test_teams(run, options, errors)
	if not errors.is_empty():
		printerr("--test-teams: " + "; ".join(errors))
		quit(1)
		return
	var seeds: Array[int] = []
	for i: int in options["runs"].to_int():
		seeds.append(options["first-seed"].to_int() + i)
	if not options["part"].is_empty():
		_play_part(run, seeds, options)
		return
	var jobs: int = clampi(options["jobs"].to_int(), 1, 32)
	var lines: Array[Report.RunLine] = _play(run, seeds, jobs, options, options["bot"])
	if OS.get_cmdline_user_args().has("--compare"):
		var by_bot: Dictionary[String, Array] = {}
		for bot_name: String in ["random", "good", "expert"]:
			by_bot[bot_name] = lines if bot_name == options["bot"] else _play(run, seeds, jobs, options, bot_name)
		print(Report.compare_summary(run, by_bot))
		print("")
	print(Report.summary(run, lines))
	if OS.get_cmdline_user_args().has("--choices"):
		print("")
		print(Report.choices_summary(run, lines))
	if OS.get_cmdline_user_args().has("--engines"):
		print("")
		print(Report.engines_summary(lines))
	if not options["endless"].is_empty():
		print("")
		print(Report.endless_summary(run, lines))
	for line: Report.RunLine in lines:
		if not line.errors.is_empty():
			printerr("seed %d: %s" % [line.seed_value, "; ".join(line.errors)])
	for lost: String in _lost:
		printerr(lost)
	quit(1 if not _lost.is_empty() or lines.any(func(line: Report.RunLine) -> bool: return not line.errors.is_empty()) else 0)


func _play(run: RunContent, seeds: Array[int], jobs: int, options: Dictionary[String, String], bot_name: String) -> Array[Report.RunLine]:
	var lines: Array[Report.RunLine] = []
	if jobs > 1:
		var for_bot: Dictionary[String, String] = options.duplicate()
		for_bot["bot"] = bot_name
		return _play_in_processes(seeds, jobs, for_bot)
	var group: String = "%s-%s" % [Progress.own_id("run_runner"), bot_name]
	lines.assign(_play_seeds(run, seeds, bot_name, options, group, "0/1"))
	return lines


## Plays `seeds` one at a time (as Report.play_many does), writing progress
## to the group's part.
func _play_seeds(run: RunContent, seeds: Array[int], bot_name: String, options: Dictionary[String, String], group: String, part: String) -> Array[Report.RunLine]:
	var progress := Progress.new()
	progress.start(Progress.own_id("run_runner"), "runs (the %s bot)" % bot_name, "runs", seeds.size(), group, part)
	var lines: Array[Report.RunLine] = []
	var test_teams: Array[Dictionary] = _test_teams(run, options, [])
	for run_seed: int in seeds:
		lines.append_array(Report.play_many(run, [run_seed], bot_name, not options["endless"].is_empty(), options["endless"] == "testing", _team(options), test_teams))
		progress.step(lines.size())
	progress.finish("failed" if lines.any(func(line: Report.RunLine) -> bool: return not line.errors.is_empty()) else "done")
	return lines


## A child process (--part=k/N): plays the seeds it claims under --claims
## (or, without it, every Nth seed from the kth), and writes the runs to --out.
func _play_part(run: RunContent, seeds: Array[int], options: Dictionary[String, String]) -> void:
	var part: PackedStringArray = options["part"].split("/")
	var group: String = options["progress-group"] if not options["progress-group"].is_empty() else Progress.own_id("run_runner")
	var played: Array[Report.RunLine] = []
	if not options["claims"].is_empty():
		played = _play_claimed(run, seeds, options, group)
	else:
		var mine: Array[int] = []
		for i: int in seeds.size():
			if i % part[1].to_int() == part[0].to_int():
				mine.append(seeds[i])
		played = _play_seeds(run, mine, options["bot"], options, group, options["part"])
	var dicts: Array[Dictionary] = []
	for line: Report.RunLine in played:
		dicts.append(line.to_dict())
	var file: FileAccess = FileAccess.open(options["out"], FileAccess.WRITE)
	file.store_var(dicts)
	file.close()
	quit(0)


## Plays each seed of `seeds` this process claims first (a folder named for
## it under --claims: making one that's there fails, so each seed is played
## once), in seed order, writing progress as it goes: its total is what it has
## played and its share of the seeds no one has claimed yet.
func _play_claimed(run: RunContent, seeds: Array[int], options: Dictionary[String, String], group: String) -> Array[Report.RunLine]:
	var jobs: int = maxi(1, options["part"].split("/")[1].to_int())
	var claims: String = options["claims"]
	var progress := Progress.new()
	progress.start(Progress.own_id("run_runner"), "runs (the %s bot)" % options["bot"], "runs", ceili(float(seeds.size()) / jobs), group, options["part"])
	var lines: Array[Report.RunLine] = []
	var test_teams: Array[Dictionary] = _test_teams(run, options, [])
	for run_seed: int in seeds:
		if DirAccess.make_dir_absolute(claims.path_join(str(run_seed))) != OK:
			continue
		lines.append_array(Report.play_many(run, [run_seed], options["bot"], not options["endless"].is_empty(), options["endless"] == "testing", _team(options), test_teams))
		var unclaimed: int = maxi(0, seeds.size() - DirAccess.get_directories_at(claims).size())
		progress.total = lines.size() + ceili(float(unclaimed) / jobs)
		progress.step(lines.size())
	progress.total = lines.size()
	progress.finish("failed" if lines.any(func(line: Report.RunLine) -> bool: return not line.errors.is_empty()) else "done")
	return lines


## Starts `jobs` child processes sharing `seeds` (each claims the next under a
## claims folder), waits for them, and reads their runs back in seed order; a
## seed no one played (its process died mid-run) is reported in `_lost`.
func _play_in_processes(seeds: Array[int], jobs: int, options: Dictionary[String, String]) -> Array[Report.RunLine]:
	DirAccess.make_dir_recursive_absolute(PARTS_DIR)
	var pids: Array[int] = []
	var outs: Array[String] = []
	var group: String = "%s-%s" % [Progress.own_id("run_runner"), options["bot"]]
	var claims: String = ProjectSettings.globalize_path("%s/claims_%d_%s" % [PARTS_DIR, OS.get_process_id(), options["bot"]])
	_remove_claims(claims)
	DirAccess.make_dir_recursive_absolute(claims)
	for k: int in jobs:
		var out: String = ProjectSettings.globalize_path("%s/part_%d_%d.bin" % [PARTS_DIR, OS.get_process_id(), k])
		outs.append(out)
		var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "tools/runners/run_runner.gd", "--",
			"--runs=%d" % seeds.size(), "--first-seed=%d" % seeds[0], "--bot=%s" % options["bot"], "--part=%d/%d" % [k, jobs], "--out=%s" % out, "--claims=%s" % claims]
		if not options["endless"].is_empty():
			args.append("--endless" if options["endless"] == "yes" else "--endless=%s" % options["endless"])
		if not options["team"].is_empty():
			args.append("--team=%s" % options["team"])
		if not options["test-teams"].is_empty():
			args.append("--test-teams=%s" % options["test-teams"])
		if OS.get_cmdline_user_args().has("--no-lean"):
			args.append("--no-lean")
		args.append("--progress-group=%s" % group)
		if OS.get_cmdline_user_args().has("--no-progress"):
			args.append("--no-progress")
		pids.append(OS.create_process(OS.get_executable_path(), args))
	# Every child checked each pass, so one that dies is reaped at once (not
	# left a zombie behind those before it, which a progress reader would take
	# for alive).
	var running: Array[int] = pids.duplicate()
	while not running.is_empty():
		running = running.filter(func(pid: int) -> bool: return OS.is_process_running(pid))
		if not running.is_empty():
			OS.delay_msec(200)
	var lines: Array[Report.RunLine] = []
	for out: String in outs:
		var file: FileAccess = FileAccess.open(out, FileAccess.READ)
		if file == null:
			_lost.append("a --jobs process wrote nothing (%s)" % out)
			continue
		var dicts: Array = file.get_var()
		file.close()
		DirAccess.remove_absolute(out)
		for data: Dictionary in dicts:
			lines.append(Report.RunLine.from_dict(data))
	_remove_claims(claims)
	var played: Dictionary[int, bool] = {}
	for line: Report.RunLine in lines:
		played[line.seed_value] = true
	var unplayed: Array[String] = []
	for run_seed: int in seeds:
		if not played.has(run_seed):
			unplayed.append(str(run_seed))
	if not unplayed.is_empty():
		_lost.append("%d seeds weren't played (a --jobs process died mid-run; the report leaves them out): %s" % [unplayed.size(), ", ".join(unplayed)])
	lines.sort_custom(func(a: Report.RunLine, b: Report.RunLine) -> bool: return a.seed_value < b.seed_value)
	return lines


func _remove_claims(claims: String) -> void:
	if not DirAccess.dir_exists_absolute(claims):
		return
	for name: String in DirAccess.get_directories_at(claims):
		DirAccess.remove_absolute(claims.path_join(name))
	DirAccess.remove_absolute(claims)


## --team=a,b,c (phase 8 part 4): every run with that team, its vows cycling;
## --team=draft: the bot drafts each run's team (Bot.team, 8d-5), its vows
## cycling; without it, the runs cycle every team the draft offers.
func _team(options: Dictionary[String, String]) -> Array[String]:
	var team: Array[String] = []
	if options["team"] == "draft":
		return Report.DRAFT.duplicate()
	if not options["team"].is_empty():
		team.assign(Array(options["team"].split(",")))
	return team


## --test-teams (ES-4): the test teams named, with their leans unless
## --no-lean; none without it.
func _test_teams(run: RunContent, options: Dictionary[String, String], errors: Array[String]) -> Array[Dictionary]:
	if options["test-teams"].is_empty():
		return []
	var lean: bool = not OS.get_cmdline_user_args().has("--no-lean")
	return Report.read_test_teams(run, FileAccess.get_file_as_string(Report.TEST_TEAMS), options["test-teams"], lean, errors)
