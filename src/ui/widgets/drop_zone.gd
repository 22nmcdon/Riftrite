class_name DropZone
extends PanelContainer
## A labeled area that accepts dragged items (and, optionally, essences) and
## hands the drag data to `on_drop`. Used for the stash, the end of a hero's
## row, selling, and throwing things away. With a `check`, it outlines
## itself green or red while something is dragged over it (would the drop
## work?), and refuses drops that wouldn't.

var on_drop: Callable
## Optional: payload -> bool, whether the drop would work.
var check: Callable
var accepts_essences: bool = false
var _style: StyleBoxFlat
var _checks: Dictionary[String, bool] = {}


static func make(text: String, action: Callable, essences: bool = false, width: int = 120, would_work: Callable = Callable()) -> DropZone:
	var zone := DropZone.new()
	zone.on_drop = action
	zone.check = would_work
	zone.accepts_essences = essences
	zone.custom_minimum_size = Vector2(width, UiStyle.TILE_HEIGHT)
	zone._style = UiStyle.box(UiStyle.BACKGROUND, UiStyle.BORDER)
	zone._style.draw_center = true
	zone.add_theme_stylebox_override("panel", zone._style)
	var label: Label = UiStyle.label(text, 14, UiStyle.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(label)
	zone.mouse_exited.connect(zone._outline.bind(Color()))
	return zone


func _outline(color: Color) -> void:
	if color == Color():
		add_theme_stylebox_override("panel", _style)
		return
	var style: StyleBoxFlat = _style.duplicate()
	style.border_color = color
	style.set_border_width_all(3)
	add_theme_stylebox_override("panel", style)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_checks.clear()
		_outline(Color())


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	if not (payload.has("uid") or (accepts_essences and payload.has("pouch_index"))):
		return false
	var ok: bool = true
	if check.is_valid():
		var key: String = str(payload)
		if not _checks.has(key):
			_checks[key] = check.call(payload)
		ok = _checks[key]
	_outline(UiStyle.GOOD if ok else UiStyle.BAD)
	return ok


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_outline(Color())
	on_drop.call(data)
