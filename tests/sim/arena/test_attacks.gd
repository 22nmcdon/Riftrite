extends GutTest
## Basic attacks: reach, cooldowns, attack speed, and the numbers
## (docs/plans/rebuild-phase1-arena-sim.md, sections 4 and 5).

const K = preload("res://tests/sim/sim_test_kit.gd")


## A unit that stands and swings at anything within 2 hexes, landing at once.
func _swinger(stats: Dictionary = {}, effects: Array = [{"type": "damage", "amount": 10, "target": "target"}], attack: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var basic: Dictionary = {"shot": false, "effects": effects}
	basic.merge(attack, true)
	return K.kit("swinger", {"stats": all_stats, "basic_attack": basic})


func _dummy(stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	return K.kit("dummy", {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A swinger at (3, 2) facing a dummy at (3, 4), exactly 2 hexes away.
func _duel(swinger: UnitDef, dummy: UnitDef = _dummy()) -> CombatSim:
	return K.sim(K.fight([K.at(swinger, 3, 2)] as Array[UnitSetup], [K.foe(dummy, 3, 4)] as Array[UnitSetup]))


func _hits(fight: CombatSim) -> Array[LogEntry]:
	return K.entries(fight, LogEntry.Kind.DAMAGE, "swinger")


func test_the_first_attack_waits_one_cooldown() -> void:
	var fight: CombatSim = _duel(_swinger())
	K.step(fight, 19)
	assert_eq(_hits(fight).size(), 0)
	fight.step()
	assert_eq(_hits(fight).size(), 1, "a 1s attack first lands at 1s")
	K.step(fight, 20)
	assert_eq(_hits(fight).size(), 2)


func test_attack_speed() -> void:
	# 100 ATSP x 100 bp a point = twice as fast.
	var fight: CombatSim = _duel(_swinger({"atsp": 100}))
	K.step(fight, 40)
	assert_eq(_hits(fight).size(), 4)
	assert_eq(_hits(fight)[0].tick, 10)


func test_melee_needs_to_be_close() -> void:
	var walker: UnitDef = K.kit("walker", {"stats": {"hp": 10000, "speed": 2, "range": 1}})
	var fight: CombatSim = K.sim(K.fight([K.at(walker, 3, 0)] as Array[UnitSetup], [K.foe(_dummy(), 3, 6)] as Array[UnitSetup]))
	var fired: Array[LogEntry] = []
	while fired.is_empty():
		fight.step()
		fired = K.entries(fight, LogEntry.Kind.FIRE, "walker")
	assert_lte(ArenaPlane.distance(fight.units[0].pos, fight.units[1].pos), 1000, "it attacked from 1 hex")
	assert_gt(fight.tick, 40, "after walking up")
	assert_eq(K.entries(fight, LogEntry.Kind.SHOT).size(), 0, "melee lands at once")


func test_the_numbers() -> void:
	# 4 + 60% of 20 ATK = 16; DEF 100 against a constant of 100 halves it.
	var fight: CombatSim = _duel(_swinger({"atk": 20}, [{"type": "damage", "amount": 4, "target": "target", "scaling": {"atk": 6000}}]), _dummy({"def": 100}))
	K.step(fight, 20)
	var hit: LogEntry = _hits(fight)[0]
	assert_eq([hit.amount, hit.mitigated, hit.crit], [8, 8, false])
	assert_eq(fight.units[1].hp, 10000 - 8)


func test_crits() -> void:
	# 100 CRIT x 100 bp a point: every hit crits, for 150%.
	var fight: CombatSim = _duel(_swinger({"crit": 100}))
	K.step(fight, 20)
	var hit: LogEntry = _hits(fight)[0]
	assert_eq([hit.amount, hit.crit], [15, true])
	var half: CombatSim = _duel(_swinger({}, [{"type": "damage", "amount": 10, "target": "target"}], {"crit_chance_bp": 5000}))
	K.step(half, 20 * 40)
	var crits: int = _hits(half).filter(func(entry: LogEntry) -> bool: return entry.crit).size()
	assert_between(crits, 10, 30, "an attack's own crit chance: about half of 40")


func test_shield_soaks_first() -> void:
	var fight: CombatSim = _duel(_swinger())
	fight.units[1].shield = 6
	K.step(fight, 20)
	var hit: LogEntry = _hits(fight)[0]
	assert_eq([hit.amount, hit.absorbed, fight.units[1].shield, fight.units[1].hp], [10, 6, 0, 10000 - 4])


func test_other_effects_of_an_attack() -> void:
	var fight: CombatSim = _duel(_swinger({}, [
		{"type": "damage", "amount": 10, "target": "target"},
		{"type": "heal", "amount": 7, "target": "self"},
		{"trigger": "on_hit", "type": "shield", "amount_bp_of_damage": 5000, "target": "self"},
		{"type": "damage", "amount": 1, "target": "all_enemies"},
	]))
	fight.units[0].hp = 9990
	K.step(fight, 20)
	assert_eq(fight.units[0].hp, 9997, "healed 7")
	assert_eq(fight.units[0].shield, 5 + 1, "half of each hit as Shield: 5 for the 10, and half of the 1 rounds up")
	assert_eq(fight.units[1].hp, 10000 - 11)
	var heal: LogEntry = K.entries(fight, LogEntry.Kind.HEAL, "swinger")[0]
	assert_eq([heal.target, heal.amount, heal.source_ability_name], ["swinger", 7, "Strike"])


func test_heals_stop_at_max_hp() -> void:
	var fight: CombatSim = _duel(_swinger({}, [{"type": "damage", "amount": 1, "target": "target"}, {"type": "heal", "amount": 50, "target": "self"}]))
	fight.units[0].hp = 9980
	K.step(fight, 20)
	assert_eq(fight.units[0].hp, 10000)
	assert_eq(K.entries(fight, LogEntry.Kind.HEAL, "swinger")[0].amount, 20)


func test_on_hit_damage_never_sets_off_more_hits() -> void:
	var fight: CombatSim = _duel(_swinger({}, [
		{"type": "damage", "amount": 10, "target": "target"},
		{"trigger": "on_hit", "type": "damage", "amount": 2, "target": "hit_target"},
	]))
	K.step(fight, 20)
	var amounts: Array[int] = []
	for hit: LogEntry in _hits(fight):
		amounts.append(hit.amount)
	assert_eq(amounts, [10, 2] as Array[int], "one attack, one on_hit, and no chain")
