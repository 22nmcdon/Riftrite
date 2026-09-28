extends GutTest
## Flying and hop away (docs/plans/rebuild-phase1-arena-sim.md, section 6,
## decided).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _post(stats: Dictionary = {}, extra: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	var data: Dictionary = {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(extra, true)
	return K.kit("post", data)


func _flier(stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 2, "range": 1}
	all_stats.merge(stats, true)
	return K.kit("flier", {"traits": ["flying"], "stats": all_stats, "basic_attack": {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})


func _source() -> EffectSource:
	return EffectSource.make("tester", "test", "Test")


# --- flying ------------------------------------------------------------------------

func test_it_flies_straight_over_units_and_rocks() -> void:
	var rocks: Array[Vector2i] = []
	for col: int in 8:
		rocks.append(Vector2i(col, 3))
	var fight: CombatSim = K.sim(K.fight([K.at(_flier(), 3, 0)] as Array[UnitSetup], [K.foe(_post(), 3, 6)] as Array[UnitSetup], rocks))
	var flier: UnitState = fight.units[0]
	var x: int = flier.pos.x
	for i: int in 60:
		fight.step()
		assert_eq(flier.pos.x, x, "straight down the column, over the wall")
	assert_true(flier.in_reach_of(fight.units[1]))
	assert_false(flier.airborne, "in reach on a free spot: it has landed")
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "flier").size(), 0)
	assert_eq(K.entries(fight, LogEntry.Kind.STOP, "flier").back().note, "lands")


func test_others_move_as_if_it_werent_there_in_the_air() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_flier(), 3, 0), K.at(_post(), 5, 0, "friend")] as Array[UnitSetup], [K.foe(_post(), 3, 6)] as Array[UnitSetup]))
	var flier: UnitState = fight.units[0]
	var friend: UnitState = fight.unit_by_id("friend")
	fight.step()
	assert_true(flier.airborne)
	assert_true(fight.fits(friend, flier.pos), "its spot is free to the others")
	assert_false(fight.obstacles_for(friend, null).any(func(circle: ArenaPlane.Circle) -> bool: return circle.tag == "flier"))
	flier.airborne = false
	assert_false(fight.fits(friend, flier.pos), "landed, it blocks like anyone")


func test_it_lands_on_a_free_spot_still_in_reach() -> void:
	# Coming straight down, it's first in reach right on top of the guard.
	var fight: CombatSim = K.sim(K.fight([K.at(_flier(), 3, 0)] as Array[UnitSetup], [K.foe(_post(), 3, 5, "prey"), K.foe(_post(), 3, 4, "guard")] as Array[UnitSetup]))
	var flier: UnitState = fight.units[0]
	var prey: UnitState = fight.unit_by_id("prey")
	Targeting.set_target(fight, flier, prey, "test")
	var landed_at: int = -1
	for i: int in 80:
		fight.step()
		if landed_at < 0 and not flier.airborne and fight.tick > 1:
			landed_at = fight.tick
	assert_gt(landed_at, 0)
	assert_true(K.no_overlaps(fight), "it landed clear of everyone")
	assert_true(flier.in_reach_of(prey))
	var first_hit: LogEntry = K.entries(fight, LogEntry.Kind.DAMAGE, "flier")[0]
	assert_eq(first_hit.target, "prey")
	assert_true(first_hit.tick >= landed_at, "no attacking from the air while a spot could be found")


