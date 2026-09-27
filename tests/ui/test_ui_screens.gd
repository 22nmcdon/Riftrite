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


func test_the_run_start_drafts_a_team_then_a_package() -> void:
	var session: RunSession = U.session()
	session.new_run(5)
	var main: Main = _main(session)
	for pick: int in RunState.TEAM_SIZE:
		var first_hero: HeroDef = session.content.heroes[session.state.offers[0]["hero"]]
		var text: String = U.text_of(main.screen)
		assert_string_contains(text, "hero %d of %d" % [pick + 1, RunState.TEAM_SIZE])
		assert_string_contains(text, first_hero.name)
		assert_string_contains(text, first_hero.innate_name)
		assert_true(U.press(main.screen, "Take"))
		assert_eq(session.state.heroes[pick].hero_id, first_hero.id)
		if pick < RunState.TEAM_SIZE - 1:
			assert_string_contains(U.text_of(main.screen), session.content.heroes[session.state.heroes[0].hero_id].name, "the team so far")
	assert_eq(session.state.phase, "start_package")
	assert_true(U.press(main.screen, "gold"))
	assert_true(main.screen is StopChoiceScreen)
	assert_string_contains(U.text_of(main._day_slot), "Day 1 of")


## Two kits for the team next to the gold and the relic
## (docs/plans/fight-questions-and-readability.md, section 3).
func test_the_start_offers_kits_with_their_infused_item() -> void:
	var session: RunSession = U.session()
	session.new_run(5)
	var main: Main = _main(session)
	for pick: int in RunState.TEAM_SIZE:
		assert_true(U.press(main.screen, "Take"))
	var text: String = U.text_of(main.screen)
	var kit: Dictionary = {}
	for offer: Dictionary in session.state.offers:
		if offer["package"] == "kit":
			kit = offer
			assert_not_null(U.button(main.screen, offer["name"]), "a button per kit, by its name")
			assert_string_contains(text, "%s, infused with %s." % [session.content.items[offer["item"]].name, session.content.essences[offer["essence"]].name])
	assert_true(U.press(main.screen, kit["name"]))
	assert_eq([session.state.stash[0].item_id, session.state.stash[0].essence_ids], [kit["item"], [kit["essence"]]])
	assert_true(main.screen is StopChoiceScreen)


## The day bar shows the whole act: a mark per day, elites and the boss
## marked, and each day's fights on hover (section 1).
func test_the_day_bar_shows_the_whole_act() -> void:
	var main: Main = _main(U.at_start())
	var session: RunSession = main.session
	var bar: Node = main._day_slot.get_child(0)
	var act: ActDef = session.run.act(1)
	for day: int in range(1, act.days + 1):
		var mark: Control = bar.find_child("Day%d" % day, true, false)
		assert_not_null(mark, "day %d" % day)
		var hover: String = mark.tooltip_text
		for encounter_id: String in RunFlow.fights_for_day(session.state, session.run, day):
			var encounter: EncounterDef = session.content.encounters[encounter_id]
			assert_string_contains(hover, encounter.name, "day %d lists its fights" % day)
			if encounter.kind != "normal":
				assert_string_contains(hover, encounter.mechanic_name + ": " + encounter.mechanic_text)
				assert_string_contains(hover, "What answers it: " + encounter.mechanic_counter)
		var icon: TextureRect = U.find_all(mark, TextureRect)[0]
		assert_eq(icon.texture.resource_path, UiStyle.ICON_DIR % ("fight_%s" % EncounterInfo.day_kind(session, day)), "day %d's icon" % day)
	var text: String = U.text_of(bar)
	assert_string_contains(text, "Day 3 · Elite")
	assert_string_contains(text, "Day %d · Boss" % act.days)
	assert_string_contains(bar.find_child("Day1", true, false).tooltip_text, "easier")
	assert_string_contains(bar.find_child("Day%d" % act.days, true, false).tooltip_text, "Day %d: the boss" % act.days)


