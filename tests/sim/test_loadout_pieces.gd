extends GutTest
## The small sim pieces the loadout pool's frame needed (docs/plans/
## rebuild-phase5c-combos.md, step 6a, section 14.5), each in a small fight:
## on_below_hp (the unit itself, up to "times" a fight), the target
## allies_near_self (as its unit falls too), and cleanse's "statuses".

const K = preload("res://tests/sim/sim_test_kit.gd")


func _hero(passives: Array = [], hero_id: String = "hero", hp: int = 1000) -> UnitDef:
	return K.kit(hero_id, {"stats": {"hp": hp, "atk": 10, "speed": 0, "range": 2}, "passives": passives,
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _dummy() -> UnitDef:
	return K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _from_dummy() -> EffectSource:
	return EffectSource.make("dummy", "dummy_attack", "Strike")


func _read(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	PartDef.read(DataReader.new({"id": "p", "name": "P", "kind": "ability", "effects": [data]}, "part", errors))
	return errors


func test_reading_the_pieces() -> void:
	assert_eq(_read({"trigger": "on_below_hp", "threshold_bp": 5000, "times": 2, "type": "shield", "amount_bp_of_max_hp": 1500, "target": "self"}), [] as Array[String])
	assert_false(_read({"trigger": "on_below_hp", "type": "shield", "amount": 1, "target": "self"}).is_empty(), "it needs a threshold")
	assert_eq(_read({"trigger": "on_fall", "type": "shield", "amount": 1, "target": "allies_near_self", "within_hexes": 2}), [] as Array[String])
	assert_false(_read({"trigger": "on_fall", "type": "shield", "amount": 1, "target": "allies_near_self"}).is_empty(), "it needs a reach")
	assert_eq(_read({"trigger": "on_heal", "type": "cleanse", "amount_bp": 10000, "statuses": ["bleed"], "target": "hit_target"}), [] as Array[String])


func test_on_below_hp_runs_as_it_drops_below() -> void:
	var ward: Array = [{"id": "ward", "name": "Ward", "kind": "ability",
		"effects": [{"trigger": "on_below_hp", "threshold_bp": 5000, "times": 2, "type": "shield", "amount": 50, "target": "self"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(ward), 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 0, "at full HP, nothing")
	hero.hp = 400
	fight.step()
	assert_eq(hero.shield, 50, "it dropped below half")
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 1, "once for each drop")
	hero.hp = 900
	fight.step()
	hero.hp = 300
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 2, "healed above and dropped again: the second time")
	hero.hp = 900
	fight.step()
	hero.hp = 300
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 2, "twice a fight at most")


func test_allies_near_self_as_it_falls() -> void:
	var last: Array = [{"id": "last", "name": "Last", "kind": "ability",
		"effects": [{"trigger": "on_fall", "type": "shield", "amount": 40, "target": "allies_near_self", "within_hexes": 2}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(last, "giver", 10), 3, 2, "giver"), K.at(_hero([], "near"), 4, 2, "near"), K.at(_hero([], "far"), 0, 0, "far")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	EffectRunner.deal_hit(fight, _from_dummy(), fight.unit_by_id("giver"), 100, false)
	K.step(fight, 2)
	assert_false(fight.unit_by_id("giver").alive)
	assert_eq([fight.unit_by_id("near").shield, fight.unit_by_id("far").shield], [40, 0], "within 2 hexes of where it fell")


func test_a_cleanse_of_some_statuses() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(), 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	var burn := EffectDef.new()
	for status: String in ["bleed", "burn"]:
		Statuses.apply(fight, hero, status, 3, 0, _from_dummy())
	burn.type = EffectDef.Type.CLEANSE
	burn.amount = FixedMath.BP_ONE
	burn.cleanse_statuses.assign(["bleed"])
	burn.target = EffectDef.Target.TARGET
	EffectRunner.land(fight, hero, hero.def.basic_attack, EffectSource.make("hero", "hero_attack", "Strike"), burn, hero, FixedMath.BP_ONE, false)
	var left: Array = hero.statuses.map(func(state: StatusState) -> String: return state.def.id)
	assert_eq(left, ["burn"], "only Bleed is cleansed")
