extends GutTest
## Knockback, pull, leap, and charge (docs/plans/rebuild-phase1-arena-sim.md,
## section 6, decided): exact directions, collisions that stun, landing
## spots, and the log.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _post(stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	return K.kit("post", {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A standing unit whose signature (fight_start unless given) has `effects`,
## reaching 6 hexes and landing at once (not a shot).
func _caster(effects: Array, trigger: Dictionary = {"kind": "fight_start"}, extra: Dictionary = {}, stats: Dictionary = {}) -> UnitDef:
	var signature: Dictionary = {"id": "move", "name": "Move", "trigger": trigger, "max_range": 6, "shot": false, "effects": effects}
	signature.merge(extra, true)
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	var data: Dictionary = {"stats": all_stats, "signature": signature,
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	if trigger["kind"] == "mana":
		data["mana"] = {"max": 10, "start": 10}
	return K.kit("caster", data)


func _fight(hero: UnitDef, enemies: Array[UnitSetup], rocks: Array[Vector2i] = []) -> CombatSim:
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], enemies, rocks))


func _source() -> EffectSource:
	return EffectSource.make("tester", "test", "Test")


func _stunned(unit: UnitState) -> bool:
	return Statuses.has_kind(unit, StatusDef.Kind.STUN)


# --- knockback and pull ----------------------------------------------------------------

func test_knockback_goes_straight_away_exactly() -> void:
	var fight: CombatSim = _fight(_caster([{"type": "knockback", "hexes": 2, "target": "target"}]), [K.foe(_post(), 4, 4)] as Array[UnitSetup])
	var hero: UnitState = fight.units[0]
	var foe: UnitState = fight.units[1]
	var start: Vector2i = foe.pos
	var dir: Vector2i = ArenaPlane.direction(hero.pos, start)
	fight.step()
	assert_eq(foe.pos, ArenaPlane.along(start, dir, 2000), "2 hexes along the line from the hero, no snapping")
	var push: LogEntry = K.entries(fight, LogEntry.Kind.PUSH)[0]
	assert_eq([push.source_unit, push.target, push.from_pos, push.to_pos, push.note], ["caster", "post", start, foe.pos, "knocked back"])
	assert_false(_stunned(foe), "nothing in the way: no stun")
	assert_string_contains(push.to_text(), "caster · Move: post is knocked back from")


func test_a_push_stopped_by_a_unit_stuns_both() -> void:
	var fight: CombatSim = _fight(_caster([{"type": "knockback", "hexes": 2, "target": "target"}]),
		[K.foe(_post(), 3, 4, "front"), K.foe(_post(), 3, 5, "behind")] as Array[UnitSetup])
	var front: UnitState = fight.unit_by_id("front")
	var behind: UnitState = fight.unit_by_id("behind")
	var start: Vector2i = front.pos
	fight.step()
	assert_eq(front.pos.x, start.x)
	assert_between(front.pos.y - start.y, 750, 800, "stopped at the last clear point, touching the unit behind (1000 apart, less two radii)")
	assert_false(ArenaPlane.overlaps(front.pos, front.radius, behind.pos, behind.radius))
	assert_true(_stunned(front))
	assert_true(_stunned(behind), "the unit it hit too")
	assert_eq(Statuses.find(front, "stun").ends_at, 1 + 20, "for collision_stun_ms")
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH)[0].note, "knocked back, stopped by behind")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED)[0].source_unit, "caster", "the stun is credited to the push")


func test_rocks_and_the_edge_stop_a_push_too() -> void:
	var rocky: CombatSim = _fight(_caster([{"type": "knockback", "hexes": 3, "target": "target"}]), [K.foe(_post(), 3, 4)] as Array[UnitSetup], [Vector2i(3, 5)] as Array[Vector2i])
	rocky.step()
	assert_eq(K.entries(rocky, LogEntry.Kind.PUSH)[0].note, "knocked back, stopped by a rock")
	assert_true(_stunned(rocky.units[1]))
	var edge: CombatSim = _fight(_caster([{"type": "knockback", "hexes": 3, "target": "target"}]), [K.foe(_post(), 3, 5)] as Array[UnitSetup])
	edge.step()
	var foe: UnitState = edge.units[1]
	assert_eq(K.entries(edge, LogEntry.Kind.PUSH)[0].note, "knocked back, stopped by the arena's edge")
	assert_true(ArenaPlane.inside(edge.grid.bounds(), foe.pos, foe.radius))
	assert_true(_stunned(foe))


