extends GutTest
## The run <-> sim bridge (RunFight) and save/load (docs/plans/run-state.md).

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEST_SAVE: String = "user://test_run_save.json"


func _content() -> ContentDb:
	return K.content()


## Brannoc (rank B, Hearthwall) in front with an infused cleaver and his
## buckler; Wren behind; a relic and some essences.
func _run() -> RunState:
	var content: ContentDb = _content()
	var state: RunState = RunState.make(11)
	RunActions.add_hero(state, content, "brannoc", 1, "brannoc_hearthwall")
	RunActions.add_hero(state, content, "wren")
	for item_id: String in ["rusted_cleaver", "mudbrick_wall"]:
		RunActions.add_item(state, content, item_id)
		RunActions.move_item(state, content, state.stash[-1].uid, "brannoc", 9)
	RunActions.add_essence(state, content, "ember")
	RunActions.infuse(state, content, state.hero("brannoc").items[0].uid, 0)
	state.hero("brannoc").items[0].xp = 40
	RunActions.add_essence(state, content, "frost")
	RunActions.add_relic(state, content, "warding_knot")
	RunActions.add_item(state, content, "longspear", 1)
	state.gold = 12
	assert_eq(state.check(content), [] as Array[String])
	return state


func _round_trip(state: RunState) -> Array:
	return RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())), _content())


# --- to and from the sim --------------------------------------------------------

func test_setup_for_builds_the_guilds_fight() -> void:
	var state: RunState = _run()
	var setup: FightSetup = RunFight.setup_for(state, _content(), "witch_coven")
	assert_eq(setup.validate(_content()), [] as Array[String])
	assert_eq(setup.heroes.size(), 2)
	var brannoc: UnitSetup = setup.heroes[0]
	assert_eq([brannoc.id, brannoc.rank, brannoc.specialization.id], ["brannoc", 1, "brannoc_hearthwall"])
	assert_eq([brannoc.items[0].def.id, brannoc.items[0].essence_ids, brannoc.items[0].infusion_xp], ["rusted_cleaver", ["ember"] as Array[String], 40])
	assert_eq([setup.heroes[1].id, setup.heroes[1].row], ["wren", UnitSetup.Row.BACK])
	assert_eq(setup.relics, ["warding_knot"] as Array[String])
	assert_eq(setup.enemy_relics, ["gloam_totem"] as Array[String])


func test_deeds_go_into_the_fight_and_come_back() -> void:
	var state: RunState = _run()
	var brannoc: RunHero = state.hero("brannoc")
	var calling: DeedTrackDef = _content().heroes["brannoc"].calling
	brannoc.calling_progress = calling.deed.goals[1]
	brannoc.calling_choice = 1
	brannoc.spec_progress = 7
	var setup: FightSetup = RunFight.setup_for(state, _content(), "witch_coven")
	var deeds: Array[DeedSetup] = setup.heroes[0].deeds
	assert_eq([deeds.size(), deeds[0].track_id, deeds[0].progress, deeds[0].choice, deeds[1].track_id, deeds[1].progress],
		[2, DeedSetup.CALLING, calling.deed.goals[1], 1, DeedSetup.SPECIALIZATION, 7])
	assert_eq(setup.heroes[1].deeds.size(), 1, "Wren has no specialization yet: only her calling")
	var result: FightResult = CombatSim.run(setup, _content())
	RunFight.apply_result(state, _content(), result)
	assert_gt(brannoc.calling_progress, calling.deed.goals[1], "progress written back")
	assert_eq(brannoc.calling_choice, 1)
	var wren: FightResult.DeedResult = result.deeds.filter(func(d: FightResult.DeedResult) -> bool: return d.unit_id == "wren")[0]
	assert_eq(state.hero("wren").calling_progress, wren.progress_after)
	var round_trip: RunState = _round_trip(state)[0]
	assert_eq([round_trip.hero("brannoc").calling_progress, round_trip.hero("brannoc").calling_choice, round_trip.hero("brannoc").spec_progress],
		[brannoc.calling_progress, 1, brannoc.spec_progress])


func test_fight_seeds_come_from_the_run() -> void:
	var first: FightSetup = RunFight.setup_for(_run(), _content(), "hound_pack")
	var same: FightSetup = RunFight.setup_for(_run(), _content(), "hound_pack")
	assert_eq(first.seed_value, same.seed_value, "same run seed, same fight seed")
	var state: RunState = _run()
	var one: int = RunFight.setup_for(state, _content(), "hound_pack").seed_value
	var two: int = RunFight.setup_for(state, _content(), "hound_pack").seed_value
	assert_ne(one, two, "each fight draws a new seed")


