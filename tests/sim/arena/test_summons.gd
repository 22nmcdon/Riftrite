extends GutTest
## Summons (docs/plans/rebuild-phase1-arena-sim.md, section 10): placement in
## each mode, the fight's order and ids, the cap of units per side, auras,
## the log, and the setup's checks.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A kit summons use: slow, and harmless.
func _pup(overrides: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 50, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	data.merge(overrides, true)
	return K.kit("pup", data)


func _post() -> UnitDef:
	return K.kit("post", {"stats": {"hp": 100000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A unit whose fight-start signature (Call) summons as `summon` says.
func _caller(summon: Dictionary, targeting: String = "self") -> UnitDef:
	var effect: Dictionary = {"type": "summon", "kit": "pup"}
	effect.merge(summon, true)
	return K.kit("caller", {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"signature": {"id": "call", "name": "Call", "trigger": {"kind": "fight_start"}, "targeting": targeting, "max_range": 8, "effects": [effect]},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A fight: `caller` for the enemies on (3, 5), a post for the heroes on
## (3, 1), and the pup kit to summon.
func _fight(caller: UnitDef, pup: UnitDef = _pup(), rocks: Array[Vector2i] = []) -> CombatSim:
	var setup: FightSetup = K.fight([K.at(_post(), 3, 1, "hero")] as Array[UnitSetup], [K.foe(caller, 3, 5)] as Array[UnitSetup], rocks)
	setup.summon_kits.append(pup)
	return K.sim(setup)


func _spots(fight: CombatSim) -> Array:
	var found: Array = []
	for entry: LogEntry in K.entries(fight, LogEntry.Kind.SUMMON):
		if entry.note.is_empty():
			found.append(entry.to_pos)
	return found


func test_edges_nearest_the_caller_first() -> void:
	var fight: CombatSim = _fight(_caller({"placement": "edges", "count": 2}))
	fight.step()
	# The caller stands at (3098, 6000); the bottom edge's spots are a radius
	# in (y 7100), every 125 back from x 6662. The nearest is x 3037; the
	# next that doesn't touch it, x 3912 (875 away), beats x 2162 (also 875
	# away, but further from the caller).
	assert_eq(_spots(fight), [Vector2i(3037, 7100), Vector2i(3912, 7100)])


func test_edges_nearest_the_target() -> void:
	var fight: CombatSim = _fight(_caller({"placement": "edges", "near": "target"}, "nearest"))
	fight.step()
	# The hero stands at (3098, 2000); the top edge is at y 400.
	assert_eq(_spots(fight), [Vector2i(3150, 400)])


func test_edges_follow_the_collapse() -> void:
	var fight: CombatSim = _fight(_caller({"placement": "edges"}))
	fight.safe = fight.grid.safe_rect(1)
	fight.step()
	# The bottom edge is now at y 5850, every 125 back from x 5796; the
	# spots nearest the caller touch it, and x 2296 is the nearest that
	# doesn't.
	assert_eq(_spots(fight), [Vector2i(2296, 5850)], "the edge of what still stands")


func test_adjacent_straight_ahead_first() -> void:
	var fight: CombatSim = _fight(_caller({"placement": "adjacent", "count": 2}))
	var caller: Vector2i = fight.unit_by_id("caller").pos
	fight.step()
	# Ahead for an enemy is toward the heroes (smaller y). The next point
	# clockwise touches the first summon, so the one after it is taken.
	assert_eq(_spots(fight), [caller + Vector2i(0, -800), ArenaPlane.along(caller, Vector2i(-866, -500), 800)])


func test_adjacent_with_no_room_is_dropped() -> void:
	var fight: CombatSim = _fight(_caller({"placement": "adjacent"}), _pup(),
		[Vector2i(3, 4), Vector2i(3, 6), Vector2i(2, 5), Vector2i(4, 5), Vector2i(2, 6), Vector2i(4, 6)] as Array[Vector2i])
	fight.step()
	assert_eq(_spots(fight), [])
	var dropped: LogEntry = K.entries(fight, LogEntry.Kind.SUMMON)[0]
	assert_eq(dropped.to_text(), "[0.05s] caller · Call can't summon pup (no room)")
	assert_eq(fight.units.size(), 2)


func test_hexes_or_the_nearest_free_spot() -> void:
	var fight: CombatSim = _fight(_caller({"placement": "hexes", "hexes": [[0, 6], [3, 5]]}))
	var caller: Vector2i = fight.unit_by_id("caller").pos
	fight.step()
	assert_eq(_spots(fight), [fight.grid.center(0, 6), Displacement.free_spot_near(fight, fight.unit_by_id("pup#2"), caller, null, 0)])
	assert_eq(_spots(fight)[1], caller + Vector2i(0, 800), "(3, 5) is the caller's own: the nearest free spot")


func test_summons_join_the_end_of_the_order_with_their_own_ids() -> void:
	# The setup already has a "pup" of its own.
	var setup: FightSetup = K.fight([K.at(_post(), 3, 1, "hero")] as Array[UnitSetup],
		[K.foe(_caller({"placement": "adjacent", "count": 2}), 3, 5), K.foe(_pup(), 0, 6)] as Array[UnitSetup])
	setup.summon_kits.append(_pup({"mana": {"max": 100, "start": 30},
		"signature": {"id": "howl", "name": "Howl", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "shield", "amount": 5, "target": "self"}]}}))
	var fight: CombatSim = K.sim(setup)
	fight.step()
	assert_eq(fight.units.map(func(unit: UnitState) -> String: return unit.id), ["hero", "caller", "pup", "pup#2", "pup#3"])
	var summoned: UnitState = fight.unit_by_id("pup#2")
	assert_eq([summoned.index, summoned.side, summoned.back_liner, summoned.mana], [3, EffectSource.Team.ENEMIES, false, 30 * Mana.SCALE])
	assert_true(fight.enemies.has(summoned))
	assert_eq(K.entries(fight, LogEntry.Kind.SUMMON)[0].to_text(), "[0.05s] caller · Call summons pup#2 at %s" % LogEntry._point(summoned.pos))


func test_a_summon_acts_on_the_tick_it_joins() -> void:
	var pup: UnitDef = _pup({"signature": {"id": "howl", "name": "Howl", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "shield", "amount": 5, "target": "self"}]}})
	var fight: CombatSim = _fight(_caller({"placement": "adjacent"}), pup)
	fight.step()
	assert_eq(K.entries(fight, LogEntry.Kind.FIRE, "pup").map(func(entry: LogEntry) -> int: return entry.tick), [1], "its fight-start signature fires as it joins")
	assert_eq(fight.unit_by_id("pup").target, fight.unit_by_id("hero"), "it picks a target")


func test_a_side_holds_at_most_its_cap_of_standing_units() -> void:
	var fight: CombatSim = _fight(_caller({"placement": "edges", "count": 4}))
	fight.tuning.max_units_per_side = 3
	fight.step()
	assert_eq(_spots(fight).size(), 2, "the caller and two summons")
	var dropped: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SUMMON).filter(func(entry: LogEntry) -> bool: return not entry.note.is_empty())
	assert_eq(dropped.size(), 2)
	assert_eq(dropped[0].to_text(), "[0.05s] caller · Call can't summon pup (its side is full)")


func test_the_fallen_dont_count_toward_the_cap() -> void:
	var caller: UnitDef = K.kit("caller", {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"signature": {"id": "call", "name": "Call", "trigger": {"kind": "at_time", "at_ms": 100}, "targeting": "self",
			"effects": [{"type": "summon", "kit": "pup", "placement": "edges", "count": 2}]},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var setup: FightSetup = K.fight([K.at(_post(), 3, 1, "hero")] as Array[UnitSetup], [K.foe(caller, 3, 5), K.foe(_pup(), 0, 6, "fallen")] as Array[UnitSetup])
	setup.summon_kits.append(_pup())
	var fight: CombatSim = K.sim(setup)
	fight.tuning.max_units_per_side = 3
	fight.unit_by_id("fallen").hp = 0
	K.step(fight, 2)
	assert_eq(_spots(fight).size(), 2)


func test_auras_reach_summons_and_come_from_them() -> void:
	var aura_pup: UnitDef = _pup({"passives": [{"id": "pack", "name": "Pack", "kind": "aura", "aura": {"target": "all_allies", "stat": "atk_bp", "value": 15000}}],
		"stats": {"hp": 50, "atk": 10, "speed": 0, "range": 1}})
	var fight: CombatSim = _fight(_caller({"placement": "adjacent"}), aura_pup)
	var caller: UnitState = fight.unit_by_id("caller")
	var atk: int = caller.stats.get_stat(UnitStats.Stat.ATK)
	fight.step()
	assert_eq(caller.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(atk, 15000), "the summon's aura reaches its side")
	assert_eq(fight.unit_by_id("pup").stats.get_stat(UnitStats.Stat.ATK), 15)
	assert_eq(K.entries(fight, LogEntry.Kind.AURA).back().to_text(), "[0.05s] pup · Pack aura starts: x1.5 ATK for all allies")


func test_an_event_passive_can_summon() -> void:
	var caller: UnitDef = K.kit("caller", {"stats": {"hp": 100000, "speed": 0, "range": 8},
		"passives": [{"id": "brood", "name": "Brood", "kind": "ability", "effects": [{"trigger": "on_basic_attack", "type": "summon", "kit": "pup", "placement": "edges", "near": "target"}]}],
		"basic_attack": {"effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = _fight(caller)
	K.step(fight, 21)
	var summons: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SUMMON)
	assert_eq([summons.size(), summons[0].source_text(), summons[0].to_pos], [1, "caller · Brood", Vector2i(3150, 400)], "near the caller's target")


func test_reading_summon_effects() -> void:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new({"type": "summon", "kit": "pup", "placement": "hexes", "hexes": [[1, 6], [2, 6]]}, "e", errors))
	assert_eq([errors, effect.target, effect.count, effect.summon_hexes], [[] as Array[String], EffectDef.Target.SELF, 2, [Vector2i(1, 6), Vector2i(2, 6)] as Array[Vector2i]])
	effect = EffectDef.read(DataReader.new({"type": "summon", "kit": "pup", "placement": "edges", "near": "target", "count": 3}, "e", errors))
	assert_eq([errors, effect.count, effect.near_target, effect.placement], [[] as Array[String], 3, true, EffectDef.Placement.EDGES])
	var bad: Array = [
		{"type": "summon", "kit": "pup", "placement": "hexes", "hexes": [[1, 6]], "count": 2},
		{"type": "summon", "kit": "pup", "placement": "hexes", "hexes": []},
		{"type": "summon", "kit": "pup", "placement": "hexes", "hexes": [[1, 6, 2]]},
		{"type": "summon", "kit": "pup", "placement": "adjacent", "near": "target"},
		{"type": "summon", "kit": "pup", "placement": "edges", "count": 0},
		{"type": "summon", "kit": "pup", "placement": "edges", "target": "self"},
		{"type": "summon", "placement": "edges"},
		{"type": "summon", "kit": "pup", "placement": "nowhere"},
		{"type": "area", "shape": {"kind": "circle", "radius": 1}, "anchor": "target", "hits": "enemies", "effects": [{"type": "summon", "kit": "pup", "placement": "edges"}]},
	]
	for data: Dictionary in bad:
		errors.clear()
		EffectDef.read(DataReader.new(data, "e", errors))
		assert_eq(errors.size(), 1, "%s: %s" % [data, errors])


func test_the_setup_checks_summon_kits() -> void:
	var setup: FightSetup = K.fight([K.at(_post(), 3, 1)] as Array[UnitSetup], [K.foe(_caller({"placement": "hexes", "hexes": [[8, 6]]}), 3, 5)] as Array[UnitSetup])
	assert_eq(setup.validate(K.content()), [
		"caller at (3, 5) summons \"pup\", which isn't among the fight's summon kits",
		"caller at (3, 5) summons onto (8, 6), off the board",
	] as Array[String])
	setup = K.fight([K.at(_post(), 3, 1)] as Array[UnitSetup], [K.foe(_caller({"placement": "edges"}), 3, 5)] as Array[UnitSetup])
	var poisoner: UnitDef = _pup({"basic_attack": {"effects": [{"type": "apply_status", "status": "venom", "target": "target"}]}})
	setup.summon_kits.append_array([poisoner, _pup()] as Array[UnitDef])
	assert_eq(setup.validate(K.content()), [
		"summon kit pup names an unknown status \"venom\"",
		"two summon kits are called pup",
	] as Array[String])
	var chain: UnitDef = _pup({"signature": {"id": "split", "name": "Split", "trigger": {"kind": "fight_start"}, "targeting": "self",
		"effects": [{"type": "summon", "kit": "mite", "placement": "adjacent"}]}})
	setup.summon_kits = [chain] as Array[UnitDef]
	assert_eq(setup.validate(K.content()), ["summon kit pup summons \"mite\", which isn't among the fight's summon kits"] as Array[String], "summons' own summons too")
