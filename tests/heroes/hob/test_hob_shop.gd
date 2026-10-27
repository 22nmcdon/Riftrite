extends GutTest
## Hob's run pieces (phase 8 part 6, docs/plans/phases/rebuild-phase8-last-heroes.md
## section 8 and Decision 6; 8f-5b): shop rules on a path's stage and on
## cards (Haggle's free reroll, Second Haggle's cheap one, Fence's half-price
## rerolls and quarter sell-back, the Hoarder's dearer rerolls, Wholesale,
## Insider's rank II charm), at the Pedlar and the boss shop only; the shards
## they save as Haggle's deed; shards spent in shops as transformed Fence's
## team snowball (the Magpie too, never the Shrine); and the run counts his
## cards grow with (fights won holding 30+ shards, shops visited), Lucky
## Find's once an act, the Tithe's shards held (The Counting House), and The
## Black Market Ledger. His apexes' (8f-5c): Black Market's slot a tier up at
## its own tier's price, its snowball (relics bought), its taste, its cards,
## and Fence's rules carrying on; Low Bar and Deep Vault on Dragon's Hoard's
## snowball (a relic still counts from 30); snowball cards reaching only their
## own layer; and Manhunter's snowball counted in fights.

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


## Hob transformed on `path_id` with `apex_id` earned.
func _apexed(path_id: String, apex_id: String, third: String = "maren", third_path: String = "deadeye") -> RunFlow:
	var flow: RunFlow = _start(path_id, third, third_path)
	var hob: RunState.Hero = flow.state.hero("hob")
	hob.transformed = true
	hob.apex = apex_id
	hob.apex_earned = true
	return flow


func test_black_market_s_slot_a_tier_up_at_its_own_price() -> void:
	var flow: RunFlow = _apexed("fence", "black_market")
	R.to_pedlar(flow)
	var slot: int = flow.state.black_market_slot
	assert_eq(slot, flow.state.shop_relics.size() - 1, "a second relic slot")
	var relic: RelicDef = _run.relics[flow.state.shop_relics[slot]]
	var drawn: int = RelicDef.TIER_NAMES.find(flow.state.black_market_tier)
	assert_eq(relic.tier, mini(drawn + 1, RelicDef.Tier.LEGENDARY), "one tier up")
	assert_eq(flow.relic_price(slot), flow.act.relic_prices[flow.state.black_market_tier], "at its own tier's price")
	assert_eq(RunState.from_dict(flow.state.to_dict()).black_market_slot, slot, "the save keeps it")
	R.to_magpie(flow)
	assert_eq(flow.state.black_market_slot, -1, "never at the Magpie (Decision 6)")


func test_black_market_s_snowball_and_its_cards() -> void:
	var flow: RunFlow = _apexed("fence", "black_market")
	var hob: RunState.Hero = flow.state.hero("hob")
	R.to_pedlar(flow)
	flow.state.shards = 200
	var price: int = flow.relic_price(0)
	assert_eq(flow.buy_relic(0), "")
	assert_eq(hob.growth[RunContent.apex_growth_key(_run.content.apexes["black_market"])], 1, "a relic bought")
	R.to_pedlar(flow)
	assert_eq(flow.relic_price(0), flow.relic_price(0, true) - 1, "relics 1 cheaper")
	hob.growth[RunContent.apex_growth_key(_run.content.apexes["black_market"])] = 100
	assert_eq(flow.relic_price(0), flow.relic_price(0, true) - flow.relic_price(0, true) / 2, "down to half")
	hob.growth[RunContent.apex_growth_key(_run.content.apexes["black_market"])] = 1
	hob.upgrades.append("volume_discount")
	assert_eq(flow.relic_price(0), flow.relic_price(0, true) - 2, "Volume Discount: 2 a relic")
	assert_eq(flow.reroll_black_market(), "the black-market relic can't be rerolled again in this shop")
	hob.upgrades.append("smugglers_route")
	var before: String = flow.state.shop_relics[flow.state.black_market_slot]
	var shards: int = flow.state.shards
	assert_eq(flow.reroll_black_market(), "")
	assert_eq(flow.state.shards, shards, "free")
	assert_ne(flow.state.shop_relics[flow.state.black_market_slot], before, "a fresh black-market relic")
	assert_eq(flow.reroll_black_market(), "the black-market relic can't be rerolled again in this shop", "once a shop")
	assert_gt(price, 0)


