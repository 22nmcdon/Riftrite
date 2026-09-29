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
		print("data/ OK: tuning, %d statuses, %d heroes, %d enemies, %d encounters, %d tactics, %d paths" % [db.status_ids.size(), db.hero_ids.size(), db.enemy_ids.size(), db.encounter_ids.size(), db.tactic_ids.size(), db.path_ids.size()])
		print("run OK: act %d, %d days (%s), %d upgrades, %d items" % [run.act.act, run.act.days.size(), ", ".join(run.act.days), run.upgrade_ids.size(), run.item_ids.size()])
		quit(0)
		return
	for message: String in errors:
		printerr(message)
	printerr("data/ has %d error(s)" % errors.size())
	quit(1)
