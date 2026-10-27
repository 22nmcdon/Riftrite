extends GutTest
## The pieces Garrow's apexes added (phase 8 part 4, docs/plans/
## rebuild-phase8-heroes.md 8d-2c), each in a small fight: power that grows
## per stack of a status (the snowballs), a spend that keeps a share of the
## Shield, a stack per so much damage, damage stored and released
## (RELEASED), the Shield deed past a share of max HP, pulled hexes, and the
## condition "a Shield over a share of max HP".

const K = preload("res://tests/sim/sim_test_kit.gd")


func _hero(extra: Dictionary = {}, attack: Dictionary = {}) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	var kit: Dictionary = {"stats": {"hp": 1000, "atk": 100, "speed": 0, "range": 2}, "basic_attack": basic}
	kit.merge(extra, true)
	return K.kit("hero", kit)


func _dummy(dummy_id: String = "dummy", attack: Dictionary = {}) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	return K.kit(dummy_id, {"stats": {"hp": 100000, "speed": 0, "range": 1}, "basic_attack": basic})


func _place(fight: CombatSim, offsets: Dictionary) -> void:
	var at: Vector2i = fight.unit_by_id("hero").pos
	for unit_id: String in offsets:
		fight.unit_by_id(unit_id).pos = at + (offsets[unit_id] as Vector2i)


func _errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func test_reading_the_pieces() -> void:
	assert_eq(_errors({"type": "shield", "amount": 10, "grows_per_stack": {"status": "bulwark_layer", "bp": 3333}, "target": "self"}), [] as Array[String])
	assert_false(_errors({"type": "pull", "hexes": 1, "grows_per_stack": {"status": "x", "bp": 5}, "target": "target"}).is_empty(), "only damage, heals, and Shields grow")
	assert_eq(_errors({"type": "spend_shield", "keep_bp": 2500, "target": "self"}), [] as Array[String])
	assert_eq(_errors({"type": "release_stored", "target": "self"}), [] as Array[String])
	assert_false(_errors({"type": "release_stored", "target": "target"}).is_empty(), "only its own")
	assert_eq(_errors({"type": "damage", "amount_bp_of_stored": 10000, "target": "target"}), [] as Array[String])
	assert_eq(_errors({"trigger": "on_holder_hit", "type": "apply_status", "status": "thorn_crown", "per_damage": 1000, "target": "self"}), [] as Array[String])
	assert_false(_errors({"trigger": "on_basic_attack", "type": "apply_status", "status": "thorn_crown", "per_damage": 1000, "target": "self"}).is_empty(), "per_damage needs a hit")
	var errors: Array[String] = []
	UnitCondition.read(DataReader.new({"shield_above_pct": 100}, "condition", errors))
	assert_eq(errors, [] as Array[String])


# --- power per stack (the snowballs) -----------------------------------------------------------

func test_power_grows_with_each_stack() -> void:
	var layers: Array = [{"id": "layers", "name": "Layers", "kind": "ability", "effects": [
		{"trigger": "on_basic_attack", "type": "shield", "amount": 100, "grows_per_stack": {"status": "bulwark_layer", "bp": 5000}, "target": "self"},
		{"trigger": "on_basic_attack", "type": "apply_status", "status": "bulwark_layer", "target": "self"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"passives": layers}, {"cooldown_ms": 500}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"dummy": Vector2i(0, 900)})
	K.step(fight, 32)
	var given: Array = K.entries(fight, LogEntry.Kind.SHIELD, "hero").map(func(entry: LogEntry) -> int: return entry.amount)
	assert_eq(given.slice(0, 3), [100, 150, 200], "+50% for each layer laid before it")


# --- a spend that keeps a share (Shatterburst) ---------------------------------------------------

func test_a_spend_can_keep_a_share() -> void:
	var spend: Dictionary = {"id": "spend", "name": "Spend", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "spend_shield", "keep_bp": 2500, "target": "self"}]}
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": spend}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("hero").shield = 400
	K.step(fight, 3)
	var spent: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHIELD_SPENT, "hero")
	assert_eq(spent.map(func(entry: LogEntry) -> int: return entry.amount), [300])
	assert_eq(fight.unit_by_id("hero").shield, 100, "a quarter kept")
	assert_string_contains(spent[0].to_text(), "(keeps 100)")


# --- a stack per so much damage (Thorned King) ---------------------------------------------------

func test_a_stack_for_every_so_much_damage() -> void:
	var crown: Array = [{"id": "crown", "name": "Crown", "kind": "ability", "effects": [
		{"trigger": "on_holder_hit", "type": "apply_status", "status": "thorn_crown", "per_damage": 100, "target": "self"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"passives": crown}, {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 250, "target": "target"}]}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"dummy": Vector2i(0, 900)})
	var hero: UnitState = fight.unit_by_id("hero")
	K.step(fight, 12)
	assert_eq(Statuses.stacks_on(hero, "thorn_crown"), 2, "250 is two hundreds, 50 banked")
	K.step(fight, 10)
	assert_eq(Statuses.stacks_on(hero, "thorn_crown"), 5, "300 more is three")


