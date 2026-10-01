extends GutTest
## Tallies (docs/plans/rebuild-phase5c-combos.md, step 4, section 9.4): what
## a hero's growing cards count, the way deeds do, including the kinds and
## filters step 4 adds. Counting never changes a fight.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _hero(attack: Dictionary = {}, passives: Array = []) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	return K.kit("hero", {"stats": {"hp": 1000, "atk": 10, "speed": 0, "range": 2}, "basic_attack": basic, "passives": passives})


func _dummy(attack: Dictionary = {}, hp: int = 100000) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	return K.kit("dummy", {"stats": {"hp": hp, "speed": 0, "range": 2}, "basic_attack": basic})


func _count(data: Dictionary, errors: Array[String] = []) -> DeedDef:
	var with_text: Dictionary = {"text": "x"}
	with_text.merge(data)
	return DeedDef.read(DataReader.new(with_text, "count", errors))


## A duel where the hero tallies `counts` (key -> its counting).
func _duel(counts: Dictionary, hero: UnitDef = null, enemy: UnitDef = null) -> CombatSim:
	var setup: UnitSetup = K.at(hero if hero != null else _hero(), 3, 2)
	for key: String in counts:
		setup.tally_keys.append(key)
		setup.tally_counts.append(_count(counts[key]))
	return K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(enemy if enemy != null else _dummy(), 3, 4)] as Array[UnitSetup]))


func _tally(fight: CombatSim, key: String) -> int:
	return CombatSim.result_of(fight).tally_amount("hero", key)


func test_reading_the_new_kinds_and_filters() -> void:
	for good: Dictionary in [{"counts": "applied", "keywords": ["marked"]}, {"counts": "taken"}, {"counts": "ms_below", "while_below_pct": 30},
			{"counts": "kills"}, {"counts": "damage", "from_basic": true}]:
		var errors: Array[String] = []
		_count(good, errors)
		assert_eq(errors, [] as Array[String], str(good))
	for bad: Dictionary in [{"counts": "ms_below"}, {"counts": "damage", "keywords": ["marked"]}, {"counts": "taken", "from_basic": true},
			{"counts": "kills", "from_ability": ["x"]}, {"counts": "healing", "while_below_pct": 30}]:
		var errors: Array[String] = []
		_count(bad, errors)
		assert_false(errors.is_empty(), "refused: %s" % bad)


func test_tallies_count_like_deeds_and_come_back_on_the_result() -> void:
	var fight: CombatSim = _duel({"hits": {"counts": "damage"}, "basic": {"counts": "damage", "from_basic": true}},
		_hero({}, [{"id": "spite", "name": "Spite", "kind": "ability", "effects": [{"trigger": "on_basic_attack", "type": "damage", "amount": 1, "target": "target"}]}]))
	K.step(fight, 4)
	assert_eq(_tally(fight, "hits"), 4 * 10 + 4 * 1, "every hit's damage, the passive's too")
	assert_eq(_tally(fight, "basic"), 4 * 10, "only the basic attack's")
	assert_eq(CombatSim.result_of(fight).deeds.size(), 0, "tallies aren't deeds")


func test_applied_counts_statuses_on_enemies_by_keyword() -> void:
	var hero: UnitDef = _hero({"cooldown_ms": 1000, "effects": [{"type": "apply_status", "status": "marked", "target": "target"},
		{"type": "apply_status", "status": "slow", "target": "target"}, {"type": "shield", "amount": 1, "target": "self"}]})
	var fight: CombatSim = _duel({"marks": {"counts": "applied", "keywords": ["marked"]}, "any": {"counts": "applied"}}, hero)
	K.step(fight, 3 * FixedMath.TICKS_PER_SECOND)
	assert_eq(_tally(fight, "marks"), 3, "each Mark")
	assert_eq(_tally(fight, "any"), 6, "each status on an enemy (a Shield on itself isn't one)")


func test_taken_counts_what_enemies_deal_it() -> void:
	var biter: UnitDef = _dummy({"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 7, "target": "target"}]})
	var fight: CombatSim = _duel({"taken": {"counts": "taken"}}, _hero({"cooldown_ms": 60000}), biter)
	Statuses.apply(fight, fight.units[0], "poison", 5, 0, EffectSource.make("dummy", "dummy_attack", "Strike"))
	K.step(fight, FixedMath.TICKS_PER_SECOND)
	assert_eq(_tally(fight, "taken"), 20 * 7 + 5, "its hits and the poison's tick")


func test_ms_below_counts_time_under_the_share() -> void:
	var fight: CombatSim = _duel({"low": {"counts": "ms_below", "while_below_pct": 30}}, _hero({"cooldown_ms": 60000}))
	K.step(fight, 5)
	fight.units[0].hp = 200
	K.step(fight, 10)
	fight.units[0].hp = 900
	K.step(fight, 5)
	assert_eq(_tally(fight, "low"), 10 * FixedMath.MS_PER_TICK, "the 10 ticks spent below 30%")


func test_kills_counts_the_enemies_it_fells() -> void:
	var fight: CombatSim = K.sim(K.fight([_tallying("kills", {"counts": "kills"})] as Array[UnitSetup],
		[K.foe(_dummy({}, 25), 3, 4), K.foe(_dummy({}, 25), 4, 4, "other")] as Array[UnitSetup]))
	K.step(fight, 20)
	assert_false(fight.units[1].alive or fight.units[2].alive)
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "kills"), 2)


func _tallying(key: String, data: Dictionary) -> UnitSetup:
	var setup: UnitSetup = K.at(_hero(), 3, 2)
	setup.tally_keys.append(key)
	setup.tally_counts.append(_count(data))
	return setup


func test_counting_never_changes_the_fight() -> void:
	var plain: FightResult = K.run(K.fight([K.at(_hero(), 3, 2)] as Array[UnitSetup], [K.foe(_dummy({}, 300), 3, 4)] as Array[UnitSetup]))
	var counted: FightResult = K.run(K.fight([_tallying("hits", {"counts": "damage"})] as Array[UnitSetup], [K.foe(_dummy({}, 300), 3, 4)] as Array[UnitSetup]))
	assert_eq(counted.combat_log.to_text(), plain.combat_log.to_text())
	assert_eq(counted.tally_amount("hero", "hits"), 300)


func test_a_setup_needs_a_count_for_each_key() -> void:
	var setup: UnitSetup = _tallying("hits", {"counts": "damage"})
	setup.tally_keys.append("more")
	var problems: Array[String] = K.fight([setup] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]).validate(K.content())
	assert_true(problems.any(func(problem: String) -> bool: return problem.contains("tally keys")))
