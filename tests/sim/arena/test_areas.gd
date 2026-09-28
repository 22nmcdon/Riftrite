extends GutTest
## Areas and warnings (docs/plans/rebuild-phase1-arena-sim.md, section 7):
## shapes, anchors, warnings, what's hit when it lands, and the log.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _post(stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	return K.kit("post", {"stats": all_stats, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A caster whose fight-start signature (6 hexes of reach) casts `area`, with
## a 10-damage hit on each unit unless `effects` says otherwise.
func _caster(area: Dictionary, stats: Dictionary = {}) -> UnitDef:
	var effect: Dictionary = {"type": "area", "hits": "enemies", "effects": [{"type": "damage", "amount": 10, "target": "target"}]}
	effect.merge(area, true)
	var all_stats: Dictionary = {"hp": 10000, "speed": 0, "range": 1}
	all_stats.merge(stats, true)
	return K.kit("caster", {"stats": all_stats,
		"signature": {"id": "blast", "name": "Blast", "trigger": {"kind": "fight_start"}, "max_range": 6, "effects": [effect]},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _hit_ids(fight: CombatSim) -> Array:
	return K.entries(fight, LogEntry.Kind.DAMAGE, "caster").map(func(entry: LogEntry) -> String: return entry.target)


func test_a_warned_area_hits_whoever_stands_there_when_it_lands() -> void:
	var caster: UnitDef = _caster({"shape": {"kind": "circle", "radius": 1}, "anchor": "target", "warning_ms": 1000})
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 3, 2)] as Array[UnitSetup], [K.foe(_post(), 3, 4, "marked"), K.foe(_post(), 0, 6, "late")] as Array[UnitSetup]))
	var marked: UnitState = fight.unit_by_id("marked")
	var center: Vector2i = marked.pos
	fight.step()
	var warning: LogEntry = K.entries(fight, LogEntry.Kind.AREA_WARNING)[0]
	assert_eq([warning.tick, warning.end_tick, warning.shape, warning.from_pos], [1, 21, "circle 1", center])
	assert_eq(warning.to_text(), "[0.05s] caster · Blast marks a circle 1 at %s (lands at 1.05s)" % LogEntry._point(center))
	marked.pos = center + Vector2i(1500, 0)
	fight.unit_by_id("late").pos = center + Vector2i(0, 500)
	K.step(fight, 19)
	assert_eq(_hit_ids(fight), [], "not yet")
	fight.step()
	var landed: LogEntry = K.entries(fight, LogEntry.Kind.AREA_LANDED)[0]
	assert_eq([landed.tick, landed.amount], [21, 1])
	assert_eq(_hit_ids(fight), ["late"], "where it was cast, not following anyone")


func test_without_a_warning_it_lands_at_once_and_never_rides_a_shot() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_caster({"shape": {"kind": "circle", "radius": 1}, "anchor": "target"}), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 3, 5)] as Array[UnitSetup]))
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.AREA_WARNING).size(), 0)
	assert_eq(_hit_ids(fight), ["post"])
	assert_eq(K.entries(fight, LogEntry.Kind.SHOT).size(), 0, "3 hexes away, but an area isn't a shot")


