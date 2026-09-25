class_name EssenceChip
extends PanelContainer
## An essence in the pouch: drag it onto an item to infuse it.

var pouch_index: int


static func make(content: ContentDb, essence_id: String, at: int) -> EssenceChip:
	var chip := EssenceChip.new()
	chip.pouch_index = at
	var color: Color = UiStyle.ESSENCE.get(essence_id, UiStyle.TEXT)
	chip.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, color))
	chip.add_child(UiStyle.label(content.essences[essence_id].name, 14, color))
	chip.tooltip_text = "%s essence: drag onto an item to infuse it" % content.essences[essence_id].name
	return chip


func _get_drag_data(_at_position: Vector2) -> Variant:
	set_drag_preview(UiStyle.label("● essence", 14, UiStyle.HIGHLIGHT))
	return {"pouch_index": pouch_index}
