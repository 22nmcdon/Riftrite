extends GutTest
## Walking on the plane (docs/plans/rebuild-phase1-arena-sim.md, section 4).

const K = preload("res://tests/sim/sim_test_kit.gd")


## A melee walker (speed 2) and a target that never moves (speed 0).
func _walker(speed: int = 2, reach: int = 1) -> UnitDef:
	return K.kit("walker", {"stats": {"hp": 10000, "speed": speed, "range": reach}})


func _post(hp: int = 10000) -> UnitDef:
	return K.kit("post", {"stats": {"hp": hp, "speed": 0}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func test_speed_is_hexes_per_second() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 3, 0)] as Array[UnitSetup], [K.foe(_post(), 3, 6)] as Array[UnitSetup]))
	var start: Vector2i = fight.units[0].pos
	fight.step()
	assert_eq(fight.units[0].pos, start + Vector2i(0, 100), "speed 2 is 100 a tick, straight at the target")
	K.step(fight, 19)
	assert_eq(fight.units[0].pos, start + Vector2i(0, 2000), "2 hexes in a second")
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "walker").size(), 1, "one straight leg")
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "post").size(), 0, "speed 0 never walks")
	assert_eq(fight.units[1].pos, fight.grid.center(3, 6))


func test_it_stops_once_in_reach() -> void:
	for reach: int in [1, 4]:
		var fight: CombatSim = K.sim(K.fight([K.at(_walker(2, reach), 3, 0)] as Array[UnitSetup], [K.foe(_post(), 3, 6)] as Array[UnitSetup]))
		K.step(fight, 100)
		var walker: UnitState = fight.units[0]
		var gap: int = ArenaPlane.distance(walker.pos, fight.units[1].pos)
		var units: int = 500 if reach == 1 else reach * 1000
		assert_between(gap, units - 100, units, "stops within reach %d (melee: half a hex), a step short at most" % reach)
		var stops: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STOP, "walker")
		assert_eq(stops.size(), 1)
		assert_eq([stops[0].to_pos, stops[0].note], [walker.pos, "in reach"])


func test_it_walks_around_a_wall() -> void:
	var rocks: Array[Vector2i] = []
	for col: int in 6:
		rocks.append(Vector2i(col, 3))
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 1, 1)] as Array[UnitSetup], [K.foe(_post(), 1, 5)] as Array[UnitSetup], rocks))
	for tick: int in 300:
		fight.step()
		assert_true(K.no_overlaps(fight), "no overlap at tick %d\n%s" % [fight.tick, ArenaDebug.render(fight)])
	assert_true(fight.units[0].in_reach_of(fight.units[1]), "it got round\n" + ArenaDebug.render(fight))
	assert_gt(K.entries(fight, LogEntry.Kind.MOVE, "walker").size(), 2, "several legs, round the end of the wall")


func test_crowds_never_overlap() -> void:
	var heroes: Array[UnitSetup] = []
	var enemies: Array[UnitSetup] = []
	var brute: UnitDef = K.kit("brute", {"stats": {"hp": 300, "atk": 10, "speed": 3}})
	for col: int in 8:
		heroes.append(K.at(brute, col, 1 + col % 2))
		enemies.append(K.foe(brute, col, 4 + col % 3))
	var fight: CombatSim = K.sim(K.fight(heroes, enemies, [Vector2i(3, 3)] as Array[Vector2i], 3))
	while not fight.finished:
		fight.step()
		assert_true(K.no_overlaps(fight), "no overlap at tick %d\n%s" % [fight.tick, ArenaDebug.render(fight)])
	assert_gt(K.entries(fight, LogEntry.Kind.DEATH).size(), 7, "they got to each other")


func test_heroes_move_first_each_tick() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 1, 0)] as Array[UnitSetup], [K.foe(_walker(), 6, 6)] as Array[UnitSetup]))
	fight.step()
	var moves: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MOVE)
	assert_eq([moves[0].source_unit, moves[1].source_unit], ["walker", "walker#2"], "the hero's step comes first")


