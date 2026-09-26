class_name StopChoiceScreen
extends UiScreen
## Pick one of the day's stops.

const BLURBS: Dictionary[String, String] = {
	"forge": "Reforge: strip an infusion from an item (costs gold).",
	"loot": "Something left behind. Take it or leave it.",
	"vault": "Spend a key on a sealed chest.",
	"retrain": "Switch a hero to another of their specializations.",
	"event": "Something stirs off the road.",
}


func build() -> void:
	heading("Where to, before the fight?")
	hint("Pick one stop. Then comes today's fight.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i: int in session.state.offers.size():
		var stop: String = session.state.offers[i]["stop"]
		var button: Button = UiStyle.button("%s\n%s" % [stop.capitalize(), BLURBS.get(stop, "")], _pick.bind(i))
		button.custom_minimum_size = Vector2(300, 90)
		row.add_child(button)
	add_child(row)


func _pick(index: int) -> void:
	session.pick_stop(index)
