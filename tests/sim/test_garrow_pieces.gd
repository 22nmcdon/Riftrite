extends GutTest
## Garrow's paths' pieces (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md
## section 4), each in a small fight: a Shield with a cap, damage worked out
## from the unit's own Shield and the Shield spent (SHIELD_SPENT), a
## signature that readies the basic attack, an aura per enemy near, and the
## enemies farthest from it (Haul's habit, section 3b).

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


# --- the enemies farthest from it (Haul's habit) ------------------------------------------------

func test_the_farthest_enemies_within_reach() -> void:
	assert_eq(_effect_errors({"trigger": "on_basic_attack", "every": 6, "type": "pull", "to": "beside", "target": "farthest_enemies", "count": 3, "within_hexes": 4}), [] as Array[String])
	assert_false(_effect_errors({"type": "pull", "to": "beside", "target": "farthest_enemies", "within_hexes": 4}).is_empty(), "it needs a count")
	var haul: Array = [{"id": "haul", "name": "Haul", "kind": "ability",
		"effects": [{"trigger": "on_basic_attack", "type": "damage", "amount": 1, "target": "farthest_enemies", "count": 2, "within_hexes": 4}]}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"passives": haul}, {"cooldown_ms": 500}), 3, 1)] as Array[UnitSetup],
		[K.foe(_dummy("near"), 3, 4), K.foe(_dummy("mid"), 4, 4), K.foe(_dummy("far"), 3, 5), K.foe(_dummy("beyond"), 3, 6)] as Array[UnitSetup]))
	_place(fight, {"near": Vector2i(0, 1500), "mid": Vector2i(1000, 2500), "far": Vector2i(0, 3900), "beyond": Vector2i(0, 4500)})
	K.step(fight, 12)
	var hits: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "haul") \
		.map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(hits.slice(0, 2), ["far", "mid"], "the two farthest within 4 hexes, farthest first; not the one beyond")



# --- the cards' pieces (8d-2d) -----------------------------------------------------------------

## A hero whose mana signature hooks the farthest enemy within 4 hexes beside
## it (Haul's shape), with `passives`, tallying the enemies it pulls.
func _hauler(passives: Array) -> UnitSetup:
	var haul: Dictionary = {"id": "haul", "name": "Haul", "trigger": {"kind": "mana"}, "targeting": "farthest", "max_range": 4,
		"effects": [{"type": "pull", "to": "beside", "target": "target"}]}
	var setup: UnitSetup = K.at(_hero({"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": haul, "passives": passives}), 3, 1)
	setup.tally_keys.append("pulled")
	var errors: Array[String] = []
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "pulled"}, "count", errors)))
	return setup


func test_a_pull_is_an_event_and_a_count() -> void:
	assert_eq(_effect_errors({"trigger": "on_pull", "from_ability": ["haul"], "type": "apply_status", "status": "stun", "duration_ms": 500, "target": "hit_target"}),
		[] as Array[String])
	var landing: Array = [{"id": "landing", "name": "Landing", "kind": "ability",
		"effects": [{"trigger": "on_pull", "from_ability": ["haul"], "type": "apply_status", "status": "stun", "duration_ms": 500, "target": "hit_target"}]}]
	var fight: CombatSim = K.sim(K.fight([_hauler(landing)] as Array[UnitSetup], [K.foe(_dummy("far"), 3, 5)] as Array[UnitSetup]))
	_place(fight, {"far": Vector2i(0, 3000)})
	K.step(fight, 8)
	var pulls: Array[LogEntry] = K.entries(fight, LogEntry.Kind.PUSH, "hero")
	assert_eq(pulls.size(), 1)
	var stuns: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "landing")
	assert_eq(stuns.map(func(entry: LogEntry) -> String: return "%s %s %d" % [entry.target, entry.status, entry.end_tick - entry.tick]), ["far stun 10"],
		"the enemy it hooked lands Stunned for 0.5s")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "pulled"), 1, "and it counts as pulled")


func test_a_pull_that_moves_nothing_raises_nothing() -> void:
	var landing: Array = [{"id": "landing", "name": "Landing", "kind": "ability",
		"effects": [{"trigger": "on_pull", "type": "apply_status", "status": "stun", "target": "hit_target"}]}]
	var heavy: UnitDef = K.kit("heavy", {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"passives": [{"id": "heavy", "name": "Heavy", "kind": "aura", "aura": {"target": "holder", "stat": "unpushable", "value": 1}}]})
	var fight: CombatSim = K.sim(K.fight([_hauler(landing)] as Array[UnitSetup], [K.foe(heavy, 3, 5)] as Array[UnitSetup]))
	_place(fight, {"heavy": Vector2i(0, 3000)})
	K.step(fight, 8)
	assert_eq(K.entries(fight, LogEntry.Kind.RESISTED, "hero").size(), 1, "it can't be moved")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").size(), 0)
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "pulled"), 0)


