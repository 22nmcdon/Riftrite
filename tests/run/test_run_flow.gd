extends GutTest
## The day structure (docs/plans/day-structure.md): the run start, the
## Caravan, stops, fights, rewards, losing, and the run bot.

const K = preload("res://tests/sim/sim_test_kit.gd")

static var _run_content: RunContent


func _content() -> ContentDb:
	return K.content()


func _run() -> RunContent:
	if _run_content == null:
		_run_content = RunContent.load_dir("res://data", _content())
		assert(_run_content.is_valid(), str(_run_content.errors))
	return _run_content


## A run past the start (first hero, gold package), at day 1's Caravan.
func _started(run_seed: int = 5) -> RunState:
	var state: RunState = RunFlow.new_run(run_seed, _content())
	assert_true(RunFlow.pick_start_hero(state, _content(), 0).ok)
	assert_true(RunFlow.pick_package(state, _content(), _run(), 0).ok)
	return state


func _refused(result: RunActions.Result, expected: String) -> void:
	assert_false(result.ok)
	assert_string_contains(result.error, expected)


## Makes the guild overwhelming: its first hero at S with a strong row.
func _make_strong(state: RunState) -> void:
	var hero: RunHero = state.heroes[0]
	hero.rank = 3
	hero.needs_specialization = false
	hero.items.clear()
	for item_id: String in ["hearthstone_ward", "first_light_dagger", "hearth_knife"]:
		var item: RunItem = RunItem.make(state.take_uid(), item_id, 3)
		hero.items.append(item)


## Walks from the Caravan to the fight (leaving the Caravan, first stop).
func _to_fight(state: RunState) -> void:
	assert_true(RunFlow.leave_caravan(state, _content(), _run()).ok)
	if state.phase == "stop_choice":
		assert_true(RunFlow.pick_stop(state, _content(), _run(), 0).ok)
	assert_true(RunFlow.leave_stop(state).ok)


# --- the run start ------------------------------------------------------------

func test_a_run_starts_with_one_of_three_heroes_and_a_package() -> void:
	var state: RunState = RunFlow.new_run(5, _content())
	assert_eq(state.phase, "start_hero")
	assert_eq(state.offers.size(), 3)
	var heroes: Array[String] = []
	for offer: Dictionary in state.offers:
		heroes.append(offer["hero"])
	assert_eq(heroes.size(), 3)
	assert_ne(heroes[0], heroes[1])
	_refused(RunFlow.buy(state, _content(), 0), "that isn't possible now (the run is at start_hero)")
	assert_true(RunFlow.pick_start_hero(state, _content(), 1).ok)
	assert_eq(state.heroes[0].hero_id, heroes[1])
	var packages: Array[String] = []
	for offer: Dictionary in state.offers:
		packages.append(offer["package"])
	assert_eq(packages, ["gold", "relic", "item"] as Array[String])
	assert_eq(_content().relics[state.offers[1]["relic"]].rarity, "common")
	assert_eq(_content().items[state.offers[2]["item"]].rarity, "common")
	assert_true(RunFlow.pick_package(state, _content(), _run(), 0).ok)
	assert_eq(state.gold, 18, "base 10 + the gold package's 8")
	assert_eq([state.phase, state.day, state.encounter_id], ["caravan", 1, "pup_litter"])


func test_the_same_seed_gives_the_same_start() -> void:
	var one: RunState = _started(9)
	var two: RunState = _started(9)
	assert_eq(JSON.stringify(one.to_dict()), JSON.stringify(two.to_dict()))


# --- the Caravan ----------------------------------------------------------------

func test_caravan_offers_follow_the_rules() -> void:
	var state: RunState = _started()
	var items: int = 0
	for offer: Dictionary in state.offers:
		if offer["type"] == "item":
			items += 1
			var def: ItemDef = _content().items[offer["item"]]
			assert_false(def.enemy_only, "never enemy-only")
			assert_eq(offer["price"], _run().economy.item_price[offer["tier"]])
			assert_lt(offer["tier"], 2, "Act 1: C or B only")
		else:
			assert_eq(offer["type"], "hero")
	assert_eq(items, 5)


