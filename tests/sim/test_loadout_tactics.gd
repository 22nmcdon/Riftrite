extends GutTest
## The loadout's tactics in a fight (docs/plans/rebuild-phase5c-combos.md,
## step 6c, section 14.6): each new order, the payoffs, and rank III's
## twists, in tiny fights, with the tactics as the data has them.

const K = preload("res://tests/sim/sim_test_kit.gd")
const T = preload("res://tests/sim/test_tactics.gd")


func _tactic(tactic_id: String, rank: int = 1) -> TacticDef:
	return K.content().tactics[tactic_id].at_rank(rank)


func _hero(hero_id: String = "hero", stats: Dictionary = {}, extra: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 2000, "atk": 10, "speed": 2, "range": 5}
	all_stats.merge(stats, true)
	var kit: Dictionary = {"stats": all_stats, "basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}}
	kit.merge(extra, true)
	return K.kit(hero_id, kit)


func _with(setup: UnitSetup, tactic_id: String, rank: int = 1) -> UnitSetup:
	setup.tactic = _tactic(tactic_id, rank)
	return setup


func _target(fight: CombatSim, unit_id: String) -> String:
	var unit: UnitState = fight.unit_by_id(unit_id)
	return unit.target.id if unit.target != null else ""


func test_fliers_first_and_its_grounding() -> void:
	var flier: UnitDef = T.archer("bat", "swarm", 1, {"traits": ["flying"]})
	var fight: CombatSim = K.sim(K.fight([_with(K.at(_hero(), 3, 1), "fliers_first", 3)] as Array[UnitSetup],
		[K.foe(T.archer("pup", "swarm", 1), 3, 4), K.foe(flier, 5, 6)] as Array[UnitSetup]))
	K.step(fight, 2)
	assert_eq(_target(fight, "hero"), "bat", "the flier, though the pup is nearer")
	for i: int in 60:
		fight.step()
	var grounded: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").filter(func(entry: LogEntry) -> bool: return entry.status == "grounded")
	assert_eq(grounded.size(), 1, "its first hit grounds it, once")
	assert_eq(grounded[0].source_ability, "fliers_first")


func test_marked_first_picks_marked_and_crits_more() -> void:
	var fight: CombatSim = K.sim(K.fight([_with(K.at(_hero(), 3, 1), "marked_first", 2)] as Array[UnitSetup],
		[K.foe(T.archer("near", "swarm", 1), 3, 4), K.foe(T.archer("marked", "swarm", 1), 5, 6)] as Array[UnitSetup]))
	var marked: UnitState = fight.unit_by_id("marked")
	Statuses.apply(fight, marked, "marked", 1, 200, EffectSource.make("near", "x", "X"))
	K.step(fight, 2)
	assert_eq(_target(fight, "hero"), "marked")
	var hero: UnitState = fight.unit_by_id("hero")
	assert_eq(EffectRunner.crit_chance_bp(fight, hero, hero.def.basic_attack, marked) - EffectRunner.crit_chance_bp(fight, hero, hero.def.basic_attack, fight.unit_by_id("near")), 2000)


func test_finish_them_picks_the_weakest_in_reach_and_gives_mana_on_a_kill() -> void:
	var hero: UnitDef = _hero("hero", {}, {"mana": {"max": 100, "start": 0}, "signature": {"id": "sig", "name": "Sig", "trigger": {"kind": "mana"}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([_with(K.at(hero, 3, 1), "finish_them", 3)] as Array[UnitSetup],
		[K.foe(T.archer("a", "swarm", 1), 3, 4), K.foe(T.archer("b", "swarm", 1), 4, 4), K.foe(T.archer("far", "swarm", 1), 0, 6)] as Array[UnitSetup]))
	fight.unit_by_id("b").hp = 100
	fight.unit_by_id("far").hp = 10
	K.step(fight, 2)
	assert_eq(_target(fight, "hero"), "b", "the weakest in reach (the one far off, weaker, isn't in reach)")
	var unit: UnitState = fight.unit_by_id("hero")
	var before: int = unit.mana
	fight.unit_by_id("b").hp = 1
	EffectRunner.deal_hit(fight, EffectSource.make("hero", "hero_attack", "Strike"), fight.unit_by_id("b"), 10, false)
	fight.step()
	assert_gte(unit.mana - before, 10 * Mana.SCALE, "+10 mana on the kill")


func test_break_the_line_picks_the_most_def_ignores_it_and_sunders_once() -> void:
	var tough: UnitDef = T.archer("tough", "brute", 1, {"stats": {"hp": 5000, "def": 50, "speed": 2, "range": 1}})
	var fight: CombatSim = K.sim(K.fight([_with(K.at(_hero(), 3, 1), "break_the_line", 3)] as Array[UnitSetup],
		[K.foe(T.archer("soft", "swarm", 1), 3, 4), K.foe(tough, 5, 6)] as Array[UnitSetup]))
	K.step(fight, 2)
	assert_eq(_target(fight, "hero"), "tough")
	var hero: UnitState = fight.unit_by_id("hero")
	assert_eq(Tactics.def_ignore_bp(hero, fight.unit_by_id("tough")), 3500)
	assert_eq(Tactics.def_ignore_bp(hero, fight.unit_by_id("soft")), 0, "only on its target")
	for i: int in 80:
		fight.step()
	var sunders: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").filter(func(entry: LogEntry) -> bool: return entry.status == "sunder")
	assert_eq(sunders.size(), 1, "its first hit only")
	assert_eq(sunders[0].amount, 10)


func test_guard_the_weakest_goes_for_its_attacker() -> void:
	var guard: UnitSetup = _with(K.at(_hero("guard"), 3, 1, "guard"), "guard_the_weakest", 3)
	var ward: UnitSetup = K.at(_hero("ward", {"range": 1}), 1, 2, "ward")
	var fight: CombatSim = K.sim(K.fight([guard, ward] as Array[UnitSetup],
		[K.foe(T.archer("near", "swarm", 1), 3, 4), K.foe(T.archer("biter", "swarm", 6), 0, 6)] as Array[UnitSetup]))
	fight.unit_by_id("ward").hp = 100
	Targeting.set_target(fight, fight.unit_by_id("biter"), fight.unit_by_id("ward"), "test")
	K.step(fight, 2)
	assert_eq(_target(fight, "guard"), "biter", "the one attacking its weakest ally")
	assert_true(Tactics.applies(fight, fight.unit_by_id("guard")))
	K.step(fight, 25)
	assert_ne(Statuses.find(fight.unit_by_id("ward"), "watched_over"), null, "rank III: the ward is watched over")


func test_keep_your_distance_backs_away() -> void:
	var kiter: UnitSetup = _with(K.at(_hero("kiter", {"range": 4}, {"basic_attack": {"cooldown_ms": 5000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}), 3, 2, "kiter"), "keep_your_distance", 3)
	var fight: CombatSim = K.sim(K.fight([kiter] as Array[UnitSetup], [K.foe(T.archer("pup", "swarm", 1, {"stats": {"hp": 5000, "speed": 0, "range": 1}}), 3, 4)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("kiter")
	var start: Vector2i = unit.pos
	K.step(fight, 20)
	assert_gt(ArenaPlane.distance(unit.pos, fight.unit_by_id("pup").pos), ArenaPlane.distance(start, fight.unit_by_id("pup").pos), "it backed off")
	assert_true(K.entries(fight, LogEntry.Kind.TACTIC, "kiter").any(func(entry: LogEntry) -> bool: return entry.note.begins_with("backs away")))
	assert_true(unit.sure_crit, "rank III: its next attack crits")


func test_stay_with_the_tank_goes_back_to_it() -> void:
	var tank: UnitSetup = K.at(_hero("tank", {"def": 50, "speed": 0, "range": 1}), 0, 0, "tank")
	var follower: UnitSetup = _with(K.at(_hero("follower", {"range": 1}), 6, 2, "follower"), "stay_with_the_tank", 3)
	var fight: CombatSim = K.sim(K.fight([tank, follower] as Array[UnitSetup], [K.foe(T.archer("pup", "swarm", 1, {"stats": {"hp": 5000, "speed": 0, "range": 1}}), 7, 6)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("follower")
	var start: int = ArenaPlane.distance(unit.pos, fight.unit_by_id("tank").pos)
	K.step(fight, 40)
	assert_lt(ArenaPlane.distance(unit.pos, fight.unit_by_id("tank").pos), start, "toward the tank, not the enemy")
	assert_true(K.entries(fight, LogEntry.Kind.TACTIC, "follower").any(func(entry: LogEntry) -> bool: return entry.note == "goes back to tank"))


func test_dive_picks_the_farthest_with_a_window() -> void:
	var fight: CombatSim = K.sim(K.fight([_with(K.at(_hero(), 3, 1), "dive")] as Array[UnitSetup],
		[K.foe(T.archer("near", "swarm", 1), 3, 4), K.foe(T.archer("far", "swarm", 1), 7, 6)] as Array[UnitSetup]))
	K.step(fight, 2)
	assert_eq(_target(fight, "hero"), "far")
	var hero: UnitState = fight.unit_by_id("hero")
	var atk: int = hero.stats.get_stat(UnitStats.Stat.ATK)
	assert_true(Tactics.applies(fight, hero))
	K.step(fight, 100)
	assert_false(Tactics.applies(fight, hero), "after 5s")
	assert_lt(hero.stats.get_stat(UnitStats.Stat.ATK), atk, "the ATK goes with it")


func _caster(signature: Dictionary) -> UnitDef:
	return _hero("hero", {"range": 6}, {"mana": {"max": 10, "start": 10}, "signature": signature})


func test_wait_for_a_crowd() -> void:
	var blast: Dictionary = {"id": "blast", "name": "Blast", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 6,
		"effects": [{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies", "effects": [{"type": "damage", "amount": 5, "target": "target"}]}]}
	var foes: Array[UnitSetup] = [K.foe(T.archer("a", "swarm", 1, {"stats": {"hp": 5000, "speed": 0, "range": 1}}), 3, 4),
		K.foe(T.archer("b", "swarm", 1, {"stats": {"hp": 5000, "speed": 0, "range": 1}}), 7, 6), K.foe(T.archer("c", "swarm", 1, {"stats": {"hp": 5000, "speed": 0, "range": 1}}), 0, 6)]
	var fight: CombatSim = K.sim(K.fight([_with(K.at(_caster(blast), 3, 1), "wait_for_a_crowd")] as Array[UnitSetup], foes))
	K.step(fight, 20)
	assert_eq(T.fires(fight, "hero", "blast"), 0, "nobody's bunched up: it waits")
	K.step(fight, 70)
	assert_eq(T.fires(fight, "hero", "blast"), 1, "4s at most")
	var hits: Array = K.entries(fight, LogEntry.Kind.DAMAGE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "blast")
	assert_false(hits.is_empty())
	assert_eq(hits[0].bonus, "+20% from Wait for a crowd", "its payoff, named on the hit")


func test_save_it_for_the_kill() -> void:
	var shot: Dictionary = {"id": "snipe", "name": "Snipe", "trigger": {"kind": "mana"}, "targeting": "nearest", "max_range": 6,
		"effects": [{"type": "damage", "amount": 5, "target": "target"}]}
	var fight: CombatSim = K.sim(K.fight([_with(K.at(_caster(shot), 3, 1), "save_it_for_the_kill")] as Array[UnitSetup],
		[K.foe(T.archer("a", "swarm", 1, {"stats": {"hp": 5000, "speed": 0, "range": 1}}), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 20)
	assert_eq(T.fires(fight, "hero", "snipe"), 0, "its target is healthy: it waits")
	fight.unit_by_id("a").hp = 2000
	K.step(fight, 5)
	assert_eq(T.fires(fight, "hero", "snipe"), 1, "below half: it fires")


func test_hold_your_ground_keeps_half_after_letting_go() -> void:
	var hold: TacticDef = _tactic("hold_ground", 3)
	assert_eq([hold.atsp_bp, hold.keep_bp], [3500, 5000])
	var plain: CombatSim = K.sim(K.fight([_with(K.at(_hero("hero", {"range": 1}), 3, 2), "hold_ground", 2)] as Array[UnitSetup], [K.foe(T.archer("a", "swarm", 1), 3, 4)] as Array[UnitSetup]))
	var kept: CombatSim = K.sim(K.fight([_with(K.at(_hero("hero", {"range": 1}), 3, 2), "hold_ground", 3)] as Array[UnitSetup], [K.foe(T.archer("a", "swarm", 1), 3, 4)] as Array[UnitSetup]))
	K.step(plain, 600)
	K.step(kept, 600)
	assert_gt(K.entries(kept, LogEntry.Kind.FIRE, "hero").size(), K.entries(plain, LogEntry.Kind.FIRE, "hero").size(), "it attacks faster after moving out")


func test_plant_your_feet_gains_def_while_stopped() -> void:
	var fight: CombatSim = K.sim(K.fight([_with(K.at(_hero("hero", {"def": 5, "range": 1}), 3, 2), "plant_feet")] as Array[UnitSetup],
		[K.foe(T.archer("a", "swarm", 1, {"stats": {"hp": 5000, "speed": 0, "range": 1}}), 3, 4)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	assert_eq(hero.stats.get_stat(UnitStats.Stat.DEF), 5)
	K.step(fight, 3)
	assert_true(hero.feet_planted)
	assert_eq(hero.stats.get_stat(UnitStats.Stat.DEF), 15, "+10 DEF while stopped")


func test_wait_to_heal_cleanses_one() -> void:
	var mend: Dictionary = {"id": "mend", "name": "Mend", "trigger": {"kind": "mana"}, "targeting": "lowest_hp_ally", "max_range": 6,
		"effects": [{"type": "heal", "amount": 5, "target": "target"}]}
	var healer: UnitSetup = _with(K.at(_caster(mend), 3, 0), "wait_to_heal", 3)
	var hurt: UnitSetup = K.at(_hero("hurt", {"speed": 0}), 3, 1, "hurt")
	var fight: CombatSim = K.sim(K.fight([healer, hurt] as Array[UnitSetup], [K.foe(T.archer("a", "swarm", 1, {"stats": {"hp": 5000, "speed": 0, "range": 1}}), 3, 6)] as Array[UnitSetup]))
	fight.unit_by_id("hurt").hp = 100
	Statuses.apply(fight, fight.unit_by_id("hurt"), "root", 1, 200, EffectSource.make("a", "x", "X"))
	K.step(fight, 3)
	assert_null(Statuses.find(fight.unit_by_id("hurt"), "root"), "the heal that waited took the Root off")
	assert_true(K.entries(fight, LogEntry.Kind.STATUS_ENDED).any(func(entry: LogEntry) -> bool: return entry.note == "cleansed by Wait to heal"))
