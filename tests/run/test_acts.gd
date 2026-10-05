extends GutTest
## Acts 2 and 3's frame (docs/plans/rebuild-phase8-acts.md, part 8c-1), on a
## stand-in content set: Act 2 and Act 3 draw Act 1's fights (fights_act),
## and Act 3 has real endless. Moving on after the boss shop, what an act
## starts afresh and what carries (losses too), the apex vow after Act 1,
## the testing option, endless after the last act, the save, and the
## records by act.

const Bot = preload("res://tools/run_bot.gd")
const RunReport = preload("res://tools/run_report.gd")
const RECORDS_PATH: String = "user://test_act_records.json"

var _run: RunContent


## The real data, with act2.json and act3.json as stand-ins made from Act 1:
## no endless after Act 2, and Act 3's not a testing option.
static func stand_in_acts() -> RunContent:
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var act1: Dictionary = JSON.parse_string(texts[RunContent.ACT_FILE])
	var act2: Dictionary = act1.duplicate(true)
	act2["act"] = 2
	act2["fights_act"] = 1
	act2.erase("endless")
	var act3: Dictionary = act1.duplicate(true)
	act3["act"] = 3
	act3["fights_act"] = 1
	(act3["endless"] as Dictionary).erase("testing")
	texts["act2.json"] = JSON.stringify(act2)
	texts["act3.json"] = JSON.stringify(act3)
	return RunContent.load_texts(texts, ContentDb.load_dir("res://data"))


func before_all() -> void:
	_run = stand_in_acts()


func after_each() -> void:
	if FileAccess.file_exists(RECORDS_PATH):
		DirAccess.remove_absolute(RECORDS_PATH)


func _start(testing: bool = false) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, Bot.first_vows(_run.content), errors, testing)
	assert_eq(errors, [] as Array[String])
	return flow


func _result(outcome: FightResult.Outcome) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	result.end_tick = 600
	return result


## Wins today's fight and settles what's waiting after it.
func _win_today(flow: RunFlow) -> void:
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	if not flow.state.pick.is_empty():
		flow.take_shards()
	if not flow.state.relic_choice.is_empty():
		flow.decline_relic()


## Plays the run's act through its boss shop (each day's node: camp).
func _finish_act(flow: RunFlow) -> void:
	var act: int = flow.state.act
	for day: int in range(1, flow.act.days.size()):
		assert_eq([flow.state.act, flow.state.day], [act, day])
		_win_today(flow)
		assert_eq(flow.finish_day(), "")
		assert_eq(flow.leave_shop(), "")
		assert_eq(flow.choose_node(flow.state.nodes.find("camp")), "")
		assert_eq(flow.leave_node(), "")
	_win_today(flow)
	assert_eq(flow.finish_day(), "")
	assert_true(flow.boss_shop())
	assert_eq(flow.leave_shop(), "")


func test_the_acts_load_in_order() -> void:
	assert_eq(_run.errors, [] as Array[String])
	assert_eq(_run.acts.map(func(act: ActDef) -> int: return act.act), [1, 2, 3])
	assert_eq(_run.acts.map(func(act: ActDef) -> int: return act.fights_act), [1, 1, 1])
	var state := RunState.new()
	state.act = 2
	assert_eq(_run.act_of(state), _run.acts[1])
	assert_eq(_run.next_act(state), _run.acts[2])
	state.act = 3
	assert_null(_run.next_act(state))
	var real: RunContent = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))
	assert_eq(real.acts.size(), 2, "Act 1 and the Glassmere (8c-4b); Act 3 comes later")
	assert_true(real.acts[0].endless.testing, "Act 1's endless is the testing option (Decision 15)")
	assert_null(real.acts[1].endless, "endless follows Act 3")
	assert_eq([real.acts[1].specialized_from_day, real.acts[1].specialized_share_pct], [3, 50], "specialized from day 3, half of each fight (Decision 1 of the Act 2 plan)")
	assert_eq(real.acts[0].specialized_from_day, 0, "Act 1 specializes none")


func test_an_act_file_must_say_its_number() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var act2: Dictionary = JSON.parse_string(texts[RunContent.ACT_FILE])
	act2["fights_act"] = 5
	texts["act2.json"] = JSON.stringify(act2)
	var run: RunContent = RunContent.load_texts(texts, ContentDb.load_dir("res://data"))
	assert_true(run.errors.has("act2.json: \"act\" must be 2"), str(run.errors))
	assert_true(run.errors.any(func(error: String) -> bool: return error.contains("fights_act 5 isn't an act")), str(run.errors))


