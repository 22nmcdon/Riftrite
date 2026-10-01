extends GutTest
## The run on screen (docs/plans/rebuild-phase5-run.md, section 11), driven
## headless through a real Main: the title's New run and Continue, vowing,
## a day (route, loadout, the fight, the Pedlar, a node), the fight on the arena (exactly RunFlow's),
## the pick after it, a Hunt, the hero bar and panel in a run, and the run's
## end. Every action is saved.

const MainScript = preload("res://src/ui/main.gd")
const U = preload("res://tests/ui/ui_test_kit.gd")
const Bot = preload("res://tools/run_bot.gd")
const SAVE: String = "user://test_run_screens.json"
const OLD_SAVE: String = "user://test_run_screens_old.json"


func after_each() -> void:
	RunSave.erase(SAVE)


## Main frees a screen it replaces on the next frame, so each test lets one
## pass before it ends.
func _main() -> Main:
	var main: Main = MainScript.new()
	main.old_save_path = OLD_SAVE
	main.run_save_path = SAVE
	add_child_autofree(main)
	return main


## A Main at day 1's route of a new run from seed 7, vowed to each hero's
## first path.
func _started() -> Main:
	var main: Main = _main()
	assert_true(U.press(main.screen, "New run"))
	assert_true(main.screen is RunStartScreen)
	(main.screen as RunStartScreen).run_seed = 7
	assert_true(U.press(main.screen, "Into the rift"))
	assert_true(main.screen is RunDayScreen)
	return main


func _flow(main: Main) -> RunFlow:
	return main.run_session.flow


func _saved() -> String:
	return JSON.stringify(RunSave.load_state(SAVE).to_dict()) if RunSave.has_save(SAVE) else ""


func test_the_title_offers_a_run() -> void:
	var main: Main = _main()
	assert_null(U.button(main.screen, "Continue"), "no run saved")
	assert_not_null(U.button(main.screen, "New run"))
	await wait_frames(1)


func test_vowing_and_starting() -> void:
	var main: Main = _main()
	U.press(main.screen, "New run")
	var start: RunStartScreen = main.screen
	start.run_seed = 3
	start.choose("maren", "trapper")
	assert_eq(start.vows["maren"], "trapper")
	start.choose("brannoc", "ironbrand")
	assert_string_contains(U.text_of(start), "A bond stirs between Ironbrand and Trapper")
	U.press(main.screen, "Into the rift")
	var state: RunState = _flow(main).state
	assert_eq([state.seed_value, state.hero("maren").path, state.hero("brannoc").path], [3, "trapper", "ironbrand"])
	assert_true(RunSave.has_save(SAVE), "saved from the start")
	assert_string_contains(U.text_of(main.screen), "Day 1 of 7")
	await wait_frames(1)


func test_a_day_from_the_route_to_the_next() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	assert_eq(flow.state.phase, RunState.Phase.ROUTE, "day 1 starts at the route (phase 5c step 8)")
	assert_string_contains(U.text_of(main.screen), "Choose today's fight")
	assert_true(U.press(main.screen, "Fight this"))
	assert_eq(flow.state.phase, RunState.Phase.LOADOUT)
	assert_eq(_saved(), JSON.stringify(flow.state.to_dict()), "each action is saved")
	assert_true(U.press(main.screen, "To the fight"))
	assert_true(main.screen is ArenaScreen)
	var arena: ArenaScreen = main.screen
	assert_eq(arena.encounter.id, flow.state.chosen)
	var setup: FightSetup = flow.fight_setup(arena.formation, [] as Array[String])
	var expected: FightResult = CombatSim.run(setup, flow.run.content)
	assert_true(U.press(arena, "Fight"))
	assert_null(U.button(arena, "Rematch"), "a run's fight is fought once")
	arena.skip()
	assert_eq(arena.player.sim.combat_log.to_text(), expected.combat_log.to_text(), "the arena plays exactly RunFlow's fight")
	assert_true(U.press(arena, "Continue"))
	assert_true(main.screen is RunDayScreen)
	assert_eq(flow.state.fought.size(), 1)
	assert_eq(flow.state.fought[0].outcome, expected.outcome)
	if expected.outcome == FightResult.Outcome.DEFEAT:
		assert_eq([flow.state.phase, flow.state.attempt], [RunState.Phase.ROUTE, 1], "the day again")
	else:
		assert_string_contains(U.text_of(main.screen), "Choose an upgrade")
		assert_true(U.press(main.screen, "shards instead"))
		assert_true(U.press(main.screen, "To the Pedlar"))
		assert_eq([flow.state.phase, flow.state.shop], [RunState.Phase.SHOP, "pedlar"])
		assert_string_contains(U.text_of(main.screen), "The Pedlar")
		assert_true(U.press(main.screen, "Leave the Pedlar"))
		assert_eq(flow.state.phase, RunState.Phase.NODES)
		assert_true(U.press(main.screen, "Go to Camp"))
		flow.state.camp.assign(["scout"])
		(main.screen as RunDayScreen).refresh()
		assert_true(U.press(main.screen, "Choose"))
		assert_eq(flow.state.scouted, [2, 3] as Array[int])
		assert_true(U.press(main.screen, "On to day 2"))
		assert_eq([flow.state.day, flow.state.phase], [2, RunState.Phase.ROUTE])
	assert_eq(_saved(), JSON.stringify(flow.state.to_dict()))
	await wait_frames(1)


