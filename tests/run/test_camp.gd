extends GutTest
## Camp, relics, and duo bonds in a run (docs/plans/rebuild-phase5-run.md,
## sections 8 and 9): places and their options, each option's one job, the
## next fight's modifiers, relic choices and relics' rules, and bonds.

const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start(run_seed: int = 7, vows: Dictionary[String, String] = {}) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, vows if not vows.is_empty() else Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


## A flow at camp with `option` offered first (camp's options set by hand).
func _camp_with(option: String, run_seed: int = 7) -> RunFlow:
	var flow: RunFlow = _start(run_seed)
	flow.state.camp.assign([option])
	return flow


func _result(outcome: FightResult.Outcome) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	result.end_tick = 600
	return result


func _to_fight(flow: RunFlow) -> void:
	if flow.state.phase == RunState.Phase.CAMP:
		assert_eq(flow.leave_camp(), "")
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
	assert_eq([_run.relic_ids.size(), _run.bond_ids.size()], [8, 3])


func test_arriving_at_camp() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	var place: CampsDef.Place = _run.camps.places.filter(func(found: CampsDef.Place) -> bool: return found.id == state.place)[0]
	assert_eq(state.camp.size(), _run.camps.shown)
	for option: String in state.camp:
		assert_has(place.options, option)
	assert_eq(state.camp, _start().state.camp, "the same seed, the same camp")
	assert_between(state.magpie_day, 3, 6)
	# The act map draws a past day's place again (phase 5b).
	assert_eq(Offers.place(_run, state.seed_value, state.act, state.day, state.attempt, state.magpie_day), state.place)
	for day: int in range(2, 7):
		state.day = day
		for attempt: int in 2:
			state.attempt = attempt
			var drawn: Array = Offers.camp(_run, state)
			var expected: String = "magpie" if day == state.magpie_day and attempt == 0 else String(drawn[0])
			assert_eq(Offers.place(_run, state.seed_value, state.act, day, attempt, state.magpie_day), expected, "day %d, try %d" % [day, attempt])


func test_the_magpies_day() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.day = state.magpie_day - 1
	state.phase = RunState.Phase.AFTER
	assert_eq(flow.finish_day(), "")
	assert_eq([state.place, state.camp], ["", ["magpie"] as Array[String]], "he's the only option")
	assert_eq(flow.choose_camp(0), "")
	assert_eq(state.shop, "magpie")
	assert_ne(state.shop_relic, "", "the Magpie always has a relic")
	assert_eq(flow.relic_price(), 14, "9 shards, half again, rounded up")


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
	assert_eq(flow.leave_camp(), "choose an upgrade or take the shards first")
	flow.take_pick(0)
	assert_eq(flow.leave_camp(), "")


func test_rest_clears_wounds() -> void:
	var flow: RunFlow = _camp_with("rest")
	flow.state.hero("vell").wounds = 3
	flow.state.hero("maren").wounds = 1
	flow.choose_camp(0)
	assert_true(flow.state.heroes.all(func(hero: RunState.Hero) -> bool: return hero.wounds == 0))
	assert_false(flow.state.rested, "no relic to steady them")


func test_map_the_rift_swaps_one_of_tomorrows_fights() -> void:
	var flow: RunFlow = _camp_with("map_the_rift")
	var tomorrow: Array = flow.state.options[1].duplicate()
	assert_eq(flow.swap_fight(0), "Map the Rift isn't waiting")
	flow.choose_camp(0)
	assert_eq(flow.leave_camp(), "choose which fight to swap first")
	assert_eq(flow.swap_fight(1), "")
	var now: Array = flow.state.options[1]
	assert_eq(now[0], tomorrow[0])
	assert_ne(now[1], tomorrow[1])
	assert_eq(_run.content.encounters[now[1]].tier, _run.content.encounters[tomorrow[1]].tier, "the same tier")
	assert_true(_run.content.encounters[now[1]].days.has(2))
	assert_eq(flow.leave_camp(), "")


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
	assert_false(flow.state.fortify, "spent, win or lose")


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
	var flow: RunFlow = _camp_with("rift_tear")
	flow.choose_camp(0)
	_to_fight(flow)
	assert_true(_setup(flow).enemies.all(func(enemy: UnitSetup) -> bool: return _has_passive(enemy.def, "rift_warded")))
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	var state: RunState = flow.state
	assert_eq(state.relic_choice.size(), 2)
	flow.take_shards()
	assert_eq(flow.finish_day(), "choose a relic or neither first")
	assert_eq(flow.take_relic(2), "there's no relic 2")
	var chosen: String = state.relic_choice[1]
	assert_eq(flow.take_relic(1), "")
	assert_eq(state.relics, [chosen] as Array[String])
	assert_eq(flow.finish_day(), "")
	assert_false(state.rift_tear)


func test_the_shrine_and_turning_a_relic_down() -> void:
	var flow: RunFlow = _camp_with("shrine")
	flow.choose_camp(0)
	assert_eq(flow.state.relic_choice.size(), 2)
	assert_eq(flow.leave_camp(), "choose a relic or neither first")
	assert_eq(flow.decline_relic(), "")
	assert_eq(flow.state.relics, [] as Array[String])
	assert_eq(flow.decline_relic(), "there's no relic choice waiting")


