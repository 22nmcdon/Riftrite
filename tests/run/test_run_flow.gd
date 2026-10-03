extends GutTest
## The run layer (docs/plans/rebuild-phase5-run.md, sections 1-3): the act
## draw, starting a run, the day's actions and their order, winning, losing
## and replays, wounds and deeds, saving and loading, and the simple run bot.

const Bot = preload("res://tools/run_bot.gd")
const R = preload("res://tests/run/run_test_kit.gd")
const SAVE_PATH: String = "user://test_rift_run.json"

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func after_all() -> void:
	RunSave.erase(SAVE_PATH)


func _start(run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


## A result with `outcome` in which `fallen` fell.
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


func test_the_run_content_loads() -> void:
	assert_true(_run.is_valid(), "\n".join(_run.errors))
	assert_eq(_run.acts[0].days, ["normal", "normal", "elite", "normal", "elite", "normal", "boss"] as Array[String])
	assert_eq([_run.acts[0].start_shards, _run.acts[0].slots, _run.acts[0].losses_to_end, _run.acts[0].pay["easier"]], [10, 3, 2, 10], "economy.md (phase 5c step 5a)")


func test_the_act_draw() -> void:
	var days: Array[Array] = ActDraw.draw(_run, 7)
	assert_eq(days.size(), 7)
	for day: int in range(1, 8):
		var options: Array = days[day - 1]
		assert_between(options.size(), 1, 2)
		if options.size() == 2:
			assert_ne(options[0], options[1], "day %d offers two different fights" % day)
		for id: String in options:
			assert_true(_run.content.encounters[id].days.has(day) or _run.acts[0].days[day - 1] != "normal", "%s can come on day %d" % [id, day])
	assert_eq(ActDraw.draw(_run, 7), days, "the same seed, the same act")
	assert_ne(ActDraw.draw(_run, 8), days, "another seed, another act")


func test_starting_needs_a_vow_for_every_hero() -> void:
	var errors: Array[String] = []
	assert_null(RunFlow.start(_run, 1, {"maren": "deadeye", "brannoc": "deadeye"} as Dictionary[String, String], errors))
	assert_eq(errors, ["brannoc can't vow to \"deadeye\"", "vell needs a vow"] as Array[String])
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	assert_eq(state.heroes.map(func(hero: RunState.Hero) -> String: return hero.path), ["hearthwall", "deadeye", "lanternbearer"])
	assert_eq(state.hero("maren").deeds, {"deadeye": 0, "trapper": 0, "volley": 0} as Dictionary[String, int])
	assert_eq(state.hero("maren").slots, ["", "", ""] as Array[String])
	assert_eq([state.day, state.phase, state.shards], [1, RunState.Phase.ROUTE, 10], "day 1 starts at the route (phase 5c step 8)")


func test_the_day_goes_in_order() -> void:
	var flow: RunFlow = _start()
	var errors: Array[String] = []
	assert_eq(flow.finish_day(), "can't move on from the fight now (the day is at route)")
	assert_eq(flow.leave_shop(), "can't leave the shop now (the day is at route)")
	assert_eq(flow.choose_node(0), "can't choose a node now (the day is at route)")
	assert_null(flow.fight(Bot.formation(), errors))
	assert_eq(errors, ["can't fight now (the day is at route)"] as Array[String])
	assert_eq(flow.choose_fight(2), "there's no fight 2 today")
	assert_eq(flow.choose_fight(1), "")
	assert_eq(flow.state.chosen, flow.state.today()[1])
	var partial: Dictionary[String, Vector2i] = {"maren": Vector2i(3, 0)}
	errors.clear()
	assert_null(flow.fight_setup(partial, errors))
	assert_has(errors, "brannoc isn't placed")


func test_a_fight_is_the_sims_own_and_a_win_pays() -> void:
	var flow: RunFlow = _start()
	flow.choose_fight(0)
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	var expected: FightResult = CombatSim.run(setup, _run.content)
	var result: FightResult = flow.fight(Bot.formation(), errors)
	assert_eq(result.combat_log.to_text(), expected.combat_log.to_text(), "the fight is CombatSim.run of its setup")
	var state: RunState = flow.state
	if result.outcome == FightResult.Outcome.DEFEAT:
		assert_eq([state.losses, state.attempt, state.phase], [1, 1, RunState.Phase.ROUTE])
		return
	assert_eq(state.shards, _run.acts[0].start_shards + _run.acts[0].pay[_run.content.encounters[state.chosen].tier])
	assert_eq(state.phase, RunState.Phase.AFTER)
	assert_eq(state.hero("maren").deeds["deadeye"], result.deed_amount("maren", "deadeye"), "deeds add what the fight put in")
	assert_eq(state.formation, Bot.formation(), "the formation is remembered")
	assert_eq(state.fought.size(), 1)
	assert_eq(state.pick.size(), 3, "a win offers a pick")
	assert_eq(flow.take_shards(), "")
	assert_eq(flow.finish_day(), "")
	assert_eq([state.day, state.phase, state.shop], [1, RunState.Phase.SHOP, "pedlar"], "then the Pedlar")
	assert_eq(R.next_day(flow), "can't move on from the fight now (the day is at shop)")
	assert_eq(flow.leave_shop(), "")
	assert_eq([state.phase, state.shop, state.nodes[0]], [RunState.Phase.NODES, "", "camp"], "then the nodes")
	assert_eq(flow.choose_node(0), "")
	assert_eq(flow.leave_node(), "")
	assert_eq([state.day, state.attempt, state.chosen, state.phase], [2, 0, "", RunState.Phase.ROUTE])


func test_a_loss_replays_the_day_and_the_second_ends_the_run() -> void:
	var flow: RunFlow = _start()
	flow.choose_fight(0)
	var options: Array[String] = flow.state.today()
	var deed := FightResult.Deed.make("maren", "trapper", 900)
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT, ["maren", "vell"] as Array[String], [deed] as Array[FightResult.Deed]))
	var state: RunState = flow.state
	assert_eq([state.losses, state.attempt, state.day, state.phase, state.shards], [1, 1, 1, RunState.Phase.ROUTE, 10], "no pay; the day again, from the route")
	assert_eq(state.today(), options, "with the same options")
	assert_eq([state.hero("maren").wounds, state.hero("vell").wounds, state.hero("brannoc").wounds], [1, 1, 0], "those who fell are wounded")
	assert_eq(state.hero("maren").deeds["trapper"], 900, "a lost fight's deeds still count")
	var errors: Array[String] = []
	flow.choose_fight(0)
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(setup.heroes[1].max_hp_bp, FixedMath.BP_ONE - _run.content.tuning.wound_bp, "the next fight knows her wound")
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq([state.phase, state.outcome], [RunState.Phase.ENDED, RunState.Outcome.LOST])
	assert_eq(flow.leave_node(), "can't leave the node now (the day is at ended)")