## An elite's or the boss's mechanic on its fight card and before the fight
## (section 2).
func test_elite_cards_show_their_mechanic() -> void:
	var session: RunSession = U.at_start()
	session.state.day = 3
	session.state.fight_options = RunFlow.fights_for_day(session.state, session.run, 3)
	session.state.phase = "fight_choice"
	var main: Main = _main(session)
	assert_true(main.screen is FightChoiceScreen)
	var text: String = U.text_of(main.screen)
	for encounter_id: String in session.state.fight_options:
		var encounter: EncounterDef = session.content.encounters[encounter_id]
		assert_string_contains(text, encounter.mechanic_name)
		assert_string_contains(text, encounter.mechanic_text)
		assert_string_contains(text, "What answers it: " + encounter.mechanic_counter)
	session.pick_fight(0)
	main.refresh()
	assert_true(main.screen is FightScreen)
	assert_string_contains(U.text_of(main.screen), session.content.encounters[session.state.encounter_id].mechanic_text)
	var plain: Main = _main(U.at_fight())
	assert_false(U.text_of(plain.screen).contains("What answers it"), "a normal fight has no mechanic")


func test_continue_resumes_the_saved_run() -> void:
	var saved: RunSession = U.at_shop(9)
	var main: Main = _main(RunSession.make(saved.content, saved.run, U.SAVE_PATH))
	assert_true(U.press(main.screen, "Continue"))
	assert_true(main.screen is ShopScreen)
	assert_eq(main.session.state.gold, saved.state.gold)


# --- shops --------------------------------------------------------------------------

func test_clicking_a_ware_buys_it_into_the_stash() -> void:
	var main: Main = _main(U.at_shop())
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
	var session: RunSession = U.at_shop()
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
	var main: Main = _main(U.at_shop())
	var state: RunState = main.session.state
	var before: Array = state.offers.duplicate(true)
	assert_true(U.press(main.screen, "Reroll (1 gold)"))
	assert_ne(state.offers, before)
	assert_not_null(U.button(main.screen, "Reroll (2 gold)"))
	state.gold = 0
	_offer_tiles(main)[0].clicked.emit()
	assert_true(main._toast.visible, "a refused buy shows why")
	assert_string_contains(main._toast.text, "Not enough gold")
	assert_string_contains(U.text_of(main.screen), main.session.run.node_name(state.stop_node), "the shop's name")
	assert_true(U.press(main.screen, "Leave, on down the road"))
	assert_true(main.screen is StopChoiceScreen)
	assert_string_contains(U.text_of(main.screen), "stop 2 of 2")


func test_drag_and_drop_moves_sells_and_throws_away() -> void:
	var main: Main = _main(U.at_shop())
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
	var zone: DropZone = _zone(main, " free")
	assert_not_null(zone, "the sheet shows the hero's row")
	assert_true(zone._can_drop_data(Vector2.ZERO, {"uid": second.uid}))
	var gold: int = state.gold
	_zone(main, "sell")._drop_data(Vector2.ZERO, {"uid": first.uid})
	assert_eq(state.owner_of(first.uid), RunState.NOWHERE)
	assert_eq(state.gold, gold + main.session.run.economy.sell_price(state.offers[0]["price"]), "half the price paid")
	_zone(main, "Throw away")._drop_data(Vector2.ZERO, {"uid": second.uid})
	assert_eq(state.stash, [] as Array[RunItem])


func test_dropping_a_copy_combines_and_an_essence_infuses() -> void:
	var session: RunSession = U.at_shop()
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
	var main: Main = _main(U.at_shop())
	var hero: RunHero = main.session.state.heroes[0]
	var row: UnitSetup.Row = hero.row
	assert_null(main.hero_sheet(), "closed until a hero is clicked")
	_click(U.find_all(main.guild_bar(), HeroToken)[0])
	assert_not_null(main.hero_sheet())
	assert_true(U.press(main.hero_sheet(), "Front" if row == UnitSetup.Row.FRONT else "Back"))
	assert_ne(hero.row, row)
	assert_null(U.button(main.hero_sheet(), "Fielded"), "no backup any more")


