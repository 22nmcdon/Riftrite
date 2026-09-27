extends GutTest
## CLAUDE.md rule 1: same seed, same inputs, same fight, every time
## (docs/plans/rebuild-phase1-arena-sim.md, section 13).

const K = preload("res://tests/sim/sim_test_kit.gd")
const LogTest = preload("res://tests/sim/arena/test_arena_log.gd")


func test_a_seeded_fight_repeats_exactly() -> void:
	var first: FightResult = K.run(LogTest.busy_setup(11))
	var second: FightResult = K.run(LogTest.busy_setup(11))
	assert_true(first.errors.is_empty(), str(first.errors))
	assert_gt(first.combat_log.entries.size(), 100)
	assert_true(first.combat_log.of_kind(LogEntry.Kind.DAMAGE).any(func(entry: LogEntry) -> bool: return entry.crit), "crits roll the seeded RNG")
	assert_eq(first.combat_log.to_text(), second.combat_log.to_text())
	assert_eq([first.outcome, first.end_tick], [second.outcome, second.end_tick])


func test_the_seed_matters() -> void:
	assert_ne(K.run(LogTest.busy_setup(11)).combat_log.to_text(), K.run(LogTest.busy_setup(12)).combat_log.to_text())


func test_the_fight_order_matters() -> void:
	# The same units listed in another order act in another order.
	var setup: FightSetup = LogTest.busy_setup(11)
	var reordered: FightSetup = LogTest.busy_setup(11)
	reordered.heroes.reverse()
	assert_ne(K.run(setup).combat_log.to_text(), K.run(reordered).combat_log.to_text())
