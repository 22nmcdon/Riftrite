extends GutTest
## Rift Collapse (docs/plans/rebuild-phase1-arena-sim.md, section 9): ring
## timing and warnings, the safe rectangle shrinking, damage only on crumbled
## ground (flat, Shield first), walking back to safe ground and never onto
## crumbled ground, and start_collapse. The 180s tie is in test_fight_end.

const K = preload("res://tests/sim/sim_test_kit.gd")

## Tuning's numbers, in ticks: the first ring crumbles at 45s, one more
## every 10s, each warned 3s before.
const START: int = 900
const RING: int = 200
const WARNING: int = 60


## A unit that never moves or hurts anyone.
func _post(stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 100000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	return K.kit("post", {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A unit that stands and shoots (range 8) for 1 damage.
func _shooter(stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 100000, "speed": 2, "range": 8}
	all_stats.merge(stats, true)
	return K.kit("shooter", {"stats": all_stats, "basic_attack": {"effects": [{"type": "damage", "amount": 1, "target": "target"}]}})


func _starter(trigger: Dictionary, starter_id: String = "starter") -> UnitDef:
	return K.kit(starter_id, {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"signature": {"id": "last_ember", "name": "Last Ember", "trigger": trigger, "targeting": "self", "effects": [{"type": "start_collapse"}]},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _ring_log(fight: CombatSim) -> Array:
	return K.entries(fight, LogEntry.Kind.COLLAPSE_RING).map(func(entry: LogEntry) -> Array: return [entry.tick, entry.amount, entry.note, entry.end_tick])


func _hits(fight: CombatSim, unit_id: String) -> Array:
	var found: Array = []
	for entry: LogEntry in K.entries(fight, LogEntry.Kind.COLLAPSE):
		if entry.target == unit_id:
			found.append([entry.tick, entry.amount])
	return found


func test_rings_are_warned_then_crumble_every_ten_seconds() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	K.step(fight, START - WARNING - 1)
	assert_eq(_ring_log(fight), [], "nothing before 42s")
	assert_eq(fight.safe, fight.grid.bounds())
	fight.step()
	assert_eq(_ring_log(fight), [[START - WARNING, 0, "warned", START]])
	K.step(fight, WARNING - 1)
	assert_eq(fight.safe, fight.grid.bounds(), "warned ground still stands")
	fight.step()
	assert_eq(fight.safe, fight.grid.safe_rect(1))
	K.step(fight, 2 * RING + 100)
	assert_eq(_ring_log(fight), [
		[START - WARNING, 0, "warned", START], [START, 0, "crumbled", START],
		[START + RING - WARNING, 1, "warned", START + RING], [START + RING, 1, "crumbled", START + RING],
		[START + 2 * RING - WARNING, 2, "warned", START + 2 * RING], [START + 2 * RING, 2, "crumbled", START + 2 * RING],
	], "the middle ring (3) never crumbles")
	assert_eq(fight.safe, fight.grid.safe_rect(3))
	K.step(fight, 2 * RING)
	assert_eq(K.entries(fight, LogEntry.Kind.COLLAPSE_RING).size(), 6, "nothing after ring 2")
	var entries: Array[LogEntry] = K.entries(fight, LogEntry.Kind.COLLAPSE_RING)
	var left: Rect2i = fight.grid.safe_rect(1)
	assert_eq([entries[0].from_pos, entries[0].to_pos, entries[1].from_pos, entries[1].to_pos], [left.position, left.end, left.position, left.end])
	assert_eq(entries[0].source_text(), "Rift Collapse")
	assert_eq(entries[0].to_text(), "[42.00s] Rift Collapse: ring 0 will crumble at 45.00s")
	assert_eq(entries[1].to_text(), "[45.00s] Rift Collapse: ring 0 crumbles, leaving (0.86, 1.25) to (6.19, 6.25)")


func test_crumbled_ground_is_the_rings_that_fell() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	K.step(fight, START + 2 * RING)
	for hex: int in fight.grid.size():
		var col: int = fight.grid.col_of(hex)
		var row: int = fight.grid.row_of(hex)
		assert_eq(fight.on_crumbled(fight.grid.center(col, row)), fight.grid.ring(col, row) < 3, "(%d, %d)" % [col, row])
	var board: String = ArenaDebug.render(fight)
	assert_string_contains(board, "~")


func test_damage_hits_only_those_on_crumbled_ground_once_a_second() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 0, 0, "edge"), K.at(_post(), 1, 1, "inner"), K.at(_post(), 3, 2, "middle")] as Array[UnitSetup],
		[K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	K.step(fight, START + RING + 20)
	assert_eq(_hits(fight, "edge").slice(0, 3), [[START, 10], [START + 20, 20], [START + 40, 30]], "base 10, then 10 more each second")
	assert_eq(_hits(fight, "edge").size(), 12)
	assert_eq(_hits(fight, "inner"), [[START + RING, 110], [START + RING + 20, 120]], "ring 1 from 55s")
	assert_eq(_hits(fight, "middle"), [], "ring 2 still stands")
	var edge: UnitState = fight.unit_by_id("edge")
	var total: int = 0
	for hit: Array in _hits(fight, "edge"):
		total += hit[1]
	assert_eq(edge.hp, 100000 - total)
	var entry: LogEntry = K.entries(fight, LogEntry.Kind.COLLAPSE)[0]
	assert_eq([entry.source_ability, entry.to_text()], [LogEntry.COLLAPSE_SOURCE, "[45.00s] Rift Collapse hits edge for 10"])


func test_damage_is_flat_and_hits_shield_first() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post({"def": 200}), 0, 0, "armored")] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	var armored: UnitState = fight.unit_by_id("armored")
	K.step(fight, START - 1)
	armored.shield = 15
	fight.step()
	assert_eq([armored.hp, armored.shield], [100000, 5], "DEF doesn't soften it; Shield takes it first")
	K.step(fight, 20)
	assert_eq([armored.hp, armored.shield], [100000 - 15, 0])
	assert_eq(K.entries(fight, LogEntry.Kind.COLLAPSE)[1].absorbed, 5)


func test_a_unit_felled_by_the_collapse_says_so() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post({"hp": 25}), 0, 0, "edge"), K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	K.step(fight, START + 20)
	assert_eq(K.entries(fight, LogEntry.Kind.DEATH)[0].to_text(), "[46.00s] edge falls (last hit: Rift Collapse)")
	K.step(fight, 40)
	assert_eq(_hits(fight, "edge").size(), 2, "the fallen aren't hit")


func test_damage_grows_faster_from_the_surge() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	# Act 1: base 10, growth 10, accel 2; the surge is 45s after the first
	# ring crumbles.
	assert_eq(Collapse.damage_at(fight, START), 10)
	assert_eq(Collapse.damage_at(fight, START + 45 * 20), 460)
	assert_eq(Collapse.damage_at(fight, START + 46 * 20), 470 + 2)
	assert_eq(Collapse.damage_at(fight, START + 48 * 20), 490 + 2 * 6)


func test_damage_uses_the_fights_act() -> void:
	var setup: FightSetup = FightSetup.make([K.at(_post(), 0, 0, "edge")] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup], [], 1, 2)
	var fight: CombatSim = K.sim(setup)
	K.step(fight, START + 20)
	assert_eq(_hits(fight, "edge"), [[START, 20], [START + 20, 40]])


