extends GutTest
## The day structure (docs/plans/day-structure.md, docs/plans/new-day.md):
## the run start, the day's stops and shops, the fight pick, rewards, losing,
## and the run bot.

const K = preload("res://tests/sim/sim_test_kit.gd")

static var _run_content: RunContent


func _content() -> ContentDb:
	return K.content()


func _run() -> RunContent:
	if _run_content == null:
		_run_content = RunContent.load_dir("res://data", _content())
		assert(_run_content.is_valid(), str(_run_content.errors))
	return _run_content


## A run whose team is drafted (the first offer each time), at the
## starting package.
func _drafted(run_seed: int) -> RunState:
	var state: RunState = RunFlow.new_run(run_seed, _content())
	for pick: int in RunState.TEAM_SIZE:
		assert_true(RunFlow.pick_start_hero(state, _content(), _run(), 0).ok)
	assert_eq(state.phase, "start_package")
	return state


## A run past the start (the first offer of each draft pick, gold package),
## at day 1's first stop choice.
func _started(run_seed: int = 5) -> RunState:
	var state: RunState = RunFlow.new_run(run_seed, _content())
	for pick: int in RunState.TEAM_SIZE:
		assert_true(RunFlow.pick_start_hero(state, _content(), _run(), 0).ok)
	assert_true(RunFlow.pick_package(state, _content(), _run(), 0).ok)
	return state


## A run at day 1's first stop, which is a shop: `node_id` (the Caravan by
## default).
func _at_shop(node_id: String = "caravan", run_seed: int = 5) -> RunState:
	var state: RunState = _started(run_seed)
	RunFlow._enter_stop(state, _content(), _run(), node_id)
	assert_eq([state.phase, state.stop_kind, state.stop_node], ["stop", "shop", node_id])
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
	for item_id: String in ["tower_shield", "reapers_sickle", "longspear"]:
		var item: RunItem = RunItem.make(state.take_uid(), item_id, 3)
		hero.items.append(item)


## Walks through the day's stops (the first offer each time, left at once)
## and picks fight `pick`.
func _to_fight(state: RunState, pick: int = 0) -> void:
	while state.phase == "stop_choice" or state.phase == "stop":
		if state.phase == "stop_choice":
			assert_true(RunFlow.pick_stop(state, _content(), _run(), 0).ok)
		assert_true(RunFlow.leave_stop(state, _content(), _run()).ok)
	if state.phase == "fight_choice":
		assert_true(RunFlow.pick_fight(state, _content(), pick).ok)
	assert_eq(state.phase, "fight")


## Makes `encounter_id` the day's only fight, then walks to it.
func _to_only_fight(state: RunState, encounter_id: String) -> void:
	state.fight_options = [encounter_id] as Array[String]
	_to_fight(state)
	assert_eq(state.encounter_id, encounter_id)


# --- the run start ------------------------------------------------------------

func _offered_heroes(state: RunState) -> Array[String]:
	var heroes: Array[String] = []
	for offer: Dictionary in state.offers:
		heroes.append(offer["hero"])
	return heroes


func test_a_run_starts_with_a_drafted_team_and_a_package() -> void:
	var state: RunState = RunFlow.new_run(5, _content())
	assert_eq(state.phase, "start_hero")
	_refused(RunFlow.pick_stop(state, _content(), _run(), 0), "that isn't possible now (the run is at start_hero)")
	var drafted: Array[String] = []
	for pick: int in RunState.TEAM_SIZE:
		var heroes: Array[String] = _offered_heroes(state)
		assert_eq(heroes.size(), 3, "pick %d offers three" % pick)
		assert_ne(heroes[0], heroes[1])
		assert_ne(heroes[1], heroes[2])
		for hero_id: String in heroes:
			assert_false(drafted.has(hero_id), "a drafted hero isn't offered again")
		_refused(RunFlow.pick_start_hero(state, _content(), _run(), 3), "no offer there")
		assert_true(RunFlow.pick_start_hero(state, _content(), _run(), 1).ok)
		drafted.append(heroes[1])
	var team: Array[String] = []
	for hero: RunHero in state.heroes:
		team.append(hero.hero_id)
	assert_eq(team, drafted)
	assert_eq([state.heroes[0].row, state.heroes[1].row, state.heroes[2].row], [UnitSetup.Row.FRONT, UnitSetup.Row.BACK, UnitSetup.Row.BACK], "the first pick stands in front")
	var packages: Array[String] = []
	for offer: Dictionary in state.offers:
		packages.append(offer["package"])
	assert_eq(packages, ["gold", "relic", "kit", "kit"] as Array[String])
	assert_eq(_content().relics[state.offers[1]["relic"]].rarity, "common")
	assert_true(RunFlow.pick_package(state, _content(), _run(), 0).ok)
	assert_eq(state.gold, 14, "base 8 + the gold package's 6")
	assert_eq([state.phase, state.day, state.visit, state.encounter_id], ["stop_choice", 1, 0, ""])
	assert_eq(state.fight_options.size(), 2, "two fights to pick from")
	for encounter_id: String in state.fight_options:
		assert_true(_run().act(1).encounters_for(_run().act(1).normal, 1).has(encounter_id), "a day-1 fight")


# --- start kits (docs/plans/fight-questions-and-readability.md, section 3) ----------

func _kits(state: RunState) -> Array[String]:
	var kits: Array[String] = []
	for offer: Dictionary in state.offers:
		if offer["package"] == "kit":
			kits.append(offer["kit"])
	return kits


