extends GutTest
## The loadout pool's frame (docs/plans/rebuild-phase5c-combos.md, step 6a,
## section 14): ranks and each kind's counter, a bought copy a rank up, rank
## III never in a shop, selling at half, prices by kind, one gambit per
## hero, ranks in the fight and in the save, and the tallies a real fight
## counts for a tactic and a sigil.

const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start(run: RunContent = _run) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(run, 7, Bot.first_vows(run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


func _own(flow: RunFlow, item_id: String, hero_id: String = "", slot: int = 0) -> void:
	flow.state.stash.append(item_id)
	flow.state.item_ranks[item_id] = 1
	flow.state.item_counts[item_id] = 0
	if not hero_id.is_empty():
		assert_eq(flow.equip(hero_id, slot, item_id), "")


func _result(outcome: FightResult.Outcome, tallies: Dictionary = {}) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	result.end_tick = 600
	for key: String in tallies:
		var tally := FightResult.Deed.new()
		tally.hero = key.get_slice("|", 0)
		tally.path = key.get_slice("|", 1)
		tally.amount = tallies[key]
		result.tallies.append(tally)
	return result


func _to_fight(flow: RunFlow) -> void:
	assert_eq(flow.leave_camp(), "")
	assert_eq(flow.choose_fight(0), "")


func test_prices_and_ranks_by_kind() -> void:
	assert_eq(_run.act.item_prices, {"charm": 6, "tactic": 4, "sigil": 8, "gambit": 12})
	assert_eq(_run.act.item_ranks["charm"], [4, 8])
	assert_eq(_run.act.item_ranks["tactic"], [60000, 180000], "60s, then 180s more (Decision 32)")
	assert_eq(_run.act.item_ranks["sigil"], [10, 25])
	assert_eq(_run.act.item_ranks["gambit"], [3, 6])
	var flow: RunFlow = _start()
	flow.open_shop("pedlar")
	assert_eq([flow.price_of("fleet"), flow.price_of("echo"), flow.price_of("plant_feet_orders")], [6, 8, 4])
	assert_eq([flow.sell_price("fleet"), flow.sell_price("echo"), flow.sell_price("plant_feet_orders")], [3, 4, 2], "half, rounded down")


func test_a_charm_ranks_up_with_won_fights() -> void:
	var flow: RunFlow = _start()
	_own(flow, "ember_tipped", "maren")
	_own(flow, "fleet")
	for i: int in 3:
		_to_fight(flow)
		flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
		assert_eq(flow.state.item_ranks["ember_tipped"], 1)
		flow.state.pick.clear()
		flow.state.relic_choice.clear()
		assert_eq(flow.finish_day(), "")
	assert_eq(flow.rank_progress("ember_tipped"), Vector2i(3, 4))
	_to_fight(flow)
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq(flow.rank_progress("ember_tipped"), Vector2i(3, 4), "a lost fight isn't a won one")
	_to_fight(flow)
	flow.record(Bot.formation(), _result(FightResult.Outcome.TIE))
	assert_eq([flow.state.item_ranks["ember_tipped"], flow.state.item_counts["ember_tipped"]], [2, 0], "a tie counts as a win: rank II")
	assert_eq(flow.state.ranked, ["ember_tipped"] as Array[String])
	assert_eq(flow.rank_progress("ember_tipped"), Vector2i(0, 8))
	assert_eq(flow.state.item_counts["fleet"], 0, "in the stash, it counts nothing")


func test_a_sigil_counts_casts_and_a_tactic_seconds() -> void:
	var flow: RunFlow = _start()
	_own(flow, "echo", "vell")
	_own(flow, "hold_ground_orders", "brannoc")
	_to_fight(flow)
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT, {"vell|item:echo": 12, "brannoc|item:hold_ground_orders": 70000}))
	assert_eq([flow.state.item_ranks["echo"], flow.state.item_counts["echo"]], [2, 2], "10 casts for rank II, the 2 over carry on")
	assert_eq([flow.state.item_ranks["hold_ground_orders"], flow.state.item_counts["hold_ground_orders"]], [2, 10000], "60s, then 10s toward rank III")
	flow.state.item_counts["echo"] = 0
	_to_fight(flow)
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT, {"vell|item:echo": 100}))
	assert_eq([flow.state.item_ranks["echo"], flow.state.item_counts["echo"]], [3, 0], "rank III is the last; nothing more counts")