func test_a_fight_in_an_act_without_collapse_numbers_is_refused() -> void:
	var setup: FightSetup = FightSetup.make([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup], [], 1, 3)
	assert_eq(setup.validate(K.content()), ["tuning has no Rift Collapse numbers for act 3"] as Array[String])


func test_a_unit_on_crumbled_ground_walks_back_before_it_attacks() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter(), 0, 1, "shooter")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup]))
	var shooter: UnitState = fight.unit_by_id("shooter")
	K.step(fight, START - 1)
	var shots_before: int = K.entries(fight, LogEntry.Kind.FIRE, "shooter").size()
	assert_gt(shots_before, 0, "it stood and shot until the ring fell")
	var start: Vector2i = shooter.pos
	fight.step()
	var move: LogEntry = K.entries(fight, LogEntry.Kind.MOVE, "shooter").back()
	assert_eq([move.tick, move.from_pos, move.to_pos], [START, start, fight.nearest_safe_point(start, shooter.radius)], "straight to the nearest spot wholly on safe ground")
	while fight.on_crumbled(shooter.pos):
		fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "shooter").size(), shots_before, "it didn't shoot on the way")
	assert_between(fight.tick, START + 1, START + 5)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "shooter").size(), shots_before + 1, "its center clear, it stops and shoots")
	assert_eq(K.entries(fight, LogEntry.Kind.STOP, "shooter").back().note, "in reach")
	K.step(fight, 20)
	assert_eq(_hits(fight, "shooter"), [[START, 10]], "one hit before it got clear")


