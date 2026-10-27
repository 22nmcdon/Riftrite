extends GutTest
## The pieces Tamsin's kit and paths added (phase 8 part 4, docs/plans/
## rebuild-phase8-heroes.md section 5), each in a small fight: the targeting
## rule weakest_within, a preference with a reach, a leap behind the target,
## a passive's step (with only and an attack reset), a Stealth that ends on
## its holder's basic attack (and one that spares some), extending several
## statuses and the extended_ms count, a signature that fires again when it
## kills, and a signature's grip.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _dummy(dummy_id: String, hp: int = 1000) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## Puts each unit at the hero's spot plus its offset (plane units).
func _place(fight: CombatSim, offsets: Dictionary) -> void:
	var at: Vector2i = fight.unit_by_id("hero").pos
	for unit_id: String in offsets:
		fight.unit_by_id(unit_id).pos = at + (offsets[unit_id] as Vector2i)


func _errors(data: Dictionary, what: String = "effect") -> Array[String]:
	var errors: Array[String] = []
	match what:
		"effect":
			EffectDef.read(DataReader.new(data, "effect", errors))
		"kit":
			UnitDef.read(DataReader.new(data, "kit", errors))
		"signature":
			AbilityDef.read_signature(DataReader.new(data, "signature", errors))
		"status":
			StatusDef.read(DataReader.new(data, "status", errors))
	return errors


func test_reading_the_pieces() -> void:
	var kit: Dictionary = {"id": "k", "name": "K", "stats": {"hp": 10, "atk": 1, "speed": 1, "range": 1},
		"basic_attack": {"id": "a", "name": "A", "cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}}
	var weakest: Dictionary = kit.duplicate()
	weakest["targeting"] = "weakest_within"
	assert_false(_errors(weakest, "kit").is_empty(), "weakest_within needs its reach")
	weakest["targeting_within_hexes"] = 3
	assert_eq(_errors(weakest, "kit"), [] as Array[String])
	assert_eq(_errors({"type": "leap", "to": "behind", "max_hexes": 3, "target": "target"}), [] as Array[String])
	assert_eq(_errors({"trigger": "on_kill", "type": "leap", "to": "step", "resets_attack": true, "target": "enemy_near_named", "within_hexes": 4, "only": {"keywords": ["marked"]}}), [] as Array[String])
	assert_false(_errors({"trigger": "on_kill", "type": "leap", "to": "step", "target": "enemies_near_named", "within_hexes": 4}).is_empty(), "a step goes to one enemy")
	assert_eq(_errors({"trigger": "on_crit", "type": "extend_status", "statuses": ["root", "stun"], "duration_ms": 300, "target": "hit_target"}), [] as Array[String])
	assert_false(_errors({"trigger": "on_crit", "type": "extend_status", "status": "root", "statuses": ["stun"], "duration_ms": 300, "target": "hit_target"}).is_empty())
	assert_eq(_errors({"id": "veil", "name": "Veil", "kind": "stealth", "until_attack": true, "spares_attacks": 3, "duration_ms": 3000}, "status"), [] as Array[String])
	var grip: Dictionary = {"id": "g", "name": "G", "trigger": {"kind": "mana"}, "again_on_kill": true,
		"effects": [{"type": "apply_status", "status": "root", "target": "target"}],
		"grip": {"status": "root", "every_ms": 500, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}}
	assert_eq(_errors(grip, "signature"), [] as Array[String])
	grip["grip"] = {"status": "root", "every_ms": 500, "effects": [{"type": "knockback", "hexes": 1, "target": "target"}]}
	assert_false(_errors(grip, "signature").is_empty(), "a grip's effects land on its target")


# --- weakest_within and a preference's reach ------------------------------------------------------

func test_the_weakest_in_reach_else_the_nearest() -> void:
	var hero: UnitDef = K.kit("hero", {"targeting": "weakest_within", "targeting_within_hexes": 3, "stats": {"speed": 0}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("near"), 3, 4), K.foe(_dummy("hurt"), 4, 4), K.foe(_dummy("far"), 5, 5)] as Array[UnitSetup]))
	_place(fight, {"near": Vector2i(0, 1000), "hurt": Vector2i(1500, 1000), "far": Vector2i(0, 3500)})
	fight.unit_by_id("hurt").hp = 500
	fight.unit_by_id("far").hp = 100
	K.step(fight, 3)
	assert_eq(fight.unit_by_id("hero").target.id, "hurt", "the lowest share within 3 hexes, not the weaker one beyond")
	var alone: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("far"), 5, 5)] as Array[UnitSetup]))
	_place(alone, {"far": Vector2i(0, 3500)})
	K.step(alone, 3)
	assert_eq(alone.unit_by_id("hero").target.id, "far", "none in reach: the nearest")


