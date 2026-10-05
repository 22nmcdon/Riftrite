extends GutTest
## The run on screen (docs/plans/rebuild-phase5-run.md, section 11), driven
## headless through a real Main: the title's New run and Continue, vowing,
## a day (route, loadout, the fight, the Pedlar, a node), the fight on the arena (exactly RunFlow's),
## the pick after it, a Hunt, the hero bar and panel in a run, and the run's
## end. Every action is saved.

const ActsTest = preload("res://tests/run/test_acts.gd")
const SpecsTest = preload("res://tests/run/test_specializations.gd")
const MainScript = preload("res://src/ui/main.gd")
const U = preload("res://tests/ui/ui_test_kit.gd")
const Bot = preload("res://tools/run_bot.gd")
const SAVE: String = "user://test_run_screens.json"
const OLD_SAVE: String = "user://test_run_screens_old.json"
const RECORDS: String = "user://test_run_screens_records.json"


func after_each() -> void:
	RunSave.erase(SAVE)
	if FileAccess.file_exists(RECORDS):
		DirAccess.remove_absolute(RECORDS)


## Main frees a screen it replaces on the next frame, so each test lets one
## pass before it ends.
func _main() -> Main:
	var main: Main = MainScript.new()
	main.old_save_path = OLD_SAVE
	main.run_save_path = SAVE
	main.records_path = RECORDS
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


## Endless (phase 8 part 1): the choice after the act's boss shop, a
## floor's top bar and route, and the end, with the deepest floor kept.
func test_going_deeper_and_falling_on_a_floor() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	flow.state.day = main.run_session.run.acts[0].days.size()
	flow.state.phase = RunState.Phase.CHOICE
	flow.state.testing = true
	main.run_session.save()
	main.show_day()
	var text: String = U.text_of(main.screen)
	assert_string_contains(text, "Old Mother Ash is beaten")
	assert_not_null(U.button(main.screen, "End the run"))
	assert_true(U.press(main.screen, "Go deeper"))
	text = U.text_of(main.screen)
	assert_string_contains(text, "Floor 1")
	assert_string_contains(text, "Endless")
	assert_string_contains(text, "The first loss ends the run")
	assert_string_contains(text, "enemies ×1.15 HP and ATK, Rift Collapse from 44s")
	assert_true(U.press(main.screen, "Fight this"))
	var lost := FightResult.new()
	lost.outcome = FightResult.Outcome.DEFEAT
	lost.end_tick = 400
	main.finish_run_fight(Bot.formation(), lost)
	text = U.text_of(main.screen)
	assert_string_contains(text, "The rift takes them on floor 1")
	assert_string_contains(text, "A new deepest: floor 1.")
	assert_eq(int(RunRecords.best(RECORDS)["floor"]), 1, "the records keep it")
	await wait_frames(1)


## Apexes (phase 8 part 2): the apex vow is open from the act's end (phase 8
## part 3); the day shows each waiting hero's apexes, Vow takes one, and the
## hero bar fills its deed.
func test_the_apex_vow_after_going_deeper() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	var maren: RunState.Hero = flow.state.hero("maren")
	maren.path = "volley"
	maren.transformed = true
	flow.state.day = main.run_session.run.acts[0].days.size()
	flow.state.phase = RunState.Phase.CHOICE
	flow.state.testing = true
	# As leaving Act 1's boss shop leaves it (phase 8 part 3, Decision 2).
	flow.state.apex_open = true
	main.run_session.save()
	main.show_day()
	assert_string_contains(U.text_of(main.screen), "The apex vow is open", "at the choice already")
	assert_true(U.press(main.screen, "Go deeper"))
	var text: String = U.text_of(main.screen)
	assert_string_contains(text, "The apex vow is open")
	assert_string_contains(text, "Taste: " + flow.run.content.apexes["hailstorm"].taste)
	assert_true(U.press(main.screen, "Vow to Hailstorm"))
	assert_eq(maren.apex, "hailstorm")
	text = U.text_of(main.screen)
	assert_false(text.contains("The apex vow is open"), "answered")
	assert_string_contains(text, "Volley · Hailstorm vowed")
	assert_string_contains(text, "Hailstorm deed 0 / ")
	assert_eq(RunSave.load_state(main.run_session.save_path).hero("maren").apex, "hailstorm", "saved")
	# Earned: the day after the fight says so, and the bar names the apex.
	maren.apex_earned = true
	flow.state.just_apexed.assign(["maren"])
	main.run_session.save()
	main.show_day()
	text = U.text_of(main.screen)
	assert_string_contains(text, "reaches the apex: Hailstorm")
	assert_string_contains(text, flow.run.content.apexes["hailstorm"].text)
	assert_string_contains(text, "Volley deed")
	await wait_frames(1)


func test_big_numbers_are_short() -> void:
	assert_eq([UiStyle.short_number(9999), UiStyle.short_number(12400), UiStyle.short_number(3150000), UiStyle.short_number(-25000)], ["9999", "12.4k", "3.1M", "-25.0k"])
	assert_eq([RunDayScreen.times(15209), RunDayScreen.times(662118), RunDayScreen.times(120000000)], ["1.52", "66.2", "12.0k"])


