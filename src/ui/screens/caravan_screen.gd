class_name CaravanScreen
extends UiScreen
## The Caravan (docs/plans/ui-overhaul.md, 3.4): wares as large cards on a
## cloth stall, heroes for hire beside it, and along the bottom the reroll,
## a coin dish to sell into, and the way out. Click a ware to buy it (it
## goes to your stash). A ware that would upgrade something you hold lights
## up, and buying it combines it straight into your copy. Drag one of your
## items onto the dish to sell it.


func build() -> void:
	heading("The Caravan")
	hint("Click a ware to buy it; it goes to your stash, below. A gold-framed ware combines with an item you hold. Hover anything to read about it.")
	var items: Array[int] = []
	var heroes: Array[int] = []
	for i: int in session.state.offers.size():
		if session.state.offers[i]["type"] == "hero":
			heroes.append(i)
		else:
			items.append(i)
	var market := HBoxContainer.new()
	market.add_theme_constant_override("separation", 20)
	market.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(market)
	# The stall: wares on red cloth.
	var stall := PanelContainer.new()
	stall.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stall.size_flags_stretch_ratio = 2.0
	stall.add_theme_stylebox_override("panel", UiStyle.chrome("panel_stall", 30, 24))
	market.add_child(stall)
	var stall_box := VBoxContainer.new()
	stall_box.add_theme_constant_override("separation", 14)
	stall.add_child(stall_box)
	stall_box.add_child(UiStyle.heading("Wares", 24, UiStyle.HIGHLIGHT))
	var wares := HFlowContainer.new()
	wares.add_theme_constant_override("h_separation", 16)
	wares.add_theme_constant_override("v_separation", 16)
	for i: int in items:
		wares.add_child(OfferView.make(session, session.state.offers[i], _buy.bind(i), session.upgrade_target(i) >= 0, true))
	stall_box.add_child(wares)
	# Heroes for hire.
	var hire := PanelContainer.new()
	hire.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hire.add_theme_stylebox_override("panel", UiStyle.chrome("panel_slate", 24, 20))
	market.add_child(hire)
	var hire_box := VBoxContainer.new()
	hire_box.add_theme_constant_override("separation", 12)
	hire.add_child(hire_box)
	hire_box.add_child(UiStyle.heading("For hire", 24, UiStyle.HIGHLIGHT))
	for i: int in heroes:
		hire_box.add_child(OfferView.make(session, session.state.offers[i], _buy.bind(i), false, true))
	if heroes.is_empty():
		hire_box.add_child(UiStyle.label("No one is looking for work today.", 16, UiStyle.TEXT_DIM))
	# Reroll, sell, leave.
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 16)
	add_child(line)
	var reroll: Button = UiStyle.button("Reroll (%d gold)" % session.reroll_cost(), func() -> void: session.reroll())
	reroll.custom_minimum_size = Vector2(0, 56)
	line.add_child(reroll)
	var dish: DropZone = DropZone.make("Coin dish: drop an item here to sell it (half price)", func(data: Dictionary) -> void: session.sell(data["uid"]), false, 360,
		func(data: Dictionary) -> bool: return session.would_succeed(func(state: RunState) -> RunActions.Result: return RunFlow.sell(state, session.content, session.run, data["uid"])), 56)
	line.add_child(dish)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(spacer)
	var leave: Button = UiStyle.primary(UiStyle.button("Leave the Caravan  ›", func() -> void: session.leave_caravan()))
	leave.add_theme_font_size_override("font_size", 22)
	leave.custom_minimum_size = Vector2(260, 56)
	line.add_child(leave)


func _buy(index: int) -> void:
	session.buy(index)
