extends GutTest
## The economy in a run (docs/plans/rebuild-phase5-run.md, section 6): items
## as data, "no effect on this hero", the loadout, the Pedlar and the Magpie,
## treating wounds, and items reaching the fight.

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
	assert_eq(counts, [10, 4, 5, 3] as Array[int], "10 charms, 4 tactics, 5 sigils, 3 grafts")


func test_no_effect_on_this_hero() -> void:
	var salve: ItemDef = _run.items["mending_salve"]
	assert_false(salve.works_on(_kit("deadeye"), "maren"), "Maren doesn't heal")
	assert_true(salve.works_on(_kit("lanternbearer"), "vell"))
	assert_false(_run.items["deep_well"].works_on(_kit("last_watch", true), "brannoc"), "no mana after Last Watch")
	assert_true(_run.items["deep_well"].works_on(_kit("last_watch"), "brannoc"))
	assert_false(_run.items["wait_to_heal_orders"].works_on(_kit("hearthwall"), "brannoc"))
	assert_true(_run.items["plant_feet_orders"].works_on(_kit("hearthwall"), "brannoc"))
	var reach: ItemDef = _run.items["sigil_of_reach"]
	assert_false(reach.works_on(_kit("deadeye"), "maren"), "Marking Shot has no area")
	assert_true(reach.works_on(_kit("lanternbearer", true), "vell"), "Night Lantern does")


func test_bad_items_are_refused() -> void:
	var cases: Array = [
		[{"id": "odd", "kind": "tactic", "name": "Odd", "icon": "braced", "text": "x", "answers": "x", "price": 2, "tactic": "nothing"}, "unknown tactic \"nothing\""],
		[{"id": "nobody", "kind": "charm", "name": "Nobody", "icon": "braced", "text": "x", "answers": "x", "price": 2, "needs": ["melee", "ranged"], "mod": {"stats_bp": {"hp": 11000}}}, "does nothing on any hero"],
		[{"id": "bare", "kind": "charm", "name": "Bare", "icon": "braced", "text": "x", "answers": "x", "price": 2}, "mod"],
		[{"id": "blank", "kind": "charm", "name": "Blank", "icon": "no_such_glyph", "text": "x", "answers": "x", "price": 2, "mod": {"stats_bp": {"hp": 11000}}}, "no glyph \"no_such_glyph\""],
		[{"id": "iconless", "kind": "charm", "name": "Iconless", "text": "x", "answers": "x", "price": 2, "mod": {"stats_bp": {"hp": 11000}}}, "icon"],
	]
	for case: Array in cases:
		var run: RunContent = _with_items([case[0]])
		assert_true(run.errors.any(func(message: String) -> bool: return message.contains(case[1])), "%s: %s" % [case[1], run.errors])


func test_equipping_and_swapping() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.stash.assign(["vital_stone", "iron_skin", "plant_feet_orders", "hold_ground_orders"])
	assert_eq(flow.equip("brannoc", 0, "vital_stone"), "")
	assert_eq(state.hero("brannoc").slots, ["vital_stone", "", ""] as Array[String])
	assert_eq(flow.equip("brannoc", 0, "iron_skin"), "", "a swap")
	assert_eq(state.hero("brannoc").slots[0], "iron_skin")
	assert_eq(state.stash, ["plant_feet_orders", "hold_ground_orders", "vital_stone"] as Array[String], "the old one back in the stash")
	assert_eq(flow.equip("brannoc", 1, "plant_feet_orders"), "")
	assert_eq(flow.equip("brannoc", 2, "hold_ground_orders"), "brannoc already holds a tactic")
	assert_eq(flow.equip("brannoc", 1, "hold_ground_orders"), "", "a tactic swaps for a tactic")
	assert_eq(flow.equip("brannoc", 3, "vital_stone"), "brannoc has no slot 3")
	assert_eq(flow.equip("brannoc", 2, "whetstone"), "\"whetstone\" isn't in the stash")
	assert_eq(flow.unequip("brannoc", 2), "brannoc has nothing in slot 2")
	assert_eq(flow.unequip("brannoc", 0), "")
	assert_has(state.stash, "iron_skin")


func test_the_loadout_reaches_the_fight() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.stash.assign(["vital_stone", "plant_feet_orders", "wait_to_heal_orders"])
	flow.equip("brannoc", 0, "vital_stone")
	flow.equip("brannoc", 1, "wait_to_heal_orders")
	flow.equip("maren", 0, "plant_feet_orders")
	flow.leave_camp()
	flow.choose_fight(0)
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(setup.heroes[0].def.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(_kit("hearthwall").stats.get_stat(UnitStats.Stat.HP), 11200))
	assert_null(setup.heroes[0].tactic, "Wait to heal does nothing on Brannoc")
	assert_eq(setup.heroes[1].tactic.id, "plant_feet")


func test_the_pedlar() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	assert_eq(flow.buy(0), "no shop is open")
	assert_eq(flow.open_shop("tinker"), "there's no shop \"tinker\"")
	assert_eq(flow.open_shop("pedlar"), "")
	assert_eq(state.wares.size(), _run.act.pedlar_wares)
	for id: String in state.wares:
		var item: ItemDef = _run.items[id]
		assert_ne(item.kind, ItemDef.Kind.GRAFT, "no grafts at the Pedlar")
		assert_true(state.heroes.any(func(hero: RunState.Hero) -> bool: return item.works_on(_run.hero_kit(hero), hero.id)), "%s suits someone" % id)
	assert_eq(state.wares, Offers.pedlar(_run, state, 0), "the same state, the same wares")
	state.shards = 10
	var first: String = state.wares[0]
	assert_eq(flow.buy(0), "")
	assert_eq([state.shards, state.stash, state.wares[0]], [10 - _run.items[first].price, [first], ""])
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
	var kinds: Array = state.wares.map(func(id: String) -> ItemDef.Kind: return _run.items[id].kind)
	assert_eq(kinds.filter(func(kind: ItemDef.Kind) -> bool: return kind == ItemDef.Kind.GRAFT).size(), 2, "half grafts")
	assert_eq(state.wares.size(), 4)
	assert_eq(flow.price_of("whetstone"), 9, "6 shards at the Pedlar (a charm), half again, rounded up")
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
