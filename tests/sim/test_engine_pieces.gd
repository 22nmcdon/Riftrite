extends GutTest
## The engines' pieces (docs/plans/rebuild-phase5c-combos.md, step 5c,
## section 12.1), each in a small fight: a share of Burn spread, overheal to
## Shield from an aura, lifesteal as healing, on_lifesteal, stacking boosts,
## Knife's Edge, planted steps and DEF points, auras per Shield, stacking
## Marks and crit damage per stack, auras on the basic attack only, the
## overheal strike, fresh_only, and mods only for ranged heroes.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A standing hero (speed 0, range 2) whose attack lands every
## `cooldown_ms` for 100% ATK (10), with the given passives.
func _hero(passives: Array = [], attack: Dictionary = {}, stats: Dictionary = {}, hero_id: String = "hero") -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var basic: Dictionary = {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	return K.kit(hero_id, {"stats": all_stats, "basic_attack": basic, "passives": passives})


func _dummy(hp: int = 100000, dummy_id: String = "dummy") -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _passive(effects: Array, part_id: String = "kit") -> Dictionary:
	return {"id": part_id, "name": part_id.capitalize(), "kind": "ability", "effects": effects}


func _aura(aura: Dictionary, part_id: String = "aura") -> Dictionary:
	var all: Dictionary = {"target": "holder"}
	all.merge(aura)
	return {"id": part_id, "name": part_id.capitalize(), "kind": "aura", "aura": all}


func _setup(hero: UnitDef, enemy: UnitDef = null) -> FightSetup:
	return K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy if enemy != null else _dummy(), 3, 4)] as Array[UnitSetup])


func _duel(hero: UnitDef, enemy: UnitDef = null) -> CombatSim:
	return K.sim(_setup(hero, enemy))


func _from(unit_id: String) -> EffectSource:
	return EffectSource.make(unit_id, unit_id + "_attack", "Strike")


func _read(kind: String, data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var reader := DataReader.new(data, kind, errors)
	match kind:
		"aura":
			AuraDef.read(reader)
		"status":
			StatusDef.read(reader)
		"effect":
			EffectDef.read(reader)
	return errors


func _hits(fight: CombatSim, unit_id: String = "hero") -> Array:
	return K.entries(fight, LogEntry.Kind.DAMAGE, unit_id).map(func(entry: LogEntry) -> int: return entry.amount)


# --- reading -----------------------------------------------------------------------

func test_reading_the_new_pieces() -> void:
	for good: Array in [
			["aura", {"target": "holder", "stat": "atk_bp", "value": 11500, "while": "planted", "after_ms": 2000, "step": {"every_ms": 2000, "value": 500}}],
			["aura", {"target": "holder", "stat": "atk_bp", "per_shield_bp": 5}],
			["aura", {"target": "holder", "stat": "crit_damage_bp", "value": 2000, "per_target_stacks": "marked"}],
			["aura", {"target": "holder", "stat": "damage_bp", "value": 20000, "from_basic": true}],
			["status", {"id": "s", "name": "S", "kind": "boost", "stacking": true, "auras": [{"stat": "atsp", "value": 1}]}],
			["effect", {"trigger": "on_lifesteal", "type": "shield", "amount": 1, "target": "self"}],
			["effect", {"type": "apply_status", "status": "root", "fresh_only": true, "target": "target"}]]:
		assert_eq(_read(good[0], good[1]), [] as Array[String], str(good[1]))
	for bad: Array in [
			["aura", {"target": "holder", "stat": "atk_bp", "value": 11500, "step": {"every_ms": 2000, "value": 500}}],
			["aura", {"target": "holder", "stat": "atk_bp", "value": 11000, "per_shield_bp": 5}],
			["aura", {"target": "holder", "stat": "atk_bp", "value": 11000, "from_basic": true}],
			["status", {"id": "s", "name": "S", "kind": "boost", "auras": [{"stat": "atsp", "value": 1}]}],
			["effect", {"type": "apply_status", "status": "burn", "stacks_share_bp": 500, "target": "target"}]]:
		assert_false(_read(bad[0], bad[1]).is_empty(), "refused: %s" % bad[1])


# --- Burn spread by share (Ashen Engine) ---------------------------------------------

func test_a_share_of_the_named_units_stacks_at_least_one() -> void:
	var spread: Array = [_passive([{"trigger": "on_holder_hit", "vs": {"keywords": ["burning"]}, "type": "apply_status", "status": "burn",
		"stacks_of": "burn", "stacks_share_bp": 500, "target": "enemy_near_named"}])]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(spread), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4, "burning"), K.foe(_dummy(), 3, 6, "next")] as Array[UnitSetup]))
	Statuses.apply(fight, fight.unit_by_id("burning"), "burn", 60, 0, _from("hero"))
	K.step(fight, 1)
	assert_eq(Statuses.stacks_on(fight.unit_by_id("next"), "burn"), 3, "5% of 60")
	var small: CombatSim = K.sim(K.fight([K.at(_hero(spread), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4, "burning"), K.foe(_dummy(), 3, 6, "next")] as Array[UnitSetup]))
	Statuses.apply(small, small.unit_by_id("burning"), "burn", 4, 0, _from("hero"))
	K.step(small, 1)
	assert_eq(Statuses.stacks_on(small.unit_by_id("next"), "burn"), 1, "at least 1")