func test_each_shape() -> void:
	# From the caster at (3, 2): a (3, 4) is nearest, 2 hexes; b (3, 5) is
	# behind it; c (4, 5) is a hex from a, 2.6 from the caster.
	var enemies: Array[UnitSetup] = [K.foe(_post(), 3, 4, "a"), K.foe(_post(), 3, 5, "b"), K.foe(_post(), 4, 5, "c"), K.foe(_post(), 1, 6, "d")]
	# A ring 1 round the caster's target "a": not "a" itself.
	var ring: CombatSim = K.sim(K.fight([K.at(_caster({"shape": {"kind": "ring", "radius": 1}, "anchor": "target"}), 3, 2)] as Array[UnitSetup], enemies))
	ring.step()
	assert_eq(_hit_ids(ring), ["b", "c"], "a hex from a: b and c; a is at the center")
	# A line 4 from the caster straight down column 3: a and b, not c.
	var line: CombatSim = K.sim(K.fight([K.at(_caster({"shape": {"kind": "line", "length": 4}, "anchor": "target_direction"}), 3, 2)] as Array[UnitSetup], enemies))
	line.step()
	assert_eq(_hit_ids(line), ["a", "b"])
	var drawn: LogEntry = K.entries(line, LogEntry.Kind.AREA_LANDED)[0]
	assert_eq(drawn.from_pos, line.units[0].pos + Vector2i(0, 400), "from the caster's edge")
	assert_eq(drawn.to_pos, drawn.from_pos + Vector2i(0, 4000))
	# A cone widens: c (0.87 hexes off the line, 2.1 down it) is inside, where
	# the line missed it; d isn't.
	var cone: CombatSim = K.sim(K.fight([K.at(_caster({"shape": {"kind": "cone"}, "anchor": "target_direction"}), 3, 2)] as Array[UnitSetup], enemies))
	cone.step()
	assert_eq(_hit_ids(cone), ["a", "b", "c"])
	var short: CombatSim = K.sim(K.fight([K.at(_caster({"shape": {"kind": "cone", "depth": 2}, "anchor": "target_direction"}), 3, 2)] as Array[UnitSetup], enemies))
	short.step()
	assert_eq(_hit_ids(short), ["a"], "depth 2 stops short of b and c")
	# A circle on the caster itself: only a, exactly 2 hexes away.
	var burst: CombatSim = K.sim(K.fight([K.at(_caster({"shape": {"kind": "circle", "radius": 2}, "anchor": "self"}), 3, 2)] as Array[UnitSetup], enemies))
	burst.step()
	assert_eq(_hit_ids(burst), ["a"])


func test_hits_picks_a_side() -> void:
	var healing: Dictionary = {"shape": {"kind": "circle", "radius": 2}, "anchor": "self", "hits": "allies", "effects": [{"type": "heal", "amount": 10, "target": "target"}]}
	var fight: CombatSim = K.sim(K.fight([K.at(_caster(healing), 3, 2), K.at(_post(), 4, 2, "friend")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup]))
	for unit: UnitState in fight.units:
		unit.hp = 5000
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.HEAL, "caster").map(func(entry: LogEntry) -> String: return entry.target), ["caster", "friend"], "the caster too, not the enemy")
	var everyone: CombatSim = K.sim(K.fight([K.at(_caster({"shape": {"kind": "circle", "radius": 2}, "anchor": "self", "hits": "all"}), 3, 2), K.at(_post(), 4, 2, "friend")] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup]))
	everyone.step()
	assert_eq(_hit_ids(everyone), ["caster", "friend", "post"])


