class_name Main
extends Control
## The game's root: a background, the day bar, the current screen, and a
## toast. It picks the screen from the run's phase and rebuilds it after
## every change (screens never keep state of their own between changes).

## Screens by run phase.
const SCREENS: Dictionary[String, String] = {
	"start_hero": "run_start", "start_package": "run_start",
	"caravan": "caravan", "stop_choice": "stop_choice", "stop": "stop",
	"fight": "fight", "rewards": "rewards", "act_end": "run_end", "run_over": "run_end",
}
const SCREEN_DIR: String = "res://src/ui/screens/%s_screen.gd"

var session: RunSession
var screen: UiScreen = null
var _day_slot: MarginContainer
var _screen_slot: ScrollContainer
var inspector: Inspector
var _toast: Toast


func _ready() -> void:
	if session == null:
		session = RunSession.open()
	theme = UiStyle.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	_day_slot = MarginContainer.new()
	column.add_child(_day_slot)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	_screen_slot = ScrollContainer.new()
	_screen_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_slot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(_screen_slot)
	inspector = Inspector.make(session)
	body.add_child(inspector)
	_toast = Toast.new()
	_toast.visible = false
	_toast.add_theme_font_size_override("font_size", 20)
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.position.y -= 80
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	session.changed.connect(_on_changed)
	refresh()


## The screen for the run's phase (the title when there's no run).
func screen_script() -> GDScript:
	var screen_name: String = "title" if session.state == null else SCREENS[session.state.phase]
	return load(SCREEN_DIR % screen_name)


## Rebuilds the day bar and the screen from the session.
func refresh() -> void:
	for child: Node in _day_slot.get_children():
		_day_slot.remove_child(child)
		child.queue_free()
	if session.state != null and not session.state.phase.begins_with("start"):
		_day_slot.add_child(DayBar.make(session))
	var scroll: int = _screen_slot.scroll_vertical
	var same_screen: bool = screen != null and screen.get_script() == screen_script()
	if screen != null:
		_screen_slot.remove_child(screen)
		screen.queue_free()
	screen = (screen_script().new() as UiScreen)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_slot.add_child(screen)
	screen.setup(session)
	if same_screen:
		# Keep the scroll position when the same screen is rebuilt.
		_screen_slot.set_deferred("scroll_vertical", scroll)
	if screen is FightScreen:
		(screen as FightScreen).finished.connect(refresh)
		(screen as FightScreen).started.connect(_update_inspector)
	_update_inspector()


## The inspector shows beside screens with the guild on them.
func _update_inspector() -> void:
	var phase: String = session.state.phase if session.state != null else ""
	var playing: bool = screen is FightScreen and (screen as FightScreen).playing
	inspector.visible = not (phase.is_empty() or phase.begins_with("start") or phase == "act_end" or phase == "run_over" or playing)
	inspector.refresh()


## A run note for the toast: capitalized, with hero ids as names.
func friendly(note: String) -> String:
	var text: String = note
	for hero_id: String in session.content.heroes:
		var pattern := RegEx.new()
		pattern.compile("\\b%s\\b" % hero_id)
		text = pattern.sub(text, session.content.heroes[hero_id].name.split(" of ")[0], true)
	return text[0].to_upper() + text.substr(1)


func _on_changed(result: RunActions.Result) -> void:
	if not result.ok:
		_toast.show_message(friendly(result.error))
		return
	if not result.note.is_empty() and result.note != "selected":
		_toast.show_message(friendly(result.note), UiStyle.GOOD)
	# A fight being played back keeps its screen until Continue.
	if screen is FightScreen and (screen as FightScreen).playing:
		return
	refresh()
