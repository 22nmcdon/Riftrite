extends GutTest
## Picking targets (docs/plans/rebuild-phase1-arena-sim.md, section 4).

const K = preload("res://tests/sim/sim_test_kit.gd")


func _post(hp: int = 10000) -> UnitDef:
	return K.kit("post", {"stats": {"hp": hp, "speed": 0}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _hunter(reach: int = 1, atk_damage: int = 0) -> UnitDef:
	return K.kit("hunter", {"stats": {"hp": 10000, "speed": 2, "range": reach}, "basic_attack": {"effects": [{"type": "damage", "amount": atk_damage, "target": "target"}]}})


func _picks(fight: CombatSim, unit_id: String) -> Array[String]:
	var found: Array[String] = []
	for entry: LogEntry in K.entries(fight, LogEntry.Kind.TARGET, unit_id):
		found.append(entry.target)
	return found


func test_nearest_is_by_path() -> void:
	# "near" is straight ahead but behind a wall with its gap at the far end;
	# "far" is further in a straight line, but by the gap.
	var rocks: Array[Vector2i] = []
	for col: int in range(0, 6):
		rocks.append(Vector2i(col, 3))
	var fight: CombatSim = K.sim(K.fight([K.at(_hunter(), 1, 2)] as Array[UnitSetup], [K.foe(_post(), 1, 4, "near"), K.foe(_post(), 7, 5, "far")] as Array[UnitSetup], rocks))
	fight.step()
	assert_eq(fight.units[0].target.id, "far", "the wall makes the near one the longer walk")
	var open: CombatSim = K.sim(K.fight([K.at(_hunter(), 1, 2)] as Array[UnitSetup], [K.foe(_post(), 1, 4, "near"), K.foe(_post(), 7, 5, "far")] as Array[UnitSetup]))
	open.step()
	assert_eq(open.units[0].target.id, "near")


func test_ties_go_to_the_earlier_unit() -> void:
	# Both already in reach of a long-range hunter: the first in the fight's order.
	var fight: CombatSim = K.sim(K.fight([K.at(_hunter(6), 3, 1)] as Array[UnitSetup], [K.foe(_post(), 5, 5, "b"), K.foe(_post(), 1, 5, "a")] as Array[UnitSetup]))
	fight.step()
	assert_eq(fight.units[0].target.id, "b")


func test_targets_are_sticky_until_they_fall() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hunter(1, 60), 3, 2)] as Array[UnitSetup], [K.foe(_post(100), 3, 4, "first"), K.foe(_post(), 6, 6, "second")] as Array[UnitSetup]))
	fight.step()
	assert_eq(fight.units[0].target.id, "first")
	# Move the second one right next to the hunter: it keeps its target.
	fight.units[2].pos = fight.units[0].pos + Vector2i(900, 0)
	K.step(fight, 5)
	assert_eq(fight.units[0].target.id, "first", "sticky")
	while fight.units[1].alive:
		fight.step()
	fight.step()
	assert_eq(_picks(fight, "hunter"), ["first", "second"] as Array[String], "a new pick once the first falls")


func test_picks_are_logged_with_their_reason() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_hunter(), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 3, 4, "hound")] as Array[UnitSetup]))
	fight.step()
	var pick: LogEntry = K.entries(fight, LogEntry.Kind.TARGET, "hunter")[0]
	assert_string_contains(pick.to_text(), "hunter targets hound: nearest")


func test_nothing_to_reach_means_no_target() -> void:
	var boxed: Vector2i = Vector2i(4, 5)
	var fight: CombatSim = K.sim(K.fight([K.at(_hunter(), 4, 1)] as Array[UnitSetup], [K.foe(_post(), boxed.x, boxed.y, "boxed")] as Array[UnitSetup], HexGrid.make().neighbors(boxed.x, boxed.y)))
	K.step(fight, 30)
	assert_null(fight.units[0].target)
	assert_eq(_picks(fight, "hunter"), [] as Array[String])
	assert_eq(fight.units[0].pos, fight.grid.center(4, 1), "it waits where it is")


