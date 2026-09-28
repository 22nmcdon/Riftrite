extends SceneTree
## Times the arena sim against its budget (docs/plans/rebuild-phase1-arena-sim.md,
## section 13: a 60s fight of 3 against 6 in under 100 ms) and prints a
## fingerprint of each fight's log, so a speed-up can be checked to change
## nothing.
## Usage: godot --headless --path . -s tools/bench_sim.gd
## The fights are the test kits' busy fight (tests/sim/arena/test_arena_log.gd)
## with one hero fewer, at 1x to 3x HP (1.5x runs about a minute, the
## budget's case); each is run 3 times and the fastest counts.

const K = preload("res://tests/sim/sim_test_kit.gd")
const LogTest = preload("res://tests/sim/arena/test_arena_log.gd")
const RUNS: int = 3


func _init() -> void:
	var total_ms: int = 0
	var total_ticks: int = 0
	for hp_bp: int in [10000, 15000, 20000, 30000]:
		for fight_seed: int in [5, 11]:
			var best_usec: int = 0
			var result: FightResult = null
			for run: int in RUNS:
				var setup: FightSetup = _setup(fight_seed, hp_bp)
				var started: int = Time.get_ticks_usec()
				result = K.run(setup)
				var usec: int = Time.get_ticks_usec() - started
				best_usec = usec if run == 0 else mini(best_usec, usec)
			@warning_ignore("integer_division")
			var ms: int = best_usec / 1000
			total_ms += ms
			total_ticks += result.end_tick
			@warning_ignore("integer_division")
			print("hp x%-3s seed %2d: %4d ticks (%3ds), %4d ms, %3d ms per 60s, log %s" % [str(hp_bp / 10000.0), fight_seed, result.end_tick, result.end_tick / FixedMath.TICKS_PER_SECOND, ms, ms * 1200 / maxi(result.end_tick, 1), result.combat_log.to_text().md5_text()])
	@warning_ignore("integer_division")
	print("all: %d ms per 60s" % (total_ms * 1200 / maxi(total_ticks, 1)))
	quit()


static func _setup(fight_seed: int, hp_bp: int) -> FightSetup:
	var setup: FightSetup = LogTest.busy_setup(fight_seed)
	setup.heroes.remove_at(3)
	for unit: UnitSetup in setup.units():
		unit.def.stats.values[UnitStats.Stat.HP] = FixedMath.apply_bp(unit.def.stats.values[UnitStats.Stat.HP], hp_bp)
	return setup
