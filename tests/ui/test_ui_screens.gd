extends GutTest
## Main and its screens (docs/plans/first-ui.md): the screen follows the
## run's phase, and buttons, clicks, and drops change the run through the
## session. Headless, no pixel checks.

const U = preload("res://tests/ui/ui_test_kit.gd")
const MainScript = preload("res://src/ui/main.gd")


func _main(session: RunSession) -> Main:
	var main: Main = MainScript.new()
	main.session = session
	add_child_autofree(main)
	return main


func _offer_tiles(main: Main) -> Array[ItemTile]:
	var tiles: Array[ItemTile] = []
	for node: Node in U.find_all(main, ItemTile):
		if (node as ItemTile).uid < 0:
			tiles.append(node)
	return tiles


func _owned_tile(main: Main, uid: int) -> ItemTile:
	for node: Node in U.find_all(main, ItemTile):
		if (node as ItemTile).uid == uid:
			return node
	return null


func _click(control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	control._gui_input(click)


func _zone(main: Main, text: String) -> DropZone:
	for node: Node in U.find_all(main, DropZone):
		if U.text_of(node).contains(text):
			return node
	return null


# --- screens follow the phase ---------------------------------------------------

func test_the_title_starts_a_run() -> void:
	var main: Main = _main(U.session())
	assert_true(main.screen is TitleScreen)
	assert_null(U.button(main.screen, "Continue"), "no save yet")
	assert_true(U.press(main.screen, "New run"))
	assert_true(main.screen is RunStartScreen)
	assert_eq(main.session.state.phase, "start_hero")


func test_the_run_start_picks_a_hero_then_a_package() -> void:
	var session: RunSession = U.session()
	session.new_run(5)
	var main: Main = _main(session)
	var first_hero: String = session.state.offers[0]["hero"]
	assert_string_contains(U.text_of(main.screen), session.content.heroes[first_hero].name)
	assert_true(U.press(main.screen, "Take"))
	assert_eq(session.state.heroes[0].hero_id, first_hero)
	assert_eq(session.state.phase, "start_package")
	assert_true(U.press(main.screen, "gold"))
	assert_true(main.screen is CaravanScreen)
	assert_string_contains(U.text_of(main._day_slot), "Day 1 of")


func test_continue_resumes_the_saved_run() -> void:
	var saved: RunSession = U.at_caravan(9)
	var main: Main = _main(RunSession.make(saved.content, saved.run, U.SAVE_PATH))
	assert_true(U.press(main.screen, "Continue"))
	assert_true(main.screen is CaravanScreen)
	assert_eq(main.session.state.gold, saved.state.gold)


# --- the Caravan ------------------------------------------------------------------

func test_clicking_a_ware_buys_it_into_the_stash() -> void:
	var main: Main = _main(U.at_caravan())
	var state: RunState = main.session.state
	var tiles: Array[ItemTile] = _offer_tiles(main)
	assert_eq(tiles.size(), 5, "5 wares")
	var gold: int = state.gold
	var price: int = state.offers[0]["price"]
	tiles[0].clicked.emit()
	assert_eq(state.stash.size(), 1)
	assert_eq(state.stash[0].item_id, tiles[0].item_id)
	assert_eq(state.gold, gold - price)
	assert_true(state.offers[0]["taken"])
	assert_true(_offer_tiles(main)[0].modulate.a < 1.0, "a bought ware is dimmed")


func test_an_upgrade_lights_up_and_combines_into_your_copy() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	var ware: Dictionary = state.offers[1]
	var held := RunItem.make(state.take_uid(), ware["item"], ware["tier"])
	state.stash.append(held)
	var main: Main = _main(session)
	var tiles: Array[ItemTile] = _offer_tiles(main)
	assert_eq([tiles[0].lit, tiles[1].lit], [state.offers[0]["item"] == ware["item"], true])
	tiles[1].clicked.emit()
	assert_eq(state.stash.size(), 1, "combined, not added")
	assert_eq(held.tier, ware["tier"] + 1)


func test_reroll_leave_and_refusals() -> void:
	var main: Main = _main(U.at_caravan())
	var state: RunState = main.session.state
	var before: Array = state.offers.duplicate(true)
	assert_true(U.press(main.screen, "Reroll (1 gold)"))
	assert_ne(state.offers, before)
	assert_not_null(U.button(main.screen, "Reroll (2 gold)"))
	state.gold = 0
	_offer_tiles(main)[0].clicked.emit()
	assert_true(main._toast.visible, "a refused buy shows why")
	assert_string_contains(main._toast.text, "Not enough gold")
	assert_true(U.press(main.screen, "Leave the Caravan"))
	assert_true(main.screen is StopChoiceScreen)


func test_drag_and_drop_moves_sells_and_throws_away() -> void:
	var main: Main = _main(U.at_caravan())
	var state: RunState = main.session.state
	_offer_tiles(main)[0].clicked.emit()
	_offer_tiles(main)[1].clicked.emit()
	var first: RunItem = state.stash[0]
	var second: RunItem = state.stash[1]
	var hero: RunHero = state.heroes[0]
	var token: HeroToken = U.find_all(main.guild_bar(), HeroToken)[0]
	assert_true(token._can_drop_data(Vector2.ZERO, {"uid": first.uid}), "a hero's token takes items")
	assert_eq(token.get_theme_stylebox("panel").border_color, UiStyle.GOOD)
	token._drop_data(Vector2.ZERO, {"uid": first.uid})
	assert_eq(state.owner_of(first.uid), hero.hero_id, "into the hero's row")
	main.session.open_hero(hero.hero_id)
	var zone: DropZone = _zone(main, "free slot")
	assert_not_null(zone, "the sheet shows the hero's row")
	assert_true(zone._can_drop_data(Vector2.ZERO, {"uid": second.uid}))
	var gold: int = state.gold
	_zone(main, "sell")._drop_data(Vector2.ZERO, {"uid": first.uid})
	assert_eq(state.owner_of(first.uid), RunState.NOWHERE)
	assert_eq(state.gold, gold + main.session.run.economy.sell_price(state.offers[0]["price"]))
	_zone(main, "Throw away")._drop_data(Vector2.ZERO, {"uid": second.uid})
	assert_eq(state.stash, [] as Array[RunItem])


func test_dropping_a_copy_combines_and_an_essence_infuses() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	var keep := RunItem.make(state.take_uid(), "hearth_knife")
	var copy := RunItem.make(state.take_uid(), "hearth_knife")
	state.stash.append_array([keep, copy])
	state.pouch.append("ember")
	var main: Main = _main(session)
	var tile: ItemTile = _owned_tile(main, keep.uid)
	assert_false(tile._can_drop_data(Vector2.ZERO, {"uid": keep.uid}), "not onto itself")
	tile._drop_data(Vector2.ZERO, {"uid": copy.uid})
	assert_eq([state.stash.size(), keep.tier], [1, 1])
	var lower := RunItem.make(state.take_uid(), "hearth_knife")
	state.stash.append(lower)
	main.refresh()
	_owned_tile(main, keep.uid)._drop_data(Vector2.ZERO, {"uid": lower.uid})
	assert_eq([state.stash, keep.tier], [[lower, keep] as Array[RunItem], 1], "a copy at another tier just moves")
	state.stash.erase(lower)
	main.refresh()
	var chips: Array[Node] = U.find_all(main, EssenceChip)
	assert_eq(chips.size(), 1)
	var tile_now: ItemTile = _owned_tile(main, keep.uid)
	assert_true(tile_now._can_drop_data(Vector2.ZERO, {"pouch_index": 0}))
	tile_now._drop_data(Vector2.ZERO, {"pouch_index": 0})
	assert_eq(keep.essence_ids, ["ember"] as Array[String])
	assert_eq(state.pouch, [] as Array[String])


func test_formation_buttons() -> void:
	var main: Main = _main(U.at_caravan())
	var hero: RunHero = main.session.state.heroes[0]
	var row: UnitSetup.Row = hero.row
	assert_null(main.hero_sheet(), "closed until a hero is clicked")
	_click(U.find_all(main.guild_bar(), HeroToken)[0])
	assert_not_null(main.hero_sheet())
	assert_true(U.press(main.hero_sheet(), "Front" if row == UnitSetup.Row.FRONT else "Back"))
	assert_ne(hero.row, row)
	assert_true(U.press(main.hero_sheet(), "Fielded"))
	assert_true(main._toast.visible, "the only hero can't sit in backup")
	assert_false(hero.benched)


func test_the_hero_sheet_opens_steps_and_closes() -> void:
	var session: RunSession = U.at_caravan()
	var state: RunState = session.state
	state.heroes.append(RunHero.make("brannoc"))
	state.heroes[1].benched = true
	var main: Main = _main(session)
	var tokens: Array[Node] = U.find_all(main.guild_bar(), HeroToken)
	assert_eq(tokens.size(), 2)
	_click(tokens[1])
	assert_eq(main.hero_sheet().hero_id, "brannoc")
	assert_string_contains(U.text_of(main.hero_sheet()), "Brannoc of the Hearthwatch")
	assert_not_null(U.button(main.hero_sheet(), "In backup"))
	assert_true(U.press(main.hero_sheet(), "Next hero"))
	assert_eq(main.hero_sheet().hero_id, state.heroes[0].hero_id, "wraps around")
	assert_true(U.press(main.hero_sheet(), "✕"))
	assert_null(main.hero_sheet())
	_click(U.find_all(main.guild_bar(), HeroToken)[0])
	_click(U.find_all(main.guild_bar(), HeroToken)[0])
	assert_null(main.hero_sheet(), "clicking the open hero's token closes it")


# --- stops, the fight, rewards ------------------------------------------------------

func test_stop_choice_and_stop() -> void:
	var session: RunSession = U.at_caravan()
	session.leave_caravan()
	var main: Main = _main(session)
	assert_eq(session.state.offers.size(), 2, "two nodes")
	var stop: String = session.state.offers[0]["stop"]
	if session.run.node_kind(stop) == "fight":
		stop = session.state.offers[1]["stop"]
	for offer: Dictionary in session.state.offers:
		var card: Button = U.button(main.screen, session.run.node_name(offer["stop"]))
		assert_not_null(card, "each node shows its name")
		assert_true(card.text.contains(session.run.node_text(offer["stop"])), "and its blurb")
	assert_true(U.press(main.screen, session.run.node_name(stop)))
	assert_eq([session.state.phase, session.state.stop_node], ["stop", stop])
	assert_true(main.screen is StopScreen)
	assert_string_contains(U.text_of(main.screen), session.run.node_name(stop))
	assert_true(U.press(main.screen, "Leave, on to the fight"))
	assert_true(main.screen is FightScreen)


func test_a_skirmish_plays_back_then_offers_its_spoils() -> void:
	var session: RunSession = U.at_caravan()
	session.leave_caravan()
	var state: RunState = session.state
	state.offers = [{"type": "stop", "stop": "skirmish", "price": 0, "taken": false}] as Array[Dictionary]
	var main: Main = _main(session)
	assert_true(U.press(main.screen, "A Rift Skirmish"))
	assert_true(main.screen is FightScreen, "a skirmish to fight shows the fight screen")
	var text: String = U.text_of(main.screen)
	assert_true(text.contains("A Rift Skirmish: " + session.content.encounters[state.stop_encounter].name), text)
	assert_not_null(U.button(main.screen, "Skip the skirmish"))
	var fight: FightScreen = main.screen
	var losses: int = state.losses
	assert_true(U.press(fight, "Fight!"))
	assert_true(fight.playing)
	assert_eq([state.phase, state.stop_used, state.losses], ["stop", true, losses], "never counted as a loss")
	fight._on_entries(fight.player.skip_to_end())
	fight._continue()
	assert_true(main.screen is StopScreen, "then the stop, with any spoils")
	assert_string_contains(U.text_of(main.screen), "The skirmish is over")
	assert_true(U.press(main.screen, "Leave, on to the fight"))
	assert_true(main.screen is FightScreen)
	assert_string_contains(U.text_of(main.screen), "Today's fight")


func test_a_skirmish_can_be_skipped() -> void:
	var session: RunSession = U.at_caravan()
	session.leave_caravan()
	session.state.offers = [{"type": "stop", "stop": "skirmish", "price": 0, "taken": false}] as Array[Dictionary]
	session.pick_stop(0)
	var main: Main = _main(session)
	assert_true(U.press(main.screen, "Skip the skirmish"))
	assert_eq(session.state.phase, "fight")
	assert_string_contains(U.text_of(main.screen), "Today's fight")


func test_the_fight_plays_back_then_moves_on() -> void:
	var main: Main = _main(U.at_fight())
	var session: RunSession = main.session
	var fight: FightScreen = main.screen
	assert_string_contains(U.text_of(fight), "Today's fight")
	assert_not_null(main.guild_bar(), "the guild bar shows before the fight")
	assert_true(U.press(fight, "Fight!"))
	assert_true(fight.playing)
	assert_null(main.guild_bar(), "and hides while it plays")
	assert_eq(main.screen, fight, "the fight keeps its screen while it plays")
	assert_ne(session.state.phase, "fight")
	fight._process(1.0)
	assert_eq(fight.player.sim.tick, 20)
	assert_true(U.press(fight, "4x"))
	assert_eq(fight.player.speed, 4.0)
	assert_true(U.press(fight, "Pause"))
	fight._process(1.0)
	assert_eq(fight.player.sim.tick, 20)
	assert_null(U.button(fight, "Continue"))
	assert_true(U.press(fight, "Skip"))
	assert_true(fight.player.finished())
	var lines: PackedStringArray = PackedStringArray()
	for entry: LogEntry in fight.shown:
		lines.append(entry.to_text())
	assert_eq("\n".join(lines), session.last_fight.combat_log.to_text(), "every entry reaches the screen, in order")
	var log_text: String = fight._log.get_parsed_text()
	for unit: UnitState in fight.player.sim.enemies:
		assert_false(log_text.contains(unit.id), "the log names %s instead of its id" % unit.id)
		assert_string_contains(log_text, fight.names.name_of(unit.id))
	assert_false(log_text.contains(" fires"), "item fires are hidden by default")
	fight._set_show_fires(true)
	assert_string_contains(fight._log.get_parsed_text(), " fires")
	assert_string_contains(U.text_of(fight), "Victory!" if session.last_fight.guild_won() else "Defeat")
	assert_true(U.press(fight, "Continue"))
	assert_false(main.screen is FightScreen)
	assert_eq(main.screen.get_script(), main.screen_script())


func _key(fight: FightScreen, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	fight._unhandled_input(event)


func test_fight_keyboard_shortcuts() -> void:
	var main: Main = _main(U.at_fight())
	var fight: FightScreen = main.screen
	fight.start_fight()
	assert_false(main.inspector.visible, "the inspector hides during playback")
	_key(fight, KEY_3)
	assert_eq(fight.player.speed, 2.0)
	assert_true(fight._speed_buttons[2].button_pressed)
	assert_false(fight._speed_buttons[1].button_pressed)
	_key(fight, KEY_SPACE)
	assert_true(fight.player.paused)
	assert_eq(fight._pause_button.text, "Resume")
	_key(fight, KEY_SPACE)
	assert_false(fight.player.paused)
	_key(fight, KEY_S)
	assert_true(fight.player.finished())
	_key(fight, KEY_ENTER)
	assert_false(main.screen is FightScreen, "Enter continues")


func test_the_day_bar_abandons_the_run() -> void:
	var main: Main = _main(U.at_caravan())
	var bar: Node = main._day_slot.get_child(0)
	assert_string_contains(U.text_of(bar), "Seed 5")
	var dialog: ConfirmationDialog = U.find_all(bar, ConfirmationDialog)[0]
	dialog.confirmed.emit()
	assert_null(main.session.state)
	assert_true(main.screen is TitleScreen)
	assert_false(main.inspector.visible)


func test_rewards_and_the_run_end() -> void:
	var session: RunSession = U.at_fight()
	session.fight()
	var main: Main = _main(session)
	if session.state.phase == "rewards":
		assert_true(main.screen is RewardsScreen)
		assert_true(U.press(main.screen, "Continue"))
	assert_true(main.screen is CaravanScreen)
	session.state.phase = "run_over"
	main.refresh()
	assert_true(main.screen is RunEndScreen)
	assert_string_contains(U.text_of(main.screen), "The guild has fallen")
	assert_true(U.press(main.screen, "Back to the title"))
	assert_true(main.screen is TitleScreen)
	assert_false(session.has_save())


# --- a whole run, clicked through ------------------------------------------------------

## Plays a run only through the UI: buys the cheapest ware it can afford,
## drops stash items onto a hero's free slots, takes every stop and reward
## offer, and fights (skipping to the end). Stops at the run's end.
func test_a_whole_run_clicked_through() -> void:
	var session: RunSession = U.session()
	session.fixed_seed = 1
	var main: Main = _main(session)
	assert_true(U.press(main.screen, "New run"))
	var fights: int = 0
	var taken: int = 0
	var bought: int = 0
	var ending: String = ""
	for step: int in 400:
		var state: RunState = main.session.state
		if state == null:
			break
		match state.phase:
			"start_hero":
				assert_true(U.press(main.screen, "Take"))
			"start_package":
				assert_true(U.press(main.screen, "gold"))
			"caravan":
				bought += _shop(main)
				_equip(main)
				assert_true(U.press(main.screen, "Leave the Caravan"))
			"stop_choice":
				assert_true(U.press(main.screen, main.session.run.node_name(main.session.state.offers[0]["stop"])))
			"stop" when main.session.skirmish_pending():
				fights += 1
				assert_true(U.press(main.screen, "Fight!"))
				assert_true(U.press(main.screen, "Skip"))
				assert_true(U.press(main.screen, "Continue"))
			"stop":
				taken += _take_everything(main)
				assert_true(U.press(main.screen, "Leave, on to the fight"))
			"fight":
				_equip(main)
				fights += 1
				assert_true(U.press(main.screen, "Fight!"))
				assert_true(U.press(main.screen, "Skip"))
				assert_true(U.press(main.screen, "Continue"))
			"rewards":
				taken += _take_everything(main)
				assert_true(U.press(main.screen, "Continue"))
			"act_end", "run_over":
				assert_true(main.screen is RunEndScreen)
				ending = "%s on day %d" % [main.session.state.phase, main.session.state.day]
				assert_eq(main.session.state.check(main.session.content), [] as Array[String])
				assert_true(U.press(main.screen, "Back to the title"))
	assert_null(main.session.state, "the run ended and went back to the title")
	assert_true(main.screen is TitleScreen)
	assert_gt(fights, 1)
	assert_gt(bought, 0)
	assert_gt(taken, 0)
	gut.p("clicked-through run: %s, %d fights, %d bought, %d taken" % [ending, fights, bought, taken])


## Returns how many wares it bought.
func _shop(main: Main) -> int:
	var bought: int = 0
	for i: int in 3:
		var state: RunState = main.session.state
		var tiles: Array[ItemTile] = _offer_tiles(main)
		for t: int in tiles.size():
			var offer: Dictionary = _item_offers(state)[t]
			if not offer["taken"] and offer["price"] <= state.gold:
				tiles[t].clicked.emit()
				bought += 1
				break
	return bought


func _item_offers(state: RunState) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for offer: Dictionary in state.offers:
		if offer["type"] == "item":
			items.append(offer)
	return items


## Drops each stash item onto the first hero token that takes it.
func _equip(main: Main) -> void:
	for item: RunItem in main.session.state.stash.duplicate():
		for token: Node in U.find_all(main.guild_bar(), HeroToken):
			if (token as HeroToken)._can_drop_data(Vector2.ZERO, {"uid": item.uid}):
				(token as HeroToken)._drop_data(Vector2.ZERO, {"uid": item.uid})
				break


## Returns how many offers it took.
func _take_everything(main: Main) -> int:
	var taken: int = 0
	for i: int in main.session.state.offers.size():
		var offer: Dictionary = main.session.state.offers[i]
		if offer["taken"] or offer["price"] > main.session.state.gold:
			continue
		if offer["type"] == "item":
			var tiles: Array[ItemTile] = _offer_tiles(main)
			for tile: ItemTile in tiles:
				if tile.item_id == offer["item"] and tile.modulate.a == 1.0:
					tile.clicked.emit()
					taken += 1
					break
		else:
			for node: Node in U.find_all(main.screen, Button):
				var button: Button = node
				if not button.disabled and (button.text.ends_with("(Take)") or button.text.ends_with("gold)")) and button.get_parent() is HBoxContainer:
					button.pressed.emit()
					taken += 1
					break
	return taken


func after_each() -> void:
	if FileAccess.file_exists(U.SAVE_PATH):
		DirAccess.remove_absolute(U.SAVE_PATH)