func test_the_fight_tallies_casts_and_standing() -> void:
	var flow: RunFlow = _start()
	_own(flow, "echo", "vell")
	_own(flow, "plant_feet_orders", "brannoc")
	_own(flow, "fleet", "maren")
	_to_fight(flow)
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	var result: FightResult = CombatSim.run(setup, _run.content)
	var signature: String = setup.heroes[2].def.signature.id
	var casts: int = result.combat_log.entries.filter(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.FIRE and entry.source_unit == "vell" and entry.source_ability == signature).size()
	assert_gt(casts, 0)
	assert_eq(result.tally_amount("vell", "item:echo"), casts, "every fire of its signature; the echoes are their own")
	var fell: Array = result.combat_log.entries.filter(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.DEATH and entry.target == "brannoc")
	var stood: int = (fell[0].tick if not fell.is_empty() else result.end_tick) * FixedMath.MS_PER_TICK
	assert_almost_eq(result.tally_amount("brannoc", "item:plant_feet_orders"), stood, 2 * FixedMath.MS_PER_TICK, "the ms it stood")
	assert_eq(result.tally_amount("maren", "item:fleet"), 0, "a charm counts won fights, in the run")


func test_a_bought_copy_is_a_rank_up() -> void:
	var flow: RunFlow = _start()
	flow.open_shop("pedlar")
	flow.state.shards = 100
	var ware: String = flow.state.wares[0]
	assert_eq(flow.buy(0), "")
	assert_eq(flow.state.item_ranks[ware], 1)
	flow.state.item_counts[ware] = 2
	flow.state.wares[1] = ware
	assert_eq(flow.buy(1), "")
	assert_eq([flow.state.item_ranks[ware], flow.state.item_counts[ware], flow.state.stash.count(ware)], [2, 0, 1], "a rank up, its count starting again, still one")
	flow._gain_item(ware, 2)
	assert_eq(flow.state.item_ranks[ware], 3, "a rank II copy on a rank II one: rank III")
	flow.state.item_ranks.erase(ware)
	flow.state.stash.erase(ware)
	flow._gain_item(ware, 2)
	assert_eq(flow.state.item_ranks[ware], 2, "a rank II copy, new: rank II")


func test_rank_iii_never_reaches_a_shop() -> void:
	var flow: RunFlow = _start()
	for id: String in _run.item_ids:
		flow.state.item_ranks[id] = 3
	flow.state.item_ranks.erase("fleet")
	flow.state.item_ranks.erase("echo")
	for rerolls: int in 5:
		for id: String in Offers.pedlar(_run, flow.state, rerolls):
			assert_has(["fleet", "echo"], id)
	assert_eq(Offers.pedlar(_run, flow.state, 0).size(), 2)


func test_the_pedlar_draws_every_kind_unfiltered() -> void:
	var flow: RunFlow = _start()
	var seen: Dictionary[int, bool] = {}
	for rerolls: int in 40:
		for id: String in Offers.pedlar(_run, flow.state, rerolls):
			seen[_run.items[id].kind] = true
	assert_true(seen.has(ItemDef.Kind.CHARM) and seen.has(ItemDef.Kind.TACTIC) and seen.has(ItemDef.Kind.SIGIL))
	var wait: bool = false
	for rerolls: int in 80:
		wait = wait or Offers.pedlar(_run, flow.state, rerolls).has("wait_to_heal_orders")
	assert_true(wait, "Wait to heal shows up though only Vell can follow it")