func test_it_gives_up_on_a_target_it_cant_reach() -> void:
	# A post boxed in by rocks on every side, and another it can reach.
	var boxed: Vector2i = Vector2i(4, 5)
	var fight_setup: FightSetup = K.fight([K.at(_walker(), 4, 1)] as Array[UnitSetup], [K.foe(_post(), boxed.x, boxed.y, "boxed"), K.foe(_post(), 0, 6, "open")] as Array[UnitSetup],
		HexGrid.make().neighbors(boxed.x, boxed.y))
	var fight: CombatSim = K.sim(fight_setup)
	fight.step()
	assert_eq(fight.units[0].target.id, "open", "nearest only picks what it can reach")
	Targeting.set_target(fight, fight.units[0], fight.units[1], "test")
	K.step(fight, 25)
	var picks: Array[LogEntry] = K.entries(fight, LogEntry.Kind.TARGET, "walker")
	var notes: Array[String] = []
	for entry: LogEntry in picks:
		notes.append("%s: %s" % [entry.target, entry.note])
	assert_eq(notes, ["open: nearest", "boxed: test", ": no way to reach boxed", "open: nearest"] as Array[String])
	assert_between(picks[2].tick - picks[1].tick, 20, 21, "it waits 1s with no way through")


func test_blocked_only_by_units_it_keeps_its_target() -> void:
	# A post ringed by six others (wide units, so the ring leaves no spot in
	# reach): no way in, but no rock walls it off, so the walker waits for an
	# opening instead of giving up (playtest gate 1).
	var boxed: Vector2i = Vector2i(4, 5)
	var enemies: Array[UnitSetup] = [K.foe(_post(), boxed.x, boxed.y, "boxed")]
	var ring: Array[Vector2i] = HexGrid.make().neighbors(boxed.x, boxed.y)
	for i: int in ring.size():
		enemies.append(K.foe(_post(), ring[i].x, ring[i].y, "guard%d" % i))
	enemies.append(K.foe(_post(), 0, 6, "open"))
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 4, 1)] as Array[UnitSetup], enemies), true)
	var walker: UnitState = fight.units[0]
	var target: UnitState = fight.unit_by_id("boxed")
	fight.step()
	Targeting.set_target(fight, walker, target, "test")
	K.step(fight, 100)
	assert_eq(walker.target, target, "5s blocked, still on it")
	assert_false(K.entries(fight, LogEntry.Kind.TARGET, "walker").any(func(entry: LogEntry) -> bool: return entry.note.begins_with("no way")), "never gave up")
	assert_false(Movement.walled_off(fight, walker, target), "units aside, there's a way")
	# A guard steps aside: the way opens.
	fight.unit_by_id("guard%d" % (ring.size() - 1)).pos = fight.grid.center(0, 3)
	K.step(fight, 100)
	assert_true(walker.in_reach_of(target), "it got there")
	assert_true(K.entries(fight, LogEntry.Kind.DAMAGE, "walker").any(func(entry: LogEntry) -> bool: return entry.target == "boxed"))


