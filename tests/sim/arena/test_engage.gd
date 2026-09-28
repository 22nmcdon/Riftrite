extends GutTest
## The Engage trait (docs/plans/rebuild-phase1-arena-sim.md, section 4,
## decided): held 1s when trying to reach someone else, not when fighting the
## engager, free until contact ends, and caught again on coming back.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _post(extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 10000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(extra, true)
	return K.kit("post", data)


func _walker(stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 2, "range": 1}
	all_stats.merge(stats, true)
	return K.kit("walker", {"stats": all_stats, "basic_attack": {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})


## A walker set down right in front of an enemy engager (900 away), aiming
## for a post far off in the corner.
func _held_walker(walker: UnitDef = _walker()) -> CombatSim:
	var fight: CombatSim = K.sim(K.fight([K.at(walker, 6, 0)] as Array[UnitSetup],
		[K.foe(_post({"traits": ["engage"]}), 3, 4, "tank"), K.foe(_post(), 0, 6, "bait")] as Array[UnitSetup]))
	fight.units[0].pos = fight.unit_by_id("tank").pos - Vector2i(0, 900)
	Targeting.set_target(fight, fight.units[0], fight.unit_by_id("bait"), "test")
	return fight


func _engaged(fight: CombatSim) -> bool:
	return Statuses.find(fight.units[0], "engaged") != null


func test_held_for_1s_when_it_wants_someone_else() -> void:
	var fight: CombatSim = _held_walker()
	var at: Vector2i = fight.units[0].pos
	fight.step()
	var applied: LogEntry = K.entries(fight, LogEntry.Kind.STATUS_APPLIED)[0]
	assert_eq(applied.to_text(), "[0.05s] tank · Engage applies Engaged to walker")
	K.step(fight, 19)
	assert_eq(fight.units[0].pos, at, "held from tick 1 to 20")
	assert_true(_engaged(fight))
	fight.step()
	var freed: LogEntry = K.entries(fight, LogEntry.Kind.BREAK_FREE)[0]
	assert_eq([freed.tick, freed.to_text()], [21, "[1.05s] walker breaks free of tank"])
	assert_ne(fight.units[0].pos, at, "and walks on that tick")
	assert_false(_engaged(fight))
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_ENDED)[0].note, "broke free")


func test_fighting_the_engager_isnt_held() -> void:
	var fight: CombatSim = _held_walker()
	Targeting.set_target(fight, fight.units[0], fight.unit_by_id("tank"), "test")
	K.step(fight, 30)
	assert_false(_engaged(fight))
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 0)
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "walker").size(), 0, "it just fights")


func test_walking_to_the_engager_isnt_held() -> void:
	# With engage_reach wider than its reach, a unit can be next to an
	# engager and still need to walk to it.
	var fight: CombatSim = _held_walker()
	fight.tuning.engage_reach = 1500
	var walker: UnitState = fight.units[0]
	walker.pos = fight.unit_by_id("tank").pos - Vector2i(0, 1400)
	Targeting.set_target(fight, walker, fight.unit_by_id("tank"), "test")
	var at: Vector2i = walker.pos
	fight.step()
	assert_ne(walker.pos, at, "it walks straight in")
	assert_false(_engaged(fight))
	# Held on the way to someone else, then turned on the engager: it's let go.
	var turned: CombatSim = _held_walker()
	turned.tuning.engage_reach = 1500
	var held: UnitState = turned.units[0]
	held.pos = turned.unit_by_id("tank").pos - Vector2i(0, 1400)
	K.step(turned, 3)
	var stuck: Vector2i = held.pos
	assert_true(Statuses.find(held, "engaged") != null)
	Targeting.set_target(turned, held, turned.unit_by_id("tank"), "test")
	turned.step()
	assert_ne(held.pos, stuck, "no longer trying to get past it")


func test_a_held_unit_still_attacks_what_it_can_reach() -> void:
	# Held while it tries to walk to the bait; then the bait comes within its
	# range 2 (1.5 hexes away), and it attacks, still held.
	var fight: CombatSim = _held_walker(_walker({"range": 2}))
	K.step(fight, 2)
	assert_true(_engaged(fight))
	fight.unit_by_id("bait").pos = fight.units[0].pos + Vector2i(-1500, 0)
	K.step(fight, 10)
	assert_true(_engaged(fight))
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "walker")[0].target, "bait")
	# A unit that stands in reach of its target isn't trying to get past
	# anyone, so it's never held.
	var standing: CombatSim = _held_walker(_walker({"range": 2}))
	standing.unit_by_id("bait").pos = standing.units[0].pos + Vector2i(-1500, 0)
	K.step(standing, 12)
	assert_eq(K.entries(standing, LogEntry.Kind.STATUS_APPLIED).size(), 0)
	assert_eq(K.entries(standing, LogEntry.Kind.DAMAGE, "walker")[0].target, "bait")


