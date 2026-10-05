extends GutTest
## The void, Act 3's board rule (docs/plans/rebuild-phase8-act3.md, part
## 8c-5b; Islands): the setup's checks, walkers going over a bridge, fliers
## crossing, landing off it, charges and hops stopping short, falls and what
## they set off (and don't), and the islands with their condition.

const K = preload("res://tests/sim/sim_test_kit.gd")


static func still(unit_id: String, extra: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 5000, "atk": 10, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}
	for key: String in extra:
		if key == "stats":
			(data["stats"] as Dictionary).merge(extra["stats"], true)
		else:
			data[key] = extra[key]
	return K.kit(unit_id, data)


## The whole of `row` but the hexes in `bridges`.
static func row_but(row: int, bridges: Array[int]) -> Array[Vector2i]:
	var hexes: Array[Vector2i] = []
	for col: int in 8:
		if not bridges.has(col):
			hexes.append(Vector2i(col, row))
	return hexes


## A unit that knocks its target a hex back from 2 hexes away (no damage, so
## only a fall makes it the last to hit), and on a kill gains a Shield.
static func pusher(unit_id: String = "pusher") -> UnitDef:
	return still(unit_id, {"stats": {"range": 2}, "basic_attack": {"id": "shove", "name": "Shove", "cooldown_ms": 1000,
		"effects": [{"type": "knockback", "hexes": 1, "target": "target"}]},
		"passives": [{"id": "glee", "name": "Glee", "kind": "ability", "effects": [{"trigger": "on_kill", "type": "shield", "amount": 7, "target": "self"}]}]})


## The pusher at (3, 2) and `victim` at (3, 4) with the void at (3, 5) behind
## it (the row but a bridge at its far end); the enemies' far row is its own
## island.
static func fall_setup(victim: UnitDef) -> FightSetup:
	var setup: FightSetup = K.fight([K.at(pusher(), 3, 2)] as Array[UnitSetup], [K.foe(victim, 3, 4)] as Array[UnitSetup])
	setup.void_hexes = row_but(5, [7] as Array[int])
	return setup


