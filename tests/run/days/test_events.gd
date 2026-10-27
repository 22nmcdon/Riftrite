extends GutTest
## The Event node (docs/plans/rebuild-phase5c-combos.md, step 8c, section
## 16.7; events.md): the scenes and every choice's results, greyed choices,
## walking away, the Bloodied Oath and each oath's burden, reward, and end,
## the nodes a day shows, and the save.

const Bot = preload("res://tools/run_bot.gd")
const R = preload("res://tests/run/run_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start(run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


## A flow in event node `node` ("event:<scene>" or "oath") on `day`, with 30
## shards.
func _at(node: String, day: int = 1) -> RunFlow:
	var flow: RunFlow = _start()
	flow.state.day = day
	flow.state.shards = 30
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign([node])
	assert_eq(flow.choose_node(0), "")
	return flow


func _choice(flow: RunFlow, choice_id: String) -> int:
	var scene: EventDef.Scene = flow.event_scene()
	for i: int in scene.choices.size():
		if scene.choices[i].id == choice_id:
			return i
	return -1


func _result(outcome: FightResult.Outcome, fallen: Array[String] = [], deeds: Array[FightResult.Deed] = []) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	result.end_tick = 600
	for hero_id: String in fallen:
		var entry := LogEntry.new()
		entry.kind = LogEntry.Kind.DEATH
		entry.target = hero_id
		result.combat_log.add(entry)
	result.deeds = deeds
	return result


func _setup(flow: RunFlow, formation: Dictionary[String, Vector2i] = Bot.formation()) -> FightSetup:
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(formation, errors)
	assert_eq(errors, [] as Array[String])
	return setup


func _hero_setup(setup: FightSetup, hero_id: String) -> UnitSetup:
	return setup.heroes.filter(func(unit: UnitSetup) -> bool: return unit.id == hero_id)[0]


func test_the_events_load() -> void:
	assert_eq(_run.events.scenes.map(func(scene: EventDef.Scene) -> String: return scene.id), ["kneeling_knight", "rift_merchant", "whispering_stones",
		"bleeding_tear", "old_well", "carrion_birds", "mirror_pool", "ashes_of_a_band"])
	assert_eq(_run.events.oaths.map(func(oath: EventDef.Oath) -> String: return oath.id), ["blood", "silence", "vanguard", "blood_price"])
	assert_eq([_run.events.oath_pct, _run.events.oath_fights], [25, 2], "Decision 43; events.md")
	for scene: EventDef.Scene in _run.events.scenes:
		assert_eq(scene.choices.size(), 2, scene.id)


func test_walking_away_is_free_and_one_choice_an_event() -> void:
	var flow: RunFlow = _at("event:kneeling_knight")
	var before: String = JSON.stringify(flow.state.to_dict())
	assert_eq(flow.leave_node(), "", "walk away")
	assert_eq(flow.state.taken_nodes, ["event:kneeling_knight"] as Array[String])
	flow = _at("event:kneeling_knight")
	assert_eq(flow.choose_event(_choice(flow, "bury")), "")
	assert_eq(flow.choose_event(_choice(flow, "bury")), "the choice is made")
	assert_ne(JSON.stringify(flow.state.to_dict()), before)


func test_the_kneeling_knight() -> void:
	var flow: RunFlow = _at("event:kneeling_knight")
	var take: int = _choice(flow, "take_blade")
	assert_eq(flow.choose_event(take), "choose who or what it's for")
	flow.state.hero("vell").wounds = 3
	assert_eq(flow.event_problem(take, "vell"), "vell can't take another wound")
	assert_eq(flow.choose_event(take, "maren"), "")
	assert_eq(flow.state.hero("maren").wounds, 1)
	assert_eq(flow.state.stash.size(), 1)
	var charm: String = flow.state.stash[0]
	assert_eq([_run.items[charm].kind, flow.state.item_ranks[charm]], [ItemDef.Kind.CHARM, 2], "a charm at rank II")
	flow = _at("event:kneeling_knight")
	flow.state.hero("brannoc").wounds = 2
	flow.choose_event(_choice(flow, "bury"))
	assert_true(flow.state.heroes.all(func(hero: RunState.Hero) -> bool: return hero.wounds == 0))


func test_the_rift_merchant() -> void:
	var flow: RunFlow = _at("event:rift_merchant")
	flow.choose_event(_choice(flow, "take_relic"))
	assert_eq(flow.state.relics.size(), 1)
	assert_eq(_run.relics[flow.state.relics[0]].tier, RelicDef.Tier.EPIC)
	R.to_pedlar(flow)
	assert_eq(flow.price_of("fleet"), 9, "the next shop: 50% more")
	assert_eq(flow.state.dear_shop_bp, 0, "only the next")
	R.to_pedlar(flow)
	assert_eq(flow.price_of("fleet"), 6)
	flow = _at("event:rift_merchant")
	flow.state.shards = 9
	assert_eq(flow.event_problem(_choice(flow, "leave_coin")), "it costs 10 shards; there are 9")
	flow.state.shards = 12
	assert_eq(flow.choose_event(_choice(flow, "leave_coin")), "")
	assert_eq([flow.state.shards, _run.relics[flow.state.relics[0]].tier], [2, RelicDef.Tier.RARE])


func test_whispering_stones() -> void:
	var flow: RunFlow = _at("event:whispering_stones")
	var threshold: int = _run.content.paths["deadeye"].deed.threshold
	assert_eq(flow.choose_event(_choice(flow, "listen"), "maren"), "")
	assert_eq(flow.state.hero("maren").deeds["deadeye"], FixedMath.apply_bp(threshold, 3333), "a third of the threshold")
	flow.leave_node()
	flow.choose_fight(0)
	assert_null(_hero_setup(_setup(flow), "maren").def.signature, "no signature in the next fight")
	assert_not_null(_hero_setup(_setup(flow), "vell").def.signature)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq(flow.state.hero("maren").next_fight, [] as Array[String], "spent once won")
	flow = _at("event:whispering_stones")
	flow.state.hero("maren").deeds["deadeye"] = threshold - 10
	flow.choose_event(_choice(flow, "listen"), "maren")
	assert_eq(flow.state.hero("maren").deeds["deadeye"], threshold, "never past the threshold")
	flow = _at("event:whispering_stones")
	flow.state.hero("maren").transformed = true
	assert_eq(flow.event_problem(_choice(flow, "listen"), "maren"), "maren has transformed")
	assert_eq(flow.choose_event(_choice(flow, "smash")), "")
	assert_eq(flow.state.shards, 38)


func test_a_bleeding_tear() -> void:
	var flow: RunFlow = _at("event:bleeding_tear")
	flow.choose_event(_choice(flow, "reach_in"))
	assert_eq(flow.state.relics.size(), 1)
	assert_ne(_run.relics[flow.state.relics[0]].tier, RelicDef.Tier.BOSS)
	flow = _at("event:bleeding_tear")
	var shards: int = flow.state.shards
	assert_eq(flow.choose_event(_choice(flow, "seal")), "")
	assert_eq(flow.leave_node(), "")
	var state: RunState = flow.state
	var sealed: String = state.options[1][0]
	assert_eq([state.day, state.phase, state.fought.back().encounter, state.fought.back().seconds], [2, RunState.Phase.AFTER, sealed, 0], "tomorrow's fight, won without fighting")
	assert_eq(state.shards, shards + _run.acts[0].pay[_run.content.encounters[sealed].tier] / 2, "half its pay")
	assert_false(state.pick.is_empty(), "and its pick")
	assert_eq(_at("event:bleeding_tear", 2).event_problem(1), "not before an elite or the boss", "day 3 is an elite day")


func test_the_old_well() -> void:
	var flow: RunFlow = _at("event:old_well")
	assert_eq(flow.event_problem(_choice(flow, "drink")), "no item of yours can go a rank up")
	flow._gain_item("fleet")
	assert_eq(flow.choose_event(_choice(flow, "drink")), "")
	assert_eq(flow.state.item_ranks["fleet"], 2)
	var weakened: Array = flow.state.heroes.filter(func(hero: RunState.Hero) -> bool: return hero.weakened == 1)
	assert_eq(weakened.size(), 1, "a random hero")
	var hero_id: String = (weakened[0] as RunState.Hero).id
	flow.leave_node()
	flow.choose_fight(0)
	assert_eq(_hero_setup(_setup(flow), hero_id).def.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(flow.kit_of(hero_id).stats.get_stat(UnitStats.Stat.HP), 9000), "10% less max HP")
	flow = _at("event:old_well")
	flow._gain_item("fleet")
	assert_eq(flow.choose_event(_choice(flow, "coin"), "echo"), "echo can't go a rank up")
	assert_eq(flow.choose_event(_choice(flow, "coin"), "fleet"), "")
	assert_eq([flow.state.item_ranks["fleet"], flow.state.shards], [2, 25])


func test_carrion_birds() -> void:
	var flow: RunFlow = _at("event:carrion_birds")
	assert_eq(flow.choose_event(_choice(flow, "drive_off")), "")
	assert_eq(_run.content.encounters[flow.state.hunt].tier, "hunt")
	assert_eq(flow.leave_node(), "fight the Hunt first")
	assert_eq(flow.fight_encounter(), flow.state.hunt)
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq([flow.state.losses, flow.leave_node()], [0, ""], "a lost Hunt isn't a loss")


func test_the_mirror_pool() -> void:
	var flow: RunFlow = _at("event:mirror_pool")
	var look: int = _choice(flow, "look_in")
	var maren: RunState.Hero = flow.state.hero("maren")
	maren.deeds["deadeye"] = 600
	assert_eq(flow.event_problem(look, "maren:deadeye"), "maren can't take \"deadeye\"")
	assert_eq(flow.choose_event(look, "maren:trapper"), "")
	assert_eq(maren.path, "trapper")
	assert_eq(maren.deeds["trapper"], 600 * _run.content.paths["trapper"].deed.threshold / _run.content.paths["deadeye"].deed.threshold / 2, "half its share")
	flow = _at("event:mirror_pool")
	for hero: RunState.Hero in flow.state.heroes:
		hero.transformed = true
	assert_eq(flow.event_problem(look), "no one it fits", "greyed: no hero to take")


func test_ashes_of_a_band() -> void:
	var flow: RunFlow = _at("event:ashes_of_a_band")
	flow.choose_event(_choice(flow, "search"))
	assert_eq(flow.state.stash.size(), 2)
	for id: String in flow.state.stash:
		assert_has([ItemDef.Kind.CHARM, ItemDef.Kind.TACTIC, ItemDef.Kind.SIGIL], _run.items[id].kind)
	flow = _at("event:ashes_of_a_band")
	flow.state.hero("vell").wounds = 2
	flow.choose_event(_choice(flow, "names"))
	assert_eq(flow.state.hero("vell").wounds, 0)
	flow.leave_node()
	flow.choose_fight(0)
	var setup: FightSetup = _setup(flow)
	for hero: RunState.Hero in flow.state.heroes:
		assert_eq(_hero_setup(setup, hero.id).def.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(flow.kit_of(hero.id).stats.get_stat(UnitStats.Stat.HP), 10500), "+5% max HP next fight")


func test_the_bloodied_oath() -> void:
	var flow: RunFlow = _at("oath")
	var offer: Array[String] = flow.state.oath_offer
	assert_eq(offer.size(), 2)
	assert_ne(offer[0].get_slice(":", 0), offer[1].get_slice(":", 0), "two different oaths")
	assert_ne(offer[0].get_slice(":", 1), offer[1].get_slice(":", 1), "on two different heroes")
	assert_eq(flow.take_oath(2), "there's no oath 2")
	assert_eq(flow.take_oath(0), "")
	assert_eq(flow.take_oath(1), "an oath is taken")
	var hero: RunState.Hero = flow.state.hero(offer[0].get_slice(":", 1))
	assert_eq([hero.oath, hero.oath_fights], [offer[0].get_slice(":", 0), 2])
	assert_eq(_at("oath").leave_node(), "", "passing is free")


## A flow at the next day fight with `hero_id` sworn to `oath_id`.
func _sworn(oath_id: String, hero_id: String) -> RunFlow:
	var flow: RunFlow = _start()
	flow.state.hero(hero_id).oath = oath_id
	flow.state.hero(hero_id).oath_fights = 2
	flow.choose_fight(0)
	return flow


func test_each_oath() -> void:
	# Blood: less max HP, deeds doubled.
	var flow: RunFlow = _sworn("blood", "maren")
	assert_eq(_hero_setup(_setup(flow), "maren").def.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(flow.kit_of("maren").stats.get_stat(UnitStats.Stat.HP), 7500))
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT, [] as Array[String], [FightResult.Deed.make("maren", "deadeye", 100), FightResult.Deed.make("vell", "lanternbearer", 5)] as Array[FightResult.Deed]))
	assert_eq([flow.state.hero("maren").deeds["deadeye"], flow.state.hero("vell").deeds["lanternbearer"]], [200, 5], "its deeds count double")
	assert_eq(flow.state.hero("maren").oath_fights, 1, "a lost fight counts")
	flow.choose_fight(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq([flow.state.hero("maren").oath, flow.state.hero("maren").oath_fights], ["", 0], "two day fights, then it's done")
	# Silence: no signature, more ATK.
	flow = _sworn("silence", "vell")
	var vell: UnitDef = _hero_setup(_setup(flow), "vell").def
	assert_null(vell.signature)
	assert_eq(vell.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(flow.kit_of("vell").stats.get_stat(UnitStats.Stat.ATK), 12000))
	# The Vanguard: the front row, no tactic, +20 DEF.
	flow = _sworn("vanguard", "brannoc")
	flow._gain_item("plant_feet_orders")
	flow.equip("brannoc", 0, "plant_feet_orders")
	var front: int = flow.front_row()
	var formation: Dictionary[String, Vector2i] = Bot.formation()
	var errors: Array[String] = []
	formation["brannoc"] = Vector2i(formation["brannoc"].x, front - 1)
	assert_null(flow.fight_setup(formation, errors))
	assert_has(errors, "brannoc is sworn to the front row (Oath of the Vanguard)")
	formation["brannoc"] = Vector2i(0, front)
	var brannoc: UnitSetup = _hero_setup(_setup(flow, formation), "brannoc")
	assert_null(brannoc.tactic, "its tactic set aside")
	assert_eq(brannoc.def.stats.get_stat(UnitStats.Stat.DEF), flow.kit_of("brannoc").stats.get_stat(UnitStats.Stat.DEF) + 20)
	# Blood Price: a fall is 2 wounds.
	flow = _sworn("blood_price", "maren")
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT, ["maren", "vell"] as Array[String]))
	assert_eq([flow.state.hero("maren").wounds, flow.state.hero("vell").wounds], [2, 1])


