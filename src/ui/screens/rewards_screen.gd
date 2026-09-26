class_name RewardsScreen
extends UiScreen
## After a win: the spoils on a parchment ledger. Take or pass each reward
## (a relic choice takes one of three).


func build() -> void:
	add_theme_constant_override("separation", 18)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	add_child(spacer)
	var page: VBoxContainer = card("panel_parchment", 1000)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	page.add_child(top)
	top.add_child(UiStyle.icon("stop_loot", 80))
	var words := VBoxContainer.new()
	top.add_child(words)
	words.add_child(UiStyle.heading("Spoils", 32, UiStyle.OAK_600))
	words.add_child(UiStyle.label("Take what you want; anything left behind is lost when you continue.", 17, UiStyle.INK_TEXT))
	var singles: Array[int] = []
	var relic_choice: Array[int] = []
	for i: int in session.state.offers.size():
		if session.state.offers[i].get("group", "") == "relic_choice":
			relic_choice.append(i)
		else:
			singles.append(i)
	if not singles.is_empty():
		page.add_child(offer_row(singles, _take))
	if not relic_choice.is_empty():
		page.add_child(UiStyle.heading("Choose one relic (or none):", 20, UiStyle.OAK_600))
		page.add_child(offer_row(relic_choice, _take))
	var go: Button = primary_button("Continue", func() -> void: session.done())
	go.size_flags_horizontal = Control.SIZE_SHRINK_END
	page.add_child(go)


func _take(index: int) -> void:
	session.take(index)
