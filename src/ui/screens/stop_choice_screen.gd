class_name StopChoiceScreen
extends UiScreen
## Pick one of the day's stop nodes (docs/plans/stop-nodes.md): each shows its
## name, what kind of stop it is, and its blurb.

const KIND_LABELS: Dictionary[String, String] = {
	"forge": "Forge", "loot": "Loot", "vault": "Vault", "retrain": "Retrain", "event": "Event", "fight": "Extra fight",
}


func build() -> void:
	heading("Where to, before the fight?")
	hint("Pick one stop. Then comes today's fight.")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for i: int in session.state.offers.size():
		var node_id: String = session.state.offers[i]["stop"]
		var text: String = "%s  (%s)\n%s" % [session.run.node_name(node_id), KIND_LABELS.get(session.run.node_kind(node_id), ""), session.run.node_text(node_id)]
		var button: Button = UiStyle.button(text, _pick.bind(i))
		button.custom_minimum_size = Vector2(420, 110)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(button)
	add_child(row)
	add_child(GuildPanel.make(session))


func _pick(index: int) -> void:
	session.pick_stop(index)
