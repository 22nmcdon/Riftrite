extends GutTest
## FightPlayer and the fight on ArenaScreen (docs/plans/rebuild-phase3-fight-sandbox.md,
## section 4, Decision 2): live stepping at every speed replays the fight
## exactly; pause, skip, restart, and seek; smooth drawn positions; and the
## screen's controls and keys, with fake time.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")

var _content: ContentDb


func before_all() -> void:
	_content = ContentDb.load_dir("res://data")


func _setup(encounter_id: String = "the_pack") -> FightSetup:
	var errors: Array[String] = []
	return Encounters.setup(_content, encounter_id, PracticeSession.DEFAULT_FORMATION, 3, errors)


func _player(encounter_id: String = "the_pack") -> FightPlayer:
	return FightPlayer.make(_setup(encounter_id), _content)


# --- the player -------------------------------------------------------------------

func test_every_speed_replays_the_fight_exactly() -> void:
	var recorded: String = CombatSim.run(_setup(), _content).combat_log.to_text()
	for speed: float in FightPlayer.SPEEDS:
		var player: FightPlayer = _player()
		player.speed = speed
		var lines: PackedStringArray = PackedStringArray()
		for entry: LogEntry in player.take_new():
			lines.append(entry.to_text())
		var frames: int = 0
		while not player.finished() and frames < 100000:
			for entry: LogEntry in player.advance(1.0 / 60.0):
				lines.append(entry.to_text())
			frames += 1
		assert_true(player.finished(), "speed %s" % speed)
		assert_eq("\n".join(lines), recorded, "speed %s" % speed)


func test_speed_sets_how_many_ticks_pass() -> void:
	var player: FightPlayer = _player()
	assert_eq(FightPlayer.SPEEDS, [0.5, 1.0, 2.0] as Array[float], "up to 2x (Decision 2)")
	player.advance(1.0)
	assert_eq(player.sim.tick, 20, "20 ticks a second at 1x")
	player.speed = 2.0
	player.advance(0.5)
	assert_eq(player.sim.tick, 40)
	player.speed = 0.5
	player.advance(0.05)
	assert_eq(player.sim.tick, 40, "half a tick waits")
	player.advance(0.05)
	assert_eq(player.sim.tick, 41)
	assert_almost_eq(player.fight_seconds(), 2.05, 0.001)


func test_pause_stops_and_skip_ends() -> void:
	var player: FightPlayer = _player()
	player.take_new()
	player.paused = true
	assert_eq(player.advance(5.0), [] as Array[LogEntry])
	assert_eq(player.sim.tick, 0)
	player.paused = false
	player.advance(0.5)
	assert_eq(player.sim.tick, 10)
	player.skip_to_end()
	assert_true(player.finished())
	assert_eq(player.sim.combat_log.to_text(), CombatSim.run(_setup(), _content).combat_log.to_text())
	assert_eq(player.take_new(), [] as Array[LogEntry], "everything was handed out")
	var end: int = player.sim.tick
	assert_eq(player.advance(3.0), [] as Array[LogEntry])
	assert_eq(player.sim.tick, end, "nothing moves once it's over")
	var raced: FightPlayer = _player()
	while not raced.finished():
		raced.advance(7.33)
	assert_eq(raced._carry, 0.0, "the fraction of a tick left when it ends is dropped")


func test_seeking_gives_the_same_fight_at_that_moment() -> void:
	var straight: FightPlayer = _player()
	straight.advance(12.0)
	var seeker: FightPlayer = _player()
	seeker.advance(20.0)
	seeker.seek(240)
	assert_eq(seeker.sim.tick, 240)
	assert_eq(seeker.sim.combat_log.to_text(), straight.sim.combat_log.to_text())
	for i: int in straight.sim.units.size():
		var a: UnitState = straight.sim.units[i]
		var b: UnitState = seeker.sim.units[i]
		assert_eq([b.id, b.pos, b.hp, b.mana, b.alive], [a.id, a.pos, a.hp, a.mana, a.alive])
	assert_eq(seeker.take_new(), [] as Array[LogEntry], "what came before the seek counts as handed out")
	seeker.advance(0.05)
	assert_eq(seeker.sim.tick, 241)
	seeker.restart()
	assert_eq(seeker.sim.tick, 0)
	var fresh: FightPlayer = _player()
	fresh.seek(100)
	assert_eq(fresh.take_new(), [] as Array[LogEntry], "a seek counts everything before it as handed out")
	var ended: FightPlayer = _player()
	ended.seek(1000000)
	assert_true(ended.finished(), "seeking past the end stops at the end")


func test_units_are_drawn_between_their_last_two_ticks() -> void:
	var player: FightPlayer = _player("hollow_line")
	var brannoc: UnitState = player.sim.unit_by_id("brannoc")
	assert_eq(player.drawn_position(brannoc), Vector2(brannoc.pos), "before any step, where it stands")
	assert_eq(player.drawn_time(), 0.0, "and the drawn time is the tick itself")
	player.advance(0.5)
	player.advance(0.025)
	var walker: UnitState = null
	for unit: UnitState in player.sim.units:
		if player._before[unit.id] != unit.pos:
			walker = unit
	assert_not_null(walker, "someone is moving")
	var before: Vector2i = player._before[walker.id]
	assert_almost_eq(player.drawn_position(walker), Vector2(before).lerp(Vector2(walker.pos), 0.5), Vector2(0.01, 0.01), "halfway into the next tick")
	assert_almost_eq(player.drawn_time(), player.sim.tick - 0.5, 0.001, "drawn time trails the sim by the smoothing")
	player.skip_to_end()
	assert_eq(player.drawn_position(walker), Vector2(walker.pos), "after a skip, where it stands")
	assert_eq(player.drawn_time(), float(player.sim.tick))


