extends RefCounted
## Progress files for the long tools (run_runner.gd, sim_runner.gd,
## placement_data.gd, placement_check.gd), so a run's status shows while it
## goes (the run-status mod in .claude/skills/run-status/ reads them).
## Each process writes <repo>/.progress/<id>.json:
##   {"label", "kind", "total", "done", "started_ms", "updated_ms", "group",
##    "part", "pid", "status"}
## with status "running", "done", or "failed"; times are wall-clock ms since
## the Unix epoch, `part` "k/N" (k from 0) when a group's processes split the
## work, and `kind` what a unit is ("runs", "encounters", "teams", "builds").
## Rules: only the tools' entry scripts use it, never library code or
## src/sim/, so a test that calls a report library writes nothing; a write
## happens at most every WRITE_EVERY_MS of wall-clock time (and at start and
## finish), goes to a temp file renamed over the real one, so a reader never
## sees half a file; and any I/O error is ignored, so progress never breaks a
## run. Off with --no-progress or RIFTRITE_PROGRESS=0; RIFTRITE_PROGRESS_DIR
## writes somewhere else (the tests).

const WRITE_EVERY_MS: int = 2000
const DIR_NAME: String = ".progress"

var id: String = ""
var label: String = ""
var kind: String = ""
var total: int = 0
var done: int = 0
var group: String = ""
var part: String = ""
var status: String = "running"
var started_ms: int = 0
var enabled: bool = false
## Times the file was written (for the tests).
var writes: int = 0
var _last_write_ticks: int = -WRITE_EVERY_MS


## Off when the tool was given --no-progress or RIFTRITE_PROGRESS is "0".
static func wanted() -> bool:
	return not OS.get_cmdline_user_args().has("--no-progress") and OS.get_environment("RIFTRITE_PROGRESS") != "0"


## Where the files go: RIFTRITE_PROGRESS_DIR, else <repo>/.progress.
static func directory() -> String:
	var dir: String = OS.get_environment("RIFTRITE_PROGRESS_DIR")
	return dir if not dir.is_empty() else ProjectSettings.globalize_path("res://").path_join(DIR_NAME)


## A process's own id: the tool's name and the process id.
static func own_id(tool_name: String) -> String:
	return "%s-%d" % [tool_name, OS.get_process_id()]


## --progress-group=<name> if given (a --jobs parent passes it to its
## children), else `fallback`.
static func group_arg(fallback: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--progress-group="):
			return arg.trim_prefix("--progress-group=")
	return fallback


func start(job_id: String, job_label: String, job_kind: String, job_total: int, job_group: String = "", job_part: String = "") -> void:
	enabled = wanted()
	id = job_id
	label = job_label
	kind = job_kind
	total = job_total
	group = job_group if not job_group.is_empty() else job_id
	part = job_part
	done = 0
	status = "running"
	started_ms = _now_ms()
	_write()


## `units_done` units are done; written if WRITE_EVERY_MS has passed.
func step(units_done: int) -> void:
	done = units_done
	if Time.get_ticks_msec() - _last_write_ticks >= WRITE_EVERY_MS:
		_write()


func finish(final_status: String = "done") -> void:
	status = final_status
	if final_status == "done":
		done = total
	_write()


func path() -> String:
	return directory().path_join(id + ".json")


func to_dict() -> Dictionary:
	return {"label": label, "kind": kind, "total": total, "done": done, "started_ms": started_ms, "updated_ms": _now_ms(),
		"group": group, "part": part, "pid": OS.get_process_id(), "status": status}


func _write() -> void:
	_last_write_ticks = Time.get_ticks_msec()
	if not enabled or id.is_empty():
		return
	var dir: String = directory()
	if DirAccess.make_dir_recursive_absolute(dir) != OK:
		return
	# Keeps Godot's importer out of the folder.
	if not FileAccess.file_exists(dir.path_join(".gdignore")):
		var ignore: FileAccess = FileAccess.open(dir.path_join(".gdignore"), FileAccess.WRITE)
		if ignore != null:
			ignore.close()
	var temp: String = path() + ".tmp"
	var file: FileAccess = FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(to_dict()))
	file.close()
	if DirAccess.rename_absolute(temp, path()) == OK:
		writes += 1


static func _now_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000.0)
