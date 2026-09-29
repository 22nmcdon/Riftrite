extends GutTest
## Counting deeds (Deeds, DeedDef; docs/plans/rebuild-phase4-paths.md,
## section 3), in tiny fights: each kind counts what it says, each filter
## keeps out what it should, and counting never changes the fight. The board
## runs in the plan's terms: heroes in rows 0-2, enemies in rows 4-6, a row
## a hex apart.

const K = preload("res://tests/sim/sim_test_kit.gd")


## A deed read from data, so it's checked like the real ones.
static func deed(data: Dictionary) -> DeedDef:
	var full: Dictionary = {"text": "A deed"}
	full.merge(data, true)
	var errors: Array[String] = []
	var def: DeedDef = DeedDef.read(DataReader.new(full, "deed", errors))
	assert(errors.is_empty(), str(errors))
	return def


## A path of `hero`'s with `deed` (its kits don't matter to counting).
static func path_with(hero: String, path_id: String, the_deed: DeedDef) -> PathDef:
	var path := PathDef.new()
	path.id = path_id
	path.hero = hero
	path.name = path_id.capitalize()
	path.deed = the_deed
	return path


## `setup` counting these deeds, one path each ("p0", "p1", ...).
static func counting(setup: UnitSetup, deeds: Array[DeedDef]) -> UnitSetup:
	for i: int in deeds.size():
		setup.deed_paths.append(path_with(setup.def.id, "p%d" % i, deeds[i]))
	return setup


## What the hero's own entries of `kind` added up to (from `ability_id` only,
## if given).
static func logged(fight: CombatSim, kind: LogEntry.Kind, unit_id: String, ability_id: String = "") -> int:
	var total: int = 0
	for entry: LogEntry in K.entries(fight, kind, unit_id):
		if ability_id.is_empty() or entry.source_ability == ability_id:
			total += entry.amount
	return total


static func amount(fight: CombatSim, hero: String, path_id: String) -> int:
	for found: FightResult.Deed in fight.deed_amounts():
		if found.hero == hero and found.path == path_id:
			return found.amount
	return -1


## A foe that stands still and hits softly, with a Shield up at the start.
static func dummy(overrides: Dictionary = {}) -> UnitDef:
	var data: Dictionary = {"stats": {"hp": 5000, "atk": 1, "speed": 0},
		"basic_attack": {"effects": [{"type": "damage", "amount": 1, "target": "target"}]},
		"signature": {"id": "brace", "name": "Brace", "trigger": {"kind": "fight_start"}, "targeting": "self",
			"effects": [{"type": "shield", "amount": 25, "target": "self"}]}}
	data.merge(overrides, true)
	return K.kit("dummy", data)


func test_damage_counts_each_hit_shield_included() -> void:
	var hero: UnitSetup = counting(K.at(K.kit("brawler"), 3, 2), [deed({"counts": "damage"})])
	var fight: CombatSim = K.sim(K.fight([hero], [K.foe(dummy(), 3, 4)]))
	K.step(fight, 200)
	var absorbed: int = 0
	for entry: LogEntry in K.entries(fight, LogEntry.Kind.DAMAGE, "brawler"):
		absorbed += entry.absorbed
	assert_gt(absorbed, 0, "some of it went into the Shield")
	assert_gt(logged(fight, LogEntry.Kind.DAMAGE, "brawler"), 50)
	assert_eq(amount(fight, "brawler", "p0"), logged(fight, LogEntry.Kind.DAMAGE, "brawler"))


func test_each_kind_counts_its_own() -> void:
	# Each swing also heals and shields the brawler (a passive on its attack),
	# and the dummy hits back hard enough that the heals restore something.
	var brawler: UnitDef = K.kit("brawler", {"stats": {"hp": 400},
		"passives": [{"id": "second_wind", "name": "Second Wind", "kind": "ability", "effects": [
			{"trigger": "on_basic_attack", "type": "heal", "amount": 6, "target": "self"},
			{"trigger": "on_basic_attack", "type": "shield", "amount": 4, "target": "self"}]}]})
	var deeds: Array[DeedDef] = [deed({"counts": "damage"}), deed({"counts": "healing"}), deed({"counts": "shield"})]
	var hero: UnitSetup = counting(K.at(brawler, 3, 2), deeds)
	var fight: CombatSim = K.sim(K.fight([hero], [K.foe(dummy({"stats": {"hp": 5000, "atk": 8, "speed": 0},
		"basic_attack": {"effects": [{"type": "damage", "amount": 12, "target": "target"}]}}), 3, 4)]))
	K.step(fight, 300)
	var healed: int = logged(fight, LogEntry.Kind.HEAL, "brawler")
	var shielded: int = logged(fight, LogEntry.Kind.SHIELD, "brawler")
	assert_gt(healed, 0)
	assert_gt(shielded, 0)
	assert_eq([amount(fight, "brawler", "p0"), amount(fight, "brawler", "p1"), amount(fight, "brawler", "p2")],
		[logged(fight, LogEntry.Kind.DAMAGE, "brawler"), healed, shielded])
	assert_eq(logged(fight, LogEntry.Kind.SHIELD, "dummy"), 25, "the dummy's own Shield isn't the brawler's")


