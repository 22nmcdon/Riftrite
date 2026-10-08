extends GutTest
## The tuning phase's relics for sustain, control, and swarms
## (docs/plans/tuning-phase.md, T-1; relics/): each one's effect in a small
## fight, with the sim pieces they brought: plain hits, once_per_enemy,
## on_enemy_near, above_hp_pct, and the hero rules holds, held_weak, and
## held_keeps_burn.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


## A hero with `relics`' mods (speed 0, range 2), hitting every tick for 10
## unless `attack` says otherwise.
func _hero(relics: Array, overrides: Dictionary = {}, unit_id: String = "hero") -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 1000, "atk": 10, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}}
	for key: String in overrides:
		if data.has(key) and data[key] is Dictionary:
			(data[key] as Dictionary).merge(overrides[key], true)
		else:
			data[key] = overrides[key]
	var def: UnitDef = K.kit(unit_id, data)
	for relic_id: String in relics:
		if _run.relics[relic_id].mod != null:
			def = _run.relics[relic_id].mod.apply(def)
	return def


## A sturdy enemy that stands still and barely attacks.
func _dummy(overrides: Dictionary = {}, kit_id: String = "dummy") -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(overrides, true)
	return K.kit(kit_id, data)


## A fight of `heroes` against `enemies`, under `relics`' hero rules.
func _fight(heroes: Array[UnitSetup], enemies: Array[UnitSetup], relics: Array = []) -> CombatSim:
	var setup: FightSetup = K.fight(heroes, enemies)
	for relic_id: String in relics:
		if _run.relics[relic_id].rules != null:
			setup.hero_rules = setup.hero_rules.merged(_run.relics[relic_id].rules)
	return K.sim(setup)


func _applied(fight: CombatSim, status: String, target: String = "") -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in fight.combat_log.entries:
		if entry.kind == LogEntry.Kind.STATUS_APPLIED and entry.status == status and (target.is_empty() or entry.target == target):
			found.append(entry)
	return found


func test_the_thirteen_are_in_the_pool() -> void:
	var tiers: Dictionary = {"soothing_salve": "common", "weighted_net": "common", "snare_wire": "common", "thorned_bandage": "rare",
		"heavy_pommel": "rare", "dulled_shackles": "rare", "choking_hold": "rare", "splinter_shot": "rare", "full_vigor": "epic",
		"shackle_engine": "epic", "unending_vigil": "legendary", "iron_garden": "legendary", "stillwater_seal": "legendary"}
	for relic_id: String in tiers:
		assert_true(_run.relics.has(relic_id), relic_id)
		assert_eq(RelicDef.TIER_NAMES[_run.relics[relic_id].tier], tiers[relic_id], relic_id)


func test_soothing_salve_heals_more() -> void:
	var healer: UnitDef = _hero(["soothing_salve"], {"basic_attack": {"effects": [{"type": "heal", "amount": 10, "target": "self"}]}})
	var fight: CombatSim = _fight([K.at(healer, 3, 2, "hero")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup])
	fight.units[0].hp = 500
	K.step(fight, 2)
	var heals: Array = K.entries(fight, LogEntry.Kind.HEAL, "hero").map(func(entry: LogEntry) -> int: return entry.amount)
	assert_eq(heals.slice(0, 2), [11, 11], "+10% to its heals")


