class_name EssenceChip
extends PanelContainer
## An essence in the pouch: drag it onto an item to infuse it.

var pouch_index: int


static func make(content: ContentDb, essence_id: String, at: int) -> EssenceChip:
	var chip := EssenceChip.new()
	chip.pouch_index = at
	var color: Color = UiStyle.ESSENCE.get(essence_id, UiStyle.TEXT)
	chip.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, color))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(line)
	line.add_child(Glyph.gem(essence_id, 18))
	var name_label: Label = UiStyle.label(content.essences[essence_id].name, 16, color)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(name_label)
	Inspector.hover(chip, "%s essence" % content.essences[essence_id].name, "Drag it onto an item to infuse it, or select an item and use its Infuse button.")
	return chip


func _get_drag_data(_at_position: Vector2) -> Variant:
	set_drag_preview(UiStyle.label("◆ essence", 16, UiStyle.HIGHLIGHT))
	return {"pouch_index": pouch_index}