func test_the_hero_sheet_opens_steps_and_closes() -> void:
	var session: RunSession = U.at_shop()
	var state: RunState = session.state
	var main: Main = _main(session)
	var tokens: Array[Node] = U.find_all(main.guild_bar(), HeroToken)
	assert_eq(tokens.size(), 3)
	_click(tokens[2])
	var last: HeroDef = session.content.heroes[state.heroes[2].hero_id]
	assert_eq(main.hero_sheet().hero_id, last.id)
	assert_string_contains(U.text_of(main.hero_sheet()), last.name)
	assert_string_contains(U.text_of(main.hero_sheet()), "Innate: %s" % last.innate_name)
	assert_true(U.press(main.hero_sheet(), "Next hero"))
	assert_eq(main.hero_sheet().hero_id, state.heroes[0].hero_id, "wraps around")
	assert_true(U.press(main.hero_sheet(), "✕"))
	assert_null(main.hero_sheet())
	_click(U.find_all(main.guild_bar(), HeroToken)[0])
	_click(U.find_all(main.guild_bar(), HeroToken)[0])
	assert_null(main.hero_sheet(), "clicking the open hero's token closes it")


# --- stops, the fight, rewards ------------------------------------------------------

func test_two_stops_then_the_fight_choice() -> void:
	var session: RunSession = U.at_start()
	var main: Main = _main(session)
	assert_true(main.screen is StopChoiceScreen)
	assert_string_contains(U.text_of(main.screen), "stop 1 of 2")
	assert_eq(session.state.offers.size(), 2, "two nodes")
	for offer: Dictionary in session.state.offers:
		var card: Button = U.button(main.screen, session.run.node_name(offer["stop"]))
		assert_not_null(card, "each node shows its name")
		assert_true(card.text.contains(session.run.node_text(offer["stop"])), "and its blurb")
	assert_true(U.button(main.screen, session.run.node_name(session.state.offers[0]["stop"])).text.contains("(Shop)"), "one is a shop")
	var stop: String = session.state.offers[1]["stop"]
	assert_true(U.press(main.screen, session.run.node_name(stop)))
	assert_eq([session.state.phase, session.state.stop_node], ["stop", stop])
	assert_true(main.screen is StopScreen)
	assert_string_contains(U.text_of(main.screen), session.run.node_name(stop))
	assert_true(U.press(main.screen, "Leave, on down the road"))
	assert_true(main.screen is StopChoiceScreen)
	assert_true(U.press(main.screen, session.run.node_name(session.state.offers[0]["stop"])))
	assert_true(main.screen is ShopScreen)
	assert_true(U.press(main.screen, "Leave, on to the fight"))
	assert_true(main.screen is FightChoiceScreen)
	var text: String = U.text_of(main.screen)
	for encounter_id: String in session.state.fight_options:
		assert_string_contains(text, session.content.encounters[encounter_id].name)
	assert_string_contains(text, "easier")
	assert_string_contains(text, "harder")
	assert_string_contains(text, "More gold, and rarer spoils")
	assert_string_contains(U.text_of(main._day_slot), " or ", "the day bar shows both fights")
	var buttons: Array[Node] = U.find_all(main.screen, Button)
	(buttons[1] as Button).pressed.emit()
	assert_eq([session.state.phase, session.state.encounter_id], ["fight", session.state.fight_options[1]])
	assert_true(main.screen is FightScreen)
	assert_string_contains(U.text_of(main.screen), "Today's fight: " + session.content.encounters[session.state.fight_options[1]].name)


