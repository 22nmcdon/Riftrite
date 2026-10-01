extends GutTest
## Triggers and the chain guard (docs/plans/rebuild-phase5c-combos.md, step
## 3, sections 8.4 and 8.5): the new events, the filters on the built ones,
## and chains of event effects that stop at the fight's chain_limit.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A standing hero (speed 0, range 2) whose attack lands every
## `cooldown_ms` for 100% ATK (10), with the given passives.
func _hero(passives: Array, attack: Dictionary = {}, stats: Dictionary = {}, hero_id: String = "hero") -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var basic: Dictionary = {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	return K.kit(hero_id, {"stats": all_stats, "basic_attack": basic, "passives": passives})


func _dummy(attack: Dictionary = {}, passives: Array = []) -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	return K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 2}, "basic_attack": basic, "passives": passives})


func _passive(effects: Array, part_id: String = "kit") -> Dictionary:
	return {"id": part_id, "name": part_id.capitalize(), "kind": "ability", "effects": effects}


func _duel(hero: UnitDef, enemy: UnitDef = null) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy if enemy != null else _dummy(), 3, 4)] as Array[UnitSetup]))


func _from(unit_id: String) -> EffectSource:
	return EffectSource.make(unit_id, unit_id + "_attack", "Strike")


func _passive_entries(fight: CombatSim, kind: LogEntry.Kind, unit_id: String, part_id: String = "kit") -> Array[LogEntry]:
	return K.entries(fight, kind, unit_id).filter(func(entry: LogEntry) -> bool: return entry.source_ability == part_id)


func _read(effect: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	PartDef.read(DataReader.new(_passive([effect]), "part", errors))
	return errors


# --- reading -----------------------------------------------------------------------

func test_reading_the_new_triggers_and_filters() -> void:
	assert_eq(_read({"trigger": "on_holder_hit", "every": 4, "vs": {"keywords": ["rooted"]}, "type": "shield", "amount_bp_of_damage": 5000, "target": "self"}), [] as Array[String])
	assert_eq(_read({"trigger": "on_shield_broken", "type": "damage", "amount_bp_of_damage": 10000, "target": "hit_target"}), [] as Array[String])
	assert_eq(_read({"trigger": "on_ally_ability", "type": "gain_mana", "amount": 6, "target": "self"}), [] as Array[String])
	assert_eq(_read({"trigger": "on_status", "keywords": ["marked"], "type": "shield", "amount": 1, "target": "self"}), [] as Array[String])
	assert_eq(_read({"trigger": "on_kill", "once": true, "vs": {"keywords": ["burning"]}, "type": "shield", "amount": 1, "target": "self"}), [] as Array[String])
	for bad: Dictionary in [
			{"trigger": "on_basic_attack", "vs": {"keywords": ["rooted"]}, "type": "shield", "amount": 1, "target": "self"},
			{"trigger": "on_status", "keywords": ["shielded"], "type": "shield", "amount": 1, "target": "self"},
			{"trigger": "on_kill", "type": "damage", "amount": 1, "target": "hit_target"},
			{"trigger": "on_ally_ability", "type": "shield", "amount_bp_of_damage": 5000, "target": "self"},
			{"trigger": "on_holder_hit", "vs": {}, "type": "shield", "amount": 1, "target": "self"}]:
		assert_false(_read(bad).is_empty(), "refused: %s" % bad)


# --- the new events ------------------------------------------------------------------

func test_on_holder_hit_names_the_enemy_and_the_hit() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_holder_hit", "type": "shield", "amount_bp_of_damage": 5000, "target": "self"},
		{"trigger": "on_holder_hit", "every": 2, "type": "apply_status", "status": "slow", "target": "hit_target"}])])
	var fight: CombatSim = _duel(hero)
	K.step(fight, 4)
	assert_eq(_passive_entries(fight, LogEntry.Kind.SHIELD, "hero").size(), 4, "every hit")
	assert_eq(fight.units[0].shield, 4 * 5, "half of each 10-damage hit")
	assert_eq(_passive_entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").map(func(entry: LogEntry) -> String: return entry.target), ["dummy", "dummy"], "every 2nd, on the enemy hit")


func test_on_holder_hit_is_for_hits_on_enemies_not_damage_over_time() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_holder_hit", "type": "shield", "amount": 1, "target": "self"}])],
		{"cooldown_ms": 60000})
	var fight: CombatSim = _duel(hero)
	Statuses.apply(fight, fight.units[1], "poison", 10, 0, _from("hero"))
	K.step(fight, FixedMath.TICKS_PER_SECOND)
	assert_gt(K.entries(fight, LogEntry.Kind.STATUS_DAMAGE, "hero").size(), 0)
	assert_eq(fight.units[0].shield, 0, "the poison's ticks aren't hits")


