extends GutTest
## The pieces Aldous's apexes added (phase 8 part 4, docs/plans/
## rebuild-phase8-heroes.md 8d-4c), each in a small fight: the aura stats
## mana_gain_bp, mana_store_bp, and overflow_power_bp, the condition
## fired_over_full, a boost's signature_power_bp, an aura's per_hex, the
## trigger on_ally_hit and the "by" filters, the deed counts ally_casts and
## mana_overflow, and gain_mana's grows_per_stack.

const K = preload("res://tests/sim/sim_test_kit.gd")
## A signature that never fills, so a unit can carry a mana bar.
const IDLE: Dictionary = {"id": "idle", "name": "Idle", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "heal", "amount": 1, "target": "self"}]}
const BLAST: Dictionary = {"id": "blast", "name": "Blast", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 6,
	"effects": [{"type": "damage", "amount": 100, "target": "target"}]}


func _dummy(dummy_id: String, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 10000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(extra, true)
	return K.kit(dummy_id, data)


func _aura(part_id: String, aura: Dictionary) -> Dictionary:
	return {"id": part_id, "name": part_id.capitalize(), "kind": "aura", "aura": aura}


func _place(fight: CombatSim, offsets: Dictionary) -> void:
	var at: Vector2i = fight.unit_by_id("hero").pos
	for unit_id: String in offsets:
		fight.unit_by_id(unit_id).pos = at + (offsets[unit_id] as Vector2i)


func _count(setup: UnitSetup, key: String, data: Dictionary) -> void:
	var errors: Array[String] = []
	setup.tally_keys.append(key)
	setup.tally_counts.append(DeedDef.read(DataReader.new(data, "count", errors)))
	assert_eq(errors, [] as Array[String])


func _source() -> EffectSource:
	return EffectSource.make("", "test", "Test")


func test_more_mana_from_every_source() -> void:
	var gain: Array = [_aura("voice", {"target": "holder", "stat": "mana_gain_bp", "value": 15000})]
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 1000, "per_attack": 10, "regen_per_s": 0}, "signature": IDLE, "passives": gain, "stats": {"speed": 0}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"mark": Vector2i(0, 400)})
	K.step(fight, 25)
	assert_eq(fight.unit_by_id("hero").mana, 1500, "15 for an attack's 10")
	var regen: UnitDef = K.kit("hero", {"mana": {"max": 1000, "per_attack": 0, "regen_per_s": 2}, "signature": IDLE, "passives": gain, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	fight = K.sim(K.fight([K.at(regen, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	K.step(fight, 20)
	assert_eq(fight.unit_by_id("hero").mana, 300, "and regen: 3 a second, not 2")


func test_a_bar_past_full_keeps_the_rest_and_hits_harder() -> void:
	var deep: Array = [_aura("deep", {"target": "holder", "stat": "mana_store_bp", "value": 20000}), _aura("overflow", {"target": "holder", "stat": "overflow_power_bp", "value": 100})]
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "per_attack": 0}, "signature": BLAST, "passives": deep, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("hero")
	assert_eq(unit.mana_store, 2000, "it holds two bars")
	unit.mana = 1500
	K.step(fight, 6)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_eq(hits.map(func(entry: LogEntry) -> int: return entry.amount), [105], "+1% for each of the 5 mana past full")
	assert_eq(unit.mana, 500, "one bar spent, the rest kept")
	assert_true(UnitCondition.read(DataReader.new({"fired_over_full": true}, "condition", [] as Array[String])).holds(unit))
	var plain: UnitDef = K.kit("hero", {"mana": {"max": 10, "per_attack": 0}, "signature": BLAST, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	fight = K.sim(K.fight([K.at(plain, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	assert_eq(fight.unit_by_id("hero").mana_store, 0, "no store without one")


func test_a_boost_for_the_next_signature() -> void:
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": BLAST, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	Statuses.apply(fight, fight.unit_by_id("hero"), "grand_note", 0, 0, _source())
	K.step(fight, 6)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> int: return entry.amount), [130])
	var ended: Array = K.entries(fight, LogEntry.Kind.STATUS_ENDED).filter(func(entry: LogEntry) -> bool: return entry.status == "grand_note")
	assert_eq(ended.size(), 1)
	assert_string_contains(ended[0].note, "spent by its signature")


func test_more_damage_for_each_hex() -> void:
	var far: Array = [_aura("long_wind", {"target": "holder", "stat": "damage_bp", "value": 11000, "per_hex": true})]
	var amounts: Array[int] = []
	for hexes: int in [1, 3]:
		var hero: UnitDef = K.kit("hero", {"passives": far, "stats": {"speed": 0, "range": 4}, "basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 100, "target": "target"}]}})
		var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
		_place(fight, {"mark": Vector2i(0, hexes * 1000 + 100)})
		K.step(fight, 30)
		amounts.append(K.entries(fight, LogEntry.Kind.DAMAGE, "hero")[0].amount)
	assert_eq(amounts, [110, 130] as Array[int], "+10% a whole hex")


func test_an_allys_hit_by_a_ranged_ally() -> void:
	var ring: Array = [{"id": "ring", "name": "Ring", "kind": "ability",
		"effects": [{"trigger": "on_ally_hit", "by": {"ranged": true}, "type": "damage", "amount": 7, "target": "hit_target"}]}]
	var hero: UnitDef = _dummy("hero", {"passives": ring, "stats": {"hp": 1000, "speed": 0, "range": 3}})
	var archer: UnitDef = K.kit("archer", {"stats": {"speed": 0, "range": 4}})
	var brawler: UnitDef = K.kit("brawler", {"stats": {"speed": 0, "range": 1}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 4, 0), K.at(archer, 2, 2), K.at(brawler, 6, 2)] as Array[UnitSetup],
		[K.foe(_dummy("by_archer"), 2, 5), K.foe(_dummy("by_brawler"), 6, 4)] as Array[UnitSetup]))
	_place(fight, {"archer": Vector2i(-2000, 0), "by_archer": Vector2i(-2000, 3500), "brawler": Vector2i(2000, 0), "by_brawler": Vector2i(2000, 300)})
	K.step(fight, 50)
	var archer_hits: int = K.entries(fight, LogEntry.Kind.DAMAGE, "archer").size()
	assert_gt(archer_hits, 0)
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "brawler").size(), 0)
	var rung: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_eq(rung.size(), archer_hits, "one for each of the archer's hits, none for the brawler's")
	assert_eq(rung.map(func(entry: LogEntry) -> String: return entry.target).filter(func(id: String) -> bool: return id != "by_archer"), [], "on what it hit")


func test_a_kill_by_a_ranged_ally_from_afar() -> void:
	var gust: Array = [{"id": "gust", "name": "Gust", "kind": "ability",
		"effects": [{"trigger": "on_enemy_fell", "by": {"ranged": true}, "by_beyond_hexes": 3, "type": "apply_status", "status": "wellspring_swell", "target": "self"}]}]
	var hero: UnitDef = _dummy("hero", {"passives": gust, "stats": {"hp": 1000, "speed": 0, "range": 3}})
	var archer: UnitDef = K.kit("archer", {"stats": {"speed": 0, "range": 4}, "basic_attack": {"effects": [{"type": "damage", "amount": 50, "target": "target"}]}})
	var brawler: UnitDef = K.kit("brawler", {"stats": {"speed": 0, "range": 1}, "basic_attack": {"effects": [{"type": "damage", "amount": 50, "target": "target"}]}})
	var weak: Dictionary = {"stats": {"hp": 40, "speed": 0, "range": 1}}
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 4, 0), K.at(archer, 2, 2), K.at(brawler, 6, 2)] as Array[UnitSetup],
		[K.foe(_dummy("by_archer", weak), 2, 5), K.foe(_dummy("by_brawler", weak), 6, 4), K.foe(_dummy("last"), 4, 6)] as Array[UnitSetup]))
	_place(fight, {"archer": Vector2i(-2000, 0), "by_archer": Vector2i(-2000, 3500), "brawler": Vector2i(2000, 0), "by_brawler": Vector2i(2000, 300), "last": Vector2i(0, 6000)})
	K.step(fight, 40)
	assert_false(fight.unit_by_id("by_archer").alive)
	assert_false(fight.unit_by_id("by_brawler").alive)
	assert_eq(Statuses.stacks_on(fight.unit_by_id("hero"), "wellspring_swell"), 1, "only the archer's kill, from 3.5 hexes")


func test_ally_signatures_near_it_and_mana_past_full() -> void:
	var store: Array = [_aura("deep", {"target": "all_allies", "stat": "mana_store_bp", "value": 20000})]
	var setup: UnitSetup = K.at(_dummy("hero", {"passives": store, "stats": {"hp": 1000, "speed": 0, "range": 3}}), 3, 1)
	_count(setup, "casts", {"text": "x", "counts": "ally_casts", "within_hexes": 3})
	_count(setup, "over", {"text": "x", "counts": "mana_overflow"})
	var caster: Dictionary = {"mana": {"max": 10, "per_attack": 15}, "signature": IDLE, "stats": {"speed": 0, "range": 4}, "basic_attack": {"cooldown_ms": 1000}}
	var far: Dictionary = caster.duplicate(true)
	far["stats"] = {"speed": 0, "range": 6}
	var fight: CombatSim = K.sim(K.fight([setup, K.at(K.kit("near", caster), 2, 1), K.at(K.kit("far", far), 7, 0)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"near": Vector2i(-1000, 0), "far": Vector2i(4000, 0), "mark": Vector2i(0, 3000)})
	K.step(fight, 25)
	var result: FightResult = CombatSim.result_of(fight)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "idle").size(), 2, "both fire once")
	assert_eq(result.tally_amount("hero", "casts"), 1, "only the one within 3 hexes")
	assert_eq(result.tally_amount("hero", "over"), 10, "5 past full on each bar")


func test_mana_given_grows_per_stack() -> void:
	var pour: Dictionary = {"id": "pour", "name": "Pour", "trigger": {"kind": "mana"}, "targeting": "self",
		"effects": [{"type": "gain_mana", "amount": 10, "target": "allies_near_self", "within_hexes": 3, "grows_per_stack": {"status": "wellspring_swell", "bp": 5000}}]}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": pour, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2), K.at(_dummy("ally", {"mana": {"max": 100}, "signature": IDLE}), 2, 2)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	for i: int in 2:
		Statuses.apply(fight, fight.unit_by_id("hero"), "wellspring_swell", 1, 0, _source())
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.MANA_GIVEN, "hero").map(func(entry: LogEntry) -> int: return entry.amount), [2000], "10 mana, +50% for each of 2 stacks")
