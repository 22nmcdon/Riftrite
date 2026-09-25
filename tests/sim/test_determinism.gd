extends GutTest
## CLAUDE.md rule 1: same seed + same inputs = same fight, every time.
## These must keep passing through every change to the sim.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK


## A fight that leans on randomness: random targets, frequent crits, and
## all eight essences (conversions, statuses, Storm's extra fires, Umbral crits),
## a mid-fight level-up to Resonant that starts a spill, alloys (Inferno,
## Plasma's jumping burn), and auras with windows.
func _chaotic_fight(seed_value: int) -> FightSetup:
	var scatter: ItemDef = K.item("scatter", {"cooldown_ms": 700, "crit_chance_bp": 3000, "effects": K.damage(9, "enemy_random")})
	var cleave: ItemDef = K.item("cleave", {"size": 2, "cooldown_ms": 2150, "crit_chance_bp": 2000, "effects": K.damage(25)})
	var mend: ItemDef = K.item("mend", {"cooldown_ms": 1650, "xp_per_fire": 5, "effects": [{"trigger": "on_fire", "type": "heal", "amount": 12, "target": "ally_lowest_hp"}]})
	var hex: ItemDef = K.item("hex", {"size": 2, "cooldown_ms": 1300, "effects": K.damage(12, "enemy_random")})
	var drum: ItemDef = K.item("drum", {"cooldown_ms": 2000, "effects": K.damage(3, "all_enemies"), "auras": [
		{"target": "linked_allies", "stat": "damage_bp", "value": 15000, "window": {"until_ms": 10000}},
		{"target": "adjacent_items", "stat": "crit_chance_bp", "value": 2000}]})
	var claw: ItemDef = K.item("claw", {"cooldown_ms": 900, "crit_chance_bp": 2500, "effects": K.damage(7, "enemy_random")})
	return FightSetup.make(
		[K.unit("warden", 420, FRONT, [K.equip(cleave, ["ember", "ember"] as Array[String]), drum]), K.unit("striker", 300, FRONT, [K.equip(scatter, ["umbral"] as Array[String])]), K.unit("mender", 260, BACK, [K.equip(mend, ["verdant"] as Array[String], 0, 280), K.equip(scatter, ["stone"] as Array[String])])],
		[K.unit("ghoul_a", 380, FRONT, [K.equip(claw, ["frost"] as Array[String])]), K.unit("ghoul_b", 380, FRONT, [K.equip(claw, ["venom"] as Array[String])]), K.unit("shade", 300, BACK, [K.equip(claw, ["wrath"] as Array[String]), K.equip(hex, ["ember", "storm"] as Array[String])])],
		seed_value, 1, [_benched_vell(mend)])


func _benched_vell(mend: ItemDef) -> UnitSetup:
	var vell: UnitSetup = K.unit("vell", 260, BACK, [K.item("chime", {"rarity": "uncommon", "effects": [],
		"backup": {"cooldown_ms": 2500, "effects": [{"trigger": "on_fire", "type": "heal", "amount": 9, "target": "ally_lowest_hp"}]}})])
	vell.backup = K.backup({"cooldown_ms": 3000, "effects": [{"trigger": "on_fire", "type": "damage", "amount": 6, "target": "enemy_random"}]})
	return vell


func test_same_seed_same_log() -> void:
	var first: FightResult = CombatSim.run(_chaotic_fight(5), K.content())
	var second: FightResult = CombatSim.run(_chaotic_fight(5), K.content())
	assert_eq(first.errors, [] as Array[String])
	assert_gt(first.combat_log.entries.size(), 100, "a real fight happened")
	assert_gt(first.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).size(), 0, "statuses are in play")
	assert_gt(first.combat_log.of_kind(LogEntry.Kind.INFUSION_LEVEL).size(), 0, "an infusion levels up")
	assert_eq(first.combat_log.of_kind(LogEntry.Kind.AURA).size() >= 2, true, "auras start and end")
	assert_eq(first.combat_log.to_text(), second.combat_log.to_text())
	assert_eq(first.outcome, second.outcome)
	assert_eq(first.end_tick, second.end_tick)


func test_different_seed_different_log() -> void:
	var first: FightResult = CombatSim.run(_chaotic_fight(5), K.content())
	var other: FightResult = CombatSim.run(_chaotic_fight(6), K.content())
	assert_ne(first.combat_log.to_text(), other.combat_log.to_text())


func test_stepping_matches_running() -> void:
	var ran: FightResult = CombatSim.run(_chaotic_fight(9), K.content())
	var sim := CombatSim.new(_chaotic_fight(9), K.content())
	while not sim.finished:
		sim.step()
	assert_eq(sim.combat_log.to_text(), ran.combat_log.to_text())
