extends GutTest
## Camp, relics, and duo bonds in a run (docs/plans/rebuild-phase5-run.md,
## sections 8 and 9): places and their options, each option's one job, the
## next fight's modifiers, relic choices and relics' rules, and bonds. Since
## phase 5c step 8 Camp is a node after the day's shop, and its modifiers are
## for tomorrow's fight.

const Bot = preload("res://tools/run_bot.gd")
const R = preload("res://tests/run/run_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start(run_seed: int = 7, vows: Dictionary[String, String] = {}) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, vows if not vows.is_empty() else Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


## A flow in day 1's Camp node with `option` its one option (set by hand).
func _camp_with(option: String, run_seed: int = 7) -> RunFlow:
	var flow: RunFlow = _start(run_seed)
	R.to_camp(flow, [option] as Array[String])
	return flow


func _result(outcome: FightResult.Outcome) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	result.end_tick = 600
	return result


## On to the next fight: from a node, the next day's; from a shop opened
## by hand, today's.
func _to_fight(flow: RunFlow) -> void:
	if flow.state.phase == RunState.Phase.NODE:
		assert_eq(flow.leave_node(), "")
	elif flow.state.phase == RunState.Phase.SHOP:
		flow.close_shop()
		flow.state.phase = RunState.Phase.ROUTE
	assert_eq(flow.choose_fight(0), "")


func _setup(flow: RunFlow) -> FightSetup:
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	return setup


func _has_passive(kit: UnitDef, id: String) -> bool:
	return kit.passives.any(func(part: PartDef) -> bool: return part.id == id)


func test_the_camp_content_loads() -> void:
	assert_true(_run.is_valid(), "\n".join(_run.errors))
	assert_eq(_run.camps.places.map(func(place: CampsDef.Place) -> String: return place.id), ["waystone", "ruined_chapel", "hunters_blind", "rift_scar"])
	assert_eq(_run.camps.options.size(), CampsDef.OPTIONS.size())
	assert_eq([_run.relic_ids.size(), _run.bond_ids.size()], [94, 8], "89 and the built three bonds, then Garrow's two, Tamsin's Hold and Break, and Aldous's two (phase 8 part 4)")


func test_arriving_at_camp() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	R.to_camp(flow)
	var place: CampsDef.Place = _run.camps.places.filter(func(found: CampsDef.Place) -> bool: return found.id == state.place)[0]
	assert_eq(state.camp.size(), _run.camps.shown)
	for option: String in state.camp:
		assert_has(place.options, option)
		assert_false(["pedlar", "magpie", "rift_tear"].has(option), "the shop and the other nodes aren't camp's options (phase 5c step 8)")
	var twin: RunFlow = _start()
	R.to_camp(twin)
	assert_eq([state.place, state.camp], [twin.state.place, twin.state.camp], "the same seed, the same camp")
	assert_eq(flow.leave_node(), "")
	assert_eq(state.taken_nodes, ["camp:" + twin.state.place] as Array[String], "the act map draws a past day's place again")
	assert_eq([state.place, state.camp, state.node], ["", [] as Array[String], ""])


func test_the_magpies_node() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	R.to_magpie(flow)
	assert_eq([state.shop, state.magpie_visits], ["magpie", 1])
	assert_eq(state.shop_relics.size(), 1, "the Magpie always has a relic")
	var tier: RelicDef.Tier = _run.relics[state.shop_relics[0]].tier
	assert_true(tier == RelicDef.Tier.EPIC or tier == RelicDef.Tier.LEGENDARY, "an epic or a legendary")
	assert_eq(flow.relic_price(), _run.acts[0].relic_prices[RelicDef.TIER_NAMES[tier]] * 75 / 100, "at 25% off, rounded down")
	assert_eq(flow.choose_camp(0), "can't choose a camp option now (the day is at node)")
	assert_eq(flow.leave_node(), "")
	assert_eq([state.shop, state.taken_nodes], ["", ["magpie"] as Array[String]])


func test_one_option_a_camp() -> void:
	var flow: RunFlow = _camp_with("scout")
	assert_eq(flow.choose_camp(1), "there's no camp option 1")
	assert_eq(flow.choose_camp(0), "")
	assert_eq(flow.choose_camp(0), "camp's option is already taken today (scout)")
	assert_eq(flow.state.scouted, [2, 3] as Array[int], "the next 2 days")


func test_train_gives_a_pick() -> void:
	var flow: RunFlow = _camp_with("train")
	flow.choose_camp(0)
	assert_eq(flow.state.pick.size(), 3)
	assert_eq(flow.leave_node(), "choose an upgrade or take the shards first")
	flow.take_pick(0)
	assert_eq(flow.leave_node(), "")


func test_rest_clears_wounds() -> void:
	var flow: RunFlow = _camp_with("rest")
	flow.state.hero("vell").wounds = 3
	flow.state.hero("maren").wounds = 1
	flow.choose_camp(0)
	assert_true(flow.state.heroes.all(func(hero: RunState.Hero) -> bool: return hero.wounds == 0))


func test_map_the_rift_swaps_one_of_tomorrows_fights() -> void:
	var flow: RunFlow = _camp_with("map_the_rift")
	var tomorrow: Array = flow.state.options[1].duplicate()
	assert_eq(flow.swap_fight(0), "Map the Rift isn't waiting")
	flow.choose_camp(0)
	assert_eq(flow.leave_node(), "choose which fight to swap first")
	assert_eq(flow.swap_fight(1), "")
	var now: Array = flow.state.options[1]
	assert_eq(now[0], tomorrow[0])
	assert_ne(now[1], tomorrow[1])
	assert_eq(_run.content.encounters[now[1]].tier, _run.content.encounters[tomorrow[1]].tier, "the same tier")
	assert_true(_run.content.encounters[now[1]].days.has(2))
	assert_eq(flow.leave_node(), "")


func test_fortify_shields_the_next_fight_only() -> void:
	var flow: RunFlow = _camp_with("fortify")
	flow.choose_camp(0)
	_to_fight(flow)
	var setup: FightSetup = _setup(flow)
	assert_true(setup.heroes.all(func(hero: UnitSetup) -> bool: return _has_passive(hero.def, "fortified")))
	var sim := CombatSim.new(setup, _run.content)
	sim.step()
	sim.step()
	assert_eq(sim.unit_by_id("maren").shield, 40, "a small Shield at the start")
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_true(flow.state.fortify, "held for the replay (phase 5c Decision 42)")
	_to_fight(flow)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_false(flow.state.fortify, "spent once won")


func test_dig_in_places_a_rock() -> void:
	var flow: RunFlow = _camp_with("dig_in")
	assert_eq(flow.place_rock(Vector2i(0, 0)), "Dig In wasn't taken")
	flow.choose_camp(0)
	assert_eq(flow.place_rock(Vector2i(0, 4)), "a rock goes on a hex in your zone")
	assert_eq(flow.place_rock(Vector2i(0, 1)), "")
	_to_fight(flow)
	assert_has(_setup(flow).rocks, Vector2i(0, 1))
	var errors: Array[String] = []
	flow.place_rock(Vector2i(3, 2))
	assert_null(flow.fight_setup(Bot.formation(), errors), "not under a hero")
	assert_false(errors.is_empty())


func test_a_rift_tear_upgrades_the_enemies_and_a_win_offers_a_relic() -> void:
	var flow: RunFlow = _start()
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["camp", "rift_tear"])
	assert_eq(flow.choose_node(1), "")
	assert_eq(flow.choose_depth(0), "", "Shallow (phase 5c step 8b)")
	assert_eq(flow.state.rift_depth, "shallow")
	_to_fight(flow)
	assert_true(_setup(flow).enemies.all(func(enemy: UnitSetup) -> bool: return _has_passive(enemy.def, "rift_warded")))
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	var state: RunState = flow.state
	assert_eq(state.relic_choice.size(), 2)
	assert_true(state.relic_choice.all(func(id: String) -> bool: return _run.relics[id].tier == RelicDef.Tier.RARE), "Shallow: 2 rares")
	flow.take_shards()
	assert_eq(flow.finish_day(), "choose a relic or neither first")
	assert_eq(flow.take_relic(2), "there's no relic 2")
	var chosen: String = state.relic_choice[1]
	assert_eq(flow.take_relic(1), "")
	assert_eq(state.relics, [chosen] as Array[String])
	assert_eq(flow.finish_day(), "")
	assert_eq([state.rift_depth, state.rift_mods], ["", [] as Array[String]])
	assert_eq(R.next_day(flow), "can't move on from the fight now (the day is at shop)")
	flow.leave_shop()
	flow.choose_node(0)
	flow.leave_node()
	assert_eq([state.day, state.taken_nodes[0]], [3, "rift_tear"])


