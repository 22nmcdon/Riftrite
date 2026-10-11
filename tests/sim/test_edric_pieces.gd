extends GutTest
## The fight pieces Edric's paths and apexes added (phase 8 part 5,
## docs/plans/rebuild-phase8-severine-edric.md section 5, 8e-3a), each in a
## small fight: the aura stat shield_absorb_bp (Hallowed Ground: a Shield
## absorbs more), trigger_ally on on_ally_shield_broken (the ally whose
## Shield broke: Offering, Reforge), lowest_hp_ally's count (Bastion of
## Saints' taste), a Shield's plus_per_shard_bp (Golden Aegis, from
## FightSetup.shards), and the effect shards (Collection; SHARDS).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 1000) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## An attacker hitting `holder_kit` (its first hero) for 100 a second.
func _hit_fight(heroes: Array[UnitSetup]) -> CombatSim:
	var attacker: UnitDef = K.kit("attacker", {"stats": {"hp": 5000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 100, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight(heroes, [K.foe(attacker, 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("attacker").pos = fight.heroes[0].pos + Vector2i(0, 400)
	return fight


func _effect(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func test_reading_the_pieces() -> void:
	assert_eq(_effect({"type": "shield", "amount": 0, "plus_per_shard_bp": 20000, "target": "all_allies"}), [] as Array[String])
	assert_eq(_effect({"trigger": "on_ally_shield_broken", "type": "gain_mana", "amount": 5, "target": "trigger_ally"}), [] as Array[String])
	assert_false(_effect({"trigger": "on_hit_taken", "type": "gain_mana", "amount": 5, "target": "trigger_ally"}).is_empty(), "trigger_ally needs its event")
	assert_eq(_effect({"trigger": "on_interval", "interval_ms": 1000, "type": "shield", "amount": 5, "target": "lowest_hp_ally", "count": 2}), [] as Array[String])
	assert_eq(_effect({"trigger": "on_enemy_fell", "type": "shards", "amount": 1, "target": "self"}), [] as Array[String])
	assert_false(_effect({"trigger": "on_enemy_fell", "type": "shards", "amount": 1, "target": "all_allies"}).is_empty(), "its own")


func test_a_shield_that_absorbs_twice_as_much() -> void:
	var holder: UnitDef = K.kit("holder", {"stats": {"hp": 1000, "speed": 0, "range": 1, "def": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"passives": [{"id": "hallowed", "name": "Hallowed", "kind": "aura", "aura": {"target": "holder", "stat": "shield_absorb_bp", "value": 10000}}]})
	var fight: CombatSim = _hit_fight([K.at(holder, 3, 2)] as Array[UnitSetup])
	var unit: UnitState = fight.unit_by_id("holder")
	unit.shield = 300
	K.step(fight, 22)
	var hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "attacker")[0]
	assert_eq([unit.shield, unit.hp, hit.absorbed], [300 - hit.amount / 2, 1000, hit.amount], "the whole hit absorbed, at half the Shield")


func test_trigger_ally_is_the_ally_whose_shield_broke() -> void:
	var holder: UnitDef = K.kit("holder", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"mana": {"max": 100, "per_attack": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "nothing", "name": "Nothing", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "self"}]}})
	var priest: UnitDef = K.kit("priest", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"passives": [{"id": "offering", "name": "Offering", "kind": "ability", "effects": [
			{"trigger": "on_ally_shield_broken", "type": "gain_mana", "amount": 5, "target": "trigger_ally"},
			{"trigger": "on_ally_shield_broken", "type": "shield", "amount_bp_of_max_hp": 200, "target": "trigger_ally", "cooldown_per_unit_ms": 8000}]}]})
	var fight: CombatSim = _hit_fight([K.at(holder, 3, 2), K.at(priest, 0, 0)] as Array[UnitSetup])
	fight.unit_by_id("holder").shield = 10
	K.step(fight, 22)
	var given: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MANA_GIVEN, "priest")
	assert_eq(given.map(func(entry: LogEntry) -> String: return entry.target), ["holder"], "the ally whose Shield broke, not its breaker")
	var shields: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHIELD, "priest")
	assert_eq(shields.map(func(entry: LogEntry) -> Array: return [entry.target, entry.amount]), [["holder", 20]], "a new Shield of 2% of its max HP")
	K.step(fight, 40)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD, "priest").size(), 1, "it broke again, but the next waits out its 8s")
	assert_eq(K.entries(fight, LogEntry.Kind.MANA_GIVEN, "priest").size(), 2, "the new Shield broke too, and its mana came without a cooldown")


func test_lowest_hp_ally_reaches_the_two_lowest() -> void:
	var priest: UnitDef = K.kit("priest", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"passives": [{"id": "hallow", "name": "Hallow", "kind": "ability", "effects": [
			{"trigger": "on_interval", "interval_ms": 1000, "type": "shield", "amount": 5, "target": "lowest_hp_ally", "count": 2}]}]})
	var fight: CombatSim = K.sim(K.fight([K.at(priest, 0, 0), K.at(_dummy("a"), 2, 0), K.at(_dummy("b"), 4, 0)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 7, 6)] as Array[UnitSetup]))
	fight.unit_by_id("a").hp = 500
	fight.unit_by_id("b").hp = 300
	K.step(fight, 21)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD, "priest").map(func(entry: LogEntry) -> String: return entry.target), ["b", "a"], "the lowest first, then the next")


func test_a_shield_grows_with_the_shards_held() -> void:
	var priest: UnitDef = K.kit("priest", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"passives": [{"id": "golden", "name": "Golden", "kind": "ability", "effects": [
			{"trigger": "on_fight_start", "type": "shield", "amount_bp_of_max_hp": 800, "plus_per_shard_bp": 20000, "target": "self"}]}]})
	var setup: FightSetup = K.fight([K.at(priest, 0, 0)] as Array[UnitSetup], [K.foe(_dummy("mark"), 7, 6)] as Array[UnitSetup])
	setup.shards = 30
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 2)
	assert_eq(fight.unit_by_id("priest").shield, 80 + 60, "8% of 1,000 and 2 for each of 30 shards")
	var poor: CombatSim = K.sim(K.fight([K.at(priest, 0, 0)] as Array[UnitSetup], [K.foe(_dummy("mark"), 7, 6)] as Array[UnitSetup]))
	K.step(poor, 2)
	assert_eq(poor.unit_by_id("priest").shield, 80, "none held: none added")


func test_shards_for_the_run() -> void:
	var collector: UnitDef = K.kit("collector", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 500, "target": "target"}]},
		"passives": [{"id": "collection", "name": "Collection", "kind": "ability", "effects": [{"trigger": "on_enemy_fell", "type": "shards", "amount": 1, "target": "self"}]}]})
	var fight: CombatSim = K.sim(K.fight([K.at(collector, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark", 100), 3, 4), K.foe(_dummy("far"), 7, 6)] as Array[UnitSetup]))
	fight.unit_by_id("mark").pos = fight.unit_by_id("collector").pos + Vector2i(0, 400)
	K.step(fight, 24)
	var paid: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHARDS, "collector")
	assert_eq(paid.map(func(entry: LogEntry) -> int: return entry.amount), [1])
	assert_string_contains(paid[0].to_text(), "collects 1 shard")