func test_melee_reaches_half_a_hex() -> void:
	var sig: Dictionary = {"id": "jab", "name": "Jab", "trigger": {"kind": "fight_start"}, "targeting": "nearest", "effects": [{"type": "damage", "amount": 1, "target": "target"}]}
	var melee: UnitDef = K.kit("melee", {"stats": {"hp": 100, "speed": 0, "range": 1}, "signature": sig})
	var far_sig: Dictionary = sig.duplicate(true)
	far_sig["max_range"] = 4
	var ranged: UnitDef = K.kit("ranged", {"stats": {"hp": 100, "speed": 0, "range": 3}, "signature": far_sig})
	var fight: CombatSim = K.sim(K.fight([K.at(melee, 3, 0, "melee"), K.at(ranged, 5, 0, "ranged")] as Array[UnitSetup], [K.foe(_post(), 3, 6)] as Array[UnitSetup]))
	var close: UnitState = fight.unit_by_id("melee")
	var far: UnitState = fight.unit_by_id("ranged")
	assert_eq([close.reach(), far.reach()], [500, 3000], "range 1 is melee: tuning's melee_reach; range 3 is 3 hexes")
	assert_eq(close.reach_sq, 500 * 500)
	assert_eq([close.reach_of(close.def.signature), far.reach_of(far.def.signature)], [500, 4000], "a signature reaches its own max_range, or its unit's reach")
	var summoned: UnitState = UnitState.make_summon(melee, EffectSource.Team.ENEMIES, "melee#9", fight.units.size(), fight.tuning.unit_radius)
	fight.add_unit(summoned)
	assert_eq([summoned.reach(), summoned.radius], [500, 100], "summons too")
	var post: UnitState = fight.unit_by_id("post")
	post.pos = close.pos + Vector2i(0, 501)
	assert_false(close.in_reach_of(post))
	post.pos = close.pos + Vector2i(0, 500)
	assert_true(close.in_reach_of(post))


func test_it_slides_past_what_it_grazes() -> void:
	# A post just off the straight line: the walker brushes past it.
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 3, 0)] as Array[UnitSetup], [K.foe(_post(), 3, 6, "goal"), K.foe(_post(1), 3, 4, "rock")] as Array[UnitSetup]))
	fight.units[2].pos += Vector2i(700, 0)
	for tick: int in 120:
		fight.step()
		assert_true(K.no_overlaps(fight), "no overlap at tick %d" % fight.tick)
	assert_true(fight.units[0].in_reach_of(fight.units[1]) or fight.units[0].target != fight.units[1], "it got past")


func test_it_aims_again_as_its_target_moves() -> void:
	# The target drifts sideways every tick; the walker re-plans every 0.5s.
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 1, 0)] as Array[UnitSetup], [K.foe(_post(), 1, 6)] as Array[UnitSetup]))
	for tick: int in 40:
		fight.units[1].pos += Vector2i(40, 0)
		fight.step()
	var legs: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MOVE, "walker")
	assert_gte(legs.size(), 4, "a fresh leg at least every 10 ticks")
	for i: int in range(1, legs.size()):
		assert_lte(legs[i].tick - legs[i - 1].tick, 10)
		assert_gt(legs[i].to_pos.x, legs[i - 1].to_pos.x, "each leg aims where the target has got to")


func test_a_walker_with_no_way_checks_cheaply_before_searching_again() -> void:
	# The only enemy is boxed in by rocks: the first searches flood the board,
	# and later ones see at once that its surroundings are closed off (the
	# result is the same; see NavGrid.find_path's `suspect`).
	# (The post is a flier, so its own targeting never searches.)
	var boxed: Vector2i = Vector2i(4, 5)
	var post: UnitDef = K.kit("post", {"stats": {"hp": 10000, "speed": 0}, "traits": ["flying"], "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(_walker(), 4, 1)] as Array[UnitSetup], [K.foe(post, boxed.x, boxed.y, "boxed")] as Array[UnitSetup],
		HexGrid.make().neighbors(boxed.x, boxed.y)))
	var walker: UnitState = fight.units[0]
	fight.step()
	assert_null(walker.target, "nearest finds no one")
	assert_true(walker.nearest_failed)
	assert_gt(fight._nav.settled_count(), 500, "the first search floods what it can reach")
	K.step(fight, 10)
	assert_eq(fight._nav.settled_count(), 0, "the next one checks first")
	# Given the boxed post as its target, its routes fail the same way.
	Targeting.set_target(fight, walker, fight.units[1], "test")
	fight.step()
	assert_gt(fight._nav.settled_count(), 500)
	assert_eq(walker.no_path_since, fight.tick)
	K.step(fight, 10)
	assert_eq(fight._nav.settled_count(), 0)
	# Once it can reach someone again, the flag clears.
	fight.rocks.clear()
	walker.target = null
	K.step(fight, 10)
	assert_eq(walker.target, fight.units[1])
	assert_false(walker.nearest_failed)
