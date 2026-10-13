extends GutTest
## Hob's run pieces (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## section 8 and Decision 6; 8f-5b): shop rules on a path's stage and on
## cards (Haggle's free reroll, Second Haggle's cheap one, Fence's half-price
## rerolls and quarter sell-back, the Hoarder's dearer rerolls, Wholesale,
## Insider's rank II charm), at the Pedlar and the boss shop only; the shards
## they save as Haggle's deed; shards spent in shops as transformed Fence's
## team snowball (the Magpie too, never the Shrine); and the run counts his
## cards grow with (fights won holding 30+ shards, shops visited), Lucky
## Find's once an act, the Tithe's shards held (The Counting House), and The
## Black Market Ledger.

const R = preload("res://tests/run/run_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start(path_id: String, third: String = "maren", third_path: String = "deadeye") -> RunFlow:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {"brannoc": "hearthwall", "hob": path_id}
	vows[third] = third_path
	var flow: RunFlow = RunFlow.start(_run, 7, vows, errors)
	assert_eq(errors, [] as Array[String])
	return flow


func _own(flow: RunFlow, item_id: String) -> void:
	flow.state.stash.append(item_id)
	flow.state.item_ranks[item_id] = 1
	flow.state.item_counts[item_id] = 0


func _won(flow: RunFlow) -> FightResult:
	var result := FightResult.new()
	result.outcome = FightResult.Outcome.VICTORY
	result.end_tick = 600
	return result


func test_haggle_frees_the_first_reroll_and_its_deed_counts_the_saving() -> void:
	var flow: RunFlow = _start("fence")
	R.to_pedlar(flow)
	var full: int = flow.reroll_price(true)
	assert_gt(full, 0)
	assert_eq(flow.reroll_price(), 0, "Haggle: the first is free")
	var shards: int = flow.state.shards
	assert_eq(flow.reroll(), "")
	assert_eq(flow.state.shards, shards)
	assert_eq(flow.state.hero("hob").deeds["fence"], full, "the deed counts what it saved")
	assert_eq(flow.reroll_price(), flow.reroll_price(true), "the second costs what it costs")
	flow.state.hero("hob").upgrades.append("second_haggle")
	assert_eq(flow.reroll_price(), 1, "Second Haggle: 1 shard")
	R.to_magpie(flow)
	assert_eq(flow.reroll(), "only the Pedlar rerolls")


func test_transformed_fence_halves_rerolls_and_sells_for_a_quarter() -> void:
	var flow: RunFlow = _start("fence")
	_own(flow, "echo")
	R.to_pedlar(flow)
	var half: int = flow.sell_price("echo")
	flow.state.hero("hob").transformed = true
	var price: int = flow.act.item_prices[ItemDef.KIND_NAMES[_run.items["echo"].kind]]
	assert_eq([half, flow.sell_price("echo")], [price / 2, price / 4], "half, then a quarter")
	flow.state.rerolls = 3
	var full: int = flow.reroll_price(true)
	assert_eq(flow.reroll_price(), full / 2, "half, rounded down")


func test_the_hoarder_pays_more_for_rerolls() -> void:
	var flow: RunFlow = _start("hoarder")
	R.to_pedlar(flow)
	assert_eq(flow.reroll_price(), flow.reroll_price(true))
	flow.state.hero("hob").transformed = true
	assert_eq(flow.reroll_price(), flow.reroll_price(true) + 1, "every relic bought makes him weaker")


func test_wholesale_and_insider_at_the_pedlar_only() -> void:
	var flow: RunFlow = _start("fence")
	var hob: RunState.Hero = flow.state.hero("hob")
	hob.transformed = true
	R.to_pedlar(flow)
	var echo: int = flow.price_of("echo")
	hob.upgrades.append("wholesale")
	assert_eq(flow.price_of("echo"), echo - 1, "Wholesale: 1 less")
	R.to_magpie(flow)
	assert_eq(flow.price_of(flow.state.wares[0]), flow.act.magpie_charm_price, "the Magpie keeps his own (Decision 6)")
	hob.upgrades.append("insider")
	R.to_pedlar(flow)
	var charms: Array[int] = []
	for i: int in flow.state.wares.size():
		if _run.items[flow.state.wares[i]].kind == ItemDef.Kind.CHARM:
			charms.append(i)
	assert_gt(charms.size(), 0, "this shop shows a charm")
	assert_eq(flow.state.wares_rank_ii, [charms[0]] as Array[int], "the first charm comes at rank II")
	assert_eq(flow.ware_rank(charms[0]), 2)
	var loaded: RunState = RunState.from_dict(flow.state.to_dict())
	assert_eq(loaded.wares_rank_ii, flow.state.wares_rank_ii, "the save keeps it")
	flow.state.shards = 99
	var id: String = flow.state.wares[charms[0]]
	assert_eq(flow.buy(charms[0]), "")
	assert_eq(flow.state.item_ranks[id], 2, "bought at rank II")
	flow.close_shop()
	assert_eq(flow.state.wares_rank_ii, [] as Array[int])


func test_shards_spent_grow_transformed_fence_s_team_bonus() -> void:
	var flow: RunFlow = _start("fence")
	var hob: RunState.Hero = flow.state.hero("hob")
	var key: String = RunContent.path_growth_key(_run.content.paths["fence"])
	R.to_pedlar(flow)
	flow.state.shards = 99
	assert_eq(flow.buy(0), "")
	assert_false(hob.growth.has(key), "vowed, nothing counts")
	hob.transformed = true
	var before: int = flow.state.shards
	assert_eq(flow.buy(1), "")
	assert_eq(hob.growth[key], before - flow.state.shards, "each shard spent")
	flow.state.rerolls = 3
	var reroll: int = flow.reroll_price()
	var counted: int = hob.growth[key]
	assert_eq(flow.reroll(), "")
	assert_eq(hob.growth[key], counted + reroll, "a reroll's price")
	hob.wounds = 1
	var spent: int = hob.growth[key]
	assert_eq(flow.treat_wound("hob"), "")
	assert_eq(hob.growth[key], spent + flow.wound_price(), "a wound treated")
	R.to_magpie(flow)
	var at_magpie: int = hob.growth[key]
	before = flow.state.shards
	assert_eq(flow.buy(0), "")
	assert_eq(hob.growth[key], at_magpie + before - flow.state.shards, "the Magpie's count too")
	hob.growth[key] = 25
	var mods: Array[KitMod] = _run.relic_mods(flow.state)
	var grown: Array[KitMod] = mods.filter(func(mod: KitMod) -> bool: return mod.stats_bp.size() > 0 and mod.stats_bp[UnitStats.Stat.ATK] == 10200)
	assert_eq(grown.size(), 1, "+1% ATK, MGK, and max HP for every 10, to the whole team")
	hob.upgrades.append("big_spender")
	hob.growth[key] = 20
	var bigger: Array[KitMod] = _run.relic_mods(flow.state).filter(func(mod: KitMod) -> bool: return mod.stats_bp.size() > 0 and mod.stats_bp[UnitStats.Stat.MGK] == 10300)
	assert_eq(bigger.size(), 1, "Big Spender: 20 spent counts as 30")


func test_won_holding_and_shops_visited_grow_his_cards() -> void:
	var flow: RunFlow = _start("hoarder")
	var hob: RunState.Hero = flow.state.hero("hob")
	hob.transformed = true
	hob.upgrades.append("old_coins")
	flow.choose_fight(0)
	flow.state.shards = 29
	flow.record(HeroTeam.place(_run.content, ["brannoc", "maren", "hob"] as Array[String], HeroTeam.GUARDED), _won(flow))
	assert_eq(hob.growth.get("old_coins", 0), 0, "29 shards held isn't enough")
	flow.state.pick.clear()
	flow.state.relic_choice.clear()
	assert_eq(R.next_day(flow), "")
	flow.choose_fight(0)
	flow.state.shards = 30
	flow.record(HeroTeam.place(_run.content, ["brannoc", "maren", "hob"] as Array[String], HeroTeam.GUARDED), _won(flow))
	assert_eq(hob.growth.get("old_coins", 0), 1, "won holding 30")
	var fence: RunFlow = _start("fence")
	var fenced: RunState.Hero = fence.state.hero("hob")
	fenced.transformed = true
	fenced.upgrades.append("old_contacts")
	R.to_pedlar(fence)
	R.to_magpie(fence)
	assert_eq(fenced.growth.get("old_contacts", 0), 2, "each shop visited")
	fenced.growth["old_contacts"] = 12
	assert_eq(_run.tithe_steps(fenced), 2, "1 more a win for every 5 shops")


func test_lucky_find_pays_once_an_act() -> void:
	var flow: RunFlow = _start("hoarder")
	var hob: RunState.Hero = flow.state.hero("hob")
	hob.upgrades.append("lucky_find")
	flow.choose_fight(0)
	var result: FightResult = _won(flow)
	assert_eq(flow._tithes(result, flow.state.chosen).get("hob", 0), 5, "the act's first won fight")
	assert_eq(flow._tithes(result, flow.state.chosen).get("hob", 0), 0, "not the next")
	assert_eq(RunState.Hero.from_dict(hob.to_dict()).tithe_act, 1, "the save keeps when it paid")
	flow.state.act = 2
	assert_eq(flow._tithes(result, flow.state.chosen).get("hob", 0), 5, "a new act")


func test_the_tithe_s_shards_held_are_spent_last() -> void:
	var flow: RunFlow = _start("hoarder", "edric", "tithe_collector")
	flow.state.hero("edric").transformed = true
	flow.choose_fight(0)
	flow.state.shards = 20
	flow.record(HeroTeam.place(_run.content, ["brannoc", "edric", "hob"] as Array[String], HeroTeam.GUARDED), _won(flow))
	var tithe: int = flow.state.fought.back().tithe
	assert_gt(tithe, 0, "Edric's Tithe paid")
	assert_eq(flow.state.tithe_held, tithe)
	flow.state.shards = tithe - 2
	var errors: Array[String] = []
	flow.state.pick.clear()
	flow.state.relic_choice.clear()
	assert_eq(R.next_day(flow), "")
	flow.choose_fight(0)
	var setup: FightSetup = flow.fight_setup(HeroTeam.place(_run.content, ["brannoc", "edric", "hob"] as Array[String], HeroTeam.GUARDED), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(setup.tithe_shards, mini(tithe, flow.state.shards), "spending took the rest first")
	flow.record(HeroTeam.place(_run.content, ["brannoc", "edric", "hob"] as Array[String], HeroTeam.GUARDED), _won(flow))
	assert_eq(flow.state.tithe_held, tithe - 2 + flow.state.fought.back().tithe, "what spending left of them, and today's")


func test_the_black_market_ledger() -> void:
	var flow: RunFlow = _start("fence", "ottilie", "transmuter")
	var hob: RunState.Hero = flow.state.hero("hob")
	hob.transformed = true
	flow.state.hero("ottilie").transformed = true
	var key: String = RunContent.path_growth_key(_run.content.paths["fence"])
	_own(flow, "echo")
	_own(flow, "fleet")
	R.to_pedlar(flow)
	assert_eq(flow.transmute("echo"), "")
	assert_false(hob.growth.has(key), "without the relic, transmuting isn't spending")
	flow.state.relics.append("the_black_market_ledger")
	R.to_pedlar(flow)
	var price: int = flow.act.item_prices[ItemDef.KIND_NAMES[_run.items["fleet"].kind]]
	assert_eq(flow.transmute("fleet"), "")
	assert_eq(hob.growth[key], price, "its full price counts as spent")
	assert_eq(flow.state.ledger_rerolls, 1)
	flow.state.rerolls = 3
	assert_eq(flow.reroll_price(), 0, "a free reroll (where it would cost something)")
	assert_eq(flow.reroll(), "")
	assert_eq([flow.state.ledger_rerolls, flow.reroll_price() > 0], [0, true], "spent")
