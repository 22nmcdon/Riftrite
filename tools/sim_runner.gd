extends SceneTree
## Fights the Act 1 encounters with placed parties and reports whether
## placement matters (docs/plans/rebuild-phase2-heroes-enemies.md, section 7).
## Usage:
##   godot --headless --path . -s tools/sim_runner.gd -- [--encounter=id] [--seeds=50] [--sweep=40] [--draw-seed=1] [--no-boards] [--tactics] [--paths] [--deeds]
##   --encounter  one encounter (default: all, in encounters.json's order)
##   --seeds      fights per formation, seeds 1 to N (they only change crits)
##   --sweep      formations drawn from --draw-seed, besides the named ones in
##                tools/sim_formations.json
##   --no-boards  leave out the best and worst formations' boards
##   --tactics    the tactics report instead (phase 3b): the same formations
##                with each tactic on each hero who can take it, against no
##                tactics. It's a report, not a gate, so it exits 0.
##   --paths      the paths report instead (phase 4): each path vowed and
##                transformed on its hero, against all base; its win rate
##                and where the hero stands in the formations it wins.
##   --deeds      the deeds report instead (phase 4): what a fight puts into
##                each deed at each stage, the taste bar, and where allies
##                stand around Brannoc. With --paths, both from the same
##                fights. Reports, not gates: they exit 0.
##   --apexes     the apexes report instead (phase 8 part 2,
##                tools/apex_report.gd): each team in tools/apex_teams.json
##                transformed and at apex, over enemies scaled up step by
##                step; --singles adds each apex alone, --team=<name> one
##                team, --apex-deeds what a fight puts into each apex's deed
##                with its taste. Use --sweep=4 or so: it fights a lot.
##   --act=N      only act N's encounters (phase 8 part 3)
##   --scales=a,b,...  the apexes report's enemy strengths, in basis points
##                (default ApexReport.SCALES, x1.0 to x5.0); below 10000 too
##   --by-encounter  with --apexes: each encounter's half point for each
##                team, transformed and at apex (for tuning an act's scales)
##   --builds     the builds report instead (phase 8 part 4,
##                tools/build_report.gd; docs/plans/build-tuning.md): each
##                path in tools/build_teams.json, its floor (in the neutral
##                team), its ceiling (in its build team, with its relics), and
##                an enabler's lift; --team=<name> one build,
##                --strength=15000 the ceiling's and lift's enemies x1.5
##                (a build team wins nearly every Act 1 fight). Use
##                --seeds=1 --sweep=20 and --act=1.
## Ends with a line per encounter, and exits 1 if any fails the gate.

const Report = preload("res://tools/sim_report.gd")
const PathReport = preload("res://tools/path_report.gd")
const ApexReport = preload("res://tools/apex_report.gd")
const BuildReport = preload("res://tools/build_report.gd")
const FORMATIONS_FILE: String = "res://tools/sim_formations.json"


