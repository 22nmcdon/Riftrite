class_name CaravanScreen
extends UiScreen
## The Caravan: click a ware to buy it (into the stash). A ware that would
## upgrade something you hold lights up, and buying it combines it straight
## into your copy. Drag an item onto "Sell" to sell it.


func build() -> void:
	heading("The Caravan")
	hint("Click a ware to buy it (it goes to your stash). A gold-bordered ware upgrades an item you hold: buying it combines it straight in. Hover anything to read it in the panel on the right.")
	var items: Array[int] = []
	var heroes: Array[int] = []
	for i: int in session.state.offers.size():
		if session.state.offers[i]["type"] == "hero":
			heroes.append(i)
		else:
			items.append(i)
	add_child(offer_row(items, _buy, func(i: int) -> bool: return session.upgrade_target(i) >= 0))
	add_child(offer_row(heroes, _buy))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.add_child(UiStyle.button("Reroll (%d gold)" % session.reroll_cost(), func() -> void: session.reroll()))
	line.add_child(DropZone.make("Drop an item here to sell it (half price)", func(data: Dictionary) -> void: session.sell(data["uid"]), false, 220))
	line.add_child(UiStyle.button("Leave the Caravan", func() -> void: session.leave_caravan()))
	add_child(line)
	add_child(GuildPanel.make(session))


func _buy(index: int) -> void:
	session.buy(index)
