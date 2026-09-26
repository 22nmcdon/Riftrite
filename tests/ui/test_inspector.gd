extends GutTest
## The inspector (the item panel): click an item to select it, then act on
## it with buttons; hovering shows the hover card; plain-language item text;
## fight names for the log.

const U = preload("res://tests/ui/ui_test_kit.gd")
const MainScript = preload("res://src/ui/main.gd")


func _main(session: RunSession) -> Main:
	var main: Main = MainScript.new()
	main.session = session
	add_child_autofree(main)
	return main


func _tile(main: Main, uid: int) -> ItemTile:
	for node: Node in U.find_all(main, ItemTile):
		if (node as ItemTile).uid == uid:
			return node
	return null


func _release(tile: ItemTile) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	tile._gui_input(click)


## A Caravan with an item bought into the stash, selected.
func _selected() -> Main:
	var session: RunSession = U.at_caravan()
	var main: Main = _main(session)
	var ware: ItemTile = null
	for node: Node in U.find_all(main, ItemTile):
		if (node as ItemTile).uid < 0:
			ware = node
			break
	ware.clicked.emit()
	_release(_tile(main, session.state.stash[0].uid))
	return main


func test_clicking_an_item_selects_it() -> void:
	var main: Main = _selected()
	var session: RunSession = main.session
	var item: RunItem = session.state.stash[0]
	assert_eq(session.selected_uid, item.uid)
	assert_true(main.inspector.visible, "the item panel pops up")
	assert_true(_tile(main, item.uid).get_theme_stylebox("panel").border_color == UiStyle.HIGHLIGHT, "the selected tile is highlighted")
	var text: String = U.text_of(main.inspector)
	assert_string_contains(text, session.content.items[item.item_id].name)
	assert_string_contains(text, "In the stash")
	assert_not_null(U.button(main.inspector, "Sell for"))
	assert_null(U.button(main.inspector, "Put in the stash"), "already there")
	_release(_tile(main, item.uid))
	assert_eq(session.selected_uid, -1, "clicking again clears it")
	assert_false(main.inspector.visible, "and the panel hides")


func test_inspector_buttons_act_on_the_item() -> void:
	var main: Main = _selected()
	var state: RunState = main.session.state
	var item: RunItem = state.stash[0]
	var hero: RunHero = state.heroes[0]
	var gold: int = state.gold
	hero.items.append(RunItem.make(state.take_uid(), "hearth_knife"))
	main.refresh()
	assert_true(U.press(main.inspector, "Give to " + main.session.content.heroes[hero.hero_id].name))
	assert_eq(state.owner_of(item.uid), hero.hero_id)
	assert_eq(main.session.selected_uid, item.uid, "still selected after moving")
	assert_true(U.press(main.inspector, "Move left in the row"))
	assert_eq(hero.items.find(item), hero.items.size() - 2)
	assert_true(U.press(main.inspector, "Move right in the row"))
	assert_eq(hero.items.find(item), hero.items.size() - 1)
	assert_true(U.press(main.inspector, "Put in the stash"))
	assert_eq(state.owner_of(item.uid), RunState.STASH)
	var price: int = main.session.sell_price(item.uid)
	assert_true(U.press(main.inspector, "Sell for %d gold" % price))
	assert_eq([state.owner_of(item.uid), state.gold], [RunState.NOWHERE, gold + price])
	assert_string_contains(U.text_of(main.inspector), "Click an item you hold", "a sold item leaves the inspector")


func test_combine_infuse_and_throw_away_from_the_inspector() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	var keep := RunItem.make(state.take_uid(), "hearth_knife")
	var copy := RunItem.make(state.take_uid(), "hearth_knife")
	state.stash.append_array([keep, copy])
	state.pouch.append_array(["ember", "frost", "ember"] as Array[String])
	var main: Main = _main(session)
	session.select(keep.uid)
	assert_true(U.press(main.inspector, "Combine with your other copy → tier B"))
	assert_eq([keep.tier, state.stash.size()], [1, 1])
	assert_eq(U.find_all(main.inspector, Button).filter(func(b: Button) -> bool: return b.text.begins_with("Infuse")).size(), 2, "one button per kind of essence")
	assert_true(U.press(main.inspector, "Infuse with Frost"))
	assert_eq(keep.essence_ids, ["frost"] as Array[String])
	assert_eq(state.pouch, ["ember", "ember"] as Array[String])
	assert_null(U.button(main.inspector, "Infuse"), "no free socket left")
	assert_true(U.press(main.inspector, "Throw away"))
	assert_eq(state.stash, [] as Array[RunItem])