func test_the_start_offers_two_kits_for_the_teams_affinities() -> void:
	var seen: Array[String] = []
	for run_seed: int in range(1, 60):
		var state: RunState = _drafted(run_seed)
		var affinities: Array[String] = []
		for hero: RunHero in state.heroes:
			affinities.append_array(_content().heroes[hero.hero_id].affinities)
		var kits: Array[String] = _kits(state)
		assert_eq(kits.size(), 2, "seed %d" % run_seed)
		assert_ne(kits[0], kits[1], "two different kits")
		for keyword: String in kits:
			assert_true(affinities.has(keyword), "seed %d: %s is one of the team's affinities" % [run_seed, keyword])
			if not seen.has(keyword):
				seen.append(keyword)
		for offer: Dictionary in state.offers:
			if offer["package"] == "kit":
				var kit: EconomyDef.Kit = _run().economy.kit_for(offer["kit"])
				assert_eq([offer["name"], offer["item"], offer["essence"], offer["tier"]], [kit.name, kit.item, kit.essence, 0])
	assert_gt(seen.size(), 4, "different teams get different kits")


func test_kits_top_up_from_other_keywords_when_the_team_has_too_few() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var economy: Dictionary = JSON.parse_string(texts[RunContent.ECONOMY_FILE])
	economy["kits"] = [{"keyword": "bow", "name": "Only Bows", "item": "flint_arrows", "essence": "wrath"},
		{"keyword": "hex", "name": "Only Hexes", "item": "thorn_darts", "essence": "frost"}]
	texts[RunContent.ECONOMY_FILE] = JSON.stringify(economy)
	var run: RunContent = RunContent.load_texts(texts, _content())
	assert_true(run.is_valid(), str(run.errors))
	var state: RunState = RunFlow.new_run(3, _content())
	for pick: int in RunState.TEAM_SIZE:
		RunFlow.pick_start_hero(state, _content(), run, 0)
	var kits: Array[String] = _kits(state)
	kits.sort()
	assert_eq(kits, ["bow", "hex"] as Array[String], "the only two kits there are")


func test_picking_a_kit_gives_its_item_already_infused() -> void:
	var state: RunState = _drafted(5)
	var index: int = -1
	for i: int in state.offers.size():
		if state.offers[i]["package"] == "kit":
			index = i
	var offer: Dictionary = state.offers[index]
	var result: RunActions.Result = RunFlow.pick_package(state, _content(), _run(), index)
	assert_true(result.ok, result.error)
	assert_eq(state.stash.size(), 1)
	assert_eq([state.stash[0].item_id, state.stash[0].tier, state.stash[0].essence_ids, state.stash[0].xp], [offer["item"], 0, [offer["essence"]], 0])
	assert_string_contains(result.note, "infused with %s" % _content().essences[offer["essence"]].name)
	assert_eq(state.gold, _run().economy.base_gold, "a kit gives no gold")
	assert_eq(state.phase, "stop_choice")
	assert_true(state.check(_content()).is_empty(), str(state.check(_content())))


# --- the whole act's fights (docs/plans/fight-questions-and-readability.md, 1) ------

func test_every_days_fights_are_known_from_the_start_and_match_the_day() -> void:
	for run_seed: int in range(1, 15):
		var state: RunState = _started(run_seed)
		var act: ActDef = _run().act(1)
		var planned: Array = []
		for day: int in range(1, act.days + 1):
			planned.append(RunFlow.fights_for_day(state, _run(), day))
		assert_eq(RunFlow.fights_for_day(state, _run(), 1), state.fight_options, "day 1 as offered")
		for day: int in range(1, act.days + 1):
			var fights: Array[String] = planned[day - 1]
			if act.is_boss_day(day):
				assert_eq(fights, [act.boss] as Array[String])
			else:
				assert_eq(fights.size(), 2, "day %d" % day)
				for encounter_id: String in fights:
					assert_eq(_content().encounters[encounter_id].kind, "elite" if act.is_elite_day(day) else "normal", "day %d" % day)
		var other: RunState = _started(run_seed + 1000)
		var differs: bool = false
		for day: int in range(1, act.days):
			differs = differs or RunFlow.fights_for_day(other, _run(), day) != planned[day - 1]
		assert_true(differs, "another seed plans other fights")


func test_the_same_seed_gives_the_same_start() -> void:
	var one: RunState = _started(9)
	var two: RunState = _started(9)
	assert_eq(JSON.stringify(one.to_dict()), JSON.stringify(two.to_dict()))


# --- the day's stops --------------------------------------------------------------

func test_each_visit_offers_a_shop_and_a_different_stop() -> void:
	var seen: Array[String] = []
	for run_seed: int in range(1, 120):
		var state: RunState = _started(run_seed)
		for visit: int in _run().economy.stops_per_day:
			assert_eq([state.phase, state.visit], ["stop_choice", visit])
			var stops: Array[String] = []
			for offer: Dictionary in state.offers:
				stops.append(offer["stop"])
				if not seen.has(offer["stop"]):
					seen.append(offer["stop"])
			assert_eq(stops.size(), _run().economy.node_choices, "two stops")
			assert_true(_run().is_shop(stops[0]), "the first is a shop")
			assert_false(_run().is_shop(stops[1]), "the other isn't")
			for stop: String in ["forge", "vault", "retrain", "upgrade"]:
				assert_false(stops.has(stop), "%s needs an infusion, a key, or a specialization, or it's before the boss" % stop)
			assert_true(RunFlow.pick_stop(state, _content(), _run(), 1).ok)
			assert_true(RunFlow.leave_stop(state, _content(), _run()).ok)
		assert_eq(state.phase, "fight_choice", "after the last stop, the fight")
	for stop: String in ["caravan", "whetstone_stall", "arms_rack", "ember_seller", "smiths_cart", "synergy_peddler", "loot_item", "loot_essence", "loot_gold", "barrow_hoard"]:
		assert_true(seen.has(stop), "%s can come up" % stop)
	assert_false(seen.has("skirmish"), "no more extra fights")
	var keyed: RunState = _started(3)
	keyed.keys = 1
	keyed.stash.append(RunItem.make(keyed.take_uid(), "longspear"))
	keyed.stash[0].essence_ids = ["ember"] as Array[String]
	var found: Array[String] = []
	for day: int in range(1, 6):
		keyed.day = day
		for attempt: int in 12:
			keyed.attempt = attempt
			RunFlow._offer_stops(keyed, _content(), _run())
			for offer: Dictionary in keyed.offers:
				found.append(offer["stop"])
	assert_true(found.has("vault") and found.has("forge"), "a key and an infusion open the Vault and the Forge")