func test_the_rewards_screen_shows_the_pick_of_three() -> void:
	var session: RunSession = U.at_shop()
	var state: RunState = session.state
	state.phase = "rewards"
	state.offers.assign([
		{"type": "item", "item": "rift_claw", "tier": 0, "price": 0, "taken": false, "group": RunFlow.REWARD_PICK, "drop": "yes"},
		{"type": "item", "item": "hearth_knife", "tier": 0, "price": 0, "taken": false, "group": RunFlow.REWARD_PICK},
		{"type": "item", "item": "hatchet", "tier": 0, "price": 0, "taken": false, "group": RunFlow.REWARD_PICK},
	])
	var main: Main = _main(session)
	assert_string_contains(U.text_of(main.screen), "Choose one spoil (or none): the first is from the enemy team")
	_offer_tiles(main)[1].clicked.emit()
	assert_eq(state.stash[0].item_id, "hearth_knife")
	assert_eq([state.offers[0]["taken"], state.offers[2]["taken"]], [true, true], "one of the three")


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
	var main: Main = _main(U.at_shop())
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
	assert_true(main.screen is StopChoiceScreen)
	session.state.phase = "run_over"
	main.refresh()
	assert_true(main.screen is RunEndScreen)
	assert_string_contains(U.text_of(main.screen), "The guild has fallen")
	assert_true(U.press(main.screen, "Back to the title"))
	assert_true(main.screen is TitleScreen)
	assert_false(session.has_save())


func test_the_hero_sheet_shows_deeds_and_the_level_two_choice() -> void:
	var session: RunSession = U.at_shop()
	var hero: RunHero = session.state.heroes[0]
	var calling: DeedTrackDef = session.content.heroes[hero.hero_id].calling
	hero.calling_progress = calling.deed.goals[0]
	session.open_hero(hero.hero_id)
	var main: Main = _main(session)
	var deeds: Node = main.hero_sheet().find_child("Deeds", true, false)
	assert_not_null(deeds)
	assert_string_contains(U.text_of(deeds), "%s, level 1: %s (%d / %d)" % [calling.name, calling.deed.text, calling.deed.goals[0], calling.deed.goals[1]])
	var first: String = calling.levels[DeedTrackDef.CHOICE_LEVEL].options[0].name
	assert_null(U.button(deeds, first), "no choice before level 2")
	hero.calling_progress = calling.deed.goals[1]
	main.refresh()
	deeds = main.hero_sheet().find_child("Deeds", true, false)
	assert_true(U.press(deeds, first))
	assert_eq(hero.calling_choice, 0)
	deeds = main.hero_sheet().find_child("Deeds", true, false)
	assert_null(U.button(deeds, first), "chosen for good")


func test_the_draft_shows_each_heros_calling() -> void:
	var session: RunSession = U.session()
	session.new_run(5)
	var main: Main = _main(session)
	var first: HeroDef = session.content.heroes[session.state.offers[0]["hero"]]
	assert_string_contains(U.text_of(main.screen), "Calling: %s." % first.calling_name)


func test_the_fight_ends_with_deed_progress() -> void:
	var session: RunSession = U.at_fight()
	var main: Main = _main(session)
	(main.screen as FightScreen).start_fight()
	(main.screen as FightScreen).skip()
	var text: String = U.text_of(main.screen)
	assert_string_contains(text, "Deeds")
	var hero: RunHero = session.state.heroes[0]
	assert_string_contains(text, "%s (%s): 0 → %d" % [session.content.heroes[hero.hero_id].calling_name, session.content.heroes[hero.hero_id].calling.deed.text, hero.calling_progress])


