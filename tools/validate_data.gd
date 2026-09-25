extends SceneTree
## Validates every file in data/ and exits non-zero if anything is wrong.
## Usage: godot --headless --path . -s tools/validate_data.gd


func _init() -> void:
	var db: ContentDb = ContentDb.load_dir("res://data")
	if db.is_valid():
		print("data/ OK: %d statuses, %d essences" % [db.status_ids.size(), db.essence_ids.size()])
		quit(0)
		return
	for message: String in db.errors:
		printerr(message)
	printerr("data/ has %d error(s)" % db.errors.size())
	quit(1)
