extends GutTest
## Run actions (docs/plans/run-state.md): items, essences, heroes, formation,
## and the rule that a refused action changes nothing.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _content() -> ContentDb:
	return K.content()


## A run with brannoc (in front) and 20 gold.
func _run() -> RunState:
	var state: RunState = RunState.make(7)
	assert_true(RunActions.add_hero(state, _content(), "brannoc").ok)
	state.gold = 20
	return state


func _add(state: RunState, item_id: String, tier: int = 0) -> int:
	var result: RunActions.Result = RunActions.add_item(state, _content(), item_id, tier)
	assert_true(result.ok, result.error)
	return state.stash[-1].uid


func _refused(result: RunActions.Result, expected: String) -> void:
	assert_false(result.ok)
	assert_string_contains(result.error, expected)


func _snapshot(state: RunState) -> String:
	return JSON.stringify(state.to_dict())


# --- items --------------------------------------------------------------------

func test_items_move_between_the_stash_and_rows() -> void:
	var state: RunState = _run()
	var cleaver: int = _add(state, "rusted_cleaver")
	var buckler: int = _add(state, "oak_buckler")
	assert_true(RunActions.move_item(state, _content(), cleaver, "brannoc", 0).ok)
	assert_true(RunActions.move_item(state, _content(), buckler, "brannoc", 0).ok)
	var row: Array[String] = []
	for item: RunItem in state.hero("brannoc").items:
		row.append(item.item_id)
	assert_eq(row, ["oak_buckler", "rusted_cleaver"] as Array[String], "inserted at the index")
	assert_true(RunActions.move_item(state, _content(), cleaver, RunState.STASH, 0).ok)
	assert_eq(state.stash.size(), 1)
	assert_eq(state.check(_content()), [] as Array[String])


func test_loadout_slots_and_the_stash_have_room_limits() -> void:
	var state: RunState = _run()
	var knives: Array[int] = []
	for i: int in _content().tuning.stash_slots:
		knives.append(_add(state, "hearth_knife"))
	_refused(RunActions.add_item(state, _content(), "oak_buckler"), "the stash has no room for Oak Buckler")
	assert_true(RunActions.move_item(state, _content(), knives[0], "brannoc", 0).ok)
	assert_true(RunActions.move_item(state, _content(), knives[1], "brannoc", 0).ok)
	var before: String = _snapshot(state)
	_refused(RunActions.move_item(state, _content(), knives[2], "brannoc", 0), "brannoc has room for 2 abilities")
	assert_eq(_snapshot(state), before, "a refused move changes nothing")
	var drum: int = _add(state, "war_drum")
	var bell: int = _add(state, "bell_of_vigil")
	assert_true(RunActions.move_item(state, _content(), drum, "brannoc", 9).ok, "passives have their own slots")
	_refused(RunActions.move_item(state, _content(), bell, "brannoc", 9), "brannoc has room for 1 passive")
	assert_true(RunActions.rank_up(state, _content(), "brannoc").ok)
	assert_true(RunActions.move_item(state, _content(), knives[2], "brannoc", 0).ok, "rank B: 3 abilities")
	assert_eq(state.check(_content()), [] as Array[String])
	while state.stash.size() < _content().tuning.stash_slots:
		_add(state, "hearth_knife")
	_refused(RunActions.move_item(state, _content(), knives[0], RunState.STASH, 0), "the stash has no room for that (6 items)")


func test_one_auto_attack_item_per_hero() -> void:
	var state: RunState = _run()
	var claw: int = _add(state, "rusted_cleaver")
	var maw: int = _add(state, "blackthorn_bow")
	for uid: int in [claw, maw]:
		var def: ItemDef = _content().items[state.find_item(uid).item_id]
		assert_true(def.auto_attack, "%s is an auto-attack item" % def.id)
	assert_true(RunActions.move_item(state, _content(), claw, "brannoc", 0).ok)
	_refused(RunActions.move_item(state, _content(), maw, "brannoc", 0), "brannoc has room for 1 basic attack")


