extends GutTest
## Placement (docs/plans/rebuild-phase3-fight-sandbox.md, section 3):
## PracticeSession's remembered formation, moving heroes on ArenaScreen by
## dragging, legality from the sim, the enemy panel, and the Fight button.

const MainScript = preload("res://src/ui/main.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


## Real heroes and enemies, and one made-up encounter with rocks in the
## heroes' zone.
func _rocky_content() -> ContentDb:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[ContentDb.ENCOUNTERS_FILE] = JSON.stringify([{"id": "rocky", "name": "Rocky", "tests": "rocks", "act": 1, "days": [1],
		"enemies": [{"enemy": "rift_pup", "hex": [3, 5]}], "rocks": [[3, 2], [4, 1]]}])
	var db: ContentDb = ContentDb.load_texts(texts)
	assert(db.is_valid(), str(db.errors))
	return db


func _screen(encounter_id: String = "sentinel_gate", session: PracticeSession = null) -> ArenaScreen:
	var practice: PracticeSession = session if session != null else PracticeSession.make(_content)
	var screen: ArenaScreen = ArenaScreen.make(practice, encounter_id)
	add_child_autofree(screen)
	screen.size = Vector2(1800, 1000)
	screen.setup()
	await wait_process_frames(2)
	return screen


func _hex_pixel(screen: ArenaScreen, hex: Vector2i) -> Vector2:
	return screen.view.to_pixel(screen.view.grid.center(hex.x, hex.y))


# --- the session ------------------------------------------------------------------

func test_the_first_formation_is_brannoc_guarding_and_is_legal_everywhere() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	assert_eq(session.formation, PracticeSession.DEFAULT_FORMATION)
	for encounter_id: String in _content.encounter_ids:
		assert_eq(session.formation_for(encounter_id), PracticeSession.DEFAULT_FORMATION, encounter_id)
		assert_eq(session.errors(encounter_id, PracticeSession.DEFAULT_FORMATION), [] as Array[String], encounter_id)


func test_a_remembered_hex_that_isnt_legal_goes_to_the_nearest_free_one() -> void:
	var session: PracticeSession = PracticeSession.make(_rocky_content())
	assert_eq(session.formation_for("rocky"), {"brannoc": Vector2i(2, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)},
		"Brannoc's hex is a rock: of the legal hexes a hex away, (2, 2) comes first (hexes count column by column)")
	session.remember({"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(2, 2)} as Dictionary[String, Vector2i])
	assert_eq(session.formation_for("rocky"), {"brannoc": Vector2i(2, 2), "maren": Vector2i(3, 0), "vell": Vector2i(1, 1)},
		"heroes go in heroes.json's order: Brannoc takes (2, 2), so Vell moves to the first free hex a hex away")
	session.formation.clear()
	session.remember({"brannoc": Vector2i(3, 6), "maren": Vector2i(0, 0)} as Dictionary[String, Vector2i])
	var placed: Dictionary[String, Vector2i] = session.formation_for("rocky")
	assert_eq(placed.keys(), ["brannoc", "maren", "vell"], "a hero missing from the memory starts from the first formation")
	assert_eq(placed["vell"], Vector2i(4, 0))
	assert_eq(session.errors("rocky", placed), [] as Array[String])


func test_a_move_onto_a_hero_swaps_them() -> void:
	var start: Dictionary[String, Vector2i] = PracticeSession.DEFAULT_FORMATION
	assert_eq(PracticeSession.moved(start, "maren", Vector2i(0, 0)), {"brannoc": Vector2i(3, 2), "maren": Vector2i(0, 0), "vell": Vector2i(4, 0)})
	assert_eq(PracticeSession.moved(start, "maren", Vector2i(3, 2)), {"brannoc": Vector2i(3, 0), "maren": Vector2i(3, 2), "vell": Vector2i(4, 0)})
	assert_eq(start, PracticeSession.DEFAULT_FORMATION, "the original is left alone")


func test_errors_name_what_is_wrong() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	var bad: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 4), "maren": Vector2i(3, 0), "vell": Vector2i(3, 0)}
	var errors: Array[String] = session.errors("sentinel_gate", bad)
	assert_true(errors.any(func(error: String) -> bool: return error.contains("outside its side's zone")), str(errors))
	assert_true(errors.any(func(error: String) -> bool: return error.contains("shares its hex")), str(errors))
	assert_eq(session.errors("nowhere", PracticeSession.DEFAULT_FORMATION), ["unknown encounter \"nowhere\""])


# --- moving heroes on the screen ----------------------------------------------

func test_a_legal_drop_moves_the_hero_and_its_token() -> void:
	var screen: ArenaScreen = await _screen()
	screen.view._drop_data(_hex_pixel(screen, Vector2i(6, 1)), {"hero": "maren"})
	assert_eq(screen.formation["maren"], Vector2i(6, 1))
	assert_eq(screen.view.token("maren").plane_pos, screen.view.grid.center(6, 1))
	assert_eq(screen.view.flashing, Vector2i(-1, -1))


func test_a_drop_on_a_hero_swaps_them() -> void:
	var screen: ArenaScreen = await _screen()
	var brannoc: UnitToken = screen.view.token("brannoc")
	brannoc._drop_data(Vector2(brannoc.size.x / 2.0, 1.0), {"hero": "vell"})
	assert_eq([screen.formation["vell"], screen.formation["brannoc"]], [Vector2i(3, 2), Vector2i(4, 0)], "a drop on a token, even on its head, counts for the hex it stands on")


func test_an_illegal_drop_is_refused_and_its_hex_flashes() -> void:
	var screen: ArenaScreen = await _screen()
	for hex: Vector2i in [Vector2i(3, 3), Vector2i(2, 4), Vector2i(0, 6), Vector2i(2, 3)]:
		assert_false(screen.move_hero("maren", hex), str(hex))
		assert_eq(screen.formation["maren"], Vector2i(3, 0))
		assert_eq(screen.view.flashing, hex)
	screen.view._process(ArenaView.FLASH_SECONDS + 0.01)
	assert_eq(screen.view.flashing, Vector2i(-1, -1), "the flash fades")
	assert_false(screen.move_hero("maren", Vector2i(3, 0)), "onto its own hex: nothing to do")
	assert_eq(screen.view.flashing, Vector2i(-1, -1))
	watch_signals(screen.view)
	screen.view._drop_data(Vector2(-40, -40), {"hero": "maren"})
	assert_signal_not_emitted(screen.view, "hero_dropped", "off the board: nothing to try")
	assert_eq(screen.formation["maren"], Vector2i(3, 0))


func test_only_heroes_are_dragged_and_only_while_placing() -> void:
	var screen: ArenaScreen = await _screen()
	var maren: UnitToken = screen.view.token("maren")
	assert_eq(maren._get_drag_data(Vector2.ZERO), {"hero": "maren"})
	assert_null(screen.view.token("hollow_archer")._get_drag_data(Vector2.ZERO))
	assert_false(screen.view._can_drop_data(Vector2.ZERO, "maren"), "only hero drags drop")
	assert_true(screen.view._can_drop_data(Vector2.ZERO, {"hero": "maren"}))
	screen.view.set_mode(ArenaView.Mode.FIGHT)
	assert_null(maren._get_drag_data(Vector2.ZERO))
	assert_false(screen.view._can_drop_data(Vector2.ZERO, {"hero": "maren"}))


# --- the enemy panel, and fighting ---------------------------------------------

func test_hovering_an_enemy_shows_it_in_the_side_panel() -> void:
	var screen: ArenaScreen = await _screen()
	assert_eq(screen.enemy_panel.title.text, EnemyPanel.EMPTY_TEXT)
	screen.view.token("hollow_archer#2").mouse_entered.emit()
	assert_eq([screen.enemy_panel.showing, screen.enemy_panel.title.text, screen.enemy_panel.archetype.text, screen.enemy_panel.threat.text],
		["hollow_archer#2", "Hollow Archer", "Ranged", "Outranges your archers"], "the unit hovered, and its kit's details")
	assert_eq(screen.enemy_panel.stats.text, "HP 460 · ATK 18 · DEF 4 · Speed 2 · Range 5")
	screen.view.token("vell").mouse_entered.emit()
	assert_eq(screen.enemy_panel.showing, "hollow_archer#2", "hovering a hero leaves the panel alone")
	screen.view.token("vell").mouse_exited.emit()
	assert_eq(screen.enemy_panel.showing, "hollow_archer#2")
	screen.view.token("hollow_archer#2").mouse_exited.emit()
	assert_eq(screen.enemy_panel.title.text, EnemyPanel.EMPTY_TEXT)
	assert_false(screen.enemy_panel.threat.visible)


func test_fight_remembers_the_formation_and_hands_over_the_setup() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	var screen: ArenaScreen = await _screen("the_pack", session)
	watch_signals(screen)
	screen.move_hero("vell", Vector2i(5, 1))
	assert_eq(session.formation, PracticeSession.DEFAULT_FORMATION, "moving doesn't remember; fighting does")
	screen.fight_button.pressed.emit()
	assert_signal_emitted(screen, "fight_requested")
	var setup: FightSetup = get_signal_parameters(screen, "fight_requested")[0]
	assert_eq(setup.heroes.map(func(hero: UnitSetup) -> Vector2i: return Vector2i(hero.col, hero.row)), [Vector2i(3, 2), Vector2i(3, 0), Vector2i(5, 1)])
	assert_eq(session.formation["vell"], Vector2i(5, 1))
	var next: ArenaScreen = await _screen("moth_cloud", session)
	assert_eq(next.formation["vell"], Vector2i(5, 1), "the next encounter starts from it")


func test_an_illegal_formation_disables_fight_and_says_why() -> void:
	var screen: ArenaScreen = await _screen()
	watch_signals(screen)
	screen.formation = {"brannoc": Vector2i(3, 4), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
	screen._show()
	assert_true(screen.fight_button.disabled)
	assert_string_contains(screen.error_label.text, "outside its side's zone")
	screen._fight()
	assert_signal_not_emitted(screen, "fight_requested")
	screen.formation = PracticeSession.DEFAULT_FORMATION.duplicate()
	screen._show()
	assert_false(screen.fight_button.disabled)
	assert_eq(screen.error_label.text, "")


func test_back_and_the_backdrop() -> void:
	var main: Main = MainScript.new()
	main.old_save_path = "user://test_no_save.json"
	add_child_autofree(main)
	assert_true(main.backdrop.visible, "the title shows the backdrop")
	var screen: ArenaScreen = ArenaScreen.make(PracticeSession.make(_content), "ash_nest")
	main.show_screen(screen)
	assert_false(main.backdrop.visible, "the arena hides it")
	watch_signals(screen)
	for button: Button in screen.find_children("*", "Button", true, false):
		if button.text == "Back":
			button.pressed.emit()
	assert_signal_emitted(screen, "back_requested")
	main.show_screen(TitleScreen.new())
	assert_true(main.backdrop.visible)
	await wait_process_frames(1)
