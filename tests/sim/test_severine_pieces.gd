extends GutTest
## The pieces Severine's kit added (phase 8 part 5, docs/plans/
## rebuild-phase8-severine-edric.md section 4), each in a small fight: a
## damage effect's own lifesteal ("lifesteal_pct"), added to its unit's
## lifesteal auras, and the aura stat lifesteal_more_bp, which multiplies
## the whole share and may be worked out per hit against some targets.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _effect(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func _aura(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	AuraDef.read(DataReader.new(data, "aura", errors))
	return errors


## A striker that hits for 100 a second with `steal_pct` lifesteal of its
## own, hurt so it can heal, beside a dummy at `hp_pct` of its HP.
func _fight(steal_pct: int, passives: Array = [], hp_pct: int = 100) -> CombatSim:
	var hit: Dictionary = {"type": "damage", "amount": 100, "target": "target"}
	if steal_pct > 0:
		hit["lifesteal_pct"] = steal_pct
	var striker: UnitDef = K.kit("striker", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 1000, "effects": [hit]}, "passives": passives})
	var fight: CombatSim = K.sim(K.fight([K.at(striker, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("striker").hp = 100
	var mark: UnitState = fight.unit_by_id("mark")
	mark.pos = fight.unit_by_id("striker").pos + Vector2i(0, 400)
	mark.hp = mark.max_hp * hp_pct / 100
	return fight


func _stolen(fight: CombatSim) -> Array:
	return K.entries(fight, LogEntry.Kind.LIFESTEAL, "striker").map(func(entry: LogEntry) -> int: return entry.amount)


func test_reading_the_pieces() -> void:
	assert_eq(_effect({"type": "damage", "amount": 10, "target": "target", "lifesteal_pct": 15}), [] as Array[String])
	assert_false(_effect({"type": "damage", "amount": 10, "target": "target", "lifesteal_pct": 15, "plain": true}).is_empty(), "a plain hit never lifesteals")
	assert_eq(_aura({"target": "holder", "stat": "lifesteal_more_bp", "value": 10000, "vs": {"below_hp_pct": 50}}), [] as Array[String])
	assert_eq(_aura({"target": "holder", "stat": "lifesteal_more_bp", "value": 10000, "from_basic": true}), [] as Array[String])


func test_a_hit_lifesteals_its_own_share() -> void:
	var fight: CombatSim = _fight(20)
	K.step(fight, 22)
	assert_eq(_stolen(fight), [20], "20% of the 100 it dealt")
	var none: CombatSim = _fight(0)
	K.step(none, 22)
	assert_eq(_stolen(none), [], "no lifesteal anywhere: none")


func test_its_share_adds_to_the_units_auras() -> void:
	var fight: CombatSim = _fight(20, [{"id": "thirst", "name": "Thirst", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_bp", "value": 1000}}])
	K.step(fight, 22)
	assert_eq(_stolen(fight), [30], "20% and the aura's 10%")


func test_more_lifesteal_multiplies_the_share_against_some_targets() -> void:
	var more: Array = [{"id": "hemophage", "name": "Hemophage", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_more_bp", "value": 10000, "vs": {"below_hp_pct": 50}}}]
	var healthy: CombatSim = _fight(20, more, 100)
	K.step(healthy, 22)
	assert_eq(_stolen(healthy), [20], "the target is above half its HP")
	var wounded: CombatSim = _fight(20, more, 40)
	K.step(wounded, 22)
	assert_eq(_stolen(wounded), [40], "doubled below half its HP")
	var always: CombatSim = _fight(20, [{"id": "more", "name": "More", "kind": "aura", "aura": {"target": "holder", "stat": "lifesteal_more_bp", "value": 5000}}])
	K.step(always, 22)
	assert_eq(_stolen(always), [30], "+50% on every hit")