func test_the_boss_shop_leads_on_to_the_next_act() -> void:
	var flow: RunFlow = _start()
	var act1_options: Array[Array] = flow.state.options.duplicate(true)
	_finish_act(flow)
	var state: RunState = flow.state
	assert_eq([state.act, state.day, state.attempt, state.phase], [2, 1, 0, RunState.Phase.ROUTE], "Act 2's day 1 route, with no choice (not a testing run)")
	assert_eq(state.options, ActDraw.draw(_run, 7, _run.acts[1]), "Act 2's fights, drawn as it starts")
	assert_ne(state.options, act1_options, "drawn afresh for the act")
	assert_true(state.apex_open, "the apex vow opens after Act 1's boss (Decision 2)")
	assert_eq([state.taken_nodes, state.scouted, state.magpie_visits], [[] as Array[String], [] as Array[int], 0], "what an act keeps starts again")
	assert_true(state.fought.all(func(fought: RunState.Fought) -> bool: return fought.act == 1))
	_win_today(flow)
	assert_eq([state.fought.back().act, state.fought.back().day], [2, 1], "a fight knows its act")


func test_what_carries_into_the_next_act() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.hero("maren").weakened = 2
	state.hero("brannoc").wounds = 1
	state.losses = 1
	state.magpie_visits = 2
	state.relics.append(_run.relic_ids[0])
	_finish_act(flow)
	assert_eq(state.act, 2)
	assert_eq(state.losses, 1, "losses carry (Decision 11)")
	assert_eq(state.hero("maren").weakened, 0, "The Old Well's cut lasts the act")
	assert_eq(state.relics.has(_run.relic_ids[0]), true)
	assert_eq(state.magpie_visits, 0)
	# One more loss, in Act 2, ends the run.
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq([state.phase, state.outcome], [RunState.Phase.ENDED, RunState.Outcome.LOST], "any two losses end the run")


func test_a_testing_run_chooses_after_act_1() -> void:
	var plain: RunFlow = _start()
	_finish_act(plain)
	assert_eq(plain.state.act, 2, "a plain run doesn't stop at Act 1's endless")
	var flow: RunFlow = _start(true)
	_finish_act(flow)
	assert_eq([flow.state.act, flow.state.phase], [1, RunState.Phase.CHOICE])
	assert_true(flow.can_go_deeper())
	assert_eq(flow.next_act(), "")
	assert_eq([flow.state.act, flow.state.day, flow.state.phase], [2, 1, RunState.Phase.ROUTE])
	assert_eq(flow.go_deeper(), "can't go deeper now (the day is at route)")
	var deeper: RunFlow = _start(true)
	_finish_act(deeper)
	assert_eq(deeper.go_deeper(), "")
	assert_eq([deeper.state.act, deeper.floor_number()], [1, 1], "the testing option: Act 1's floors")


func test_endless_follows_the_last_act() -> void:
	var flow: RunFlow = _start()
	_finish_act(flow)
	_finish_act(flow)
	assert_eq(flow.state.act, 3, "no endless after Act 2: straight on")
	_finish_act(flow)
	assert_eq([flow.state.act, flow.state.phase], [3, RunState.Phase.CHOICE], "real endless after Act 3, testing or not")
	assert_eq(flow.next_act(), "this is the last act")
	assert_eq(flow.go_deeper(), "")
	assert_eq([flow.state.day, flow.floor_number()], [8, 1])
	assert_true(_run.floor_pool(flow.state, "normal").has(flow.state.today()[0]), "drawn from Act 3's fights")


func test_the_save_keeps_the_act_and_an_older_save_still_loads() -> void:
	var flow: RunFlow = _start(true)
	_finish_act(flow)
	flow.next_act()
	_win_today(flow)
	var data: Dictionary = JSON.parse_string(JSON.stringify(flow.state.to_dict()))
	assert_eq(int(data["version"]), RunState.VERSION)
	var loaded: RunState = RunState.from_dict(data)
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(flow.state.to_dict()))
	assert_eq([loaded.act, loaded.testing, loaded.fought.back().act], [2, true, 2])
	data["version"] = 6
	data.erase("testing")
	data["endless"] = true
	assert_true(RunState.from_dict(data).testing, "a version 6 save that went deeper went deeper after Act 1: a testing run")
	data["endless"] = false
	assert_false(RunState.from_dict(data).testing)


func test_the_records_keep_each_acts_endless_apart() -> void:
	var state := RunState.new()
	state.heroes.append(RunState.Hero.new())
	state.heroes[0].id = "maren"
	state.heroes[0].path = "deadeye"
	assert_true(RunRecords.note(state, 6, RECORDS_PATH))
	state.act = 3
	assert_true(RunRecords.note(state, 2, RECORDS_PATH), "after Act 3 is its own record")
	assert_eq([int(RunRecords.best(RECORDS_PATH, 1)["floor"]), int(RunRecords.best(RECORDS_PATH, 3)["floor"])], [6, 2])
	assert_false(RunRecords.note(state, 1, RECORDS_PATH))
	var file := FileAccess.open(RECORDS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"floor": 9, "seed": 4, "vows": {}}))
	file.close()
	assert_eq(int(RunRecords.best(RECORDS_PATH, 1)["floor"]), 9, "an older file's one record is Act 1's")
	assert_eq(RunRecords.best(RECORDS_PATH, 3), {})


