extends GutTest
## Deeds (docs/plans/deeds.md): what they count, levels reached mid-fight,
## the level-2 choice that waits, and what the fight reports.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK
const BIG_HP: int = 10000000


func _assert_error(errors: Array[String], expected: String) -> void:
	assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "expected an error containing '%s', got: %s" % [expected, errors])


func _deed(data: Dictionary) -> Array:
	var errors: Array[String] = []
	var def: DeedDef = DeedDef.read(DataReader.new(data, "deed", errors))
	return [def, errors]


func _track(ranks: Dictionary, deed: Dictionary = {}) -> DeedTrackDef:
	var errors: Array[String] = []
	var track: DeedTrackDef = DeedTrackDef.read(DataReader.new(K.track_data(ranks, deed), "track", errors), "Test Calling", "test_calling")
	assert_eq(errors, [] as Array[String])
	return track


## A hero with a calling `track` at `progress` (level-2 choice `choice`).
func _hero(unit_id: String, track: DeedTrackDef, progress: int = 0, choice: int = -1, items: Array = [], row: UnitSetup.Row = FRONT, basic: ItemDef = null) -> UnitSetup:
	var setup: UnitSetup = K.unit(unit_id, BIG_HP, row, items, basic)
	setup.deeds = [DeedSetup.make(DeedSetup.CALLING, track, progress, choice)]
	return setup


func _deed_result(result: FightResult, unit_id: String = "hero") -> FightResult.DeedResult:
	for deed: FightResult.DeedResult in result.deeds:
		if deed.unit_id == unit_id:
			return deed
	return null


func _levels(sim_log: CombatLog) -> Array[String]:
	var lines: Array[String] = []
	for entry: LogEntry in sim_log.of_kind(LogEntry.Kind.DEED_LEVEL):
		lines.append(entry.to_text())
	return lines


# --- data --------------------------------------------------------------------------

func test_deeds_read_and_reject() -> void:
	var good: Array = _deed({"text": "Deal Burn damage", "counts": "damage", "filter": {"statuses": ["burn"]}, "goals": [10, 30, 90]})
	assert_eq(good[1], [] as Array[String])
	var def: DeedDef = good[0]
	assert_eq([def.counts, def.statuses, def.goals], [DeedDef.Counts.DAMAGE, ["burn"] as Array[String], [10, 30, 90] as Array[int]])
	assert_eq([def.level_for(0), def.level_for(9), def.level_for(10), def.level_for(89), def.level_for(90), def.level_for(9999)], [0, 0, 1, 2, 3, 3])
	_assert_error(_deed({"text": "X", "counts": "damage", "goals": [10, 20]})[1], "a deed needs 3 goals, one per level")
	_assert_error(_deed({"text": "X", "counts": "damage", "goals": [10, 10, 20]})[1], "goals must be at least 1 and rise each level")
	_assert_error(_deed({"text": "X", "counts": "hugs", "goals": [1, 2, 3]})[1], "counts: unknown value \"hugs\"")
	_assert_error(_deed({"text": "X", "counts": "shield", "filter": {"statuses": ["burn"]}, "goals": [1, 2, 3]})[1], "\"statuses\" doesn't filter shield")
	_assert_error(_deed({"text": "X", "counts": "damage_taken", "filter": {"own_row": "middle"}, "goals": [1, 2, 3]})[1], "own_row: unknown value \"middle\"")


func test_tracks_need_three_levels_and_a_choice_at_level_two() -> void:
	var track: DeedTrackDef = _track({"b": [K._stand_in("one")]})
	assert_eq([track.levels.size(), track.levels[1].is_choice(), track.levels[1].options.size()], [3, true, 2])
	var data: Dictionary = K.track_data({})
	data["levels"] = (data["levels"] as Array).slice(0, 2)
	var errors: Array[String] = []
	DeedTrackDef.read(DataReader.new(data, "track", errors), "X", "x")
	_assert_error(errors, "a deed track needs 3 levels")
	data = K.track_data({})
	data["levels"][1]["options"] = [data["levels"][1]["options"][0]]
	errors.clear()
	DeedTrackDef.read(DataReader.new(data, "track", errors), "X", "x")
	_assert_error(errors, "level 2 offers a choice of exactly 2 options")


