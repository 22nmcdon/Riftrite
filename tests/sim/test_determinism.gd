extends GutTest
## CLAUDE.md rule 1: same seed + same inputs = same fight, every time.
## These must keep passing through every change to the sim.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK


## A fight that leans on randomness: random targets and frequent crits.
func _chaotic_fight(seed_value: int) -> FightSetup:
	var scatter: ItemDef = K.item("scatter", {"cooldown_ms": 700, "crit_chance_bp": 3000, "effects": K.damage(9, "enemy_random")})
	var cleave: ItemDef = K.item("cleave", {"size": 2, "cooldown_ms": 2150, "crit_chance_bp": 2000, "effects": K.damage(25)})
	var mend: ItemDef = K.item("mend", {"cooldown_ms": 1650, "effects": [{"trigger": "on_fire", "type": "heal", "amount": 12, "target": "ally_lowest_hp"}]})
	var claw: ItemDef = K.item("claw", {"cooldown_ms": 900, "crit_chance_bp": 2500, "effects": K.damage(7, "enemy_random")})
	return K.fight(
		[K.unit("warden", 420, FRONT, [cleave]), K.unit("striker", 300, FRONT, [scatter]), K.unit("mender", 260, BACK, [mend, scatter])],
		[K.unit("ghoul_a", 380, FRONT, [claw]), K.unit("ghoul_b", 380, FRONT, [claw]), K.unit("shade", 300, BACK, [claw, scatter])],
		seed_value)


func test_same_seed_same_log() -> void:
	var first: FightResult = CombatSim.run(_chaotic_fight(5), K.tuning())
	var second: FightResult = CombatSim.run(_chaotic_fight(5), K.tuning())
	assert_eq(first.errors, [] as Array[String])
	assert_gt(first.combat_log.entries.size(), 100, "a real fight happened")
	assert_eq(first.combat_log.to_text(), second.combat_log.to_text())
	assert_eq(first.outcome, second.outcome)
	assert_eq(first.end_tick, second.end_tick)


func test_different_seed_different_log() -> void:
	var first: FightResult = CombatSim.run(_chaotic_fight(5), K.tuning())
	var other: FightResult = CombatSim.run(_chaotic_fight(6), K.tuning())
	assert_ne(first.combat_log.to_text(), other.combat_log.to_text())


func test_stepping_matches_running() -> void:
	var ran: FightResult = CombatSim.run(_chaotic_fight(9), K.tuning())
	var sim := CombatSim.new(_chaotic_fight(9), K.tuning())
	while not sim.finished:
		sim.step()
	assert_eq(sim.combat_log.to_text(), ran.combat_log.to_text())
