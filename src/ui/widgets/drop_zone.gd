class_name DropZone
extends PanelContainer
## A labeled area that accepts dragged items (and, optionally, essences) and
## hands the drag data to `on_drop`. Used for the stash, the end of a hero's
## row, selling, and throwing things away.

var on_drop: Callable
var accepts_essences: bool = false


static func make(text: String, action: Callable, essences: bool = false, width: int = 120) -> DropZone:
	var zone := DropZone.new()
	zone.on_drop = action
	zone.accepts_essences = essences
	zone.custom_minimum_size = Vector2(width, UiStyle.TILE_HEIGHT)
	zone.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BACKGROUND, UiStyle.BORDER))
	var label: Label = UiStyle.label(text, 14, UiStyle.TEXT_DIM)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.add_child(label)
	return zone


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	return payload.has("uid") or (accepts_essences and payload.has("pouch_index"))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_drop.call(data)