func test_caravan_never_offers_enemy_only_items() -> void:
	var state: RunState = _started()
	for reroll: int in 40:
		state.reroll_count = reroll
		RunFlow._fill_caravan(state, _content(), _run())
		for offer: Dictionary in state.offers:
			if offer["type"] == "item":
				assert_false(_content().items[offer["item"]].enemy_only, "%s is enemy-only" % offer["item"])


func test_caravan_offers_held_items_at_the_held_tier() -> void:
	var state: RunState = _started()
	for item_id: String in _content().item_ids:
		if not _content().items[item_id].enemy_only:
			state.stash.clear()
			state.stash.append(RunItem.make(state.take_uid(), item_id, 1))
			for reroll: int in 3:
				state.reroll_count = reroll
				RunFlow._fill_caravan(state, _content(), _run())
				for offer: Dictionary in state.offers:
					if offer.get("item", "") == item_id:
						assert_eq(offer["tier"], 1, "%s is held at B" % item_id)


func test_buying_selling_and_rerolling() -> void:
	var state: RunState = _started()
	var index: int = -1
	for i: int in state.offers.size():
		if state.offers[i]["type"] == "item":
			index = i
			break
	var price: int = state.offers[index]["price"]
	assert_true(RunFlow.buy(state, _content(), index).ok)
	assert_eq([state.gold, state.stash.size()], [18 - price, 1])
	_refused(RunFlow.buy(state, _content(), index), "already taken")
	var uid: int = state.stash[0].uid
	assert_true(RunFlow.sell(state, _content(), _run(), uid).ok)
	assert_eq(state.gold, 18 - price + price / 2, "sold for half, rounded down")
	var before: Array[Dictionary] = state.offers.duplicate(true)
	var gold: int = state.gold
	assert_true(RunFlow.reroll(state, _content(), _run()).ok)
	assert_true(RunFlow.reroll(state, _content(), _run()).ok)
	assert_eq(state.gold, gold - 1 - 2, "rerolls cost 1, then 2")
	assert_ne(JSON.stringify(state.offers), JSON.stringify(before))
	state.gold = 0
	_refused(RunFlow.reroll(state, _content(), _run()), "not enough gold")


func test_buying_needs_gold_and_room() -> void:
	var state: RunState = _started()
	var index: int = 0
	while state.offers[index]["type"] != "item":
		index += 1
	state.gold = 0
	_refused(RunFlow.buy(state, _content(), index), "not enough gold")
	state.gold = 100
	for i: int in _content().tuning.stash_slots:
		state.stash.append(RunItem.make(state.take_uid(), "hearth_knife"))
	var before: String = JSON.stringify(state.to_dict())
	_refused(RunFlow.buy(state, _content(), index), "the stash has no room")
	assert_eq(JSON.stringify(state.to_dict()), before, "a refused purchase changes nothing")


func test_full_roster_only_offers_copies() -> void:
	var state: RunState = _started()
	for hero_id: String in _content().hero_ids:
		if state.hero(hero_id) == null:
			state.heroes.append(RunHero.make(hero_id))
	for i: int in 2:
		state.heroes.append(RunHero.make("x%d" % i))
	assert_eq(state.heroes.size(), FightSetup.ROSTER_CAP)
	RunFlow._fill_caravan(state, _content(), _run())
	for offer: Dictionary in state.offers:
		if offer["type"] == "hero":
			assert_not_null(state.hero(offer["hero"]), "only heroes already held (they combine)")
			assert_eq(offer["rank"], state.hero(offer["hero"]).rank, "at the held rank")


# --- stops ----------------------------------------------------------------------

func test_stops_are_offered_only_when_they_apply() -> void:
	var state: RunState = _started()
	assert_true(RunFlow.leave_caravan(state, _content(), _run()).ok)
	assert_eq(state.phase, "stop_choice")
	var stops: Array[String] = []
	for offer: Dictionary in state.offers:
		stops.append(offer["stop"])
	assert_eq(stops.size(), 2, "only Loot and Event apply on day 1")
	for stop: String in ["forge", "vault", "retrain"]:
		assert_false(stops.has(stop), "%s needs an infusion, a key, or a specialization" % stop)
	assert_false(stops.has("upgrade"), "the Upgrade stop is only before the boss")