func test_a_preference_with_a_reach() -> void:
	var errors: Array[String] = []
	var patch: KitPatch = KitPatch.read(DataReader.new({"prefer": {"label": "Scent", "vs": {"keywords": ["marked"]}, "within_hexes": 2}}, "patch", errors))
	assert_eq(errors, [] as Array[String])
	var hero: UnitDef = patch.apply(K.kit("hero", {"stats": {"speed": 0}}))
	assert_eq(hero.prefer_reach, 2 * HexGrid.HEX)
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("near"), 3, 4), K.foe(_dummy("marked_far"), 5, 5), K.foe(_dummy("marked"), 4, 4)] as Array[UnitSetup]))
	_place(fight, {"near": Vector2i(0, 1000), "marked_far": Vector2i(0, 4000), "marked": Vector2i(1500, 1000)})
	var source: EffectSource = EffectSource.make("near", "test", "Test")
	Statuses.apply(fight, fight.unit_by_id("marked_far"), "marked", 1, 0, source)
	K.step(fight, 3)
	assert_eq(fight.unit_by_id("hero").target.id, "near", "the only Marked one is beyond 2 hexes")
	fight.unit_by_id("hero").target = null
	Statuses.apply(fight, fight.unit_by_id("marked"), "marked", 1, 0, source)
	K.step(fight, 3)
	assert_eq(fight.unit_by_id("hero").target.id, "marked", "a Marked one within 2 hexes comes first")


# --- the leaps -------------------------------------------------------------------------------------

func test_a_leap_behind_lands_past_the_target() -> void:
	var step: Dictionary = {"id": "slip", "name": "Slip", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 3,
		"effects": [{"type": "leap", "to": "behind", "max_hexes": 3, "target": "target"}]}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": step, "stats": {"speed": 0}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"mark": Vector2i(0, 1500)})
	var start: Vector2i = fight.unit_by_id("hero").pos
	K.step(fight, 2)
	var leaps: Array[LogEntry] = K.entries(fight, LogEntry.Kind.LEAP, "hero")
	assert_eq(leaps.size(), 1)
	var landed: Vector2i = fight.unit_by_id("hero").pos
	var mark: Vector2i = fight.unit_by_id("mark").pos
	assert_gt(landed.y, mark.y, "on the far side of it")
	assert_gt(ArenaPlane.length_sq(landed - start), ArenaPlane.length_sq(mark - start), "past it, not short of it")
	assert_string_contains(leaps[0].to_text(), "behind")
	assert_eq(fight.unit_by_id("hero").target.id, "mark", "and it's her target")


