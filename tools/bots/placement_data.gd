extends SceneTree
## Placement data for fitting the good bot's weights (phase 6 step 6b,
## docs/plans/rebuild-phase6-bot-tuning.md, section 2.2): for each
## encounter of every act (Hunts aside), random legal formations of a random
## team (each hero vowed to a random path, transformed half the time in Act
## 1, always from Act 2 on, against enemies scaled down as the sim
## runner's gate scales them, so the fights can go either way:
## tools/sim_report.gd's gate_scale_bp; phase 8 part 3), each fought on a
## practice seed. One CSV line a fight: the encounter, the features
## (tools/bots/placement.gd), whether it was won, and the heroes' HP left.
## tools/bots/fit_placement.py fits WEIGHTS from it.
## Usage: godot --headless --path . -s tools/bots/placement_data.gd -- [--per=300] [--part=0/1] [--act=N] > data.csv
## (--act: only that act's encounters, to refresh one act's rows.)

const Placement = preload("res://tools/bots/placement.gd")
const SimReport = preload("res://tools/sim_report.gd")


func _init() -> void:
	var options: Dictionary[String, String] = {"per": "300", "part": "0/1", "act": ""}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair: PackedStringArray = arg.trim_prefix("--").split("=", true, 1)
			options[pair[0]] = pair[1]
	var part: PackedStringArray = options["part"].split("/")
	var content: ContentDb = ContentDb.load_dir("res://data")
	var grid: HexGrid = content.tuning.make_grid()
	var zone: Array[Vector2i] = []
	for row: int in grid.height:
		if grid.zone(row) == HexGrid.Zone.HEROES:
			for col: int in grid.width:
				zone.append(Vector2i(col, row))
	if part[0] == "0":
		print("encounter,%s,%s,won,hp_left" % [",".join(Placement.FEATURE_NAMES), ",".join(Placement.CONTEXT_NAMES.map(func(name: String) -> String: return "ctx_" + name))])
	var index: int = 0
	for encounter_id: String in content.encounter_ids:
		if content.encounters[encounter_id].tier == "hunt":
			continue
		if not options["act"].is_empty() and content.encounters[encounter_id].act != options["act"].to_int():
			continue
		var rng := SimRng.new(encounter_id.hash() & 0x7fffffff)
		for i: int in options["per"].to_int():
			index += 1
			var vows: Dictionary[String, String] = {}
			var transformed: Array[String] = []
			for hero_id: String in content.hero_ids:
				var paths: Array[PathDef] = content.heroes[hero_id].paths
				vows[hero_id] = paths[rng.range_int(paths.size())].id
				if rng.range_int(2) == 0 or content.encounters[encounter_id].act > 1:
					transformed.append(hero_id)
			var free: Array[Vector2i] = zone.duplicate()
			var formation: Dictionary[String, Vector2i] = {}
			for hero_id: String in content.hero_ids:
				formation[hero_id] = free.pop_at(rng.range_int(free.size()))
			if index % part[1].to_int() != part[0].to_int():
				continue
			var errors: Array[String] = []
			var setup: FightSetup = Encounters.setup(content, encounter_id, formation, 7001 + i, errors, {}, vows, transformed)
			if setup == null:
				continue
			if content.encounters[encounter_id].act > 1:
				var scale_bp: int = SimReport.gate_scale_bp(content.encounters[encounter_id])
				for enemy: UnitSetup in setup.enemies:
					enemy.def = Encounters.scaled(enemy.def, scale_bp)
				for k: int in setup.summon_kits.size():
					setup.summon_kits[k] = Encounters.scaled(setup.summon_kits[k], scale_bp)
			if not setup.validate(content).is_empty():
				continue
			var info: Dictionary = Placement.read_enemies(setup, grid)
			var f: PackedFloat64Array = Placement.features(setup, grid, info)
			f.append_array(info["context"])
			var sim := CombatSim.new(setup, content)
			while not sim.finished:
				sim.step()
			var hp: int = 0
			var max_hp: int = 0
			for unit: UnitState in sim.heroes:
				hp += maxi(unit.hp, 0) if unit.alive else 0
				max_hp += unit.max_hp
			var cells: PackedStringArray = PackedStringArray()
			for value: float in f:
				cells.append("%.4f" % value)
			var won: int = 0 if sim.outcome == FightResult.Outcome.DEFEAT else 1
			print("%s,%s,%d,%.4f" % [encounter_id, ",".join(cells), won, float(hp) / maxf(max_hp, 1)])
	quit(0)
