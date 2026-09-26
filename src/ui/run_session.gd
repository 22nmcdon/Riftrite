class_name RunSession
extends RefCounted
## The UI's one door into a run: it holds the RunState and the content, calls
## RunFlow/RunActions for every change (the UI never edits state itself),
## saves after each successful action, and emits `changed` with the action's
## Result (a refused action changes nothing and carries its error).

signal changed(result: RunActions.Result)

var content: ContentDb
var run: RunContent
## The current run, or null (on the title screen).
var state: RunState = null
var save_path: String
## The last fight, for playback and the damage meter.
var last_fight: FightResult = null
var last_setup: FightSetup = null
## Tests set this so "New run" is repeatable; otherwise each run gets a
## fresh seed.
var fixed_seed: int = -1
## UI only (not part of the run or its save): the item selected in the
## inspector, or -1.
var selected_uid: int = -1


static func make(fight_content: ContentDb, run_content: RunContent, path: String = RunSave.DEFAULT_PATH) -> RunSession:
	var session := RunSession.new()
	session.content = fight_content
	session.run = run_content
	session.save_path = path
	return session


## Loads the game data from res://data.
static func open(path: String = RunSave.DEFAULT_PATH) -> RunSession:
	var fight_content: ContentDb = ContentDb.load_dir("res://data")
	return make(fight_content, RunContent.load_dir("res://data", fight_content), path)


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## The seed for the next new run (the run itself is deterministic from it).
func next_seed() -> int:
	return fixed_seed if fixed_seed >= 0 else int(Time.get_unix_time_from_system()) ^ Time.get_ticks_usec()


func new_run(run_seed: int) -> void:
	state = RunFlow.new_run(run_seed, content)
	selected_uid = -1
	last_fight = null
	last_setup = null
	_after(RunActions._ok("a new run begins"))


## Loads the saved run. Returns "" or what went wrong.
func continue_run() -> String:
	var loaded: Array = RunSave.load_run(content, save_path)
	var errors: Array[String] = loaded[1]
	if not errors.is_empty():
		return errors[0]
	state = loaded[0]
	selected_uid = -1
	changed.emit(RunActions._ok("the run continues"))
	return ""


## Ends the run and deletes its save (back to the title).
func abandon() -> void:
	state = null
	if has_save():
		DirAccess.remove_absolute(save_path)
	changed.emit(RunActions._ok("back to the title"))


## Selects an item for the inspector (again to clear it). Not a run change:
## nothing is saved, but screens redraw to show the selection.
func select(uid: int) -> void:
	selected_uid = -1 if uid == selected_uid else uid
	changed.emit(RunActions._ok("selected"))


## Would this action succeed right now? `action` takes a RunState and
## returns a Result; it runs on a throwaway copy of the run, so the real run
## never changes (drag feedback uses this to outline drop targets).
func would_succeed(action: Callable) -> bool:
	if state == null:
		return false
	var copy: RunState = RunState.from_dict(state.to_dict(), content)[0]
	return copy != null and (action.call(copy) as RunActions.Result).ok


func _after(result: RunActions.Result) -> RunActions.Result:
	if result.ok and state != null:
		var problem: String = RunSave.save(state, save_path)
		if not problem.is_empty():
			result.note += " (not saved: %s)" % problem
	changed.emit(result)
	return result


# --- the run's flow -------------------------------------------------------------

func pick_start_hero(index: int) -> RunActions.Result:
	return _after(RunFlow.pick_start_hero(state, content, index))


func pick_package(index: int) -> RunActions.Result:
	return _after(RunFlow.pick_package(state, content, run, index))


func buy(index: int) -> RunActions.Result:
	return _after(RunFlow.buy(state, content, index))


func upgrade_target(index: int) -> int:
	return RunFlow.upgrade_target(state, content, index)


func sell(uid: int) -> RunActions.Result:
	return _after(RunFlow.sell(state, content, run, uid))


func sell_price(uid: int) -> int:
	var item: RunItem = state.find_item(uid)
	return run.economy.sell_price(run.economy.item_price[item.tier]) if item != null else 0


func reroll() -> RunActions.Result:
	return _after(RunFlow.reroll(state, content, run))


func reroll_cost() -> int:
	return RunFlow.reroll_cost(state, run)


func leave_caravan() -> RunActions.Result:
	return _after(RunFlow.leave_caravan(state, content, run))


func pick_stop(index: int) -> RunActions.Result:
	return _after(RunFlow.pick_stop(state, content, run, index))


func take(index: int) -> RunActions.Result:
	return _after(RunFlow.take(state, content, index))


func forge_reforge(uid: int) -> RunActions.Result:
	return _after(RunFlow.forge_reforge(state, content, uid))


func retrain(hero_id: String, specialization_id: String) -> RunActions.Result:
	return _after(RunFlow.retrain(state, content, hero_id, specialization_id))


func upgrade(uid: int) -> RunActions.Result:
	return _after(RunFlow.upgrade(state, content, uid))


func leave_stop() -> RunActions.Result:
	return _after(RunFlow.leave_stop(state))


## Runs today's fight and keeps it for playback.
func fight() -> RunActions.Result:
	var out: Array = RunFlow.fight(state, content, run)
	var result: RunActions.Result = out[0]
	if result.ok:
		last_fight = out[1]
		last_setup = out[2]
	return _after(result)


func done() -> RunActions.Result:
	return _after(RunFlow.done(state, content, run))


# --- the guild (between fights) -------------------------------------------------

func move_item(uid: int, to: String, index: int) -> RunActions.Result:
	return _after(RunActions.move_item(state, content, uid, to, index))


func combine(keep_uid: int, new_uid: int) -> RunActions.Result:
	return _after(RunActions.combine_items(state, content, keep_uid, new_uid))


func infuse(uid: int, pouch_index: int) -> RunActions.Result:
	return _after(RunActions.infuse(state, content, uid, pouch_index))


func discard_item(uid: int) -> RunActions.Result:
	return _after(RunActions.discard_item(state, content, uid))


func discard_essence(pouch_index: int) -> RunActions.Result:
	return _after(RunActions.discard_essence(state, content, pouch_index))


func set_row(hero_id: String, row: UnitSetup.Row) -> RunActions.Result:
	return _after(RunActions.set_row(state, hero_id, row))


func set_benched(hero_id: String, benched: bool) -> RunActions.Result:
	return _after(RunActions.set_benched(state, hero_id, benched))


func move_hero(hero_id: String, index: int) -> RunActions.Result:
	return _after(RunActions.move_hero(state, hero_id, index))


func choose_specialization(hero_id: String, specialization_id: String) -> RunActions.Result:
	return _after(RunActions.choose_specialization(state, content, hero_id, specialization_id))