func test_a_hunt_isnt_an_oath_fight() -> void:
	var flow: RunFlow = _start()
	flow.state.hero("maren").oath = "blood"
	flow.state.hero("maren").oath_fights = 2
	R.to_camp(flow, ["hunt"] as Array[String])
	flow.choose_camp(0)
	var setup: FightSetup = _setup(flow)
	assert_eq(_hero_setup(setup, "maren").def.stats.get_stat(UnitStats.Stat.HP), flow.kit_of("maren").stats.get_stat(UnitStats.Stat.HP), "no burden on a Hunt")
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq(flow.state.hero("maren").oath_fights, 2)


func test_the_nodes_a_day_shows() -> void:
	var oaths: int = 0
	var two_events: int = 0
	var seen: Dictionary[String, bool] = {}
	for run_seed: int in range(1, 41):
		var state: RunState = _start(run_seed).state
		for day: int in range(1, 7):
			state.day = day
			var nodes: Array[String] = Offers.nodes(_run, state)
			assert_eq(nodes.size(), 3, "Camp and two more (Decision 41)")
			assert_eq(nodes[0], "camp")
			assert_lte(nodes.count("oath"), 1, "one oath a day at most")
			var events: Array = nodes.filter(func(node: String) -> bool: return node.begins_with("event:") or node == "oath")
			two_events += 1 if events.size() == 2 else 0
			for node: String in nodes:
				assert_eq(nodes.count(node), 1, "no node twice")
				seen[node] = true
				oaths += 1 if node == "oath" else 0
	assert_gt(two_events, 0, "two events can show")
	assert_gt(oaths, 0)
	for scene: EventDef.Scene in _run.events.scenes:
		assert_true(seen.has("event:" + scene.id), scene.id)


func test_the_events_state_saves() -> void:
	var flow: RunFlow = _at("oath")
	flow.take_oath(0)
	flow.state.hero("vell").weakened = 1
	flow.state.hero("vell").next_fight.assign(["silenced"])
	flow.state.dear_shop_bp = 15000
	flow.state.sealed = true
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(flow.state.to_dict()))
	assert_eq([loaded.event_done, loaded.oath_offer, loaded.sealed, loaded.hero("vell").next_fight], [true, flow.state.oath_offer, true, ["silenced"]])
