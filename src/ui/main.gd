class_name Main
extends Control
## The game's root: the title backdrop, the current screen in the middle, and
## the hover card and a toast floating over everything. After the rebuild's
## gut (docs/plans/rebuild-build-order.md, phase 0) the only screen is the
## title; Practice (phase 3) and the run (phase 5) add theirs.

## The title backdrop (tools/art/backdrops.py).
const BACKDROP: String = "res://art/ui/backgrounds/title.svg"
## Where the old game kept its run. Saves from before the rebuild can't be
## loaded, so the title drops one quietly (decided in the build order).
const OLD_SAVE_PATH: String = "user://run.json"

## Tests point this somewhere harmless.
var old_save_path: String = OLD_SAVE_PATH
var screen: UiScreen = null
var hover_card: HoverCard
var backdrop: TextureRect
var _screen_slot: ScrollContainer
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
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
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
	_toast.add_theme_color_override("font_outline_color", UiStyle.INK_900)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)
	show_screen(TitleScreen.new())


## Replaces the current screen.
func show_screen(next: UiScreen) -> void:
	if screen != null:
		_screen_slot.remove_child(screen)
		screen.queue_free()
	screen = next
	screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_screen_slot.add_child(screen)
	screen.setup()
	backdrop.visible = screen.shows_backdrop


## A short message over everything.
func toast(message: String, color: Color = UiStyle.TEXT) -> void:
	_toast.show_message(message, color)


## Deletes a save from before the rebuild, if there is one.
static func drop_old_save(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