func test_an_enemy_already_in_reach_is_nearest() -> void:
	# "reached" is exactly in reach. "almost" is just out of reach, though the
	# pathfinder's cell under the hunter would count it in reach: what counts
	# is where the hunter really stands.
	var fight: CombatSim = K.sim(K.fight([K.at(_hunter(2), 3, 2)] as Array[UnitSetup], [K.foe(_post(), 6, 6, "reached"), K.foe(_post(), 0, 6, "almost")] as Array[UnitSetup]))
	var hunter: Vector2i = fight.units[0].pos
	fight.units[1].pos = hunter + Vector2i(2000, 0)
	fight.units[2].pos = hunter - Vector2i(2020, 0)
	var nav_cell: Vector2i = fight.nav_for(fight.units[0], null).center(fight.nav_for(fight.units[0], null).cell_at(hunter))
	assert_true(ArenaPlane.within(nav_cell, fight.units[2].pos, 2000), "the test needs the cell to see \"almost\" in reach")
	fight.step()
	assert_eq(fight.units[0].target.id, "reached")


# --- the other rules ---------------------------------------------------------------

## A hunter with `rule`, against five posts: (1, 4) front, (3, 5) and (5, 6)
## back-liners, (6, 4) and (0, 6).
func _rule_fight(rule: String) -> CombatSim:
	var hunter: UnitDef = K.kit("hunter", {"targeting": rule, "stats": {"hp": 10000, "speed": 0, "range": 1}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	return K.sim(K.fight([K.at(hunter, 3, 1)] as Array[UnitSetup],
		[K.foe(_post(), 1, 4, "front"), K.foe(_post(), 3, 5, "back_a"), K.foe(_post(), 5, 6, "back_b"), K.foe(_post(), 6, 4, "side"), K.foe(_post(), 0, 6, "corner")] as Array[UnitSetup]))


func test_weakest_backliner() -> void:
	var fight: CombatSim = _rule_fight("weakest_backliner")
	fight.unit_by_id("front").hp = 100
	fight.unit_by_id("back_a").hp = 5000
	fight.unit_by_id("back_b").hp = 4000
	fight.step()
	assert_eq(_picks(fight, "hunter"), ["back_b"] as Array[String], "the weaker back-liner, not the weaker front-liner")
	assert_eq(K.entries(fight, LogEntry.Kind.TARGET, "hunter")[0].note, "weakest_backliner")
	for id: String in ["back_a", "back_b", "corner"]:
		fight.unit_by_id(id).hp = 0
	K.step(fight, 2)
	assert_eq(fight.units[0].target.id, "front", "no back-liner left: the lowest HP% of all")


func test_hp_share_is_exact() -> void:
	var fight: CombatSim = _rule_fight("weakest_backliner")
	var a: UnitState = fight.unit_by_id("back_a")
	var b: UnitState = fight.unit_by_id("back_b")
	a.hp = 5000
	b.max_hp = 20000
	b.hp = 9999
	fight.step()
	assert_eq(fight.units[0].target.id, "back_b", "49.995% is lower than 50%")
	var tie: CombatSim = _rule_fight("weakest_backliner")
	tie.unit_by_id("back_b").max_hp = 20000
	tie.unit_by_id("back_b").hp = 10000
	tie.unit_by_id("back_a").hp = 5000
	tie.unit_by_id("corner").hp = 9000
	tie.step()
	assert_eq(tie.units[0].target.id, "back_a", "a tie goes to the earlier unit")


func test_farthest_and_largest_group() -> void:
	var far: CombatSim = _rule_fight("farthest")
	far.step()
	assert_eq(far.units[0].target.id, "back_b", "(5, 6) is 5.29 hexes away, (0, 6) 5.20")
	var group: CombatSim = _rule_fight("largest_group")
	# Two gathered round the side post, each out of reach of the other.
	var side: UnitState = group.unit_by_id("side")
	group.unit_by_id("front").pos = side.pos + Vector2i(-900, 0)
	group.unit_by_id("corner").pos = side.pos + Vector2i(900, 900)
	group.step()
	assert_eq(group.units[0].target.id, "side", "two others within 2 hexes of it; no one else has more than one")


func test_highest_mana() -> void:
	var caster: UnitDef = K.kit("caster", {"stats": {"hp": 10000, "speed": 0}, "mana": {"max": 100},
		"signature": {"id": "s", "name": "S", "trigger": {"kind": "mana"}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var hunter: UnitDef = K.kit("hunter", {"targeting": "highest_mana", "stats": {"hp": 10000, "speed": 0}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(hunter, 3, 1)] as Array[UnitSetup], [K.foe(_post(), 3, 4, "plain"), K.foe(caster, 1, 6, "low"), K.foe(caster, 5, 6, "high")] as Array[UnitSetup]))
	fight.unit_by_id("low").mana = 1000
	fight.unit_by_id("high").mana = 3000
	fight.step()
	assert_eq(fight.units[0].target.id, "high")
	var none: CombatSim = K.sim(K.fight([K.at(hunter, 3, 1)] as Array[UnitSetup], [K.foe(_post(), 3, 4, "plain")] as Array[UnitSetup]))
	K.step(none, 3)
	assert_null(none.units[0].target, "a unit with no mana bar is never picked")


func test_lowest_hp_ally_walks_to_its_ally() -> void:
	var healer: UnitDef = K.kit("healer", {"targeting": "lowest_hp_ally", "stats": {"hp": 10000, "speed": 2}, "basic_attack": {"effects": [{"type": "heal", "amount": 5, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(healer, 3, 0), K.at(_post(), 0, 2, "hurt"), K.at(_post(), 6, 2, "fine")] as Array[UnitSetup], [K.foe(_post(), 3, 6)] as Array[UnitSetup]))
	fight.unit_by_id("hurt").hp = 4000
	fight.units[0].hp = 9000
	K.step(fight, 60)
	assert_eq(fight.units[0].target.id, "hurt")
	assert_gt(K.entries(fight, LogEntry.Kind.HEAL, "healer").size(), 0, "it walked over and healed")
	var itself: CombatSim = K.sim(K.fight([K.at(healer, 3, 0), K.at(_post(), 0, 2, "hurt")] as Array[UnitSetup], [K.foe(_post(), 3, 6)] as Array[UnitSetup]))
	itself.units[0].hp = 3000
	itself.unit_by_id("hurt").hp = 4000
	itself.step()
	assert_eq(itself.units[0].target.id, "healer", "the unit itself counts")


func test_a_signature_picks_within_its_reach() -> void:
	var pouncer: UnitDef = K.kit("pouncer", {"stats": {"hp": 10000, "speed": 0},
		"signature": {"id": "pounce", "name": "Pounce", "trigger": {"kind": "fight_start"}, "targeting": "weakest_backliner", "max_range": 4, "shot": false,
			"effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(pouncer, 3, 1)] as Array[UnitSetup],
		[K.foe(_post(), 3, 4, "front"), K.foe(_post(), 3, 5, "near_back"), K.foe(_post(), 7, 6, "far_back")] as Array[UnitSetup]))
	fight.unit_by_id("near_back").hp = 6000
	fight.unit_by_id("far_back").hp = 1000
	fight.step()
	var fired: LogEntry = K.entries(fight, LogEntry.Kind.FIRE, "pouncer").filter(func(entry: LogEntry) -> bool: return entry.source_ability == "pounce")[0]
	assert_eq(fired.target, "near_back", "the weakest back-liner within 4 hexes")


func test_ties_go_to_the_earlier_unit_under_every_rule() -> void:
	# (2, 5) and (4, 5) are as far from (3, 1); listed right first.
	var hunter_for: Callable = func(rule: String) -> UnitDef:
		return K.kit("hunter", {"targeting": rule, "stats": {"hp": 10000, "speed": 0}, "basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var caster: UnitDef = K.kit("caster", {"stats": {"hp": 10000, "speed": 0}, "mana": {"max": 100, "start": 30},
		"signature": {"id": "s", "name": "S", "trigger": {"kind": "mana"}, "effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"basic_attack": {"effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	for rule: String in ["farthest", "largest_group", "highest_mana"]:
		var fight: CombatSim = K.sim(K.fight([K.at(hunter_for.call(rule), 3, 1)] as Array[UnitSetup], [K.foe(caster, 4, 5, "right"), K.foe(caster, 2, 5, "left")] as Array[UnitSetup]))
		fight.step()
		assert_eq(fight.units[0].target.id, "right", rule)