func test_forge_reforge_and_retrain_need_their_stops() -> void:
	var state: RunState = _started()
	state.stash.append(RunItem.make(state.take_uid(), "hearth_knife"))
	state.stash[0].essence_ids = ["ember"] as Array[String]
	state.gold = 10
	_refused(RunFlow.forge_reforge(state, _content(), state.stash[0].uid), "reforging needs the Forge")
	RunFlow._enter_stop(state, _content(), _run(), "forge")
	assert_true(RunFlow.forge_reforge(state, _content(), state.stash[0].uid).ok)
	var hero: RunHero = state.heroes[0]
	hero.rank = 1
	var specs: Array[String] = []
	for spec_id: String in _content().specialization_ids:
		if _content().specializations[spec_id].hero == hero.hero_id:
			specs.append(spec_id)
	hero.specialization_id = specs[0]
	_refused(RunFlow.retrain(state, _content(), hero.hero_id, specs[1]), "retraining needs a Retrain stop")
	RunFlow._enter_stop(state, _content(), _run(), "retrain")
	_refused(RunFlow.retrain(state, _content(), hero.hero_id, specs[0]), "already their specialization")
	assert_true(RunFlow.retrain(state, _content(), hero.hero_id, specs[1]).ok)
	assert_eq(hero.specialization_id, specs[1])
	_refused(RunFlow.retrain(state, _content(), hero.hero_id, specs[2]), "used")


func test_vault_spends_a_key() -> void:
	var state: RunState = _started()
	state.keys = 1
	RunFlow._enter_stop(state, _content(), _run(), "vault")
	assert_eq(state.keys, 0)
	assert_eq(state.offers.size(), 1)
	assert_true(["item", "relic"].has(state.offers[0]["type"]))


func test_loot_and_events_can_be_taken_or_passed() -> void:
	for day: int in range(1, 8):
		var state: RunState = _started(day)
		state.day = day
		RunFlow._enter_stop(state, _content(), _run(), "loot")
		assert_eq(state.offers.size(), 1)
		var before_gold: int = state.gold
		var result: RunActions.Result = RunFlow.take(state, _content(), 0)
		assert_true(result.ok, result.error)
		assert_true(state.offers[0]["taken"])
		if state.offers[0]["type"] == "gold":
			assert_eq(state.gold, before_gold + _run().economy.loot_gold)
		RunFlow._enter_stop(state, _content(), _run(), "event")
		assert_gt(state.offers.size(), 0)
		assert_true(_run().events.has(state.offers[0]["event"]))
		assert_true(RunFlow.leave_stop(state).ok, "passing is just leaving")


func test_relic_merchant_sells_one() -> void:
	var state: RunState = _started()
	state.gold = 100
	state.offers.clear()
	RunFlow._add_relic_offers(state, _content(), SimRng.new(3), _run().economy.relic_weights, 3, "merchant", -1, _run().economy)
	state.phase = "stop"
	assert_eq(state.offers.size(), 3)
	var price: int = state.offers[1]["price"]
	assert_eq(price, _run().economy.relic_price[ItemDef.RARITIES.find(_content().relics[state.offers[1]["relic"]].rarity)])
	assert_true(RunFlow.take(state, _content(), 1).ok)
	assert_eq(state.gold, 100 - price)
	_refused(RunFlow.take(state, _content(), 0), "already taken")


func test_the_upgrade_stop_comes_before_the_boss() -> void:
	var state: RunState = _started()
	state.day = 6
	RunFlow._start_day(state, _content(), _run())
	assert_eq(state.encounter_id, "the_ash_mother")
	assert_true(RunFlow.leave_caravan(state, _content(), _run()).ok)
	assert_eq([state.phase, state.stop_kind], ["stop", "upgrade"])
	var claw: RunItem = RunItem.make(state.take_uid(), "rift_claw", 0)
	state.stash.append(claw)
	var top: RunItem = RunItem.make(state.take_uid(), "hearth_knife", 3)
	state.stash.append(top)
	_refused(RunFlow.upgrade(state, _content(), top.uid), "already S")
	assert_true(RunFlow.upgrade(state, _content(), claw.uid).ok, "enemy-only items too")
	assert_eq(claw.tier, 1)
	_refused(RunFlow.upgrade(state, _content(), claw.uid), "used")