func test_the_second_visits_stops_are_drawn_fresh() -> void:
	var differs: bool = false
	for run_seed: int in range(1, 20):
		var state: RunState = _started(run_seed)
		var first: String = JSON.stringify(state.offers)
		RunFlow.pick_stop(state, _content(), _run(), 1)
		RunFlow.leave_stop(state, _content(), _run())
		assert_eq(state.visit, 1)
		differs = differs or JSON.stringify(state.offers) != first
	assert_true(differs, "each visit has its own draw")


func test_the_node_pool_is_checked() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var nodes: Array = JSON.parse_string(texts[RunContent.NODES_FILE])
	nodes.append({"id": "lost_purse", "name": "X", "text": "?", "kind": "loot", "loot": "gold", "weight": 1})
	nodes.append({"id": "y", "name": "Y", "text": "?", "kind": "loot", "loot": "relics", "weight": 1})
	nodes.append({"id": "z", "name": "Z", "text": "?", "kind": "fight", "weight": 0})
	nodes.append({"id": "w", "name": "W", "text": "?", "kind": "shop", "shop": {"keyword": "thorns", "slot": "hat"}, "weight": 1})
	nodes.append({"id": "v", "name": "V", "text": "?", "kind": "shop", "shop": {"essence": "mud", "keywords": ["ward"]}, "weight": 1})
	nodes.append({"id": "u", "name": "U", "text": "?", "kind": "shop", "shop": {"keywords": ["ward"]}, "weight": 1})
	texts[RunContent.NODES_FILE] = JSON.stringify(nodes)
	var errors: Array[String] = RunContent.load_texts(texts, _content()).errors
	for expected: String in ["duplicate id \"lost_purse\"", "loot: unknown value \"relics\"", "kind: unknown value \"fight\"", "weight: 0 is out of range",
			"unknown keyword \"thorns\"", "slot: unknown value \"hat\"", "unknown essence \"mud\"", "keywords go with an essence merchant's essence"]:
		assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "%s in %s" % [expected, errors])
	var no_shops: Array = []
	for node: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://data".path_join(RunContent.NODES_FILE))):
		if node["kind"] != "shop":
			no_shops.append(node)
	texts[RunContent.NODES_FILE] = JSON.stringify(no_shops)
	errors = RunContent.load_texts(texts, _content()).errors
	assert_true(errors.any(func(e: String) -> bool: return e.contains("needs at least one shop")), str(errors))


func test_forge_reforge_and_retrain_need_their_stops() -> void:
	var state: RunState = _started()
	state.stash.append(RunItem.make(state.take_uid(), "longspear"))
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
	hero.spec_progress = 999
	hero.spec_choice = 1
	hero.calling_progress = 50
	_refused(RunFlow.retrain(state, _content(), hero.hero_id, specs[1]), "retraining needs a Retrain stop")
	RunFlow._enter_stop(state, _content(), _run(), "retrain")
	_refused(RunFlow.retrain(state, _content(), hero.hero_id, specs[0]), "already their specialization")
	assert_true(RunFlow.retrain(state, _content(), hero.hero_id, specs[1]).ok)
	assert_eq(hero.specialization_id, specs[1])
	assert_eq([hero.spec_progress, hero.spec_choice, hero.calling_progress], [0, -1, 50], "the new deed starts from zero; the calling is kept")
	_refused(RunFlow.retrain(state, _content(), hero.hero_id, specs[2]), "used")


func test_vault_spends_a_key() -> void:
	var state: RunState = _started()
	state.keys = 1
	RunFlow._enter_stop(state, _content(), _run(), "vault")
	assert_eq(state.keys, 0)
	assert_eq(state.offers.size(), 1)
	assert_true(["item", "relic"].has(state.offers[0]["type"]))


func test_loot_and_events_can_be_taken_or_passed() -> void:
	for loot: Array in [["loot_item", "item"], ["loot_essence", "essence"], ["loot_gold", "gold"]]:
		var state: RunState = _started(4)
		RunFlow._enter_stop(state, _content(), _run(), loot[0])
		assert_eq([state.stop_kind, state.stop_node], ["loot", loot[0]])
		assert_eq(state.offers.size(), 1)
		assert_eq(state.offers[0]["type"], loot[1], "each loot node gives its own kind")
		var before_gold: int = state.gold
		var result: RunActions.Result = RunFlow.take(state, _content(), 0)
		assert_true(result.ok, result.error)
		assert_true(state.offers[0]["taken"])
		if loot[1] == "gold":
			assert_eq(state.gold, before_gold + _run().economy.loot_gold)
	for event_id: String in _run().event_ids:
		var state: RunState = _started(4)
		RunFlow._enter_stop(state, _content(), _run(), event_id)
		assert_eq([state.stop_kind, state.stop_node], ["event", event_id])
		for offer: Dictionary in state.offers:
			assert_eq(offer["event"], event_id, "the node picked is the event you get")
		assert_true(RunFlow.leave_stop(state, _content(), _run()).ok, "passing is just leaving")
		assert_eq([state.stop_node, state.visit, state.phase], ["", 1, "stop_choice"], "on to the day's second stop")


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


# --- shops ------------------------------------------------------------------------