func test_numbers_are_set_when_cast_and_it_lands_after_the_caster_falls() -> void:
	var caster: UnitDef = _caster({"shape": {"kind": "circle", "radius": 1}, "anchor": "target", "warning_ms": 500,
		"effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}, {"atk": 30})
	var fight: CombatSim = K.sim(K.fight([K.at(caster, 3, 2), K.at(_post(), 7, 0, "friend")] as Array[UnitSetup], [K.foe(_post(), 3, 4), K.foe(_post(), 0, 6)] as Array[UnitSetup]))
	fight.step()
	fight.units[0].stats.values[UnitStats.Stat.ATK] = 1
	fight.units[0].hp = 0
	K.step(fight, 10)
	assert_false(fight.units[0].alive)
	assert_eq(K.entries(fight, LogEntry.Kind.DAMAGE, "caster").map(func(entry: LogEntry) -> int: return entry.amount), [30])


func test_a_knockback_in_an_area_goes_away_from_its_center() -> void:
	var slam: Dictionary = {"shape": {"kind": "circle", "radius": 2}, "anchor": "target", "effects": [{"type": "knockback", "hexes": 1, "target": "target"}]}
	# The caster's target is "center" (3 hexes away); "side" is a hex from it.
	var fight: CombatSim = K.sim(K.fight([K.at(_caster(slam), 3, 1)] as Array[UnitSetup], [K.foe(_post(), 3, 4, "center"), K.foe(_post(), 4, 5, "side")] as Array[UnitSetup]))
	var center: Vector2i = fight.unit_by_id("center").pos
	var side: UnitState = fight.unit_by_id("side")
	var from: Vector2i = side.pos
	fight.step()
	assert_eq(side.pos, ArenaPlane.along(from, ArenaPlane.direction(center, from), 1000))


func test_a_cone_pushes_away_from_the_caster_and_misses_the_fallen() -> void:
	var cone: Dictionary = {"shape": {"kind": "cone"}, "anchor": "target_direction", "effects": [{"type": "knockback", "hexes": 1, "target": "target"}]}
	var fight: CombatSim = K.sim(K.fight([K.at(_caster(cone), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 3, 4, "aim"), K.foe(_post(), 4, 5, "off")] as Array[UnitSetup]))
	var caster: UnitState = fight.units[0]
	var off: UnitState = fight.unit_by_id("off")
	var from: Vector2i = off.pos
	fight.step()
	assert_eq(off.pos, ArenaPlane.along(from, ArenaPlane.direction(caster.pos, from), 1000), "from the caster's center, not the cone's start")
	var fallen: CombatSim = K.sim(K.fight([K.at(_caster({"shape": {"kind": "circle", "radius": 2}, "anchor": "self", "warning_ms": 200}), 3, 2)] as Array[UnitSetup],
		[K.foe(_post(), 3, 4, "a"), K.foe(_post(), 0, 6, "far")] as Array[UnitSetup]))
	fallen.step()
	fallen.unit_by_id("a").hp = 0
	K.step(fallen, 4)
	assert_eq(K.entries(fallen, LogEntry.Kind.AREA_LANDED)[0].amount, 0, "a fallen unit isn't hit")
	assert_eq(_hit_ids(fallen), [])


func test_area_data_is_checked() -> void:
	var cases: Dictionary = {
		"anchor: a line takes target_direction": {"type": "area", "shape": {"kind": "line", "length": 3}, "anchor": "target", "hits": "enemies", "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"anchor: a circle takes target or self": {"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target_direction", "hits": "enemies", "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"an area needs effects": {"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "enemies"},
		"an area's effects aim at \"target\" (each unit hit), on_fire": {"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "enemies", "effects": [{"type": "damage", "amount": 1, "target": "self"}]},
		"an area's effects can't be an area, a leap, or a charge": {"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "enemies", "effects": [{"type": "leap", "max_hexes": 1, "target": "target"}]},
		"an area is cast as its ability fires (on_fire)": {"type": "area", "trigger": "on_hit", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "enemies", "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"hits: unknown value \"foes\"": {"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "self", "hits": "foes", "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
	}
	for expected: String in cases:
		var errors: Array[String] = []
		EffectDef.read(DataReader.new(cases[expected], "e", errors))
		assert_true(errors.any(func(message: String) -> bool: return message.contains(expected)), "expected '%s' in %s" % [expected, errors])
	var good: Array[String] = []
	var area: EffectDef = EffectDef.read(DataReader.new({"type": "area", "shape": {"kind": "cone"}, "anchor": "target_direction", "warning_ms": 750, "hits": "all",
		"effects": [{"type": "apply_status", "status": "burn", "stacks": 3, "target": "target"}]}, "e", good))
	assert_eq(good, [] as Array[String])
	assert_eq([area.shape.kind, area.shape.size, area.anchor, area.warning_ticks, area.hits, area.area_effects.size()], [ShapeDef.Kind.CONE, 3, EffectDef.Anchor.TARGET_DIRECTION, 15, EffectDef.Hits.ALL, 1])
	# Statuses named inside an area are checked with the rest.
	var bad_status: UnitDef = _caster({"shape": {"kind": "circle", "radius": 1}, "anchor": "self", "effects": [{"type": "apply_status", "status": "frost", "target": "target"}]})
	var errors: Array[String] = K.fight([K.at(bad_status, 3, 2)] as Array[UnitSetup], [K.foe(_post(), 3, 4)] as Array[UnitSetup]).validate(K.content())
	assert_true(errors.has("caster at (3, 2) names an unknown status \"frost\""), str(errors))