func test_a_hunt() -> void:
	var flow: RunFlow = _camp_with("hunt")
	flow.choose_camp(0)
	var state: RunState = flow.state
	assert_eq(_run.content.encounters[state.hunt].tier, "hunt")
	assert_eq(flow.fight_encounter(), state.hunt)
	assert_eq(flow.leave_camp(), "fight the Hunt first")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(setup.enemies.size(), _run.content.encounters[state.hunt].enemies.size())
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq([state.hunt, state.losses, state.phase, state.shards], ["", 0, RunState.Phase.CAMP, 3], "a lost Hunt isn't a loss")
	assert_eq(_run.content.encounters[state.fought.back().encounter].tier, "hunt", "recorded as fought")
	flow.state.camp_used = ""
	flow.choose_camp(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq([state.shards, state.pick], [3 + _run.act.pay["hunt"], [] as Array[String]], "shards, no pick")
	assert_eq(flow.leave_camp(), "")


func test_relics_that_change_the_run() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.relic_choice.assign(["hollow_crown"])
	flow.take_relic(0)
	assert_eq(state.hero("maren").slots.size(), 4, "a fourth slot")
	state.hero("maren").wounds = 1
	state.relic_choice.assign(["rift_glass_eye"])
	flow.take_relic(0)
	_to_fight(flow)
	var setup: FightSetup = _setup(flow)
	assert_eq(setup.heroes[1].max_hp_bp, 8000, "a wound takes 20%")
	var enemy: UnitSetup = setup.enemies[0]
	var plain: UnitDef = Encounters.scaled(_run.content.enemies[enemy.def.id].kit, _run.content.encounters[state.chosen].scale_bp)
	assert_eq(enemy.def.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(plain.stats.get_stat(UnitStats.Stat.HP), 11000))


func test_relics_on_pay_picks_and_prices() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.relic_choice.assign(["gravediggers_coin"])
	flow.take_relic(0)
	state.relic_choice.assign(["pilgrims_lantern"])
	flow.take_relic(0)
	flow.open_shop("pedlar")
	assert_eq(flow.price_of("whetstone"), 4, "the Pedlar charges 1 more")
	flow.close_shop()
	state.camp.assign(["rest"])
	flow.choose_camp(0)
	assert_true(state.rested)
	_to_fight(flow)
	var setup: FightSetup = _setup(flow)
	var kit: UnitDef = _run.content.paths["hearthwall"].vowed_kit
	assert_eq(setup.heroes[0].def.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(kit.stats.get_stat(UnitStats.Stat.HP), 11000), "steadied by the Rest")
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq(state.shards, 3 + _run.act.pay[_run.content.encounters[state.chosen].tier] + 2)
	assert_eq(state.pick.size(), 2, "only 2 cards")
	assert_false(state.rested)


func test_a_team_relic_changes_every_hero() -> void:
	var flow: RunFlow = _start()
	flow.state.relic_choice.assign(["bloodstone"])
	flow.take_relic(0)
	_to_fight(flow)
	var setup: FightSetup = _setup(flow)
	for i: int in 3:
		var hero: RunState.Hero = flow.state.heroes[i]
		var kit: UnitDef = _run.content.paths[hero.path].vowed_kit
		assert_eq(setup.heroes[i].def.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(kit.stats.get_stat(UnitStats.Stat.ATK), 11200))


func test_the_pedlar_sometimes_has_a_relic() -> void:
	var found: int = 0
	for run_seed: int in range(1, 31):
		var flow: RunFlow = _start(run_seed)
		flow.open_shop("pedlar")
		if flow.state.shop_relic.is_empty():
			assert_eq(flow.buy_relic(), "there's no relic for sale")
			continue
		found += 1
		flow.state.shards = 9
		var relic: String = flow.state.shop_relic
		assert_eq(flow.buy_relic(), "")
		assert_eq([flow.state.relics, flow.state.shards, flow.state.shop_relic], [[relic], 0, ""])
	assert_between(found, 3, 20, "about 1 visit in 3 (%d of 30)" % found)


func test_a_duo_bond_stirs_then_switches_on() -> void:
	var vows: Dictionary[String, String] = {"brannoc": "hearthwall", "maren": "deadeye", "vell": "lanternbearer"}
	var flow: RunFlow = _start(7, vows)
	var state: RunState = flow.state
	assert_eq(_run.stirring_bonds(state).map(func(bond: BondDef) -> String: return bond.id), ["sentry_and_sniper"])
	assert_eq(_run.active_bonds(state), [] as Array[BondDef])
	state.hero("brannoc").transformed = true
	_to_fight(flow)
	assert_false(_has_passive(_setup(flow).heroes[1].def, "sentry_sight"), "not until both transform")
	var deed := FightResult.Deed.make("maren", "deadeye", 99999)
	var result: FightResult = _result(FightResult.Outcome.VICTORY)
	result.deeds = [deed] as Array[FightResult.Deed]
	flow.record(Bot.formation(), result)
	assert_eq(state.bonds_found, ["sentry_and_sniper"] as Array[String], "found as it switches on")
	assert_eq(_run.stirring_bonds(state), [] as Array[BondDef])
	flow.take_shards()
	flow.finish_day()
	_to_fight(flow)
	var setup: FightSetup = _setup(flow)
	assert_true(_has_passive(setup.heroes[1].def, "sentry_sight"))
	assert_eq(setup.heroes[0].def.mana.per_attack, _run.content.paths["hearthwall"].transformed_kit.mana.per_attack + 2)


func test_the_bot_plays_camps_to_the_end() -> void:
	for run_seed: int in range(1, 9):
		var errors: Array[String] = []
		var flow: RunFlow = Bot.play(_run, run_seed, errors)
		assert_eq(errors, [] as Array[String], "seed %d" % run_seed)
		assert_eq(flow.state.phase, RunState.Phase.ENDED)