func test_apply_result_keeps_xp_discoveries_and_the_record() -> void:
	var state: RunState = _run()
	# The buckler is second in the loadout, after the cleaver.
	RunActions.add_essence(state, _content(), "stone")
	var buckler: RunItem = state.hero("brannoc").items[1]
	RunActions.infuse(state, _content(), buckler.uid, state.pouch.size() - 1)
	var result: FightResult = CombatSim.run(RunFight.setup_for(state, _content(), "sentinel_vigil"), _content())
	assert_eq(result.errors, [] as Array[String])
	RunFight.apply_result(state, _content(), result)
	assert_gt(state.hero("brannoc").items[0].xp, 40, "fires and the battle added XP")
	assert_gt(buckler.xp, 0, "matched by loadout index")
	assert_true(state.discovered.has("bulwark_of_stone"), "Raise Wall infused with Stone")
	assert_eq(state.wins + state.losses, 1)
	assert_eq(state.wins, 1 if result.guild_won() else 0)


# --- save and load --------------------------------------------------------------

func test_round_trip_keeps_everything() -> void:
	var state: RunState = _run()
	RunFight.setup_for(state, _content(), "hound_pack")
	var loaded: Array = _round_trip(state)
	assert_eq(loaded[1], [] as Array[String])
	assert_eq(JSON.stringify((loaded[0] as RunState).to_dict()), JSON.stringify(state.to_dict()))


func test_save_load_continue_matches_continue() -> void:
	var state: RunState = _run()
	var copy: RunState = _round_trip(state)[0]
	var ran: FightResult = CombatSim.run(RunFight.setup_for(state, _content(), "witch_coven"), _content())
	var ran_after_load: FightResult = CombatSim.run(RunFight.setup_for(copy, _content(), "witch_coven"), _content())
	assert_eq(ran_after_load.combat_log.to_text(), ran.combat_log.to_text())


func test_broken_saves_are_refused() -> void:
	var data: Dictionary = _run().to_dict()
	var cases: Array = [
		["version", 99, "version 99 isn't supported"],
		["pouch", ["glitter"], "unknown essence \"glitter\""],
		["relics", ["warding_knot", "warding_knot"], "relic \"warding_knot\" is held twice"],
		["gold", -5, "gold and keys can't be negative"],
	]
	for case: Array in cases:
		var broken: Dictionary = data.duplicate(true)
		broken[case[0]] = case[1]
		var errors: Array[String] = RunState.from_dict(broken, _content())[1]
		assert_true(errors.any(func(e: String) -> bool: return e.contains(case[2])), "%s: %s" % [case[2], errors])
	_assert_refused(_with({"version": 3}), "version 3 isn't supported (expected 4)")
	var early_choice: Dictionary = data.duplicate(true)
	early_choice["heroes"][0]["deeds"]["calling_choice"] = 1
	_assert_refused(early_choice, "brannoc: a calling unlock chosen before its level")
	var orphan: Dictionary = data.duplicate(true)
	orphan["heroes"][1]["deeds"]["specialization"] = 40
	_assert_refused(orphan, "wren: specialization deed progress without a specialization")
	var overfull: Dictionary = data.duplicate(true)
	for i: int in 6:
		overfull["stash"].append({"uid": 90 + i, "item": "rusted_cleaver", "tier": 0, "essences": [], "xp": 0})
	overfull["next_uid"] = 100
	_assert_refused(overfull, "the stash holds 7 items; it has room for 6")
	var crowded: Dictionary = data.duplicate(true)
	for hero_id: String in ["vell", "odo"]:
		crowded["heroes"].append(RunHero.make(hero_id).to_dict())
	_assert_refused(crowded, "4 heroes; the team is 3")
	var packed: Dictionary = data.duplicate(true)
	for i: int in 3:
		packed["heroes"][0]["items"].append({"uid": 80 + i, "item": "longspear", "tier": 0, "essences": [], "xp": 0})
	packed["next_uid"] = 100
	_assert_refused(packed, "brannoc has room for 3 abilities")
	var wrong_spec: Dictionary = data.duplicate(true)
	wrong_spec["heroes"][0]["specialization"] = "wren_duelist"
	_assert_refused(wrong_spec, "specialization \"wren_duelist\" belongs to wren")
	_assert_refused("not a save", "expected an object")


## The test save with some keys changed.
func _with(changes: Dictionary) -> Dictionary:
	var data: Dictionary = _run().to_dict()
	data.merge(changes, true)
	return data


func _assert_refused(data: Variant, expected: String) -> void:
	var errors: Array[String] = RunState.from_dict(data, _content())[1]
	assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "%s: %s" % [expected, errors])


func test_save_file_round_trip() -> void:
	var state: RunState = _run()
	assert_eq(RunSave.save(state, TEST_SAVE), "")
	var loaded: Array = RunSave.load_run(_content(), TEST_SAVE)
	assert_eq(loaded[1], [] as Array[String])
	assert_eq(JSON.stringify((loaded[0] as RunState).to_dict()), JSON.stringify(state.to_dict()))
	DirAccess.remove_absolute(TEST_SAVE)
	assert_string_contains((RunSave.load_run(_content(), TEST_SAVE)[1] as Array[String])[0], "no saved run")