func test_combining_items() -> void:
	var state: RunState = _run()
	var kept: int = _add(state, "hearth_knife")
	var copy: int = _add(state, "hearth_knife")
	var other_tier: int = _add(state, "hearth_knife", 1)
	state.find_item(kept).essence_ids = ["ember"] as Array[String]
	state.find_item(kept).xp = 50
	_refused(RunActions.combine_items(state, _content(), kept, other_tier), "only copies at the same tier combine")
	assert_true(RunActions.combine_items(state, _content(), kept, copy).ok)
	var result: RunItem = state.find_item(kept)
	assert_eq([result.tier, result.essence_ids, result.xp], [1, ["ember"] as Array[String], 50], "no infusion on the new copy: the kept one stays")
	assert_null(state.find_item(copy))
	state.find_item(other_tier).essence_ids = ["frost"] as Array[String]
	assert_true(RunActions.combine_items(state, _content(), kept, other_tier).ok)
	assert_eq([result.tier, result.essence_ids, result.xp], [2, ["frost"] as Array[String], 0], "the new copy's infusion replaces the old one")


func test_combining_limits() -> void:
	var state: RunState = _run()
	var a: int = _add(state, "hearth_knife", 3)
	var b: int = _add(state, "hearth_knife", 3)
	_refused(RunActions.combine_items(state, _content(), a, b), "S items can't combine")
	var knife: int = _add(state, "bone_sling")
	_refused(RunActions.combine_items(state, _content(), a, knife), "only two copies of the same item combine")
	_refused(RunActions.combine_items(state, _content(), a, a), "pick two different items")


func test_discard_and_legendaries_seen() -> void:
	var state: RunState = _run()
	var knife: int = _add(state, "hearth_knife")
	assert_true(RunActions.discard_item(state, _content(), knife).ok)
	assert_eq(state.stash.size(), 0)
	_refused(RunActions.add_item(state, _content(), "moon_blade"), "unknown item")


# --- essences -----------------------------------------------------------------

func test_any_item_fuses_two_essences_and_resets_xp() -> void:
	var state: RunState = _run()
	var knife: int = _add(state, "hearth_knife")
	var drum: int = _add(state, "war_drum")
	for essence_id: String in ["ember", "storm", "frost", "verdant"]:
		assert_true(RunActions.add_essence(state, _content(), essence_id).ok)
	assert_true(RunActions.infuse(state, _content(), knife, 0).ok)
	state.find_item(knife).xp = 90
	var fused: RunActions.Result = RunActions.infuse(state, _content(), knife, 0)
	assert_true(fused.ok, "a Common takes a second essence too")
	assert_string_contains(fused.note, "Plasma")
	assert_eq(state.find_item(knife).essence_ids, ["ember", "storm"] as Array[String])
	assert_eq(state.find_item(knife).xp, 0, "fusing resets XP")
	var before: String = _snapshot(state)
	_refused(RunActions.infuse(state, _content(), knife, 0), "Hearth Knife already holds two essences")
	assert_eq(_snapshot(state), before, "no third essence")
	assert_true(RunActions.infuse(state, _content(), drum, 1).ok, "passives can be infused")
	assert_eq(state.pouch, ["frost"] as Array[String])
	assert_eq(state.check(_content()), [] as Array[String])


func test_the_pouch_has_a_cap() -> void:
	var state: RunState = _run()
	for i: int in _content().tuning.pouch_cap:
		assert_true(RunActions.add_essence(state, _content(), "ember").ok)
	_refused(RunActions.add_essence(state, _content(), "frost"), "the essence pouch is full (8)")
	assert_true(RunActions.discard_essence(state, _content(), 0).ok)
	assert_true(RunActions.add_essence(state, _content(), "frost").ok)