func test_real_heroes_have_callings_and_specializations_have_deeds() -> void:
	var content: ContentDb = K.content()
	for hero_id: String in content.hero_ids:
		var hero: HeroDef = content.heroes[hero_id]
		assert_not_null(hero.calling, "%s has a calling" % hero_id)
		assert_false(hero.calling_name.is_empty())
		assert_eq(hero.calling.levels.size(), DeedDef.LEVELS)
		assert_true(hero.calling.levels[DeedTrackDef.CHOICE_LEVEL].is_choice(), "%s: level 2 is a choice" % hero_id)
	for spec_id: String in content.specialization_ids:
		var track: DeedTrackDef = content.specializations[spec_id].track
		assert_not_null(track.deed, "%s has a deed" % spec_id)
		assert_eq(track.levels[DeedTrackDef.CHOICE_LEVEL].options.size(), 2, "%s: two options at level 2" % spec_id)


# --- counting ----------------------------------------------------------------------

## Runs 3 seconds with `hero` against a dummy and returns the hero's deed
## progress from the fight result.
func _progress(deed: Dictionary, items: Array, row: UnitSetup.Row = FRONT, enemy_items: Array = [], basic: ItemDef = null) -> Array:
	var track: DeedTrackDef = _track({}, deed)
	var hero: UnitSetup = _hero("hero", track, 0, -1, items, row, basic)
	var foe: UnitSetup = K.unit("foe", BIG_HP, FRONT, enemy_items, K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	var back: UnitSetup = K.dummy("far", BIG_HP, BACK)
	var sim := CombatSim.new(K.fight([hero], [foe, back]), K.content())
	while sim.tick < 60:
		sim.step()
	return [sim.units[0].deeds[0].progress, sim]


func _sum(sim: CombatSim, kind: LogEntry.Kind, filter: Callable) -> int:
	var total: int = 0
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if filter.call(entry):
			total += entry.amount
	return total


func test_damage_counts_hits_and_damage_over_time() -> void:
	var torch: ItemDef = K.item("torch", {"effects": [{"trigger": "on_fire", "type": "damage", "amount": 10, "target": "enemy_front"},
		{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 3, "target": "enemy_front"},
		{"trigger": "on_fire", "type": "apply_status", "status": "poison", "stacks": 3, "target": "enemy_front"}]})
	var got: Array = _progress({"text": "Deal damage", "counts": "damage", "goals": [1, 2, 3]}, [torch])
	var sim: CombatSim = got[1]
	var mine := func(e: LogEntry) -> bool: return e.source_unit == "hero"
	var expected: int = _sum(sim, LogEntry.Kind.DAMAGE, mine) + _sum(sim, LogEntry.Kind.STATUS_DAMAGE, mine)
	assert_gt(_sum(sim, LogEntry.Kind.STATUS_DAMAGE, mine), 0, "Burn ticked")
	assert_eq(got[0], expected)
	var burn_only: Array = _progress({"text": "Burn", "counts": "damage", "filter": {"statuses": ["burn"]}, "goals": [1, 2, 3]}, [torch])
	assert_eq(burn_only[0], _sum(burn_only[1], LogEntry.Kind.STATUS_DAMAGE, func(e: LogEntry) -> bool: return e.source_unit == "hero" and e.status == "burn"), "only the Burn")
	assert_gt(_sum(burn_only[1], LogEntry.Kind.STATUS_DAMAGE, func(e: LogEntry) -> bool: return e.status == "poison"), 0, "the Poison ticked but didn't count")


func test_damage_can_count_only_the_back_row() -> void:
	var sling: ItemDef = K.item("sling", {"effects": [K.damage(5, "enemy_back")[0], K.damage(7)[0]]})
	var got: Array = _progress({"text": "Back", "counts": "damage", "filter": {"target_row": "back"}, "goals": [1, 2, 3]}, [sling])
	assert_eq(got[0], _sum(got[1], LogEntry.Kind.DAMAGE, func(e: LogEntry) -> bool: return e.source_unit == "hero" and e.target == "far"))
	assert_gt(got[0], 0)


func test_shield_healing_and_stacks() -> void:
	var ward: ItemDef = K.item("ward", {"effects": [{"trigger": "on_fire", "type": "shield", "amount": 6, "target": "self"}]})
	var shield: Array = _progress({"text": "Shield", "counts": "shield", "goals": [1, 2, 3]}, [ward])
	assert_eq(shield[0], _sum(shield[1], LogEntry.Kind.SHIELD, func(e: LogEntry) -> bool: return e.source_unit == "hero"))
	assert_gt(shield[0], 0)
	var hexer: ItemDef = K.item("hexer", {"effects": [{"trigger": "on_fire", "type": "apply_status", "status": "poison", "stacks": 2, "target": "enemy_front"},
		{"trigger": "on_fire", "type": "apply_status", "status": "slow", "stacks": 1, "target": "enemy_front"}]})
	var poison: Array = _progress({"text": "Poison", "counts": "stacks", "filter": {"statuses": ["poison"]}, "goals": [1, 2, 3]}, [hexer])
	assert_eq(poison[0], 2 * 3, "2 Poison per fire, 3 fires in 3 seconds; the Slow doesn't count")
	var any: Array = _progress({"text": "Any", "counts": "stacks", "goals": [1, 2, 3]}, [hexer])
	assert_eq(any[0], 3 * 3)


func test_healing_counts_hp_restored() -> void:
	var salve: ItemDef = K.item("salve", {"effects": [{"trigger": "on_fire", "type": "heal", "amount": 5, "target": "self"}]})
	var club: ItemDef = K.item("club", {"effects": K.damage(20)})
	var got: Array = _progress({"text": "Heal", "counts": "healing", "goals": [1, 2, 3]}, [salve], FRONT, [club])
	assert_eq(got[0], _sum(got[1], LogEntry.Kind.HEAL, func(e: LogEntry) -> bool: return e.source_unit == "hero"))
	assert_gt(got[0], 0)


func test_damage_taken_only_while_in_the_named_row() -> void:
	var club: ItemDef = K.item("club", {"effects": K.damage(20, "all_enemies")})
	var deed: Dictionary = {"text": "Hold", "counts": "damage_taken", "filter": {"own_row": "front"}, "goals": [1, 2, 3]}
	var front: Array = _progress(deed, [], FRONT, [club])
	assert_eq(front[0], _sum(front[1], LogEntry.Kind.DAMAGE, func(e: LogEntry) -> bool: return e.target == "hero"))
	assert_gt(front[0], 0)
	assert_eq(_progress(deed, [], BACK, [club])[0], 0, "not from the back row")


func test_crits_and_fires_with_a_keyword() -> void:
	var blade: ItemDef = K.item("blade", {"crit_chance_bp": 10000, "keywords": ["blade"]})
	var tome: ItemDef = K.item("tome", {"crit_chance_bp": 10000, "keywords": ["spell"]})
	var crits: Array = _progress({"text": "Crits", "counts": "crits", "filter": {"keyword": "spell"}, "goals": [1, 2, 3]}, [blade, tome])
	assert_eq(crits[0], 3, "the tome's 3 crits; not the blade's")
	var fires: Array = _progress({"text": "Fires", "counts": "fires", "goals": [1, 2, 3]}, [blade, tome])
	assert_eq(fires[0], 3 + 3 + 3, "the basic attack's fires count too")
	var spell_fires: Array = _progress({"text": "Fires", "counts": "fires", "filter": {"keyword": "spell"}, "goals": [1, 2, 3]}, [blade, tome])
	assert_eq(spell_fires[0], 3)


func test_relics_and_enemies_never_count() -> void:
	var track: DeedTrackDef = _track({}, {"text": "Shield", "counts": "shield", "goals": [100, 200, 300]})
	var enemy: UnitSetup = K.unit("foe", BIG_HP, FRONT, [K.item("ward", {"effects": [{"trigger": "on_fire", "type": "shield", "amount": 6, "target": "self"}]})])
	enemy.deeds = [DeedSetup.make(DeedSetup.CALLING, track)]
	var setup: FightSetup = K.relic_fight([_hero("hero", track, 0, -1, [], FRONT, K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))], [enemy],
		[K.relic("wall_relic", {"effects": [{"trigger": "on_fight_start", "type": "shield", "amount": 40, "target": "all_allies"}]})])
	var sim := CombatSim.new(setup, K.relic_content())
	while sim.tick < 60:
		sim.step()
	assert_eq(sim.units[0].deeds[0].progress, 0, "the relic's shield isn't the hero's")
	assert_eq(sim.units[1].deeds[0].progress, 0, "enemies have no deeds")


