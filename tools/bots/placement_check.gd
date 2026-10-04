extends SceneTree
## Checks the good bot's placement (phase 6 step 6b): for each encounter
## (Hunts aside), teams drawn as placement_data.gd draws them (transformed
## and against scaled enemies from Act 2 on) but from another stream, each placed by placement.gd's best formation and
## fought on a practice seed; against the same teams placed at random.
## Usage: godot --headless --path . -s tools/bots/placement_check.gd -- [--per=20] [--weights=path] [--act=N]

const Placement = preload("res://tools/bots/placement.gd")
const SimReport = preload("res://tools/sim_report.gd")


func _init() -> void:
	var per: int = 20
	var act: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--per="):
			per = arg.trim_prefix("--per=").to_int()
		if arg.begins_with("--act="):
			act = arg.trim_prefix("--act=").to_int()
		if arg.begins_with("--weights="):
			Placement.weights_file = arg.trim_prefix("--weights=")
	var content: ContentDb = ContentDb.load_dir("res://data")
	var grid: HexGrid = content.tuning.make_grid()
	var zone: Array[Vector2i] = []
	for row: int in grid.height:
		if grid.zone(row) == HexGrid.Zone.HEROES:
			for col: int in grid.width:
				zone.append(Vector2i(col, row))
	var total_bot: int = 0
	var total_random: int = 0
	var total: int = 0
	var started: int = Time.get_ticks_msec()
	for encounter_id: String in content.encounter_ids:
		if content.encounters[encounter_id].tier == "hunt" or (act > 0 and content.encounters[encounter_id].act != act):
			continue
		var rng := SimRng.new((encounter_id.hash() & 0xffffff) + 99991)
		var bot_wins: int = 0
		var random_wins: int = 0
		for i: int in per:
			var vows: Dictionary[String, String] = {}
			var transformed: Array[String] = []
			for hero_id: String in content.hero_ids:
				var paths: Array[PathDef] = content.heroes[hero_id].paths
				vows[hero_id] = paths[rng.range_int(paths.size())].id
				if rng.range_int(2) == 0 or content.encounters[encounter_id].act > 1:
					transformed.append(hero_id)
			var free: Array[Vector2i] = zone.duplicate()
			var random_formation: Dictionary[String, Vector2i] = {}
			for hero_id: String in content.hero_ids:
				random_formation[hero_id] = free.pop_at(rng.range_int(free.size()))
			var errors: Array[String] = []
			var setup: FightSetup = Encounters.setup(content, encounter_id, random_formation, 9001 + i, errors, {}, vows, transformed)
			SimReport.scale_for_gate(content, encounter_id, setup)
			random_wins += 1 if CombatSim.run(setup, content).outcome != FightResult.Outcome.DEFEAT else 0
			var placed: Dictionary = Placement.best_formations(setup, grid, 1)[0]
			var formation: Dictionary[String, Vector2i] = {}
			formation.assign(placed)
			var bot_setup: FightSetup = Encounters.setup(content, encounter_id, formation, 9001 + i, errors, {}, vows, transformed)
			SimReport.scale_for_gate(content, encounter_id, bot_setup)
			bot_wins += 1 if CombatSim.run(bot_setup, content).outcome != FightResult.Outcome.DEFEAT else 0
		total_bot += bot_wins
		total_random += random_wins
		total += per
		print("  %-22s bot %3d%%  random %3d%%" % [encounter_id, bot_wins * 100 / per, random_wins * 100 / per])
	print("  all                    bot %3d%%  random %3d%%   (%.1fs)" % [total_bot * 100 / total, total_random * 100 / total, (Time.get_ticks_msec() - started) / 1000.0])
	quit(0)
