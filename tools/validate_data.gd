extends SceneTree
## Validates every file in data/ (the sim's content and the run layer's) and
## exits non-zero if anything is wrong.
## Usage: godot --headless --path . -s tools/validate_data.gd


func _init() -> void:
	var db: ContentDb = ContentDb.load_dir("res://data")
	var errors: Array[String] = db.errors.duplicate()
	var run: RunContent = null
	if db.is_valid():
		run = RunContent.load_dir("res://data", db)
		errors.append_array(run.errors)
	if errors.is_empty():
		print("data/ OK: %d statuses, %d essences, %d alloys, %d items, %d heroes, %d enemies, %d encounters, %d relics, %d synergies, %d specializations, %d acts, %d events" % [
			db.status_ids.size(), db.essence_ids.size(), db.alloy_ids.size(), db.item_ids.size(),
			db.hero_ids.size(), db.enemy_ids.size(), db.encounter_ids.size(), db.relic_ids.size(), db.synergy_ids.size(), db.specialization_ids.size(),
			run.acts.size(), run.event_ids.size()])
		quit(0)
		return
	for message: String in errors:
		printerr(message)
	printerr("data/ has %d error(s)" % errors.size())
	quit(1)