## Seed 38 is one the simple bot wins through all three stand-in acts (of
## seeds 1-40, the only one past Act 1); if Act 1's tuning changes, find
## another.
func test_a_bot_plays_through_the_acts() -> void:
	var errors: Array[String] = []
	var flow: RunFlow = Bot.play(_run, 38, errors)
	assert_eq(errors, [] as Array[String])
	assert_eq([flow.state.act, flow.state.phase, flow.state.outcome], [3, RunState.Phase.ENDED, RunState.Outcome.WON], "won Act 3, and ended at the endless choice")
	assert_true(flow.state.fought.any(func(fought: RunState.Fought) -> bool: return fought.act == 2))


func test_the_records_keep_the_furthest_act() -> void:
	var state := RunState.new()
	state.act = 2
	state.day = 3
	assert_eq(RunRecords.furthest(RECORDS_PATH), {})
	assert_true(RunRecords.note_furthest(state, RECORDS_PATH))
	state.day = 2
	assert_false(RunRecords.note_furthest(state, RECORDS_PATH), "not as far")
	state.act = 1
	state.day = 7
	assert_false(RunRecords.note_furthest(state, RECORDS_PATH), "an earlier act")
	state.act = 3
	state.day = 1
	assert_true(RunRecords.note(state, 4, RECORDS_PATH), "an endless record beside it")
	assert_true(RunRecords.note_furthest(state, RECORDS_PATH))
	assert_eq([int(RunRecords.furthest(RECORDS_PATH)["act"]), int(RunRecords.furthest(RECORDS_PATH)["day"])], [3, 1])
	assert_eq(int(RunRecords.best(RECORDS_PATH, 3)["floor"]), 4, "the furthest doesn't touch the floors")


func test_the_run_report_by_act() -> void:
	var lines: Array[RunReport.RunLine] = []
	for i: int in 3:
		var line := RunReport.RunLine.new()
		line.bot = "simple"
		lines.append(line)
	lines[0].act = 1
	lines[0].day = 4
	lines[0].outcome = RunState.Outcome.LOST
	lines[1].act = 2
	lines[1].day = 6
	lines[1].outcome = RunState.Outcome.LOST
	lines[1].apexed_act["maren"] = 2
	lines[1].apexed_day["maren"] = 5
	lines[1].apexed_on["maren"] = 0
	lines[2].act = 3
	lines[2].day = 7
	lines[2].outcome = RunState.Outcome.WON
	lines[2].apexed_act["vell"] = 2
	lines[2].apexed_day["vell"] = 5
	lines[2].apexed_on["vell"] = 0
	var text: String = RunReport.acts_summary(_run, lines)
	assert_string_contains(text, "Act 1: 3 reached, 2 won (66%); lost on days 1-7: 0 0 0 1 0 0 0; apexes earned 0")
	assert_string_contains(text, "Act 2: 2 reached, 1 won (50%); lost on days 1-7: 0 0 0 0 0 1 0; apexes earned 2 (median day 5); at its boss 1, 1 with an apex", "Act 2's boss: only the run that went on to Act 3 reached it, with Vell's apex from day 5")
	assert_string_contains(text, "Act 3: 1 reached, 1 won (100%)")
	assert_string_contains(RunReport.summary(_run, lines), "By act")


func test_the_run_report_apex_vows() -> void:
	var lines: Array[RunReport.RunLine] = []
	for i: int in 3:
		var line := RunReport.RunLine.new()
		line.bot = "simple"
		line.apex_vowed["maren"] = "eagle_eye"
		lines.append(line)
	lines[0].apexes["maren"] = "eagle_eye"
	lines[0].apexed_act["maren"] = 2
	lines[0].apexed_day["maren"] = 4
	lines[0].apex_filled["maren"] = 100
	lines[1].apex_filled["maren"] = 50
	lines[2].apex_filled["maren"] = 80
	lines[2].apex_vowed["vell"] = "dawnbringer"
	lines[2].apex_filled["vell"] = 10
	for line: RunReport.RunLine in lines:
		line.apex_fights["maren"] = 4
	lines[0].apex_amount["maren"] = 2
	lines[1].apex_amount["maren"] = 1
	lines[2].apex_amount["maren"] = 1
	var text: String = RunReport.apex_vows_summary(_run, lines)
	assert_string_contains(text, "Eagle Eye")
	var threshold: int = _run.content.apexes["eagle_eye"].deed.threshold
	assert_string_contains(text, "vowed   3, earned   1 (2-4); short   2 at 80%%; 0.2 a fight, %.1f fights (threshold %d)" % [threshold / 0.2, threshold],
		"the median of 50 and 80 is the upper one; a deed of 1 or 2 over 4 fights")
	assert_string_contains(text, "vowed   1, earned   0 (-); short   1 at 10%; 0.0 a fight, - fights", "no fights counted")
	assert_false(text.contains("Stormline"), "an apex no run vowed isn't listed")

