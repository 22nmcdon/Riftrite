extends GutTest
## Rift Collapse (docs/plans/rebuild-phase1-arena-sim.md, section 9): ring
## timing and warnings, the safe rectangle shrinking, damage only on crumbled
## ground (flat, Shield first), and start_collapse. Crumbled ground is
## walkable (phase 5c, Decision 7): units fight and walk on it, and one with
## nothing to do steps off it. The 180s tie is in test_fight_end.

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
	assert_eq(_hits(fight, "edge").slice(0, 3), [[START, 15], [START + 20, 25], [START + 40, 35]], "base 15, then 10 more each second")
	assert_eq(_hits(fight, "edge").size(), 12)
	assert_eq(_hits(fight, "inner"), [[START + RING, 115], [START + RING + 20, 125]], "ring 1 from 55s")
	assert_eq(_hits(fight, "middle"), [], "ring 2 still stands")
	var edge: UnitState = fight.unit_by_id("edge")
	var total: int = 0
	for hit: Array in _hits(fight, "edge"):
		total += hit[1]
	assert_eq(edge.hp, 100000 - total)
	var entry: LogEntry = K.entries(fight, LogEntry.Kind.COLLAPSE)[0]
	assert_eq([entry.source_ability, entry.to_text()], [LogEntry.COLLAPSE_SOURCE, "[45.00s] Rift Collapse hits edge for 15"])


func test_damage_is_flat_and_hits_shield_first() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post({"def": 200}), 0, 0, "armored")] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	var armored: UnitState = fight.unit_by_id("armored")
	K.step(fight, START - 1)
	armored.shield = 20
	fight.step()
	assert_eq([armored.hp, armored.shield], [100000, 5], "DEF doesn't soften it; Shield takes it first")
	K.step(fight, 20)
	assert_eq([armored.hp, armored.shield], [100000 - 20, 0])
	assert_eq(K.entries(fight, LogEntry.Kind.COLLAPSE)[1].absorbed, 5)


func test_a_unit_felled_by_the_collapse_says_so() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post({"hp": 25}), 0, 0, "edge"), K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	K.step(fight, START + 20)
	assert_eq(K.entries(fight, LogEntry.Kind.DEATH)[0].to_text(), "[46.00s] edge falls (last hit: Rift Collapse)")
	K.step(fight, 40)
	assert_eq(_hits(fight, "edge").size(), 2, "the fallen aren't hit")


func test_damage_grows_faster_from_the_surge() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]))
	# Act 1: base 15 (phase 5c, Decision 8), growth 10, accel 2; the surge is
	# 45s after the first ring crumbles.
	assert_eq(Collapse.damage_at(fight, START), 15)
	assert_eq(Collapse.damage_at(fight, START + 45 * 20), 465)
	assert_eq(Collapse.damage_at(fight, START + 46 * 20), 475 + 2)
	assert_eq(Collapse.damage_at(fight, START + 48 * 20), 495 + 2 * 6)


## Endless (phase 8 part 1): a floor's crumbled ground hits harder, every
## second's number times the setup's crumble_bp.
func test_an_endless_floor_scales_the_crumbled_grounds_damage() -> void:
	var setup: FightSetup = K.fight([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup])
	setup.crumble_bp = 15000
	var fight: CombatSim = K.sim(setup)
	assert_eq(Collapse.damage_at(fight, START), 23, "15 x1.5, rounded once")
	assert_eq(Collapse.damage_at(fight, START + 46 * 20), (475 + 2) * 3 / 2 + 1)
	setup.crumble_bp = -1
	var errors: Array[String] = setup.validate(K.content())
	assert_true(errors.any(func(error: String) -> bool: return error.contains("crumbled ground")))


func test_damage_uses_the_fights_act() -> void:
	var setup: FightSetup = FightSetup.make([K.at(_post(), 0, 0, "edge")] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup], [], 1, 2)
	var fight: CombatSim = K.sim(setup)
	K.step(fight, START + 20)
	assert_eq(_hits(fight, "edge"), [[START, 20], [START + 20, 40]])