func test_a_step_to_the_next_marked_enemy_readies_the_attack() -> void:
	var scent: Array = [{"id": "scent", "name": "Scent", "kind": "ability", "effects": [
		{"trigger": "on_kill", "type": "leap", "to": "step", "resets_attack": true, "target": "enemy_near_named", "within_hexes": 4, "only": {"keywords": ["marked"]}}]}]
	var hero: UnitDef = K.kit("hero", {"passives": scent, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 2000, "effects": [{"type": "damage", "amount": 50, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("prey", 10), 3, 4), K.foe(_dummy("plain"), 4, 4), K.foe(_dummy("marked"), 5, 5)] as Array[UnitSetup]))
	_place(fight, {"prey": Vector2i(0, 400), "plain": Vector2i(800, 800), "marked": Vector2i(0, 3000)})
	Statuses.apply(fight, fight.unit_by_id("marked"), "marked", 1, 0, EffectSource.make("plain", "test", "Test"))
	fight.unit_by_id("hero").target = fight.unit_by_id("prey")
	K.step(fight, 56)
	var steps: Array[LogEntry] = K.entries(fight, LogEntry.Kind.LEAP, "hero")
	assert_eq(steps.map(func(entry: LogEntry) -> String: return entry.target), ["marked"], "past the plain one, to the Marked one")
	assert_string_contains(steps[0].to_text(), "steps")
	var hero_state: UnitState = fight.unit_by_id("hero")
	assert_eq(hero_state.target.id, "marked")
	assert_lte(ArenaPlane.length_sq(hero_state.pos - fight.unit_by_id("marked").pos), 300 * 300, "beside it")
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").filter(func(entry: LogEntry) -> bool: return entry.target == "marked")
	assert_gt(hits.size(), 0, "its attack was ready as it landed")
	assert_lte(hits[0].tick - steps[0].tick, fight.tuning.leap_land_ticks + 1, "as soon as it landed, not a cooldown later")


# --- Stealth that ends on attack --------------------------------------------------------------------

func test_hidden_ends_on_a_basic_attack_but_not_a_signature() -> void:
	var cheer: Dictionary = {"id": "cheer", "name": "Cheer", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "heal", "amount": 1, "target": "self"}]}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": cheer, "stats": {"speed": 0}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"mark": Vector2i(0, 400)})
	var hero_state: UnitState = fight.unit_by_id("hero")
	Statuses.apply(fight, hero_state, "hidden", 1, 400, EffectSource.make("hero", "test", "Test"))
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "cheer").size(), 1)
	assert_true(Statuses.is_stealthed(hero_state), "the signature didn't end it")
	K.step(fight, 18)
	assert_false(Statuses.is_stealthed(hero_state), "the basic attack did")
	var ended: Array = K.entries(fight, LogEntry.Kind.STATUS_ENDED).filter(func(entry: LogEntry) -> bool: return entry.status == "hidden")
	assert_eq(ended.map(func(entry: LogEntry) -> String: return entry.note), ["it attacked"])


func test_a_stealth_can_spare_some_attacks() -> void:
	var hero: UnitDef = K.kit("hero", {"stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 500}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"mark": Vector2i(0, 400)})
	fight.content.statuses["hidden"].spares_attacks = 2
	var hero_state: UnitState = fight.unit_by_id("hero")
	Statuses.apply(fight, hero_state, "hidden", 1, 400, EffectSource.make("hero", "test", "Test"))
	K.step(fight, 32)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "hero").size(), 3)
	assert_false(Statuses.is_stealthed(hero_state), "the third attack ended it")
	var ended: Array = K.entries(fight, LogEntry.Kind.STATUS_ENDED).filter(func(entry: LogEntry) -> bool: return entry.status == "hidden")
	assert_eq(ended.size(), 1)
	assert_eq(ended[0].tick, K.entries(fight, LogEntry.Kind.FIRE, "hero")[2].tick, "with the third")


# --- extending several statuses, and its count ----------------------------------------------------