func test_the_caravan_follows_the_shop_rules() -> void:
	for run_seed: int in range(1, 30):
		var state: RunState = _at_shop("caravan", run_seed)
		assert_eq(state.offers.size(), 5, "shop_items wares")
		var seen: Array[String] = []
		for offer: Dictionary in state.offers:
			assert_eq(offer["type"], "item", "only items (no heroes, no relics)")
			var def: ItemDef = _content().items[offer["item"]]
			assert_false(def.enemy_only, "never enemy-only")
			assert_ne(def.rarity, "legendary", "never Legendary")
			assert_eq(offer["price"], _run().economy.item_price_for(def.rarity, offer["tier"]), "priced by rarity and tier")
			assert_lt(offer["tier"], 2, "Act 1: C or B only")
			assert_false(seen.has(offer["item"]), "different items")
			seen.append(offer["item"])


func test_prices_go_by_rarity_then_double_per_tier() -> void:
	var economy: EconomyDef = _run().economy
	assert_eq([economy.item_price_for("common", 0), economy.item_price_for("uncommon", 0), economy.item_price_for("rare", 0), economy.item_price_for("epic", 0)], [2, 3, 5, 7])
	assert_eq([economy.item_price_for("rare", 1), economy.item_price_for("rare", 2), economy.item_price_for("rare", 3)], [10, 20, 40])
	var state: RunState = _at_shop()
	var item: RunItem = RunItem.make(state.take_uid(), "longspear", 1)
	state.stash.append(item)
	assert_eq(RunFlow.sell_price(_content(), _run(), item), economy.item_price_for(_content().items["longspear"].rarity, 1) / 2, "half, rounded down")


func test_shops_never_offer_enemy_only_items() -> void:
	var state: RunState = _at_shop()
	for reroll: int in 40:
		state.reroll_count = reroll
		RunFlow._fill_shop(state, _content(), _run())
		for offer: Dictionary in state.offers:
			assert_false(_content().items[offer["item"]].enemy_only, "%s is enemy-only" % offer["item"])


func test_shops_offer_held_items_at_the_held_tier() -> void:
	var state: RunState = _at_shop()
	for item_id: String in _content().item_ids:
		if not _content().items[item_id].enemy_only:
			state.stash.clear()
			state.stash.append(RunItem.make(state.take_uid(), item_id, 1))
			for reroll: int in 3:
				state.reroll_count = reroll
				RunFlow._fill_shop(state, _content(), _run())
				for offer: Dictionary in state.offers:
					if offer.get("item", "") == item_id:
						assert_eq(offer["tier"], 1, "%s is held at B" % item_id)


func test_keyword_and_slot_shops_sell_what_fits() -> void:
	for pair: Array in [["whetstone_stall", "keyword", "blade"], ["hedge_witch", "keyword", "hex"], ["charm_seller", "slot", ItemDef.Slot.PASSIVE], ["arms_rack", "slot", ItemDef.Slot.BASIC_ATTACK]]:
		for run_seed: int in [1, 2, 3]:
			var state: RunState = _at_shop(pair[0], run_seed)
			var fitting: int = 0
			for offer: Dictionary in state.offers:
				var def: ItemDef = _content().items[offer["item"]]
				if (pair[1] == "keyword" and def.keywords.has(pair[2])) or (pair[1] == "slot" and def.slot == pair[2]):
					fitting += 1
			assert_eq(state.offers.size(), 5, "%s: topped up with any item when too few fit" % pair[0])
			assert_gte(fitting, 3, "%s sells mostly its own wares" % pair[0])


# --- hero Epics (docs/plans/items-and-clarity.md, section 3) ---------------------

func _off_team(state: RunState, item_id: String) -> bool:
	var hero_id: String = _content().items[item_id].hero
	return not hero_id.is_empty() and state.hero(hero_id) == null


func test_shops_offer_only_the_teams_epics() -> void:
	var team_epics: int = 0
	for run_seed: int in range(1, 60):
		var state: RunState = _at_shop("caravan", run_seed)
		for reroll: int in 3:
			for offer: Dictionary in state.offers:
				if offer["type"] != "item":
					continue
				assert_false(_off_team(state, offer["item"]), "seed %d: %s is another hero's Epic" % [run_seed, offer["item"]])
				if not _content().items[offer["item"]].hero.is_empty():
					team_epics += 1
			state.gold = 99
			RunFlow.reroll(state, _content(), _run())
	assert_gt(team_epics, 0, "the team's own Epics do show up")


func test_other_sources_can_give_any_heros_epic() -> void:
	var epic_only: Array[int] = [0, 0, 0, 1, 0]
	var off_team: int = 0
	for run_seed: int in range(1, 40):
		var state: RunState = _started(run_seed)
		var rng := SimRng.new(run_seed)
		var any: String = RunFlow._pick_item(state, _content(), rng, epic_only, false)
		if _off_team(state, any):
			off_team += 1
		var shop_like: String = RunFlow._pick_item(state, _content(), rng, epic_only, false, [], Callable(), false)
		assert_false(_off_team(state, shop_like), "seed %d: a shop-style pick never names another hero's Epic" % run_seed)
	assert_gt(off_team, 10, "the Vault, events, Loot, and elite and boss rewards can")


func test_the_reward_pick_after_a_normal_fight_keeps_to_the_team() -> void:
	var epic_only: Array[int] = [0, 0, 0, 1, 0]
	var off_team_after: Dictionary = {"normal": 0, "elite": 0}
	for run_seed: int in range(1, 40):
		for kind: String in ["normal", "elite"]:
			var state: RunState = _started(run_seed)
			state.offers.clear()
			var encounter := EncounterDef.new()
			encounter.kind = kind
			RunFlow._add_reward_pick(state, _content(), _run(), encounter, epic_only, SimRng.new(run_seed))
			for offer: Dictionary in state.offers:
				if offer["type"] == "item" and _off_team(state, offer["item"]):
					off_team_after[kind] += 1
	assert_eq(off_team_after["normal"], 0, "a normal fight's reward pick offers only the team's Epics")
	assert_gt(off_team_after["elite"], 0, "an elite's can offer any hero's")


