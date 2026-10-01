extends GutTest
## Gambits (docs/plans/rebuild-phase5c-combos.md, step 6d, section 14.7):
## where a gambit lets a hero start, arriving late, swapping places, and the
## fight-start and arrival passives, with the gambits as the data has them.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _kit(item_id: String, rank: int = 1, hero_id: String = "hero", stats: Dictionary = {}) -> UnitDef:
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 2, "range": 2}
	all_stats.merge(stats, true)
	var kit: UnitDef = K.kit(hero_id, {"stats": all_stats,
		"basic_attack": {"cooldown_ms": 1000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}})
	return _run.items[item_id].mod_at(rank).apply(kit) if not item_id.is_empty() else kit


func _dummy(col: int = 3, row: int = 6, dummy_id: String = "dummy") -> UnitSetup:
	return K.foe(K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}), col, row, dummy_id)


func _errors(heroes: Array[UnitSetup], enemies: Array[UnitSetup] = [_dummy()]) -> Array[String]:
	return K.fight(heroes, enemies).validate(K.content())


func test_where_a_gambit_lets_a_hero_start() -> void:
	assert_false(_errors([K.at(_kit(""), 3, 3)] as Array[UnitSetup]).is_empty(), "no gambit: not on the middle row")
	assert_eq(_errors([K.at(_kit("infiltrate"), 3, 3)] as Array[UnitSetup]), [] as Array[String], "Infiltrate: the middle row")
	assert_false(_errors([K.at(_kit("infiltrate"), 3, 4)] as Array[UnitSetup]).is_empty(), "not the enemies' front row at rank I")
	assert_eq(_errors([K.at(_kit("infiltrate", 2), 3, 4)] as Array[UnitSetup]), [] as Array[String], "rank II: their front row too")
	assert_false(_errors([K.at(_kit("infiltrate", 2), 3, 5)] as Array[UnitSetup]).is_empty(), "but no deeper")
	assert_eq(_errors([K.at(_kit("late_arrival"), 7, 5)] as Array[UnitSetup]), [] as Array[String], "Late Arrival: any edge hex")
	assert_eq(_errors([K.at(_kit("late_arrival"), 3, 1)] as Array[UnitSetup]), [] as Array[String], "and its own zone")
	assert_false(_errors([K.at(_kit("late_arrival"), 3, 4)] as Array[UnitSetup]).is_empty(), "not the middle of the board")


func test_two_heroes_share_a_hex_with_stand_together() -> void:
	var holder: UnitSetup = K.at(_kit("stand_together"), 3, 1, "holder")
	var friend: UnitSetup = K.at(_kit("", 1, "friend"), 3, 1, "friend")
	assert_eq(_errors([holder, friend] as Array[UnitSetup]), [] as Array[String])
	var third: UnitSetup = K.at(_kit("", 1, "third"), 3, 1, "third")
	assert_false(_errors([holder, friend, third] as Array[UnitSetup]).is_empty(), "two at most")
	assert_false(_errors([K.at(_kit(""), 3, 1, "a"), K.at(_kit("", 1, "b"), 3, 1, "b")] as Array[UnitSetup]).is_empty(), "not without it")
	var fight: CombatSim = K.sim(K.fight([holder, friend] as Array[UnitSetup], [_dummy()] as Array[UnitSetup]))
	var a: UnitState = fight.unit_by_id("holder")
	var b: UnitState = fight.unit_by_id("friend")
	assert_eq(a.pos.y, b.pos.y)
	assert_eq(b.pos.x - a.pos.x, Gambits.SHARED_GAP, "side by side across the hex")
	assert_true(K.no_overlaps(fight))


