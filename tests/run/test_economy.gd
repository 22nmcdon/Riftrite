extends GutTest
## The economy in a run (docs/plans/rebuild-phase5-run.md, section 6; the
## loadout pool, phase 5c step 6): items as data, the loadout, the Pedlar and
## the Magpie, treating wounds, and items reaching the fight. Ranks and
## selling are test_loadout.gd's.

const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start(run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


func _kit(path_id: String, transformed: bool = false) -> UnitDef:
	var path: PathDef = _run.content.paths[path_id]
	return path.transformed_kit if transformed else path.vowed_kit


func _with_items(items: Array) -> RunContent:
	var texts: Dictionary[String, String] = {
		RunContent.ACT_FILE: FileAccess.get_file_as_string("res://data/act1.json"),
		RunContent.UPGRADES_FILE: FileAccess.get_file_as_string("res://data/upgrades.json"),
		RunContent.ITEMS_FILE: JSON.stringify(items),
	}
	return RunContent.load_texts(texts, _run.content)


func test_the_items_load() -> void:
	assert_true(_run.is_valid(), "\n".join(_run.errors))
	var counts: Array[int] = [0, 0, 0, 0]
	for id: String in _run.item_ids:
		counts[_run.items[id].kind] += 1
		if _run.items[id].kind == ItemDef.Kind.TACTIC:
			assert_not_null(_run.items[id].tactic, "%s has its tactic" % id)
	assert_eq(counts, [16, 4, 10, 0] as Array[int], "16 charms, 4 tactics, 10 sigils (phase 5c step 6a)")
	for id: String in _run.item_ids:
		if _run.items[id].kind != ItemDef.Kind.TACTIC:
			assert_eq(_run.items[id].ranks.size(), 3, "%s has three ranks" % id)


func test_a_tactic_a_hero_cant_follow_does_nothing() -> void:
	assert_false(RunContent.can_follow(_run.items["wait_to_heal_orders"].tactic, _kit("hearthwall"), "brannoc"))
	assert_true(RunContent.can_follow(_run.items["wait_to_heal_orders"].tactic, _kit("lanternbearer"), "vell"))
	assert_true(RunContent.can_follow(_run.items["plant_feet_orders"].tactic, _kit("hearthwall"), "brannoc"))


func test_bad_items_are_refused() -> void:
	var cases: Array = [
		[{"id": "odd", "kind": "tactic", "name": "Odd", "icon": "braced", "text": "x", "tactic": "nothing"}, "unknown tactic \"nothing\""],
		[{"id": "nobody", "kind": "charm", "name": "Nobody", "icon": "braced", "text": "x", "ranks": [{"stats_bp": {"hp": 11000}}, {"stats_bp": {"hp": 11000}}, {"on": [{"slot": "signature", "types": ["summon"], "duration_bp": 12000}]}]}, "rank III does nothing on any hero"],
		[{"id": "bare", "kind": "charm", "name": "Bare", "icon": "braced", "text": "x"}, "three ranks"],
		[{"id": "two", "kind": "sigil", "name": "Two", "icon": "braced", "text": "x", "ranks": [{"stats_bp": {"hp": 11000}}, {"stats_bp": {"hp": 11000}}]}, "three ranks"],
		[{"id": "blank", "kind": "charm", "name": "Blank", "icon": "no_such_glyph", "text": "x", "ranks": [{"stats_bp": {"hp": 11000}}, {"stats_bp": {"hp": 11000}}, {"stats_bp": {"hp": 11000}}]}, "no glyph \"no_such_glyph\""],
		[{"id": "iconless", "kind": "charm", "name": "Iconless", "text": "x", "ranks": [{"stats_bp": {"hp": 11000}}, {"stats_bp": {"hp": 11000}}, {"stats_bp": {"hp": 11000}}]}, "icon"],
		[{"id": "priced", "kind": "charm", "name": "Priced", "icon": "braced", "text": "x", "price": 3, "ranks": [{"stats_bp": {"hp": 11000}}, {"stats_bp": {"hp": 11000}}, {"stats_bp": {"hp": 11000}}]}, "price"],
	]
	for case: Array in cases:
		var run: RunContent = _with_items([case[0]])
		assert_true(run.errors.any(func(message: String) -> bool: return message.contains(case[1])), "%s: %s" % [case[1], run.errors])


func test_equipping_and_swapping() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.stash.assign(["fleet", "leech_fang", "plant_feet_orders", "hold_ground_orders"])
	assert_eq(flow.equip("brannoc", 0, "fleet"), "")
	assert_eq(state.hero("brannoc").slots, ["fleet", "", ""] as Array[String])
	assert_eq(flow.equip("brannoc", 0, "leech_fang"), "", "a swap")
	assert_eq(state.hero("brannoc").slots[0], "leech_fang")
	assert_eq(state.stash, ["plant_feet_orders", "hold_ground_orders", "fleet"] as Array[String], "the old one back in the stash")
	assert_eq(flow.equip("brannoc", 1, "plant_feet_orders"), "")
	assert_eq(flow.equip("brannoc", 2, "hold_ground_orders"), "brannoc already holds a tactic")
	assert_eq(flow.equip("brannoc", 1, "hold_ground_orders"), "", "a tactic swaps for a tactic")
	assert_eq(flow.equip("brannoc", 3, "fleet"), "brannoc has no slot 3")
	assert_eq(flow.equip("brannoc", 2, "echo"), "\"echo\" isn't in the stash")
	assert_eq(flow.unequip("brannoc", 2), "brannoc has nothing in slot 2")
	assert_eq(flow.unequip("brannoc", 0), "")
	assert_has(state.stash, "leech_fang")


func test_the_loadout_reaches_the_fight() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.stash.assign(["fleet", "plant_feet_orders", "wait_to_heal_orders"])
	flow.equip("brannoc", 0, "fleet")
	flow.equip("brannoc", 1, "wait_to_heal_orders")
	flow.equip("maren", 0, "plant_feet_orders")
	flow.leave_camp()
	flow.choose_fight(0)
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(setup.heroes[0].def.stats.get_stat(UnitStats.Stat.SPEED), _kit("hearthwall").stats.get_stat(UnitStats.Stat.SPEED) + 1, "Fleet at rank I")
	assert_null(setup.heroes[0].tactic, "Wait to heal does nothing on Brannoc")
	assert_eq(setup.heroes[1].tactic.id, "plant_feet")


func test_the_pedlar() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	assert_eq(flow.buy(0), "no shop is open")
	assert_eq(flow.open_shop("tinker"), "there's no shop \"tinker\"")
	assert_eq(flow.open_shop("pedlar"), "")
	assert_eq(state.wares.size(), _run.act.pedlar_wares)
	assert_eq(state.wares, Offers.pedlar(_run, state, 0), "the same state, the same wares")
	state.shards = 10
	var first: String = state.wares[0]
	assert_eq(flow.buy(0), "")
	assert_eq([state.shards, state.stash, state.wares[0]], [10 - _run.act.item_prices[ItemDef.KIND_NAMES[_run.items[first].kind]], [first], ""])
	assert_eq(state.item_ranks, {first: 1}, "owned at rank I")
	assert_eq(flow.buy(0), "there's no ware 0")
	var before: Array[String] = state.wares.duplicate()
	var relics_before: Array[String] = state.shop_relics.duplicate()
	assert_eq(flow.reroll_price(), 1)
	assert_eq(flow.reroll(), "")
	assert_eq(state.rerolls, 1)
	assert_ne(state.wares, before, "a fresh set")
	assert_ne(state.shop_relics, relics_before, "a reroll replaces the relic too (phase 5c Decision 19)")
	assert_eq(flow.reroll_price(), 2, "each reroll costs 1 more")
	state.shards = 0
	assert_eq(flow.reroll(), "a reroll costs 2 shards; there are 0")
	assert_string_starts_with(flow.buy(1), "it costs")
	flow.leave_camp()
	assert_eq([state.shop, state.wares], ["", [] as Array[String]], "leaving camp closes it")
	assert_eq(flow.open_shop("pedlar"), "can't open a shop now (the day is at route)")


func test_the_magpie() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	assert_eq(flow.open_shop("magpie"), "")
	assert_eq(state.wares.size(), 4)
	assert_eq(flow.price_of("fleet"), 9, "6 shards at the Pedlar (a charm), half again, rounded up")
	assert_eq(flow.reroll(), "only the Pedlar rerolls")


func test_treating_a_wound() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.hero("vell").wounds = 2
	assert_eq(flow.treat_wound("vell"), "no shop is open")
	flow.open_shop("pedlar")
	assert_eq(flow.treat_wound("vell"), "")
	assert_eq([state.hero("vell").wounds, state.shards], [1, _run.act.start_shards - _run.act.wound_price])
	assert_eq(flow.treat_wound("maren"), "maren has no wounds")
	state.shards = 0
	assert_eq(flow.treat_wound("vell"), "treating a wound costs 4 shards; there are 0")


func test_the_shop_and_stash_save() -> void:
	var flow: RunFlow = _start()
	flow.open_shop("pedlar")
	flow.state.shards = 20
	flow.buy(2)
	flow.reroll()
	flow.equip("vell", 1, flow.state.stash[0])
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(flow.state.to_dict()))
	assert_eq(loaded.shop, "pedlar")
	assert_eq(loaded.rerolls, 1)
