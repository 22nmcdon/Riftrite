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