func test_the_inspector_follows_the_step() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	var item := RunItem.make(state.take_uid(), "hearth_knife")
	item.essence_ids.append("ember")
	state.stash.append(item)
	state.phase = "stop"
	state.stop_kind = "forge"
	state.offers.clear()
	var main: Main = _main(session)
	session.select(item.uid)
	assert_null(U.button(main.inspector, "Sell"), "selling is only at the Caravan")
	assert_true(U.press(main.inspector, "Reforge"))
	assert_eq(item.essence_ids, [] as Array[String])
	state.stop_kind = "upgrade"
	main.refresh()
	assert_true(U.press(main.inspector, "Upgrade to tier B (free)"))
	assert_eq(item.tier, 1)
	assert_null(U.button(main.inspector, "Upgrade"), "the anvil is spent")


func test_hovering_shows_the_hover_card_and_keeps_the_selection() -> void:
	var main: Main = _selected()
	var selected_name: String = main.inspector._title.text
	var token: HeroToken = U.find_all(main.guild_bar(), HeroToken)[0]
	token.mouse_entered.emit()
	assert_true(main.hover_card.visible)
	assert_string_contains(main.hover_card.title_text(), "rank C")
	assert_string_contains(main.hover_card.body_text(), "Basic attack:")
	assert_eq(main.inspector._title.text, selected_name, "the item panel keeps the selection")
	assert_not_null(U.button(main.inspector, "Sell"))
	token.mouse_exited.emit()
	assert_false(main.hover_card.visible)


func test_hovering_a_tile_describes_the_item() -> void:
	var main: Main = _selected()
	var item: RunItem = main.session.state.stash[0]
	var tile: ItemTile = _tile(main, item.uid)
	tile.mouse_entered.emit()
	assert_eq(main.hover_card.title_text(), tile.info.split("\n")[0])
	assert_string_contains(main.hover_card.title_text(), main.session.content.items[item.item_id].name)


func test_selection_is_not_saved() -> void:
	var main: Main = _selected()
	var before: String = FileAccess.get_file_as_string(U.SAVE_PATH)
	main.session.select(-1)
	assert_eq(FileAccess.get_file_as_string(U.SAVE_PATH), before)
	main.session.new_run(3)
	assert_eq(main.session.selected_uid, -1, "a new run clears it")


# --- words and names --------------------------------------------------------------

func test_item_text_is_plain_words() -> void:
	var content: ContentDb = U.K.content()
	var text: String = ItemInfo.item_text(content, "tallow_torch", 1, ["ember"] as Array[String], 0, content.heroes["odo"].stats)
	assert_string_contains(text, "Tallow Torch  (Common, tier B)")
	assert_string_contains(text, "When it fires: apply ")
	assert_string_contains(text, " Burn to the front enemy")
	assert_string_contains(text, "x1.5 B tier")
	var relic: String = ItemInfo.relic_text(content, "warding_knot")
	assert_string_contains(relic, "When an ally drops below 30% HP: shield that ally for 80")
	assert_string_contains(ItemInfo.hero_text(content, "vell", 0), "Backup: Lantern Vigil")


func test_fight_names_number_duplicates_and_replace_ids() -> void:
	var session: RunSession = U.at_fight()
	session.state.encounter_id = "pup_litter"
	session.fight()
	var player: FightPlayer = FightPlayer.make(session.last_setup, session.content)
	var names: FightNames = FightNames.make(player.sim)
	var pups: Array[String] = []
	for unit: UnitState in player.sim.enemies:
		pups.append(names.name_of(unit.id))
	assert_eq(pups, ["Rift Pup 1", "Rift Pup 2"] as Array[String])
	var hero: UnitState = player.sim.heroes[0]
	assert_false(names.name_of(hero.id).contains(" of "), "heroes go by their short name")
	player.skip_to_end()
	for entry: LogEntry in player.sim.combat_log.entries:
		var line: String = names.text(entry)
		for unit: UnitState in player.sim.enemies:
			assert_false(line.contains(unit.id), line)
		assert_true(names.bbcode(entry).begins_with("["), "colored")


func after_each() -> void:
	if FileAccess.file_exists(U.SAVE_PATH):
		DirAccess.remove_absolute(U.SAVE_PATH)


# --- synergies in the UI -----------------------------------------------------------

func _synergy_badge(main: Main) -> Label:
	for node: Node in U.find_all(main.guild_bar(), Label):
		if (node as Label).mouse_filter == Control.MOUSE_FILTER_STOP and ((node as Label).text.contains("found") or (node as Label).text == "none yet"):
			return node
	return null


func test_discovered_synergies_show_in_the_guild_bar() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	state.heroes[0] = RunHero.make("brannoc")
	state.heroes[0].items.append(RunItem.make(state.take_uid(), "oak_buckler"))
	var main: Main = _main(session)
	assert_eq(_synergy_badge(main).text, "none yet")
	assert_eq(session.active_synergies(), ["wardens_oath"] as Array[String], "Brannoc with his buckler")
	state.discovered.append_array(["wardens_oath", "paper_cuts"] as Array[String])
	main.refresh()
	var badge: Label = _synergy_badge(main)
	assert_eq(badge.text, "2 found · 1 active")
	badge.mouse_entered.emit()
	var text: String = main.hover_card.body_text()
	assert_true(text.contains("★ Warden's Oath"), "active, so starred")
	assert_string_contains(text, "Paper Cuts")
	assert_false(text.contains("★ Paper Cuts"), "found but not active")
	assert_false(text.contains("Dawnstrike"), "undiscovered synergies stay hidden")


