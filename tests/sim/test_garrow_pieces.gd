extends GutTest
## Garrow's paths' pieces (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md
## section 4), each in a small fight: a Shield with a cap, damage worked out
## from the unit's own Shield and the Shield spent (SHIELD_SPENT), a
## signature that readies the basic attack, and an aura per enemy near.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A hero that never walks, with a slow basic attack unless `attack` says.
func _hero(extra: Dictionary = {}, attack: Dictionary = {}) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	var kit: Dictionary = {"stats": {"hp": 1000, "atk": 100, "speed": 0, "range": 2}, "basic_attack": basic}
	kit.merge(extra, true)
	return K.kit("hero", kit)


func _dummy(dummy_id: String = "dummy") -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## Puts each unit `offsets` names at that offset from the hero (enemies
## start in their own rows; the tests move them where they need them).
func _place(fight: CombatSim, offsets: Dictionary) -> void:
	var at: Vector2i = fight.unit_by_id("hero").pos
	for unit_id: String in offsets:
		fight.unit_by_id(unit_id).pos = at + (offsets[unit_id] as Vector2i)


func _effect_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new(data, "effect", errors))
	return errors


func test_reading_the_pieces() -> void:
	assert_eq(_effect_errors({"type": "shield", "amount_bp_of_max_hp": 300, "cap_bp_of_max_hp": 5000, "target": "self"}), [] as Array[String])
	assert_eq(_effect_errors({"type": "damage", "amount_bp_of_shield": 15000, "target": "target"}), [] as Array[String])
	assert_false(_effect_errors({"type": "damage", "amount": 5, "amount_bp_of_shield": 15000, "target": "target"}).is_empty(), "one amount")
	assert_eq(_effect_errors({"type": "spend_shield", "target": "self"}), [] as Array[String])
	assert_false(_effect_errors({"type": "spend_shield", "target": "target"}).is_empty(), "only its own Shield")
	var errors: Array[String] = []
	AuraDef.read(DataReader.new({"target": "holder", "stat": "atk_bp", "value": 10500, "per": "enemy_near", "per_within_hexes": 1}, "aura", errors))
	assert_eq(errors, [] as Array[String])
	AuraDef.read(DataReader.new({"target": "holder", "stat": "atk_bp", "value": 10500, "per_within_hexes": 1}, "aura", errors))
	assert_false(errors.is_empty(), "a reach needs \"per\": \"enemy_near\"")


# --- a Shield with a cap (Plated Blows) -----------------------------------------------------

func test_a_shield_stops_at_its_cap() -> void:
	var plated: Array = [{"id": "plated", "name": "Plated", "kind": "ability",
		"effects": [{"trigger": "on_basic_attack", "type": "shield", "amount_bp_of_max_hp": 3000, "cap_bp_of_max_hp": 5000, "target": "self"}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"passives": plated}, {"cooldown_ms": 500}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 60)
	var given: Array = K.entries(fight, LogEntry.Kind.SHIELD, "hero").map(func(entry: LogEntry) -> int: return entry.amount)
	assert_eq(given, [300, 200], "30% of max HP, then what fills it to 50%, then nothing")
	assert_eq(fight.unit_by_id("hero").shield, 500)


# --- damage from its Shield, and the Shield spent (Bulwark Burst) --------------------------------

func test_a_burst_deals_its_shield_and_spends_it() -> void:
	var burst: Dictionary = {"id": "burst", "name": "Burst", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [
		{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "enemies",
			"effects": [{"type": "damage", "amount_bp_of_shield": 15000, "target": "target"}]},
		{"type": "spend_shield", "target": "self"}]}
	var hero: UnitDef = _hero({"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": burst})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("near"), 3, 4), K.foe(_dummy("far"), 3, 5)] as Array[UnitSetup]))
	_place(fight, {"near": Vector2i(0, 900), "far": Vector2i(0, 2500)})
	fight.unit_by_id("hero").shield = 400
	K.step(fight, 10)
	var hits: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> String: return "%s %d" % [entry.target, entry.amount])
	assert_eq(hits, ["near 600"], "150% of the Shield, on the enemies within 1 hex")
	var spent: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHIELD_SPENT, "hero")
	assert_eq(spent.map(func(entry: LogEntry) -> String: return "%s %d %s" % [entry.target, entry.amount, entry.source_ability]), ["hero 400 burst"])
	assert_eq(fight.unit_by_id("hero").shield, 0, "spent")
	assert_string_contains(spent[0].to_text(), "spends hero's 400 shield")


# --- a signature that readies the basic attack (Maelstrom) --------------------------------------

func test_a_signature_can_ready_the_basic_attack() -> void:
	var ready: Dictionary = {"id": "ready", "name": "Ready", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 2, "resets_attack": true,
		"effects": [{"type": "damage", "amount": 1, "target": "target"}]}
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": ready}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 5)
	var fires: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE, "hero")
	assert_eq(fires.map(func(entry: LogEntry) -> String: return entry.source_ability), ["ready", "hero_attack"], "a 60s attack fires at once after it")
	assert_string_contains(fires[0].to_text(), "fires and readies its attack")


# --- an aura per enemy near (Crowd Strength) --------------------------------------------------

func test_an_aura_counts_the_enemies_near() -> void:
	var crowd: Array = [
		{"id": "crowd", "name": "Crowd", "kind": "aura", "aura": {"target": "holder", "stat": "atk_bp", "value": 10500, "per": "enemy_near", "per_within_hexes": 1}},
		{"id": "crowd_def", "name": "Crowd", "kind": "aura", "aura": {"target": "holder", "stat": "def", "value": 2, "per": "enemy_near", "per_within_hexes": 1}}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"passives": crowd}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("a"), 3, 4), K.foe(_dummy("b"), 4, 4), K.foe(_dummy("c"), 3, 6)] as Array[UnitSetup]))
	_place(fight, {"a": Vector2i(0, 900), "b": Vector2i(800, 0), "c": Vector2i(0, 3000)})
	fight.step()
	var hero: UnitState = fight.unit_by_id("hero")
	assert_eq([hero.stats.get_stat(UnitStats.Stat.ATK), hero.stats.get_stat(UnitStats.Stat.DEF)], [110, 4], "+5% ATK and +2 DEF for each of the two within 1 hex")
	fight.unit_by_id("b").pos = fight.unit_by_id("c").pos + Vector2i(0, 1000)
	fight.step()
	assert_eq([hero.stats.get_stat(UnitStats.Stat.ATK), hero.stats.get_stat(UnitStats.Stat.DEF)], [105, 2], "one left near")
	fight.unit_by_id("a").pos = fight.unit_by_id("c").pos + Vector2i(1000, 0)
	fight.step()
	assert_eq([hero.stats.get_stat(UnitStats.Stat.ATK), hero.stats.get_stat(UnitStats.Stat.DEF)], [100, 0], "off with none near")
