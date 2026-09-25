extends GutTest
## Run actions (docs/plans/run-state.md): items, essences, heroes, formation,
## and the rule that a refused action changes nothing.

const K = preload("res://tests/sim/sim_test_kit.gd")


func _content() -> ContentDb:
	return K.content()


## A run with brannoc (fielded) and 20 gold.
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


func test_rows_and_the_stash_have_room_limits() -> void:
	var state: RunState = _run()
	var large: int = _add(state, "hearthstone_ward")
	var medium: int = _add(state, "rusted_cleaver")
	var small: int = _add(state, "hearth_knife")
	_refused(RunActions.add_item(state, _content(), "oak_buckler"), "the stash has no room for Oak Buckler")
	assert_true(RunActions.move_item(state, _content(), large, "brannoc", 0).ok)
	var before: String = _snapshot(state)
	_refused(RunActions.move_item(state, _content(), medium, "brannoc", 1), "brannoc has no room for that (4 slots)")
	assert_eq(_snapshot(state), before, "a refused move changes nothing")
	assert_true(RunActions.move_item(state, _content(), small, "brannoc", 1).ok, "3 + 1 slots fit")


func test_one_auto_attack_item_per_hero() -> void:
	var state: RunState = _run()
	var claw: int = _add(state, "rusted_cleaver")
	var maw: int = _add(state, "blackthorn_bow")
	for uid: int in [claw, maw]:
		var def: ItemDef = _content().items[state.find_item(uid).item_id]
		assert_true(def.auto_attack, "%s is an auto-attack item" % def.id)
	assert_true(RunActions.move_item(state, _content(), claw, "brannoc", 0).ok)
	_refused(RunActions.move_item(state, _content(), maw, "brannoc", 0), "brannoc can hold only one auto-attack item")


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

func test_infusing_follows_sockets_and_resets_xp() -> void:
	var state: RunState = _run()
	var knife: int = _add(state, "hearth_knife")
	var lantern: int = _add(state, "night_lantern")
	for essence_id: String in ["ember", "frost", "verdant", "storm"]:
		assert_true(RunActions.add_essence(state, _content(), essence_id).ok)
	assert_true(RunActions.infuse(state, _content(), knife, 0).ok)
	state.find_item(knife).xp = 40
	_refused(RunActions.infuse(state, _content(), knife, 0), "Hearth Knife has no free socket (1)")
	assert_true(RunActions.infuse(state, _content(), lantern, 1).ok, "an Epic has 2 sockets")
	state.find_item(lantern).xp = 90
	assert_true(RunActions.infuse(state, _content(), lantern, 1).ok)
	assert_eq(state.find_item(lantern).essence_ids, ["verdant", "storm"] as Array[String])
	assert_eq(state.find_item(lantern).xp, 0, "a second essence resets XP")
	assert_eq(state.pouch, ["frost"] as Array[String])


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

func test_heroes_join_and_combine() -> void:
	var state: RunState = _run()
	assert_eq([state.heroes[0].row, state.heroes[0].benched], [UnitSetup.Row.FRONT, false], "the first hero stands in front")
	assert_true(RunActions.add_hero(state, _content(), "wren").ok)
	assert_eq(state.hero("wren").row, UnitSetup.Row.BACK)
	var knife: int = _add(state, "hearth_knife")
	RunActions.move_item(state, _content(), knife, "brannoc", 0)
	assert_true(RunActions.add_hero(state, _content(), "brannoc").ok)
	var brannoc: RunHero = state.hero("brannoc")
	assert_eq([brannoc.rank, brannoc.items.size(), brannoc.needs_specialization, state.heroes.size()], [1, 1, true, 2], "same rank: combine, keep items, pick at B")
	_refused(RunActions.add_hero(state, _content(), "brannoc", 0), "already in the guild at another rank")


func test_specialization_pick() -> void:
	var state: RunState = _run()
	_refused(RunActions.choose_specialization(state, _content(), "brannoc", "brannoc_hearthwall"), "no specialization to pick")
	RunActions.add_hero(state, _content(), "brannoc")
	_refused(RunActions.choose_specialization(state, _content(), "brannoc", "wren_duelist"), "isn't one of brannoc's specializations")
	assert_true(RunActions.choose_specialization(state, _content(), "brannoc", "brannoc_hearthwall").ok)
	assert_eq([state.hero("brannoc").specialization_id, state.hero("brannoc").needs_specialization], ["brannoc_hearthwall", false])
	RunActions.add_hero(state, _content(), "brannoc", 1)
	assert_eq([state.hero("brannoc").rank, state.hero("brannoc").specialization_id], [2, "brannoc_hearthwall"], "a rank-up keeps the specialization")


func test_recruits_above_c_come_with_a_specialization() -> void:
	var state: RunState = _run()
	assert_true(RunActions.add_hero(state, _content(), "wren", 2, "wren_duelist").ok)
	assert_eq([state.hero("wren").rank, state.hero("wren").needs_specialization], [2, false])
	_refused(RunActions.add_hero(state, _content(), "vell", 0, "vell_wardweaver"), "a rank-C hero has no specialization")
	assert_true(RunActions.add_hero(state, _content(), "vell", 1).ok)
	assert_true(state.hero("vell").needs_specialization)


## Real content plus three more heroes (copies of Brannoc), for roster limits.
func _seven_heroes() -> ContentDb:
	var content: ContentDb = ContentDb.load_dir("res://data")
	for hero_id: String in ["h5", "h6", "h7"]:
		var extra := HeroDef.new()
		var brannoc: HeroDef = content.heroes["brannoc"]
		extra.id = hero_id
		extra.name = hero_id.capitalize()
		extra.hero_class = brannoc.hero_class
		extra.stats = brannoc.stats
		extra.basic_attack = brannoc.basic_attack
		content.heroes[hero_id] = extra
		content.hero_ids.append(hero_id)
	return content


func test_roster_and_fielding_limits() -> void:
	var content: ContentDb = _seven_heroes()
	var state: RunState = RunState.make(3)
	for hero_id: String in ["brannoc", "wren", "vell", "odo", "h5"]:
		assert_true(RunActions.add_hero(state, content, hero_id).ok)
	assert_eq(state.fielded_count(), 5)
	assert_true(RunActions.add_hero(state, content, "h6").ok)
	assert_true(state.hero("h6").benched, "a full field sends a new hero to backup")
	_refused(RunActions.add_hero(state, content, "h7"), "the roster is full (6)")
	_refused(RunActions.set_benched(state, "h6", false), "at most 5 heroes can be fielded")
	_refused(RunActions.set_benched(state, "brannoc", true), "the first roster slot is always a field slot")
	assert_true(RunActions.set_benched(state, "wren", true).ok)
	assert_true(RunActions.set_benched(state, "h6", false).ok)
	_refused(RunActions.move_hero(state, "wren", 0), "the first roster slot is always a field slot")
	assert_eq(state.heroes[1].hero_id, "wren", "a refused move puts the hero back")
	assert_true(RunActions.move_hero(state, "odo", 0).ok)
	assert_eq(state.heroes[0].hero_id, "odo")
	assert_true(RunActions.set_benched(state, "brannoc", true).ok, "brannoc isn't in the first slot any more")
	assert_true(RunActions.set_row(state, "odo", UnitSetup.Row.BACK).ok)
	assert_eq(state.check(content), [] as Array[String])


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
