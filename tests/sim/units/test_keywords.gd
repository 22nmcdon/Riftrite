extends GutTest
## Keywords and conditions (docs/plans/rebuild-phase5c-combos.md, step 3,
## sections 8.2 and 8.3): names for a unit's state, one shape for "a unit
## that is ...", and the auras that use it.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _hero(passives: Array = []) -> UnitDef:
	return K.kit("hero", {"stats": {"hp": 1000, "atk": 100, "speed": 0, "range": 2}, "passives": passives,
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}})


func _dummy(overrides: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(overrides, true)
	return K.kit("dummy", data)


func _duel(hero: UnitDef, dummy: UnitDef = null) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(dummy if dummy != null else _dummy(), 3, 4)] as Array[UnitSetup]))


func _source() -> EffectSource:
	return EffectSource.make("hero", "hero_attack", "Strike")


func _condition(data: Dictionary, errors: Array[String] = []) -> UnitCondition:
	return UnitCondition.read(DataReader.new(data, "condition", errors))


func _aura(part_id: String, aura: Dictionary) -> Dictionary:
	aura.merge({"target": "holder"})
	return {"id": part_id, "name": part_id.capitalize(), "kind": "aura", "aura": aura}


func test_the_statuses_carry_their_keywords() -> void:
	var content: ContentDb = K.content()
	assert_eq(content.statuses["marked"].keyword, "marked")
	assert_eq(content.statuses["root"].keyword, "rooted")
	assert_eq(content.statuses["burn"].keyword, "burning")
	assert_eq(content.statuses["stealth"].keyword, "stealthed")
	assert_eq(content.statuses["stun"].keyword, "", "Stun isn't a keyword (yet)")


func test_a_status_names_only_a_known_keyword_and_never_shielded() -> void:
	for keyword: String in ["dazed", "shielded"]:
		var errors: Array[String] = []
		StatusDef.read(DataReader.new({"id": "x", "name": "X", "kind": "root", "duration_ms": 1000, "keyword": keyword}, "x", errors))
		assert_false(errors.is_empty(), "\"%s\" is refused" % keyword)


func test_each_keyword_holds_exactly_while_its_state_does() -> void:
	var fight: CombatSim = _duel(_hero())
	var dummy: UnitState = fight.units[1]
	for keyword: String in Keywords.NAMES:
		assert_false(Keywords.has(dummy, keyword), "%s: not at the start" % keyword)
	Statuses.apply(fight, dummy, "marked", 1, 0, _source())
	Statuses.apply(fight, dummy, "root", 1, 0, _source())
	Statuses.apply(fight, dummy, "stealth", 1, 0, _source())
	Statuses.apply(fight, dummy, "burn", 1, 0, _source())
	EffectRunner.give_shield(fight, dummy, 50, _source())
	for keyword: String in Keywords.NAMES:
		assert_true(Keywords.has(dummy, keyword), "%s: once applied" % keyword)
	EffectRunner.deal_hit(fight, _source(), dummy, 1000, false)
	assert_false(Keywords.has(dummy, Keywords.SHIELDED), "Shielded ends when the Shield runs out")
	K.step(fight, 3 * FixedMath.TICKS_PER_SECOND)
	assert_false(Keywords.has(dummy, "burning"), "Burning ends with the last stack")
	assert_false(Keywords.has(dummy, "stealthed"), "Stealth ran out")
	assert_true(Keywords.has(dummy, "marked"), "the Mark lasts 4s")


func test_each_field_of_a_condition() -> void:
	var flier: UnitDef = _dummy({"traits": ["flying"]})
	flier.archetype = "caster"
	var fight: CombatSim = _duel(_hero(), flier)
	var dummy: UnitState = fight.units[1]
	assert_false(_condition({"keywords": ["rooted"]}).holds(dummy))
	assert_false(_condition({"statuses": ["stun", "root"]}).holds(dummy))
	Statuses.apply(fight, dummy, "root", 1, 0, _source())
	assert_true(_condition({"keywords": ["rooted"]}).holds(dummy))
	assert_true(_condition({"keywords": ["marked", "rooted"]}).holds(dummy), "a list holds if any of it does")
	assert_true(_condition({"statuses": ["stun", "root"]}).holds(dummy), "Rooted or Stunned")
	assert_true(_condition({"flying": true}).holds(dummy))
	assert_false(_condition({"flying": false}).holds(dummy))
	assert_true(_condition({"archetypes": ["support", "caster"]}).holds(dummy))
	assert_false(_condition({"archetypes": ["swarm"]}).holds(dummy))
	assert_false(_condition({"below_hp_pct": 30}).holds(dummy))
	dummy.hp = dummy.max_hp * 29 / 100
	assert_true(_condition({"below_hp_pct": 30}).holds(dummy))
	assert_true(_condition({"keywords": ["rooted"], "below_hp_pct": 30, "flying": true}).holds(dummy), "every field given")
	assert_false(_condition({"keywords": ["rooted"], "archetypes": ["swarm"]}).holds(dummy), "one field failing fails it")


