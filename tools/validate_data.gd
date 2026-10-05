extends SceneTree
## Validates every file in data/ and exits non-zero if anything is wrong.
## Usage: godot --headless --path . -s tools/validate_data.gd


func _init() -> void:
	var db: ContentDb = ContentDb.load_dir("res://data")
	var errors: Array[String] = db.errors.duplicate()
	var run: RunContent = null
	if db.is_valid():
		run = RunContent.load_dir("res://data", db)
		errors.append_array(run.errors)
	if errors.is_empty():
		print("data/ OK: tuning, %d statuses, %d heroes, %d enemies, %d encounters, %d tactics, %d paths, %d apexes, %d enemy upgrades" % [db.status_ids.size(), db.hero_ids.size(), db.enemy_ids.size(), db.encounter_ids.size(), db.tactic_ids.size(), db.path_ids.size(), db.apex_ids.size(), db.enemy_upgrade_ids.size()])
		for act_def: ActDef in run.acts:
			print("act %d OK: %d days (%s)%s" % [act_def.act, act_def.days.size(), ", ".join(act_def.days), "" if act_def.fights_act == act_def.act else ", fights from act %d" % act_def.fights_act])
		print("run OK: %d acts, %d upgrades, %d items, %d camp places, %d relics, %d bonds, %d events, %d oaths" % [run.acts.size(), run.upgrade_ids.size(), run.item_ids.size(), run.camps.places.size(), run.relic_ids.size(), run.bond_ids.size(),
			run.events.scenes.size(), run.events.oaths.size()])
		quit(0)
		return
	for message: String in errors:
		printerr(message)
	printerr("data/ has %d error(s)" % errors.size())
	quit(1)