func test_weighted_net_roots_the_signatures_first_hit_once() -> void:
	var caster: UnitDef = _hero(["weighted_net"], {"signature": {"id": "jab", "name": "Jab", "trigger": {"kind": "count", "event": "on_basic_attack", "every": 3},
		"effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = _fight([K.at(caster, 3, 2, "hero")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "dummy")] as Array[UnitSetup])
	K.step(fight, 2)
	assert_eq(_applied(fight, "root").size(), 0, "basic attacks don't set it off")
	K.step(fight, 20)
	assert_eq(_applied(fight, "root", "dummy").size(), 1, "the first signature hit Roots, and only once a fight")


func test_snare_wire_roots_each_enemy_once_as_it_comes_near() -> void:
	var walker: UnitDef = _dummy({"stats": {"speed": 3, "range": 1}}, "walker")
	var fight: CombatSim = _fight([K.at(_hero(["snare_wire"], {}, "one"), 2, 1, "one"), K.at(_hero(["snare_wire"], {}, "two"), 4, 1, "two")] as Array[UnitSetup],
		[K.foe(walker, 3, 5, "walker")] as Array[UnitSetup])
	K.step(fight, 200)
	var roots: Array[LogEntry] = _applied(fight, "root", "walker")
	assert_eq(roots.size(), 1, "once for each enemy, across the team")
	assert_eq(roots[0].end_tick - roots[0].tick, 10, "0.5s")


func test_thorned_bandage_hurts_the_enemy_nearest_the_healed() -> void:
	var healer: UnitDef = _hero(["thorned_bandage", "leech_tooth"], {"basic_attack": {"effects": [{"type": "heal", "amount": 40, "target": "self"}]}})
	var fight: CombatSim = _fight([K.at(healer, 3, 2, "hero")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "near"), K.foe(_dummy({}, "far"), 7, 6, "far")] as Array[UnitSetup])
	fight.units[0].hp = 500
	K.step(fight, 1)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_eq(hits.size(), 1)
	assert_eq([hits[0].target, hits[0].amount, hits[0].crit], ["near", 10, false], "a quarter of the 40 healed, to the nearest enemy")
	assert_eq(K.entries(fight, LogEntry.Kind.LIFESTEAL, "hero").size(), 0, "never lifesteals")


func test_heavy_pommel_stuns_each_enemy_once_for_the_team() -> void:
	var fight: CombatSim = _fight([K.at(_hero(["heavy_pommel"], {"stats": {"range": 4}}, "one"), 2, 2, "one"),
		K.at(_hero(["heavy_pommel"], {"stats": {"range": 4}}, "two"), 4, 2, "two")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4, "dummy")] as Array[UnitSetup])
	K.step(fight, 60)
	var stuns: Array[LogEntry] = _applied(fight, "stun", "dummy")
	assert_eq(stuns.size(), 1, "the first hit on it, whichever hero lands it (Decision 5)")
	assert_eq(stuns[0].end_tick - stuns[0].tick, 20, "1s")


func test_dulled_shackles_weakens_a_held_enemy_and_lingers() -> void:
	var biter: UnitDef = _dummy({"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 100, "target": "target"}]}}, "biter")
	var still: UnitDef = _hero([], {"stats": {"hp": 100000, "atk": 0}})
	var fight: CombatSim = _fight([K.at(still, 3, 2, "hero")] as Array[UnitSetup], [K.foe(biter, 3, 4, "biter")] as Array[UnitSetup], ["dulled_shackles"])
	K.step(fight, 1)
	Statuses.apply(fight, fight.units[1], "root", 1, 10, EffectSource.make("hero", "x", "X"))
	K.step(fight, 1)
	var dulled: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "biter").map(func(entry: LogEntry) -> int: return entry.amount)
	assert_lt(dulled.back(), dulled.front(), "a held enemy hits 25% less")
	K.step(fight, 30)
	var during: int = K.entries(fight, LogEntry.Kind.DAMAGE, "biter").back().amount
	assert_eq(during, dulled.back(), "and keeps hitting less for 2s after the Root ends")
	K.step(fight, 40)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "biter").back().amount, dulled.front(), "then hits as before")


func test_choking_hold_drains_held_enemies() -> void:
	var caster: UnitDef = _dummy({"mana": {"max": 1000, "start": 50}, "signature": {"id": "spell", "name": "Spell", "trigger": {"kind": "mana"},
		"effects": [{"type": "damage", "amount": 1, "target": "target"}]}}, "caster")
	var fight: CombatSim = _fight([K.at(_hero(["choking_hold"]), 3, 2, "hero")] as Array[UnitSetup], [K.foe(caster, 3, 4, "caster")] as Array[UnitSetup])
	K.step(fight, 1)
	var before: int = fight.units[1].mana
	assert_eq(K.entries(fight, LogEntry.Kind.MANA_DRAIN, "hero").size(), 0, "not held: no drain")
	Statuses.apply(fight, fight.units[1], "root", 1, 100, EffectSource.make("x", "x", "X"))
	K.step(fight, 1)
	assert_lt(fight.units[1].mana, before, "a hit on a Rooted enemy drains its mana")


func test_splinter_shot_hits_one_enemy_beside_a_crit() -> void:
	var critter: UnitDef = _hero(["splinter_shot"], {"stats": {"crit": 200}})
	var fight: CombatSim = _fight([K.at(critter, 3, 2, "hero")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "struck"), K.foe(_dummy({}, "beside"), 4, 4, "beside")] as Array[UnitSetup])
	K.step(fight, 1)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_eq(hits.size(), 2, "the crit and its splinter")
	assert_true(hits[0].crit)
	assert_eq([hits[1].target, hits[1].crit, hits[1].amount], ["beside", false, FixedMath.apply_bp(hits[0].amount, 5000)], "half the crit, never a crit itself")


func test_full_vigor_while_near_full_hp() -> void:
	var fight: CombatSim = _fight([K.at(_hero(["full_vigor"]), 3, 2, "hero")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup])
	K.step(fight, 1)
	fight.units[0].hp = 800
	K.step(fight, 2)
	var hits: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> int: return entry.amount)
	assert_eq([hits.front(), hits.back()], [12, 10], "+15% ATK above 90% HP (11.5, rounded), none below")


func test_shackle_engine_holds_longer_and_starves_mana() -> void:
	var caster: UnitDef = _dummy({"mana": {"max": 1000, "regen_per_s": 20}, "signature": {"id": "spell", "name": "Spell", "trigger": {"kind": "mana"},
		"effects": [{"type": "damage", "amount": 1, "target": "target"}]}}, "caster")
	var fight: CombatSim = _fight([K.at(_hero([]), 3, 2, "hero")] as Array[UnitSetup], [K.foe(caster, 3, 4, "caster")] as Array[UnitSetup], ["shackle_engine"])
	K.step(fight, 5)
	Statuses.apply(fight, fight.units[1], "root", 1, 20, EffectSource.make("hero", "x", "X"))
	var root: LogEntry = _applied(fight, "root", "caster").back()
	assert_eq(root.end_tick - root.tick, 26, "30% longer")
	var held_mana: int = fight.units[1].mana
	K.step(fight, 10)
	assert_eq(fight.units[1].mana, held_mana, "no mana while held")
	K.step(fight, 30)
	assert_gt(fight.units[1].mana, held_mana, "and mana again once free")