## A fight for the log's audit and replay (test_arena_log.gd): heroes push
## enemies off an edge, and a walker goes over a bridge.
static func void_setup(fight_seed: int = 3) -> FightSetup:
	var walker: UnitDef = still("walker", {"stats": {"speed": 2}, "basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}})
	var setup: FightSetup = K.fight([K.at(pusher(), 3, 2), K.at(still("anchor", {"stats": {"hp": 400}}), 6, 1)] as Array[UnitSetup],
		[K.foe(still("victim", {"stats": {"hp": 400}}), 3, 4), K.foe(walker, 6, 4)] as Array[UnitSetup], [] as Array[Vector2i], fight_seed)
	setup.void_hexes = row_but(5, [7] as Array[int])
	setup.void_hexes.append(Vector2i(5, 3))
	return setup


func test_the_islands_and_the_setups_checks() -> void:
	var grid: HexGrid = K.content().tuning.make_grid()
	var whole: PackedInt32Array = Islands.groups(grid, row_but(3, [] as Array[int]))
	assert_eq([whole[grid.index(3, 0)], whole[grid.index(3, 6)], whole[grid.index(3, 3)]], [0, 1, -1], "a whole void row makes two islands")
	var bridged: PackedInt32Array = Islands.groups(grid, row_but(3, [4] as Array[int]))
	assert_eq([bridged[grid.index(0, 0)], bridged[grid.index(7, 6)]], [0, 0], "a bridge joins them")
	var problems: Array[String] = Islands.problems(grid, [Vector2i(9, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(1, 3), Vector2i(0, 3)] as Array[Vector2i],
		[Vector2i(1, 3)] as Array[Vector2i], [Vector2i(2, 3)] as Array[Vector2i], [] as Array[Vector2i], "")
	assert_eq(problems, ["void at (9, 3) is off the board", "void at (1, 3) is on a rock", "void at (2, 3) is on water", "void at (1, 3) is on a rock"] as Array[String])
	var apart: Array[String] = Islands.problems(grid, row_but(3, [] as Array[int]), [] as Array[Vector2i], [] as Array[Vector2i], [Vector2i(2, 5)] as Array[Vector2i], "")
	assert_eq(apart, ["an enemy at (2, 5) stands on an island the heroes' rows don't reach"] as Array[String], "a fight that couldn't meet")
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(still("foe"), 3, 5)] as Array[UnitSetup])
	setup.void_hexes = [Vector2i(3, 2), Vector2i(3, 5)] as Array[Vector2i]
	var errors: Array[String] = setup.validate(K.content())
	assert_true(errors.has("hero at (3, 2) is on the void"), str(errors))
	assert_true(errors.has("an enemy at (3, 5) is on the void"), str(errors))


func test_a_walker_goes_over_the_bridge() -> void:
	var walker: UnitDef = still("walker", {"stats": {"speed": 2}, "basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}})
	var setup: FightSetup = K.fight([K.at(still("hero"), 6, 1)] as Array[UnitSetup], [K.foe(walker, 6, 5)] as Array[UnitSetup])
	setup.void_hexes = row_but(3, [1] as Array[int])
	var fight: CombatSim = K.sim(setup)
	var unit: UnitState = fight.unit_by_id("walker")
	var over_void: int = 0
	var crossed: bool = false
	for i: int in 600:
		fight.step()
		over_void += 1 if fight.on_void(unit.pos) else 0
		crossed = crossed or fight.grid.hex_at(unit.pos) == fight.grid.index(1, 3)
		if not K.entries(fight, LogEntry.Kind.DAMAGE, "walker").is_empty():
			break
	assert_eq(over_void, 0, "never over the void")
	assert_true(crossed, "it crossed on the bridge")
	assert_false(K.entries(fight, LogEntry.Kind.DAMAGE, "walker").is_empty(), "and reached the hero")


func test_a_flier_crosses_the_void() -> void:
	var flier: UnitDef = still("flier", {"stats": {"speed": 3}, "traits": ["flying"], "basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 5, "target": "target"}]}})
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 1)] as Array[UnitSetup], [K.foe(flier, 3, 5)] as Array[UnitSetup])
	setup.void_hexes = row_but(3, [7] as Array[int])
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 80)
	assert_false(K.entries(fight, LogEntry.Kind.DAMAGE, "flier").is_empty(), "straight over it")
	assert_false(fight.on_void(fight.unit_by_id("flier").pos), "and lands off it")


func test_spots_to_land_on_stay_off_the_void() -> void:
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(still("foe"), 3, 4)] as Array[UnitSetup])
	setup.void_hexes = row_but(3, [7] as Array[int])
	var fight: CombatSim = K.sim(setup)
	var hero: UnitState = fight.unit_by_id("hero")
	var middle: Vector2i = fight.grid.center(3, 3)
	assert_true(fight.on_void(middle))
	assert_false(fight.fits(hero, middle), "no landing on the void")
	assert_false(fight.fits_ground(hero, middle), "nor walking onto it")
	var spot: Vector2i = Displacement.free_spot_near(fight, hero, middle, null, 0)
	assert_true(spot.x >= 0 and not fight.on_void(spot), "the nearest free spot is off it")


func test_a_push_over_the_void_is_a_fall_and_a_kill() -> void:
	var fall_rest: Dictionary = {"id": "burst", "name": "Burst", "kind": "ability",
		"effects": [{"trigger": "on_fall", "type": "area", "shape": {"kind": "circle", "radius": 9}, "anchor": "self", "hits": "enemies",
			"effects": [{"type": "apply_status", "status": "slow", "duration_ms": 3000, "target": "target"}]}]}
	var rise: Dictionary = {"id": "reform", "name": "Reform", "kind": "rise", "times": 1, "after_ms": 500, "hp_pct": 50}
	var victim: UnitDef = still("victim", {"passives": [fall_rest, rise]})
	var fight: CombatSim = K.sim(fall_setup(victim))
	Statuses.apply(fight, fight.unit_by_id("victim"), "undying", 1, 400, EffectSource.make("victim", "victim_attack", "Strike"))
	K.step(fight, 60)
	var fell: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FELL)
	assert_eq(fell.size(), 1)
	assert_eq([fell[0].target, fell[0].source_unit, fell[0].source_ability], ["victim", "pusher", "shove"], "sourced to the push")
	assert_true(fight.on_void(fell[0].to_pos))
	var victim_state: UnitState = fight.unit_by_id("victim")
	assert_false(victim_state.alive, "gone, though Undying was on it")
	var deaths: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DEATH)
	assert_eq(deaths.size(), 1)
	assert_eq(deaths[0].note, "fell into the void")
	assert_eq(K.entries(fight, LogEntry.Kind.SAVED), [] as Array[LogEntry], "no Undying")
	assert_eq(K.entries(fight, LogEntry.Kind.AREA_LANDED, "victim"), [] as Array[LogEntry], "no on_fall effects")
	assert_eq(K.entries(fight, LogEntry.Kind.RISE), [] as Array[LogEntry], "no rise")
	assert_eq(K.entries(fight, LogEntry.Kind.SUMMON), [] as Array[LogEntry])
	assert_true(K.entries(fight, LogEntry.Kind.SHIELD, "pusher").any(func(entry: LogEntry) -> bool: return entry.source_ability == "glee"), "a kill for the pusher (on_kill)")
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "victim").filter(func(entry: LogEntry) -> bool: return entry.status == "stun"), [] as Array[LogEntry], "no stun")
	assert_true(fight.finished)
	assert_eq(fight.outcome, FightResult.Outcome.VICTORY)