func test_from_ability_counts_only_those() -> void:
	var brawler: UnitDef = K.kit("brawler", {"passives": [{"id": "jab", "name": "Jab", "kind": "ability", "effects": [
		{"trigger": "on_basic_attack", "type": "damage", "amount": 3, "target": "target"}]}]})
	var hero: UnitSetup = counting(K.at(brawler, 3, 2), [deed({"counts": "damage", "from_ability": ["jab"]}),
		deed({"counts": "damage", "from_ability": ["brawler_attack", "jab"]})])
	var fight: CombatSim = K.sim(K.fight([hero], [K.foe(dummy(), 3, 4)]))
	K.step(fight, 200)
	var jabs: int = logged(fight, LogEntry.Kind.DAMAGE, "brawler", "jab")
	assert_gt(jabs, 0)
	assert_gt(logged(fight, LogEntry.Kind.DAMAGE, "brawler", "brawler_attack"), 0)
	assert_eq(amount(fight, "brawler", "p0"), jabs)
	assert_eq(amount(fight, "brawler", "p1"), logged(fight, LogEntry.Kind.DAMAGE, "brawler"))


func test_beyond_hexes_needs_the_distance() -> void:
	# Beyond 4 hexes: a still target 5 hexes away counts; one exactly 4 away doesn't.
	for row: int in [5, 4]:
		var archer: UnitDef = K.kit("archer", {"stats": {"range": 6}})
		var hero: UnitSetup = counting(K.at(archer, 3, 0), [deed({"counts": "damage", "beyond_hexes": 4}), deed({"counts": "damage"})])
		var fight: CombatSim = K.sim(K.fight([hero], [K.foe(dummy(), 3, row)]))
		K.step(fight, 100)
		var dealt: int = logged(fight, LogEntry.Kind.DAMAGE, "archer")
		assert_gt(dealt, 0)
		assert_eq(amount(fight, "archer", "p1"), dealt)
		assert_eq(amount(fight, "archer", "p0"), dealt if row == 5 else 0, "a target %d hexes away" % row)


func test_a_shot_counts_from_where_it_was_fired() -> void:
	# The target walks in while the arrows fly: a shot fired from beyond 4
	# hexes counts even if it lands nearer, and one fired from nearer doesn't.
	var archer: UnitDef = K.kit("archer", {"stats": {"range": 7, "speed": 0}, "basic_attack": {"cooldown_ms": 250}})
	var hero: UnitSetup = counting(K.at(archer, 3, 0), [deed({"counts": "damage", "beyond_hexes": 4})])
	var walker: UnitDef = dummy({"stats": {"hp": 5000, "atk": 1, "speed": 1}})
	var fight: CombatSim = K.sim(K.fight([hero], [K.foe(walker, 3, 6)]))
	var expected: int = 0
	var landed_nearer: int = 0
	var far: Dictionary[int, bool] = {}
	for i: int in 120:
		var before: int = fight.combat_log.entries.size()
		fight.step()
		for n: int in range(before, fight.combat_log.entries.size()):
			var entry: LogEntry = fight.combat_log.entries[n]
			if entry.source_unit != "archer":
				continue
			if entry.kind == LogEntry.Kind.SHOT:
				far[entry.end_tick] = ArenaPlane.length_sq(entry.to_pos - entry.from_pos) > 4000 * 4000
			elif entry.kind == LogEntry.Kind.DAMAGE and far.get(entry.tick, false):
				expected += entry.amount
				var target: UnitState = fight.unit_by_id(entry.target)
				if ArenaPlane.length_sq(target.pos - fight.unit_by_id("archer").pos) <= 4000 * 4000:
					landed_nearer += 1
	assert_gt(landed_nearer, 0, "some shot left from beyond 4 hexes and landed nearer (or the test proves nothing)")
	assert_gt(expected, 0)
	assert_lt(expected, logged(fight, LogEntry.Kind.DAMAGE, "archer"), "and some left from nearer")
	assert_eq(amount(fight, "archer", "p0"), expected)


