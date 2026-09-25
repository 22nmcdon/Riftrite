class_name RunSave
extends RefCounted
## Saves and loads a run as JSON (the run layer's only file I/O). A run is
## saved between steps; fights have no player input, so there's nothing to
## save mid-fight.

const DEFAULT_PATH: String = "user://run.json"


## Writes the run. Returns "" or what went wrong.
static func save(state: RunState, path: String = DEFAULT_PATH) -> String:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "couldn't write %s (error %d)" % [path, FileAccess.get_open_error()]
	file.store_string(JSON.stringify(state.to_dict(), "  "))
	return ""


## Reads a run. Returns [state, errors]; use the state only if errors is empty.
static func load_run(content: ContentDb, path: String = DEFAULT_PATH) -> Array:
	if not FileAccess.file_exists(path):
		var missing: Array[String] = ["no saved run at %s" % path]
		return [null, missing]
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		var broken: Array[String] = ["%s: invalid JSON on line %d: %s" % [path, json.get_error_line(), json.get_error_message()]]
		return [null, broken]
	return RunState.from_dict(json.data, content)
