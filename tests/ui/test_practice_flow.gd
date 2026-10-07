extends GutTest
## Practice from the title (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 1), driven headless through a real Main: title -> encounter list ->
## placement -> fight -> result -> place again, rematch, watch again, and
## back.

const MainScript = preload("res://src/ui/main.gd")
const U = preload("res://tests/ui/ui_test_kit.gd")
const SAVE: String = "user://test_practice_no_save.json"

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


## Main frees a screen it replaces on the next frame, so each test lets one
## pass before it ends.
func _main() -> Main:
	var main: Main = MainScript.new()
	main.old_save_path = SAVE
	main.run_save_path = "user://test_practice_no_run.json"
	add_child_autofree(main)
	return main


func test_the_team_row() -> void:
	var main: Main = _main()
	U.press(main.screen, "Practice")
	var list: EncounterListScreen = main.screen
	assert_eq(list.picked, HeroTeam.DEFAULT)
	assert_true(list.team_buttons["garrow"].disabled, "three are on")
	list.toggle_hero("brannoc")
	assert_string_contains(U.text_of(list), "Pick 1 more.")
	assert_true(U.button(list, "Place your heroes").disabled, "a team is three")
	assert_eq(main.practice.team, HeroTeam.DEFAULT, "the session keeps the last whole team")
	list.toggle_hero("garrow")
	assert_eq(main.practice.team, ["maren", "vell", "garrow"] as Array[String])
	assert_false(U.text_of(list).contains("at base"), "his paths are built")
	U.press(list, "Place your heroes")
	var arena: ArenaScreen = main.screen
	assert_eq(arena.hero_bar.cards.keys(), ["maren", "vell", "garrow"], "the hero bar shows the team")
	await wait_frames(1)


func test_the_encounter_list() -> void:
	var main: Main = _main()
	assert_true(U.press(main.screen, "Practice"))
	assert_true(main.screen is EncounterListScreen)
	assert_not_null(main.practice, "Practice's session is made on the way in")
	var list: EncounterListScreen = main.screen
	var cards: Array[Node] = U.find_all(list, Button).filter(func(node: Node) -> bool: return (node as Button).text == "Place your heroes")
	assert_eq(cards.size(), _content.encounter_ids.size(), "every Act 1 encounter (Decision 7), the run's new ones too")
	var picked: Array[String] = []
	list.encounter_picked.disconnect(main.show_arena)
	list.encounter_picked.connect(func(encounter_id: String) -> void: picked.append(encounter_id))
	for card: Node in cards:
		(card as Button).pressed.emit()
	assert_eq(picked, _content.encounter_ids, "each card picks its own encounter")
	var text: String = U.text_of(list)
	var at: int = -1
	for encounter_id: String in _content.encounter_ids:
		var encounter: EncounterDef = _content.encounters[encounter_id]
		var found: int = text.find(encounter.name + "\n")
		assert_gt(found, at, "%s, in encounters.json's order" % encounter.name)
		at = found
		assert_string_contains(text, "Tests %s · %s" % [encounter.tests, EncounterListScreen.when_text(encounter)])
		for line: String in EncounterListScreen.enemy_lines(encounter, _content):
			assert_string_contains(text, line)
	assert_eq(EncounterListScreen.enemy_lines(_content.encounters["moth_cloud"], _content),
		["2 × Cinder Moth (caster): Burns whoever stands together", "2 × Rift Pup (swarm): Swarms, stronger in packs"] as Array[String])
	assert_true(U.press(list, "Back"))
	assert_true(main.screen is TitleScreen)
	await wait_process_frames(1)


func test_days() -> void:
	assert_eq(EncounterListScreen.when_text(_content.encounters["the_pack"]), EncounterListScreen.days_text(_content.encounters["the_pack"].days), "Act 1's cards name only the days")
	assert_eq(EncounterListScreen.when_text(_content.encounters["the_ford"]), "Act 2 · Days 1-2")
	assert_eq(EncounterListScreen.days_text([3] as Array[int]), "Day 3")
	assert_eq(EncounterListScreen.days_text([1, 2, 3] as Array[int]), "Days 1-3")
	assert_eq(EncounterListScreen.days_text([1, 3] as Array[int]), "Days 1, 3")


func _to_arena(main: Main, encounter_id: String) -> ArenaScreen:
	U.press(main.screen, "Practice")
	var list: EncounterListScreen = main.screen
	list.encounter_picked.emit(encounter_id)
	await wait_process_frames(2)
	return main.screen as ArenaScreen