func test_a_unit_that_falls_acts_no_more() -> void:
	# It shoots every tick, so acting on the tick it went over would show.
	var shooter: UnitDef = still("victim", {"stats": {"range": 3}, "basic_attack": {"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 1, "target": "target"}]}})
	var fight: CombatSim = K.sim(fall_setup(shooter))
	K.step(fight, 60)
	var fell: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FELL)
	assert_eq(fell.size(), 1)
	var after: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHOT, "victim").filter(func(entry: LogEntry) -> bool: return entry.tick >= fell[0].tick)
	assert_eq(after, [] as Array[LogEntry], "no shot from the tick it fell")


func test_a_hero_who_falls_is_down() -> void:
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(pusher("brute"), 3, 4), K.foe(still("other"), 6, 6)] as Array[UnitSetup])
	setup.void_hexes = row_but(1, [7] as Array[int])
	var result: FightResult = K.run(setup)
	var fell: Array[LogEntry] = result.combat_log.of_kind(LogEntry.Kind.FELL)
	assert_eq(fell.size(), 1)
	assert_eq(fell[0].target, "hero")
	assert_eq(result.down_at_end(), ["hero"] as Array[String], "down at the end: a wound")
	assert_eq(result.outcome, FightResult.Outcome.DEFEAT)


func test_a_flier_is_never_pushed_off() -> void:
	var flier: UnitDef = still("victim", {"traits": ["flying"]})
	var fight: CombatSim = K.sim(fall_setup(flier))
	K.step(fight, 60)
	assert_eq(K.entries(fight, LogEntry.Kind.FELL), [] as Array[LogEntry])
	assert_true(fight.unit_by_id("victim").alive)
	assert_false(fight.on_void(fight.unit_by_id("victim").pos), "dropped clear of it")


func test_a_charge_stops_at_the_edge() -> void:
	var charger: UnitDef = still("charger", {"signature": {"id": "rush", "name": "Rush", "trigger": {"kind": "fight_start"}, "targeting": "nearest", "max_range": 4,
		"effects": [{"type": "charge", "hexes": 3, "knockback": 1, "target": "target"}]}})
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(charger, 3, 4)] as Array[UnitSetup])
	setup.void_hexes = row_but(3, [7] as Array[int])
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 3)
	var charges: Array[LogEntry] = K.entries(fight, LogEntry.Kind.CHARGE, "charger")
	assert_eq(charges.size(), 1)
	assert_eq(charges[0].note, "stopped at the void's edge")
	assert_true(charges[0].to_pos.y < charges[0].from_pos.y, "it ran some way")
	assert_false(fight.on_void(fight.unit_by_id("charger").pos))
	assert_eq(K.entries(fight, LogEntry.Kind.FELL), [] as Array[LogEntry])
	assert_eq(K.entries(fight, LogEntry.Kind.PUSH), [] as Array[LogEntry], "it never reached the hero to knock it back")


func test_a_hop_lands_short_of_the_void() -> void:
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], [K.foe(still("hopper"), 3, 4)] as Array[UnitSetup])
	setup.void_hexes = row_but(5, [7] as Array[int])
	var fight: CombatSim = K.sim(setup)
	fight.step()
	var hopper: UnitState = fight.unit_by_id("hopper")
	fight.unit_by_id("hero").pos = hopper.pos - Vector2i(0, 300)
	var start: Vector2i = hopper.pos
	assert_true(Displacement.hop(fight, hopper, EffectSource.make("hopper", "hop", "Hop")))
	assert_false(fight.on_void(hopper.pos))
	assert_true(hopper.pos.y > start.y, "it hopped some way")
	assert_eq(K.entries(fight, LogEntry.Kind.HOP)[-1].note, "cut short")


