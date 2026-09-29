extends GutTest
## Tactics in Practice (docs/plans/rebuild-phase3b-tactics.md, section 4):
## choosing one in the hero panel's Loadout tab while placing (phase 4), the board naming it,
## remembering it, the fight on screen being the sim's own fight with it,
## what a tactic did showing over the hero, and the result naming them.

const U = preload("res://tests/ui/ui_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _screen(encounter_id: String = "witch_circle", session: PracticeSession = null) -> ArenaScreen:
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


## Opens a hero's panel on its Loadout tab (placing).
func _loadout(screen: ArenaScreen, hero_id: String) -> TacticPicker:
	screen.open_panel(hero_id)
	screen.hero_panel.show_tab(HeroPanel.Tab.LOADOUT)
	return screen.hero_panel.tactic_picker


func _button_texts(picker: TacticPicker) -> Array[String]:
	var texts: Array[String] = []
	for button: Button in picker.tactic_buttons:
		texts.append(button.text)
	return texts


func test_the_session_keeps_each_heros_tactic() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	assert_eq(session.tactics_for("maren").map(func(tactic: TacticDef) -> String: return tactic.id), ["casters_first", "hold_ground", "plant_feet"])
	assert_eq(session.tactics_for("vell").map(func(tactic: TacticDef) -> String: return tactic.id), ["casters_first", "hold_ground", "wait_to_heal", "plant_feet"])
	session.set_tactic("maren", "hold_ground")
	session.set_tactic("maren", "wait_to_heal")
	assert_eq(session.tactics, {"maren": "hold_ground"} as Dictionary[String, String], "one Maren can't take is ignored")
	var fight: FightSetup = session.setup("witch_circle", PracticeSession.DEFAULT_FORMATION)
	assert_eq(fight.heroes[1].tactic, _content.tactics["hold_ground"])
	assert_eq(session.errors("witch_circle", PracticeSession.DEFAULT_FORMATION), [] as Array[String])
	var two: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "vell": Vector2i(4, 0)}
	assert_eq(session.errors("witch_circle", two), [] as Array[String], "a formation without Maren leaves her tactic out")
	assert_eq(session.formation_for("witch_circle"), PracticeSession.DEFAULT_FORMATION, "and the remembered formation still places")
	session.set_tactic("maren", "")
	assert_eq(session.tactics, {} as Dictionary[String, String])


func test_choosing_a_tactic_in_the_hero_panel() -> void:
	var screen: ArenaScreen = await _screen()
	var picker: TacticPicker = _loadout(screen, "maren")
	assert_true(screen.hero_panel.visible)
	assert_false(screen.hero_popup.visible, "the panel, not the popup, while placing")
	assert_eq(_button_texts(picker), ["None", "Casters first", "Hold your ground", "Plant your feet"] as Array[String])
	assert_true(picker.tactic_buttons[0].button_pressed, "none to begin with")
	assert_eq(screen.view.token("maren").tactic_label, "")
	assert_true(U.press(picker, "Hold your ground"))
	await wait_process_frames(2)
	assert_eq(screen.session.tactics, {"maren": "hold_ground"} as Dictionary[String, String])
	assert_eq(screen.view.token("maren").tactic_label, "Hold your ground", "the board names it under her")
	assert_true(screen.hero_panel.visible, "the panel stays open")
	assert_eq(screen.hero_panel.tab, HeroPanel.Tab.LOADOUT, "on its tab")
	picker = screen.hero_panel.tactic_picker
	assert_true(picker.tactic_buttons[2].button_pressed)
	assert_false(picker.tactic_buttons[0].button_pressed)
	assert_string_contains(picker.tactic_text.text, "within 2 hexes", "with its sentence")
	assert_eq(picker.tactic_numbers.text, "Holds until an enemy is within 2 hexes · +20% attack speed while it holds", "and its numbers line")
	assert_true(picker.tactic_numbers.visible)
	assert_eq(screen.current_setup().heroes[1].tactic, _content.tactics["hold_ground"])
	picker = _loadout(screen, "vell")
	assert_eq(_button_texts(picker), ["None", "Casters first", "Hold your ground", "Wait to heal", "Plant your feet"] as Array[String])
	assert_true(U.press(picker, "Wait to heal"))
	await wait_process_frames(2)
	assert_eq(screen.view.token("vell").tactic_label, "Wait to heal")
	picker = _loadout(screen, "maren")
	assert_true(U.press(picker, "None"))
	await wait_process_frames(2)
	assert_false(screen.hero_panel.tactic_picker.tactic_numbers.visible, "no numbers line with no tactic")
	assert_eq(screen.session.tactics, {"vell": "wait_to_heal"} as Dictionary[String, String])
	assert_eq(screen.view.token("maren").tactic_label, "")


