extends GutTest
## The run <-> sim bridge (RunFight) and save/load (docs/plans/run-state.md).

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEST_SAVE: String = "user://test_run_save.json"


func _content() -> ContentDb:
	return K.content()


## Brannoc (rank B, Hearthwall) fielded with an infused cleaver and his
## buckler; Wren in backup; a relic and some essences.
func _run() -> RunState:
	var content: ContentDb = _content()
	var state: RunState = RunState.make(11)
	RunActions.add_hero(state, content, "brannoc", 1, "brannoc_hearthwall")
	RunActions.add_hero(state, content, "wren")
	RunActions.set_benched(state, "wren", true)
	for item_id: String in ["rusted_cleaver", "oak_buckler"]:
		RunActions.add_item(state, content, item_id)
		RunActions.move_item(state, content, state.stash[-1].uid, "brannoc", 9)
	RunActions.add_essence(state, content, "ember")
	RunActions.infuse(state, content, state.hero("brannoc").items[0].uid, 0)
	state.hero("brannoc").items[0].xp = 40
	RunActions.add_essence(state, content, "frost")
	RunActions.add_relic(state, content, "warding_knot")
	RunActions.add_item(state, content, "hearth_knife", 1)
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
	assert_eq(setup.heroes.size(), 1)
	var brannoc: UnitSetup = setup.heroes[0]
	assert_eq([brannoc.id, brannoc.rank, brannoc.specialization.id], ["brannoc", 1, "brannoc_hearthwall"])
	assert_eq([brannoc.items[0].def.id, brannoc.items[0].essence_ids, brannoc.items[0].infusion_xp], ["rusted_cleaver", ["ember"] as Array[String], 40])
	assert_eq(setup.bench[0].id, "wren")
	assert_eq(setup.relics, ["warding_knot"] as Array[String])
	assert_eq(setup.enemy_relics, ["gloam_totem"] as Array[String])


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
	# The buckler starts at slot 2, after the Medium cleaver.
	RunActions.add_essence(state, _content(), "stone")
	var buckler: RunItem = state.hero("brannoc").items[1]
	RunActions.infuse(state, _content(), buckler.uid, state.pouch.size() - 1)
	var result: FightResult = CombatSim.run(RunFight.setup_for(state, _content(), "sentinel_vigil"), _content())
	assert_eq(result.errors, [] as Array[String])
	RunFight.apply_result(state, _content(), result)
	assert_gt(state.hero("brannoc").items[0].xp, 40, "fires and the battle added XP")
	assert_gt(buckler.xp, 0, "matched by slot, counting item sizes")
	assert_true(state.discovered.has("wardens_oath"), "Brannoc with his buckler")
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
	var benched_first: Dictionary = data.duplicate(true)
	benched_first["heroes"][0]["benched"] = true
	_assert_refused(benched_first, "the first roster slot is always a field slot")
	var overfull: Dictionary = data.duplicate(true)
	for i: int in 4:
		overfull["stash"].append({"uid": 90 + i, "item": "rusted_cleaver", "tier": 0, "essences": [], "xp": 0})
	overfull["next_uid"] = 100
	_assert_refused(overfull, "the stash holds 9 slots of items; it has 6")
	var wrong_spec: Dictionary = data.duplicate(true)
	wrong_spec["heroes"][0]["specialization"] = "wren_duelist"
	_assert_refused(wrong_spec, "specialization \"wren_duelist\" belongs to wren")
	_assert_refused("not a save", "expected an object")


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