## The route is the act map (docs/plans/rebuild-phase5b-art.md, section 4):
## an island a day with its fights, today's clickable; a click shows that
## fight's card, and Fight this takes it.
func test_the_route_is_the_act_map() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	var day: RunDayScreen = main.screen
	var map: ActMap = day.act_map
	assert_not_null(map, "the route shows the map")
	assert_eq(map.fights.size(), flow.run.acts[0].days.size(), "an island a day")
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


## A Rift Tear's depths and the Shrine's offerings on screen (phase 5c
## step 8b).
func test_a_rift_tear_and_the_shrine() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	var day: RunDayScreen = main.screen
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["camp", "rift_tear"])
	day.refresh()
	assert_true(U.press(day, "Go to Rift Tear"))
	for name: String in ["Go shallow", "Go deep", "Go abyssal"]:
		assert_not_null(U.button(day, name), name)
	var first: CampsDef.Modifier = flow.run.camps.modifiers[Offers.rift_modifiers(flow.run, flow.state)[0]]
	assert_string_contains(U.text_of(day), first.name, "the depths' cards show the day's modifiers")
	assert_false(U.press(day, "On to day 2") and flow.state.day == 2, "not before a depth")
	assert_true(U.press(day, "Go deep"))
	assert_eq(flow.state.rift_depth, "deep")
	assert_true(U.press(day, "On to day 2"))
	assert_string_contains(U.text_of(day), "Through a Deep rift tear", "tomorrow's fight names the tear")
	# The Shrine.
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["camp"])
	flow.choose_node(0)
	flow.state.camp.assign(["shrine"])
	flow.state.shards = 20
	day.refresh()
	assert_true(U.press(day, "Choose"))
	assert_not_null(U.button(day, "Offer 15 shards"))
	assert_true(U.press(day, "Offer a wound on Maren"))
	assert_true(U.press(day, "Take · a wound on Maren"))
	assert_eq([flow.state.hero("maren").wounds, flow.state.relics.size()], [1, 1])
	await wait_frames(1)


## An event's scene and a Bloodied Oath on screen (phase 5c step 8c).
func test_an_event_and_an_oath() -> void:
	var main: Main = _started()
	var flow: RunFlow = _flow(main)
	var day: RunDayScreen = main.screen
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["camp", "event:kneeling_knight", "oath"])
	day.refresh()
	assert_string_contains(U.text_of(day), "The Kneeling Knight", "the event's card names its scene")
	assert_true(U.press(day, "Go to The Kneeling Knight"))
	assert_not_null(U.button(day, "Walk away · on to day 2"), "walking away is always there")
	flow.state.hero("vell").wounds = 3
	day.refresh()
	assert_true(U.button(day, "Take his blade · Vell").disabled, "greyed where it can't be done")
	assert_true(U.press(day, "Take his blade · Maren"))
	assert_eq(flow.state.hero("maren").wounds, 1)
	assert_not_null(U.button(day, "On to day 2"))
	# A Bloodied Oath.
	flow.state.phase = RunState.Phase.NODES
	flow.state.node = ""
	flow.state.event_done = false
	day.refresh()
	assert_true(U.press(day, "Go to A Bloodied Oath"))
	var sworn: String = flow.state.oath_offer[0].get_slice(":", 1)
	assert_true(U.press(day, "Swear %s to it" % ArenaView.label_for(flow.run.content.heroes[sworn].kit, flow.run.content)))
	assert_ne(flow.state.hero(sworn).oath, "")
	assert_string_contains(day.hero_bar.cards[sworn].wounds_text.text, "(2 fights)", "the hero bar shows the oath")
	await wait_frames(1)


## Acts (phase 8 part 3), on the stand-in acts: the start screen's testing
## option, the choice after Act 1 in a testing run, and on to Act 2.
func test_the_testing_option_and_on_to_act_2() -> void:
	var main: Main = _main()
	main._run_content = ActsTest.stand_in_acts()
	assert_true(U.press(main.screen, "New run"))
	(main.screen as RunStartScreen).run_seed = 7
	var box: Button = U.button(main.screen, "Endless after Act 1 (for testing)")
	assert_false(box.button_pressed, "off by default")
	box.button_pressed = true
	assert_true(U.press(main.screen, "Into the rift"))
	var flow: RunFlow = _flow(main)
	assert_true(flow.state.testing, "the start screen's testing option")
	flow.state.day = flow.act.days.size()
	flow.state.phase = RunState.Phase.SHOP
	flow.open_shop("pedlar")
	main.run_session.save()
	main.show_day()
	assert_true(U.press(main.screen, "Leave the Pedlar: on to Act 2, or go deeper"))
	var text: String = U.text_of(main.screen)
	assert_string_contains(text, "Act 1 is won")
	assert_not_null(U.button(main.screen, "Go deeper (testing)"))
	assert_true(U.press(main.screen, "On to Act 2"))
	text = U.text_of(main.screen)
	assert_string_contains(text, "Day 1 of 7")
	assert_string_contains(text, "Act 2")
	assert_eq([flow.state.act, flow.state.phase], [2, RunState.Phase.ROUTE])
	await wait_frames(1)