func test_islands_are_marked_for_the_condition() -> void:
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 1), K.at(still("ally"), 6, 1)] as Array[UnitSetup], [K.foe(still("foe"), 3, 5)] as Array[UnitSetup])
	setup.void_hexes = row_but(3, [0] as Array[int])
	setup.void_hexes.append_array([Vector2i(5, 1), Vector2i(5, 0), Vector2i(5, 2), Vector2i(4, 2), Vector2i(4, 1), Vector2i(4, 0)])
	var fight: CombatSim = K.sim(setup)
	fight.step()
	var hero: UnitState = fight.unit_by_id("hero")
	var ally: UnitState = fight.unit_by_id("ally")
	var foe: UnitState = fight.unit_by_id("foe")
	assert_true(hero.island >= 0 and ally.island >= 0)
	assert_ne(hero.island, ally.island, "a shelf cut off by the void")
	assert_eq(hero.island, foe.island, "joined by the bridge at (0, 3)")
	var errors: Array[String] = []
	var condition: UnitCondition = UnitCondition.read(DataReader.new({"same_island": true}, "test", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([condition.holds(foe, hero), condition.holds(ally, hero), condition.holds(hero, hero), condition.holds(foe)], [true, false, true, false])
	assert_eq(condition.describe(), "on its island")
	# Without void, every unit is on one island.
	var plain: CombatSim = K.sim(K.fight([K.at(still("hero"), 3, 1), K.at(still("ally"), 6, 1)] as Array[UnitSetup], [K.foe(still("foe"), 3, 5)] as Array[UnitSetup]))
	plain.step()
	assert_true(condition.holds(plain.unit_by_id("ally"), plain.unit_by_id("hero")))


func test_a_fight_without_void_makes_none() -> void:
	var fight: CombatSim = K.sim(K.fight([K.at(still("hero"), 3, 1)] as Array[UnitSetup], [K.foe(still("foe"), 3, 5)] as Array[UnitSetup]))
	assert_null(fight.islands)
	assert_false(fight.has_void)
	assert_false(fight.on_void(fight.grid.center(3, 3)))


func test_content_checks_an_encounters_void() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var encounters: Array = JSON.parse_string(texts[ContentDb.ENCOUNTERS_FILE])
	var first: Dictionary = encounters[0]
	var rocks: Array = first.get("rocks", [])
	var row: Array = []
	for col: int in 8:
		if not rocks.has([col, 3]) and not rocks.has([float(col), 3.0]):
			row.append([col, 3])
	first["void"] = row
	texts[ContentDb.ENCOUNTERS_FILE] = JSON.stringify(encounters)
	var content: ContentDb = ContentDb.load_texts(texts)
	assert_true(content.errors.any(func(error: String) -> bool: return error.contains(first["id"]) and error.contains("the heroes' rows don't reach")), str(content.errors))
	(row as Array).remove_at(0)
	first["void"] = row
	texts[ContentDb.ENCOUNTERS_FILE] = JSON.stringify(encounters)
	var bridged: ContentDb = ContentDb.load_texts(texts)
	assert_eq(bridged.errors, [] as Array[String], "a bridge joins them")
	assert_eq(bridged.encounters[first["id"]].void_hexes.size(), row.size())


# --- 8c-5c-1: bridges that break, the hook, the shove ------------------------

## A heart on the enemies' far row that severs a bridge every `every_ms`
## (warned 0.5s, broken 2s), over a void row 3 bridged at (0, 3) and (7, 3).
static func sever_setup(every_ms: int = 1000, lasts_ms: int = 2000) -> FightSetup:
	var heart: UnitDef = still("heart", {"passives": [{"id": "severing", "name": "Severing", "kind": "ability",
		"effects": [{"trigger": "on_interval", "interval_ms": every_ms, "type": "sever", "warning_ms": 500, "duration_ms": lasts_ms}]}]})
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 1)] as Array[UnitSetup], [K.foe(heart, 3, 6)] as Array[UnitSetup])
	setup.void_hexes = row_but(3, [0, 7] as Array[int])
	setup.bridges = [[Vector2i(0, 3)], [Vector2i(7, 3)]] as Array[Array]
	return setup