# --- overheal and lifesteal ------------------------------------------------------------

func test_an_overheal_shield_aura_turns_its_heals_past_full_into_shield() -> void:
	var mender: UnitDef = _hero([_aura({"stat": "overheal_shield_bp", "value": 5000})], {"effects": [{"type": "heal", "amount": 100, "target": "self"}]})
	var fight: CombatSim = _duel(mender)
	fight.unit_by_id("hero").hp = 960
	K.step(fight, 1)
	assert_eq(fight.unit_by_id("hero").shield, 30, "half of the 60 past full HP")
	var plain: CombatSim = _duel(_hero([], {"effects": [{"type": "heal", "amount": 100, "target": "self"}]}))
	K.step(plain, 1)
	assert_eq(plain.unit_by_id("hero").shield, 0, "nothing without it")


func test_lifesteal_that_heals_is_a_heal() -> void:
	var hero: UnitDef = _hero([_aura({"stat": "lifesteal_bp", "value": 5000}, "leech"), _aura({"stat": "lifesteal_heals", "value": 1}, "communion"),
		_aura({"stat": "heal_bp", "value": 12000}, "power"), _passive([{"trigger": "on_heal", "type": "shield", "amount": 1, "target": "self"}], "mender")])
	var fight: CombatSim = _duel(hero)
	fight.unit_by_id("hero").hp = 500
	K.step(fight, 1)
	var heals: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HEAL, "hero")
	assert_eq(heals.size(), 1)
	assert_eq([heals[0].amount, heals[0].lifesteal], [6, true], "half of 10, +20% heal power")
	assert_true(heals[0].to_text().ends_with("(lifesteal)"))
	assert_eq(K.entries(fight, LogEntry.Kind.LIFESTEAL).size(), 0, "not its own line any more")
	assert_eq(fight.unit_by_id("hero").shield, 1, "on_heal hears it")


func test_on_lifesteal_and_a_stacking_boost_with_its_own_timers() -> void:
	var hero: UnitDef = _hero([_aura({"stat": "lifesteal_bp", "value": 5000}),
		_passive([{"trigger": "on_lifesteal", "type": "apply_status", "status": "frenzy", "target": "self"}])], {"cooldown_ms": 1000})
	var fight: CombatSim = _duel(hero)
	var unit: UnitState = fight.unit_by_id("hero")
	unit.hp = 100
	var atsp: int = unit.stats.get_stat(UnitStats.Stat.ATSP)
	for checks: int in 6:
		K.step(fight, 23)
		# Each lifesteal adds a stack that lasts 3s (60 ticks) on its own.
		var live: int = K.entries(fight, LogEntry.Kind.LIFESTEAL).filter(func(entry: LogEntry) -> bool: return entry.tick > fight.tick - 60).size()
		assert_eq(Statuses.stacks_on(unit, "frenzy"), live, "at tick %d" % fight.tick)
		assert_eq(unit.stats.get_stat(UnitStats.Stat.ATSP), atsp + 2 * live, "+2 a stack")
	assert_gt(K.entries(fight, LogEntry.Kind.LIFESTEAL).size(), 3, "enough lifesteal for stacks to run out")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_ENDED).size(), 0, "the boost goes on while it has a stack")