# --- levels -------------------------------------------------------------------------

func test_a_level_turns_on_mid_fight_and_says_so() -> void:
	var track: DeedTrackDef = _track({"b": [{"key": "rage", "kind": "aura", "target": "holder", "stat": "damage_bp", "value": 20000}]},
		{"text": "Deal damage", "counts": "damage", "goals": [25, 1000, 2000]})
	var result: FightResult = K.run([_hero("hero", track, 0, -1, [K.item("sword", {"effects": K.damage(10)})])], [K.dummy("foe", BIG_HP)])
	assert_eq(_levels(result.combat_log)[0], "[2.00s] hero reaches Test Calling 1: Level 1.", "the basic attack (5) and sword (10) each second: 30 by 2s")
	var hits: Array[int] = []
	for entry: LogEntry in K.entries(result, LogEntry.Kind.DAMAGE, "sword").slice(0, 3):
		hits.append(entry.amount)
	assert_eq(hits.slice(0, 3), [10, 10, 20] as Array[int], "x2 once level 1 lands (the 2s hit came first)")
	var deed: FightResult.DeedResult = _deed_result(result)
	assert_eq([deed.track_id, deed.progress_before, deed.level_before, deed.level_after], [DeedSetup.CALLING, 0, 0, 3], "a long fight reaches all three")
	assert_gt(deed.progress_after, 2000)