## A keyword shop whose keyword has too few items for this team (their Epics
## count; other heroes' don't) tops up with any item.
func test_a_shop_tops_up_when_too_few_items_fit() -> void:
	var probe: RunState = _started()
	var chosen: String = ""
	var fitting: Array[String] = []
	for node_id: String in _run().node_ids:
		var shop: ShopDef = _run().nodes[node_id].shop
		if shop == null or shop.keyword.is_empty() or not shop.essence.is_empty() or not chosen.is_empty():
			continue
		var items: Array[String] = []
		for item_id: String in _content().item_ids:
			var def: ItemDef = _content().items[item_id]
			var for_team: bool = def.hero.is_empty() or probe.hero(def.hero) != null
			if shop.fits(def) and not def.enemy_only and def.rarity != "legendary" and for_team:
				items.append(item_id)
		if items.size() < 5:
			chosen = node_id
			fitting = items
	assert_ne(chosen, "", "some keyword shop has too few wares for this team")
	var state: RunState = _at_shop(chosen)
	assert_eq(state.offers.size(), 5)
	var sold: int = 0
	for offer: Dictionary in state.offers:
		if fitting.has(offer["item"]):
			sold += 1
	assert_eq(sold, fitting.size(), "%s: every fitting item first, then anything" % chosen)


func test_an_essence_merchant_sells_its_essence_and_suited_items() -> void:
	var state: RunState = _at_shop("ember_seller")
	assert_eq([state.offers[0]["type"], state.offers[0]["essence"], state.offers[0]["price"]], ["essence", "ember", _run().economy.essence_price])
	assert_eq(state.offers.size(), 1 + _run().economy.shop_items)
	state.gold = 50
	assert_true(RunFlow.buy(state, _content(), 0).ok)
	assert_eq([state.pouch, state.gold], [["ember"] as Array[String], 50 - _run().economy.essence_price])
	var suited: int = 0
	for i: int in range(1, state.offers.size()):
		var def: ItemDef = _content().items[state.offers[i]["item"]]
		if def.keywords.has("burn") or def.keywords.has("spell"):
			suited += 1
	assert_gte(suited, 3, "mostly Burn and Spell items")


func test_a_tier_shop_sells_different_items_at_its_tier() -> void:
	for run_seed: int in range(1, 30):
		var state: RunState = _at_shop("smiths_cart", run_seed)
		assert_eq(state.offers.size(), 3)
		var seen: Array[String] = []
		for offer: Dictionary in state.offers:
			var def: ItemDef = _content().items[offer["item"]]
			assert_eq([offer["type"], offer["tier"], offer["price"]], ["item", 1, _run().economy.item_price_for(def.rarity, 1)], "B tier at B prices")
			assert_false(def.enemy_only)
			assert_false(seen.has(offer["item"]), "different items")
			seen.append(offer["item"])


func test_the_synergy_peddler_sells_partners_for_what_you_hold() -> void:
	var pair: SynergyDef = null
	for synergy_id: String in _content().synergy_ids:
		var synergy: SynergyDef = _content().synergies[synergy_id]
		if synergy.layer == SynergyDef.Layer.PAIR and pair == null:
			pair = synergy
	var state: RunState = _started()
	state.stash.append(RunItem.make(state.take_uid(), pair.items[0]))
	var partners: Array[String] = RunFlow.partner_items(state, _content())
	assert_true(partners.has(pair.items[1]), "the pair's other half")
	assert_false(partners.has(pair.items[0]), "never what you hold")
	for item_id: String in _content().item_ids:
		var hero_id: String = _content().items[item_id].hero
		if not hero_id.is_empty():
			assert_eq(partners.has(item_id), state.hero(hero_id) != null, "the team's heroes' Epics only")
	state.pouch.append("ember")
	for synergy_id: String in _content().synergy_ids:
		var synergy: SynergyDef = _content().synergies[synergy_id]
		if synergy.layer == SynergyDef.Layer.TRANSFORMATION and synergy.essence == "ember":
			assert_true(RunFlow.partner_items(state, _content()).has(synergy.items[0]), "an item that transforms with an essence you hold")
	RunFlow._enter_stop(state, _content(), _run(), "synergy_peddler")
	var wanted: Array[String] = RunFlow.partner_items(state, _content())
	var sold: int = 0
	for offer: Dictionary in state.offers:
		if wanted.has(offer["item"]):
			sold += 1
	assert_gt(sold, 0, "sells partners (topped up with anything)")


func test_buying_selling_and_rerolling_at_a_shop() -> void:
	var state: RunState = _at_shop()
	var price: int = state.offers[0]["price"]
	assert_true(RunFlow.buy(state, _content(), 0).ok)
	assert_eq([state.gold, state.stash.size()], [14 - price, 1])
	_refused(RunFlow.buy(state, _content(), 0), "already taken")
	var uid: int = state.stash[0].uid
	var sold_for: int = RunFlow.sell_price(_content(), _run(), state.stash[0])
	assert_true(RunFlow.sell(state, _content(), _run(), uid).ok)
	assert_eq(state.gold, 14 - price + sold_for)
	var before: Array[Dictionary] = state.offers.duplicate(true)
	var gold: int = state.gold
	assert_true(RunFlow.reroll(state, _content(), _run()).ok)
	assert_true(RunFlow.reroll(state, _content(), _run()).ok)
	assert_eq(state.gold, gold - 1 - 2, "rerolls cost 1, then 2")
	assert_ne(JSON.stringify(state.offers), JSON.stringify(before))
	state.gold = 0
	_refused(RunFlow.reroll(state, _content(), _run()), "not enough gold")
	assert_true(RunFlow.leave_stop(state, _content(), _run()).ok)
	assert_eq(state.reroll_count, 2, "kept until the next stop")
	RunFlow.pick_stop(state, _content(), _run(), 0)
	assert_eq(state.reroll_count, 0, "each shop visit's rerolls start over")