func test_vs_and_once_filter_an_event() -> void:
	var hero: UnitDef = _hero([_passive([
		{"trigger": "on_holder_hit", "vs": {"keywords": ["rooted"]}, "type": "shield", "amount": 1, "target": "self"},
		{"trigger": "on_holder_hit", "once": true, "type": "shield", "amount": 100, "target": "self"}])])
	var fight: CombatSim = _duel(hero)
	K.step(fight, 3)
	assert_eq(fight.units[0].shield, 100, "the first hit only, once; none on an enemy that isn't Rooted")
	Statuses.apply(fight, fight.units[1], "root", 1, 100, _from("hero"))
	K.step(fight, 3)
	assert_eq(fight.units[0].shield, 103, "each hit on it once it's Rooted")


func test_a_crit_on_a_marked_enemy() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_holder_crit", "vs": {"keywords": ["marked"]}, "type": "shield", "amount": 5, "target": "self"}])],
		{}, {"crit": 100})
	var fight: CombatSim = _duel(hero)
	K.step(fight, 2)
	assert_eq(fight.units[0].shield, 0, "crits on an enemy that isn't Marked")
	Statuses.apply(fight, fight.units[1], "marked", 1, 100, _from("hero"))
	K.step(fight, 2)
	assert_eq(fight.units[0].shield, 10, "each crit on a Marked enemy")


func test_on_shield_broken_from_a_hit() -> void:
	var biter: UnitDef = _dummy({"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 10, "target": "target"}]})
	var hero: UnitDef = _hero([_passive([{"trigger": "on_shield_broken", "type": "damage", "amount_bp_of_damage": 10000, "target": "hit_target"}])],
		{"cooldown_ms": 60000})
	var fight: CombatSim = _duel(hero, biter)
	fight.units[0].shield = 15
	K.step(fight, 1)
	assert_eq(_passive_entries(fight, LogEntry.Kind.DAMAGE, "hero").size(), 0, "a hit that leaves Shield standing breaks nothing")
	K.step(fight, 1)
	var bursts: Array[LogEntry] = _passive_entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_eq(bursts.size(), 1)
	assert_eq([bursts[0].target, bursts[0].amount], ["dummy", 5], "at whoever broke it, for the Shield that hit took")
	K.step(fight, 3)
	assert_eq(_passive_entries(fight, LogEntry.Kind.DAMAGE, "hero").size(), 1, "no Shield, nothing more to break")


func test_on_shield_broken_from_damage_over_time() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_shield_broken", "type": "damage", "amount": 3, "target": "hit_target"}])], {"cooldown_ms": 60000})
	var fight: CombatSim = _duel(hero)
	fight.units[0].shield = 5
	Statuses.apply(fight, fight.units[0], "bleed", 10, 0, _from("dummy"))
	K.step(fight, FixedMath.TICKS_PER_SECOND)
	var bursts: Array[LogEntry] = _passive_entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_eq(bursts.size(), 1, "the Bleed's tick took the last of it")
	assert_eq(bursts[0].target, "dummy", "the Bleed's source broke it")


func test_on_ally_ability_is_for_the_allies_not_the_caster() -> void:
	var listener: Dictionary = _passive([{"trigger": "on_ally_ability", "type": "shield", "amount": 3, "target": "self"}])
	var caster: UnitDef = _hero([listener], {"cooldown_ms": 60000}, {}, "caster")
	caster.signature = K.kit("tmp", {"signature": {"id": "rally", "name": "Rally", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "shield", "amount": 5, "target": "target"}]}}).signature
	var friend: UnitDef = _hero([listener], {"cooldown_ms": 60000}, {}, "friend")
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 3, 2), K.at(friend, 5, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 2)
	assert_eq([fight.units[0].shield, fight.units[1].shield], [5, 3], "its own Shield only; its ally's passive answers")
	var answer: Array[LogEntry] = _passive_entries(fight, LogEntry.Kind.SHIELD, "friend")
	assert_eq(answer.size(), 1)


