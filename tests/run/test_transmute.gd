extends GutTest
## Transmuting (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## section 5 and Decision 6; Ottilie's Transmuter): once a shop, at the
## Pedlar or the boss shop, a transformed Transmuter turns an item the run
## owns into shards at its full price; Appraise pays more for ranks II and
## III; never at the Magpie, never before she transforms; the count survives
## a save; a Ledger card's Tithe pays with no stage Tithe of hers; Grand
## Transmutation's items into items; and Midas Touch growing with the
## shards a fight collects.

const R = preload("res://tests/run/run_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start() -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, {"brannoc": "hearthwall", "maren": "deadeye", "ottilie": "transmuter"} as Dictionary[String, String], errors)
	assert_eq(errors, [] as Array[String])
	return flow


func _own(flow: RunFlow, item_id: String, rank: int = 1) -> void:
	flow.state.stash.append(item_id)
	flow.state.item_ranks[item_id] = rank
	flow.state.item_counts[item_id] = 0


func test_only_a_transformed_transmuter_transmutes() -> void:
	var flow: RunFlow = _start()
	_own(flow, "echo")
	R.to_pedlar(flow)
	assert_eq(flow.transmutes_left(), 0, "vowed, she can't yet")
	assert_ne(flow.transmute("echo"), "")
	flow.state.hero("ottilie").transformed = true
	assert_eq(flow.transmutes_left(), 1)
	var shards: int = flow.state.shards
	var price: int = flow.act.item_prices[ItemDef.KIND_NAMES[_run.items["echo"].kind]]
	assert_eq(flow.transmute_price("echo"), price, "its full price, where selling pays half")
	assert_eq(flow.transmute("echo"), "")
	assert_eq([flow.state.shards, flow.state.stash.has("echo"), flow.state.item_ranks.has("echo")], [shards + price, false, false])
	_own(flow, "fleet")
	assert_eq(flow.transmutes_left(), 0, "once a shop")
	assert_eq(flow.transmute("fleet"), "no more transmuting in this shop")
	R.to_pedlar(flow)
	assert_eq(flow.transmutes_left(), 1, "a new shop, a new one")
	R.to_magpie(flow)
	assert_eq(flow.transmutes_left(), 0, "never at the Magpie")


func test_appraise_and_the_save() -> void:
	var flow: RunFlow = _start()
	flow.state.hero("ottilie").transformed = true
	flow.state.hero("ottilie").upgrades.append("appraise")
	_own(flow, "echo", 2)
	_own(flow, "fleet", 3)
	R.to_pedlar(flow)
	var echo: int = flow.act.item_prices[ItemDef.KIND_NAMES[_run.items["echo"].kind]]
	var fleet: int = flow.act.item_prices[ItemDef.KIND_NAMES[_run.items["fleet"].kind]]
	assert_eq([flow.transmute_price("echo"), flow.transmute_price("fleet")], [echo + 2, fleet + 4], "rank II and III pay more")
	assert_eq(flow.transmute("echo"), "")
	var loaded: RunState = RunState.from_dict(flow.state.to_dict())
	assert_eq(loaded.transmutes, 1, "the save keeps the count")


func test_a_ledger_pays_without_a_stage_tithe() -> void:
	var flow: RunFlow = _start()
	var hero: RunState.Hero = flow.state.hero("ottilie")
	hero.transformed = true
	assert_null(_run.tithe(hero), "Transmuter has no Tithe of her own")
	hero.upgrades.append("transmuter_ledger")
	assert_not_null(_run.tithe(hero), "the Ledger's Tithe counts")
	hero.growth["transmuter_ledger"] = 65
	assert_eq(_run.tithe_steps(hero), 2, "1 for every 30 shards from Gilded Death")


func test_grand_transmutation_turns_items_into_items() -> void:
	var flow: RunFlow = _start()
	var hero: RunState.Hero = flow.state.hero("ottilie")
	hero.transformed = true
	hero.apex = "grand_transmutation"
	for apex: ApexDef in _run.content.paths["transmuter"].apexes:
		hero.deeds[apex.id] = 0
	_own(flow, "echo")
	R.to_pedlar(flow)
	assert_eq(flow.transmutes_into_left(), 1, "vowed: once an act")
	assert_eq(flow.transmute_into("echo"), "")
	assert_false(flow.state.item_ranks.has("echo"))
	var made: Array[String] = flow.state.stash.filter(func(id: String) -> bool: return id != "echo")
	assert_eq(made.size(), 1, "a new item in the stash")
	assert_eq(flow.run.items[made[0]].kind, flow.run.items["echo"].kind, "of the same kind")
	assert_eq(flow.state.item_ranks[made[0]], 1)
	assert_eq(hero.deeds.get("grand_transmutation", 0), 1, "its deed counts it")
	assert_eq(flow.transmutes_into_left(), 0, "the act's one is spent")
	assert_eq(flow.transmutes_left(), 1, "the shop's own transmute is still there")
	hero.apex_earned = true
	_own(flow, "fleet")
	R.to_pedlar(flow)
	assert_eq([flow.transmutes_left(), flow.transmutes_into_left()], [2, 2], "at apex: 2 a shop, either way")
	assert_eq(flow.transmute_into("fleet"), "")
	var fresh: Array[String] = flow.state.stash.filter(func(id: String) -> bool: return not made.has(id))
	assert_eq(flow.state.item_ranks[fresh[0]], 2, "arriving at rank II")
	assert_eq(flow.transmutes_left(), 1)


func test_midas_touch_grows_with_the_shards_collected() -> void:
	var flow: RunFlow = _start()
	var hero: RunState.Hero = flow.state.hero("ottilie")
	hero.transformed = true
	hero.apex = "midas_touch"
	hero.apex_earned = true
	var kit: UnitDef = _run.hero_kit(hero)
	assert_eq(kit.shard_cap, 12)
	flow._grow_by_run("shards", 45)
	assert_eq(hero.growth[RunContent.apex_growth_key(_run.content.apexes["midas_touch"])], 45)
	var mods: Array[KitMod] = _run.upgrade_mods(hero)
	var errors: Array[String] = []
	var grown: UnitDef = kit
	for mod: KitMod in mods:
		grown = mod.apply(grown, errors)
	assert_eq(grown.shard_cap, 14, "1 more for every 20 shards")


func test_a_fight_s_shards_grow_midas_touch() -> void:
	var flow: RunFlow = _start()
	var hero: RunState.Hero = flow.state.hero("ottilie")
	hero.transformed = true
	hero.apex = "midas_touch"
	hero.apex_earned = true
	flow.choose_fight(0)
	var result := FightResult.new()
	result.outcome = FightResult.Outcome.VICTORY
	result.end_tick = 600
	for capped: bool in [false, false, false, true]:
		var paid := LogEntry.new()
		paid.kind = LogEntry.Kind.SHARDS
		paid.source_unit = "ottilie"
		paid.source_ability = "gilded_death"
		paid.target = "ottilie"
		paid.amount = 1
		paid.capped = capped
		result.combat_log.add(paid)
	flow.record(HeroTeam.place(_run.content, ["brannoc", "maren", "ottilie"] as Array[String], HeroTeam.GUARDED), result)
	assert_eq(flow.state.fought.back().collected, 3, "the capped shard is paid nothing")
	assert_eq(hero.growth[RunContent.apex_growth_key(_run.content.apexes["midas_touch"])], 3, "and counts nothing")
