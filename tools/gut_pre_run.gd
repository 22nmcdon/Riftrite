extends GutHookScript
## GUT pre-run hook: compile every project script before tests run.
## Without this, a test file with a parse error (e.g. an untyped `var`) is
## skipped and the run still reports "All tests passed".
## GUT ignores a pre-run hook's exit code, so this only records the broken
## scripts; tools/gut_post_run.gd turns them into a failing exit code.

const SCRIPT_DIRS: Array[String] = ["res://src", "res://tests", "res://tools"]

var broken: Array[String] = []


func run() -> void:
	for dir: String in SCRIPT_DIRS:
		for path: String in _find_scripts(dir):
			var script: GDScript = load(path) as GDScript
			if script == null or not script.can_instantiate():
				broken.append(path)
	for path: String in broken:
		gut.logger.error("Script failed to compile: %s" % path)


func _find_scripts(dir: String) -> Array[String]:
	var found: Array[String] = []
	if not DirAccess.dir_exists_absolute(dir):
		return found
	# Sorted so the report order is stable.
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for file: String in files:
		if file.ends_with(".gd"):
			found.append(dir.path_join(file))
	var subdirs: PackedStringArray = DirAccess.get_directories_at(dir)
	subdirs.sort()
	for sub: String in subdirs:
		found.append_array(_find_scripts(dir.path_join(sub)))
	return found