func test_extending_any_of_several_and_counting_it() -> void:
	var choke: Array = [{"id": "choke", "name": "Choke", "kind": "ability", "effects": [
		{"trigger": "on_holder_hit", "type": "extend_status", "statuses": ["root", "stun"], "duration_ms": 500, "target": "hit_target"}]}]
	var setup: UnitSetup = K.at(K.kit("hero", {"passives": choke, "stats": {"speed": 0}, "basic_attack": {"cooldown_ms": 500}}), 3, 2)
	var errors: Array[String] = []
	setup.tally_keys.append("held")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "extended_ms", "from_ability": ["choke"]}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4)] as Array[UnitSetup]))
	_place(fight, {"mark": Vector2i(0, 400)})
	var source: EffectSource = EffectSource.make("hero", "test", "Test")
	Statuses.apply(fight, fight.unit_by_id("mark"), "root", 1, 100, source)
	K.step(fight, 11)
	var extended: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_EXTENDED, "hero")
	assert_eq(extended.map(func(entry: LogEntry) -> String: return entry.status), ["root"], "only what it has")
	Statuses.apply(fight, fight.unit_by_id("mark"), "stun", 1, 100, source)
	K.step(fight, 10)
	extended = K.entries(fight, LogEntry.Kind.STATUS_EXTENDED, "hero")
	assert_eq(extended.map(func(entry: LogEntry) -> String: return entry.status), ["root", "root", "stun"], "both")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "held"), 1500, "three half-seconds")


# --- again on a kill ---------------------------------------------------------------------------------

func test_a_signature_that_kills_fires_once_more() -> void:
	var sentence: Dictionary = {"id": "sentence", "name": "Sentence", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 3, "shot": false, "again_on_kill": true,
		"effects": [{"type": "damage", "amount": 100, "target": "target"}]}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": sentence, "stats": {"speed": 0}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy("first", 50), 3, 4), K.foe(_dummy("second", 50), 4, 4), K.foe(_dummy("third", 50), 2, 4)] as Array[UnitSetup]))
	_place(fight, {"first": Vector2i(0, 400), "second": Vector2i(800, 800), "third": Vector2i(-800, 1600)})
	K.step(fight, 6)
	var fires: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FIRE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "sentence")
	assert_eq(fires.map(func(entry: LogEntry) -> String: return entry.target), ["first", "second"], "once more, but not a third time")
	assert_string_contains(fires[1].to_text(), "again: it killed")
	assert_true(fight.unit_by_id("third").alive)


# --- the grip ------------------------------------------------------------------------------------------

func test_a_grip_holds_its_target_and_lands_until_it_ends() -> void:
	var garrote: Dictionary = {"id": "garrote", "name": "Garrote", "trigger": {"kind": "mana"}, "targeting": "nearest",
		"effects": [{"type": "apply_status", "status": "root", "duration_ms": 1000, "target": "target"}],
		"grip": {"status": "root", "every_ms": 250, "effects": [{"type": "damage", "amount": 7, "target": "target"}], "veil": "stealth"}}
	var hero: UnitDef = K.kit("hero", {"mana": {"max": 10, "start": 10, "per_attack": 0}, "signature": garrote,
		"basic_attack": {"cooldown_ms": 60000}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy("mark"), 3, 4), K.foe(_dummy("other"), 5, 5)] as Array[UnitSetup]))
	_place(fight, {"mark": Vector2i(0, 400), "other": Vector2i(0, 4000)})
	var hero_state: UnitState = fight.unit_by_id("hero")
	K.step(fight, 2)
	assert_eq(hero_state.grip_target.id, "mark")
	assert_true(Statuses.is_stealthed(hero_state), "veiled while it grips")
	var at: Vector2i = hero_state.pos
	K.step(fight, 14)
	var ticks: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "garrote")
	assert_eq(ticks.size(), 3, "every 250ms")
	assert_eq(ticks[0].amount, 7)
	assert_eq(hero_state.pos, at, "it doesn't walk while it grips")
	K.step(fight, 8)
	assert_null(hero_state.grip_target, "the Root ran out")
	var landed: int = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "garrote").size()
	K.step(fight, 10)
	assert_false(Statuses.is_stealthed(hero_state), "and the veil went with it")
	var ended: Array = K.entries(fight, LogEntry.Kind.STATUS_ENDED).filter(func(entry: LogEntry) -> bool: return entry.status == "stealth")
	assert_eq(ended.map(func(entry: LogEntry) -> String: return entry.note), ["the grip ended"])
	var count: int = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "garrote").size()
	assert_eq(count, landed, "no more once it ended")