func test_landing_spots() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_flier(), 3, 0)] as Array[UnitSetup], [K.foe(_post(), 3, 5, "prey"), K.foe(_post(), 3, 4, "guard")] as Array[UnitSetup]), true)
	var flier: UnitState = fight.units[0]
	var prey: UnitState = fight.unit_by_id("prey")
	var guard: UnitState = fight.unit_by_id("guard")
	# The nearest free spot to the guard's center, with and without a reach.
	var anywhere: Vector2i = Displacement.free_spot_near(fight, flier, guard.pos, null, 0)
	var in_reach: Vector2i = Displacement.free_spot_near(fight, flier, guard.pos, prey, 850 * 850)
	assert_true(fight.fits(flier, anywhere) and fight.fits(flier, in_reach))
	assert_lte(ArenaPlane.length_sq(prey.pos - in_reach), 850 * 850)
	assert_ne(anywhere, in_reach, "the closest free spot isn't in reach of the prey")
	# A spot picked earlier that's no longer in reach is picked again.
	flier.pos = guard.pos
	flier.airborne = true
	flier.target = prey
	flier.settle_spot = guard.pos + Vector2i(0, -3000)
	flier.has_settle_spot = true
	assert_false(Movement.settle(fight, flier, prey))
	assert_lte(ArenaPlane.length_sq(prey.pos - flier.settle_spot), flier.reach_sq)
	# With no free spot anywhere near, it attacks from the air.
	var boxed: CombatSim = K.sim(K.fight([K.at(_flier(), 3, 0)] as Array[UnitSetup], [K.foe(_post(), 3, 5, "prey"), K.foe(_post(), 3, 4, "guard")] as Array[UnitSetup]))
	var hovering: UnitState = boxed.units[0]
	hovering.pos = boxed.unit_by_id("guard").pos
	hovering.airborne = true
	boxed.safe = Rect2i(hovering.pos - Vector2i(450, 450), Vector2i(900, 900))
	assert_true(Movement.settle(boxed, hovering, boxed.unit_by_id("prey")))
	assert_true(hovering.airborne)


func test_equally_near_goes_to_the_earlier() -> void:
	# (2, 5) and (4, 5) are as far from (3, 1).
	var fight: CombatSim = K.sim(K.fight([K.at(_flier(), 3, 1)] as Array[UnitSetup], [K.foe(_post(), 4, 5, "right"), K.foe(_post(), 2, 5, "left")] as Array[UnitSetup]))
	fight.step()
	assert_eq(fight.units[0].target.id, "right")


func test_a_pushed_flier_drops_clear() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_flier({"speed": 0}), 3, 4, "flier"), K.foe(_post(), 3, 5, "behind")] as Array[UnitSetup]))
	var flier: UnitState = fight.unit_by_id("flier")
	flier.airborne = true
	Displacement.knockback(fight, flier, fight.units[0].pos, 1, 1, _source())
	var push: LogEntry = K.entries(fight, LogEntry.Kind.PUSH)[0]
	assert_eq(push.note, "knocked back, dropped clear", "over the unit behind it, not stopped by it")
	assert_true(K.no_overlaps(fight))
	assert_false(Statuses.has_kind(flier, StatusDef.Kind.STUN), "no collision")
	assert_false(flier.airborne)


func test_it_picks_by_straight_line() -> void:
	# A wall makes "near" the longer walk, but a flier goes over it.
	var rocks: Array[Vector2i] = []
	for col: int in range(0, 6):
		rocks.append(Vector2i(col, 3))
	var fight: CombatSim = K.sim(K.fight([K.at(_flier(), 1, 2)] as Array[UnitSetup], [K.foe(_post(), 1, 4, "near"), K.foe(_post(), 7, 5, "far")] as Array[UnitSetup], rocks))
	fight.step()
	assert_eq(fight.units[0].target.id, "near")


func test_engage_still_holds_it() -> void:
	var tank: UnitDef = _post({}, {"traits": ["engage"]})
	var fight: CombatSim = K.sim(K.fight([K.at(_flier(), 6, 0)] as Array[UnitSetup], [K.foe(tank, 3, 4, "tank"), K.foe(_post(), 0, 6, "bait")] as Array[UnitSetup]))
	var flier: UnitState = fight.units[0]
	flier.pos = fight.unit_by_id("tank").pos - Vector2i(0, 900)
	Targeting.set_target(fight, flier, fight.unit_by_id("bait"), "test")
	var at: Vector2i = flier.pos
	K.step(fight, 10)
	assert_eq(flier.pos, at)
	assert_true(Statuses.find(flier, "engaged") != null)


# --- hop away -----------------------------------------------------------------------