func test_a_bridge_is_warned_breaks_and_reforms() -> void:
	var fight: CombatSim = K.sim(sever_setup())
	var hero: UnitState = fight.unit_by_id("hero")
	fight.step()
	hero.pos = fight.grid.center(0, 3)
	var grid: HexGrid = fight.grid
	assert_ne(fight.islands.island_of_hex[grid.index(3, 0)], fight.islands.island_of_hex[grid.index(3, 6)], "the bridges join two islands")
	assert_eq(fight.islands.island_of_hex[grid.index(0, 3)], -1, "a bridge is no island's (8c-6a)")
	K.step(fight, 19)
	var lines: Array[LogEntry] = K.entries(fight, LogEntry.Kind.VOID)
	assert_eq(lines.size(), 1)
	assert_eq([lines[0].note, lines[0].source_unit, lines[0].source_ability, lines[0].amount], ["warns bridge 1", "heart", "severing", 1])
	assert_eq(lines[0].end_tick, lines[0].tick + 10)
	assert_eq(fight.islands.warned_hexes(), [Vector2i(0, 3)] as Array[Vector2i])
	assert_false(fight.on_void(hero.pos), "not yet")
	K.step(fight, 10)
	lines = K.entries(fight, LogEntry.Kind.VOID)
	assert_eq(lines[-1].note, "breaks bridge 1")
	assert_true(fight.on_void(fight.grid.center(0, 3)), "the bridge is void now")
	var fell: Array[LogEntry] = K.entries(fight, LogEntry.Kind.FELL)
	assert_eq(fell.size(), 1, "the hero on it fell")
	assert_eq([fell[0].target, fell[0].source_ability], ["hero", "severing"])
	assert_eq(fight.islands.island_of_hex[grid.index(0, 3)], -1, "the bridge is part of the void")


func test_bridges_break_in_turn_and_come_back() -> void:
	var setup: FightSetup = sever_setup()
	setup.heroes = [K.at(still("hero", {"stats": {"hp": 100000}}), 3, 1)] as Array[UnitSetup]
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 100)
	var notes: Array = K.entries(fight, LogEntry.Kind.VOID).map(func(entry: LogEntry) -> String: return entry.note)
	assert_eq(notes.slice(0, 6), ["warns bridge 1", "breaks bridge 1", "warns bridge 2", "breaks bridge 2", "finds every bridge already breaking", "reforms bridge 1"],
		"in turn; a third sever finds both breaking")
	assert_true(notes.has("reforms bridge 2"))
	assert_true(notes.count("warns bridge 1") >= 2, "and round again")


func test_the_next_bridge_is_the_next_in_turn() -> void:
	# Each bridge is back before the next sever, so only the turn picks.
	var fight: CombatSim = K.sim(sever_setup(1000, 300))
	K.step(fight, 70)
	var warned: Array = K.entries(fight, LogEntry.Kind.VOID).filter(func(entry: LogEntry) -> bool: return entry.note.begins_with("warns")).map(func(entry: LogEntry) -> String: return entry.note)
	assert_eq(warned.slice(0, 3), ["warns bridge 1", "warns bridge 2", "warns bridge 1"])


func test_a_sever_without_bridges_says_so() -> void:
	var setup: FightSetup = sever_setup()
	setup.void_hexes.clear()
	setup.bridges.clear()
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 21)
	assert_eq(K.entries(fight, LogEntry.Kind.VOID)[0].note, "finds no bridge to break")
	assert_null(fight.islands)
	# Bridges but no void: the islands come with the first sever.
	var bare: FightSetup = sever_setup()
	bare.void_hexes.clear()
	var later: CombatSim = K.sim(bare)
	K.step(later, 31)
	assert_true(later.has_void)
	assert_true(later.on_void(later.grid.center(0, 3)))


func test_bridges_are_checked() -> void:
	var grid: HexGrid = K.content().tuning.make_grid()
	var problems: Array[String] = Islands.problems(grid, [Vector2i(1, 3)] as Array[Vector2i], [Vector2i(2, 3)] as Array[Vector2i], [] as Array[Vector2i], [] as Array[Vector2i], "",
		[[Vector2i(1, 3)], [Vector2i(2, 3)], [Vector2i(9, 9)], [], [Vector2i(4, 3)], [Vector2i(4, 3)]] as Array[Array])
	assert_eq(problems, ["bridge 1's hex (1, 3) is on a rock, water, or the void", "bridge 2's hex (2, 3) is on a rock, water, or the void", "bridge 3's hex (9, 9) is off the board",
		"bridge 4 has no hexes", "bridge 6's hex (4, 3) is in another bridge too"] as Array[String])