func test_continuing_a_saved_run() -> void:
	var main: Main = _started()
	var saved: String = JSON.stringify(_flow(main).state.to_dict())
	main.show_title()
	assert_true(U.press(main.screen, "Continue the run"))
	assert_true(main.screen is RunDayScreen)
	assert_eq(JSON.stringify(_flow(main).state.to_dict()), saved)
	await wait_frames(1)


func test_a_hunt_at_camp() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["camp"])
	flow.choose_node(0)
	flow.state.camp.assign(["hunt"])
	(main.screen as RunDayScreen).refresh()
	U.press(main.screen, "Choose")
	assert_ne(flow.state.hunt, "")
	assert_false(U.press(main.screen, "On to day") and flow.state.phase != RunState.Phase.NODE, "not before the Hunt")
	assert_true(U.press(main.screen, "Fight the Hunt"))
	var arena: ArenaScreen = main.screen
	assert_eq(arena.encounter.tier, "hunt")
	U.press(arena, "Fight")
	arena.skip()
	U.press(arena, "Continue")
	assert_eq([flow.state.hunt, flow.state.losses, flow.state.phase], ["", 0, RunState.Phase.NODE], "a Hunt is never a loss")
	assert_true(U.press(main.screen, "On to day 2"))
	await wait_frames(1)


func test_the_shop_and_the_loadout() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	flow.state.shards = 20
	flow.state.phase = RunState.Phase.SHOP
	flow.open_shop("pedlar")
	(main.screen as RunDayScreen).refresh()
	assert_string_contains(U.text_of(main.screen), "The Pedlar")
	var ware: String = flow.state.wares[0]
	var numbers: String = ModInfo.item_numbers(flow.run.items[ware], null, flow.run.content)
	assert_false(numbers.is_empty())
	assert_string_contains(U.text_of(main.screen), numbers, "a ware's card shows its amounts (phase 5c, step 2)")
	assert_true(U.press(main.screen, "Buy"))
	assert_eq(flow.state.stash, [ware] as Array[String])
	assert_true(U.press(main.screen, "Leave the Pedlar"))
	assert_true(U.press(main.screen, "Go to Camp"))
	assert_true(U.press(main.screen, "On to day 2"))
	assert_true(U.press(main.screen, "Fight this"))
	assert_string_contains(U.text_of(main.screen), "Stash")
	assert_true(U.press(main.screen, "To Vell"))
	assert_eq(flow.state.hero("vell").slots[0], ware)
	var bar: HeroBar = (main.screen as RunDayScreen).hero_bar
	assert_string_contains(U.text_of(bar), flow.run.items[ware].name, "the hero bar shows the item")
	assert_true(U.press(main.screen, flow.run.items[ware].name), "a filled slot takes it off")
	assert_eq(flow.state.stash, [ware] as Array[String])
	await wait_frames(1)