func test_reforging_costs_gold_and_destroys_the_essence() -> void:
	var state: RunState = _run()
	var knife: int = _add(state, "hearth_knife")
	_refused(RunActions.reforge(state, _content(), knife), "has no infusion")
	RunActions.add_essence(state, _content(), "ember")
	RunActions.infuse(state, _content(), knife, 0)
	state.find_item(knife).xp = 120
	state.gold = 2
	_refused(RunActions.reforge(state, _content(), knife), "reforging costs 3 gold")
	state.gold = 5
	assert_true(RunActions.reforge(state, _content(), knife).ok)
	assert_eq([state.find_item(knife).essence_ids, state.find_item(knife).xp, state.gold, state.pouch], [[] as Array[String], 0, 2, [] as Array[String]])


# --- heroes -------------------------------------------------------------------

func test_heroes_join_the_team() -> void:
	var state: RunState = _run()
	assert_eq(state.heroes[0].row, UnitSetup.Row.FRONT, "the first hero stands in front")
	assert_true(RunActions.add_hero(state, _content(), "wren").ok)
	assert_eq(state.hero("wren").row, UnitSetup.Row.BACK)
	_refused(RunActions.add_hero(state, _content(), "brannoc"), "Brannoc of the Hearthwatch is already in the team")
	_refused(RunActions.add_hero(state, _content(), "nobody"), "unknown hero \"nobody\"")
	assert_true(RunActions.add_hero(state, _content(), "vell").ok)
	var before: String = _snapshot(state)
	_refused(RunActions.add_hero(state, _content(), "odo"), "the team is full (3)")
	assert_eq(_snapshot(state), before)
	assert_eq(state.check(_content()), [] as Array[String])


func test_rank_ups() -> void:
	var state: RunState = _run()
	var knife: int = _add(state, "hearth_knife")
	RunActions.move_item(state, _content(), knife, "brannoc", 0)
	assert_true(RunActions.rank_up(state, _content(), "brannoc").ok)
	var brannoc: RunHero = state.hero("brannoc")
	assert_eq([brannoc.rank, brannoc.items.size(), brannoc.needs_specialization], [1, 1, true], "B: keeps items, picks a specialization")
	RunActions.choose_specialization(state, _content(), "brannoc", "brannoc_hearthwall")
	assert_true(RunActions.rank_up(state, _content(), "brannoc").ok)
	assert_true(RunActions.rank_up(state, _content(), "brannoc").ok)
	assert_eq([brannoc.rank, brannoc.specialization_id, brannoc.needs_specialization], [3, "brannoc_hearthwall", false], "later rank-ups keep it")
	var before: String = _snapshot(state)
	_refused(RunActions.rank_up(state, _content(), "brannoc"), "Brannoc of the Hearthwatch is already rank S")
	_refused(RunActions.rank_up(state, _content(), "wren"), "no hero \"wren\" in the team")
	assert_eq(_snapshot(state), before)


func test_specialization_pick() -> void:
	var state: RunState = _run()
	_refused(RunActions.choose_specialization(state, _content(), "brannoc", "brannoc_hearthwall"), "no specialization to pick")
	RunActions.rank_up(state, _content(), "brannoc")
	_refused(RunActions.choose_specialization(state, _content(), "brannoc", "wren_duelist"), "isn't one of brannoc's specializations")
	assert_true(RunActions.choose_specialization(state, _content(), "brannoc", "brannoc_hearthwall").ok)
	assert_eq([state.hero("brannoc").specialization_id, state.hero("brannoc").needs_specialization], ["brannoc_hearthwall", false])


