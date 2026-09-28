extends SceneTree
## Fights the Act 1 encounters with placed parties and reports whether
## placement matters (docs/plans/rebuild-phase2-heroes-enemies.md, section 7).
## Usage:
##   godot --headless --path . -s tools/sim_runner.gd -- [--encounter=id] [--seeds=50] [--sweep=40] [--draw-seed=1] [--no-boards]
##   --encounter  one encounter (default: all, in encounters.json's order)
##   --seeds      fights per formation, seeds 1 to N (they only change crits)
##   --sweep      formations drawn from --draw-seed, besides the named ones in
##                tools/sim_formations.json
##   --no-boards  leave out the best and worst formations' boards
## Ends with a line per encounter, and exits 1 if any fails the gate.

const Report = preload("res://tools/sim_report.gd")
const FORMATIONS_FILE: String = "res://tools/sim_formations.json"


func _init() -> void:
	var options: Dictionary[String, String] = {"encounter": "", "seeds": "50", "sweep": "40", "draw-seed": "1"}
	var boards: bool = true
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--no-boards":
			boards = false
			continue
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not options.has(parts[0]):
			_fail("unknown option %s" % arg)
			return
		options[parts[0]] = parts[1]
	var content: ContentDb = ContentDb.load_dir("res://data")
	if not content.is_valid():
		_fail("data/ has errors:\n" + "\n".join(content.errors))
		return
	var errors: Array[String] = []
	var named: Dictionary[String, Dictionary] = Report.read_formations(FileAccess.get_file_as_string(FORMATIONS_FILE), errors)
	if not errors.is_empty():
		_fail("\n".join(errors))
		return
	var encounter_ids: Array[String] = content.encounter_ids
	if not options["encounter"].is_empty():
		if not content.encounters.has(options["encounter"]):
			_fail("unknown encounter %s" % options["encounter"])
			return
		encounter_ids = [options["encounter"]]
	var summary: Array[String] = []
	var failed: int = 0
	for encounter_id: String in encounter_ids:
		var report: Report.Report = Report.run_encounter(content, encounter_id, named, options["sweep"].to_int(), options["seeds"].to_int(), options["draw-seed"].to_int())
		print(Report.text(content, report, boards))
		print("")
		if not report.passes():
			failed += 1
		summary.append("  %-14s %s  gap %3d points  %2d of %d formations win  median fight %s" % [encounter_id, "pass" if report.passes() else "FAIL", report.gap_points(),
			report.winning(), report.rows.size(), Report.seconds(report.median_ticks())])
	print("Placement matters (best at least %d points above worst): %d of %d encounters" % [Report.GATE_POINTS, encounter_ids.size() - failed, encounter_ids.size()])
	print("\n".join(summary))
	quit(1 if failed > 0 else 0)


func _fail(message: String) -> void:
	printerr("sim runner: " + message)
	quit(2)
