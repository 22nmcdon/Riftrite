extends RefCounted
## Shared helpers for the UI tests: a session on a test save file, runs
## moved to a phase, and finding controls by their text.

const SAVE_PATH: String = "user://test_ui_run.json"
const K = preload("res://tests/sim/sim_test_kit.gd")

static var _run_content: RunContent


static func session() -> RunSession:
	if _run_content == null:
		_run_content = RunContent.load_dir("res://data", K.content())
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	return RunSession.make(K.content(), _run_content, SAVE_PATH)


## A session with a run at day 1's first stop choice (the first offer of
## each draft pick, gold package).
static func at_start(run_seed: int = 5) -> RunSession:
	var s: RunSession = session()
	s.new_run(run_seed)
	for pick: int in RunState.TEAM_SIZE:
		s.pick_start_hero(0)
	s.pick_package(0)
	return s


## The same, in the first stop's shop (every visit's first offer is a shop).
static func at_shop(run_seed: int = 5) -> RunSession:
	var s: RunSession = at_start(run_seed)
	s.pick_stop(0)
	return s


## The same, moved on to the day's first fight (the first stops, left at
## once, then the first fight offered).
static func at_fight(run_seed: int = 5) -> RunSession:
	var s: RunSession = at_start(run_seed)
	while s.state.phase == "stop_choice" or s.state.phase == "stop":
		if s.state.phase == "stop_choice":
			s.pick_stop(0)
		s.leave_stop()
	s.pick_fight(0)
	return s


## Every descendant of `root` that is a `type` (a class, e.g. Button).
static func find_all(root: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in root.get_children():
		if is_instance_of(child, type):
			found.append(child)
		found.append_array(find_all(child, type))
	return found


## The first button under `root` whose text contains `text`, or null.
static func button(root: Node, text: String) -> Button:
	for node: Node in find_all(root, Button):
		if (node as Button).text.contains(text):
			return node
	return null


## Presses the button under `root` whose text contains `text`. False if
## there's no such button, or it's disabled.
static func press(root: Node, text: String) -> bool:
	var found: Button = button(root, text)
	if found == null or found.disabled:
		return false
	found.pressed.emit()
	return true


## All the label text under `root`, one per line.
static func text_of(root: Node) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for node: Node in find_all(root, Label):
		lines.append((node as Label).text)
	return "\n".join(lines)