func test_a_unit_only_partly_on_crumbled_ground_steps_clear_before_it_walks() -> void:
	# A melee hero stands half over the edge of what will be ring 0's line; its
	# target is out of reach, so it walks.
	var fight: CombatSim = K.sim(K.fight([K.at(K.kit("walker", {"stats": {"hp": 100000}}), 1, 1, "walker")] as Array[UnitSetup], [K.foe(_post(), 6, 5)] as Array[UnitSetup]), true)
	var walker: UnitState = fight.unit_by_id("walker")
	fight.collapse_start = 1
	fight.step()
	fight.step()
	assert_false(fight.on_crumbled(walker.pos), "its center stands on safe ground")
	walker.pos = Vector2i(fight.safe.position.x + 300, walker.pos.y)
	walker.route.clear()
	fight.step()
	var move: LogEntry = K.entries(fight, LogEntry.Kind.MOVE, "walker").back()
	assert_eq([move.tick, move.to_pos], [3, fight.nearest_safe_point(Vector2i(fight.safe.position.x + 300, move.from_pos.y), walker.radius)])
	K.step(fight, 3)
	assert_true(ArenaPlane.inside(fight.safe, walker.pos, walker.radius))
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "walker").back().to_pos, fight.unit_by_id("post").pos, "then on toward its target")


func test_nobody_walks_onto_crumbled_ground() -> void:
	# The hero's target stands in the corner, which crumbles: it can't be
	# reached from safe ground. The hero fights on half over the edge until
	# ring 1 crumbles under its center, then walks clear and waits.
	var hero: UnitDef = K.kit("walker", {"stats": {"hp": 100000, "speed": 3}, "basic_attack": {"effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 4, 2, "walker")] as Array[UnitSetup], [K.foe(_post(), 7, 6, "cornered")] as Array[UnitSetup]), true)
	var walker: UnitState = fight.unit_by_id("walker")
	K.step(fight, START)
	var clear_since: int = -1
	for i: int in 400:
		var before: int = fight.crumbled_depth(walker.pos, walker.radius)
		var rings: int = fight.collapse_rings
		fight.step()
		var depth: int = fight.crumbled_depth(walker.pos, walker.radius)
		if depth == 0 and clear_since < 0:
			clear_since = fight.tick
		if rings == fight.collapse_rings and depth > before:
			fail_test("tick %d: it stepped further onto crumbled ground" % fight.tick)
			return
	assert_between(clear_since, START + RING + 1, START + RING + 20)
	assert_true(fight.unit_by_id("cornered").alive)


func test_the_way_back_goes_round_what_blocks_it() -> void:
	# A rock sits right inward of the hero; the way back goes round it.
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter({"range": 1}), 0, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 7, 6)] as Array[UnitSetup], [Vector2i(1, 2)] as Array[Vector2i]), true)
	var hero: UnitState = fight.unit_by_id("hero")
	fight.collapse_start = 1
	var route_start: Vector2i = hero.pos
	fight.step()
	assert_true(fight.on_crumbled(route_start))
	K.step(fight, 40)
	assert_true(ArenaPlane.inside(fight.safe, hero.pos, hero.radius), "it found its way round")
	var legs: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MOVE, "hero")
	assert_eq(legs[0].from_pos, route_start)
	assert_ne(legs[0].to_pos, fight.nearest_safe_point(route_start, hero.radius), "not straight through the rock")
	assert_true(K.no_overlaps(fight))


