extends GutTest
## FightPlayer: steps a fresh CombatSim from the fight's setup, so playback
## matches the recorded fight at every speed; pause and skip.

const U = preload("res://tests/ui/ui_test_kit.gd")


func _fought() -> RunSession:
	var session: RunSession = U.at_fight()
	assert_true(session.fight().ok)
	return session


func test_every_speed_replays_the_recorded_fight() -> void:
	var session: RunSession = _fought()
	var recorded: String = session.last_fight.combat_log.to_text()
	for speed: float in FightPlayer.SPEEDS:
		var player: FightPlayer = FightPlayer.make(session.last_setup, session.content)
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
	var session: RunSession = _fought()
	var player: FightPlayer = FightPlayer.make(session.last_setup, session.content)
	player.advance(1.0)
	assert_eq(player.sim.tick, 20, "20 ticks a second at 1x")
	player.speed = 4.0
	player.advance(0.5)
	assert_eq(player.sim.tick, 60)
	player.speed = 0.5
	player.advance(0.05)
	assert_eq(player.sim.tick, 60, "half a tick waits")
	player.advance(0.05)
	assert_eq(player.sim.tick, 61)


func test_pause_stops_and_skip_ends() -> void:
	var session: RunSession = _fought()
	var player: FightPlayer = FightPlayer.make(session.last_setup, session.content)
	player.take_new()
	player.paused = true
	assert_eq(player.advance(5.0), [] as Array[LogEntry])
	assert_eq(player.sim.tick, 0)
	player.paused = false
	player.skip_to_end()
	assert_true(player.finished())
	assert_eq(player.sim.combat_log.to_text(), session.last_fight.combat_log.to_text())
	assert_eq(player.take_new(), [] as Array[LogEntry], "everything was handed out")