func test_buying_selling_and_rerolling_need_a_shop() -> void:
	var state: RunState = _started()
	state.stash.append(RunItem.make(state.take_uid(), "longspear"))
	_refused(RunFlow.buy(state, _content(), 0), "buying needs a shop")
	_refused(RunFlow.sell(state, _content(), _run(), state.stash[0].uid), "selling needs a shop")
	_refused(RunFlow.reroll(state, _content(), _run()), "rerolling needs a shop")
	RunFlow._enter_stop(state, _content(), _run(), "loot_gold")
	_refused(RunFlow.sell(state, _content(), _run(), state.stash[0].uid), "selling needs a shop")


func test_buying_needs_gold_and_room() -> void:
	var state: RunState = _at_shop()
	state.gold = 0
	_refused(RunFlow.buy(state, _content(), 0), "not enough gold")
	state.gold = 100
	for i: int in _content().tuning.stash_slots:
		state.stash.append(RunItem.make(state.take_uid(), "longspear"))
	var before: String = JSON.stringify(state.to_dict())
	_refused(RunFlow.buy(state, _content(), 0), "the stash has no room")
	assert_eq(JSON.stringify(state.to_dict()), before, "a refused purchase changes nothing")


func test_buying_an_upgrade_combines_into_the_held_copy() -> void:
	var state: RunState = _at_shop()
	var offer: Dictionary = state.offers[0]
	assert_eq(RunFlow.upgrade_target(state, _content(), 0), -1, "nothing held yet")
	var held: RunItem = RunItem.make(state.take_uid(), offer["item"], offer["tier"])
	held.essence_ids = ["ember"] as Array[String]
	state.stash.append(held)
	for i: int in _content().tuning.stash_slots:
		state.stash.append(RunItem.make(state.take_uid(), "longspear", 2))
	assert_eq(RunFlow.upgrade_target(state, _content(), 0), held.uid, "it lights up")
	state.gold = 50
	assert_true(RunFlow.take(state, _content(), 0).ok, "an upgrade needs no stash room (take buys at a shop, combining too)")
	assert_eq([held.tier, held.essence_ids, state.gold], [offer["tier"] + 1, ["ember"] as Array[String], 50 - offer["price"]])
	assert_true(state.offers[0]["taken"])
	assert_eq(RunFlow.upgrade_target(state, _content(), 0), -1)
	state.stash.clear()
	state.stash.append(held)
	assert_true(RunFlow.take(state, _content(), 1).ok, "take buys at a shop")
	assert_eq(state.gold, 50 - offer["price"] - state.offers[1]["price"])


# --- the day's fights ---------------------------------------------------------------

func test_every_day_offers_an_easier_and_a_harder_fight() -> void:
	var act: ActDef = _run().act(1)
	assert_eq([act.days, act.elite_days], [8, [3, 6] as Array[int]], "an 8-day act, elites on days 3 and 6")
	for day: int in range(1, act.days):
		for run_seed: int in range(1, 12):
			var state: RunState = _started(run_seed)
			state.day = day
			RunFlow._start_day(state, _content(), _run())
			assert_eq(state.fight_options.size(), 2, "day %d" % day)
			assert_false(RunFlow.is_hard_fight(state, _run(), state.fight_options[0]), "the easier one first")
			assert_true(RunFlow.is_hard_fight(state, _run(), state.fight_options[1]), "then the harder one")
			for encounter_id: String in state.fight_options:
				assert_eq(_content().encounters[encounter_id].kind, "elite" if act.is_elite_day(day) else "normal", "day %d" % day)
	var boss_day: RunState = _started()
	boss_day.day = act.days
	RunFlow._start_day(boss_day, _content(), _run())
	assert_eq(boss_day.fight_options, ["the_ash_mother"] as Array[String], "only the boss")


func test_picking_the_days_fight() -> void:
	var state: RunState = _started()
	_refused(RunFlow.pick_fight(state, _content(), 0), "the run is at stop_choice")
	for visit: int in _run().economy.stops_per_day:
		assert_true(RunFlow.pick_stop(state, _content(), _run(), 0).ok)
		assert_true(RunFlow.leave_stop(state, _content(), _run()).ok)
	assert_eq([state.phase, state.encounter_id], ["fight_choice", ""])
	_refused(RunFlow.pick_fight(state, _content(), 2), "no fight there")
	_refused(RunFlow.fight(state, _content(), _run())[0], "the run is at fight_choice")
	assert_true(RunFlow.pick_fight(state, _content(), 1).ok)
	assert_eq([state.phase, state.encounter_id], ["fight", state.fight_options[1]])


func test_the_act_scales_its_fights_hp() -> void:
	var state: RunState = _started()
	state.day = 1
	var scale: int = RunFlow.fight_hp_bp(state, _run(), "pup_litter")
	assert_gt(scale, FixedMath.BP_ONE, "day-1 pups have more HP than their data says")
	_to_only_fight(state, "pup_litter")
	var setup: FightSetup = RunFight.setup_for(state, _content(), "pup_litter", scale)
	assert_eq(setup.enemies[0].stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(_content().enemies["rift_pup"].stats.get_stat(UnitStats.Stat.HP), scale))
	assert_eq(_content().enemies["rift_pup"].stats.get_stat(UnitStats.Stat.HP), 200, "the enemy's own data is untouched")
	assert_eq(RunFlow.fight_hp_bp(state, _run(), "the_ash_mother"), FixedMath.BP_ONE, "the boss is as written")