func test_a_fight_in_an_act_without_collapse_numbers_is_refused() -> void:
	var setup: FightSetup = FightSetup.make([K.at(_post(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup], [], 1, 3)
	assert_eq(setup.validate(K.content()), ["tuning has no Rift Collapse numbers for act 3"] as Array[String])


## Hides every enemy of the fight (a long Stealth), so the heroes have no
## target: nothing to do.
func _hide_enemies(fight: CombatSim) -> void:
	for enemy: UnitState in fight.enemies:
		Statuses.apply(fight, enemy, "stealth", 1, 100000, EffectSource.make(enemy.id, "test", "Test"))


func test_a_unit_in_reach_fights_on_crumbled_ground() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter(), 0, 1, "shooter")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup]))
	var shooter: UnitState = fight.unit_by_id("shooter")
	K.step(fight, START - 1)
	var shots_before: int = K.entries(fight, LogEntry.Kind.FIRE, "shooter").size()
	var start: Vector2i = shooter.pos
	K.step(fight, 41)
	assert_true(fight.on_crumbled(shooter.pos))
	assert_eq(shooter.pos, start, "it stays where it stands")
	assert_gt(K.entries(fight, LogEntry.Kind.FIRE, "shooter").size(), shots_before, "and keeps shooting")
	assert_eq(_hits(fight, "shooter"), [[START, 15], [START + 20, 25], [START + 40, 35]], "and the ground hurts it")


func test_a_cornered_target_is_reached_over_crumbled_ground() -> void:
	# The hero's target stands in the corner, which crumbles: the hero walks
	# onto the crumbled ground to reach it, and never gives up on it.
	var hero: UnitDef = K.kit("walker", {"stats": {"hp": 100000, "speed": 3}, "basic_attack": {"effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 4, 2, "walker")] as Array[UnitSetup], [K.foe(_post(), 7, 6, "cornered")] as Array[UnitSetup]), true)
	var walker: UnitState = fight.unit_by_id("walker")
	K.step(fight, START + 2 * RING)
	assert_true(fight.on_crumbled(walker.pos), "it stands on crumbled ground by its target")
	assert_eq(walker.target, fight.unit_by_id("cornered"))
	assert_gt(K.entries(fight, LogEntry.Kind.DAMAGE, "walker").filter(func(entry: LogEntry) -> bool: return entry.tick > START).size(), 0, "fighting it there")


func test_a_route_goes_round_crumbled_ground_when_it_can() -> void:
	# Hero and target both stand in ring 0 on the left edge, far apart: the
	# way between them runs over safe ground, a step in from the edge.
	var hero: UnitDef = K.kit("walker", {"stats": {"hp": 100000, "speed": 2}})
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 0, 0, "walker")] as Array[UnitSetup], [K.foe(_post(), 0, 6, "far")] as Array[UnitSetup]))
	var walker: UnitState = fight.unit_by_id("walker")
	fight.safe = fight.grid.safe_rect(1)
	fight.collapse_rings = 1
	var on_safe: int = 0
	var steps: int = 0
	for i: int in 120:
		fight.step()
		steps += 1
		if ArenaPlane.inside(fight.safe, walker.pos, walker.radius):
			on_safe += 1
		if ArenaPlane.length_sq(walker.pos - fight.unit_by_id("far").pos) <= walker.reach_sq:
			break
	assert_gt(on_safe, steps / 2, "most of the way on safe ground (%d of %d ticks)" % [on_safe, steps])


func test_a_unit_with_nothing_to_do_steps_off_crumbled_ground() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter(), 0, 1, "shooter")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup]))
	var shooter: UnitState = fight.unit_by_id("shooter")
	_hide_enemies(fight)
	var start: Vector2i = shooter.pos
	fight.collapse_start = 1
	K.step(fight, 1 + WARNING)
	var move: LogEntry = K.entries(fight, LogEntry.Kind.MOVE, "shooter").back()
	assert_eq([move.from_pos, move.to_pos], [start, fight.nearest_safe_point(start, shooter.radius)], "straight to the nearest spot wholly on safe ground")
	K.step(fight, 10)
	assert_true(ArenaPlane.inside(fight.safe, shooter.pos, shooter.radius))


func test_the_way_off_goes_round_what_blocks_it() -> void:
	# A rock sits right inward of the hero; the way off goes round it.
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter({"range": 1}), 0, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 7, 6)] as Array[UnitSetup], [Vector2i(1, 2)] as Array[Vector2i]), true)
	var hero: UnitState = fight.unit_by_id("hero")
	_hide_enemies(fight)
	fight.collapse_start = 1
	var route_start: Vector2i = hero.pos
	K.step(fight, 1 + WARNING)
	assert_true(fight.on_crumbled(route_start))
	K.step(fight, 40)
	assert_true(ArenaPlane.inside(fight.safe, hero.pos, hero.radius), "it found its way round")
	var legs: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MOVE, "hero")
	assert_eq(legs[0].from_pos, route_start)
	assert_ne(legs[0].to_pos, fight.nearest_safe_point(route_start, hero.radius), "not straight through the rock")
	assert_true(K.no_overlaps(fight))