# --- fights, rewards, losing ----------------------------------------------------

func test_a_normal_win_gives_gold_a_shard_and_a_drop() -> void:
	var state: RunState = _started()
	_make_strong(state)
	_to_fight(state)
	var gold: int = state.gold
	var fought: Array = RunFlow.fight(state, _content(), _run())
	assert_true((fought[0] as RunActions.Result).ok)
	assert_true((fought[1] as FightResult).guild_won())
	assert_eq(state.phase, "rewards")
	assert_eq(state.gold, gold + 5 + 1, "5 + the day number")
	assert_eq(state.shards.get("wrath", 0), 1, "pups yield Wrath")
	assert_eq(state.offers.size(), 1, "the guaranteed drop")
	assert_eq(state.offers[0]["item"], "rift_claw", "enemy-only items drop too")
	assert_true(RunFlow.done(state, _content(), _run()).ok)
	assert_eq([state.day, state.phase], [2, "caravan"])


func test_three_shards_make_an_essence() -> void:
	var state: RunState = _started()
	state.shards["frost"] = 5
	RunFlow._convert_shards(state, _content(), _run())
	assert_eq([state.pouch, state.shards["frost"]], [["frost"] as Array[String], 2])
	for i: int in _content().tuning.pouch_cap - 1:
		state.pouch.append("ember")
	state.shards["frost"] = 3
	RunFlow._convert_shards(state, _content(), _run())
	assert_eq(state.shards["frost"], 3, "they wait while the pouch is full")


func test_an_elite_win_gives_an_essence_and_a_relic_choice() -> void:
	var state: RunState = _started()
	_make_army(state)
	state.day = 3
	RunFlow._start_day(state, _content(), _run())
	assert_eq(state.encounter_id, "hound_alpha")
	_to_fight(state)
	var fought: Array = RunFlow.fight(state, _content(), _run())
	assert_true((fought[1] as FightResult).guild_won())
	var types: Array[String] = []
	for offer: Dictionary in state.offers:
		types.append(offer["type"])
	assert_eq(types.slice(0, 1), ["essence"] as Array[String], "a whole essence")
	var relics: Array[int] = []
	for i: int in state.offers.size():
		if state.offers[i].get("group", "") == "relic_choice":
			relics.append(i)
	assert_eq(relics.size(), 3)
	assert_true(RunFlow.take(state, _content(), relics[1]).ok)
	assert_eq(state.relics.size(), 1)
	_refused(RunFlow.take(state, _content(), relics[0]), "already taken")


func test_the_first_loss_replays_the_day_and_the_second_ends_the_run() -> void:
	var state: RunState = _started()
	state.day = 6
	RunFlow._start_day(state, _content(), _run())
	var caravan_before: String = JSON.stringify(state.offers)
	_to_fight(state)
	var gold: int = state.gold
	var fought: Array = RunFlow.fight(state, _content(), _run())
	assert_false((fought[1] as FightResult).guild_won(), "one C hero against the boss")
	assert_eq([state.phase, state.day, state.attempt, state.losses, state.encounter_id], ["caravan", 6, 1, 1, "the_ash_mother"])
	assert_eq(state.gold, gold + 10, "bonus gold: 10 + 5 per win (none yet)")
	assert_ne(JSON.stringify(state.offers), caravan_before, "a fresh Caravan")
	_to_fight(state)
	RunFlow.fight(state, _content(), _run())
	assert_eq(state.phase, "run_over")
	_refused(RunFlow.leave_caravan(state, _content(), _run()), "run_over")


## The whole roster at S, each with a specialization and a strong row.
func _make_army(state: RunState) -> void:
	_make_strong(state)
	for hero_id: String in ["wren", "vell", "odo", "brannoc"]:
		if state.hero(hero_id) == null:
			RunActions.add_hero(state, _content(), hero_id, 3, _first_spec(hero_id))
	for hero: RunHero in state.heroes:
		hero.rank = 3
		if hero.specialization_id.is_empty():
			hero.specialization_id = _first_spec(hero.hero_id)
		hero.needs_specialization = false
		if hero.items.is_empty():
			hero.items.append(RunItem.make(state.take_uid(), "first_light_dagger", 3))


