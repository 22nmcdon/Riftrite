extends GutTest
## The pieces Aldous's paths added (phase 8 part 4, docs/plans/
## rebuild-phase8-heroes.md section 6), each in a small fight: the target
## lowest_mana_ally, the trigger on_mana_gained with gain_mana by a share of
## it, mana given to another unit (MANA_GIVEN) and the deed count
## mana_given, the conditions ranged and target_beyond_hexes, the aura stat
## shot_speed_bp, and the target enemies_near_allies (a push away from each
## ally).

const K = preload("res://tests/sim/sim_test_kit.gd")
## A signature that never fills, so a unit can carry a mana bar.
const IDLE: Dictionary = {"id": "idle", "name": "Idle", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "heal", "amount": 1, "target": "self"}]}


func _dummy(dummy_id: String, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(extra, true)
	return K.kit(dummy_id, data)


func _place(fight: CombatSim, offsets: Dictionary) -> void:
	var at: Vector2i = fight.unit_by_id("hero").pos
	for unit_id: String in offsets:
		fight.unit_by_id(unit_id).pos = at + (offsets[unit_id] as Vector2i)


func _condition(data: Dictionary) -> UnitCondition:
	var errors: Array[String] = []
	var condition: UnitCondition = UnitCondition.read(DataReader.new(data, "condition", errors))
	assert_eq(errors, [] as Array[String])
	return condition


func _effect(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func test_reading_the_pieces() -> void:
	assert_eq(_effect({"type": "gain_mana", "amount": 15, "target": "lowest_mana_ally", "count": 2}), [] as Array[String])
	assert_eq(_effect({"trigger": "on_mana_gained", "type": "gain_mana", "amount_bp_of_damage": 5000, "target": "allies_near_self", "within_hexes": 3}), [] as Array[String])
	assert_false(_effect({"trigger": "on_basic_attack", "type": "gain_mana", "amount_bp_of_damage": 5000, "target": "self"}).is_empty(), "a basic attack names no gain")
	assert_eq(_effect({"type": "knockback", "hexes": 1, "target": "enemies_near_allies", "within_hexes": 2, "around": {"ranged": true}}), [] as Array[String])
	assert_false(_effect({"type": "knockback", "hexes": 1, "target": "enemies_near_allies"}).is_empty(), "it needs a reach")
	assert_false(_effect({"type": "knockback", "hexes": 1, "target": "enemies_near_self", "within_hexes": 2, "around": {"ranged": true}}).is_empty(), "only enemies_near_allies goes round allies")


func test_the_ally_with_the_least_mana() -> void:
	var bar: Dictionary = {"mana": {"max": 100, "start": 0, "per_attack": 0}, "signature": IDLE}
	var breath: Dictionary = {"id": "breath", "name": "Breath", "trigger": {"kind": "mana"}, "targeting": "self",
		"effects": [{"type": "gain_mana", "amount": 15, "target": "lowest_mana_ally", "count": 2}]}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": breath, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2), K.at(_dummy("full", bar), 1, 2), K.at(_dummy("empty", bar), 2, 2),
		K.at(_dummy("half", bar), 4, 2), K.at(_dummy("barless"), 5, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	fight.unit_by_id("full").mana = 9000
	fight.unit_by_id("half").mana = 5000
	K.step(fight, 2)
	var given: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MANA_GIVEN, "hero")
	assert_eq(given.map(func(entry: LogEntry) -> String: return entry.target), ["empty", "half"], "the two least full, never itself or one with no bar")
	assert_eq(given[0].amount, 1500)
	assert_eq(fight.unit_by_id("empty").mana, 1500)
	assert_string_contains(given[0].to_text(), "gives empty 15 mana")


func test_a_share_of_each_gain_goes_to_the_allies_near() -> void:
	var chorus: Array = [{"id": "chorus", "name": "Chorus", "kind": "ability", "effects": [
		{"trigger": "on_mana_gained", "type": "gain_mana", "amount_bp_of_damage": 5000, "target": "allies_near_self", "within_hexes": 3}]}]
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 1000, "per_attack": 10, "regen_per_s": 2}, "signature": IDLE, "passives": chorus, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 1000}})
	var setup: UnitSetup = K.at(hero, 3, 2)
	var errors: Array[String] = []
	setup.tally_keys.append("given")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "mana_given"}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	# The near ally has the same passive: what it gains from him sets off
	# nothing more.
	var near: UnitDef = _dummy("near", {"mana": {"max": 1000}, "signature": IDLE, "passives": chorus})
	var fight: CombatSim = K.sim(K.fight([setup, K.at(near, 2, 2), K.at(_dummy("far", {"mana": {"max": 1000}, "signature": IDLE}), 7, 0)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"mark": Vector2i(0, 400), "near": Vector2i(-1000, 0), "far": Vector2i(5000, 0)})
	K.step(fight, 50)
	var given: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MANA_GIVEN, "hero")
	assert_eq(given.size(), 2, "one share an attack (regen sets off nothing)")
	assert_eq(given.map(func(entry: LogEntry) -> String: return entry.target), ["near", "near"], "only the ally within 3 hexes")
	assert_eq(given[0].amount, 500, "half of 10")
	assert_eq(K.entries(fight, LogEntry.Kind.MANA_GIVEN, "near").size(), 0, "a share doesn't set off a share")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "given"), 10, "the deed counts whole mana given")


