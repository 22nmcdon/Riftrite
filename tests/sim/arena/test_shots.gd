extends GutTest
## Shots in flight (docs/plans/rebuild-phase1-arena-sim.md, section 5, decided):
## 1 tick per hex, following the target, numbers fixed when fired, still
## landing after the shooter falls, fizzling if the target falls first.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _archer(extra: Dictionary = {}) -> UnitDef:
	var stats: Dictionary = {"hp": 10000, "atk": 20, "speed": 0, "range": 5}
	stats.merge(extra, true)
	return K.kit("archer", {"stats": stats, "basic_attack": {"effects": [
		{"type": "damage", "amount": 5, "target": "target", "scaling": {"atk": 5000}},
		{"type": "heal", "amount": 3, "target": "self"},
	]}})


func _target(speed: int = 0) -> UnitDef:
	return K.kit("target", {"stats": {"hp": 10000, "speed": speed, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## An archer at (3, 0) and a target `rows` rows further down column 3.
func _range(rows: int = 4, target: UnitDef = _target()) -> CombatSim:
	return K.sim(K.fight([K.at(_archer(), 3, 0)] as Array[UnitSetup], [K.foe(target, 3, rows)] as Array[UnitSetup]))


func test_a_shot_takes_a_tick_per_hex() -> void:
	for rows: int in [4, 5]:
		var fight: CombatSim = _range(rows)
		K.step(fight, 20)
		var shot: LogEntry = K.entries(fight, LogEntry.Kind.SHOT, "archer")[0]
		assert_eq([shot.tick, shot.end_tick, shot.target], [20, 20 + rows, "target"], "%d hexes, %d ticks" % [rows, rows])
		assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "archer").size(), 0, "not landed yet")
		K.step(fight, rows - 1)
		assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "archer").size(), 0)
		fight.step()
		var hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "archer")[0]
		assert_eq([hit.tick, hit.amount], [20 + rows, 15])
	assert_eq(Shots.flight_ticks(0), 1, "at least a tick")
	assert_eq(Shots.flight_ticks(1001), 2, "rounded up")


func test_what_isnt_aimed_at_the_target_happens_as_it_fires() -> void:
	var fight: CombatSim = _range(5)
	fight.units[0].hp = 9000
	K.step(fight, 20)
	assert_eq(fight.units[0].hp, 9003, "the self-heal doesn't ride the arrow")


func test_it_follows_a_moving_target() -> void:
	# The target walks toward the archer while the shot is in the air.
	var fight: CombatSim = K.sim(K.fight([K.at(_archer(), 3, 0)] as Array[UnitSetup], [K.foe(_target(3), 3, 6)] as Array[UnitSetup]))
	var fired_at: Vector2i = Vector2i.ZERO
	while K.entries(fight, LogEntry.Kind.SHOT).is_empty():
		fight.step()
	fired_at = fight.units[1].pos
	while K.entries(fight, LogEntry.Kind.DAMAGE, "archer").is_empty():
		fight.step()
	assert_ne(fight.units[1].pos, fired_at, "it moved")
	assert_eq(fight.units[1].hp, 10000 - 15, "and was hit anyway")


func test_the_numbers_are_set_as_it_fires() -> void:
	var fight: CombatSim = _range(5)
	K.step(fight, 20)
	fight.units[0].stats.values[UnitStats.Stat.ATK] = 1000
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "archer")[0].amount, 15, "ATK changing mid-flight doesn't change the hit")


func test_it_still_lands_after_the_archer_falls() -> void:
	# A friend keeps the fight going once the archer is down.
	var fight: CombatSim = K.sim(K.fight([K.at(_archer(), 3, 0), K.at(_target(), 0, 0, "friend")] as Array[UnitSetup], [K.foe(_target(), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 20)
	fight.units[0].hp = 0
	K.step(fight, 5)
	assert_false(fight.units[0].alive)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "archer").size(), 1)


func test_it_fizzles_if_the_target_falls_first() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_archer(), 3, 0)] as Array[UnitSetup], [K.foe(_target(), 3, 5), K.foe(_target(), 0, 6, "other")] as Array[UnitSetup]))
	K.step(fight, 20)
	fight.units[1].hp = 0
	K.step(fight, 5)
	var fizzled: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHOT_FIZZLED, "archer")
	assert_eq(fizzled.size(), 1)
	assert_string_contains(fizzled[0].to_text(), "archer · Strike's shot at target fizzles (target fell)")
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "archer").size(), 0)


func test_no_shot_when_it_says_so() -> void:
	var beam: UnitDef = K.kit("archer", {"stats": {"hp": 10000, "speed": 0, "range": 5}, "basic_attack": {"shot": false}})
	var fight: CombatSim = K.sim(K.fight([K.at(beam, 3, 0)] as Array[UnitSetup], [K.foe(_target(), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.SHOT).size(), 0)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "archer")[0].tick, 20, "it lands as it fires")