func _init() -> void:
	var options: Dictionary[String, String] = {"encounter": "", "seeds": "50", "sweep": "40", "draw-seed": "1", "team": "", "act": "", "scales": "", "strength": "10000"}
	var by_encounter: bool = false
	var apexes: bool = false
	var singles: bool = false
	var apex_deeds: bool = false
	var boards: bool = true
	var tactics: bool = false
	var paths: bool = false
	var deeds: bool = false
	var builds: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--no-boards":
			boards = false
			continue
		if arg == "--tactics":
			tactics = true
			continue
		if arg == "--paths":
			paths = true
			continue
		if arg == "--deeds":
			deeds = true
			continue
		if arg == "--apexes":
			apexes = true
			continue
		if arg == "--builds":
			builds = true
			continue
		if arg == "--singles":
			singles = true
			continue
		if arg == "--apex-deeds":
			apex_deeds = true
			continue
		if arg == "--by-encounter":
			by_encounter = true
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
	# The gate's team (phase 8 part 4): the built three, cast by role.
	named = Report.for_team(content, named, HeroTeam.DEFAULT)
	# A Hunt's small pack (phase 5) is a quick fight for shards, not a
	# placement question, so only --encounter runs one.
	var encounter_ids: Array[String] = content.encounter_ids.filter(func(id: String) -> bool: return content.encounters[id].tier != "hunt")
	if not options["act"].is_empty():
		encounter_ids = encounter_ids.filter(func(id: String) -> bool: return content.encounters[id].act == options["act"].to_int())
	var scales: Array[int] = ApexReport.SCALES.duplicate()
	if not options["scales"].is_empty():
		scales.clear()
		for value: String in options["scales"].split(","):
			scales.append(value.to_int())
	if not options["encounter"].is_empty():
		if not content.encounters.has(options["encounter"]):
			_fail("unknown encounter %s" % options["encounter"])
			return
		encounter_ids = [options["encounter"]]
	if apexes or apex_deeds:
		var teams: Array[ApexReport.Team] = ApexReport.read_teams(errors)
		if not errors.is_empty():
			_fail("\n".join(errors))
			return
		if not options["team"].is_empty():
			var picked: Array[ApexReport.Team] = []
			for team: ApexReport.Team in teams:
				if team.name == options["team"]:
					picked.append(team)
			teams = picked
		if apex_deeds:
			print(ApexReport.deeds_text(content, teams, encounter_ids, named, options["sweep"].to_int()))
		if apexes and by_encounter:
			print(ApexReport.by_encounter_text(content, teams, encounter_ids, named, options["sweep"].to_int(), scales))
		elif apexes:
			for team: ApexReport.Team in teams:
				var variants: Array[ApexReport.Lineup] = ApexReport.variants_for(content, team, singles)
				for variant: ApexReport.Lineup in variants:
					ApexReport.run_variant(content, variant, encounter_ids, named, options["sweep"].to_int(), scales)
				print(ApexReport.team_text(content, team, variants, scales))
				print("")
		quit(0)
		return
	if builds:
		var run: RunContent = RunContent.load_dir("res://data", content)
		var picked: Array[BuildReport.Build] = BuildReport.read_builds(content, run, errors)
		if not errors.is_empty():
			_fail("\n".join(errors))
			return
		if not options["team"].is_empty():
			picked = picked.filter(func(build: BuildReport.Build) -> bool: return build.name == options["team"])
		var results: Array[BuildReport.Result] = []
		for build: BuildReport.Build in picked:
			results.append(BuildReport.run_build(content, run, build, encounter_ids, named, options["sweep"].to_int(), options["seeds"].to_int(), options["strength"].to_int()))
		print(BuildReport.text(content, results))
		quit(0)
		return
	if paths or deeds:
		var path_reports: Array[PathReport.PathReport] = []
		for encounter_id: String in encounter_ids:
			var path_report: PathReport.PathReport = PathReport.run_paths(content, encounter_id, named, options["sweep"].to_int(), options["seeds"].to_int(), options["draw-seed"].to_int())
			if paths:
				print(PathReport.paths_text(content, path_report))
			if deeds:
				print(PathReport.deeds_text(content, path_report))
			print("")
			path_reports.append(path_report)
		if paths:
			print(PathReport.paths_summary(content, path_reports))
		if deeds:
			print(PathReport.deeds_summary(content, path_reports))
		quit(0)
		return
	if tactics:
		var reports: Array[Report.TacticReport] = []
		for encounter_id: String in encounter_ids:
			var report: Report.TacticReport = Report.run_tactics(content, encounter_id, named, options["sweep"].to_int(), options["seeds"].to_int(), options["draw-seed"].to_int())
			print(Report.tactics_text(content, report))
			print("")
			reports.append(report)
		print(Report.tactics_summary(content, reports))
		quit(0)
		return
	var summary: Array[String] = []
	var failed: int = 0
	for encounter_id: String in encounter_ids:
		var report: Report.Report = Report.run_encounter(content, encounter_id, named, options["sweep"].to_int(), options["seeds"].to_int(), options["draw-seed"].to_int())
		print(Report.text(content, report, boards))
		print("")
		if not report.passes():
			failed += 1
		summary.append("  %-14s %s  gap %3d points  %2d of %d formations win  median fight %s" % [encounter_id, ("days 1-3" if report.exempt() else "pass") if report.passes() else "FAIL", report.gap_points(),
			report.winning(), report.rows.size(), Report.seconds(report.median_ticks())] + ("" if report.scale_bp == 0 else "  (enemies x%.2f)" % (report.scale_bp / 10000.0)))
	print("Placement matters (best at least %d points above worst): %d of %d encounters" % [Report.GATE_POINTS, encounter_ids.size() - failed, encounter_ids.size()])
	print("\n".join(summary))
	quit(1 if failed > 0 else 0)


func _fail(message: String) -> void:
	printerr("sim runner: " + message)
	quit(2)