func test_pull_stops_touching_the_puller() -> void:
	var fight: CombatSim = _fight(_caster([{"type": "pull", "hexes": 5, "target": "target"}]), [K.foe(_post(), 3, 5)] as Array[UnitSetup])
	var hero: UnitState = fight.units[0]
	var foe: UnitState = fight.units[1]
	fight.step()
	assert_eq(ArenaPlane.distance(hero.pos, foe.pos), 200, "touching (two radii), not overlapping")
	assert_false(_stunned(foe), "stopping at the puller isn't a collision")
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH)[0].note, "pulled")
	var short: CombatSim = _fight(_caster([{"type": "pull", "hexes": 1, "target": "target"}]), [K.foe(_post(), 3, 5)] as Array[UnitSetup])
	var from: Vector2i = short.units[1].pos
	short.step()
	assert_eq(from - short.units[1].pos, Vector2i(0, 1000), "1 hex toward the puller")


func test_a_pushed_walker_loses_its_path() -> void:
	var walker: UnitDef = K.kit("walker", {"stats": {"hp": 10000, "speed": 2, "range": 1}})
	var fight: CombatSim = K.sim(K.fight([K.at(walker, 3, 0)] as Array[UnitSetup], [K.foe(_post(), 3, 6)] as Array[UnitSetup]))
	K.step(fight, 5)
	var unit: UnitState = fight.units[0]
	assert_true(unit.leg_active)
	Displacement.knockback(fight, unit, unit.pos + Vector2i(1000, 0), 1, 1, _source())
	assert_false(unit.leg_active)
	assert_eq(unit.route.size(), 0)
	assert_eq(unit.replan_at, fight.tick + 1)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE).back().from_pos, unit.pos - (unit.pos - K.entries(fight, LogEntry.Kind.PUSH)[0].to_pos), "a new leg from where it was pushed")


func test_same_point_pushes_go_forward() -> void:
	var fight: CombatSim = _fight(_post(), [K.foe(_post(), 3, 5)] as Array[UnitSetup])
	var foe: UnitState = fight.units[1]
	var start: Vector2i = foe.pos
	Displacement.knockback(fight, foe, foe.pos, -1, 1, _source())
	assert_eq(foe.pos, start - Vector2i(0, 1000), "an enemy's forward is up the board")


func test_a_push_ends_an_engagement() -> void:
	var tank: UnitDef = K.kit("tank", {"traits": ["engage"], "stats": {"hp": 10000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var walker: UnitDef = K.kit("walker", {"stats": {"hp": 10000, "speed": 2, "range": 1}})
	var fight: CombatSim = K.sim(K.fight([K.at(walker, 6, 0)] as Array[UnitSetup], [K.foe(tank, 3, 4, "tank"), K.foe(_post(), 0, 6, "bait")] as Array[UnitSetup]))
	var unit: UnitState = fight.units[0]
	unit.pos = fight.unit_by_id("tank").pos - Vector2i(0, 900)
	Targeting.set_target(fight, unit, fight.unit_by_id("bait"), "test")
	K.step(fight, 3)
	assert_eq(unit.engagements.size(), 1)
	Displacement.push(fight, unit, Vector2i(0, -ArenaPlane.DIR), 50, _source(), "nudged")
	assert_eq(unit.engagements.size(), 1, "still within a hex: still engaged")
	Displacement.knockback(fight, unit, fight.unit_by_id("tank").pos, 1, 1, _source())
	assert_eq(unit.engagements.size(), 0, "at once")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_ENDED)[0].note, "moved out of reach of tank")


# --- leap -------------------------------------------------------------------------

func test_a_leap_lands_on_the_closest_free_spot() -> void:
	var pouncer: UnitDef = _caster([{"type": "leap", "max_hexes": 6, "target": "target"}, {"type": "damage", "amount": 7, "target": "target"}], {"kind": "fight_start"}, {}, {"range": 1})
	var fight: CombatSim = _fight(pouncer, [K.foe(_post(), 3, 6)] as Array[UnitSetup])
	var hero: UnitState = fight.units[0]
	var foe: UnitState = fight.units[1]
	fight.step()
	assert_eq(hero.pos, foe.pos - Vector2i(0, 200), "the spot facing it, touching: straight up from the target")
	var leap: LogEntry = K.entries(fight, LogEntry.Kind.LEAP)[0]
	assert_eq([leap.tick, leap.end_tick, leap.target, leap.to_pos], [1, 1 + 6, "post", hero.pos])
	var hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "caster")[0]
	assert_eq([hit.tick, hit.amount], [1, 7], "then the hit lands at once: a leaping ability is never a shot")
	assert_eq(K.entries(fight, LogEntry.Kind.SHOT).size(), 0)


func test_a_leaping_ability_is_never_a_shot() -> void:
	var pouncer: UnitDef = _caster([{"type": "leap", "max_hexes": 6, "target": "target"}, {"type": "damage", "amount": 7, "target": "target"}])
	pouncer.signature.shot = -1
	assert_false(pouncer.signature.is_shot(6), "6 hexes of reach would make it a shot")
	var fight: CombatSim = _fight(pouncer, [K.foe(_post(), 3, 6)] as Array[UnitSetup])
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "caster")[0].tick, 1)


