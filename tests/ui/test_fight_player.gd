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


# --- the animated fight (FightFx, Figure) ------------------------------------------

func test_attack_styles_come_from_item_tags() -> void:
	assert_eq(FightFx.style_for(["weapon", "melee"] as Array[String]), FightFx.Style.MELEE)
	assert_eq(FightFx.style_for(["weapon", "ranged"] as Array[String]), FightFx.Style.RANGED)
	assert_eq(FightFx.style_for(["tome", "magic"] as Array[String]), FightFx.Style.MAGIC)
	assert_eq(FightFx.style_for([] as Array[String]), FightFx.Style.MELEE, "no tags: a plain swing")


func test_fight_cards_stand_up_figures_that_fall() -> void:
	var session: RunSession = U.at_fight()
	session.fight()
	var player: FightPlayer = FightPlayer.make(session.last_setup, session.content)
	var hero: UnitState = player.sim.heroes[0]
	var enemy: UnitState = player.sim.enemies[0]
	assert_eq(CharacterArt.base_id(enemy.id), enemy.id.left(enemy.id.rfind("_")), "fight ids map to their art")
	var hero_card: UnitCard = UnitCard.make(hero)
	var enemy_card: UnitCard = UnitCard.make(enemy)
	add_child_autofree(hero_card)
	add_child_autofree(enemy_card)
	assert_not_null(hero_card.figure)
	assert_false(hero_card.figure.flip, "heroes face right")
	assert_true(enemy_card.figure.flip, "enemies face left")
	enemy.alive = false
	enemy_card.refresh()
	assert_true(enemy_card.figure.fallen)


func test_a_hit_and_a_melee_attack_animate_the_figures() -> void:
	var attacker: Figure = Figure.make("wren", 100)
	var target: Figure = Figure.make("rift_pup", 100, true)
	var layer := Control.new()
	add_child_autofree(attacker)
	add_child_autofree(target)
	add_child_autofree(layer)
	target.position = Vector2(0, -200)
	var landed: Array[bool] = [false]
	FightFx.attack(attacker, target, FightFx.Style.MELEE, layer, 4.0, Color.WHITE, func() -> void: landed[0] = true)
	await wait_seconds(0.5)
	assert_true(landed[0], "the blow lands")
	assert_almost_eq(attacker.offset.length(), 0.0, 0.5, "and the attacker steps back")
	FightFx.hit(target, 4.0, true)
	assert_true(target.has_meta("hit_tween"))
