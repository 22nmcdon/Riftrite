class_name StopScreen
extends UiScreen
## The stop being visited: take or pass what's offered (Loot, the Vault,
## events), reforge (Forge), retrain, or upgrade an item (before the boss).


func build() -> void:
	var state: RunState = session.state
	match state.stop_kind:
		"forge":
			heading("The Forge")
			add_child(UiStyle.label("Reforging strips an item's infusion (the essences are lost) for %d gold." % session.content.tuning.reforge_gold, 14, UiStyle.TEXT_DIM))
			add_child(_item_buttons(func(item: RunItem) -> bool: return not item.essence_ids.is_empty(), "Reforge", func(uid: int) -> void: session.forge_reforge(uid)))
		"retrain":
			heading("Retrain")
			_retrain_options()
		"upgrade":
			heading("An anvil before the boss")
			add_child(UiStyle.label("Raise one item a tier, for free." if not state.stop_used else "The anvil is spent.", 14, UiStyle.TEXT_DIM))
			if not state.stop_used:
				add_child(_item_buttons(func(item: RunItem) -> bool: return item.tier < 3 and session.content.items[item.item_id].rarity != "legendary", "Upgrade", func(uid: int) -> void: session.upgrade(uid)))
		_:
			var event_id: String = state.offers[0].get("event", "") if not state.offers.is_empty() else ""
			if not event_id.is_empty():
				heading(session.run.events[event_id].name)
				add_child(UiStyle.label(session.run.events[event_id].text, 16, UiStyle.TEXT_DIM))
			else:
				heading(state.stop_kind.capitalize())
			var all: Array[int] = []
			for i: int in state.offers.size():
				all.append(i)
			add_child(offer_row(all, _take))
	add_child(UiStyle.button("Leave, on to the fight", func() -> void: session.leave_stop()))
	add_child(GuildPanel.make(session))


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


func _retrain_options() -> void:
	if session.state.stop_used:
		add_child(UiStyle.label("Retraining done.", 14, UiStyle.TEXT_DIM))
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
		add_child(line)