func test_it_cant_act_while_landing() -> void:
	var pouncer: UnitDef = _caster([{"type": "leap", "max_hexes": 6, "land_ms": 500, "target": "target"}], {"kind": "fight_start"}, {}, {"range": 1})
	pouncer.basic_attack.cooldown_ticks = 1
	var fight: CombatSim = _fight(pouncer, [K.foe(_post(), 3, 6)] as Array[UnitSetup])
	K.step(fight, 10)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "caster").filter(func(entry: LogEntry) -> bool: return entry.source_ability != "move").size(), 0, "landing until tick 11")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "caster").back().tick, 11)


func test_a_leap_skips_taken_spots_and_can_fail() -> void:
	var fight: CombatSim = _fight(_post(), [K.foe(_post(), 3, 6, "prey"), K.foe(_post(), 0, 6, "guard")] as Array[UnitSetup])
	var hero: UnitState = fight.units[0]
	var prey: UnitState = fight.unit_by_id("prey")
	assert_eq(Displacement.leap_spot(fight, hero, prey, 6), prey.pos - Vector2i(0, 200), "the spot facing the leaper")
	fight.unit_by_id("guard").pos = prey.pos - Vector2i(0, 200)
	var spot: Vector2i = Displacement.leap_spot(fight, hero, prey, 6)
	# The guard blocks that spot and the two on each side of it (the spots
	# are 30 degrees apart on a circle two radii round the prey, so the ones
	# at 60 degrees would just touch it); the next two are as close as each
	# other, and the first in the list wins.
	assert_eq(spot, prey.pos + Vector2i(200, 0))
	assert_true(fight.fits(hero, spot))
	# Too far to reach any spot: the whole signature fails, and waits.
	var far: CombatSim = _fight(_caster([{"type": "leap", "max_hexes": 1, "target": "target"}, {"type": "damage", "amount": 7, "target": "target"}]), [K.foe(_post(), 3, 6)] as Array[UnitSetup])
	K.step(far, 5)
	var failed: Array[LogEntry] = K.entries(far, LogEntry.Kind.LEAP)
	assert_eq(failed.size(), 1, "logged once, not every tick it waits")
	assert_eq(failed[0].to_text(), "[0.05s] caster · Move can't leap to post (no room to land)")
	assert_eq(K.entries(far, LogEntry.Kind.DAMAGE).size(), 0, "nothing else in it happened")
	assert_eq(K.entries(far, LogEntry.Kind.FIRE).size(), 0)
	far.units[0].pos = far.units[1].pos - Vector2i(0, 1100)
	far.step()
	assert_eq(K.entries(far, LogEntry.Kind.LEAP).size(), 2, "it fires once there's room")


func test_a_new_failure_is_logged_after_a_success() -> void:
	var fight: CombatSim = _fight(_caster([{"type": "leap", "max_hexes": 1, "target": "target"}], {"kind": "mana"}), [K.foe(_post(), 3, 6)] as Array[UnitSetup])
	var hero: UnitState = fight.units[0]
	var foe: UnitState = fight.units[1]
	K.step(fight, 3)
	hero.pos = foe.pos - Vector2i(0, 1100)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.LEAP).map(func(entry: LogEntry) -> String: return entry.note), ["no room to land", ""])
	hero.pos = foe.pos - Vector2i(0, 3000)
	hero.mana = hero.mana_cap
	K.step(fight, 8)
	assert_eq(K.entries(fight, LogEntry.Kind.LEAP).size(), 3, "once it has landed, failing again is news again")


func test_a_failed_leap_keeps_the_mana() -> void:
	var fight: CombatSim = _fight(_caster([{"type": "leap", "max_hexes": 1, "target": "target"}], {"kind": "mana"}), [K.foe(_post(), 3, 6)] as Array[UnitSetup])
	K.step(fight, 3)
	assert_true(Mana.is_full(fight.units[0]))
	var cast: CombatSim = _fight(_caster([{"type": "leap", "max_hexes": 1, "target": "target"}], {"kind": "mana"}, {"cast_ms": 100}), [K.foe(_post(), 3, 6)] as Array[UnitSetup])
	K.step(cast, 5)
	assert_true(Mana.is_full(cast.units[0]), "nor when a cast ends in one")


# --- charge -------------------------------------------------------------------------