# --- damage stored and released (Vengeance) -------------------------------------------------------

func test_damage_is_stored_grows_and_is_released() -> void:
	var vengeance: Array = [
		{"id": "store", "name": "Store", "kind": "aura", "aura": {"target": "holder", "stat": "store_bp", "value": 5000}},
		{"id": "grudge", "name": "Grudge", "kind": "aura", "aura": {"target": "holder", "stat": "store_grows_bp", "value": 1000}},
		{"id": "blast", "name": "Blast", "kind": "ability", "effects": [
			{"trigger": "on_interval", "interval_ms": 2000, "once": true, "type": "area", "shape": {"kind": "circle", "radius": 2}, "anchor": "self", "hits": "enemies",
				"effects": [{"type": "damage", "amount_bp_of_stored": 10000, "target": "target"}]},
			{"trigger": "on_interval", "interval_ms": 2000, "once": true, "type": "release_stored", "target": "self"}]}]
	var biter: UnitDef = _dummy("biter", {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 200, "target": "target"}]})
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"passives": vengeance}), 3, 2)] as Array[UnitSetup], [K.foe(biter, 3, 4)] as Array[UnitSetup]))
	_place(fight, {"biter": Vector2i(0, 400)})
	K.step(fight, 12)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "biter")
	assert_eq(hits.size(), 1)
	var hero: UnitState = fight.unit_by_id("hero")
	assert_string_contains(hits[0].note, "stored", "the hit says what it stored")
	var stored: int = hero.stored
	assert_gt(stored, 0)
	assert_eq(hits[0].amount + stored, 200 * 100 / (100 + 0), "half of the hit stored, half taken (no DEF)")
	K.step(fight, 30)
	var released: Array[LogEntry] = K.entries(fight, LogEntry.Kind.RELEASED, "hero")
	assert_eq(released.size(), 1, "let go once")
	assert_gt(released[0].amount, stored * 2, "it grew a tenth a second, and more hits were stored")
	assert_eq(hero.stored, 0)
	var blast: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "blast")
	assert_eq(blast.map(func(entry: LogEntry) -> String: return entry.target), ["biter"])
	assert_eq(blast[0].amount, released[0].amount, "the blast is what was stored")
	assert_string_contains(released[0].to_text(), "releases hero's")


# --- the deed filters ------------------------------------------------------------------------------

func _tallying(unit_def: UnitDef, key: String, data: Dictionary) -> UnitSetup:
	var setup: UnitSetup = K.at(unit_def, 3, 2)
	var errors: Array[String] = []
	var with_text: Dictionary = {"text": "x"}
	with_text.merge(data)
	setup.tally_keys.append(key)
	setup.tally_counts.append(DeedDef.read(DataReader.new(with_text, "count", errors)))
	assert_eq(errors, [] as Array[String])
	return setup


func test_shield_past_a_share_of_max_hp() -> void:
	var plated: Array = [{"id": "plated", "name": "Plated", "kind": "ability",
		"effects": [{"trigger": "on_basic_attack", "type": "shield", "amount": 200, "target": "self"}]}]
	var fight: CombatSim = K.sim(K.fight([_tallying(_hero({"passives": plated}, {"cooldown_ms": 500}), "past", {"counts": "shield", "above_pct_of_max_hp": 50})] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"dummy": Vector2i(0, 900)})
	K.step(fight, 41)
	assert_eq(fight.unit_by_id("hero").shield, 800, "four Shields of 200")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "past"), 300, "only what went past 500 counts")


func test_pulled_hexes() -> void:
	var tug: Dictionary = {"id": "tug", "name": "Tug", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 4, "effects": [{"type": "pull", "hexes": 2, "target": "target"}]}
	var fight: CombatSim = K.sim(K.fight([_tallying(_hero({"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": tug}), "hexes", {"counts": "pulled", "by_hexes": true})] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"dummy": Vector2i(0, 3500)})
	K.step(fight, 10)
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "hexes"), 2, "pulled 2 hexes")


func test_a_shield_over_a_share_of_max_hp() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(), 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	var errors: Array[String] = []
	var over: UnitCondition = UnitCondition.read(DataReader.new({"shield_above_pct": 100}, "condition", errors))
	var hero: UnitState = fight.unit_by_id("hero")
	hero.shield = 1000
	assert_false(over.holds(hero), "a Shield of its max HP isn't over it")
	hero.shield = 1001
	assert_true(over.holds(hero))
	assert_eq(over.describe(), "with a Shield over 100% of max HP")