func test_a_late_arrival() -> void:
	var late: UnitSetup = K.at(_kit("late_arrival", 3), 0, 2, "late")
	var other: UnitSetup = K.at(_kit("", 1, "other"), 3, 1, "other")
	var fight: CombatSim = K.sim(K.fight([late, other] as Array[UnitSetup], [_dummy(0, 6)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("late")
	assert_false(unit.alive, "away at the start")
	assert_true(unit.arriving)
	K.step(fight, 70)
	assert_false(unit.alive, "still away before 4s")
	K.step(fight, 15)
	assert_true(unit.alive, "in at 4s (rank II and III)")
	var arrive: Array[LogEntry] = K.entries(fight, LogEntry.Kind.ARRIVE)
	assert_eq(arrive.size(), 1)
	assert_eq([arrive[0].target, arrive[0].source_ability_name], ["late", "Late Arrival"])
	assert_string_contains(arrive[0].to_text(), "late arrives at")
	var applied: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "late").map(func(entry: LogEntry) -> String: return entry.status)
	assert_has(applied, "stealth", "hidden on arrival")
	assert_has(applied, "late_surge", "and surging (rank II)")


func test_an_arriving_hero_isnt_down() -> void:
	var late: UnitSetup = K.at(_kit("late_arrival"), 0, 2, "late")
	var other: UnitSetup = K.at(_kit("", 1, "other"), 3, 1, "other")
	var fight: CombatSim = K.sim(K.fight([late, other] as Array[UnitSetup], [_dummy()] as Array[UnitSetup]))
	fight.unit_by_id("other").hp = 0
	fight.step()
	assert_false(fight.finished, "one still to arrive keeps the fight going")
	K.step(fight, 120)
	assert_true(fight.unit_by_id("late").alive)


func test_switch_places() -> void:
	var switcher: UnitSetup = K.at(_kit("switch_places", 3, "switcher", {"speed": 0}), 0, 0, "switcher")
	var far: UnitSetup = K.at(_kit("", 1, "far", {"speed": 0}), 7, 2, "far")
	var fight: CombatSim = K.sim(K.fight([switcher, far] as Array[UnitSetup], [_dummy()] as Array[UnitSetup]))
	var a: Vector2i = fight.unit_by_id("switcher").pos
	var b: Vector2i = fight.unit_by_id("far").pos
	K.step(fight, 200)
	assert_eq([fight.unit_by_id("switcher").pos, fight.unit_by_id("far").pos], [b, a], "swapped at 10s")
	var pushes: Array = K.entries(fight, LogEntry.Kind.PUSH).filter(func(entry: LogEntry) -> bool: return entry.note == "swapped places")
	assert_eq(pushes.size(), 2)
	assert_eq(K.entries(fight, LogEntry.Kind.SHIELD).size(), 2, "rank III: both Shielded")
	var chosen: CombatSim = K.sim(K.fight([switcher, far] as Array[UnitSetup], [_dummy()] as Array[UnitSetup]))
	chosen.unit_by_id("switcher").swap_at = 100
	K.step(chosen, 100)
	assert_eq(chosen.unit_by_id("switcher").pos, b, "at the moment chosen")


func test_ambush_and_rear_guard_start_hidden() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(_kit("ambush", 3), 3, 1)] as Array[UnitSetup], [_dummy(3, 4)] as Array[UnitSetup]))
	var hero: UnitState = fight.unit_by_id("hero")
	assert_true(Statuses.is_stealthed(hero), "hidden from the start")
	assert_ne(Statuses.find(hero, "ambush_2"), null)
	for i: int in 40:
		fight.step()
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "hero")
	assert_false(hits.is_empty())
	assert_true(hits[0].crit, "its first attack crits")
	assert_true(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").any(func(entry: LogEntry) -> bool: return entry.status == "marked"), "rank III Marks")
	var guard: CombatSim = K.sim(K.fight([K.at(_kit("rear_guard", 2, "hero", {"speed": 0, "range": 1}), 4, 1), K.at(_kit("", 1, "decoy", {"speed": 0}), 3, 1, "decoy")] as Array[UnitSetup],
		[K.foe(K.kit("walker", {"stats": {"hp": 100000, "speed": 2, "range": 1}, "basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}), 3, 6, "walker")] as Array[UnitSetup]))
	var rear: UnitState = guard.unit_by_id("hero")
	K.step(guard, 5)
	assert_true(Statuses.is_stealthed(rear), "hidden while nothing's near")
	for i: int in 200:
		guard.step()
		if not Statuses.is_stealthed(rear):
			break
	assert_false(Statuses.is_stealthed(rear), "an enemy came within 2 hexes")
	assert_true(K.entries(guard, LogEntry.Kind.STATUS_ENDED).any(func(entry: LogEntry) -> bool: return entry.note == "an enemy came near"))
	guard.step()
	assert_ne(Statuses.find(rear, "rear_guard"), null, "rank II: faster out of hiding")


func test_the_run_shares_and_chooses() -> void:
	const Bot = preload("res://tools/run_bot.gd")
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, Bot.first_vows(_run.content), errors)
	for id: String in ["stand_together", "switch_places"]:
		flow.state.stash.append(id)
		flow.state.item_ranks[id] = 2
	assert_eq(flow.equip("brannoc", 0, "stand_together"), "")
	assert_eq(flow.equip("maren", 0, "switch_places"), "")
	assert_eq(flow.set_gambit_at("maren", 15), "")
	assert_eq(flow.set_gambit_at("maren", 7), "it swaps at 5, 10, or 15 seconds")
	assert_eq(flow.set_gambit_at("vell", 5), "vell holds no gambit whose moment it can choose")
	flow.leave_camp()
	flow.choose_fight(0)
	var formation: Dictionary[String, Vector2i] = Bot.formation()
	formation["vell"] = formation["brannoc"]
	var setup: FightSetup = flow.fight_setup(formation, errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(setup.heroes[2].def.place_rule, "share", "Vell, sharing Brannoc's hex, gets his gambit too")
	assert_eq(setup.heroes[1].swap_at, 15 * FixedMath.TICKS_PER_SECOND)
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_eq(loaded.hero("maren").gambit_at, 15)
