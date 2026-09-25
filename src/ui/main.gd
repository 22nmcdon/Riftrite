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
	_screen_slot = ScrollContainer.new()
	_screen_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_slot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_screen_slot)
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
	if screen != null:
		_screen_slot.remove_child(screen)
		screen.queue_free()
	screen = (screen_script().new() as UiScreen)
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_slot.add_child(screen)
	screen.setup(session)
	if screen is FightScreen:
		(screen as FightScreen).finished.connect(refresh)


func _on_changed(result: RunActions.Result) -> void:
	if not result.ok:
		_toast.show_message(result.error)
		return
	# A fight being played back keeps its screen until Continue.
	if screen is FightScreen and (screen as FightScreen).playing:
		return
	refresh()
