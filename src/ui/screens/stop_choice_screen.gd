class_name StopChoiceScreen
extends UiScreen
## Pick one of the day's stop nodes (docs/plans/stop-nodes.md): big cards,
## each with its kind's icon over its name, its kind, and its blurb.

const KIND_LABELS: Dictionary[String, String] = {
	"forge": "Forge", "loot": "Loot", "vault": "Vault", "retrain": "Retrain", "event": "Event", "fight": "Extra fight",
}
## The icon for each kind (art/ui/icons/<name>.svg).
const KIND_ICONS: Dictionary[String, String] = {
	"forge": "stop_forge", "loot": "stop_loot", "vault": "stop_vault", "retrain": "stop_retrain", "event": "stop_event", "fight": "fight_normal",
}


func build() -> void:
	heading("Where to, before the fight?")
	hint("Pick one stop. Then comes today's fight.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i: int in session.state.offers.size():
		row.add_child(_card(session.state.offers[i]["stop"], i))
	add_child(row)


## A node as a big card: its kind's icon over its name, kind, and blurb.
func _card(node_id: String, index: int) -> Button:
	var kind: String = session.run.node_kind(node_id)
	var text: String = "%s\n(%s)\n\n%s" % [session.run.node_name(node_id), KIND_LABELS.get(kind, ""), session.run.node_text(node_id)]
	var button: Button = UiStyle.button(text, _pick.bind(index))
	button.custom_minimum_size = Vector2(320, 340)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_path: String = UiStyle.ICON_DIR % KIND_ICONS.get(kind, "stop_event")
	button.icon = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
	button.expand_icon = true
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 128)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_stylebox_override("normal", UiStyle.chrome("panel_oak", 28, 28))
	button.add_theme_stylebox_override("hover", UiStyle.chrome("button_hover", 28, 28))
	button.add_theme_stylebox_override("pressed", UiStyle.chrome("button_pressed", 28, 28))
	return button


func _pick(index: int) -> void:
	session.pick_stop(index)