## Specializations (phase 8 part 3) on today's fight card, on the stand-in
## acts with Act 2 specializing from day 3.
func test_the_fight_card_names_specializations() -> void:
	var main: Main = _main()
	main._run_content = SpecsTest.specialized_acts()
	assert_true(U.press(main.screen, "New run"))
	(main.screen as RunStartScreen).run_seed = 7
	assert_true(U.press(main.screen, "Into the rift"))
	var flow: RunFlow = _flow(main)
	flow.state.act = 2
	flow.state.day = 4
	# A seed whose first fight on day 4 has one.
	for run_seed: int in range(1, 40):
		flow.state.seed_value = run_seed
		flow.state.options = ActDraw.draw(flow.run, run_seed, flow.run.acts[1])
		flow._start_day()
		if flow.state.today_specs[0].any(func(id: Variant) -> bool: return not str(id).is_empty()):
			break
	main.run_session.save()
	main.show_day()
	var line: String = RunDayScreen.specs_line(flow.run.content, flow.run.content.encounters[flow.state.today()[0]], flow.state.today_specs[0])
	assert_false(line.is_empty(), "a first fight on day 4 with one")
	assert_string_contains(U.text_of(main.screen), line.get_slice("\n", 0))
	await wait_frames(1)


## The boss day names its act's boss (8c-6b), not always Old Mother Ash.
func test_the_boss_day_names_the_acts_boss() -> void:
	var main: Main = _main()
	assert_true(U.press(main.screen, "New run"))
	(main.screen as RunStartScreen).run_seed = 7
	assert_true(U.press(main.screen, "Into the rift"))
	var flow: RunFlow = _flow(main)
	flow.state.day = 7
	flow.state.options[6] = ["the_heart_of_the_rift"]
	main.run_session.save()
	main.show_day()
	assert_string_contains(U.text_of(main.screen), "The Heart of the Rift waits.")
	await wait_frames(1)


## What the rift learned (phase 8 part 3, 8c-5d) on the boss's fight card:
## its own line naming the habit, and not again among the specializations.
func test_the_fight_card_names_what_the_rift_learned() -> void:
	var main: Main = _main()
	assert_true(U.press(main.screen, "New run"))
	(main.screen as RunStartScreen).run_seed = 7
	assert_true(U.press(main.screen, "Into the rift"))
	var flow: RunFlow = _flow(main)
	flow.state.options[0] = ["old_mother_ash"]
	flow.state.today_specs = [["", "drifting_moth", ""]] as Array[Array]
	flow.state.today_learned = [[{"enemy": 1, "habit": "bunching", "specialization": "drifting_moth"}, {"enemy": 2, "habit": "roots", "upgrade": "anchored"}]] as Array[Array]
	main.run_session.save()
	main.show_day()
	var text: String = U.text_of(main.screen)
	assert_string_contains(text, "Learned: Drifting Ash Hound, against your bunching up: ")
	assert_string_contains(text, "Anchored Ash Hound, against your Roots: It can't be knocked back or pulled")
	assert_false(text.contains("Specialized:"), "a learned specialization is named once, as learned")
	await wait_frames(1)


## Upgrades (phase 8 part 3, 8c-5a) on an elite's fight card, and in the
## enemy panel with the enemy's name.
func test_the_fight_card_and_enemy_panel_name_upgrades() -> void:
	var main: Main = _main()
	assert_true(U.press(main.screen, "New run"))
	(main.screen as RunStartScreen).run_seed = 7
	assert_true(U.press(main.screen, "Into the rift"))
	var flow: RunFlow = _flow(main)
	flow.state.options[0] = ["witch_coven"]
	flow.state.today_upgrades = [["frenzied", "warded"]] as Array[Array]
	main.run_session.save()
	main.show_day()
	assert_string_contains(U.text_of(main.screen), "Upgraded: Frenzied: It attacks faster once it's below half its HP.")
	assert_string_contains(U.text_of(main.screen), "Warded: It starts the fight behind a Shield.")
	var content: ContentDb = flow.run.content
	var panel: EnemyPanel = EnemyPanel.make()
	add_child_autofree(panel)
	var kit: UnitDef = content.enemy_upgrades["warded"].apply(content.enemy_upgrades["frenzied"].apply(content.enemies["gloam_witch"].kit))
	panel.show_enemy("gloam_witch", content.enemies["gloam_witch"], content, kit)
	assert_eq(panel.title.text, "Warded Frenzied Gloam Witch")
	assert_string_contains(panel.threat.text, "Frenzied: It attacks faster")
	assert_string_contains(panel.threat.text, "Warded: It starts the fight behind a Shield.")
	assert_true(U.text_of(panel).contains("Warded"), "its passives listed")
	await wait_frames(1)