func test_the_upgrade_stop_is_the_boss_days_last_stop() -> void:
	var state: RunState = _started()
	state.day = 8
	RunFlow._start_day(state, _content(), _run())
	assert_eq(state.phase, "stop_choice", "the first visit is a normal pick")
	assert_true(RunFlow.pick_stop(state, _content(), _run(), 0).ok)
	assert_true(RunFlow.leave_stop(state, _content(), _run()).ok)
	assert_eq([state.phase, state.stop_kind], ["stop", "upgrade"])
	var claw: RunItem = RunItem.make(state.take_uid(), "rift_claw", 0)
	state.stash.append(claw)
	var top: RunItem = RunItem.make(state.take_uid(), "longspear", 3)
	state.stash.append(top)
	_refused(RunFlow.upgrade(state, _content(), top.uid), "already S")
	assert_true(RunFlow.upgrade(state, _content(), claw.uid).ok, "enemy-only items too")
	assert_eq(claw.tier, 1)
	_refused(RunFlow.upgrade(state, _content(), claw.uid), "used")
	assert_true(RunFlow.leave_stop(state, _content(), _run()).ok)
	assert_eq([state.phase, state.encounter_id], ["fight", "the_ash_mother"], "no pick: straight to the boss")


# --- fights, rewards, losing ----------------------------------------------------

func _reward_pick(state: RunState) -> Array[int]:
	var picks: Array[int] = []
	for i: int in state.offers.size():
		if state.offers[i].get("group", "") == RunFlow.REWARD_PICK:
			picks.append(i)
	return picks


func test_a_win_gives_gold_an_essence_and_a_pick_of_three() -> void:
	var state: RunState = _started()
	_make_strong(state)
	_to_only_fight(state, "pup_litter")
	var gold: int = state.gold
	var fought: Array = RunFlow.fight(state, _content(), _run())
	assert_true((fought[0] as RunActions.Result).ok)
	assert_true((fought[1] as FightResult).guild_won())
	assert_eq(state.phase, "rewards")
	assert_eq(state.gold, gold + 5 + 1, "5 + the day number")
	assert_eq([state.offers[0]["type"], state.offers[0]["essence"]], ["essence", "wrath"], "a whole essence: pups yield Wrath")
	var picks: Array[int] = _reward_pick(state)
	assert_eq(picks.size(), 1 + _run().economy.reward_pool_items, "a pick of three")
	assert_eq([state.offers[picks[0]]["item"], state.offers[picks[0]]["drop"]], ["rift_claw", "yes"], "the enemy drop first: enemy-only items drop too")
	var ids: Array[String] = []
	for i: int in picks.slice(1):
		var def: ItemDef = _content().items[state.offers[i]["item"]]
		assert_false(def.enemy_only or def.rarity == "legendary", "pool items: never enemy-only or Legendary")
		assert_false(ids.has(def.id) or def.id == "rift_claw", "three different items")
		ids.append(def.id)
	assert_true(RunFlow.take(state, _content(), picks[2]).ok)
	_refused(RunFlow.take(state, _content(), picks[0]), "already taken")
	assert_true(RunFlow.take(state, _content(), 0).ok, "the essence is separate")
	assert_eq(state.pouch, ["wrath"] as Array[String])
	assert_true(RunFlow.done(state, _content(), _run()).ok)
	assert_eq([state.day, state.phase, state.visit], [2, "stop_choice", 0])


func test_the_harder_fight_pays_more() -> void:
	var golds: Array[int] = []
	for pick: int in 2:
		var state: RunState = _started()
		_make_strong(state)
		_to_fight(state, pick)
		assert_eq(RunFlow.is_hard_fight(state, _run(), state.encounter_id), pick == 1)
		var gold: int = state.gold
		assert_true((RunFlow.fight(state, _content(), _run())[1] as FightResult).guild_won())
		golds.append(state.gold - gold)
	assert_eq(golds, [6, FixedMath.apply_bp(6, _run().economy.hard_gold_bp)], "the harder fight's gold, times hard_gold_bp")


func test_an_elite_win_gives_an_essence_a_relic_choice_and_a_rank_up() -> void:
	var state: RunState = _started()
	_make_army(state)
	state.day = 3
	RunFlow._start_day(state, _content(), _run())
	_to_only_fight(state, "hound_alpha")
	var fought: Array = RunFlow.fight(state, _content(), _run())
	assert_true((fought[1] as FightResult).guild_won())
	var types: Array[String] = []
	for offer: Dictionary in state.offers:
		types.append(offer["type"])
	assert_eq(types.slice(0, 1), ["essence"] as Array[String], "a whole essence")
	assert_eq(_reward_pick(state).size(), 3, "and the reward pick")
	var relics: Array[int] = []
	for i: int in state.offers.size():
		if state.offers[i].get("group", "") == "relic_choice":
			relics.append(i)
	assert_eq(relics.size(), 3)
	assert_true(RunFlow.take(state, _content(), relics[1]).ok)
	assert_eq(state.relics.size(), 1)
	_refused(RunFlow.take(state, _content(), relics[0]), "already taken")
	var rank_up: int = types.find("rank_up")
	assert_gte(rank_up, 0, "an elite gives a rank-up")
	assert_eq(types.count("rank_up"), 1)
	_refused(RunFlow.take(state, _content(), rank_up), "choose which hero gets the rank-up")
	_refused(RunFlow.give_rank_up(state, _content(), relics[0], state.heroes[0].hero_id), "no rank-up there")
	var before: String = JSON.stringify(state.to_dict())
	_refused(RunFlow.give_rank_up(state, _content(), rank_up, state.heroes[0].hero_id), "is already rank S")
	assert_eq(JSON.stringify(state.to_dict()), before, "a refused rank-up changes nothing")
	var second: RunHero = state.heroes[1]
	second.rank = 0
	second.specialization_id = ""
	assert_true(RunFlow.give_rank_up(state, _content(), rank_up, second.hero_id).ok)
	assert_eq([second.rank, second.needs_specialization], [1, true])
	_refused(RunFlow.give_rank_up(state, _content(), rank_up, second.hero_id), "already given")
	assert_true(RunFlow.done(state, _content(), _run()).ok)
	_refused(RunFlow.give_rank_up(state, _content(), rank_up, second.hero_id), "there's no rank-up to give now")


