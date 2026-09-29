extends GutTest
## Paths in Practice (docs/plans/rebuild-phase4-paths.md, section 6): the
## session keeping each hero's path and stage, the hero panel (its tabs,
## track, cards, back and forward), choosing a path and stage, the board's
## figures and tags, placing a transformed Trapper's snares, the fight on
## screen being the sim's own, and the result's deeds.

const U = preload("res://tests/ui/ui_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _screen(encounter_id: String = "the_pack", session: PracticeSession = null) -> ArenaScreen:
	var screen: ArenaScreen = ArenaScreen.make(session if session != null else PracticeSession.make(_content), encounter_id)
	add_child_autofree(screen)
	screen.size = Vector2(1900, 1000)
	screen.setup()
	await wait_process_frames(2)
	return screen


func _click(screen: ArenaScreen, unit_id: String) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = false
	click.position = screen.view.token(unit_id).center()
	screen.view._gui_input(click)


## The button `text` on the panel's card for `path_name`, or null.
func _card_button(panel: HeroPanel, path_name: String, text: String) -> Button:
	for node: Node in U.find_all(panel.page, PanelContainer):
		var card := node as PanelContainer
		var heading: Label = U.find_all(card, Label)[0]
		if heading.text == path_name:
			return U.button(card, text)
	return null


func _press_card(screen: ArenaScreen, path_name: String, text: String) -> void:
	var button: Button = _card_button(screen.hero_panel, path_name, text)
	assert_not_null(button, "%s has %s" % [path_name, text])
	if button != null:
		button.pressed.emit()
	await wait_process_frames(2)


func test_the_session_keeps_each_heros_path_and_stage() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	assert_eq(session.stage_of("maren"), PathDef.Stage.BASE)
	assert_eq(session.kit_of("maren"), _content.heroes["maren"].kit)
	session.set_path("maren", "deadeye", PathDef.Stage.VOWED)
	session.set_path("maren", "hearthwall", PathDef.Stage.VOWED)
	assert_eq(session.vows, {"maren": "deadeye"} as Dictionary[String, String], "another hero's path is ignored")
	assert_eq(session.kit_of("maren"), _content.paths["deadeye"].vowed_kit)
	session.set_path("brannoc", "ironbrand", PathDef.Stage.TRANSFORMED)
	assert_eq(session.stage_of("brannoc"), PathDef.Stage.TRANSFORMED)
	var fight: FightSetup = session.setup("the_pack", PracticeSession.DEFAULT_FORMATION)
	assert_eq([fight.heroes[0].path, fight.heroes[0].stage, fight.heroes[1].path, fight.heroes[1].stage, fight.heroes[2].path],
		[_content.paths["ironbrand"], PathDef.Stage.TRANSFORMED, _content.paths["deadeye"], PathDef.Stage.VOWED, null])
	assert_eq(fight.heroes[0].def, _content.paths["ironbrand"].transformed_kit)
	session.set_path("brannoc", "", PathDef.Stage.BASE)
	assert_eq(session.vows, {"maren": "deadeye"} as Dictionary[String, String])
	assert_eq(session.transformed, [] as Array[String])


func test_a_tactic_the_new_kit_cant_take_is_dropped() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	session.set_tactic("vell", "wait_to_heal")
	session.set_path("vell", "wardweaver", PathDef.Stage.VOWED)
	assert_eq(session.tactics, {"vell": "wait_to_heal"} as Dictionary[String, String], "Ward Thread still heals")
	session.set_path("vell", "wardweaver", PathDef.Stage.TRANSFORMED)
	assert_eq(session.tactics, {} as Dictionary[String, String], "Warding Circle doesn't (Decision 7)")
	assert_false(session.tactics_for("vell").any(func(tactic: TacticDef) -> bool: return tactic.id == "wait_to_heal"))
	session.set_tactic("vell", "wait_to_heal")
	assert_eq(session.tactics, {} as Dictionary[String, String])
	assert_eq(session.errors("the_pack", PracticeSession.DEFAULT_FORMATION), [] as Array[String])


func test_a_transformed_trapper_places_her_snares() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	session.set_path("maren", "trapper", PathDef.Stage.VOWED)
	assert_false(session.snares.has("maren"), "the vowed kit places none")
	session.set_path("maren", "trapper", PathDef.Stage.TRANSFORMED)
	assert_eq(session.snares["maren"], [Vector2i(2, 3), Vector2i(5, 3)])
	var formation: Dictionary[String, Vector2i] = PracticeSession.DEFAULT_FORMATION
	assert_eq(session.setup("the_pack", formation).heroes[1].snares, [Vector2i(2, 3), Vector2i(5, 3)] as Array[Vector2i])
	assert_false(session.move_snare("the_pack", formation, "maren", 0, Vector2i(2, 5)), "not in the enemies' half")
	assert_eq(session.snares["maren"], [Vector2i(2, 3), Vector2i(5, 3)])
	assert_true(session.move_snare("the_pack", formation, "maren", 0, Vector2i(1, 2)))
	assert_true(session.move_snare("the_pack", formation, "maren", 0, Vector2i(5, 3)), "onto the other: a swap")
	assert_eq(session.snares["maren"], [Vector2i(5, 3), Vector2i(1, 2)])
	session.snares["maren"] = [Vector2i(9, 9), Vector2i(1, 2)]
	session.fit_snares("the_pack", formation)
	assert_eq(session.errors("the_pack", formation), [] as Array[String], "fitted onto legal hexes")
	assert_eq(session.snares["maren"][1], Vector2i(1, 2), "a legal one stays")
	session.set_path("maren", "deadeye", PathDef.Stage.TRANSFORMED)
	assert_false(session.snares.has("maren"), "dropped with the path")


func test_the_panel_opens_on_the_path_tab_and_chooses_paths() -> void:
	var screen: ArenaScreen = await _screen()
	_click(screen, "maren")
	await wait_process_frames(2)
	var panel: HeroPanel = screen.hero_panel
	assert_true(panel.visible)
	assert_eq([panel.showing, panel.tab], ["maren", HeroPanel.Tab.PATH])
	assert_eq([panel.form_tag.text, panel.hero_name.text], ["Base form", "Maren Thistledown"])
	var text: String = U.text_of(panel)
	for said: String in ["Base", "Vow", "Transform", "Upgrades", "Apex", "Not vowed", "Opens on transforming", "Later in the run", "No vow"]:
		assert_string_contains(text, said)
	for path: PathDef in _content.heroes["maren"].paths:
		assert_string_contains(text, path.name)
		assert_string_contains(text, "Deed: %s · no fight yet" % path.deed.text)
	await _press_card(screen, "Deadeye", "Vow")
	assert_eq(screen.session.vows, {"maren": "deadeye"} as Dictionary[String, String])
	assert_eq([screen.view.token("maren").path_label, screen.view.token("maren").art_key], ["Deadeye (vow)", "heroes/maren_base"], "a vowed hero keeps her base figure")
	text = U.text_of(panel)
	assert_string_contains(text, HeroPanel.VOWED_TEXT)
	assert_string_contains(text, "Taste: " + _content.paths["deadeye"].taste)
	assert_string_contains(text, "Cost: " + _content.paths["deadeye"].vowed_cost)
	assert_eq(panel.form_tag.text, "Deadeye · vowed")
	await _press_card(screen, "Deadeye", "Transform")
	assert_eq(screen.session.stage_of("maren"), PathDef.Stage.TRANSFORMED)
	assert_eq([screen.view.token("maren").path_label, screen.view.token("maren").art_key], ["Deadeye", "heroes/maren_deadeye"], "transformed: her path's figure")
	text = U.text_of(panel)
	assert_string_contains(text, HeroPanel.TRANSFORMED_TEXT)
	assert_string_contains(text, "Transformed: " + _content.paths["deadeye"].transformed_text)
	await _press_card(screen, "Volley", "Vow")
	assert_eq(screen.session.vows, {"maren": "volley"} as Dictionary[String, String], "another card's Vow switches paths")
	assert_eq(screen.session.stage_of("maren"), PathDef.Stage.VOWED)
	await _press_card(screen, "Volley", "Base (no path)")
	assert_eq(screen.session.vows, {} as Dictionary[String, String])
	assert_eq(screen.view.token("maren").path_label, "")


func test_the_kit_tab_is_the_kit_at_the_heros_stage() -> void:
	var screen: ArenaScreen = await _screen()
	screen.session.set_path("vell", "vigil_keeper", PathDef.Stage.TRANSFORMED)
	_click(screen, "vell")
	screen.hero_panel.show_tab(HeroPanel.Tab.KIT)
	var text: String = U.text_of(screen.hero_panel.page)
	for line: UnitInfo.Line in UnitInfo.lines(_content.paths["vigil_keeper"].transformed_kit, "Vell", _content):
		assert_string_contains(text, line.name)
	assert_string_contains(text, "Sunfall")
	assert_eq(screen.hero_panel.stats.text, UnitInfo.stats_text(_content.paths["vigil_keeper"].transformed_kit.stats))


func test_back_forward_and_close() -> void:
	var screen: ArenaScreen = await _screen()
	_click(screen, "maren")
	screen.hero_panel.show_tab(HeroPanel.Tab.KIT)
	assert_true(U.press(screen.hero_panel, ">"))
	assert_eq([screen.hero_panel.showing, screen.hero_panel.tab], ["vell", HeroPanel.Tab.KIT], "the same tab")
	assert_true(U.press(screen.hero_panel, ">"))
	assert_eq(screen.hero_panel.showing, "brannoc", "round to the first")
	assert_true(U.press(screen.hero_panel, "<"))
	assert_eq(screen.hero_panel.showing, "vell")
	assert_true(U.press(screen.hero_panel, "Close"))
	assert_false(screen.hero_panel.visible)
	_click(screen, "vell")
	await wait_process_frames(2)
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.global_position = screen.hero_panel.frame.get_global_rect().position + Vector2(4, 4)
	screen.hero_panel._gui_input(outside)
	assert_true(screen.hero_panel.visible, "a click on the panel keeps it open")
	outside.global_position = screen.hero_panel.frame.get_global_rect().end + Vector2(4, 4)
	screen.hero_panel._gui_input(outside)
	assert_false(screen.hero_panel.visible, "a click beside the panel closes it")


func test_snare_markers_are_dragged_like_heroes() -> void:
	var screen: ArenaScreen = await _screen()
	screen.choose_path("maren", "trapper", PathDef.Stage.TRANSFORMED)
	assert_eq(screen.view.snare_markers.size(), 2)
	var view: ArenaView = screen.view
	var first: Vector2 = view.to_pixel(view.grid.center(2, 3))
	assert_eq(view.snare_at(first), view.snare_markers[0])
	var data: Variant = {"snare": "maren", "index": 0}
	assert_true(view._can_drop_data(first, data))
	view._drop_data(view.to_pixel(view.grid.center(2, 5)), data)
	assert_eq(view.flashing, Vector2i(2, 5), "the enemies' half is refused")
	assert_eq(screen.session.snares["maren"][0], Vector2i(2, 3))
	view._drop_data(view.to_pixel(view.grid.center(1, 1)), data)
	assert_eq(screen.session.snares["maren"][0], Vector2i(1, 1))
	assert_eq(view.snare_markers[0].hex, Vector2i(1, 1), "the board shows it")
	assert_eq(screen.current_setup().heroes[1].snares[0], Vector2i(1, 1))
	screen._fight()
	assert_eq(view.snare_markers.size(), 2)
	view._drop_data(view.to_pixel(view.grid.center(2, 2)), data)
	assert_eq(screen.session.snares["maren"][0], Vector2i(1, 1), "no moving them in a fight")


func test_the_fight_plays_with_paths_and_the_result_names_the_deeds() -> void:
	var screen: ArenaScreen = await _screen()
	screen.choose_path("brannoc", "hearthwall", PathDef.Stage.TRANSFORMED)
	screen.choose_path("maren", "trapper", PathDef.Stage.TRANSFORMED)
	screen.choose_path("vell", "lanternbearer", PathDef.Stage.VOWED)
	screen._fight()
	var frames: int = 0
	while not screen.player.finished() and frames < 20000:
		screen._process(1.0 / 20.0)
		frames += 1
	assert_true(screen.player.finished())
	var result: FightResult = CombatSim.run(screen.player.setup, _content)
	assert_eq(screen.player.sim.combat_log.to_text(), result.combat_log.to_text(), "the sim's own fight, paths and all")
	var details: String = screen.result_details.text
	assert_string_contains(details, "Paths: Brannoc, Hearthwall (transformed) · Maren, Trapper (transformed) · Vell, Lanternbearer (vowed)")
	var trapper: int = result.deed_amount("maren", "trapper")
	assert_gt(trapper, 0, "her snares rooted something")
	assert_string_contains(details, "Maren: Trapper %s · Deadeye" % UnitInfo.deed_amount_text(_content.paths["trapper"].deed, trapper), "the vowed path first")
	assert_string_contains(details, "Brannoc: Hearthwall")
	assert_eq(screen.session.last_deed("maren", "trapper"), trapper, "the session keeps it")
	screen.place_again()
	_click(screen, "maren")
	assert_string_contains(U.text_of(screen.hero_panel), "last fight: %s" % UnitInfo.deed_amount_text(_content.paths["trapper"].deed, trapper))


func test_guard_counts_as_damage_taken_for_the_guard() -> void:
	var setup: FightSetup = FightSetup.make([], [], [], 1, 1)
	var brannoc: UnitSetup = UnitSetup.make(_content.heroes["brannoc"].kit, EffectSource.Team.HEROES, 3, 2)
	var vell: UnitSetup = UnitSetup.make(_content.heroes["vell"].kit, EffectSource.Team.HEROES, 2, 1)
	setup.heroes.assign([brannoc, vell])
	var tally: FightTally = FightTally.make(setup, {"brannoc": "Brannoc", "vell": "Vell"} as Dictionary[String, String])
	var entry: LogEntry = LogEntry.new()
	entry.kind = LogEntry.Kind.GUARD
	entry.source_unit = "brannoc"
	entry.source_ability_name = "Guard"
	entry.target = "vell"
	entry.amount = 30
	entry.absorbed = 10
	tally.add(entry)
	var bar: FightTally.Bar = tally.bar(FightTally.Tab.TAKEN, "brannoc")
	assert_eq(bar.by_type, [20, 10] as Array[int])
	assert_eq(bar.sources, {"Guard for Vell": 30})
	assert_eq(tally.bar(FightTally.Tab.TAKEN, "vell").total(), 0)