func test_a_tie_pays_like_a_win_and_wounds_stop_at_three() -> void:
	var flow: RunFlow = _start()
	flow.choose_fight(0)
	flow.state.hero("brannoc").wounds = 3
	flow.state.hero("maren").wounds = 2
	flow.record(Bot.formation(), _result(FightResult.Outcome.TIE, ["brannoc"] as Array[String]))
	assert_eq([flow.state.hero("brannoc").wounds, flow.state.hero("maren").wounds, flow.state.hero("vell").wounds], [3, 1, 0],
		"a win (a tie too) heals one wound on each hero, then the fallen take one")
	assert_eq(flow.state.phase, RunState.Phase.AFTER)
	assert_gt(flow.state.shards, 10)
	flow.state.phase = RunState.Phase.LOADOUT
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT, ["brannoc"] as Array[String]))
	assert_eq([flow.state.hero("brannoc").wounds, flow.state.hero("maren").wounds], [3, 1], "a loss heals none, and wounds stop at three")


func test_winning_the_boss_ends_the_run() -> void:
	var flow: RunFlow = _start()
	flow.state.day = 7
	flow.state.phase = RunState.Phase.ROUTE
	flow.choose_fight(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq(flow.state.relic_choice.size(), 3, "a choice of boss relics first (phase 5c Decision 18)")
	for id: String in flow.state.relic_choice:
		assert_eq(_run.relics[id].tier, RelicDef.Tier.BOSS)
	assert_eq(flow.state.pick, [] as Array[String], "no pick after the boss")
	var taken: String = flow.state.relic_choice[0]
	assert_eq(flow.take_relic(0), "")
	assert_true(flow.state.relics.has(taken))
	assert_eq(flow.finish_day(), "")
	assert_eq([flow.state.phase, flow.state.shop], [RunState.Phase.SHOP, "pedlar"], "then the boss shop (phase 5c Decision 48)")
	assert_eq(flow.leave_shop(), "")
	assert_eq([flow.state.phase, flow.state.outcome], [RunState.Phase.ENDED, RunState.Outcome.WON], "the last act, and Act 1's endless only in a testing run (phase 8 part 3)")


func test_saving_and_loading_gives_the_same_run() -> void:
	var flow: RunFlow = _start(11)
	var hexes: Dictionary[String, Vector2i] = Bot.formation()
	var errors: Array[String] = []
	for step: int in 12:
		assert_true(RunSave.save(flow.state, SAVE_PATH))
		var loaded: RunState = RunSave.load_state(SAVE_PATH)
		assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(flow.state.to_dict()), "step %d" % step)
		if flow.state.phase == RunState.Phase.ENDED:
			break
		# Going on from the loaded state gives the same run as going on from the live one.
		var twin: RunFlow = RunFlow.resume(_run, loaded)
		Bot.step_once(flow, hexes, errors)
		Bot.step_once(twin, hexes, errors)
		assert_eq(JSON.stringify(twin.state.to_dict()), JSON.stringify(flow.state.to_dict()))
	assert_eq(errors, [] as Array[String])
	var bad := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	bad.store_string("{\"version\": 99}")
	bad.close()
	assert_null(RunSave.load_state(SAVE_PATH), "another version loads as nothing")


func test_the_bot_plays_runs_to_the_end_the_same_each_time() -> void:
	for run_seed: int in [1, 2, 3]:
		var errors: Array[String] = []
		var flow: RunFlow = Bot.play(_run, run_seed, errors)
		assert_eq(errors, [] as Array[String], "seed %d" % run_seed)
		assert_eq(flow.state.phase, RunState.Phase.ENDED)
		assert_ne(flow.state.outcome, RunState.Outcome.NONE)
		var again: RunFlow = Bot.play(_run, run_seed, errors)
		assert_eq(JSON.stringify(again.state.to_dict()), JSON.stringify(flow.state.to_dict()), "seed %d plays the same run twice" % run_seed)
