class_name Main
extends Control
## The game's root: the title backdrop, the current screen in the middle, and
## the hover card and a toast floating over everything. After the rebuild's
## gut (docs/plans/rebuild-build-order.md, phase 0) the screens are the
## title and Practice (phase 3: the encounter list, then placement and the
## fight on ArenaScreen), and the run (phase 5: the new-run screen, then day
## by day on RunDayScreen, and each fight on ArenaScreen).
## Main moves between screens on their signals. Practice's session (the
## remembered formation, speed, and seed) lives here while the game is open;
## the run's session is saved after every action (RunSave), and Continue on
## the title loads it.

## The title backdrop (tools/art/backdrops.py).
const BACKDROP: String = "res://art/ui/backgrounds/title.svg"
## Where the old game kept its run. Saves from before the rebuild can't be
## loaded, so the title drops one quietly (decided in the build order).
const OLD_SAVE_PATH: String = "user://run.json"

## Tests point this somewhere harmless.
var old_save_path: String = OLD_SAVE_PATH
var screen: UiScreen = null
## Made the first time Practice opens (it loads the content then).
var practice: PracticeSession = null
## The run under way (null: none open).
var run_session: RunSession = null
## Where the run is saved (tests point it somewhere harmless).
var run_save_path: String = RunSave.PATH
## Endless's records (phase 8 part 1; tests point it elsewhere).
var records_path: String = RunRecords.PATH
var _run_content: RunContent = null
var hover_card: HoverCard
var backdrop: TextureRect
var _screen_slot: ScrollContainer
var _margin: MarginContainer
var _toast: Toast


func _ready() -> void:
	drop_old_save(old_save_path)
	theme = UiStyle.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	backdrop = TextureRect.new()
	backdrop.texture = load(BACKDROP) as Texture2D
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin = margin
	add_child(margin)
	_screen_slot = ScrollContainer.new()
	_screen_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_slot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(_screen_slot)
	hover_card = HoverCard.make()
	add_child(hover_card)
	_toast = Toast.new()
	_toast.visible = false
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y += 64
	_toast.add_theme_color_override("font_outline_color", UiStyle.NAVY_900)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	show_title()


func show_title() -> void:
	var title := TitleScreen.new()
	title.can_continue = RunSave.has_save(run_save_path)
	title.practice_requested.connect(show_encounters)
	title.run_requested.connect(show_run_start)
	title.continue_requested.connect(continue_run)
	show_screen(title)


## The run's content, loaded the first time a run opens.
func run_content() -> RunContent:
	if _run_content == null:
		_run_content = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))
	return _run_content


## Vowing the heroes for a new run, with a seed drawn now (the only thing
## the clock decides; the run itself is its seed's).
func show_run_start(run_seed: int = 0) -> void:
	if run_seed <= 0:
		run_seed = int(Time.get_ticks_usec() % 1000000) + 1
	var start: RunStartScreen = RunStartScreen.make(run_content(), run_seed)
	start.run_started.connect(start_run)
	start.back_requested.connect(show_title)
	show_screen(start)


func start_run(vows: Dictionary[String, String], run_seed: int, testing: bool = false) -> void:
	var errors: Array[String] = []
	run_session = RunSession.begin(run_content(), run_seed, vows, errors, run_save_path, testing)
	if run_session != null:
		run_session.records_path = records_path
	if run_session == null:
		toast(errors[0] if not errors.is_empty() else "The run couldn't start", UiStyle.BAD)
		return
	run_session.save()
	show_day()


## Loads the saved run and goes on from it.
func continue_run() -> void:
	var state: RunState = RunSave.load_state(run_save_path)
	if state == null:
		RunSave.erase(run_save_path)
		toast("That run was saved by another version, so it can't be loaded.", UiStyle.BAD)
		show_title()
		return
	run_session = RunSession.over(run_content(), RunFlow.resume(run_content(), state), run_save_path)
	run_session.records_path = records_path
	show_day()


## The run's day between fights.
func show_day() -> void:
	var day: RunDayScreen = RunDayScreen.make(run_session)
	day.fight_requested.connect(show_run_fight)
	day.finished.connect(end_run)
	show_screen(day)


## The waiting fight (the day's, or a Hunt), placed and played on the arena.
func show_run_fight() -> void:
	var arena: ArenaScreen = ArenaScreen.make(run_session, run_session.flow.fight_encounter())
	arena.back_requested.connect(show_day)
	arena.run_fight_done.connect(finish_run_fight)
	show_screen(arena)


## Records the fight the arena played (exactly RunFlow's), saves, and goes
## back to the day.
func finish_run_fight(formation: Dictionary[String, Vector2i], result: FightResult) -> void:
	run_session.remember(formation)
	run_session.flow.record(formation, result)
	run_session.save()
	show_day()


## The run is over: its save goes, and the title comes back.
func end_run() -> void:
	RunSave.erase(run_save_path)
	run_session = null
	show_title()


## Practice's list of encounters.
func show_encounters() -> void:
	if practice == null:
		practice = PracticeSession.make(ContentDb.load_dir("res://data"))
	var list: EncounterListScreen = EncounterListScreen.make(practice.content, practice)
	list.encounter_picked.connect(show_arena)
	list.back_requested.connect(show_title)
	show_screen(list)


## Placement, then the fight, for one encounter.
func show_arena(encounter_id: String) -> void:
	var arena: ArenaScreen = ArenaScreen.make(practice, encounter_id)
	arena.back_requested.connect(show_encounters)
	show_screen(arena)


## Replaces the current screen.
func show_screen(next: UiScreen) -> void:
	if screen != null:
		_screen_slot.remove_child(screen)
		screen.queue_free()
	screen = next
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_slot.add_child(screen)
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 0 if screen.full_bleed else 16)
	screen.setup()
	backdrop.visible = screen.shows_backdrop


## A short message over everything.
func toast(message: String, color: Color = UiStyle.TEXT) -> void:
	_toast.show_message(message, color)


## Deletes a save from before the rebuild, if there is one.
static func drop_old_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