func test_on_status_by_keyword() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_status", "keywords": ["rooted"], "type": "shield", "amount": 1, "target": "self"}])],
		{"cooldown_ms": 1000, "effects": [{"type": "apply_status", "status": "root", "target": "target"}, {"type": "apply_status", "status": "slow", "target": "target"}]})
	var fight: CombatSim = _duel(hero)
	K.step(fight, 2 * FixedMath.TICKS_PER_SECOND)
	assert_eq(fight.units[0].shield, 2, "each Root, not the Slows")


func test_on_kill_reads_the_fallen_as_it_falls() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_kill", "vs": {"keywords": ["burning"]}, "type": "shield", "amount": 100, "target": "self"}])])
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4), K.foe(_dummy(), 4, 4, "other")] as Array[UnitSetup]))
	fight.units[1].hp = 5
	K.step(fight, 2)
	assert_false(fight.units[1].alive)
	assert_eq(fight.units[0].shield, 0, "it wasn't Burning")
	Statuses.apply(fight, fight.units[2], "burn", 20, 0, _from("hero"))
	fight.units[2].hp = 5
	K.step(fight, 6)
	assert_false(fight.units[2].alive)
	assert_eq(fight.units[0].shield, 100, "a Burning enemy it felled (its statuses are read before they're cleared)")


# --- the chain guard ---------------------------------------------------------------

## Two units whose passives answer every hit they take by hitting back: one
## hit starts a chain that only the guard stops.
func _ping_pong(limit: int) -> CombatSim:
	var answer: Dictionary = _passive([{"trigger": "on_hit_taken", "type": "damage", "amount": 1, "target": "hit_target"}], "spite")
	var fight: CombatSim = _duel(_hero([answer], {"cooldown_ms": 60000}), _dummy({}, [answer]))
	fight.tuning.chain_limit = limit
	EffectRunner.deal_hit(fight, _from("hero"), fight.units[1], 1, false)
	K.step(fight, 1)
	return fight


func _chain_of(fight: CombatSim) -> Array:
	return fight.combat_log.entries.filter(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.DAMAGE and entry.source_ability == "spite") \
		.map(func(entry: LogEntry) -> Array: return [entry.tick, entry.source_unit, entry.chain])


func test_a_chain_stops_at_the_limit_in_the_tick_it_starts() -> void:
	var chain: Array = _chain_of(_ping_pong(8))
	assert_eq(chain.size(), 8, "eight links, then the eighth sets off nothing")
	for i: int in chain.size():
		assert_eq(chain[i], [1, "dummy" if i % 2 == 0 else "hero", i + 1], "link %d" % (i + 1))
	assert_eq(_chain_of(_ping_pong(3)).size(), 3, "chain_limit comes from tuning")
	assert_eq(K.content().tuning.chain_limit, 8)


func test_a_chain_repeats_exactly() -> void:
	var first: CombatSim = _ping_pong(8)
	var second: CombatSim = _ping_pong(8)
	K.step(first, 40)
	K.step(second, 40)
	assert_eq(first.combat_log.entries.size(), second.combat_log.entries.size())
	assert_eq(_chain_of(first), _chain_of(second))


func test_a_kill_carries_its_hits_chain() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_kill", "type": "shield", "amount": 100, "target": "self"}])], {"cooldown_ms": 60000})
	for depth: int in [7, 8]:
		var fight: CombatSim = _duel(hero)
		fight.units[1].hp = 1
		fight.chain_depth = depth
		EffectRunner.deal_hit(fight, _from("hero"), fight.units[1], 5, false)
		fight.chain_depth = 0
		K.step(fight, 1)
		assert_false(fight.units[1].alive)
		var shields: Array[LogEntry] = _passive_entries(fight, LogEntry.Kind.SHIELD, "hero")
		if depth == 7:
			assert_eq(shields.size(), 1, "felled 7 links deep: its on_kill runs")
			assert_eq(shields[0].chain, 8, "as the chain's next link")
		else:
			assert_eq(shields.size(), 0, "felled at the limit: nothing more")