func test_a_hook_carries_its_catch_beside_it() -> void:
	var angler: UnitDef = still("angler", {"stats": {"range": 5}, "basic_attack": {"id": "hook", "name": "Hook", "cooldown_ms": 1000,
		"effects": [{"type": "pull", "to": "beside", "target": "target"}]}})
	var setup: FightSetup = K.fight([K.at(still("hero"), 3, 1)] as Array[UnitSetup], [K.foe(angler, 3, 5)] as Array[UnitSetup])
	setup.void_hexes = row_but(3, [7] as Array[int])
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 30)
	var pushes: Array[LogEntry] = K.entries(fight, LogEntry.Kind.PUSH)
	assert_false(pushes.is_empty())
	assert_eq(pushes[0].note, "hooked")
	var hero: UnitState = fight.unit_by_id("hero")
	assert_false(fight.on_void(hero.pos), "never over the void")
	assert_true(ArenaPlane.distance(hero.pos, fight.unit_by_id("angler").pos) <= 400, "beside it, across the gap")
	assert_eq(hero.island, fight.unit_by_id("angler").island)
	assert_eq(K.entries(fight, LogEntry.Kind.FELL), [] as Array[LogEntry])
	# The unpushable charm: it can't be hooked.
	var braced: UnitDef = still("hero", {"passives": [{"id": "braced", "name": "Braced", "kind": "aura", "aura": {"stat": "unpushable", "value": 1, "target": "holder"}}]})
	setup.heroes = [K.at(braced, 3, 1)] as Array[UnitSetup]
	var held: CombatSim = K.sim(setup)
	K.step(held, 30)
	assert_eq(K.entries(held, LogEntry.Kind.PUSH), [] as Array[LogEntry])
	assert_eq(K.entries(held, LogEntry.Kind.RESISTED)[0].status_name, "being hooked")


## Cliffmites that shove the hero they bite half a hex toward the nearest
## edge while `needed` of them are on it.
static func mite(unit_id: String, needed: int) -> UnitDef:
	return still(unit_id, {"stats": {"speed": 2}, "basic_attack": {"id": "bite", "name": "Bite", "cooldown_ms": 500,
		"effects": [{"type": "damage", "amount": 1, "target": "target"},
			{"type": "knockback", "hexes": 1, "distance_bp": 5000, "toward": "edge", "when_attackers": needed, "target": "target"}]}})


func test_a_crowd_shoves_toward_the_edge() -> void:
	for count: int in [2, 3]:
		var mites: Array[UnitSetup] = []
		for i: int in count:
			mites.append(K.foe(mite("mite", 3), 2 + i, 4, "mite" if i == 0 else "mite#%d" % (i + 1)))
		var setup: FightSetup = K.fight([K.at(still("hero"), 3, 2)] as Array[UnitSetup], mites)
		setup.void_hexes = row_but(0, [] as Array[int])
		var fight: CombatSim = K.sim(setup)
		K.step(fight, 120)
		var shoves: Array[LogEntry] = K.entries(fight, LogEntry.Kind.PUSH)
		if count == 2:
			assert_eq(shoves, [] as Array[LogEntry], "two on it aren't enough")
			continue
		assert_false(shoves.is_empty(), "three on it shove")
		assert_eq(shoves[0].note.get_slice(",", 0), "knocked back toward the edge")
		assert_true(shoves[0].to_pos.y < shoves[0].from_pos.y, "toward the void behind it, not away from the mite")
		assert_eq(ArenaPlane.distance(shoves[0].from_pos, shoves[0].to_pos), 500, "half a hex")


func test_the_new_keys_are_refused_where_they_dont_belong() -> void:
	for data: Dictionary in [{"type": "pull", "to": "beside", "hexes": 2, "target": "target"}, {"type": "pull", "hexes": 1, "toward": "edge", "target": "target"},
			{"type": "knockback", "hexes": 1, "toward": "water", "target": "target"}, {"type": "sever", "duration_ms": 1000}]:
		var errors: Array[String] = []
		EffectDef.read(DataReader.new(data, "test", errors))
		assert_false(errors.is_empty(), "refused: %s" % data)
	var info: ContentDb = K.content()
	var lines: Array[String] = UnitInfo.effect_numbers(mite("mite", 3).basic_attack.effects, mite("mite", 3), info)
	assert_eq(lines[-1], "shoves 50% of 1 hex toward the nearest edge (with 3 of its side on the target)")