func test_unending_vigil_grows_each_second_near_full() -> void:
	var fight: CombatSim = _fight([K.at(_hero(["unending_vigil"]), 3, 2, "hero")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup])
	K.step(fight, 61)
	assert_eq(Statuses.stacks_on(fight.units[0], "vigilant"), 3, "a stack a second above 75% HP")
	fight.units[0].hp = 500
	K.step(fight, 40)
	assert_eq(Statuses.stacks_on(fight.units[0], "vigilant"), 3, "none below it, and the stacks stay")


func test_iron_garden_grows_the_team_with_every_hold() -> void:
	var rooter: UnitDef = _hero(["iron_garden"], {"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 1, "target": "target"},
		{"trigger": "on_hit", "type": "apply_status", "status": "root", "target": "hit_target"}]}, "stats": {"range": 4}}, "rooter")
	var fight: CombatSim = _fight([K.at(rooter, 2, 2, "rooter"), K.at(_hero(["iron_garden"], {"stats": {"range": 4}}, "mate"), 4, 2, "mate")] as Array[UnitSetup],
		[K.foe(_dummy(), 3, 4)] as Array[UnitSetup])
	K.step(fight, 41)
	var roots: int = _applied(fight, "root").size()
	assert_gt(roots, 0)
	assert_eq(Statuses.stacks_on(fight.units[1], "iron_garden"), roots, "every hero gains a stack for every Root any hero puts on an enemy")


func test_stillwater_seal_keeps_burn_on_held_enemies() -> void:
	var fight: CombatSim = _fight([K.at(_hero([], {"stats": {"atk": 0}}), 3, 2, "hero")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "dummy")] as Array[UnitSetup], ["stillwater_seal"])
	var dummy: UnitState = fight.units[1]
	Statuses.apply(fight, dummy, "burn", 40, 0, EffectSource.make("hero", "x", "X"))
	Statuses.apply(fight, dummy, "root", 1, 200, EffectSource.make("hero", "x", "X"))
	K.step(fight, 60)
	assert_eq(Statuses.stacks_on(dummy, "burn"), 40, "held: the Burn doesn't fade")
	Statuses.end_now(fight, dummy, Statuses.find(dummy, "root"), "test")
	K.step(fight, 20)
	assert_lt(Statuses.stacks_on(dummy, "burn"), 40, "free: it fades again")


# --- the shard caps (the tuning phase, Decisions 7 and 8) ----------------------

## Overkill counted as steps: one for any overkill, one more at 50% of the
## fallen's max HP, one more at 100%, whatever the numbers.
func test_overkill_steps_count_shares_of_max_hp() -> void:
	var hitter: UnitDef = _hero([], {"stats": {"atk": 100, "range": 6}, "basic_attack": {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}})
	var setup: UnitSetup = K.at(hitter, 3, 1, "hero")
	var errors: Array[String] = []
	setup.tally_keys.append("tithe")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"counts": "overkill", "steps_at_pct": [0, 50, 100]}, "count", errors), false))
	assert_eq(errors, [] as Array[String])
	# Overkill 10 of 90 (11%): 1; 40 of 60 (67%): 2; 60 of 40 (150%): 3.
	var fight: CombatSim = _fight([setup] as Array[UnitSetup], [K.foe(_dummy({"stats": {"hp": 90, "speed": 0, "range": 2}}, "a"), 1, 5, "a"),
		K.foe(_dummy({"stats": {"hp": 60, "speed": 0, "range": 2}}, "b"), 3, 5, "b"), K.foe(_dummy({"stats": {"hp": 40, "speed": 0, "range": 2}}, "c"), 5, 5, "c")] as Array[UnitSetup])
	K.step(fight, 20)
	assert_eq(fight.enemies.filter(func(unit: UnitState) -> bool: return not unit.alive).size(), 3, "each falls to one hit")
	assert_eq(CombatSim.result_of(fight).tally_amount("hero", "tithe"), 6, "1 + 2 + 3")


func test_a_growth_caps_its_steps_a_fight() -> void:
	var errors: Array[String] = []
	var growth: GrowthDef = GrowthDef.read(DataReader.new({"counts": {"counts": "crits"}, "per": 15, "each_shards": 1, "max_steps_per_fight": 5}, "grows", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq(growth.grown(0, 40), 40, "2 steps: under the cap")
	assert_eq(growth.grown(0, 300), 75, "20 steps' worth: 5 kept, the rest dropped")
	assert_eq(growth.grown(14, 300), 75 + 0, "from 14 (no step yet), 5 steps reach 75")
	assert_eq(growth.steps(growth.grown(80, 300)) - growth.steps(80), 5, "never more than 5 a fight")