func test_a_condition_must_say_something_known() -> void:
	for data: Dictionary in [{}, {"keywords": ["dazed"]}, {"archetypes": ["wizard"]}, {"below_hp_pct": 100}, {"near": 2}]:
		var errors: Array[String] = []
		_condition(data, errors)
		assert_false(errors.is_empty(), "refused: %s" % data)


func test_a_condition_in_words() -> void:
	assert_eq(_condition({"keywords": ["rooted"], "statuses": ["stun"]}).describe(), "Rooted or Stun")
	assert_eq(_condition({"below_hp_pct": 30, "flying": true}).describe(), "below 30% HP, flying")


func test_a_vs_aura_is_power_against_the_targets_that_meet_it() -> void:
	var hero: UnitDef = _hero([
		_aura("thorns", {"stat": "damage_bp", "value": 12500, "vs": {"keywords": ["rooted"]}}),
		_aura("fury", {"stat": "damage_bp", "value": 11000}),
	])
	var fight: CombatSim = _duel(hero)
	var dummy: UnitState = fight.units[1]
	assert_eq(EffectRunner.deal_hit(fight, _source(), dummy, 1000, false), 1000, "the hit's own power isn't the fury aura's (that's in power_of); not Rooted: nothing")
	Statuses.apply(fight, dummy, "root", 1, 0, _source())
	assert_eq(EffectRunner.deal_hit(fight, _source(), dummy, 1000, false), 1250, "Rooted: +25% power")
	assert_eq(EffectRunner.deal_hit(fight, _source(), dummy, 1000, false, 1000), 1350, "adds with the attacker's other power: +25% +10%")
	Statuses.apply(fight, dummy, "marked", 1, 0, _source())
	assert_eq(EffectRunner.deal_hit(fight, _source(), dummy, 1000, false, 1000), 1553, "and multiplies with the Mark: x1.35 x1.15")


func test_a_vs_aura_lands_on_real_hits_and_is_logged_with_its_condition() -> void:
	var hero: UnitDef = _hero([_aura("thorns", {"stat": "damage_bp", "value": 12500, "vs": {"keywords": ["rooted"]}})])
	hero.basic_attack.cooldown_ticks = FixedMath.TICKS_PER_SECOND
	var fight: CombatSim = _duel(hero)
	Statuses.apply(fight, fight.units[1], "root", 1, 100, _source())
	K.step(fight, FixedMath.TICKS_PER_SECOND)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].amount, 125, "100 ATK, +25% against a Rooted enemy")
	var auras: Array[LogEntry] = K.entries(fight, LogEntry.Kind.AURA, "hero")
	assert_string_contains(auras[0].note, "against Rooted")


func test_only_a_damage_aura_can_be_vs() -> void:
	var errors: Array[String] = []
	AuraDef.read(DataReader.new({"target": "holder", "stat": "atk_bp", "value": 11000, "vs": {"keywords": ["rooted"]}}, "aura", errors))
	assert_false(errors.is_empty())


func test_an_aura_while_its_holder_is_in_a_state() -> void:
	var hero: UnitDef = _hero([_aura("cornered", {"stat": "atk_bp", "value": 15000, "while": "state", "state": {"keywords": ["rooted"]}})])
	var fight: CombatSim = _duel(hero)
	var unit: UnitState = fight.units[0]
	K.step(fight, 1)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 100, "off while it isn't Rooted")
	Statuses.apply(fight, unit, "root", 1, 10, _source())
	K.step(fight, 1)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 150, "on once it's Rooted")
	K.step(fight, 12)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 100, "off again when the Root ends")
	assert_eq(K.entries(fight, LogEntry.Kind.AURA, "hero").size(), 2, "its start and its end are logged")


func test_a_condition_names_only_known_statuses() -> void:
	var content: ContentDb = K.content()
	var kit: UnitDef = _hero([_aura("odd", {"stat": "damage_bp", "value": 11000, "vs": {"statuses": ["dazed"]}})])
	assert_true(kit.condition_status_ids().has("dazed"), "a kit's conditions name statuses ContentDb and FightSetup check")
	assert_false(content.statuses.has("dazed"))