func test_a_fight_announces_new_synergies() -> void:
	var session: RunSession = U.at_fight()
	var state: RunState = session.state
	state.heroes[0] = RunHero.make("brannoc")
	state.heroes[0].items.append(RunItem.make(state.take_uid(), "oak_buckler"))
	var main: Main = _main(session)
	(main.screen as FightScreen).start_fight()
	assert_eq(session.last_discoveries, ["wardens_oath"] as Array[String])
	assert_string_contains(U.text_of(main.screen), "Synergy discovered: Warden's Oath")
	session.state.phase = "fight"
	session.fight()
	assert_eq(session.last_discoveries, [] as Array[String], "only the first time")


func test_synergy_text_says_what_sets_it_off() -> void:
	var content: ContentDb = U.K.content()
	assert_string_contains(ItemInfo.synergy_text(content, "paper_cuts"), "When one fielded hero holds Whetstone and Twin Daggers.")
	assert_string_contains(ItemInfo.synergy_text(content, "warden_trait"), "2+:")
	assert_string_contains(ItemInfo.synergy_text(content, "wildfire_torch"), "Tallow Torch infused with Ember")


# --- Legendaries --------------------------------------------------------------------

func test_a_legendary_shows_its_path_and_can_be_fed() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	assert_true(RunActions.add_item(state, session.content, "hungering_censer").ok)
	var censer: RunItem = state.stash[-1]
	state.pouch.append_array(["venom", "ember"] as Array[String])
	var knife := RunItem.make(state.take_uid(), "hearth_knife")
	state.stash.append(knife)
	var main: Main = _main(session)
	session.select(censer.uid)
	var text: String = U.text_of(main.inspector)
	assert_true(text.contains("Essence-hungry: feed it Ember (0/1 fed to A)"), text)
	assert_true(text.contains("Never combines. Upgrade path: Essence-hungry (starts at B)"), text)
	assert_true(U.press(main.inspector, "Feed it Ember (0/1 to A)"))
	assert_eq([censer.tier, censer.progress, state.pouch], [2, 0, ["venom"] as Array[String]])
	assert_true(U.press(main.inspector, "Feed it Venom (0/2 to S)"), "now it wants Venom")
	assert_eq([censer.progress, state.pouch], [1, [] as Array[String]])
	assert_null(U.button(main.inspector, "Feed it"), "no Venom left")
	var bar: ProgressBar = _tile(main, censer.uid).find_child("PathBar", true, false)
	assert_not_null(bar, "a Legendary's tile has a path bar")
	assert_eq([int(bar.value), int(bar.max_value)], [1, 2])
	assert_null(_tile(main, knife.uid).find_child("PathBar", true, false), "other tiles don't")


func test_items_can_be_fed_to_a_devourer_from_the_inspector() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	assert_true(RunActions.add_item(state, session.content, "maw_of_the_hollow").ok)
	var maw: RunItem = state.stash[-1]
	var knife := RunItem.make(state.take_uid(), "hearth_knife", 2)
	state.stash.append(knife)
	var main: Main = _main(session)
	session.select(maw.uid)
	assert_null(U.button(main.inspector, "Feed to"), "a Devourer doesn't eat itself")
	session.select(knife.uid)
	assert_true(U.press(main.inspector, "Feed to Maw of the Hollow (a meal worth 3)"))
	assert_eq([maw.tier, maw.progress, maw.eaten], [1, 0, ["hearth_knife"] as Array[String]])
	assert_eq(state.owner_of(knife.uid), RunState.NOWHERE)
	session.select(maw.uid)
	var text: String = U.text_of(main.inspector)
	assert_true(text.contains("Has eaten: Hearth Knife (+3% to its numbers)"), text)
	assert_true(text.contains("x1.03 devoured"), "the trace shows in the numbers")


func test_a_fight_announces_a_legendary_growing() -> void:
	var session: RunSession = U.at_fight()
	var state: RunState = session.state
	assert_true(RunActions.add_item(state, session.content, "tallymans_bow").ok)
	var bow: RunItem = state.stash[-1]
	assert_true(RunActions.move_item(state, session.content, bow.uid, state.heroes[0].hero_id, 0).ok)
	bow.progress = 59
	state.encounter_id = "pup_litter"
	var main: Main = _main(session)
	(main.screen as FightScreen).start_fight()
	assert_eq(session.last_growth, ["The Tallyman's Bow grows to B"] as Array[String])
	assert_string_contains(U.text_of(main.screen), "✦ The Tallyman's Bow grows to B")