func test_beating_the_boss_ends_the_act() -> void:
	var state: RunState = _started()
	_make_army(state)
	state.day = 6
	RunFlow._start_day(state, _content(), _run())
	_to_fight(state)
	var fought: Array = RunFlow.fight(state, _content(), _run())
	assert_true((fought[1] as FightResult).guild_won())
	var relic_choices: int = 0
	for offer: Dictionary in state.offers:
		if offer.get("group", "") == "relic_choice":
			relic_choices += 1
			assert_eq(_content().relics[offer["relic"]].rarity, "legendary", "boss relics are Legendary")
	assert_eq(relic_choices, 3)
	assert_true(RunFlow.done(state, _content(), _run()).ok)
	assert_eq(state.phase, "act_end")


func _first_spec(hero_id: String) -> String:
	for spec_id: String in _content().specialization_ids:
		if _content().specializations[spec_id].hero == hero_id:
			return spec_id
	return ""


func test_a_fight_needs_specializations_picked() -> void:
	var state: RunState = _started()
	state.heroes[0].rank = 1
	state.heroes[0].needs_specialization = true
	_to_fight(state)
	_refused(RunFlow.fight(state, _content(), _run())[0], "needs a specialization first")


# --- determinism and saving -----------------------------------------------------

func test_a_replayed_day_keeps_its_fight() -> void:
	var seen: Array[String] = []
	for run_seed: int in range(1, 25):
		var state: RunState = _started(run_seed)
		state.day = 4
		RunFlow._start_day(state, _content(), _run())
		var first: String = state.encounter_id
		if not seen.has(first):
			seen.append(first)
		state.attempt = 1
		state.gold += 37
		state.wins += 2
		RunFlow._start_day(state, _content(), _run())
		assert_eq(state.encounter_id, first, "seed %d" % run_seed)
	assert_gt(seen.size(), 1, "day 4 has several possible fights")


func test_offers_dont_depend_on_earlier_picks() -> void:
	var one: RunState = _started(21)
	var two: RunState = _started(21)
	RunFlow.leave_caravan(one, _content(), _run())
	RunFlow.leave_caravan(two, _content(), _run())
	RunFlow.pick_stop(one, _content(), _run(), 0)
	RunFlow.pick_stop(two, _content(), _run(), 1)
	two.gold += 11
	for state: RunState in [one, two]:
		state.day = 2
		RunFlow._start_day(state, _content(), _run())
	assert_eq(one.encounter_id, two.encounter_id, "tomorrow's fight doesn't depend on today's stop")


func test_save_and_load_mid_run_continues_the_same() -> void:
	var state: RunState = _started(13)
	RunFlow.reroll(state, _content(), _run())
	var loaded: Array = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())), _content())
	assert_eq(loaded[1], [] as Array[String])
	var copy: RunState = loaded[0]
	assert_eq(JSON.stringify(copy.to_dict()), JSON.stringify(state.to_dict()))
	for run_state: RunState in [state, copy]:
		RunFlow.buy(run_state, _content(), 0)
		RunFlow.reroll(run_state, _content(), _run())
		_to_fight(run_state)
		RunFlow.fight(run_state, _content(), _run())
	assert_eq(JSON.stringify(copy.to_dict()), JSON.stringify(state.to_dict()))


# --- the bot ------------------------------------------------------------------

func test_the_bot_plays_whole_runs() -> void:
	var reports: Array[RunBot.Report] = []
	for run_seed: int in [1, 2, 3, 4]:
		var report: RunBot.Report = RunBot.play(run_seed, _content(), _run())
		assert_eq(report.errors, [] as Array[String], "seed %d" % run_seed)
		assert_true(["act_end", "run_over"].has(report.ending), "seed %d ended: %s" % [run_seed, report.ending])
		reports.append(report)
	var again: RunBot.Report = RunBot.play(1, _content(), _run())
	assert_eq([again.ending, again.day, again.bought], [reports[0].ending, reports[0].day, reports[0].bought], "same seed, same run")
	var lines: PackedStringArray = RunReport.lines(reports, 1)
	assert_eq(lines[0], "== 4 runs, seeds 1-4 ==")
	assert_true(lines[1].begins_with("Act cleared: "))