func test_tactics_are_remembered_across_encounters() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	var first: ArenaScreen = await _screen("witch_circle", session)
	U.press(_loadout(first, "brannoc"), "Hold your ground")
	await wait_process_frames(2)
	var second: ArenaScreen = await _screen("the_pack", session)
	assert_eq(second.view.token("brannoc").tactic_label, "Hold your ground")
	assert_eq(second.current_setup().heroes[0].tactic, _content.tactics["hold_ground"])


func test_the_fight_plays_with_the_tactics_and_shows_them() -> void:
	var screen: ArenaScreen = await _screen()
	screen.session.set_tactic("brannoc", "hold_ground")
	screen.session.set_tactic("maren", "casters_first")
	screen.session.set_tactic("vell", "wait_to_heal")
	screen._show()
	screen._fight()
	assert_eq(screen.view.token("brannoc").tactic_label, "Hold your ground", "(the label stays on the token)")
	var popups: Dictionary[String, bool] = {}
	var frames: int = 0
	while not screen.player.finished() and frames < 20000:
		screen._process(1.0 / 30.0)
		for fx: FightFx.Fx in screen.view.fx.effects:
			if fx.kind == FightFx.Kind.POPUP:
				popups[fx.text] = true
		frames += 1
	assert_true(screen.player.finished())
	assert_eq(screen.player.sim.combat_log.to_text(), CombatSim.run(screen.player.setup, _content).combat_log.to_text(), "the sim's own fight, tactics and all")
	for said: String in ["Holds its ground", "Moves out", "Mend waits"]:
		assert_true(popups.has(said), "%s over the hero" % said)
	assert_string_contains(screen.result_details.text, "Tactics: Brannoc, Hold your ground · Maren, Casters first · Vell, Wait to heal")


func test_in_a_fight_the_popup_names_the_tactic_without_buttons() -> void:
	var screen: ArenaScreen = await _screen()
	screen.session.set_tactic("maren", "casters_first")
	screen._show()
	screen._fight()
	screen._process(0.5)
	screen.toggle_pause()
	_click(screen, "maren")
	assert_true(screen.hero_popup.visible)
	assert_eq(screen.hero_popup.tactic_box.tactic_buttons.size(), 0, "no changing it mid-fight")
	assert_true(U.text_of(screen.hero_popup).contains("Tactic: Casters first"))
	assert_true(U.text_of(screen.hero_popup).contains("+20% damage to them"), "its numbers line in a fight too")
	screen.choose_tactic("maren", "hold_ground")
	assert_eq(screen.session.tactics["maren"], "casters_first", "choose_tactic does nothing in a fight")
	_click(screen, "brannoc")
	assert_true(U.text_of(screen.hero_popup).contains("Tactic: none"))


func test_a_result_without_tactics_says_nothing_of_them() -> void:
	var screen: ArenaScreen = await _screen()
	screen._fight()
	screen.skip()
	screen._process(0.1)
	assert_false(screen.result_details.text.contains("Tactics"))