func test_a_charge_stops_at_the_first_unit_and_knocks_back_an_enemy() -> void:
	var charger: UnitDef = _caster([{"type": "charge", "hexes": 5, "knockback": 1, "target": "target"}])
	var fight: CombatSim = _fight(charger, [K.foe(_post(), 3, 5, "far"), K.foe(_post(), 3, 4, "near")] as Array[UnitSetup])
	var hero: UnitState = fight.units[0]
	var near: UnitState = fight.unit_by_id("near")
	Targeting.set_target(fight, hero, fight.unit_by_id("far"), "test")
	var near_start: Vector2i = near.pos
	fight.step()
	var charge: LogEntry = K.entries(fight, LogEntry.Kind.CHARGE)[0]
	assert_eq([charge.target, charge.note], ["near", "reached near"], "the signature picked the nearest enemy")
	var push: LogEntry = K.entries(fight, LogEntry.Kind.PUSH)[0]
	assert_eq([push.target, push.from_pos], ["near", near_start])
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH).size(), 1)


func test_a_charge_goes_up_to_its_hexes_and_spares_allies() -> void:
	var charger: UnitDef = _caster([{"type": "charge", "hexes": 1, "knockback": 2, "target": "target"}])
	var fight: CombatSim = _fight(charger, [K.foe(_post(), 3, 6)] as Array[UnitSetup])
	var start: Vector2i = fight.units[0].pos
	fight.step()
	assert_eq(fight.units[0].pos - start, Vector2i(0, 1000), "1 hex, then it stops short")
	assert_eq(K.entries(fight, LogEntry.Kind.CHARGE)[0].note, "")
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH).size(), 0, "it touched no one")
	var reaching: CombatSim = _fight(_caster([{"type": "charge", "hexes": 5, "target": "target"}]), [K.foe(_post(), 3, 5)] as Array[UnitSetup])
	reaching.step()
	assert_eq(ArenaPlane.distance(reaching.units[0].pos, reaching.units[1].pos), 200, "touching")
	assert_eq(K.entries(reaching, LogEntry.Kind.CHARGE)[0].note, "reached post")
	assert_eq(K.entries(reaching, LogEntry.Kind.PUSH).size(), 0, "no knockback set")
	# An ally in the way stops it, unharmed.
	var friend: CombatSim = K.sim(K.fight([K.at(_caster([{"type": "charge", "hexes": 5, "knockback": 2, "target": "target"}]), 3, 0), K.at(_post(), 3, 1, "friend")] as Array[UnitSetup],
		[K.foe(_post(), 3, 5)] as Array[UnitSetup]))
	friend.step()
	assert_eq(K.entries(friend, LogEntry.Kind.CHARGE)[0].note, "stopped by friend")
	assert_eq(K.entries(friend, LogEntry.Kind.PUSH).size(), 0)
	assert_false(_stunned(friend.units[0]), "a charge is its own move: no collision stun")


# --- data --------------------------------------------------------------------------

func test_the_rules_on_moving_effects() -> void:
	var errors: Array[String] = []
	EffectDef.read(DataReader.new({"type": "leap", "max_hexes": 3, "target": "all_enemies"}, "e", errors))
	EffectDef.read(DataReader.new({"type": "charge", "hexes": 3, "trigger": "on_hit", "target": "target"}, "e", errors))
	var passive: Array[String] = []
	PartDef.read(DataReader.new({"id": "p", "name": "P", "kind": "ability", "effects": [{"trigger": "on_kill", "type": "leap", "max_hexes": 2, "target": "target"}]}, "p", passive))
	var attack: Array[String] = []
	AbilityDef.read(DataReader.new({"id": "a", "name": "A", "cooldown_ms": 1000, "effects": [{"type": "charge", "hexes": 2, "target": "target"}]}, "a", attack))
	assert_true(errors.any(func(message: String) -> bool: return message.contains("leap moves the unit itself to its target")), str(errors))
	assert_true(errors.any(func(message: String) -> bool: return message.contains("charge moves the unit itself")), str(errors))
	assert_true(passive.has("p.effects[0]: a passive can't leap or charge (but for a leap back to the start, behind its target, or a step)"), str(passive))
	assert_true(attack.has("a: leap and charge are for signatures, not basic attacks"), str(attack))
	var good: Array[String] = []
	var leap: EffectDef = EffectDef.read(DataReader.new({"type": "leap", "max_hexes": 4, "land_ms": 250, "target": "target"}, "e", good))
	var charge: EffectDef = EffectDef.read(DataReader.new({"type": "charge", "hexes": 3, "knockback": 2, "target": "target"}, "e", good))
	var pull: EffectDef = EffectDef.read(DataReader.new({"type": "pull", "hexes": 2, "target": "all_enemies"}, "e", good))
	assert_eq(good, [] as Array[String])
	assert_eq([leap.hexes, leap.land_ticks, charge.hexes, charge.knockback_hexes, pull.hexes], [4, 5, 3, 2, 2])