func test_the_rewards_screen_gives_a_rank_up() -> void:
	var session: RunSession = U.at_shop()
	var state: RunState = session.state
	state.phase = "rewards"
	state.offers.assign([{"type": "rank_up", "price": 0, "taken": false}])
	state.heroes[0].rank = 3
	var main: Main = _main(session)
	var text: String = U.text_of(main.screen)
	assert_string_contains(text, "A rank-up: give it to one hero")
	var first_names: Array[String] = []
	for hero: RunHero in state.heroes:
		first_names.append(HeroToken.first_name(session.content.heroes[hero.hero_id].name))
	assert_null(U.button(main.screen, "%s: S" % first_names[0]), "an S hero can't rank up")
	assert_true(U.press(main.screen, "%s: C → B" % first_names[1]))
	assert_eq([state.heroes[1].rank, state.heroes[1].needs_specialization, state.heroes[2].rank], [1, true, 0])
	assert_string_contains(U.text_of(main.screen), "Rank-up given")
	assert_null(U.button(main.screen, " → "), "only one hero gets it")


# --- a whole run, clicked through ------------------------------------------------------

## Plays a run only through the UI: drafts a team, buys the cheapest ware it
## can afford, drops stash items onto a hero's free slots, takes every stop
## and reward offer, gives rank-ups (picking the first specialization), and
## fights (skipping to the end). Stops at the run's end.
func test_a_whole_run_clicked_through() -> void:
	var session: RunSession = U.session()
	session.fixed_seed = 1
	var main: Main = _main(session)
	assert_true(U.press(main.screen, "New run"))
	var fights: int = 0
	var taken: int = 0
	var bought: int = 0
	var ranked: int = 0
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
			"stop_choice":
				# The shop on the first visit, the other stop on the second.
				assert_true(U.press(main.screen, main.session.run.node_name(main.session.state.offers[mini(main.session.state.visit, 1)]["stop"])))
			"stop" when main.screen is ShopScreen:
				bought += _shop(main)
				_equip(main)
				assert_true(U.press(main.screen, "Leave, on"))
			"stop":
				taken += _take_everything(main)
				assert_true(U.press(main.screen, "Leave, on"))
			"fight_choice":
				assert_true(U.press(main.screen, "Fight them"))
			"fight":
				_equip(main)
				_pick_specializations(main)
				fights += 1
				assert_true(U.press(main.screen, "Fight!"))
				assert_true(U.press(main.screen, "Skip"))
				assert_true(U.press(main.screen, "Continue"))
			"rewards":
				var rank_up: Button = U.button(main.screen, " → ")
				if rank_up != null:
					rank_up.pressed.emit()
					ranked += 1
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
	gut.p("clicked-through run: %s, %d fights, %d bought, %d taken, %d rank-ups" % [ending, fights, bought, taken, ranked])


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


## Picks the first specialization for each hero who needs one, from their
## sheet's menu.
func _pick_specializations(main: Main) -> void:
	for hero: RunHero in main.session.state.heroes:
		if hero.needs_specialization:
			if main.session.open_hero_id != hero.hero_id:
				main.session.open_hero(hero.hero_id)
			var menu: MenuButton = U.find_all(main.hero_sheet(), MenuButton)[0]
			menu.get_popup().id_pressed.emit(0)
			assert_false(hero.needs_specialization)
	main.session.open_hero("")


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


func test_the_draft_shows_affinities_and_how_a_hero_fits_the_team() -> void:
	var session: RunSession = U.session()
	session.new_run(5)
	var main: Main = _main(session)
	var first: HeroDef = session.content.heroes[session.state.offers[0]["hero"]]
	assert_string_contains(U.text_of(main.screen), "Affinities: " + ItemInfo.keyword_names(session.content, first.affinities))
	var state := RunState.make(1)
	state.heroes.append(RunHero.make("brannoc"))
	assert_eq(RunStartScreen.team_notes(session.content, state, "hesk"), PackedStringArray(["Shares Ward with Brannoc", "A bond with Brannoc: ?"]), "the bond's name stays hidden")
	state.discovered.append("twin_walls")
	assert_eq(RunStartScreen.team_notes(session.content, state, "hesk")[1], "A bond with Brannoc: Twin Walls", "until it's found")
	assert_eq(RunStartScreen.team_notes(session.content, state, "maren"), PackedStringArray(), "nothing shared, no bond")