func test_a_unit_with_no_way_back_waits() -> void:
	var hero: UnitDef = _shooter({"range": 1})
	# Boxed in against the edge by rocks.
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 0, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 7, 6)] as Array[UnitSetup], [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 3)] as Array[Vector2i]), true)
	var hero_state: UnitState = fight.unit_by_id("hero")
	var start: Vector2i = hero_state.pos
	fight.collapse_start = 1
	K.step(fight, 30)
	assert_eq(hero_state.pos, start)
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero"), [] as Array[LogEntry])


func test_a_flier_flies_back() -> void:
	var flier: UnitDef = K.kit("flier", {"traits": ["flying"], "stats": {"hp": 100000, "range": 8}})
	var fight: CombatSim = K.sim(K.fight([K.at(flier, 0, 2, "flier")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup], [Vector2i(1, 2)] as Array[Vector2i]))
	var unit: UnitState = fight.unit_by_id("flier")
	fight.collapse_start = 1
	var start: Vector2i = unit.pos
	fight.step()
	assert_true(unit.airborne, "it takes off")
	var move: LogEntry = K.entries(fight, LogEntry.Kind.MOVE, "flier")[0]
	assert_eq(move.to_pos, fight.nearest_safe_point(start, unit.radius), "straight back, over the rock")


func test_start_collapse_warns_the_first_ring_now() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_starter({"kind": "at_time", "at_ms": 10000}), 4, 4)] as Array[UnitSetup]))
	K.step(fight, 200)
	var warning: LogEntry = K.entries(fight, LogEntry.Kind.COLLAPSE_RING)[0]
	assert_eq([warning.tick, warning.end_tick, warning.source_text()], [200, 200 + WARNING, "starter · Last Ember"])
	assert_eq(warning.to_text(), "[10.00s] starter · Last Ember: ring 0 will crumble at 13.00s")
	K.step(fight, WARNING + RING)
	assert_eq(_ring_log(fight), [
		[200, 0, "warned", 200 + WARNING], [200 + WARNING, 0, "crumbled", 200 + WARNING],
		[200 + RING, 1, "warned", 200 + WARNING + RING], [200 + WARNING + RING, 1, "crumbled", 200 + WARNING + RING],
	], "the rest keep the same spacing")
	assert_eq(Collapse.damage_at(fight, 200 + WARNING + 20), 20, "the damage counts from the first crumble")


func test_start_collapse_does_nothing_once_it_has_started() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup],
		[K.foe(_starter({"kind": "at_time", "at_ms": 10000}), 4, 4), K.foe(_starter({"kind": "at_time", "at_ms": 11000}, "second"), 5, 4)] as Array[UnitSetup]))
	K.step(fight, 220 + WARNING)
	assert_eq(_ring_log(fight), [[200, 0, "warned", 200 + WARNING], [200 + WARNING, 0, "crumbled", 200 + WARNING]])
	var late: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_starter({"kind": "at_time", "at_ms": 43000}), 4, 4)] as Array[UnitSetup]))
	K.step(late, START)
	assert_eq(_ring_log(late), [[START - WARNING, 0, "warned", START], [START, 0, "crumbled", START]], "warned at 42s already")


