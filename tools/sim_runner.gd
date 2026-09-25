extends SceneTree
## Headless balance sim. Runs every party in tools/sim_parties.json against
## every encounter in data/encounters.json (or just the ones named) and prints
## a report per matchup.
##
## Usage:
##   godot --headless --path . -s tools/sim_runner.gd -- [--fights=200] [--seed=1] [--party=id] [--encounter=id]


func _init() -> void:
	var args: Dictionary[String, String] = {"fights": "200", "seed": "1", "party": "", "encounter": ""}
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
		if parts.size() != 2 or not args.has(parts[0]):
			printerr("unknown argument: %s" % arg)
			quit(2)
			return
		args[parts[0]] = parts[1]

	var content: ContentDb = ContentDb.load_dir("res://data")
	if not content.is_valid():
		for message: String in content.errors:
			printerr(message)
		quit(1)
		return
	var parties: BalanceRun.Parties = BalanceRun.load_parties(content)
	if not parties.errors.is_empty():
		for message: String in parties.errors:
			printerr(message)
		quit(1)
		return

	var start: int = Time.get_ticks_msec()
	var failed: bool = false
	for party: BalanceRun.Party in parties.list:
		if not args["party"].is_empty() and party.id != args["party"]:
			continue
		for encounter_id: String in content.encounter_ids:
			if not args["encounter"].is_empty() and encounter_id != args["encounter"]:
				continue
			var stats: BalanceRun.Stats = BalanceRun.run(content, party, encounter_id, args["fights"].to_int(), args["seed"].to_int())
			failed = failed or not stats.errors.is_empty()
			print("\n".join(BalanceRun.report(stats)))
			print("")
	print("Done in %.1fs" % ((Time.get_ticks_msec() - start) / 1000.0))
	quit(1 if failed else 0)
