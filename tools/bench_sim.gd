extends SceneTree
## Times the arena sim against its budget (docs/plans/rebuild-phase1-arena-sim.md,
## section 13: a 60s fight of 3 against 6 in under 100 ms) and prints a
## fingerprint of each fight's log, so a speed-up can be checked to change
## nothing.
## Usage: godot --headless --path . -s tools/bench_sim.gd
## Two fights, 3 against 6, at 1x to 3x HP (1.5x runs about a minute, the
## budget's case); each is run 3 times and the fastest counts:
##   steady    tanks, archers, hounds, and snipers that mostly stand and trade
##   crowded   the same, but the snipers taunt whoever they hit and the hounds
##             engage, so heroes keep walking through the enemy line (the
##             hardest case for pathfinding)
## The kits are fixed here, so the numbers compare across changes.

const K = preload("res://tests/sim/sim_test_kit.gd")
const RUNS: int = 3


func _init() -> void:
	var total_ms: int = 0
	var total_ticks: int = 0
	for crowded: bool in [false, true]:
		for hp_bp: int in [10000, 15000, 20000, 30000]:
			for fight_seed: int in [5, 11]:
				var best_usec: int = 0
				var result: FightResult = null
				for run: int in RUNS:
					var setup: FightSetup = _setup(fight_seed, hp_bp, crowded)
					var started: int = Time.get_ticks_usec()
					result = K.run(setup)
					var usec: int = Time.get_ticks_usec() - started
					best_usec = usec if run == 0 else mini(best_usec, usec)
				@warning_ignore("integer_division")
				var ms: int = best_usec / 1000
				total_ms += ms
				total_ticks += result.end_tick
				@warning_ignore("integer_division")
				print("%-8s hp x%-3s seed %2d: %4d ticks (%3ds), %4d ms, %3d ms per 60s, log %s" % ["crowded" if crowded else "steady", str(hp_bp / 10000.0), fight_seed, result.end_tick, result.end_tick / FixedMath.TICKS_PER_SECOND, ms, ms * 1200 / maxi(result.end_tick, 1), result.combat_log.to_text().md5_text()])
	@warning_ignore("integer_division")
	print("all: %d ms per 60s" % (total_ms * 1200 / maxi(total_ticks, 1)))
	quit()


static func _setup(fight_seed: int, hp_bp: int, crowded: bool = false) -> FightSetup:
	var tank: UnitDef = K.kit("tank", {"stats": {"hp": 500, "atk": 12, "def": 30, "speed": 2}, "traits": ["engage"],
		"signature": {"id": "stand", "name": "Stand", "trigger": {"kind": "hp_below", "threshold_bp": 4000}, "targeting": "self",
			"effects": [{"type": "shield", "amount": 60, "target": "self"}]}})
	var archer: UnitDef = K.kit("archer", {"stats": {"hp": 250, "atk": 20, "speed": 2, "range": 4, "crit": 20},
		"basic_attack": {"cooldown_ms": 900, "effects": [{"type": "damage", "amount": 6, "target": "target", "scaling": {"atk": 6000}}]},
		"mana": {"max": 40, "per_attack": 10, "regen_per_s": 2},
		"signature": {"id": "volley", "name": "Volley", "trigger": {"kind": "mana"}, "max_range": 5, "cast_ms": 400,
			"effects": [{"type": "damage", "amount": 15, "target": "target", "scaling": {"atk": 5000}}, {"type": "apply_status", "status": "slow", "target": "target"}]}})
	var hound_data: Dictionary = {"stats": {"hp": 180, "atk": 14, "speed": 3, "crit": 10},
		"passives": [{"id": "pack", "name": "Pack", "kind": "aura", "aura": {"target": "all_allies", "stat": "atsp_bp", "value": 11000}},
			{"id": "snap", "name": "Snap", "kind": "ability", "effects": [{"trigger": "on_hit_taken", "every": 3, "type": "damage", "amount": 4, "target": "hit_target"}]}]}
	var sniper_data: Dictionary = {"stats": {"hp": 140, "atk": 12, "speed": 2, "range": 5}}
	if crowded:
		hound_data["traits"] = ["engage"]
		sniper_data["basic_attack"] = {"effects": [{"type": "damage", "amount": 10, "target": "target"}, {"type": "apply_status", "status": "taunt", "target": "target"}]}
	var hound: UnitDef = K.kit("hound", hound_data)
	var sniper: UnitDef = K.kit("sniper", sniper_data)
	for unit_def: UnitDef in [tank, archer, hound, sniper]:
		unit_def.stats.values[UnitStats.Stat.HP] = FixedMath.apply_bp(unit_def.stats.values[UnitStats.Stat.HP], hp_bp)
	return K.fight([K.at(tank, 3, 2), K.at(archer, 3, 0), K.at(tank, 5, 1)] as Array[UnitSetup],
		[K.foe(hound, 1, 4), K.foe(hound, 3, 4), K.foe(hound, 5, 4), K.foe(sniper, 2, 6), K.foe(sniper, 4, 6), K.foe(hound, 6, 5)] as Array[UnitSetup],
		[Vector2i(4, 3), Vector2i(1, 3)] as Array[Vector2i], fight_seed)