func test_the_hero_bar_and_panel_in_a_run() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	flow.state.hero("maren").wounds = 2
	flow.state.hero("maren").deeds["deadeye"] = 300
	var day: RunDayScreen = main.screen
	day.refresh()
	var card: HeroBar.Card = day.hero_bar.cards["maren"]
	assert_eq(card.wounds_text.text, "2 wounds")
	var threshold: int = flow.run.content.paths["deadeye"].deed.threshold
	assert_eq(card.deed_text.text, "Deadeye deed 300 / %s" % UnitInfo.deed_amount_text(flow.run.content.paths["deadeye"].deed, threshold))
	assert_almost_eq(card.hp_bar.lost, 0.3, 0.001, "two wounds grey out 30%")
	day.open_panel("maren")
	assert_true(day.hero_panel.visible)
	assert_string_contains(U.text_of(day.hero_panel), "300 / %d" % threshold)
	assert_true(U.press(day.hero_panel, "Switch vow"))
	await wait_frames(1)
	assert_eq(flow.state.hero("maren").path, "trapper", "switched from the panel")
	await wait_frames(1)


func test_the_runs_end() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	flow.state.phase = RunState.Phase.ENDED
	flow.state.outcome = RunState.Outcome.LOST
	main.run_session.save()
	main.show_day()
	assert_string_contains(U.text_of(main.screen), "the run is lost")
	assert_true(U.press(main.screen, "Back to the title"))
	assert_true(main.screen is TitleScreen)
	assert_false(RunSave.has_save(SAVE), "the save goes with the run")
	await wait_frames(1)


## The route is the act map (docs/plans/rebuild-phase5b-art.md, section 4):
## an island a day with its fights, today's clickable; a click shows that
## fight's card, and Fight this takes it.
func test_the_route_is_the_act_map() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	var day: RunDayScreen = main.screen
	var map: ActMap = day.act_map
	assert_not_null(map, "the route shows the map")
	assert_eq(map.fights.size(), flow.run.act.days.size(), "an island a day")
	for each_day: int in map.fights:
		var nodes: Array = map.fights[each_day]
		assert_eq(nodes.size(), (flow.state.options[each_day - 1] as Array).size(), "day %d's fights" % each_day)
		for node: TextureButton in nodes:
			assert_eq(node.disabled, each_day != 1, "only today's can be clicked")
	assert_eq(map.places.keys(), [] as Array, "a day shows its node once one is taken (phase 5c step 8)")
	var second: String = flow.state.today()[1]
	(map.fights[1][1] as TextureButton).pressed.emit()
	assert_eq(map.selected, 1)
	assert_string_contains(U.text_of(day), flow.run.content.encounters[second].name, "its card")
	assert_true(U.press(day, "Fight this"))
	assert_eq(flow.state.chosen, second)
	await wait_frames(1)
	# A day later: day 1's fought fight is marked, and its place still shown.
	flow.state.fought.append(RunState.Fought.from_dict({"day": 1, "attempt": 0, "encounter": second, "outcome": int(FightResult.Outcome.VICTORY), "seconds": 30}))
	flow.state.day = 2
	flow.state.phase = RunState.Phase.ROUTE
	flow.state.taken_nodes.assign(["camp:hunters_blind"])
	day.refresh()
	map = day.act_map
	assert_eq(map._fought_there(1), 1)
	assert_eq((map.fights[1][1] as TextureButton).modulate.a, 1.0, "the fight fought stands out")
	assert_lt((map.fights[1][0] as TextureButton).modulate.a, 1.0, "the other is dimmed")
	assert_eq(map.places.keys(), [1])
	assert_eq(map._place_id(1), "camp:hunters_blind")
	assert_eq(map.places[1].tooltip_text, "Day 1 · %s" % RunDayScreen.node_name(flow.run, "camp:hunters_blind"))
	await wait_frames(1)


func test_what_grew_shows_after_a_fight_and_now_in_the_panel() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	var maren: RunState.Hero = flow.state.hero("maren")
	maren.upgrades.append("notched_bow")
	maren.growth["notched_bow"] = 23
	flow.state.grew.assign(["maren:notched_bow"])
	(main.screen as RunDayScreen).refresh()
	var text: String = U.text_of(main.screen)
	assert_string_contains(text, "What grew")
	assert_string_contains(text, "Notched Bow (Maren): Now: +7% ATK (2 / 3 enemies Marked to the next)")
	await wait_frames(1)
