extends GutTest
## The pieces relics share (docs/plans/rebuild-phase5c-combos.md, step 5b,
## section 11.1), each in a small fight: effects at the fight's start,
## lifesteal, crit bonuses, timed boosts, a status ending, lengthening and
## extending statuses, the targets around a unit, ally_near, Salt Circle, and
## overkill.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A standing hero (speed 0, range 2) whose attack lands every
## `cooldown_ms` for 100% ATK (10), with the given passives.
func _hero(passives: Array = [], attack: Dictionary = {}, stats: Dictionary = {}, hero_id: String = "hero") -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var basic: Dictionary = {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	return K.kit(hero_id, {"stats": all_stats, "basic_attack": basic, "passives": passives})


## A standing enemy that never attacks (unless given one).
func _dummy(hp: int = 100000, attack: Dictionary = {}, dummy_id: String = "dummy") -> UnitDef:
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 2}, "basic_attack": basic})


func _passive(effects: Array, part_id: String = "kit") -> Dictionary:
	return {"id": part_id, "name": part_id.capitalize(), "kind": "ability", "effects": effects}


func _aura(aura: Dictionary, part_id: String = "aura") -> Dictionary:
	return {"id": part_id, "name": part_id.capitalize(), "kind": "aura", "aura": aura}


func _duel(hero: UnitDef, enemy: UnitDef = null) -> CombatSim:
	return K.sim(_duel_setup(hero, enemy))


func _duel_setup(hero: UnitDef, enemy: UnitDef = null) -> FightSetup:
	return K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy if enemy != null else _dummy(), 3, 4)] as Array[UnitSetup])


func _effect(data: Dictionary, relic: bool = false) -> EffectDef:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new(data, "effect", errors), relic)
	assert_eq(errors, [] as Array[String], str(data))
	return effect


## A relic's start effect on the setup, at `scale_bp`.
func _start(setup: FightSetup, data: Dictionary, scale_bp: int = FixedMath.BP_ONE) -> void:
	setup.relic_effects.append(_effect(data, true))
	setup.relic_sources.append(EffectSource.relic("charm", "Charm", EffectSource.Team.HEROES))
	setup.relic_scales.append(scale_bp)


func _from(unit_id: String) -> EffectSource:
	return EffectSource.make(unit_id, unit_id + "_attack", "Strike")


func _unit(fight: CombatSim, unit_id: String) -> UnitState:
	return fight.unit_by_id(unit_id)


# --- 1. effects at the fight's start ---------------------------------------------------

func test_a_relics_effects_run_as_the_fight_starts_sourced_to_it() -> void:
	var setup: FightSetup = _duel_setup(_hero())
	_start(setup, {"type": "shield", "amount_bp_of_max_hp": 800, "target": "all_allies"})
	_start(setup, {"type": "apply_status", "status": "burn", "stacks": 3, "target": "all_enemies"}, 2 * FixedMath.BP_ONE)
	var fight: CombatSim = K.sim(setup)
	var shields: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHIELD)
	assert_eq(shields.size(), 1)
	assert_eq([shields[0].tick, shields[0].target, shields[0].amount], [0, "hero", 80], "8% of 1000 max HP, before anything acts")
	assert_eq([shields[0].source_ability, shields[0].source_ability_name, shields[0].source_relic_side], ["charm", "Charm", EffectSource.Team.HEROES])
	assert_eq(Statuses.find(_unit(fight, "dummy"), "burn").total_stacks(), 6, "doubled (Reliquary's scale)")


func test_nearest_enemies_are_the_count_nearest_any_hero() -> void:
	var setup: FightSetup = K.fight([K.at(_hero(), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 6, "far"), K.foe(_dummy(), 3, 4, "near"), K.foe(_dummy(), 3, 5, "middle")] as Array[UnitSetup])
	_start(setup, {"type": "apply_status", "status": "root", "duration_ms": 1500, "target": "nearest_enemies", "count": 2})
	var fight: CombatSim = K.sim(setup)
	var rooted: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED).map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(rooted, ["near", "middle"], "the two nearest, nearest first")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED)[0].end_tick, 30, "1.5s")