func test_the_shrine_asks_an_offering() -> void:
	var flow: RunFlow = _camp_with("shrine")
	flow.choose_camp(0)
	assert_eq(flow.state.shrine, "open", "an offering first (phase 5c step 8b)")
	assert_eq(flow.state.relic_choice, [] as Array[String])
	assert_eq(flow.leave_node(), "", "and none is needed")


func test_a_hunt() -> void:
	var flow: RunFlow = _camp_with("hunt")
	flow.choose_camp(0)
	var state: RunState = flow.state
	assert_eq(_run.content.encounters[state.hunt].tier, "hunt")
	assert_eq(flow.fight_encounter(), state.hunt)
	assert_eq(flow.leave_node(), "fight the Hunt first")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(setup.enemies.size(), _run.content.encounters[state.hunt].enemies.size())
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq([state.hunt, state.losses, state.phase, state.shards], ["", 0, RunState.Phase.NODE, _run.acts[0].start_shards], "a lost Hunt isn't a loss")
	assert_eq(_run.content.encounters[state.fought.back().encounter].tier, "hunt", "recorded as fought")
	flow.state.camp_used = ""
	flow.choose_camp(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq([state.shards, state.pick], [_run.acts[0].start_shards + _run.acts[0].pay["hunt"], [] as Array[String]], "shards, no pick")
	assert_eq(flow.leave_node(), "")


func test_relics_that_change_the_run() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.relic_choice.assign(["hollow_crown"])
	flow.take_relic(0)
	assert_eq(state.hero("maren").slots.size(), 4, "a fourth slot")
	state.relic_choice.assign(["rift_glass_eye"])
	flow.take_relic(0)
	_to_fight(flow)
	var setup: FightSetup = _setup(flow)
	var enemy: UnitSetup = setup.enemies[0]
	var plain: UnitDef = Encounters.scaled(_run.content.enemies[enemy.def.id].kit, _run.content.encounters[state.chosen].scale_bp)
	assert_eq(enemy.def.stats.get_stat(UnitStats.Stat.HP), plain.stats.get_stat(UnitStats.Stat.HP), "no cost: enemies are as they were")


func test_relics_on_pay_picks_and_prices() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	for id: String in ["gravediggers_coin", "hagglers_charm", "widened_offering", "loose_change"]:
		state.relic_choice.assign([id])
		flow.take_relic(0)
	var before: int = state.shards
	R.to_pedlar(flow)
	assert_eq(state.shards, before + 2, "Loose Change pays as a shop opens")
	assert_eq(flow.price_of("fleet"), 5, "Haggler's Charm: 1 less at the Pedlar")
	_to_fight(flow)
	before = state.shards
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq(state.shards, before + _run.acts[0].pay[_run.content.encounters[state.chosen].tier] + 3, "Gravedigger's Coin: +3 a win")
	assert_eq(state.pick.size(), 4, "Widened Offering: one more card")


func test_a_team_relic_changes_every_hero() -> void:
	var flow: RunFlow = _start()
	flow.state.relic_choice.assign(["bloodstone"])
	flow.take_relic(0)
	_to_fight(flow)
	var setup: FightSetup = _setup(flow)
	for i: int in 3:
		var hero: RunState.Hero = flow.state.heroes[i]
		var kit: UnitDef = _run.content.paths[hero.path].vowed_kit
		assert_eq(setup.heroes[i].def.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(kit.stats.get_stat(UnitStats.Stat.ATK), 10800), "Bloodstone: +8% ATK")


func test_the_pedlar_always_has_a_relic_mostly_common() -> void:
	var tiers: Array[int] = [0, 0, 0, 0, 0]
	for run_seed: int in range(1, 41):
		var flow: RunFlow = _start(run_seed)
		R.to_pedlar(flow)
		assert_eq(flow.state.shop_relics.size(), 1)
		var relic: String = flow.state.shop_relics[0]
		tiers[_run.relics[relic].tier] += 1
		flow.state.shards = 40
		var price: int = flow.relic_price()
		assert_eq(price, _run.acts[0].relic_prices[RelicDef.TIER_NAMES[_run.relics[relic].tier]])
		assert_eq(flow.buy_relic(), "")
		assert_eq([flow.state.relics, flow.state.shards, flow.state.shop_relics], [[relic], 40 - price, [""]])
		assert_eq(flow.buy_relic(), "there's no relic for sale")
	assert_gt(tiers[RelicDef.Tier.COMMON], tiers[RelicDef.Tier.RARE], "mostly common: %s" % [tiers])
	assert_eq(tiers[RelicDef.Tier.LEGENDARY] + tiers[RelicDef.Tier.BOSS], 0, "never a legendary or a boss relic")


func test_a_duo_bond_stirs_then_switches_on() -> void:
	var vows: Dictionary[String, String] = {"brannoc": "hearthwall", "maren": "deadeye", "vell": "lanternbearer"}
	var flow: RunFlow = _start(7, vows)
	var state: RunState = flow.state
	assert_eq(_run.stirring_bonds(state).map(func(bond: BondDef) -> String: return bond.id), ["sentry_and_sniper"])
	assert_eq(_run.active_bonds(state), [] as Array[BondDef])
	state.hero("brannoc").transformed = true
	_to_fight(flow)
	assert_eq(_run.bond_relics(state), [] as Array[String], "not until both transform")
	var deed := FightResult.Deed.make("maren", "deadeye", 99999)
	var result: FightResult = _result(FightResult.Outcome.VICTORY)
	result.deeds = [deed] as Array[FightResult.Deed]
	flow.record(Bot.formation(), result)
	assert_eq(state.bonds_found, ["sentry_and_sniper"] as Array[String], "found as it switches on")
	assert_eq(_run.stirring_bonds(state), [] as Array[BondDef])
	assert_eq(_run.bond_relics(state), ["the_watchtower_stone"] as Array[String], "its relic can show up in shops now")
	flow.take_shards()
	assert_eq(R.next_day(flow), "")
	_to_fight(flow)
	var setup: FightSetup = _setup(flow)
	assert_eq(setup.heroes[0].def.mana.per_attack, _run.content.paths["hearthwall"].transformed_kit.mana.per_attack, "a bond gives no boost of its own (phase 5c step 5d)")


func test_the_bot_plays_camps_to_the_end() -> void:
	for run_seed: int in range(1, 9):
		var errors: Array[String] = []
		var flow: RunFlow = Bot.play(_run, run_seed, errors)
		assert_eq(errors, [] as Array[String], "seed %d" % run_seed)
		assert_eq(flow.state.phase, RunState.Phase.ENDED)
