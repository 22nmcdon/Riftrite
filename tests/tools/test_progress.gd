extends GutTest
## The long tools' progress files (tools/progress.gd): a valid file, written
## at most every 2 seconds, renamed into place, finished with a status; and
## run_runner.gd's report the same with progress on and off.

const Progress = preload("res://tools/progress.gd")

var _dir: String = ""


func before_each() -> void:
	_dir = ProjectSettings.globalize_path("user://test_progress_%d" % Time.get_ticks_usec())
	OS.set_environment("RIFTRITE_PROGRESS_DIR", _dir)


func after_each() -> void:
	OS.unset_environment("RIFTRITE_PROGRESS_DIR")
	if not DirAccess.dir_exists_absolute(_dir):
		return
	for file_name: String in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file_name))
	DirAccess.remove_absolute(_dir)


func _read(progress: Progress) -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(progress.path()))
	assert_true(data is Dictionary, "a whole JSON object")
	return data if data is Dictionary else {}


func test_start_writes_a_valid_file() -> void:
	var progress := Progress.new()
	progress.start("job-1", "runs (the good bot)", "runs", 40, "group-a", "1/4")
	var data: Dictionary = _read(progress)
	assert_eq(data["label"], "runs (the good bot)")
	assert_eq(data["kind"], "runs")
	assert_eq(int(data["total"]), 40)
	assert_eq(int(data["done"]), 0)
	assert_eq(data["group"], "group-a")
	assert_eq(data["part"], "1/4")
	assert_eq(int(data["pid"]), OS.get_process_id())
	assert_eq(data["status"], "running")
	assert_almost_eq(float(data["started_ms"]), Time.get_unix_time_from_system() * 1000.0, 60000.0, "wall-clock ms")
	assert_true(float(data["updated_ms"]) >= float(data["started_ms"]))


func test_a_group_defaults_to_the_id() -> void:
	var progress := Progress.new()
	progress.start("job-2", "x", "runs", 3)
	assert_eq(_read(progress)["group"], "job-2")


func test_steps_are_throttled_to_every_two_seconds() -> void:
	var progress := Progress.new()
	progress.start("job-3", "x", "runs", 10)
	assert_eq(progress.writes, 1, "start writes")
	progress.step(1)
	progress.step(2)
	assert_eq(progress.writes, 1, "steps within 2s don't write")
	assert_eq(int(_read(progress)["done"]), 0)
	progress._last_write_ticks -= Progress.WRITE_EVERY_MS
	progress.step(3)
	assert_eq(progress.writes, 2, "a step 2s later writes")
	assert_eq(int(_read(progress)["done"]), 3)


func test_the_file_is_renamed_into_place() -> void:
	var progress := Progress.new()
	progress.start("job-4", "x", "runs", 2)
	assert_false(FileAccess.file_exists(progress.path() + ".tmp"), "no temp file left")
	assert_eq(Array(DirAccess.get_files_at(_dir)).filter(func(name: String) -> bool: return name.ends_with(".json")), ["job-4.json"])
	assert_true(FileAccess.file_exists(_dir.path_join(".gdignore")), "the importer stays out")


func test_finish_sets_the_status() -> void:
	var progress := Progress.new()
	progress.start("job-5", "x", "runs", 5)
	progress.step(2)
	progress.finish()
	var data: Dictionary = _read(progress)
	assert_eq(data["status"], "done")
	assert_eq(int(data["done"]), 5)
	var failing := Progress.new()
	failing.start("job-6", "x", "runs", 5)
	failing.step(2)
	failing.finish("failed")
	assert_eq(_read(failing)["status"], "failed")
	assert_eq(int(_read(failing)["done"]), 2, "a failed job keeps how far it got")


func test_off_writes_nothing() -> void:
	OS.set_environment("RIFTRITE_PROGRESS", "0")
	var progress := Progress.new()
	progress.start("job-7", "x", "runs", 5)
	progress.finish()
	OS.unset_environment("RIFTRITE_PROGRESS")
	assert_false(FileAccess.file_exists(progress.path()))
	assert_eq(progress.writes, 0)


func test_an_unwritable_place_is_ignored() -> void:
	OS.set_environment("RIFTRITE_PROGRESS_DIR", "/dev/null/nowhere")
	var progress := Progress.new()
	progress.start("job-8", "x", "runs", 5)
	progress.step(1)
	progress.finish()
	assert_eq(progress.writes, 0, "no file, and the run goes on")
	assert_engine_error("Could not create directory")
	assert_engine_error("Could not create directory")


## Progress changes no run: the same report with it on (one process and two,
## the two claiming seeds from a shared list) and off.
func test_run_runner_reports_the_same_with_progress_on_and_off() -> void:
	var off: String = _run_runner(["--no-progress"])
	var on: String = _run_runner([])
	assert_true(off.contains("Runs: 3"), "the report printed")
	assert_eq(on, off)
	var files: Array = Array(DirAccess.get_files_at(_dir)).filter(func(name: String) -> bool: return name.ends_with(".json"))
	assert_eq(files.size(), 1, "one process, one file")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(_dir.path_join(str(files[0]))))
	assert_eq(data["status"], "done")
	assert_eq(int(data["done"]), 3)
	assert_eq(data["part"], "0/1")
	DirAccess.remove_absolute(_dir.path_join(str(files[0])))
	assert_eq(_run_runner(["--jobs=2"]), off, "the same split over two processes")
	var parts: Array = Array(DirAccess.get_files_at(_dir)).filter(func(name: String) -> bool: return name.ends_with(".json"))
	assert_eq(parts.size(), 2, "a file a process")
	var groups: Dictionary = {}
	var done: int = 0
	for file_name: Variant in parts:
		var part: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_dir.path_join(str(file_name))))
		groups[part["group"]] = true
		assert_eq(part["status"], "done")
		assert_eq(int(part["done"]), int(part["total"]), "a part's total ends as what it played")
		done += int(part["done"])
	assert_eq(groups.size(), 1, "the parts share a group")
	assert_eq(done, 3, "each seed claimed and played once between them")
	var leftovers: Array = Array(DirAccess.get_directories_at(ProjectSettings.globalize_path("user://run_parts"))).filter(func(name: String) -> bool: return name.begins_with("claims_"))
	assert_eq(leftovers, [], "the claims are cleared")


func _run_runner(extra: Array[String]) -> String:
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", "tools/run_runner.gd", "--", "--runs=3", "--bot=random"]
	args.append_array(extra)
	var output: Array = []
	OS.execute(OS.get_executable_path(), args, output)
	var text: String = "".join(output)
	return text.substr(text.find("Runs: "))
