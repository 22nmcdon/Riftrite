extends GutTest
## RunSession (docs/plans/first-ui.md): every action goes through
## RunFlow/RunActions, saves the run, and emits `changed` with its Result.

const U = preload("res://tests/ui/ui_test_kit.gd")

var _results: Array[RunActions.Result] = []


func _watch(session: RunSession) -> void:
	_results.clear()
	session.changed.connect(func(result: RunActions.Result) -> void: _results.append(result))


func test_a_new_run_saves_and_emits() -> void:
	var session: RunSession = U.session()
	_watch(session)
	assert_false(session.has_save())
	session.new_run(7)
	assert_eq(session.state.phase, "start_hero")
	assert_true(session.has_save())
	assert_eq(_results.size(), 1)
	assert_true(_results[0].ok)


func test_actions_save_and_emit() -> void:
	var session: RunSession = U.at_caravan()
	_watch(session)
	var gold: int = session.state.gold
	var result: RunActions.Result = session.reroll()
	assert_true(result.ok)
	assert_eq(_results, [result] as Array[RunActions.Result])
	var loaded: Array = RunSave.load_run(session.content, U.SAVE_PATH)
	assert_eq(session.state.gold, gold - 1, "the first reroll costs 1")
	assert_eq((loaded[0] as RunState).gold, session.state.gold, "the save has the reroll")


func test_a_refused_action_passes_its_error_and_changes_nothing() -> void:
	var session: RunSession = U.at_caravan()
	_watch(session)
	var before: String = FileAccess.get_file_as_string(U.SAVE_PATH)
	var result: RunActions.Result = session.pick_stop(0)
	assert_false(result.ok)
	assert_eq(_results.size(), 1)
	assert_false(_results[0].ok)
	assert_ne(_results[0].error, "")
	assert_eq(FileAccess.get_file_as_string(U.SAVE_PATH), before)


func test_continue_and_abandon() -> void:
	var session: RunSession = U.at_caravan(11)
	session.reroll()
	var other: RunSession = RunSession.make(session.content, session.run, U.SAVE_PATH)
	assert_eq(other.continue_run(), "")
	assert_eq([other.state.phase, other.state.gold, other.state.day], [session.state.phase, session.state.gold, session.state.day])
	other.abandon()
	assert_null(other.state)
	assert_false(other.has_save())
	assert_ne(other.continue_run(), "", "nothing to continue")


func test_fight_keeps_the_fight_for_playback() -> void:
	var session: RunSession = U.at_fight()
	assert_null(session.last_fight)
	assert_true(session.fight().ok)
	assert_not_null(session.last_fight)
	assert_not_null(session.last_setup)
	assert_ne(session.state.phase, "fight")


func after_all() -> void:
	if FileAccess.file_exists(U.SAVE_PATH):
		DirAccess.remove_absolute(U.SAVE_PATH)