func test_levels_already_reached_apply_from_the_start() -> void:
	var track: DeedTrackDef = _track({"b": [{"key": "rage", "kind": "aura", "target": "holder", "stat": "damage_bp", "value": 20000}]})
	var result: FightResult = K.run([_hero("hero", track, 10, -1, [K.item("sword", {"effects": K.damage(10)})])], [K.dummy("foe", BIG_HP)])
	assert_eq(K.entries(result, LogEntry.Kind.DAMAGE, "sword")[0].amount, 20)
	assert_eq(_levels(result.combat_log).size(), 2, "levels 2 and 3 land during the fight (goals 20, 30)")


func test_the_choice_level_waits_until_an_option_is_chosen() -> void:
	var track: DeedTrackDef = _track({"b": [K._stand_in("one")], "a": [{"key": "first", "kind": "aura", "target": "holder", "stat": "damage_bp", "value": 20000}]},
		{"text": "Deal damage", "counts": "damage", "goals": [1, 20, 100000]})
	var sword: ItemDef = K.item("sword", {"effects": K.damage(10)})
	var waiting: FightResult = K.run([_hero("hero", track, 1, -1, [sword])], [K.dummy("foe", BIG_HP)])
	assert_eq(_levels(waiting.combat_log)[0], "[2.00s] hero reaches Test Calling 2: choose its unlock between fights")
	assert_eq(K.entries(waiting, LogEntry.Kind.DAMAGE, "sword")[3].amount, 10, "nothing turned on")
	var chosen: FightResult = K.run([_hero("hero", track, 1, 0, [sword])], [K.dummy("foe", BIG_HP)])
	assert_eq(_levels(chosen.combat_log)[0], "[2.00s] hero reaches Test Calling 2: The first option.")
	assert_eq(K.entries(chosen, LogEntry.Kind.DAMAGE, "sword")[3].amount, 20, "the chosen option turned on")
	var other: FightResult = K.run([_hero("hero", track, 20, 1, [sword])], [K.dummy("foe", BIG_HP)])
	assert_eq(K.entries(other, LogEntry.Kind.DAMAGE, "sword")[0].amount, 10, "the second option is only the stand-in")


func test_a_level_can_add_and_replace_abilities_mid_fight() -> void:
	var jab: Dictionary = {"key": "jab", "kind": "ability", "name": "Jab", "cooldown_ms": 1000, "effects": K.damage(1)}
	var shove: Dictionary = {"key": "jab", "kind": "ability", "name": "Shove", "cooldown_ms": 1000, "effects": K.damage(3)}
	var track: DeedTrackDef = _track({"b": [jab], "s": [shove]}, {"text": "Deal damage", "counts": "damage", "goals": [1, 2, 40]})
	var result: FightResult = K.run([_hero("hero", track, 2, 0, [])], [K.dummy("foe", BIG_HP)])
	var names: Array[String] = []
	for entry: LogEntry in result.combat_log.of_kind(LogEntry.Kind.FIRE):
		if entry.source_unit == "hero" and not names.has(entry.source_item_name):
			names.append(entry.source_item_name)
	assert_true(names.has("Jab (Test Calling 1)") and names.has("Shove (Test Calling 3)"), str(names))
	var after: Array[LogEntry] = result.combat_log.of_kind(LogEntry.Kind.FIRE).filter(func(e: LogEntry) -> bool: return e.tick > 200 and e.source_unit == "hero")
	assert_false(after.any(func(e: LogEntry) -> bool: return e.source_item_name.begins_with("Jab")), "Shove replaced Jab")


func test_losses_count_too() -> void:
	var track: DeedTrackDef = _track({}, {"text": "Deal damage", "counts": "damage", "goals": [1000, 2000, 3000]})
	var hero: UnitSetup = _hero("hero", track, 0, -1, [])
	hero.stats = UnitStats.make(30, 10)
	var result: FightResult = K.run([hero], [K.unit("brute", BIG_HP, FRONT, [K.item("maul", {"effects": K.damage(50)})])])
	assert_false(result.guild_won())
	assert_gt(_deed_result(result).progress_after, 0)
