extends SceneTree
func _init() -> void:
	var content: ContentDb = ContentDb.load_dir("res://data")
	var cases: Array = [["eagle_eye", "deadeye", Vector2i(0, 0)], ["stormline", "deadeye", Vector2i(0, 0)], ["windrunner", "volley", Vector2i(4, 0)], ["hailstorm", "volley", Vector2i(4, 0)]]
	for c: Array in cases:
		var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": c[2], "vell": Vector2i(3, 1)}
		var totals: Array = [[0, 0], [0, 0], [0, 0]]
		var marks: Array = [0, 0, 0]
		var n: int = 0
		for enc: String in content.encounter_ids:
			if content.encounters[enc].tier == "hunt":
				continue
			n += 1
			for k: int in 3:
				var errors: Array[String] = []
				var av: Dictionary[String, String] = {}
				var apexed: Array[String] = []
				if k >= 1:
					av["maren"] = c[0]
				if k == 2:
					apexed.append("maren")
				var s: FightSetup = Encounters.setup(content, enc, formation, 7, errors, {}, {"maren": c[1]} as Dictionary[String, String], ["maren"] as Array[String], {}, av, apexed)
				var sim := CombatSim.new(s, content)
				while not sim.finished:
					sim.step()
				var r: FightResult = CombatSim.result_of(sim)
				totals[k][0] += r.deed_amount("maren", c[0])
				totals[k][1] += 1 if r.outcome != FightResult.Outcome.DEFEAT else 0
				for e: LogEntry in sim.combat_log.entries:
					if e.source_unit == "maren" and (e.note == "executed" or (e.kind == LogEntry.Kind.HOP and e.source_ability == "longshot")):
						marks[k] += 1
		print("%-11s deed/fight: transformed %.1f, taste %.1f, apex %.1f | wins %d/%d/%d of %d | executions or hops %d/%d/%d" % [c[0], totals[0][0] / float(n), totals[1][0] / float(n), totals[2][0] / float(n), totals[0][1], totals[1][1], totals[2][1], n, marks[0], marks[1], marks[2]])
	quit()