func test_start_collapse_reads_with_no_target_and_not_in_an_area() -> void:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new({"type": "start_collapse"}, "e", errors))
	assert_eq([errors, effect.type, effect.target], [[] as Array[String], EffectDef.Type.START_COLLAPSE, EffectDef.Target.SELF])
	EffectDef.read(DataReader.new({"type": "start_collapse", "target": "target"}, "e", errors))
	assert_eq(errors.size(), 1, "no target key")
	errors.clear()
	EffectDef.read(DataReader.new({"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies",
		"effects": [{"type": "start_collapse"}]}, "e", errors))
	assert_eq(errors.size(), 1, "not in an area")


## The collapse starts at once and a ring crumbles every `ring_ticks`.
func _fast_collapse(fight: CombatSim, ring_ticks: int, warning_ticks: int = WARNING) -> void:
	fight.tuning.collapse_ring_ticks = ring_ticks
	fight.tuning.collapse_warning_ticks = warning_ticks
	fight.collapse_start = 1


func test_crumbled_ground_starts_past_the_safe_edge() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	fight.safe = fight.grid.safe_rect(1)
	var safe: Rect2i = fight.safe
	for point: Vector2i in [safe.position, safe.end, Vector2i(safe.position.x, safe.end.y), Vector2i(safe.end.x, safe.position.y)]:
		assert_false(fight.on_crumbled(point), "the edge itself is safe: %s" % point)
	for point: Vector2i in [safe.position - Vector2i(1, 0), safe.position - Vector2i(0, 1), safe.end + Vector2i(1, 0), safe.end + Vector2i(0, 1)]:
		assert_true(fight.on_crumbled(point), "just past it isn't: %s" % point)


func test_walking_back_never_goes_further_out_or_off_the_arena() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]), true)
	var hero: UnitState = fight.unit_by_id("hero")
	fight.safe = fight.grid.safe_rect(2)
	# 1632 past the left edge and 2150 past the top: the top counts.
	hero.pos = Vector2i(500, 500)
	assert_eq(fight.crumbled_depth(hero.pos, hero.radius), 2150)
	assert_true(fight.fits_leaving(hero, Vector2i(600, 600)), "back toward safe ground")
	assert_true(fight.fits_leaving(hero, Vector2i(420, 500)), "further out on the left, but no further out than it was")
	assert_false(fight.fits_leaving(hero, Vector2i(500, 480)), "further out at the top")
	assert_false(fight.fits_leaving(hero, Vector2i(399, 500)), "off the arena")
	assert_false(fight.fits(hero, Vector2i(600, 600)), "an ordinary step can't be on crumbled ground at all")


func test_a_flier_in_the_air_crosses_crumbled_ground() -> void:
	# Its target stands in a corner that crumbles; the flier flies out over
	# the crumbled ground and fights it from the air.
	# Three rings are down by tick 21, so no spot on safe ground is in reach.
	var flier: UnitDef = K.kit("flier", {"traits": ["flying"], "stats": {"hp": 100000, "speed": 3}})
	var fight: CombatSim = K.sim(K.fight([K.at(flier, 4, 2, "flier")] as Array[UnitSetup], [K.foe(_post(), 7, 6, "cornered")] as Array[UnitSetup]))
	_fast_collapse(fight, 10)
	K.step(fight, 80)
	var unit: UnitState = fight.unit_by_id("flier")
	assert_true(unit.airborne and fight.on_crumbled(unit.pos), "over crumbled ground")
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "flier").size(), 0, "fighting")


func test_a_rooted_unit_stays_on_crumbled_ground() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter(), 0, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	var start: Vector2i = hero.pos
	Statuses.apply(fight, hero, "root", 1, 100, EffectSource.make("post", "test", "Test"))
	_fast_collapse(fight, 10000)
	K.step(fight, 20)
	assert_eq(hero.pos, start)
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "hero"), [] as Array[LogEntry], "nor does it shoot")