func test_normal_wins_give_no_rank_up() -> void:
	var state: RunState = _started()
	_make_army(state)
	_to_fight(state)
	assert_true((RunFlow.fight(state, _content(), _run())[1] as FightResult).guild_won())
	for offer: Dictionary in state.offers:
		assert_ne(offer["type"], "rank_up")


func test_the_first_loss_replays_the_day_and_the_second_ends_the_run() -> void:
	var state: RunState = _started()
	state.day = 8
	RunFlow._start_day(state, _content(), _run())
	var stops_before: String = JSON.stringify(state.offers)
	_to_fight(state)
	var gold: int = state.gold
	var fought: Array = RunFlow.fight(state, _content(), _run())
	assert_false((fought[1] as FightResult).guild_won(), "a C team against the boss")
	assert_eq([state.phase, state.day, state.visit, state.attempt, state.losses, state.encounter_id], ["stop_choice", 8, 0, 1, 1, ""])
	assert_eq(state.fight_options, ["the_ash_mother"] as Array[String], "the same fight")
	assert_eq(state.gold, gold + 10, "bonus gold: 10 + 5 per win (none yet)")
	assert_ne(JSON.stringify(state.offers), stops_before, "fresh stops")
	_to_fight(state)
	RunFlow.fight(state, _content(), _run())
	assert_eq(state.phase, "run_over")
	_refused(RunFlow.pick_stop(state, _content(), _run(), 0), "run_over")


## The whole team at S, each with a specialization and a strong loadout.
func _make_army(state: RunState) -> void:
	_make_strong(state)
	for hero: RunHero in state.heroes:
		hero.rank = 3
		if hero.specialization_id.is_empty():
			hero.specialization_id = _first_spec(hero.hero_id)
		hero.needs_specialization = false
		if hero.items.is_empty():
			for item_id: String in ["tower_shield", "reapers_sickle", "longspear"]:
				hero.items.append(RunItem.make(state.take_uid(), item_id, 3))


func test_beating_the_boss_ends_the_act() -> void:
	var state: RunState = _started()
	_make_army(state)
	state.day = 8
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

func test_a_replayed_day_keeps_its_fights() -> void:
	var seen: Array[String] = []
	for run_seed: int in range(1, 25):
		var state: RunState = _started(run_seed)
		state.day = 4
		RunFlow._start_day(state, _content(), _run())
		var first: Array[String] = state.fight_options.duplicate()
		for encounter_id: String in first:
			if not seen.has(encounter_id):
				seen.append(encounter_id)
		state.attempt = 1
		state.gold += 37
		state.wins += 2
		RunFlow._start_day(state, _content(), _run())
		assert_eq(state.fight_options, first, "seed %d" % run_seed)
	assert_gt(seen.size(), 2, "day 4 has several possible fights")


func test_offers_dont_depend_on_earlier_picks() -> void:
	var one: RunState = _started(21)
	var two: RunState = _started(21)
	RunFlow.pick_stop(one, _content(), _run(), 0)
	RunFlow.pick_stop(two, _content(), _run(), 1)
	two.gold += 11
	for state: RunState in [one, two]:
		RunFlow.leave_stop(state, _content(), _run())
	assert_eq(JSON.stringify(one.offers), JSON.stringify(two.offers), "the second visit's stops don't depend on the first's")
	for state: RunState in [one, two]:
		state.day = 2
		RunFlow._start_day(state, _content(), _run())
	assert_eq(one.fight_options, two.fight_options, "tomorrow's fights don't depend on today's stops")


func test_save_and_load_mid_run_continues_the_same() -> void:
	var state: RunState = _at_shop("caravan", 13)
	RunFlow.reroll(state, _content(), _run())
	var loaded: Array = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())), _content())
	assert_eq(loaded[1], [] as Array[String])
	var copy: RunState = loaded[0]
	assert_eq(JSON.stringify(copy.to_dict()), JSON.stringify(state.to_dict()))
	for run_state: RunState in [state, copy]:
		RunFlow.buy(run_state, _content(), 0)
		RunFlow.reroll(run_state, _content(), _run())
		_to_fight(run_state, 1)
		RunFlow.fight(run_state, _content(), _run())
	assert_eq(JSON.stringify(copy.to_dict()), JSON.stringify(state.to_dict()))


func test_a_save_names_only_the_days_fights() -> void:
	var state: RunState = _started()
	_to_fight(state)
	var data: Dictionary = state.to_dict()
	data["encounter"] = "the_ash_mother"
	var errors: Array[String] = RunState.from_dict(JSON.parse_string(JSON.stringify(data)), _content())[1]
	assert_true(errors.any(func(e: String) -> bool: return e.contains("isn't one of the day's")), str(errors))


# --- the bot ------------------------------------------------------------------

func test_the_bot_plays_whole_runs() -> void:
	var reports: Array[RunBot.Report] = []
	for run_seed: int in [1, 2, 3, 4]:
		var report: RunBot.Report = RunBot.play(run_seed, _content(), _run())
		assert_eq(report.errors, [] as Array[String], "seed %d" % run_seed)
		assert_true(["act_end", "run_over"].has(report.ending), "seed %d ended: %s" % [run_seed, report.ending])
		assert_gt(report.fights.size(), 0)
		reports.append(report)
	var again: RunBot.Report = RunBot.play(1, _content(), _run())
	assert_eq([again.ending, again.day, again.bought], [reports[0].ending, reports[0].day, reports[0].bought], "same seed, same run")
	var lines: PackedStringArray = RunReport.lines(reports, 1)
	assert_eq(lines[0], "== 4 runs, seeds 1-4 ==")
	assert_true(lines[1].begins_with("Act cleared: "))
	assert_true(Array(lines).any(func(line: String) -> bool: return line.begins_with("Fights: ")))