func test_a_stacking_boost_without_a_duration_lasts_the_fight() -> void:
	var fight: CombatSim = _duel(_hero([_passive([{"trigger": "on_holder_hit", "type": "apply_status", "status": "quickened", "target": "self"}])], {}, {"atsp": 100}))
	K.step(fight, 200)
	var unit: UnitState = fight.unit_by_id("hero")
	var stacks: int = Statuses.stacks_on(unit, "quickened")
	assert_gt(stacks, 100, "a stack for every hit")
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATSP), 100 + stacks)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_ENDED).size(), 0, "never ends")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).back().stacks, stacks, "the log counts its stacks")


func test_the_overheal_strike_hits_the_target_and_never_steals() -> void:
	var hero: UnitDef = _hero([_aura({"stat": "lifesteal_bp", "value": 5000}, "leech"), _aura({"stat": "overheal_strike_bp", "value": 50000}, "strike")], {"cooldown_ms": 60000})
	var fight: CombatSim = _duel(hero)
	fight.step()
	EffectRunner.deal_hit(fight, _from("hero"), fight.unit_by_id("dummy"), 10, false)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_eq(hits.map(func(entry: LogEntry) -> int: return entry.amount), [10, 25], "the 5 it couldn't heal, x5")
	assert_eq(hits[1].note, "overheal from lifesteal")
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE).size(), 2, "the strike itself steals nothing, so nothing more")


# --- crits ---------------------------------------------------------------------------

func test_knifes_edge_turns_crit_chance_past_full_into_crit_damage() -> void:
	var edge: CombatSim = _duel(_hero([_aura({"stat": "crit_overflow_bp", "value": 20000})], {}, {"crit": 150}))
	K.step(edge, 1)
	assert_eq(_hits(edge), [25], "x1.5, +2 x 50% past 100%")
	var under: CombatSim = _duel(_hero([_aura({"stat": "crit_overflow_bp", "value": 20000})], {}, {"crit": 100}))
	K.step(under, 1)
	assert_eq(_hits(under), [15], "nothing past 100%")


func test_marks_stack_under_the_rule_and_crits_count_them() -> void:
	var hunter: UnitDef = _hero([_aura({"stat": "crit_damage_bp", "value": 2000, "per_target_stacks": "marked"})], {"cooldown_ms": 60000}, {"crit": 100})
	var setup: FightSetup = _setup(hunter)
	setup.hero_rules.marks_stack = true
	var fight: CombatSim = K.sim(setup)
	var dummy: UnitState = fight.unit_by_id("dummy")
	for i: int in 3:
		Statuses.apply(fight, dummy, "marked", 0, 0, _from("hero"))
	assert_eq(Statuses.stacks_on(dummy, "marked"), 3)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).back().stacks, 3)
	Statuses.apply(fight, dummy, "marked", 0, 0, _from("dummy"))
	assert_eq(Statuses.stacks_on(dummy, "marked"), 3, "an enemy's own Mark doesn't stack")
	EffectRunner.deal_hit(fight, _from("hero"), dummy, 100, true)
	assert_eq(_hits(fight), [DamageRule.apply(100, 0, 5000 + 3 * 2000, 1500)], "+20% crit damage per stack")
	var plain: CombatSim = _duel(hunter)
	for i: int in 3:
		Statuses.apply(plain, plain.unit_by_id("dummy"), "marked", 0, 0, _from("hero"))
	assert_eq(Statuses.stacks_on(plain.unit_by_id("dummy"), "marked"), 1, "without the rule a Mark only refreshes")