func test_reading_start_effects_and_nearest_enemies() -> void:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new({"type": "apply_status", "status": "root", "target": "nearest_enemies", "count": 2}, "effect", errors))
	assert_false(errors.is_empty(), "nearest_enemies is a relic's")
	for bad: Dictionary in [{"trigger": "on_fire", "type": "shield", "amount": 5, "target": "all_allies"},
			{"type": "knockback", "hexes": 1, "target": "all_enemies"}]:
		var relic_errors: Array[String] = []
		RelicDef.read(DataReader.new({"id": "r", "name": "R", "icon": "x", "flavor": "f", "text": "t", "tier": "common", "at_start": [bad]}, "relic", relic_errors))
		assert_false(relic_errors.is_empty(), "refused: %s" % bad)


# --- 2. lifesteal ------------------------------------------------------------------------

func test_lifesteal_heals_a_share_of_each_hit_on_its_own_line() -> void:
	var hero: UnitDef = _hero([_aura({"target": "holder", "stat": "lifesteal_bp", "value": 5000}),
		_passive([{"trigger": "on_heal", "type": "shield", "amount": 1, "target": "self"}], "mender")])
	var fight: CombatSim = _duel(hero)
	_unit(fight, "hero").hp = 500
	K.step(fight, 4)
	var stolen: Array[LogEntry] = K.entries(fight, LogEntry.Kind.LIFESTEAL)
	assert_eq(stolen.size(), 4)
	assert_eq([stolen[0].source_unit, stolen[0].target, stolen[0].amount], ["hero", "hero", 5], "half of each 10-damage hit")
	assert_eq(_unit(fight, "hero").hp, 520)
	assert_eq(K.entries(fight, LogEntry.Kind.HEAL).size(), 0, "not healing")
	assert_eq(_unit(fight, "hero").shield, 0, "so on_heal never hears it")


func test_lifesteal_never_heals_past_full_and_can_be_vs_some_targets() -> void:
	var full: CombatSim = _duel(_hero([_aura({"target": "holder", "stat": "lifesteal_bp", "value": 5000})]))
	K.step(full, 4)
	assert_eq(K.entries(full, LogEntry.Kind.LIFESTEAL).size(), 0, "nothing to heal")
	var thirst: Array = [_aura({"target": "holder", "stat": "lifesteal_bp", "value": 5000, "vs": {"below_hp_pct": 50}})]
	var fight: CombatSim = _duel(_hero(thirst))
	_unit(fight, "hero").hp = 500
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.LIFESTEAL).size(), 0, "the dummy is healthy")
	_unit(fight, "dummy").hp = 100
	K.step(fight, 2)
	assert_eq(K.entries(fight, LogEntry.Kind.LIFESTEAL).size(), 2, "below half HP now")


# --- 3. crit bonuses ---------------------------------------------------------------------

func test_crit_damage_adds_to_the_crit_kind() -> void:
	var plain: CombatSim = _duel(_hero([], {}, {"crit": 100}))
	K.step(plain, 1)
	var keen: CombatSim = _duel(_hero([_aura({"target": "holder", "stat": "crit_damage_bp", "value": 5000})], {}, {"crit": 100}))
	K.step(keen, 1)
	var plain_hit: LogEntry = K.entries(plain, LogEntry.Kind.DAMAGE)[0]
	var keen_hit: LogEntry = K.entries(keen, LogEntry.Kind.DAMAGE)[0]
	assert_true(plain_hit.crit and keen_hit.crit)
	assert_eq([plain_hit.amount, keen_hit.amount], [15, 20], "x1.5, then +50% more on the crit kind")


func test_crit_chance_can_be_vs_some_targets() -> void:
	var sure: Array = [_aura({"target": "holder", "stat": "crit_chance_bp", "value": 10000, "vs": {"keywords": ["marked"]}})]
	var fight: CombatSim = _duel(_hero(sure))
	K.step(fight, 3)
	assert_false(K.entries(fight, LogEntry.Kind.DAMAGE).any(func(entry: LogEntry) -> bool: return entry.crit), "no crits on an unmarked enemy")
	Statuses.apply(fight, _unit(fight, "dummy"), "marked", 0, 200, _from("hero"))
	var before: int = K.entries(fight, LogEntry.Kind.DAMAGE).size()
	K.step(fight, 3)
	var after: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE).slice(before)
	assert_eq(after.size(), 3)
	assert_true(after.all(func(entry: LogEntry) -> bool: return entry.crit), "every hit on the Marked enemy crits")


# --- 4. timed boosts, and 5. a status ending ---------------------------------------------