func test_a_unit_with_no_way_off_waits() -> void:
	var hero: UnitDef = _shooter({"range": 1})
	# Boxed in against the edge by rocks.
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 0, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 7, 6)] as Array[UnitSetup], [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 3)] as Array[Vector2i]), true)
	var hero_state: UnitState = fight.unit_by_id("hero")
	_hide_enemies(fight)
	var start: Vector2i = hero_state.pos
	fight.collapse_start = 1
	K.step(fight, 30 + WARNING)
	assert_eq(hero_state.pos, start)
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero"), [] as Array[LogEntry])


func test_a_flier_with_nothing_to_do_flies_off() -> void:
	var flier: UnitDef = K.kit("flier", {"traits": ["flying"], "stats": {"hp": 100000, "range": 8}})
	var fight: CombatSim = K.sim(K.fight([K.at(flier, 0, 2, "flier")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup], [Vector2i(1, 2)] as Array[Vector2i]))
	var unit: UnitState = fight.unit_by_id("flier")
	_hide_enemies(fight)
	fight.collapse_start = 1
	var start: Vector2i = unit.pos
	K.step(fight, 1 + WARNING)
	assert_true(unit.airborne, "it takes off")
	var move: LogEntry = K.entries(fight, LogEntry.Kind.MOVE, "flier")[0]
	assert_eq(move.to_pos, fight.nearest_safe_point(start, unit.radius), "straight off, over the rock")


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
	assert_eq(Collapse.damage_at(fight, 200 + WARNING + 20), 25, "the damage counts from the first crumble")


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


func test_walking_may_cross_crumbled_ground_but_landing_spots_stay_safe() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_post(), 3, 2, "hero")] as Array[UnitSetup], [K.foe(_post(), 4, 4)] as Array[UnitSetup]), true)
	var hero: UnitState = fight.unit_by_id("hero")
	fight.safe = fight.grid.safe_rect(2)
	assert_true(fight.fits_ground(hero, Vector2i(600, 600)), "a step onto crumbled ground")
	assert_false(fight.fits_ground(hero, Vector2i(399, 500)), "off the arena")
	assert_false(fight.fits(hero, Vector2i(600, 600)), "a spot it picks to land on stays on safe ground")


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
	assert_gt(K.entries(fight, LogEntry.Kind.FIRE, "hero").size(), 0, "Root stops walking, not shooting")


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


func test_a_unit_with_no_way_off_looks_again_every_half_second() -> void:
	# Two rocks and two allies box the hero in; one ally is moved away.
	var fight: CombatSim = K.sim(K.fight([K.at(_shooter({"range": 1}), 0, 1, "hero"), K.at(_post(), 1, 1), K.at(_post(), 0, 2, "ally")] as Array[UnitSetup],
		[K.foe(_post(), 7, 6)] as Array[UnitSetup], [Vector2i(0, 0), Vector2i(1, 0)] as Array[Vector2i]), true)
	_hide_enemies(fight)
	_fast_collapse(fight, 10000, 0)
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero"), [] as Array[LogEntry], "no way off yet")
	fight.unit_by_id("ally").pos = fight.grid.center(3, 2)
	K.step(fight, 5)
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero"), [] as Array[LogEntry], "not until it looks again")
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.MOVE, "hero")[0].tick, 11)


func test_a_walker_keeps_on_toward_its_target_when_a_ring_falls_under_it() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(K.kit("walker", {"stats": {"hp": 100000, "speed": 1}}), 0, 2, "hero")] as Array[UnitSetup],
		[K.foe(_post(), 7, 5)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	_fast_collapse(fight, 30, 0)
	K.step(fight, 31)
	assert_eq(hero.route_for, fight.unit_by_id("post"), "still walking to its target")
	assert_eq(K.entries(fight, LogEntry.Kind.STOP, "hero").filter(func(entry: LogEntry) -> bool: return entry.note == "no way off crumbled ground"), [] as Array[LogEntry])


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