func test_while_below_counts_only_low_hits() -> void:
	var brawler: UnitDef = K.kit("brawler", {"stats": {"hp": 300}})
	var hero: UnitSetup = counting(K.at(brawler, 3, 2), [deed({"counts": "damage", "while_below_pct": 50})])
	var bruiser: UnitDef = dummy({"stats": {"hp": 5000, "atk": 10, "speed": 0},
		"basic_attack": {"effects": [{"type": "damage", "amount": 9, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([hero], [K.foe(bruiser, 3, 4)]))
	var unit: UnitState = fight.unit_by_id("brawler")
	var expected: int = 0
	var high: int = 0
	while not fight.finished:
		var before: int = fight.combat_log.entries.size()
		fight.step()
		var low: bool = unit.hp * 2 < unit.max_hp
		for n: int in range(before, fight.combat_log.entries.size()):
			var entry: LogEntry = fight.combat_log.entries[n]
			if entry.kind == LogEntry.Kind.DAMAGE and entry.source_unit == "brawler":
				if low:
					expected += entry.amount
				else:
					high += entry.amount
	assert_gt(high, 0)
	assert_gt(expected, 0)
	assert_eq(amount(fight, "brawler", "p0"), expected)


func test_counting_changes_nothing_and_reaches_the_result() -> void:
	var plain: FightSetup = K.fight([K.at(K.kit("brawler"), 3, 2), K.at(K.kit("archer", {"stats": {"range": 4}}), 2, 1)], [K.foe(dummy(), 3, 4)])
	var counted: FightSetup = K.fight([counting(K.at(K.kit("brawler"), 3, 2), [deed({"counts": "damage"}), deed({"counts": "shield"})]),
		counting(K.at(K.kit("archer", {"stats": {"range": 4}}), 2, 1), [deed({"counts": "damage", "beyond_hexes": 3})])], [K.foe(dummy(), 3, 4)])
	var without: FightResult = K.run(plain)
	var with_deeds: FightResult = K.run(counted)
	assert_eq(with_deeds.combat_log.to_text(), without.combat_log.to_text())
	assert_eq(without.deeds.size(), 0)
	var order: Array = with_deeds.deeds.map(func(found: FightResult.Deed) -> String: return "%s %s" % [found.hero, found.path])
	assert_eq(order, ["brawler p0", "brawler p1", "archer p0"], "the fight's order, then each hero's paths")
	assert_gt(with_deeds.deed_amount("brawler", "p0"), 0)
	assert_eq(with_deeds.deed_amount("brawler", "p1"), 0, "no Shield given")
	assert_eq(with_deeds.deed_amount("nobody", "p0"), 0)


func test_extra_hits_count_hits_beyond_the_attacks_own_target() -> void:
	var cleaver: UnitDef = K.kit("cleaver", {"stats": {"hp": 5000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 500, "shot": false, "effects": [{"type": "damage", "amount": 2, "target": "target"},
			{"type": "damage", "amount": 1, "target": "enemies_near_target", "within_hexes": 1}]}})
	var hero: UnitSetup = counting(K.at(cleaver, 3, 2), [deed({"counts": "extra_hits", "from_ability": ["cleaver_attack"]}), deed({"counts": "extra_hits"})])
	var fight: CombatSim = K.sim(K.fight([hero], [K.foe(dummy(), 3, 4), K.foe(dummy(), 3, 5)]))
	K.step(fight, 100)
	var fires: int = K.entries(fight, LogEntry.Kind.FIRE, "cleaver").size()
	assert_gt(fires, 3)
	assert_eq(amount(fight, "cleaver", "p0"), fires, "one extra enemy each swing")
	assert_eq(amount(fight, "cleaver", "p1"), fires)


func test_rooted_ms_counts_how_long_its_roots_last() -> void:
	var binder: UnitDef = K.kit("binder", {"stats": {"hp": 5000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 1000, "shot": false, "effects": [{"type": "apply_status", "status": "root", "duration_ms": 1500, "target": "target"},
			{"type": "apply_status", "status": "slow", "target": "target"}]}})
	var hero: UnitSetup = counting(K.at(binder, 3, 2), [deed({"counts": "rooted_ms"})])
	var fight: CombatSim = K.sim(K.fight([hero], [K.foe(dummy(), 3, 4)]))
	K.step(fight, 70)
	var roots: int = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "binder").filter(func(entry: LogEntry) -> bool: return entry.status == "root").size()
	assert_gt(roots, 1)
	assert_eq(amount(fight, "binder", "p0"), roots * 1500, "Slow doesn't count")


func test_guarded_counts_what_the_guard_took() -> void:
	var guard: Dictionary = {"id": "guard", "name": "Guard", "kind": "guard", "share_pct": 30, "within_hexes": 1, "covers": "all"}
	var guardian: UnitSetup = counting(K.at(K.kit("guardian", {"stats": {"hp": 5000, "speed": 0}, "passives": [guard]}), 3, 1), [deed({"counts": "guarded"})])
	var archer: UnitDef = K.kit("archer", {"stats": {"hp": 5000, "speed": 0, "range": 5}, "targeting": "nearest",
		"basic_attack": {"cooldown_ms": 500, "effects": [{"type": "damage", "amount": 40, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(K.kit("ally", {"stats": {"hp": 5000, "speed": 0}}), 3, 2), guardian], [K.foe(archer, 3, 4)]))
	K.step(fight, 60)
	var guarded: int = 0
	for entry: LogEntry in K.entries(fight, LogEntry.Kind.GUARD, "guardian"):
		guarded += entry.amount
	assert_gt(guarded, 0)
	assert_eq(amount(fight, "guardian", "p0"), guarded)


func test_new_kinds_take_no_ability_filter_where_it_makes_no_sense() -> void:
	for kind: String in ["rooted_ms", "guarded"]:
		var errors: Array[String] = []
		DeedDef.read(DataReader.new({"text": "x", "counts": kind, "from_ability": ["snare"]}, "deed", errors))
		assert_eq(errors.size(), 1, kind)
