extends GutTest
## Signatures and their triggers (docs/plans/rebuild-phase1-arena-sim.md,
## section 5): mana, hp_below, fight_start, at_time, count, would_fall;
## Stun holding back only mana signatures; casts; picking a target.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A standing unit (speed 0, range 2) whose signature is `signature` (a
## trigger, plus any other keys), with a mana bar if given.
func _hero(trigger: Dictionary, extra: Dictionary = {}, mana: Dictionary = {}, stats: Dictionary = {}) -> UnitDef:
	var signature: Dictionary = {"id": "burst", "name": "Burst", "trigger": trigger, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}
	signature.merge(extra, true)
	var all_stats: Dictionary = {"hp": 1000, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var data: Dictionary = {"stats": all_stats, "signature": signature,
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	if not mana.is_empty():
		data["mana"] = mana
	return K.kit("hero", data)


func _dummy(stats: Dictionary = {}, attack: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var basic: Dictionary = {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}
	basic.merge(attack, true)
	return K.kit("dummy", {"stats": all_stats, "basic_attack": basic})


func _duel(hero: UnitDef, enemy: UnitDef = null) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(enemy if enemy != null else _dummy(), 3, 4)] as Array[UnitSetup]))


func _fires(fight: CombatSim) -> Array:
	return K.entries(fight, LogEntry.Kind.FIRE, "hero").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "burst").map(func(entry: LogEntry) -> int: return entry.tick)


func _source() -> EffectSource:
	return EffectSource.make("tester", "test", "Test")


# --- mana ------------------------------------------------------------------------

func test_a_full_bar_fires_and_empties() -> void:
	var hero: UnitDef = _hero({"kind": "mana"}, {}, {"max": 10, "per_attack": 10}, {})
	hero.basic_attack.cooldown_ticks = 20
	var fight: CombatSim = _duel(hero)
	K.step(fight, 20)
	assert_eq(fight.units[0].mana, 1000, "its attack filled the bar")
	assert_eq(_fires(fight), [])
	fight.step()
	assert_eq(_fires(fight), [21], "it fires on its next turn")
	assert_eq(fight.units[0].mana, 0, "and the bar empties")
	var shot: LogEntry = K.entries(fight, LogEntry.Kind.SHOT, "hero").back()
	assert_eq(shot.source_ability, "burst", "2 hexes away, it flies")


func test_it_waits_for_a_target_in_reach() -> void:
	var fight: CombatSim = _duel(_hero({"kind": "mana"}, {"max_range": 1}, {"max": 10, "start": 10}))
	K.step(fight, 30)
	assert_eq(_fires(fight), [], "the only enemy is 2 hexes away")
	assert_true(Mana.is_full(fight.units[0]), "the bar stays full")
	fight.units[1].pos = fight.units[0].pos + Vector2i(0, 900)
	fight.step()
	assert_eq(_fires(fight), [31])


func test_stun_holds_back_only_a_mana_signature() -> void:
	var fight: CombatSim = _duel(_hero({"kind": "mana"}, {}, {"max": 10, "start": 10}))
	Statuses.apply(fight, fight.units[0], "stun", 1, 0, _source())
	K.step(fight, 19)
	assert_eq(_fires(fight), [], "stunned until tick 20")
	fight.step()
	assert_eq(_fires(fight), [20], "it fires as the stun ends")
	var last_stand: CombatSim = _duel(_hero({"kind": "hp_below", "threshold_bp": 3000}, {"targeting": "self", "effects": [{"type": "shield", "amount": 5, "target": "self"}]}))
	Statuses.apply(last_stand, last_stand.units[0], "stun", 1, 0, _source())
	last_stand.units[0].hp = 200
	last_stand.step()
	assert_eq(_fires(last_stand), [1], "an HP trigger fires while stunned")


# --- the other triggers ----------------------------------------------------------------

func test_hp_below_fires_once() -> void:
	var fight: CombatSim = _duel(_hero({"kind": "hp_below", "threshold_bp": 5000}, {"targeting": "self", "effects": [{"type": "shield", "amount": 5, "target": "target"}]}))
	var hero: UnitState = fight.units[0]
	hero.hp = 500
	fight.step()
	assert_eq(_fires(fight), [], "exactly half isn't below half")
	hero.hp = 499
	fight.step()
	assert_eq(_fires(fight), [2])
	assert_eq(hero.shield, 5, "self-targeted, so it lands at once (no shot at itself)")
	hero.hp = 100
	K.step(fight, 5)
	assert_eq(_fires(fight), [2], "once a fight")
	var felled: CombatSim = _duel(_hero({"kind": "hp_below", "threshold_bp": 5000}, {"targeting": "self", "effects": [{"type": "shield", "amount": 5, "target": "target"}]}))
	felled.units[0].hp = 0
	felled.step()
	assert_eq(_fires(felled), [], "at 0 HP it isn't standing below half: it falls")
	assert_false(felled.units[0].alive)


