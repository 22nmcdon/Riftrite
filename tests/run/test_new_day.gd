extends GutTest
## The new day (docs/plans/rebuild-phase5c-combos.md, step 8a, section 16;
## days-and-nodes.md): the route, the fight, after it, the Pedlar after every
## fight, then a node (Camp always, Rift Tear, the Magpie); the boss's day
## (its pay, its relics, then the boss shop: Decision 48); a loss replaying the day with the node's setup held
## (Decision 42); the node draw (Decision 41); and the save.

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


func _result(outcome: FightResult.Outcome) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	result.end_tick = 600
	return result


## Wins today's first fight and settles what's waiting after it.
func _win_today(flow: RunFlow) -> void:
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	if not flow.state.pick.is_empty():
		flow.take_shards()
	if not flow.state.relic_choice.is_empty():
		flow.decline_relic()


func test_the_pedlar_after_every_fight_and_the_boss_shop() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	for day: int in range(1, 7):
		assert_eq([state.day, state.phase], [day, RunState.Phase.ROUTE])
		_win_today(flow)
		assert_eq(flow.finish_day(), "")
		assert_eq([state.phase, state.shop], [RunState.Phase.SHOP, "pedlar"], "day %d's shop" % day)
		assert_false(flow.boss_shop(), "a plain Pedlar the day before the boss's too (Decision 48; day %d)" % day)
		assert_eq(flow.leave_shop(), "")
		assert_eq(flow.choose_node(state.nodes.find("camp")), "")
		assert_eq(flow.leave_node(), "")
	assert_eq(state.taken_nodes.size(), 6, "a node a day before the boss's")
	assert_true(state.taken_nodes.all(func(node: String) -> bool: return node.begins_with("camp:")))
	# The boss's day: the fight, its pay, and its relic choice, then the boss
	# shop, then the run's end (Decision 48).
	var shards: int = state.shards
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq(state.shards - shards, 60, "the boss pays 60")
	assert_eq([state.phase, state.relic_choice.size()], [RunState.Phase.AFTER, _run.acts[0].boss_relics])
	assert_eq(flow.finish_day(), "choose a relic or neither first", "the boss relics before the shop")
	assert_eq(flow.take_relic(0), "")
	assert_eq(flow.finish_day(), "")
	assert_eq([state.phase, state.shop], [RunState.Phase.SHOP, "pedlar"])
	assert_true(flow.boss_shop())
	assert_eq(_run.relics[state.shop_relics[0]].tier, RelicDef.Tier.LEGENDARY)
	assert_eq(flow.leave_shop(), "")
	# The last act's boss shop ends the run won (Act 1's endless is only for
	# a testing run: phase 8 part 3).
	assert_eq([state.phase, state.outcome, state.shop], [RunState.Phase.ENDED, RunState.Outcome.WON, ""])


func test_a_node_waits_for_what_it_opened() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.phase = RunState.Phase.NODES
	state.nodes.assign(["camp", "magpie"])
	assert_eq(flow.choose_node(2), "there's no node 2")
	assert_eq(flow.choose_node(0), "")
	assert_eq(flow.choose_node(1), "can't choose a node now (the day is at node)", "one node a day")
	state.camp.assign(["train"])
	flow.choose_camp(0)
	assert_eq(flow.leave_node(), "choose an upgrade or take the shards first")
	flow.take_shards()
	assert_eq(flow.leave_node(), "")
	assert_eq([state.day, state.phase, state.node, state.nodes, state.camp_used], [2, RunState.Phase.ROUTE, "", [] as Array[String], ""])


func test_a_loss_replays_the_day_with_the_nodes_setup_held() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	R.to_camp(flow, ["fortify"] as Array[String])
	flow.choose_camp(0)
	flow.leave_node()
	assert_eq([state.day, state.fortify], [2, true], "for tomorrow's fight")
	flow.choose_fight(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq([state.day, state.attempt, state.phase, state.chosen], [2, 1, RunState.Phase.ROUTE, ""], "the day again, from the route")
	assert_true(state.fortify, "Fortify holds for the replay (Decision 42)")
	flow.choose_fight(1)
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_true(setup.heroes.all(func(hero: UnitSetup) -> bool: return hero.def.passives.any(func(part: PartDef) -> bool: return part.id == "fortified")))
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_false(state.fortify, "spent once won")
	# A Rift Tear holds too.
	flow.take_shards()
	flow.finish_day()
	flow.leave_shop()
	state.nodes.assign(["camp", "rift_tear"])
	flow.choose_node(1)
	assert_eq(flow.leave_node(), "choose a depth first")
	flow.choose_depth(1)
	var mods: Array[String] = state.rift_mods.duplicate()
	flow.leave_node()
	flow.choose_fight(0)
	state.losses = 0
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq([state.rift_depth, state.rift_mods], ["deep", mods], "still torn, as deep, for the replay")


func test_the_node_draw() -> void:
	var seen: Dictionary[String, int] = {}
	for run_seed: int in range(1, 41):
		var flow: RunFlow = _start(run_seed)
		var state: RunState = flow.state
		for day: int in range(1, 7):
			state.day = day
			var nodes: Array[String] = Offers.nodes(_run, state)
			assert_eq(nodes[0], "camp", "Camp always (Decision 41)")
			assert_eq(nodes.size(), 3, "Camp and two more (an Event takes a repeat's place, step 8c)")
			for node: String in nodes:
				seen[node] = seen.get(node, 0) + 1
				assert_eq(nodes.count(node), 1, "no node twice")
			if day < _run.camps.magpie_from_day:
				assert_false(nodes.has("magpie"), "no Magpie before day %d" % _run.camps.magpie_from_day)
			assert_eq(Offers.nodes(_run, state), nodes, "the same state, the same nodes")
		state.day = 4
		state.magpie_visits = _run.camps.magpie_per_act
		for day: int in range(3, 7):
			state.day = day
			assert_false(Offers.nodes(_run, state).has("magpie"), "at most %d Magpies an act" % _run.camps.magpie_per_act)
	assert_gt(seen.get("rift_tear", 0), 0)
	assert_gt(seen.get("magpie", 0), 0)


func test_the_magpie_counts_his_visits() -> void:
	var flow: RunFlow = _start()
	R.to_magpie(flow)
	assert_eq(flow.state.magpie_visits, 1)
	assert_eq(flow.leave_node(), "")
	assert_eq(flow.state.taken_nodes, ["magpie"] as Array[String])


func test_the_new_days_state_saves() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	R.to_magpie(flow)
	flow.leave_node()
	_win_today(flow)
	flow.finish_day()
	flow.leave_shop()
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(state.to_dict()))
	assert_eq([loaded.phase, loaded.nodes, loaded.taken_nodes, loaded.magpie_visits], [RunState.Phase.NODES, state.nodes, ["magpie"] as Array[String], 1])
	flow.choose_node(0)
	loaded = RunState.from_dict(JSON.parse_string(JSON.stringify(state.to_dict())))
	assert_eq([loaded.phase, loaded.node], [RunState.Phase.NODE, "camp"])
