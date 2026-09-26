class_name StopScreen
extends UiScreen
## The stop being visited: take or pass what's offered (Loot, the Vault,
## events, a won skirmish's spoils), reforge (Forge), retrain, or upgrade an
## item (before the boss). A skirmish still to fight shows the FightScreen.


func build() -> void:
	var state: RunState = session.state
	add_theme_constant_override("separation", 18)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	add_child(spacer)
	match state.stop_kind:
		"forge":
			var forge: VBoxContainer = _stop_card("forge", _title("The Forge"), "Reforging strips an item's infusion (the essences are lost) for %d gold." % session.content.tuning.reforge_gold)
			forge.add_child(_item_buttons(func(item: RunItem) -> bool: return not item.essence_ids.is_empty(), "Reforge", func(uid: int) -> void: session.forge_reforge(uid)))
			forge.add_child(_leave())
		"retrain":
			var retrain: VBoxContainer = _stop_card("retrain", _title("Retrain"), "Switch a hero to another of their specializations.")
			_retrain_options(retrain)
			retrain.add_child(_leave())
		"upgrade":
			var anvil: VBoxContainer = _stop_card("upgrade", "An anvil before the boss", "Raise one item a tier, for free." if not state.stop_used else "The anvil is spent.")
			if not state.stop_used:
				anvil.add_child(_item_buttons(func(item: RunItem) -> bool: return item.tier < 3 and session.content.items[item.item_id].rarity != "legendary", "Upgrade", func(uid: int) -> void: session.upgrade(uid)))
			anvil.add_child(_leave())
		_:
			# Events, Loot, the Vault, and a fought skirmish: an illustrated
			# parchment card with the node's name and blurb.
			var title: String = _title(state.stop_kind.capitalize())
			var text: String = session.run.node_text(state.stop_node) if session.run.node_pool().has(state.stop_node) else ""
			if state.stop_kind == "fight":
				text = "The skirmish is over. A win's spoils wait below; a loss leaves none, and no harm done."
			var page: VBoxContainer = card("panel_parchment", 980)
			var top := HBoxContainer.new()
			top.add_theme_constant_override("separation", 18)
			page.add_child(top)
			top.add_child(UiStyle.icon(StopChoiceScreen.KIND_ICONS.get(state.stop_kind, "stop_event"), 96))
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top.add_child(words)
			words.add_child(UiStyle.heading(title, 30, UiStyle.OAK_600))
			var body: Label = UiStyle.label(text, 18, UiStyle.INK_TEXT)
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			words.add_child(body)
			var all: Array[int] = []
			for i: int in state.offers.size():
				all.append(i)
			page.add_child(offer_row(all, _take))
			page.add_child(_leave())


## A stop's card (oak): its icon and name over what it does; returns the
## column to fill.
func _stop_card(stop: String, title: String, text: String) -> VBoxContainer:
	var column: VBoxContainer = card("panel_oak", 900)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 18)
	column.add_child(top)
	top.add_child(UiStyle.icon("stop_" + stop, 88))
	var words := VBoxContainer.new()
	top.add_child(words)
	words.add_child(UiStyle.heading(title, 30, UiStyle.EMBER))
	words.add_child(UiStyle.label(text, 17, UiStyle.TEXT_DIM))
	return column


## The stop's node name, or `fallback` when it has none (the Upgrade stop).
func _title(fallback: String) -> String:
	return session.run.node_name(session.state.stop_node) if session.run.node_pool().has(session.state.stop_node) else fallback


func _leave() -> Button:
	var button: Button = primary_button("Leave, on to the fight", func() -> void: session.leave_stop(), 320)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	return button


func _take(index: int) -> void:
	session.take(index)


## A button per held item that passes `keep`.
func _item_buttons(keep: Callable, verb: String, action: Callable) -> HFlowContainer:
	var flow := HFlowContainer.new()
	var lists: Array = [session.state.stash]
	for hero: RunHero in session.state.heroes:
		lists.append(hero.items)
	for list: Array in lists:
		for item: RunItem in list:
			if keep.call(item):
				var text: String = "%s %s %s" % [verb, session.content.items[item.item_id].name, TuningDef.TIER_LABELS[item.tier]]
				flow.add_child(UiStyle.button(text, action.bind(item.uid)))
	if flow.get_child_count() == 0:
		flow.add_child(UiStyle.label("Nothing to %s." % verb.to_lower(), 14, UiStyle.TEXT_DIM))
	return flow


func _retrain_options(into: VBoxContainer) -> void:
	if session.state.stop_used:
		into.add_child(UiStyle.label("Retraining done.", 16, UiStyle.TEXT_DIM))
		return
	for hero: RunHero in session.state.heroes:
		if hero.specialization_id.is_empty():
			continue
		var line := HBoxContainer.new()
		line.add_child(UiStyle.label("%s (%s):" % [session.content.heroes[hero.hero_id].name, session.content.specializations[hero.specialization_id].name], 15))
		for spec_id: String in session.content.specialization_ids:
			var spec: SpecializationDef = session.content.specializations[spec_id]
			if spec.hero == hero.hero_id and spec_id != hero.specialization_id:
				line.add_child(UiStyle.button("Become a " + spec.name, func() -> void: session.retrain(hero.hero_id, spec_id)))
		into.add_child(line)