# --- auras that grow or are scoped ---------------------------------------------------

func test_a_planted_aura_steps_up_while_still_and_resets_on_moving() -> void:
	var stone: Array = [_aura({"stat": "atk_bp", "value": 11500, "while": "planted", "after_ms": 2000, "step": {"every_ms": 2000, "value": 500}}),
		_aura({"stat": "def", "value": 15, "while": "planted", "after_ms": 2000, "step": {"every_ms": 2000, "value": 5}}, "stone_def")]
	var fight: CombatSim = _duel(_hero(stone, {"cooldown_ms": 60000}, {"atk": 100, "def": 10}))
	var unit: UnitState = fight.unit_by_id("hero")
	unit.moved_at = 0
	K.step(fight, 39)
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 100, "not yet 2s")
	K.step(fight, 1)
	assert_eq([unit.stats.get_stat(UnitStats.Stat.ATK), unit.stats.get_stat(UnitStats.Stat.DEF)], [115, 25])
	K.step(fight, 40)
	assert_eq([unit.stats.get_stat(UnitStats.Stat.ATK), unit.stats.get_stat(UnitStats.Stat.DEF)], [120, 30], "a step more")
	unit.moved_at = fight.tick
	fight.step()
	assert_eq([unit.stats.get_stat(UnitStats.Stat.ATK), unit.stats.get_stat(UnitStats.Stat.DEF)], [100, 10], "moving resets it")


func test_an_aura_per_point_of_shield() -> void:
	var fight: CombatSim = _duel(_hero([_aura({"stat": "atk_bp", "per_shield_bp": 5})], {"cooldown_ms": 60000}, {"atk": 100}))
	var unit: UnitState = fight.unit_by_id("hero")
	fight.step()
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 100, "no Shield")
	EffectRunner.give_shield(fight, unit, 400, _from("hero"))
	fight.step()
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 120, "400 Shield: +20%")
	unit.shield = 100
	fight.step()
	assert_eq(unit.stats.get_stat(UnitStats.Stat.ATK), 105)


func test_an_aura_on_the_basic_attack_only() -> void:
	var hero: UnitDef = _hero([_aura({"stat": "damage_bp", "value": 20000, "from_basic": true}),
		_passive([{"trigger": "on_basic_attack", "type": "damage", "amount": 10, "target": "target"}])])
	var fight: CombatSim = _duel(hero)
	K.step(fight, 1)
	assert_eq(_hits(fight), [20, 10], "the basic attack's hit doubled, the passive's not")


# --- fresh_only, and mods for ranged heroes ----------------------------------------------

func test_fresh_only_never_stacks_or_lengthens() -> void:
	var hero: UnitDef = _hero([], {"effects": [{"type": "apply_status", "status": "root", "duration_ms": 1000, "fresh_only": true, "target": "target"}]})
	var fight: CombatSim = _duel(hero)
	K.step(fight, 3)
	var roots: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED)
	assert_eq(roots.size(), 1, "only while it isn't Rooted")
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 2, "again once it ran out")


func test_a_relic_mod_only_for_ranged_heroes() -> void:
	var errors: Array[String] = []
	var relic: RelicDef = RelicDef.read(DataReader.new({"id": "r", "name": "R", "icon": "x", "flavor": "f", "text": "t", "tier": "boss", "mod_for": "ranged",
		"mod": {"stats_add": {"atk": 1}}}, "relic", errors))
	assert_eq(errors, [] as Array[String])
	assert_true(relic.mod_fits(_hero([], {}, {"range": 4})))
	assert_false(relic.mod_fits(_hero([], {}, {"range": 1})))
	var bad: Array[String] = []
	RelicDef.read(DataReader.new({"id": "r", "name": "R", "icon": "x", "flavor": "f", "text": "t", "tier": "boss", "mod_for": "ranged", "slots_add": 1}, "relic", bad))
	assert_false(bad.is_empty(), "mod_for needs a mod")
