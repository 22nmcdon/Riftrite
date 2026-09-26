class_name Main
extends Control
## The game's root (docs/plans/ui-overhaul.md, 3): the day bar on top, the
## current screen in the middle, and on run screens the guild bar along the
## bottom, with the open hero's sheet just above it. The item panel
## (Inspector) pops up at the right while an item is selected; the hover
## card and a toast float over everything. It picks the screen from the
## run's phase and rebuilds everything after every change (screens never
## keep state of their own between changes).

## Screens by run phase.
const SCREENS: Dictionary[String, String] = {
	"start_hero": "run_start", "start_package": "run_start",
	"caravan": "caravan", "stop_choice": "stop_choice", "stop": "stop",
	"fight": "fight", "rewards": "rewards", "act_end": "run_end", "run_over": "run_end",
}
const SCREEN_DIR: String = "res://src/ui/screens/%s_screen.gd"
## Phases whose screens show the guild bar.
const GUILD_PHASES: Array[String] = ["caravan", "stop_choice", "stop", "fight", "rewards"]
## The title backdrop (tools/art/backdrops.py), shown behind the title, the
## run start, and the run's end.
const BACKDROP: String = "res://art/ui/backgrounds/title.svg"

var session: RunSession
var screen: UiScreen = null
var _day_slot: MarginContainer
var _screen_slot: ScrollContainer
## The open hero's sheet, then the guild bar (empty off run screens).
var _sheet_slot: MarginContainer
var _guild_slot: MarginContainer
var inspector: Inspector
var hover_card: HoverCard
var _backdrop: TextureRect
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
	_backdrop = TextureRect.new()
	_backdrop.texture = load(BACKDROP) as Texture2D
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)
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
	_screen_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_screen_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_slot.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_screen_slot)
	_sheet_slot = MarginContainer.new()
	column.add_child(_sheet_slot)
	_guild_slot = MarginContainer.new()
	column.add_child(_guild_slot)
	inspector = Inspector.make(session)
	inspector.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	inspector.offset_left = -Inspector.WIDTH - 16
	inspector.offset_right = -16
	inspector.offset_top = 76
	inspector.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(inspector)
	hover_card = HoverCard.make()
	add_child(hover_card)
	_toast = Toast.new()
	_toast.visible = false
	_toast.add_theme_font_size_override("font_size", 20)
	# Just under the day bar, clear of the guild bar.
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y += 64
	_toast.add_theme_color_override("font_outline_color", UiStyle.INK_900)
	_toast.add_theme_constant_override("outline_size", 8)
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
		(screen as FightScreen).started.connect(_update_guild)
	_update_guild()


## Whether this screen shows the guild (bar, sheet, and item panel): run
## screens between fights, and a fight before it starts.
func shows_guild() -> bool:
	var phase: String = session.state.phase if session.state != null else ""
	var playing: bool = screen is FightScreen and (screen as FightScreen).playing
	return GUILD_PHASES.has(phase) and not playing


## Rebuilds the guild bar and the open hero's sheet, and shows the item
## panel while an item is selected.
func _update_guild() -> void:
	for slot: MarginContainer in [_sheet_slot, _guild_slot]:
		for child: Node in slot.get_children():
			slot.remove_child(child)
			child.queue_free()
	var phase: String = session.state.phase if session.state != null else ""
	_backdrop.visible = phase.is_empty() or phase.begins_with("start") or phase == "act_end" or phase == "run_over"
	var guild: bool = shows_guild()
	if guild:
		_guild_slot.add_child(GuildBar.make(session))
		var hero: RunHero = session.open_hero_or_null()
		if hero != null:
			_sheet_slot.add_child(HeroSheet.make(session, hero))
	inspector.refresh()
	inspector.visible = guild and inspector.has_selection()


## The guild bar in the scene, or null (off run screens).
func guild_bar() -> GuildBar:
	return _guild_slot.get_child(0) as GuildBar if _guild_slot.get_child_count() > 0 else null


## The open hero's sheet, or null.
func hero_sheet() -> HeroSheet:
	return _sheet_slot.get_child(0) as HeroSheet if _sheet_slot.get_child_count() > 0 else null


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