func test_deed_unlock_choices() -> void:
	var state: RunState = _run()
	var brannoc: RunHero = state.hero("brannoc")
	var goals: Array[int] = _content().heroes["brannoc"].calling.deed.goals
	brannoc.calling_progress = goals[0]
	_refused(RunActions.choose_deed_unlock(state, _content(), "brannoc", DeedSetup.CALLING, 0), "brannoc has no calling unlock to choose")
	brannoc.calling_progress = goals[1]
	assert_true(brannoc.choice_waiting(_content(), DeedSetup.CALLING))
	_refused(RunActions.choose_deed_unlock(state, _content(), "brannoc", DeedSetup.CALLING, 2), "no option 2")
	_refused(RunActions.choose_deed_unlock(state, _content(), "brannoc", DeedSetup.SPECIALIZATION, 0), "brannoc has no specialization deed")
	_refused(RunActions.choose_deed_unlock(state, _content(), "wren", DeedSetup.CALLING, 0), "no hero \"wren\" in the team")
	var taken: RunActions.Result = RunActions.choose_deed_unlock(state, _content(), "brannoc", DeedSetup.CALLING, 1)
	assert_true(taken.ok)
	assert_string_contains(taken.note, _content().heroes["brannoc"].calling.levels[1].options[1].name)
	assert_eq(brannoc.calling_choice, 1)
	var before: String = _snapshot(state)
	_refused(RunActions.choose_deed_unlock(state, _content(), "brannoc", DeedSetup.CALLING, 0), "brannoc already chose that unlock")
	assert_eq(_snapshot(state), before, "the choice is for good")
	assert_eq(state.check(_content()), [] as Array[String])


func test_a_new_specialization_starts_its_deed_from_zero() -> void:
	var state: RunState = _run()
	RunActions.rank_up(state, _content(), "brannoc")
	var brannoc: RunHero = state.hero("brannoc")
	brannoc.spec_progress = 5
	assert_true(RunActions.choose_specialization(state, _content(), "brannoc", "brannoc_hearthwall").ok)
	assert_eq([brannoc.spec_progress, brannoc.spec_choice], [0, -1])


func test_heroes_joining_above_c_come_with_a_specialization() -> void:
	var state: RunState = _run()
	assert_true(RunActions.add_hero(state, _content(), "wren", 2, "wren_duelist").ok)
	assert_eq([state.hero("wren").rank, state.hero("wren").needs_specialization], [2, false])
	_refused(RunActions.add_hero(state, _content(), "vell", 0, "vell_wardweaver"), "a rank-C hero has no specialization")
	assert_true(RunActions.add_hero(state, _content(), "vell", 1).ok)
	assert_true(state.hero("vell").needs_specialization)


func test_team_order_and_rows() -> void:
	var state: RunState = _run()
	for hero_id: String in ["wren", "vell"]:
		assert_true(RunActions.add_hero(state, _content(), hero_id).ok)
	assert_true(RunActions.move_hero(state, "vell", 0).ok)
	assert_eq([state.heroes[0].hero_id, state.heroes[1].hero_id, state.heroes[2].hero_id], ["vell", "brannoc", "wren"])
	assert_true(RunActions.move_hero(state, "vell", 99).ok, "clamped to the end")
	assert_eq(state.heroes[2].hero_id, "vell")
	_refused(RunActions.move_hero(state, "odo", 0), "no hero \"odo\" in the team")
	assert_true(RunActions.set_row(state, "brannoc", UnitSetup.Row.BACK).ok)
	assert_eq(state.hero("brannoc").row, UnitSetup.Row.BACK)
	assert_eq(state.check(_content()), [] as Array[String])


# --- gold and relics ----------------------------------------------------------

func test_gold_and_relics() -> void:
	var state: RunState = _run()
	_refused(RunActions.spend_gold(state, 30), "not enough gold (20 of 30)")
	assert_true(RunActions.spend_gold(state, 5).ok)
	assert_true(RunActions.gain_gold(state, 10).ok)
	assert_eq(state.gold, 25)
	assert_true(RunActions.add_relic(state, _content(), "warding_knot").ok)
	_refused(RunActions.add_relic(state, _content(), "warding_knot"), "already holds Warding Knot")
	_refused(RunActions.add_relic(state, _content(), "no_relic"), "unknown relic")
