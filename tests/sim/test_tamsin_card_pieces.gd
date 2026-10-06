extends GutTest
## The pieces Tamsin's cards and her bond relic added (phase 8 part 4,
## docs/plans/rebuild-phase8-heroes.md 8d-3d), each in a small fight: the aura
## stat evade_bp (Evasive), a pull toward the unit's nearest ally (Drag), the
## conditions targets_holder (Backstab) and target (Stalker), a cleanse on
## on_status keeping its own statuses (Mist Step), and a signature's reach_add
## and grip_fast_vs (Hammer and Wire).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 1000) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _place(fight: CombatSim, offsets: Dictionary) -> void:
	var at: Vector2i = fight.unit_by_id("hero").pos
	for unit_id: String in offsets:
		fight.unit_by_id(unit_id).pos = at + (offsets[unit_id] as Vector2i)


func _condition(data: Dictionary) -> UnitCondition:
	var errors: Array[String] = []
	var condition: UnitCondition = UnitCondition.read(DataReader.new(data, "condition", errors))
	assert_eq(errors, [] as Array[String])
	return condition


func test_evade_misses_basic_attacks_on_its_holder() -> void:
	var evasive: Array = [{"id": "evasive", "name": "Evasive", "kind": "aura", "aura": {"target": "holder", "stat": "evade_bp", "value": 10000}}]
	var hero: UnitDef = K.kit("hero", {"passives": evasive, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	var striker: UnitDef = K.kit("striker", {"stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 10, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(striker, 3, 4)] as Array[UnitSetup]))
	_place(fight, {"striker": Vector2i(0, 400)})
	K.step(fight, 40)
	var dodged: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DODGED, "striker")
	assert_gt(dodged.size(), 2, "every one misses")
	assert_eq(dodged[0].note, "evaded")
	assert_string_contains(dodged[0].to_text(), "(evaded)")
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "striker").size(), 0)
	var plain: CombatSim = K.sim(K.fight([K.at(K.kit("hero", {"stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}}), 3, 2)] as Array[UnitSetup],
		[K.foe(striker, 3, 4)] as Array[UnitSetup]))
	_place(plain, {"striker": Vector2i(0, 400)})
	K.step(plain, 40)
	assert_eq(K.entries(plain, LogEntry.Kind.DODGED, "striker").size(), 0, "without it, none do")


func test_a_pull_toward_the_nearest_ally() -> void:
	var drag: Dictionary = {"id": "drag", "name": "Drag", "trigger": {"kind": "mana"}, "targeting": "nearest",
		"effects": [{"type": "pull", "hexes": 1, "toward": "ally", "target": "target"}]}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": drag, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2), K.at(_dummy("friend"), 1, 2), K.at(_dummy("far_friend"), 6, 0)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"mark": Vector2i(0, 400), "friend": Vector2i(-2000, 400), "far_friend": Vector2i(5000, 400)})
	var friend: Vector2i = fight.unit_by_id("friend").pos
	var before: int = ArenaPlane.length_sq(fight.unit_by_id("mark").pos - friend)
	K.step(fight, 4)
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH, "hero").size(), 1)
	assert_lt(ArenaPlane.length_sq(fight.unit_by_id("mark").pos - friend), before, "toward the ally nearest the puller")
	var errors: Array[String] = []
	EffectDef.read(DataReader.new({"type": "knockback", "hexes": 1, "toward": "ally", "target": "target"}, "effect", errors))
	assert_false(errors.is_empty(), "a knockback never goes toward an ally")


func test_whom_a_unit_targets() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_dummy("hero"), 3, 2), K.at(_dummy("friend"), 1, 2)] as Array[UnitSetup],
		[K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	var mark: UnitState = fight.unit_by_id("mark")
	var away: UnitCondition = _condition({"targets_holder": false})
	mark.target = fight.unit_by_id("friend")
	assert_true(away.holds(mark, hero), "Backstab: it's after someone else")
	mark.target = hero
	assert_false(away.holds(mark, hero))
	assert_true(_condition({"targets_holder": true}).holds(mark, hero))
	var stalker: UnitCondition = _condition({"target": {"keywords": ["marked"]}})
	hero.target = mark
	assert_false(stalker.holds(hero, hero))
	Statuses.apply(fight, mark, "marked", 1, 0, EffectSource.make("friend", "test", "Test"))
	assert_true(stalker.holds(hero, hero), "Stalker: her target is Marked")
	assert_string_contains(stalker.describe(), "Marked")


func test_a_cleanse_on_on_status_keeps_its_own_statuses() -> void:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new({"trigger": "on_status", "keywords": ["stealthed"], "type": "cleanse", "count": 2,
		"statuses": ["slow", "root"], "target": "self"}, "effect", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq(effect.statuses, [] as Array[String], "it fires on any Stealth it applies")
	assert_eq(effect.cleanse_statuses, ["slow", "root"] as Array[String])
	var mist: Array = [{"id": "mist", "name": "Mist", "kind": "ability", "effects": [
		{"trigger": "on_status", "keywords": ["stealthed"], "type": "cleanse", "count": 2, "statuses": ["slow", "root"], "target": "self"}]}]
	var hide: Dictionary = {"id": "hide", "name": "Hide", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "apply_status", "status": "hidden", "target": "self"}]}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 0, "per_attack": 0, "regen_per_s": 20}, "signature": hide, "passives": mist,
		"stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 5)] as Array[UnitSetup]))
	var hero_state: UnitState = fight.unit_by_id("hero")
	var source: EffectSource = EffectSource.make("mark", "test", "Test")
	Statuses.apply(fight, hero_state, "slow", 1, 400, source)
	Statuses.apply(fight, hero_state, "root", 1, 400, source)
	assert_not_null(Statuses.find(hero_state, "root"))
	K.step(fight, 14)
	assert_true(Statuses.is_stealthed(hero_state))
	assert_null(Statuses.find(hero_state, "root"), "hiding shook off the Root")
	assert_null(Statuses.find(hero_state, "slow"), "and the Slow")