func test_damage_that_ignores_def() -> void:
	var armored: UnitDef = K.kit("armored", {"stats": {"hp": 100000, "def": 100, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var hits: Array[int] = []
	for pierces: bool in [false, true]:
		var fight: CombatSim = K.sim(K.fight([K.at(_hero({}, {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 100, "ignores_def": pierces, "target": "target"}]}), 3, 2)] as Array[UnitSetup],
			[K.foe(armored, 3, 4)] as Array[UnitSetup]))
		_place(fight, {"armored": Vector2i(0, 900)})
		K.step(fight, 12)
		hits.append(K.entries(fight, LogEntry.Kind.DAMAGE, "hero")[0].amount)
	assert_lt(hits[0], 100, "DEF takes its share")
	assert_eq(hits[1], 100, "not from a hit that ignores it")


func test_iron_will_shortens_stuns() -> void:
	var stunner: Dictionary = {"cooldown_ms": 500, "effects": [{"type": "apply_status", "status": "stun", "duration_ms": 1000, "target": "target"}]}
	var lengths: Array[int] = []
	for passives: Array in [[], [{"id": "will", "name": "Will", "kind": "aura", "aura": {"target": "holder", "stat": "stun_time_bp", "value": -5000}}]]:
		var target: UnitDef = K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 1}, "passives": passives,
			"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
		var fight: CombatSim = K.sim(K.fight([K.at(_hero({}, stunner), 3, 2)] as Array[UnitSetup], [K.foe(target, 3, 4)] as Array[UnitSetup]))
		_place(fight, {"dummy": Vector2i(0, 900)})
		K.step(fight, 12)
		var stun: LogEntry = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero")[0]
		lengths.append(stun.end_tick - stun.tick)
	assert_eq(lengths, [20, 10] as Array[int], "half as long")


func test_some_enemies_near_count_twice() -> void:
	var crowd: Array = [{"id": "crowd", "name": "Crowd", "kind": "aura",
		"aura": {"target": "holder", "stat": "def", "value": 2, "per": "enemy_near", "per_within_hexes": 1, "per_twice": {"statuses": ["bleed"]}}}]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"passives": crowd}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("a"), 3, 4), K.foe(_dummy("b"), 4, 4)] as Array[UnitSetup]))
	_place(fight, {"a": Vector2i(0, 900), "b": Vector2i(800, 0)})
	fight.step()
	var hero: UnitState = fight.unit_by_id("hero")
	assert_eq(hero.stats.get_stat(UnitStats.Stat.DEF), 4, "two enemies near")
	Statuses.apply(fight, fight.unit_by_id("a"), "bleed", 1, 0, EffectSource.make("hero", "test", "Test"))
	fight.step()
	assert_eq(hero.stats.get_stat(UnitStats.Stat.DEF), 6, "a Bleeding one counts twice")
	var errors: Array[String] = []
	AuraDef.read(DataReader.new({"target": "holder", "stat": "def", "value": 2, "per_twice": {"statuses": ["bleed"]}}, "aura", errors))
	assert_false(errors.is_empty(), "per_twice needs \"per\": \"enemy_near\"")


func test_spending_a_shield_is_an_event() -> void:
	var woven: Array = [{"id": "woven", "name": "Woven", "kind": "ability",
		"effects": [{"trigger": "on_shield_spent", "type": "shield", "amount_bp_of_damage": 3000, "target": "self"}]}]
	var spend: Dictionary = {"id": "spend", "name": "Spend", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "spend_shield", "target": "self"}]}
	var fight: CombatSim = K.sim(K.fight([K.at(_hero({"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": spend, "passives": woven}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	fight.unit_by_id("hero").shield = 400
	K.step(fight, 3)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD, "hero").map(func(entry: LogEntry) -> String: return "%s %d" % [entry.source_ability, entry.amount]), ["woven 120"],
		"30% of the 400 it spent comes back")
	assert_eq(fight.unit_by_id("hero").shield, 120)


func test_a_pulled_enemy_can_land_on_a_snare() -> void:
	var relics: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/relics.json"))
	var chain: Dictionary = relics.filter(func(relic: Dictionary) -> bool: return relic["id"] == "the_snaring_chain")[0]["mod"]["passives"][0]
	var fight: CombatSim = K.sim(K.fight([_hauler([chain])] as Array[UnitSetup], [K.foe(_dummy("far"), 3, 5)] as Array[UnitSetup]))
	_place(fight, {"far": Vector2i(0, 3000)})
	K.step(fight, 12)
	var snares: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SNARE, "hero")
	assert_eq(snares.map(func(entry: LogEntry) -> String: return entry.note), ["set", "sprung"], "a snare where it landed, sprung at once")
	var roots: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").filter(func(entry: LogEntry) -> bool: return entry.status == "root")
	assert_eq(roots.map(func(entry: LogEntry) -> String: return entry.target), ["far"], "and it Roots the enemy")