func test_low_bar_counts_from_25() -> void:
	var flow: RunFlow = _apexed("hoarder", "dragons_hoard")
	var hob: RunState.Hero = flow.state.hero("hob")
	var key: String = RunContent.apex_growth_key(_run.content.apexes["dragons_hoard"])
	flow._grow_by_run("won_holding", 1, 27)
	assert_eq(hob.growth.get(key, 0), 0, "27 isn't 30")
	hob.upgrades.append("low_bar")
	assert_eq(_run.holding_threshold(hob), 25)
	flow._grow_by_run("won_holding", 1, 27)
	assert_eq(hob.growth.get(key, 0), 1, "with Low Bar, 25 is enough")
	hob.upgrades.append("deep_vault")
	hob.growth[key] = 4
	assert_eq(_run.apex_count(hob, _run.content.apexes["dragons_hoard"]), 6, "Deep Vault: half again")
	var mods: Array[KitMod] = _run.relic_mods(flow.state).filter(func(mod: KitMod) -> bool: return mod.stats_bp.size() > 0 and mod.stats_bp[UnitStats.Stat.MGK] == 10600)
	assert_eq(mods.size(), 1, "+1% ATK, MGK, and max HP to every hero for each")


func test_manhunter_s_snowball_counts_bounties_in_fights() -> void:
	var flow: RunFlow = _apexed("bounty_hunter", "manhunter")
	var hob: RunState.Hero = flow.state.hero("hob")
	var key: String = RunContent.apex_growth_key(_run.content.apexes["manhunter"])
	assert_true(_run.growth_tallies(flow.state, hob)[0].has(key), "the fight tallies it")
	flow.choose_fight(0)
	var result: FightResult = _won(flow)
	result.tallies.append(FightResult.Deed.make("hob", key, 3))
	flow.record(HeroTeam.place(_run.content, ["brannoc", "maren", "hob"] as Array[String], HeroTeam.GUARDED), result)
	assert_eq(hob.growth[key], 3, "3 Bounties collected")
	var mods: Array[KitMod] = _run.relic_mods(flow.state).filter(func(mod: KitMod) -> bool: return mod.passives.any(func(part: PartDef) -> bool: return part.id == "manhunter_trophies"))
	assert_eq(mods.size(), 1, "the team's")
	assert_eq(mods[0].passives[0].aura.value, 10300, "+1% against Bounties for each")
	hob.upgrades.append("hunting_party")
	assert_eq(_run.apex_count(hob, _run.content.apexes["manhunter"]), 6, "Hunting Party: twice")


func test_black_market_s_taste_and_fence_s_rules_carrying_on() -> void:
	var flow: RunFlow = _apexed("fence", "black_market")
	var hob: RunState.Hero = flow.state.hero("hob")
	hob.apex_earned = false
	R.to_pedlar(flow)
	assert_eq(flow.relic_price(0), maxi(flow.relic_price(0, true) - 2, 0), "vowed: the first relic bought 2 less")
	flow.state.shop_relics_bought = 1
	assert_eq(flow.relic_price(0), flow.relic_price(0, true), "the next at its price")
	hob.apex_earned = true
	var rules: ShopRulesDef = _run.shop_rules(hob)
	assert_eq([rules.reroll_less_bp, rules.sell_less_bp], [5000, 2500], "the apex keeps Fence's rerolls and sell-back")


func test_snowball_cards_reach_only_their_own_layer() -> void:
	var flow: RunFlow = _apexed("fence", "black_market")
	var hob: RunState.Hero = flow.state.hero("hob")
	var apex: ApexDef = _run.content.apexes["black_market"]
	hob.growth[RunContent.apex_growth_key(apex)] = 4
	hob.upgrades.append("big_spender")
	assert_eq(_run.apex_count(hob, apex), 4, "Big Spender is the path's snowball's, not the apex's")


func test_low_bar_changes_something() -> void:
	var kit: UnitDef = _run.content.apexes["dragons_hoard"].kit(PathDef.Stage.APEX)
	assert_true(_run.changes_something(_run.upgrades["low_bar"], true, kit), "a lower bar is offered though it has no mod")


func test_a_relic_counting_won_holding_counts_from_30() -> void:
	var errors: Array[String] = []
	var relic: RelicDef = RelicDef.read(DataReader.new({"id": "stand_in_hoard", "name": "S", "icon": "x", "flavor": "f", "text": "t", "tier": "common",
		"grows": {"run_counts": "won_holding", "per": 1, "each": {"stats_bp": {"atk": 10100}}}}, "relic", errors))
	assert_eq(errors, [] as Array[String])
	_run.relics["stand_in_hoard"] = relic
	var flow: RunFlow = _start("hoarder")
	flow.state.relics.append("stand_in_hoard")
	flow._grow_by_run("won_holding", 1, 27)
	assert_eq(flow.state.growth.get("stand_in_hoard", 0), 0, "27 held isn't 30")
	flow._grow_by_run("won_holding", 1, 30)
	assert_eq(flow.state.growth.get("stand_in_hoard", 0), 1, "won holding 30")
	_run.relics.erase("stand_in_hoard")