func test_fight_start_and_at_time() -> void:
	var start: CombatSim = _duel(_hero({"kind": "fight_start"}))
	K.step(start, 5)
	assert_eq(_fires(start), [1], "on its first turn")
	var timed: CombatSim = _duel(_hero({"kind": "at_time", "at_ms": 500}))
	K.step(timed, 30)
	assert_eq(_fires(timed), [10], "at 0.5s, once")


func test_count_fires_every_nth_event() -> void:
	var biter: UnitDef = _dummy({}, {"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 1, "target": "target"}]})
	var fight: CombatSim = _duel(_hero({"kind": "count", "event": "on_hit_taken", "every": 3}, {"targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "self"}]}), biter)
	K.step(fight, 10)
	assert_eq(_fires(fight), [4, 7, 10], "hit every tick; the 3rd hit is read at the end of its tick, and it fires on the next turn")
	var swinger: UnitDef = _hero({"kind": "count", "event": "on_basic_attack", "every": 2}, {"targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "target"}]})
	swinger.basic_attack = _dummy({}, {"cooldown_ms": 100}).basic_attack
	var swinging: CombatSim = _duel(swinger)
	K.step(swinging, 9)
	assert_eq(_fires(swinging), [5, 9], "every 2nd attack (ticks 2, 4, 6, 8)")
	var self_harm: UnitDef = _hero({"kind": "count", "event": "on_hit_taken"}, {"targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "target"}]})
	self_harm.basic_attack = _dummy({}, {"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 1, "target": "self"}]}).basic_attack
	var hurting: CombatSim = _duel(self_harm)
	K.step(hurting, 5)
	assert_eq(K.entries(hurting, LogEntry.Kind.DAMAGE, "hero").size(), 5)
	assert_eq(_fires(hurting), [], "its own hits on itself aren't hits taken")
	var killer: UnitDef = _hero({"kind": "count", "event": "on_kill"}, {"targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "self"}]})
	killer.basic_attack = _dummy({}, {"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 10, "target": "target"}]}).basic_attack
	var hunt: CombatSim = K.sim(K.fight([K.at(killer, 3, 2)] as Array[UnitSetup], [K.foe(_dummy({"hp": 10}), 3, 4), K.foe(_dummy(), 7, 6)] as Array[UnitSetup]))
	K.step(hunt, 3)
	assert_eq(_fires(hunt), [2], "the kill on tick 1 fires it on tick 2")


func test_would_fall_saves_once() -> void:
	var smasher: UnitDef = _dummy({}, {"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 500, "target": "target"}]})
	var fight: CombatSim = _duel(_hero({"kind": "would_fall"}, {"targeting": "self", "effects": [{"type": "apply_status", "status": "undying", "target": "self"}]}), smasher)
	var hero: UnitState = fight.units[0]
	hero.hp = 100
	fight.step()
	assert_true(hero.alive)
	assert_eq(hero.hp, 1, "left at 1 HP")
	assert_eq(_fires(fight), [1], "and the signature fired at once")
	var saved: LogEntry = K.entries(fight, LogEntry.Kind.SAVED)[0]
	assert_eq(saved.to_text(), "[0.05s] hero is held at 1 HP by hero · Burst (would fall)")
	K.step(fight, 19)
	assert_true(hero.alive, "Undying held it for 1s")
	assert_eq(K.entries(fight, LogEntry.Kind.SAVED).size(), 20)
	assert_eq(K.entries(fight, LogEntry.Kind.SAVED).back().note, "Undying")
	fight.step()
	assert_false(hero.alive, "then it falls: would_fall is once a fight")
	assert_eq(_fires(fight), [1])


func test_a_save_that_fells_someone_settles_this_tick() -> void:
	# The hero is earlier in the fight's order than the enemy whose save fells it.
	var hero: UnitDef = _dummy({"hp": 50}, {"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 500, "target": "target"}]})
	var avenger: UnitDef = _hero({"kind": "would_fall"}, {"shot": false, "effects": [{"type": "damage", "amount": 100, "target": "target"}]}, {}, {"hp": 100})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(avenger, 3, 4)] as Array[UnitSetup]))
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.DEATH).map(func(entry: LogEntry) -> Array: return [entry.tick, entry.target]), [[1, "dummy"]])
	assert_true(fight.finished)


# --- casts ----------------------------------------------------------------------

func test_a_cast_stands_still_then_lands() -> void:
	var fight: CombatSim = _duel(_hero({"kind": "mana"}, {"cast_ms": 500, "max_range": 3}, {"max": 10, "start": 10}, {"speed": 2, "range": 1}))
	var at: Vector2i = fight.units[0].pos
	fight.step()
	var cast: LogEntry = K.entries(fight, LogEntry.Kind.CAST, "hero")[0]
	assert_eq([cast.tick, cast.end_tick, cast.target], [1, 11, "dummy"])
	K.step(fight, 9)
	assert_eq(fight.units[0].pos, at, "it stands still while casting")
	assert_eq(_fires(fight), [])
	assert_true(Mana.is_full(fight.units[0]), "the mana is spent when it lands")
	fight.step()
	assert_eq(_fires(fight), [11])
	assert_eq(fight.units[0].mana, 0)
	fight.step()
	assert_ne(fight.units[0].pos, at, "then it walks again")


func test_a_cast_under_way_lands_though_its_mana_is_drained() -> void:
	var fight: CombatSim = _duel(_hero({"kind": "mana"}, {"cast_ms": 500}, {"max": 10, "start": 10}))
	K.step(fight, 3)
	Mana.drain(fight, fight.units[0], 10, _source())
	K.step(fight, 8)
	assert_eq(_fires(fight), [11], "the mana was committed when the cast began")
	assert_eq(fight.units[0].mana, 0)


func test_a_signature_that_stuns_its_unit_holds_it_that_tick() -> void:
	var walker: UnitDef = _hero({"kind": "fight_start"}, {"targeting": "self", "effects": [{"type": "apply_status", "status": "stun", "target": "target"}]}, {}, {"speed": 2, "range": 1})
	var fight: CombatSim = _duel(walker)
	var at: Vector2i = fight.units[0].pos
	fight.step()
	assert_eq(fight.units[0].pos, at, "stunned from the moment it fired")


func test_stun_cancels_a_cast_and_keeps_the_mana() -> void:
	var fight: CombatSim = _duel(_hero({"kind": "mana"}, {"cast_ms": 500}, {"max": 10, "start": 10}))
	K.step(fight, 5)
	Statuses.apply(fight, fight.units[0], "stun", 1, 0, _source())
	fight.step()
	var cancelled: LogEntry = K.entries(fight, LogEntry.Kind.CAST_CANCELLED)[0]
	assert_eq([cancelled.tick, cancelled.note], [6, "stunned"])
	assert_true(Mana.is_full(fight.units[0]))
	K.step(fight, 19)
	assert_eq(K.entries(fight, LogEntry.Kind.CAST, "hero").back().tick, 25, "it starts again once the stun ends")
	K.step(fight, 10)
	assert_eq(_fires(fight), [35])


func test_a_cast_whose_target_falls_picks_again() -> void:
	var hero: UnitDef = _hero({"kind": "mana"}, {"cast_ms": 500, "max_range": 3}, {"max": 10, "start": 10})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 4, 4, "first"), K.foe(_dummy(), 3, 4, "second")] as Array[UnitSetup]))
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.CAST, "hero")[0].target, "first")
	fight.unit_by_id("first").hp = 0
	K.step(fight, 10)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "hero").back().target, "second")
	var alone: CombatSim = _duel(_hero({"kind": "mana"}, {"cast_ms": 500}, {"max": 10, "start": 10}))
	alone.step()
	alone.units[1].pos = Vector2i(500, 7000)
	K.step(alone, 10)
	assert_eq(K.entries(alone, LogEntry.Kind.CAST_CANCELLED)[0].note, "no target")
	assert_true(Mana.is_full(alone.units[0]))


# --- targets --------------------------------------------------------------------

func test_nearest_in_a_straight_line_ties_to_fight_order() -> void:
	# (2, 4) and (4, 4) are exactly as far from (3, 2).
	var hero: UnitDef = _hero({"kind": "fight_start"}, {"max_range": 3})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 4, 4, "right"), K.foe(_dummy(), 2, 4, "left")] as Array[UnitSetup]))
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "hero")[0].target, "right")
	# (4, 4) is 1.73 hexes away, (3, 4) 2.
	var closer: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(_dummy(), 3, 4, "ahead"), K.foe(_dummy(), 4, 4, "near")] as Array[UnitSetup]))
	closer.step()
	assert_eq(K.entries(closer, LogEntry.Kind.FIRE, "hero")[0].target, "near", "closer beats earlier")