func test_selling() -> void:
	var flow: RunFlow = _start()
	_own(flow, "fleet", "maren")
	_own(flow, "echo")
	flow.state.item_ranks["fleet"] = 3
	var shards: int = flow.state.shards
	assert_eq(flow.sell("fleet"), "only the Pedlar buys items")
	flow.open_shop("pedlar")
	shards = flow.state.shards
	assert_eq(flow.sell("fleet"), "")
	assert_eq([flow.state.shards, flow.state.hero("maren").slots[0], flow.state.item_ranks.has("fleet")], [shards + 3, "", false],
		"half a charm's price, rank III or not, from its slot")
	assert_eq(flow.sell("echo"), "")
	assert_eq([flow.state.shards, flow.state.stash.has("echo")], [shards + 7, false], "and from the stash")
	assert_eq(flow.sell("echo"), "the run doesn't own \"echo\"")
	flow.close_shop()
	flow.state.camp.assign(["magpie"])
	_own(flow, "echo")
	flow.open_shop("magpie")
	assert_eq(flow.sell("echo"), "only the Pedlar buys items", "the Magpie doesn't buy items")


func test_ranks_reach_the_fight() -> void:
	var flow: RunFlow = _start()
	_own(flow, "fleet", "maren")
	_to_fight(flow)
	var speed: int = _run.hero_kit(flow.state.hero("maren")).stats.get_stat(UnitStats.Stat.SPEED)
	var errors: Array[String] = []
	assert_eq(flow.fight_setup(Bot.formation(), errors).heroes[1].def.stats.get_stat(UnitStats.Stat.SPEED), speed + 1)
	flow.state.item_ranks["fleet"] = 3
	assert_eq(flow.fight_setup(Bot.formation(), errors).heroes[1].def.stats.get_stat(UnitStats.Stat.SPEED), speed + 2, "rank III")


func test_one_gambit_per_hero() -> void:
	var rank: Dictionary = {"stats_add": {"speed": 1}}
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	items.append({"id": "test_gambit", "kind": "gambit", "name": "Test", "icon": "braced", "text": "x", "ranks": [rank, rank, rank]})
	items.append({"id": "test_gambit_2", "kind": "gambit", "name": "Test 2", "icon": "braced", "text": "x", "ranks": [rank, rank, rank]})
	var texts: Dictionary[String, String] = {}
	for file: String in [RunContent.ACT_FILE, RunContent.UPGRADES_FILE, RunContent.CAMPS_FILE, RunContent.RELICS_FILE, RunContent.BONDS_FILE]:
		texts[file] = FileAccess.get_file_as_string("res://data/" + file)
	texts[RunContent.ITEMS_FILE] = JSON.stringify(items)
	var run: RunContent = RunContent.load_texts(texts, _run.content)
	assert_true(run.is_valid(), "\n".join(run.errors))
	var flow: RunFlow = _start(run)
	_own(flow, "test_gambit", "brannoc")
	_own(flow, "test_gambit_2")
	assert_eq(flow.equip("brannoc", 1, "test_gambit_2"), "brannoc already holds a gambit")
	assert_eq(flow.equip("brannoc", 0, "test_gambit_2"), "", "a gambit swaps for a gambit")
	assert_eq(flow.equip("maren", 0, "test_gambit"), "")


func test_ranks_save() -> void:
	var flow: RunFlow = _start()
	_own(flow, "fleet", "maren")
	flow.state.item_ranks["fleet"] = 2
	flow.state.item_counts["fleet"] = 5
	flow.state.ranked.assign(["fleet"])
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(flow.state.to_dict()))
	assert_eq([loaded.item_ranks["fleet"], loaded.item_counts["fleet"], loaded.ranked], [2, 5, ["fleet"]])
	var old: Dictionary = flow.state.to_dict()
	old["version"] = 1
	assert_null(RunState.from_dict(old), "a save from before the loadout pool doesn't load (its items are gone)")