func test_freedom_lasts_until_contact_ends() -> void:
	var fight: CombatSim = _held_walker()
	K.step(fight, 25)
	assert_eq(K.entries(fight, LogEntry.Kind.BREAK_FREE).size(), 1)
	# Still next to the tank for a few ticks: free all the same.
	assert_false(_engaged(fight))
	fight.units[0].pos = fight.unit_by_id("tank").pos - Vector2i(0, 1010)
	fight.step()
	assert_eq(fight.units[0].engagements.size(), 0, "just over a hex away: the engagement is over")
	fight.units[0].pos = fight.unit_by_id("tank").pos - Vector2i(0, 900)
	fight.step()
	assert_true(_engaged(fight), "back in contact, it's caught again")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).size(), 2)


func test_a_fallen_engager_lets_go() -> void:
	var fight: CombatSim = _held_walker()
	K.step(fight, 5)
	fight.unit_by_id("tank").hp = 0
	K.step(fight, 2)
	assert_false(_engaged(fight))
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_ENDED)[0].note, "tank fell")
	assert_eq(K.entries(fight, LogEntry.Kind.BREAK_FREE).size(), 0)
	assert_eq(fight.units[0].engagements.size(), 0)


func test_it_holds_only_enemies_and_each_engager_separately() -> void:
	# An ally of the engager is never held.
	var tank: UnitDef = _post({"traits": ["engage"]})
	var friends: CombatSim = K.sim(K.fight([K.at(tank, 3, 2), K.at(_walker(), 4, 2)] as Array[UnitSetup], [K.foe(_post(), 0, 6)] as Array[UnitSetup]))
	K.step(friends, 5)
	assert_eq(K.entries(friends, LogEntry.Kind.STATUS_APPLIED).size(), 0)
	# Two engagers: breaking free of one leaves it held by the other, whose
	# clock started later.
	var twice: CombatSim = K.sim(K.fight([K.at(_walker(), 6, 0)] as Array[UnitSetup],
		[K.foe(tank, 3, 4, "tank"), K.foe(tank, 6, 4, "tank2"), K.foe(_post(), 0, 6, "bait")] as Array[UnitSetup]))
	var walker: UnitState = twice.units[0]
	walker.pos = twice.unit_by_id("tank").pos - Vector2i(0, 900)
	Targeting.set_target(twice, walker, twice.unit_by_id("bait"), "test")
	twice.step()
	assert_eq(walker.engagements.size(), 1, "only the first tank is within a hex")
	twice.unit_by_id("tank2").pos = walker.pos + Vector2i(900, 0)
	K.step(twice, 5)
	assert_eq(walker.engagements.size(), 2)
	assert_eq(K.entries(twice, LogEntry.Kind.STATUS_APPLIED).size(), 1, "held by two, Engaged once")
	var at: Vector2i = walker.pos
	K.step(twice, 15)
	assert_eq(K.entries(twice, LogEntry.Kind.BREAK_FREE).map(func(entry: LogEntry) -> Array: return [entry.tick, entry.target]), [[21, "tank"]])
	assert_eq(walker.pos, at, "still held by tank2 until tick 22")
	assert_true(Statuses.find(walker, "engaged") != null)
	twice.step()
	assert_eq(K.entries(twice, LogEntry.Kind.BREAK_FREE).size(), 2)
	assert_ne(walker.pos, at)


func test_leaving_one_engager_leaves_it_held_by_the_other() -> void:
	var tank: UnitDef = _post({"traits": ["engage"]})
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 6, 0)] as Array[UnitSetup],
		[K.foe(tank, 3, 4, "tank"), K.foe(tank, 6, 4, "tank2"), K.foe(_post(), 0, 6, "bait")] as Array[UnitSetup]))
	var walker: UnitState = fight.units[0]
	walker.pos = fight.unit_by_id("tank").pos - Vector2i(0, 900)
	fight.unit_by_id("tank2").pos = walker.pos + Vector2i(900, 0)
	Targeting.set_target(fight, walker, fight.unit_by_id("bait"), "test")
	K.step(fight, 5)
	fight.unit_by_id("tank2").pos = Vector2i(6500, 7000)
	fight.step()
	assert_eq(walker.engagements.size(), 1)
	assert_true(Statuses.find(walker, "engaged") != null, "tank still holds it")


func test_engaging_sets_off_no_status_event() -> void:
	var tank: UnitDef = _post({"traits": ["engage"], "passives": [{"id": "glee", "name": "Glee", "kind": "ability",
		"effects": [{"trigger": "on_status", "type": "shield", "amount": 5, "target": "self"}]}]})
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 6, 0)] as Array[UnitSetup], [K.foe(tank, 3, 4, "tank"), K.foe(_post(), 0, 6, "bait")] as Array[UnitSetup]))
	fight.units[0].pos = fight.unit_by_id("tank").pos - Vector2i(0, 900)
	Targeting.set_target(fight, fight.units[0], fight.unit_by_id("bait"), "test")
	K.step(fight, 3)
	assert_true(_engaged(fight))
	assert_eq(fight.unit_by_id("tank").shield, 0, "Engaged comes from the trait, not an effect")


func test_engaged_is_only_the_traits() -> void:
	var errors: Array[String] = K.fight([K.at(_walker(), 3, 2)] as Array[UnitSetup],
		[K.foe(_post({"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "apply_status", "status": "engaged", "target": "target"}]}}), 3, 4)] as Array[UnitSetup]).validate(K.content())
	assert_true(errors.has("post at (3, 4) names \"engaged\", which only the Engage trait sets"), str(errors))