func _hopper() -> UnitDef:
	return K.kit("hopper", {"traits": ["hop_away"], "hop_cooldown_ms": 3000, "stats": {"hp": 10000, "speed": 0, "range": 4},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func test_it_hops_a_hex_away_then_waits() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hopper(), 3, 1)] as Array[UnitSetup], [K.foe(_post(), 3, 5)] as Array[UnitSetup]))
	var hopper: UnitState = fight.units[0]
	var foe: UnitState = fight.units[1]
	foe.pos = hopper.pos + Vector2i(600, 800)
	var start: Vector2i = hopper.pos
	fight.step()
	var hop: LogEntry = K.entries(fight, LogEntry.Kind.HOP)[0]
	assert_eq(hopper.pos, ArenaPlane.along(start, ArenaPlane.direction(foe.pos, start), 1000), "straight away from it, a hex")
	assert_eq([hop.source_unit, hop.target, hop.from_pos, hop.note], ["hopper", "post", start, ""])
	assert_string_contains(hop.to_text(), "hopper hops away from post")
	foe.pos = hopper.pos + Vector2i(0, 900)
	K.step(fight, 59)
	assert_eq(K.entries(fight, LogEntry.Kind.HOP).size(), 1, "3s cooldown: the next hop is ready on tick 61")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.HOP).size(), 2)


func test_only_an_enemy_within_a_hex_and_the_nearest_one() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hopper(), 3, 1)] as Array[UnitSetup], [K.foe(_post(), 1, 5, "first"), K.foe(_post(), 5, 5, "second")] as Array[UnitSetup]))
	var hopper: UnitState = fight.units[0]
	fight.unit_by_id("first").pos = hopper.pos + Vector2i(0, 1500)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.HOP).size(), 0, "1.5 hexes away isn't close enough")
	fight.unit_by_id("first").pos = hopper.pos + Vector2i(-900, 300)
	fight.unit_by_id("second").pos = hopper.pos + Vector2i(820, 0)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.HOP)[0].target, "second", "away from the nearer one")


func test_no_room_means_no_hop() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hopper(), 3, 1)] as Array[UnitSetup], [K.foe(_post(), 3, 5)] as Array[UnitSetup]), true)
	var hopper: UnitState = fight.units[0]
	fight.units[1].pos = hopper.pos + Vector2i(0, 800)
	fight.safe = Rect2i(hopper.pos - Vector2i(400, 400), Vector2i(800, 2000))
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.HOP).size(), 0)
	assert_eq(hopper.hop_ready_at, 0, "and no cooldown spent")


func test_a_hop_is_cut_short_without_a_stun() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hopper(), 3, 1), K.at(_post(), 3, 0, "wall")] as Array[UnitSetup], [K.foe(_post(), 3, 5)] as Array[UnitSetup]))
	var hopper: UnitState = fight.units[0]
	fight.units[2].pos = hopper.pos + Vector2i(0, 900)
	fight.step()
	var hop: LogEntry = K.entries(fight, LogEntry.Kind.HOP)[0]
	assert_eq(hop.note, "cut short")
	assert_lt(ArenaPlane.distance(hop.from_pos, hop.to_pos), 1000)
	assert_false(Statuses.has_kind(hopper, StatusDef.Kind.STUN))
	assert_true(K.no_overlaps(fight))


func test_no_hop_while_an_engager_holds_it() -> void:
	var tank: UnitDef = _post({}, {"traits": ["engage"]})
	var fight: CombatSim = K.sim(K.fight([K.at(_hopper(), 6, 0)] as Array[UnitSetup], [K.foe(tank, 3, 4, "tank"), K.foe(_post(), 0, 6, "bait")] as Array[UnitSetup]))
	var hopper: UnitState = fight.units[0]
	hopper.pos = fight.unit_by_id("tank").pos - Vector2i(0, 900)
	Targeting.set_target(fight, hopper, fight.unit_by_id("bait"), "test")
	K.step(fight, 20)
	assert_eq(K.entries(fight, LogEntry.Kind.HOP).size(), 0, "held until it breaks free, on tick 21")
	assert_true(Statuses.find(hopper, "engaged") != null)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.BREAK_FREE).size(), 1)
	assert_eq(K.entries(fight, LogEntry.Kind.HOP).size(), 1, "then it hops away")
