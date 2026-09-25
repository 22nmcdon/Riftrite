class_name RewardsScreen
extends UiScreen
## After a win: take or pass each reward (a relic choice takes one of three).


func build() -> void:
	heading("Spoils")
	var singles: Array[int] = []
	var relic_choice: Array[int] = []
	for i: int in session.state.offers.size():
		if session.state.offers[i].get("group", "") == "relic_choice":
			relic_choice.append(i)
		else:
			singles.append(i)
	if not singles.is_empty():
		add_child(offer_row(singles, _take))
	if not relic_choice.is_empty():
		add_child(UiStyle.label("Choose one relic (or none):", 16, UiStyle.EMBER))
		add_child(offer_row(relic_choice, _take))
	add_child(UiStyle.button("Continue", func() -> void: session.done()))
	add_child(GuildPanel.make(session))


func _take(index: int) -> void:
	session.take(index)
