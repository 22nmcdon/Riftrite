extends GutTest
## How a fight ends (docs/plans/rebuild-phase1-arena-sim.md, section 3).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _brawler(hp: int, damage: int) -> UnitDef:
	return K.kit("brawler", {"stats": {"hp": hp, "speed": 0, "range": 2}, "basic_attack": {"shot": false, "effects": [{"type": "damage", "amount": damage, "target": "target"}]}})


func _duel(hero: UnitDef, enemy: UnitDef) -> FightResult:
	return K.run(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy, 3, 4)] as Array[UnitSetup]))


func test_victory_and_defeat() -> void:
	var win: FightResult = _duel(_brawler(100, 50), _brawler(40, 1))
	assert_eq(win.outcome, FightResult.Outcome.VICTORY)
	assert_true(win.guild_won())
	var loss: FightResult = _duel(_brawler(40, 1), _brawler(100, 50))
	assert_eq(loss.outcome, FightResult.Outcome.DEFEAT)
	assert_false(loss.guild_won())
	var deaths: Array[LogEntry] = loss.combat_log.of_kind(LogEntry.Kind.DEATH)
	assert_eq(deaths.size(), 1)
	assert_string_contains(deaths[0].to_text(), "brawler falls (last hit: brawler#2 · Strike)")


func test_both_falling_together_is_a_tie() -> void:
	var result: FightResult = _duel(_brawler(50, 50), _brawler(50, 50))
	assert_eq(result.outcome, FightResult.Outcome.TIE, "both land on the same tick; deaths wait for the end of it")
	assert_true(result.guild_won(), "a tie counts as a victory")


func test_three_minutes_is_a_tie() -> void:
	# Neither can reach the other.
	var result: FightResult = K.run(K.fight([K.at(_brawler(100, 1), 0, 0)] as Array[UnitSetup], [K.foe(_brawler(100, 1), 7, 6)] as Array[UnitSetup]))
	assert_eq([result.outcome, result.end_tick], [FightResult.Outcome.TIE, 3600])
	assert_string_contains(result.combat_log.to_text(), "Tie: both sides outlasted the rift")