func test_a_grip_reaches_further_and_lands_faster_on_the_stunned() -> void:
	var garrote: Dictionary = {"id": "garrote", "name": "Garrote", "trigger": {"kind": "mana"}, "targeting": "nearest", "shot": false,
		"effects": [{"type": "apply_status", "status": "root", "duration_ms": 2000, "target": "target"}],
		"grip": {"status": "root", "every_ms": 500, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": garrote, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 60000}})
	var errors: Array[String] = []
	var wire: KitMod = KitMod.read(DataReader.new({"on": [{"slot": "abilities", "ability": "garrote", "prefer": {"statuses": ["stun"]}, "reach_add": 3,
		"add_effects": [{"type": "leap", "to": "behind", "max_hexes": 4, "target": "target"}], "grip_fast_vs": {"statuses": ["stun"]}}]}, "mod", errors))
	assert_eq(errors, [] as Array[String])
	var refused: Array[String] = []
	KitMod.read(DataReader.new({"on": [{"slot": "basic_attack", "reach_add": 1}]}, "mod", refused))
	assert_false(refused.is_empty(), "reach_add changes a signature")
	var problems: Array[String] = []
	var wired: UnitDef = wire.apply(hero, problems)
	assert_eq(problems, [] as Array[String])
	assert_eq(wired.signature.max_range, 4, "from 1 hex to 4")
	assert_not_null(wired.signature.grip_fast_vs)
	assert_true(wire.affects(hero))
	assert_false(wire.affects(K.kit("other", {})), "nothing on a kit without Garrote")
	var fight: CombatSim = K.sim(K.fight([K.at(wired, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("near"), 3, 4), K.foe(_dummy("dazed"), 4, 5)] as Array[UnitSetup]))
	_place(fight, {"near": Vector2i(0, 600), "dazed": Vector2i(1500, 3000)})
	Statuses.apply(fight, fight.unit_by_id("dazed"), "stun", 1, 400, EffectSource.make("near", "test", "Test"))
	K.step(fight, 22)
	var hero_state: UnitState = fight.unit_by_id("hero")
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "hero")[0].target, "dazed", "the Stunned one, past the nearer")
	assert_eq(K.entries(fight, LogEntry.Kind.LEAP, "hero").size(), 1, "she steps behind it")
	assert_eq(hero_state.grip_target.id, "dazed")
	var ticks: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> int: return entry.tick)
	assert_gt(ticks.size(), 1)
	assert_eq(ticks[1] - ticks[0], 5, "every 250ms while it's Stunned, not 500ms")