# --- the view ---------------------------------------------------------------------

func test_the_view_follows_the_fight_and_gives_summons_tokens() -> void:
	var setup: FightSetup = Chaos.setup()
	var content: ContentDb = K.content()
	var view := ArenaView.new()
	add_child_autofree(view)
	view.size = Vector2(1000, 900)
	view.show_setup(setup, content)
	var player: FightPlayer = FightPlayer.make(setup, content)
	var start: int = view.tokens.size()
	var saw_fallen: bool = false
	while not player.finished():
		player.advance(0.1)
		view.sync_fight(player)
		for unit: UnitState in player.sim.units:
			var unit_token: UnitToken = view.token(unit.id)
			assert_eq(unit_token.visible, unit.alive)
			saw_fallen = saw_fallen or not unit.alive
			if unit.alive:
				assert_almost_eq(unit_token.center(), view.to_pixel_f(player.drawn_position(unit)), Vector2(0.01, 0.01))
		if is_failing():
			return
	assert_gt(view.tokens.size(), start, "summons got tokens")
	assert_eq(view.tokens.size(), player.sim.units.size())
	assert_true(saw_fallen)
	var pup: UnitToken = view.tokens[start]
	assert_eq([pup.label_text, pup.is_hero()], ["Pup", false])


# --- the screen -------------------------------------------------------------------

func _screen(session: PracticeSession = null) -> ArenaScreen:
	var practice: PracticeSession = session if session != null else PracticeSession.make(_content)
	var screen: ArenaScreen = ArenaScreen.make(practice, "the_pack")
	add_child_autofree(screen)
	screen.size = Vector2(1800, 1000)
	screen.setup()
	await wait_process_frames(2)
	return screen


func _key(screen: ArenaScreen, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	screen._unhandled_input(event)


func test_fight_starts_playing_at_once_on_the_same_board() -> void:
	var screen: ArenaScreen = await _screen()
	assert_null(screen.player)
	screen.fight_button.pressed.emit()
	assert_not_null(screen.player)
	assert_false(screen.player.paused, "a fight doesn't start paused (Decision 2)")
	assert_eq(screen.view.mode, ArenaView.Mode.FIGHT)
	assert_eq(screen.hint_label.text, ArenaScreen.FIGHT_HINT)
	assert_false(screen.fight_button.is_visible_in_tree())
	assert_null(screen.view.token("maren")._get_drag_data(Vector2.ZERO), "no dragging during the fight")
	screen._process(1.0)
	assert_eq(screen.player.sim.tick, 20)
	assert_eq(screen.clock_label.text, "1.0s")
	var hound: UnitState = screen.player.sim.unit_by_id("rift_hound")
	var drawn: Vector2 = screen.view.fx.moved_position(hound.id, screen.player.drawn_position(hound), screen.player.drawn_time())
	assert_almost_eq(screen.view.token("rift_hound").center(), screen.view.to_pixel_f(drawn), Vector2(0.01, 0.01), "where it's drawn (sliding, if a leap or push is still being shown)")


func test_the_controls_and_keys() -> void:
	var session: PracticeSession = PracticeSession.make(_content)
	var screen: ArenaScreen = await _screen(session)
	screen._fight()
	assert_eq(screen.speed_buttons.map(func(button: Button) -> String: return button.text), ["0.5x", "1x", "2x"])
	assert_eq(screen.speed_buttons.map(func(button: Button) -> bool: return button.button_pressed), [false, true, false])
	_key(screen, KEY_3)
	assert_eq([screen.player.speed, session.speed], [2.0, 2.0], "the speed is remembered in the session")
	assert_eq(screen.speed_buttons.map(func(button: Button) -> bool: return button.button_pressed), [false, false, true])
	screen._process(1.0)
	assert_eq(screen.player.sim.tick, 40)
	_key(screen, KEY_SPACE)
	assert_true(screen.player.paused)
	assert_eq(screen.pause_button.text, "Play")
	screen._process(1.0)
	assert_eq(screen.player.sim.tick, 40)
	screen.pause_button.pressed.emit()
	assert_false(screen.player.paused)
	_key(screen, KEY_1)
	assert_eq(screen.player.speed, 0.5)
	_key(screen, KEY_S)
	assert_true(screen.player.finished())
	assert_true(screen.outcome_label.text.begins_with("Victory in") or screen.outcome_label.text.begins_with("Defeat in") or screen.outcome_label.text.begins_with("A tie"))
	screen.restart()
	assert_eq([screen.player.sim.tick, screen.outcome_label.text], [0, ""])
	screen.place_again()
	assert_null(screen.player)
	assert_eq(screen.view.mode, ArenaView.Mode.PLACEMENT)
	assert_eq(screen.hint_label.text, screen.placement_hint())
	assert_true(screen.fight_button.is_visible_in_tree())
	assert_eq(screen.formation, PracticeSession.DEFAULT_FORMATION)
	screen.move_hero("vell", Vector2i(6, 1))
	assert_eq(screen.formation["vell"], Vector2i(6, 1), "placing works again")
	screen._fight()
	assert_eq(screen.player.speed, 0.5, "the next fight starts at the last speed")


func test_outcome_texts() -> void:
	assert_eq(ArenaScreen.outcome_text(FightResult.Outcome.VICTORY, 31.25), "Victory in 31.2s")
	assert_eq(ArenaScreen.outcome_text(FightResult.Outcome.DEFEAT, 12.0), "Defeat in 12.0s")
	assert_eq(ArenaScreen.outcome_text(FightResult.Outcome.TIE, 180.0), "A tie at 180.0s (it counts as a win)")
	assert_eq(ArenaScreen.speed_text(0.5), "0.5x")
	assert_eq(ArenaScreen.speed_text(2.0), "2x")
