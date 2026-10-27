class_name RunSave
extends RefCounted
## The run's save (docs/plans/rebuild-phase5-run.md, section 1): the
## RunState as JSON, written after every action, read back by the title's
## Continue. A save from another version, or one that won't parse, loads as
## nothing.

## (Not the old game's user://run.json, which the title drops on sight.)
const PATH: String = "user://rift_run.json"


static func save(state: RunState, path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state.to_dict(), "\t"))
	return true


## The saved run, or null.
static func load_state(path: String = PATH) -> RunState:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return RunState.from_dict(data)


static func has_save(path: String = PATH) -> bool:
	return load_state(path) != null


static func erase(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