func test_a_boost_counts_like_an_aura_while_it_lasts() -> void:
	var fight: CombatSim = _duel(_hero([], {}, {"atsp": 100}))
	var hero: UnitState = _unit(fight, "hero")
	Statuses.apply(fight, hero, "veiled_haste", 0, 0, _from("hero"))
	assert_eq(hero.stats.get_stat(UnitStats.Stat.ATSP), 130, "+30 ATSP")
	Statuses.apply(fight, hero, "storm_call", 0, 0, _from("hero"))
	assert_eq(hero.stats.get_stat(UnitStats.Stat.ATK), 12, "+20% ATK")
	K.step(fight, 61)
	assert_eq([hero.stats.get_stat(UnitStats.Stat.ATSP), hero.stats.get_stat(UnitStats.Stat.ATK)], [100, 10], "both gone after 3s")


func test_on_status_ended_hears_a_status_running_out_even_a_relics() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_status_ended", "statuses": ["stealth"], "type": "apply_status", "status": "veiled_haste", "target": "self"}])])
	var setup: FightSetup = _duel_setup(hero)
	_start(setup, {"type": "apply_status", "status": "stealth", "duration_ms": 1000, "target": "all_allies"})
	var fight: CombatSim = K.sim(setup)
	Statuses.apply(fight, _unit(fight, "hero"), "slow", 0, 100, _from("dummy"))
	K.step(fight, 25)
	var hasted: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").filter(func(entry: LogEntry) -> bool: return entry.status == "veiled_haste")
	assert_eq(hasted.size(), 1, "once, as the Stealth ran out (not the Slow)")
	assert_eq(hasted[0].tick, 20, "as the 1s Stealth ends")


# --- 6. lengthening some statuses, and 7. extending one --------------------------------

func test_a_kit_mods_change_can_touch_only_some_statuses() -> void:
	var kit: UnitDef = _hero([], {"effects": [{"type": "apply_status", "status": "stealth", "duration_ms": 1000, "target": "self"},
		{"type": "apply_status", "status": "slow", "duration_ms": 1000, "target": "target"}]})
	var errors: Array[String] = []
	var mod: KitMod = KitMod.read(DataReader.new({"on": [{"slot": "abilities", "statuses": ["stealth"], "duration_add_ms": 1000}]}, "mod", errors))
	assert_eq(errors, [] as Array[String])
	var modded: UnitDef = mod.apply(kit)
	assert_eq(modded.basic_attack.effects.map(func(effect: EffectDef) -> int: return effect.duration_ticks), [40, 20], "Stealth 1s longer, Slow unchanged")
	var bad_errors: Array[String] = []
	KitMod.read(DataReader.new({"on": [{"slot": "abilities", "types": ["damage"], "statuses": ["stealth"], "duration_add_ms": 1000}]}, "mod", bad_errors))
	assert_false(bad_errors.is_empty(), "types or statuses, not both")


func test_extend_status_lengthens_a_timed_status_already_there() -> void:
	var hero: UnitDef = _hero([_passive([{"trigger": "on_holder_hit", "type": "extend_status", "status": "marked", "duration_ms": 1000, "target": "hit_target"}])])
	var fight: CombatSim = _duel(hero)
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_EXTENDED).size(), 0, "nothing to extend")
	Statuses.apply(fight, _unit(fight, "dummy"), "marked", 0, 20, _from("hero"))
	var ends: int = Statuses.find(_unit(fight, "dummy"), "marked").ends_at
	K.step(fight, 1)
	var extended: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_EXTENDED)
	assert_eq(extended.size(), 1)
	assert_eq([extended[0].target, extended[0].status, extended[0].end_tick], ["dummy", "marked", ends + 20])
	assert_eq(Statuses.find(_unit(fight, "dummy"), "marked").ends_at, ends + 20)


# --- 8. around the unit, or the one the event names ------------------------------------

func test_burn_spreads_from_a_felled_burning_enemy_to_those_near_it() -> void:
	var pyre: Array = [_passive([{"trigger": "on_kill", "vs": {"keywords": ["burning"]}, "type": "apply_status", "status": "burn", "stacks_of": "burn",
		"target": "enemies_near_named", "within_hexes": 1}])]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(pyre, {}, {"atk": 1000}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(50), 3, 4, "victim"), K.foe(_dummy(), 3, 5, "beside"), K.foe(_dummy(), 7, 6, "far")] as Array[UnitSetup]))
	Statuses.apply(fight, _unit(fight, "victim"), "burn", 7, 0, _from("hero"))
	K.step(fight, 2)
	assert_false(_unit(fight, "victim").alive)
	assert_eq(Statuses.find(_unit(fight, "beside"), "burn").total_stacks(), 7, "as many stacks as it had")
	assert_null(Statuses.find(_unit(fight, "far"), "burn"), "only within 1 hex of it")