func test_a_unit_with_no_way_looks_again_every_half_second() -> void:
	# A rock and an ally box the hero into its corner, and a Taunt keeps its
	# target; the ally is moved away on tick 5, and the hero sees the way
	# only when it looks again.
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter({"range": 1}), 0, 0, "hero"), K.at(_post(), 1, 0, "ally")] as Array[UnitSetup],
		[K.foe(_post(), 7, 6, "taunter")] as Array[UnitSetup], [Vector2i(0, 1)] as Array[Vector2i]), true)
	Statuses.apply(fight, fight.unit_by_id("hero"), "taunt", 1, 1000, EffectSource.make("taunter", "test", "Test"))
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.STOP, "hero"), [] as Array[LogEntry])
	assert_eq(fight.unit_by_id("hero").no_path_since, 1, "no way to its target")
	K.step(fight, 4)
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero"), [] as Array[LogEntry], "no way yet")
	fight.unit_by_id("ally").pos = fight.grid.center(3, 2)
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero"), [] as Array[LogEntry], "not until it looks again")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero")[0].tick, 11)


func test_a_unit_with_no_way_back_looks_again_every_half_second() -> void:
	# Two rocks and two allies box the hero in; one ally is moved away.
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter({"range": 1}), 0, 1, "hero"), K.at(_post(), 1, 1), K.at(_post(), 0, 2, "ally")] as Array[UnitSetup],
		[K.foe(_post(), 7, 6)] as Array[UnitSetup], [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]), true)
	_fast_collapse(fight, 10000)
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero"), [] as Array[LogEntry], "no way back yet")
	fight.unit_by_id("ally").pos = fight.grid.center(3, 2)
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero"), [] as Array[LogEntry], "not until it looks again")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero")[0].tick, 11)


func test_a_new_ring_sends_everyone_on_a_fresh_way_back() -> void:
	# Ring 0 falls on tick 1, and the hero walks back until its center is
	# safe, by tick 5; ring 1 falls on tick 10, before its half-second look
	# again.
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter(), 0, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	_fast_collapse(fight, 9, 0)
	K.step(fight, 9)
	assert_false(fight.on_crumbled(hero.pos))
	fight.step()
	assert_true(fight.on_crumbled(hero.pos))
	var move: LogEntry = K.entries(fight, LogEntry.Kind.MOVE, "hero").back()
	assert_eq([move.tick, move.to_pos], [10, fight.nearest_safe_point(move.from_pos, hero.radius)])


func test_after_walking_the_way_back_is_planned_fresh() -> void:
	# The hero walks back from ring 0, then walks toward its target; ring 1
	# falls under it as it goes.
	var fight: CombatSim = K.sim(K.fight([K.at(K.kit("walker", {"stats": {"hp": 100000, "speed": 1}}), 0, 2, "hero")] as Array[UnitSetup],
		[K.foe(_post(), 7, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	_fast_collapse(fight, 30, 0)
	K.step(fight, 30)
	assert_eq(hero.route_for, fight.unit_by_id("post"), "walking to its target")
	fight.step()
	assert_false(ArenaPlane.inside(fight.safe, hero.pos, hero.radius), "ring 1 is under it")
	var move: LogEntry = K.entries(fight, LogEntry.Kind.MOVE, "hero").back()
	assert_eq([move.tick, move.to_pos], [31, fight.nearest_safe_point(move.from_pos, hero.radius)])


func test_a_route_back_is_never_walked_as_a_route_to_the_target() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(K.kit("walker", {"stats": {"hp": 100000}}), 3, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 3, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	fight.step()
	# As if it had been pushed onto safe ground on its way back.
	hero.route = [Vector2i(500, 500)] as Array[Vector2i]
	hero.route_for = null
	hero.replan_at = 100
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero").back().to_pos, fight.unit_by_id("post").pos)