func test_pick_place_fight_and_the_result() -> void:
	var main: Main = _main()
	U.press(main.screen, "Practice")
	var cards: Array[Node] = U.find_all(main.screen, Button).filter(func(node: Node) -> bool: return (node as Button).text == "Place your heroes")
	(cards[4] as Button).pressed.emit()
	await wait_process_frames(2)
	assert_true(main.screen is ArenaScreen)
	var arena: ArenaScreen = main.screen
	assert_eq(arena.encounter.id, "the_pack", "the fifth card is the fifth encounter (after the two day-1 fights)")
	assert_false(main.backdrop.visible, "the board reads on a quiet background")
	assert_eq(arena.formation, PracticeSession.DEFAULT_FORMATION, "the heroes start guarded the first time")
	arena.move_hero("vell", Vector2i(6, 1))
	arena._fight()
	assert_eq(arena.player.setup.seed_value, 1, "the first fight's seed")
	assert_false(arena.result_box.visible, "no result while it plays")
	arena._process(2.0)
	assert_false(arena.result_box.visible)
	arena.skip()
	assert_true(arena.result_box.visible, "the result, at the end")
	assert_false(arena._controls_box.visible, "in place of the controls")
	var sim: CombatSim = arena.player.sim
	assert_eq(arena.outcome_label.text, ArenaScreen.outcome_text(sim.outcome, arena.player.fight_seconds()))
	assert_eq(arena.result_details.text, ArenaScreen.result_text(sim, arena.names))
	assert_eq(arena.result_chart.tally, arena.tally, "the fight chart, in full")
	assert_eq(U.find_all(arena.result_chart, FightChart.StackedBar).size(), 3)
	assert_lte(arena.result_chart.get_combined_minimum_size().x, float(ArenaScreen.SIDE_WIDTH), "it fits the side column, so the board keeps its size")
	# Rematch: the same placement, the next seed.
	assert_true(U.press(arena, "Rematch"))
	assert_eq(arena.player.setup.seed_value, 2)
	assert_eq(main.practice.seed_value, 2, "remembered for the next fight")
	assert_eq(arena.player.sim.tick, 0, "a fresh fight")
	assert_false(arena.result_box.visible)
	assert_true(arena._controls_box.visible)
	assert_eq(arena.formation["vell"], Vector2i(6, 1), "the same placement")
	arena.skip()
	var end_text: String = arena.outcome_label.text
	# Watch again: the same fight from the start.
	assert_true(U.press(arena, "Watch again"))
	assert_eq([arena.player.sim.tick, arena.player.setup.seed_value], [0, 2])
	assert_false(arena.result_box.visible)
	arena.skip()
	assert_eq(arena.outcome_label.text, end_text, "the same fight, the same end")
	# Place again, then back to the list; the formation is remembered.
	assert_true(U.press(arena, "Place again"))
	assert_eq(arena.view.mode, ArenaView.Mode.PLACEMENT)
	assert_false(arena.result_box.is_visible_in_tree())
	assert_true(U.press(arena, "Back"))
	assert_true(main.screen is EncounterListScreen)
	var again: ArenaScreen = await _to_arena_from_list(main, "hollow_line")
	assert_eq(again.formation["vell"], Vector2i(6, 1), "the last formation fought with, in another encounter (Decision 4)")
	again._fight()
	assert_eq(again.player.setup.seed_value, 2, "the seed carries on")
	await wait_process_frames(1)


func _to_arena_from_list(main: Main, encounter_id: String) -> ArenaScreen:
	(main.screen as EncounterListScreen).encounter_picked.emit(encounter_id)
	await wait_process_frames(2)
	return main.screen as ArenaScreen


func test_the_result_text() -> void:
	var main: Main = _main()
	var arena: ArenaScreen = await _to_arena(main, "the_pack")
	arena._fight()
	var sim: CombatSim = arena.player.sim
	sim.unit_by_id("maren").alive = false
	sim.unit_by_id("brannoc").hp = 120
	assert_eq(ArenaScreen.result_text(sim, arena.names), "Seed 1 (it only changes crits)\nBrannoc 120/630 HP · Maren fell · Vell 300/300 HP",
		"no paths, no deeds (the hero panel has them)")
	await wait_process_frames(1)


func test_the_result_is_filled_once_and_cleared_by_a_restart() -> void:
	var main: Main = _main()
	var arena: ArenaScreen = await _to_arena(main, "the_pack")
	arena._fight()
	arena.skip()
	var shown: String = arena.result_details.text
	arena.result_details.text = "changed"
	arena._process(0.5)
	assert_eq(arena.result_details.text, "changed", "filled in once, when the fight ends")
	arena.restart()
	assert_false(arena._result_shown)
	arena.skip()
	assert_eq(arena.result_details.text, shown)
	await wait_process_frames(1)