func test_the_enemy_nearest_a_felled_one() -> void:
	var mire: Array = [_passive([{"trigger": "on_kill", "type": "apply_status", "status": "root", "duration_ms": 1000, "target": "enemy_near_named"}])]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(mire, {}, {"atk": 1000}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(50), 3, 4, "victim"), K.foe(_dummy(), 3, 6, "next"), K.foe(_dummy(), 7, 6, "far")] as Array[UnitSetup]))
	K.step(fight, 2)
	var rooted: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED).map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(rooted, ["next"], "the one nearest the fallen")


func test_enemies_near_the_unit_itself() -> void:
	var aegis: Array = [_passive([{"trigger": "on_shield_broken", "type": "damage", "amount_bp_of_damage": 10000, "target": "enemies_near_self", "within_hexes": 1}], "aegis")]
	var fight: CombatSim = K.sim(K.fight([K.at(_hero(aegis, {"cooldown_ms": 60000}), 3, 2)] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4, "close"), K.foe(_dummy(), 7, 6, "far")] as Array[UnitSetup]))
	var hero: UnitState = _unit(fight, "hero")
	_unit(fight, "close").pos = hero.pos + Vector2i(900, 0)
	EffectRunner.give_shield(fight, hero, 30, _from("hero"))
	EffectRunner.deal_hit(fight, _from("far"), hero, 40, false)
	fight.step()
	var shards: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "aegis")
	assert_eq(shards.map(func(entry: LogEntry) -> Array: return [entry.target, entry.amount]), [["close", 30]], "the Shield the blow broke, within 1 hex only")


# --- 9. close to an ally -----------------------------------------------------------------

func test_ally_near_holds_while_another_ally_is_close() -> void:
	var banner: Array = [_aura({"target": "holder", "stat": "damage_reduced_bp", "value": 5000, "while": "ally_near", "within_hexes": 1})]
	var close: CombatSim = K.sim(K.fight([K.at(_hero(banner), 3, 2), K.at(_hero([], {}, {}, "friend"), 3, 1, "friend")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	close.step()
	assert_eq(_unit(close, "hero").aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 5000)
	EffectRunner.deal_hit(close, _from("dummy"), _unit(close, "hero"), 100, false)
	assert_eq(K.entries(close, LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.target == "hero")[0].amount, 50, "takes half")
	var apart: CombatSim = K.sim(K.fight([K.at(_hero(banner), 3, 2), K.at(_hero([], {}, {}, "friend"), 0, 0, "friend")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 5)] as Array[UnitSetup]))
	apart.step()
	assert_eq(_unit(apart, "hero").aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 0, "no ally within 1 hex")


# --- 10. Salt Circle ---------------------------------------------------------------------

func test_salt_circle_breaks_the_first_enemy_areas() -> void:
	var slam: Dictionary = {"cooldown_ms": 500, "effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies",
		"effects": [{"type": "damage", "amount": 40, "target": "target"}]}]}
	var setup: FightSetup = _duel_setup(_hero([], {"cooldown_ms": 60000}), _dummy(100000, slam))
	setup.salt_circles = 1
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 25)
	var landed: Array[LogEntry] = K.entries(fight, LogEntry.Kind.AREA_LANDED)
	assert_eq(landed.size(), 2)
	assert_eq([landed[0].note, landed[0].amount], ["broken by Salt Circle", 0], "the first lands on nothing")
	assert_eq([landed[1].note, landed[1].amount], ["", 1], "the next lands")
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.target == "hero").size(), 1)


# --- 11. overkill ------------------------------------------------------------------------

func test_overkill_is_the_damage_past_the_last_hp_and_tallies() -> void:
	var setup: UnitSetup = K.at(_hero([], {}, {"atk": 100}), 3, 2)
	var errors: Array[String] = []
	setup.tally_keys.append("tithe")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "overkill"}, "count", errors)))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(_dummy(30), 3, 4)] as Array[UnitSetup]))
	EffectRunner.give_shield(fight, _unit(fight, "dummy"), 20, _from("dummy"))
	K.step(fight, 2)
	var hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE)[0]
	assert_eq([hit.amount, hit.absorbed, hit.overkill], [100, 20, 50], "100 into 20 Shield and 30 HP")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "tithe"), 50)
