class_name StopChoiceScreen
extends UiScreen
## Pick one of the day's stops: big cards with the stop's icon.

const BLURBS: Dictionary[String, String] = {
	"forge": "Reforge: strip an infusion from an item (costs gold).",
	"loot": "Something left behind. Take it or leave it.",
	"vault": "Spend a key on a sealed chest.",
	"retrain": "Switch a hero to another of their specializations.",
	"event": "Something stirs off the road.",
	"upgrade": "An anvil before the boss: raise one item a tier, free.",
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


## A stop as a big card: its icon over its name and what it does.
func _card(stop: String, index: int) -> Button:
	var button: Button = UiStyle.button("%s\n\n%s" % [stop.capitalize(), BLURBS.get(stop, "")], _pick.bind(index))
	button.custom_minimum_size = Vector2(320, 340)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.icon = load(UiStyle.ICON_DIR % ("stop_" + stop)) as Texture2D if ResourceLoader.exists(UiStyle.ICON_DIR % ("stop_" + stop)) else null
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
