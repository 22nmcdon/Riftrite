extends GutTest
## The playtest journal: every run writes what happened to a JSON file, for
## reading after a playtest (docs/plans/slice-content.md).

const U = preload("res://tests/ui/ui_test_kit.gd")
const DIR: String = "user://test_playtests"


func _session() -> RunSession:
	var plain: RunSession = U.session()
	return RunSession.make(plain.content, plain.run, U.SAVE_PATH, DIR)


func _read(session: RunSession) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(session.journal.path()))


func test_a_run_writes_its_journal() -> void:
	var session: RunSession = _session()
	session.new_run(21)
	assert_true(FileAccess.file_exists(DIR.path_join("run_21.json")))
	session.pick_start_hero(0)
	session.pick_package(0)
	session.reroll()
	var data: Dictionary = _read(session)
	assert_eq([int(data["seed"]), int(data["sessions"])], [21, 1])
	var did: Array = (data["actions"] as Array).map(func(entry: Dictionary) -> String: return entry["did"])
	assert_eq(did.size(), 4, "new run, hero, package, reroll: %s" % [did])
	assert_string_contains(did[3], "rerolled")
	assert_eq([int((data["actions"] as Array)[3]["day"]), (data["actions"] as Array)[3]["phase"]], [1, "caravan"])


func test_fights_are_recorded_with_the_guild() -> void:
	var session: RunSession = _session()
	session.new_run(21)
	session.pick_start_hero(0)
	session.pick_package(0)
	var encounter: String = session.state.encounter_id
	session.leave_caravan()
	session.pick_stop(0)
	session.leave_stop()
	session.fight()
	var fight: Dictionary = (_read(session)["fights"] as Array)[0]
	assert_eq([int(fight["day"]), fight["encounter"]], [1, encounter])
	assert_true(["victory", "defeat", "tie"].has(fight["outcome"]))
	assert_gt(float(fight["seconds"]), 0.0)
	assert_eq((fight["guild"] as Array)[0]["hero"], session.state.heroes[0].hero_id)


func test_continuing_picks_up_the_journal_and_the_end_is_recorded() -> void:
	var session: RunSession = _session()
	session.new_run(22)
	session.pick_start_hero(0)
	var again: RunSession = RunSession.make(session.content, session.run, U.SAVE_PATH, DIR)
	assert_eq(again.continue_run(), "")
	var data: Dictionary = _read(again)
	assert_eq(int(data["sessions"]), 2)
	assert_eq((data["actions"] as Array).size(), 2, "the first session's actions are kept")
	again.state.phase = "run_over"
	again.journal.action(again.state, "the guild falls")
	assert_eq(_read(again)["ending"]["phase"], "run_over")


func test_sessions_without_a_journal_write_nothing() -> void:
	var session: RunSession = U.session()
	assert_null(session.journal)
	session.new_run(23)
	assert_false(FileAccess.file_exists(DIR.path_join("run_23.json")))


func after_each() -> void:
	for file: String in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(file))
	if FileAccess.file_exists(U.SAVE_PATH):
		DirAccess.remove_absolute(U.SAVE_PATH)