func test_ranged_and_how_far_its_target_stands() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero", {"stats": {"hp": 1000, "speed": 0, "range": 4}}), 3, 2), K.at(_dummy("melee"), 1, 2)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	var ranged: UnitCondition = _condition({"ranged": true})
	assert_true(ranged.holds(hero))
	assert_false(ranged.holds(fight.unit_by_id("melee")))
	assert_true(_condition({"ranged": false}).holds(fight.unit_by_id("melee")))
	var far: UnitCondition = _condition({"target_beyond_hexes": 3})
	hero.target = fight.unit_by_id("mark")
	hero.target.pos = hero.pos + Vector2i(0, 3500)
	assert_true(far.holds(hero), "3.5 hexes away")
	hero.target.pos = hero.pos + Vector2i(0, 2000)
	assert_false(far.holds(hero))
	hero.target = null
	assert_false(far.holds(hero), "no target")
	assert_string_contains(far.describe(), "3 hexes")


func test_faster_shots() -> void:
	var swift: Array = [{"id": "swift", "name": "Swift", "kind": "aura", "aura": {"target": "holder", "stat": "shot_speed_bp", "value": 5000}}]
	var ticks: Array[int] = []
	for passives: Array in [[], swift]:
		var hero: UnitDef = K.kit("hero", {"passives": passives, "stats": {"speed": 0, "range": 6}, "basic_attack": {"cooldown_ms": 1000}})
		var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
		_place(fight, {"mark": Vector2i(0, 6000)})
		K.step(fight, 25)
		var shot: LogEntry = K.entries(fight, LogEntry.Kind.SHOT, "hero")[0]
		ticks.append(shot.end_tick - shot.tick)
	assert_eq(ticks, [6, 4], "6 hexes in 4 ticks, not 6")


func test_a_push_round_each_ranged_ally() -> void:
	var gale: Dictionary = {"id": "gale", "name": "Gale", "trigger": {"kind": "mana"}, "targeting": "self",
		"effects": [{"type": "knockback", "hexes": 1, "target": "enemies_near_allies", "within_hexes": 1, "around": {"ranged": true}}]}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": gale, "stats": {"speed": 0, "range": 3}, "basic_attack": {"cooldown_ms": 60000}})
	var archer: UnitDef = _dummy("archer", {"stats": {"hp": 1000, "speed": 0, "range": 4}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 4, 2), K.at(archer, 2, 2), K.at(_dummy("brawler"), 6, 2)] as Array[UnitSetup],
		[K.foe(_dummy("by_archer"), 2, 4), K.foe(_dummy("by_brawler"), 6, 4), K.foe(_dummy("far"), 4, 6)] as Array[UnitSetup]))
	_place(fight, {"archer": Vector2i(-2000, 0), "by_archer": Vector2i(-2000, 600), "brawler": Vector2i(2000, 0), "by_brawler": Vector2i(2000, 600), "far": Vector2i(0, 4000)})
	var before: Vector2i = fight.unit_by_id("by_archer").pos
	K.step(fight, 2)
	var pushes: Array[LogEntry] = K.entries(fight, LogEntry.Kind.PUSH, "hero")
	assert_eq(pushes.map(func(entry: LogEntry) -> String: return entry.target), ["by_archer"], "round the ranged ally, not the melee one or no one's")
	var archer_at: Vector2i = fight.unit_by_id("archer").pos
	assert_gt(ArenaPlane.length_sq(fight.unit_by_id("by_archer").pos - archer_at), ArenaPlane.length_sq(before - archer_at), "away from the archer")
