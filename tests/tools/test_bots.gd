extends GutTest
## Phase 6's bots (docs/plans/rebuild-phase6-bot-tuning.md, section 2): each
## plays whole runs through RunPlayer without a refused action, and a run
## repeats from its seed; and the run report's run lines survive --jobs.

const RunPlayer = preload("res://tools/bots/run_player.gd")
const Report = preload("res://tools/run_report.gd")
const Placement = preload("res://tools/bots/placement.gd")
const Practice = preload("res://tools/bots/practice.gd")
const GoodBot = preload("res://tools/bots/good_bot.gd")
const ExpertBot = preload("res://tools/bots/expert_bot.gd")
const Simple = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _vows(run_seed: int) -> Dictionary[String, String]:
	var vows: Dictionary[String, String] = {}
	vows.assign(Report.vow_combinations(_run.content)[run_seed % 27])
	return vows


func _play(bot_name: String, run_seed: int) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunPlayer.play(_run, run_seed, Report.make_bot(bot_name), _vows(run_seed), errors)
	assert_eq(errors, [] as Array[String], "%s, seed %d" % [bot_name, run_seed])
	assert_eq(flow.state.phase, RunState.Phase.ENDED, "%s, seed %d ends" % [bot_name, run_seed])
	return flow


func test_each_bot_plays_runs_to_their_end_and_repeats() -> void:
	# The good bot and the expert take about a minute a run; they're played
	# to day 3 below instead.
	for bot_name: String in ["simple", "simple-peek", "random"]:
		for run_seed: int in [3, 8]:
			var first: RunFlow = _play(bot_name, run_seed)
			var again: RunFlow = _play(bot_name, run_seed)
			assert_eq(JSON.stringify(again.state.to_dict()), JSON.stringify(first.state.to_dict()), "%s, seed %d repeats" % [bot_name, run_seed])


func test_each_bot_drafts_a_team() -> void:
	# Phase 8 part 4 (8d-5): the base drafts the old three, the random bot any
	# team at random (its seed's), and the good bot the team whose practice is
	# worth most.
	var vows_of: Callable = func(team: Array[String]) -> Dictionary[String, String]: return Report.seed_vows(_run.content, team, 4)
	assert_eq(Report.make_bot("simple").team(_run, 4, false, vows_of), HeroTeam.DEFAULT)
	var drawn: Dictionary[String, bool] = {}
	for run_seed: int in 8:
		var team: Array[String] = Report.make_bot("random").team(_run, run_seed, false, vows_of)
		assert_eq(HeroTeam.problem(_run.content, team), "")
		assert_eq(Report.make_bot("random").team(_run, run_seed, false, vows_of), team, "its seed's")
		drawn[",".join(team)] = true
	assert_gt(drawn.size(), 3, "teams at random")
	var good: Array[String] = Report.make_bot("good").team(_run, 4, false, vows_of)
	assert_eq(HeroTeam.problem(_run.content, good), "")
	var worth: Callable = func(team: Array[String]) -> float:
		var errors: Array[String] = []
		var flow: RunFlow = RunFlow.start(_run, 4, vows_of.call(team), errors)
		return Practice.team_worth(flow, Practice.practice_set(flow))
	assert_gte(worth.call(good), worth.call(HeroTeam.DEFAULT), "no worse in practice than the old three")
	Practice.clear_cache()


func test_the_random_bot_does_what_the_simple_one_never_does() -> void:
	# The simple bot always takes today's first fight; the random one takes
	# the harder one now and then.
	var fights: Dictionary[String, bool] = {}
	for run_seed: int in range(1, 7):
		var flow: RunFlow = _play("random", run_seed)
		for fought: RunState.Fought in flow.state.fought:
			fights[fought.encounter] = true
	var harder: bool = fights.keys().any(func(id: String) -> bool: return _run.content.encounters[id].tier == "harder")
	assert_true(harder, "it takes the harder fight sometimes; the simple bot never does")


func test_a_run_line_survives_jobs() -> void:
	var line: Report.RunLine = Report.play(_run, 5, "random")
	var file: FileAccess = FileAccess.open("user://test_run_line.bin", FileAccess.WRITE)
	file.store_var([line.to_dict()])
	file.close()
	file = FileAccess.open("user://test_run_line.bin", FileAccess.READ)
	var back: Report.RunLine = Report.RunLine.from_dict(file.get_var()[0])
	file.close()
	DirAccess.remove_absolute("user://test_run_line.bin")
	var lines: Array[Report.RunLine] = [line]
	var read: Array[Report.RunLine] = [back]
	assert_eq(Report.summary(_run, read), Report.summary(_run, lines), "the report from a line read back is the same")
	assert_eq(Report.engines_summary(read), Report.engines_summary(lines))
	assert_eq(back.bot, "random")


## A flow at day `day`'s loadout, its first fight chosen.
func _at_fight(run_seed: int, encounter_id: String = "") -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, _vows(run_seed), errors)
	if not encounter_id.is_empty():
		flow.state.options[0][0] = encounter_id
	flow.choose_fight(0)
	return flow


func test_the_quick_score_is_the_features_score() -> void:
	var grid: HexGrid = _run.content.tuning.make_grid()
	for encounter_id: String in ["pup_warren", "hollow_line", "cairn_watch", "old_mother_ash"]:
		var errors: Array[String] = []
		var setup: FightSetup = Encounters.setup(_run.content, encounter_id, Simple.formation(), 1, errors)
		var scores: Array[float] = []
		var found: Array[Dictionary] = Placement.best_formations(setup, grid, 4, scores)
		assert_eq(found.size(), 4, encounter_id)
		for i: int in found.size():
			assert_almost_eq(Placement.formation_score(setup, grid, found[i]), scores[i], 0.0001, "%s, formation %d" % [encounter_id, i])
			if i > 0:
				assert_true(scores[i] <= scores[i - 1], "best first")
		assert_eq(setup.heroes.map(func(unit: UnitSetup) -> Vector2i: return Vector2i(unit.col, unit.row)),
			Simple.formation().values(), "the setup is put back")


## Act 3's void (phase 8 part 3, 8c-6c): the fight is read as one over
## the void, scored by its own weights, its pushers counted; no formation
## stands over the void, and the two features read it.
func test_the_good_bot_reads_the_void() -> void:
	var grid: HexGrid = _run.content.tuning.make_grid()
	var errors: Array[String] = []
	var setup: FightSetup = Encounters.setup(_run.content, "the_span", Simple.formation(), 1, errors)
	var info: Dictionary = Placement.read_enemies(setup, grid)
	assert_eq(info["context"][Placement.VOID], 1.0, "a fight over the void")
	assert_eq(info["pushers"], 6, "six Cliffmites shove")
	Placement.weights()
	assert_eq(Placement.weights_for(info["context"]), Placement._void_weights, "scored by the void weights")
	var scores: Array[float] = []
	for formation: Dictionary in Placement.best_formations(setup, grid, 6, scores):
		for hex: Vector2i in formation.values():
			assert_false(setup.void_hexes.has(hex), "never over the void")
	# (3, 2) stands beside the void row; (3, 0) two rows back.
	assert_eq(Placement.beside_void(setup, grid, Vector2i(3, 2)), 1.0)
	assert_eq(Placement.beside_void(setup, grid, Vector2i(3, 0)), 0.0)
	var at: Callable = func(col: int, row: int) -> Vector2: return Vector2(grid.center(col, row)) / float(HexGrid.HEX)
	assert_true(Placement.void_distance(setup, grid, at.call(3, 0)) > Placement.void_distance(setup, grid, at.call(3, 2)), "farther back, farther from the void")
	var plain: FightSetup = Encounters.setup(_run.content, "pup_warren", Simple.formation(), 1, errors)
	var plain_info: Dictionary = Placement.read_enemies(plain, grid)
	assert_eq(plain_info["context"][Placement.VOID], 0.0)
	var f: PackedFloat64Array = Placement.features(plain, grid, plain_info)
	assert_eq([f[24], f[25]], [0.0, 0.0], "both 0 without void")


func test_roles_come_from_the_kits() -> void:
	var errors: Array[String] = []
	var setup: FightSetup = Encounters.setup(_run.content, "the_pack", Simple.formation(), 1, errors)
	assert_eq(Placement.roles_of(setup).map(func(unit: UnitSetup) -> String: return unit.id), ["brannoc", "maren", "vell"], "tank, far, mid")


func test_the_good_bot_places_a_legal_formation_without_fighting() -> void:
	var flow: RunFlow = _at_fight(4)
	var before: String = JSON.stringify(flow.state.to_dict())
	var bot: GoodBot = GoodBot.new()
	bot.begin(flow)
	var hexes: Dictionary[String, Vector2i] = bot.formation(flow)
	var again: Dictionary[String, Vector2i] = bot.formation(flow)
	assert_eq(again, hexes, "the same reading twice")
	var errors: Array[String] = []
	assert_not_null(flow.fight_setup(hexes, errors), ", ".join(errors))
	assert_eq(JSON.stringify(flow.state.to_dict()), before, "reading changes nothing")
	assert_null(flow.last_result, "and fights nothing")


func test_the_expert_never_does_worse_than_the_good_bot() -> void:
	for encounter_id: String in ["hollow_line", "cairn_watch"]:
		var flow: RunFlow = _at_fight(6, encounter_id)
		var good: GoodBot = GoodBot.new()
		var expert: ExpertBot = ExpertBot.new()
		var errors: Array[String] = []
		var good_hexes: Dictionary[String, Vector2i] = good.formation(flow)
		var expert_hexes: Dictionary[String, Vector2i] = expert.formation(flow)
		var good_worth: float = Practice.worth(flow.fight_setup(good_hexes, errors, good.markers(flow, good_hexes)), _run.content)
		var expert_worth: float = Practice.worth(flow.fight_setup(expert_hexes, errors, expert.markers(flow, expert_hexes)), _run.content)
		assert_true(expert_worth >= good_worth, "%s: expert %.2f, good %.2f" % [encounter_id, expert_worth, good_worth])


## Plays `bot_name` from `run_seed` until day `day` starts (or the run ends).
func _play_to(bot_name: String, run_seed: int, day: int) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, _vows(run_seed), errors)
	var bot: RefCounted = Report.make_bot(bot_name)
	bot.call("begin", flow)
	for i: int in RunPlayer.MAX_STEPS:
		if flow.state.phase == RunState.Phase.ENDED or flow.state.day >= day:
			break
		var said: String = RunPlayer.step(flow, bot)
		assert_eq(said, "", "%s, seed %d, day %d" % [bot_name, run_seed, flow.state.day])
		if not said.is_empty():
			break
	return flow


func test_the_good_bot_and_the_expert_play_and_repeat() -> void:
	for bot_name: String in ["good", "expert"]:
		var first: RunFlow = _play_to(bot_name, 5, 3)
		var again: RunFlow = _play_to(bot_name, 5, 3)
		assert_true(first.state.day >= 3 or first.state.phase == RunState.Phase.ENDED, bot_name)
		assert_eq(JSON.stringify(again.state.to_dict()), JSON.stringify(first.state.to_dict()), "%s repeats" % bot_name)


func test_the_practice_set_is_what_the_map_shows() -> void:
	var flow: RunFlow = _at_fight(2)
	var state: RunState = flow.state
	assert_eq(Practice.practice_set(flow), [state.options[1][0], state.options[2][0], state.options[4][0]] as Array[String],
		"never today's fight (Decision 5): days 2 and 3, then the next elite after them")
	assert_false(Practice.practice_set(flow).has(state.options[0][0]) and state.options[0][0] != state.options[1][0])
	state.phase = RunState.Phase.SHOP
	state.day = 5
	assert_eq(Practice.practice_set(flow), [state.options[6][0], state.options[4][0]] as Array[String],
		"the boss (two days off), then the latest fight already behind; never day 6's")
	state.day = 6
	assert_eq(Practice.practice_set(flow), [state.options[5][0], state.options[4][0]] as Array[String], "with the boss next, fights behind")
	state.day = 7
	assert_eq(Practice.practice_set(flow), [] as Array[String], "nothing after the boss")


func test_practice_tries_a_copy_and_counts_the_shards() -> void:
	var flow: RunFlow = _at_fight(3)
	flow.record(Simple.formation(), _won())
	var before: String = JSON.stringify(flow.state.to_dict())
	var coming: Array[String] = Practice.practice_set(flow)
	var team: float = Practice.team_worth(flow, coming)
	var shards: float = Practice.value(flow, func(trial: RunFlow) -> String: return trial.take_shards(), coming)
	assert_almost_eq(shards, team + _run.acts[0].pick_shards * Practice.shard_worth(flow), 0.0001, "the shards' worth on the same fights")
	assert_eq(Practice.value(flow, func(trial: RunFlow) -> String: return trial.take_pick(99), coming), -INF, "refused")
	assert_eq(JSON.stringify(flow.state.to_dict()), before, "the run itself is untouched")
	var bot: GoodBot = GoodBot.new()
	bot.begin(flow)
	var card: int = bot.pick(flow)
	assert_true(card >= -1 and card < flow.state.pick.size())
	assert_eq(JSON.stringify(flow.state.to_dict()), before, "judging changes nothing")
	assert_null(flow.last_result, "and fights no real fight")
	var setup: FightSetup = flow.fight_setup(Simple.formation(), [] as Array[String])
	assert_null(setup, "no fight is waiting after the fight")


func test_shards_are_worth_less_as_the_act_runs_out() -> void:
	var flow: RunFlow = _at_fight(3)
	var early: float = Practice.shard_worth(flow)
	flow.state.day = 7
	assert_true(Practice.shard_worth(flow) < early)
	flow.state.day = 8
	assert_eq(Practice.shard_worth(flow), 0.0)


func _won() -> FightResult:
	var result := FightResult.new()
	result.outcome = FightResult.Outcome.VICTORY
	return result


func test_the_choices_and_compare_reports() -> void:
	var lines: Array[Report.RunLine] = []
	lines.assign(Report.play_many(_run, [2, 3, 4] as Array[int], "random"))
	assert_true(lines.any(func(line: Report.RunLine) -> bool: return not line.offered.is_empty()), "offers were seen")
	for line: Report.RunLine in lines:
		for key: String in line.taken:
			if key.begins_with("card:"):
				assert_true(line.offered.has(key), "%s was taken from an offer" % key)
	var text: String = Report.choices_summary(_run, lines, 1)
	for heading: String in ["Cards (", "Items (", "Relics ("]:
		assert_string_contains(text, heading)
	var by_bot: Dictionary[String, Array] = {"random": lines, "simple": Report.play_many(_run, [2, 3, 4] as Array[int], "simple")}
	var compared: String = Report.compare_summary(_run, by_bot)
	assert_string_contains(compared, "  random ")
	assert_string_contains(compared, "  simple ")


## Plays the act through its boss shop to endless's choice, every fight won
## on paper.
## A testing run (phase 8 part 3: Act 1's endless is the testing option),
## with Maren on Volley, transformed, so the apex vow that opens as the act
## ends waits on her.
func _to_choice(run_seed: int) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, _vows(run_seed), errors, true)
	flow.state.hero("maren").path = "volley"
	flow.state.hero("maren").transformed = true
	for day: int in _run.acts[0].days.size():
		flow.choose_fight(0)
		flow.record(Simple.formation(), _won())
		if not flow.state.pick.is_empty():
			flow.take_shards()
		if not flow.state.relic_choice.is_empty():
			flow.decline_relic()
		flow.finish_day()
		flow.leave_shop()
		if flow.state.phase == RunState.Phase.NODES:
			flow.choose_node(flow.state.nodes.find("camp"))
			flow.leave_node()
	assert_eq(flow.state.phase, RunState.Phase.CHOICE)
	return flow


func test_a_bot_that_goes_deeper_plays_floors_to_its_first_loss() -> void:
	var states: Array[String] = []
	for deeper: bool in [true, true, false]:
		var flow: RunFlow = _to_choice(6)
		var bot: RefCounted = Report.make_bot("simple")
		bot.set("deeper", deeper)
		bot.call("begin", flow)
		for i: int in RunPlayer.MAX_STEPS:
			if flow.state.phase == RunState.Phase.ENDED:
				break
			var said: String = RunPlayer.step(flow, bot)
			assert_eq(said, "", "day %d" % flow.state.day)
			if not said.is_empty():
				break
		assert_eq([flow.state.phase, flow.state.endless], [RunState.Phase.ENDED, deeper])
		if not deeper:
			assert_eq(flow.state.act, 2, "declining endless, it goes on into Act 2 (8c-4b)")
		if deeper:
			assert_eq(flow.state.outcome, RunState.Outcome.WON, "the first loss in endless still wins the run")
			assert_gt(flow.floor_number(), 0, "it reached a floor")
			assert_eq(flow.state.fought.back().outcome, FightResult.Outcome.DEFEAT, "and fell there")
			assert_eq(flow.state.hero("maren").apex, "hailstorm", "the bot vowed her to an apex (phase 8 part 2)")
		else:
			assert_eq(flow.state.hero("maren").apex, "hailstorm", "the vow opens as the act ends (phase 8 part 3), so the bot vows her at the choice either way")
		states.append(JSON.stringify(flow.state.to_dict()))
	assert_eq(states[1], states[0], "it repeats")


func test_the_endless_report() -> void:
	var lines: Array[Report.RunLine] = []
	for floor_reached: int in [0, 3, 7, 12]:
		var line := Report.RunLine.new()
		line.vows.assign(_vows(floor_reached))
		line.floor_reached = floor_reached
		if floor_reached > 0:
			line.fell_to = _run.floor_pool(RunState.new(), "normal")[0]
			@warning_ignore("integer_division")
			line.endless_mods.assign(_run.camps.modifier_ids.slice(0, floor_reached / 3))
		lines.append(line)
	var text: String = Report.endless_summary(_run, lines)
	assert_string_starts_with(text, "Endless: 3 of 4 runs won the act and went deeper")
	assert_string_contains(text, "median 7, quartiles 3-12, deepest 12, shallowest 3")
	assert_string_contains(text, "Runs falling by floors: 1-5: 1, 6-10: 1, 11-15: 1")
	assert_string_contains(text, "Rift modifiers on at the end: 2.3 a run")
	assert_string_contains(text, "Median floor by vow: ")
	var none: Array[Report.RunLine] = [lines[0]]
	assert_eq(Report.endless_summary(_run, none), "Endless: 0 of 1 runs won the act and went deeper")


func test_a_hero_sworn_to_the_front_row_is_placed_there() -> void:
	var flow: RunFlow = _at_fight(4)
	var vanguard: int = -1
	for i: int in _run.events.oaths.size():
		if _run.events.oaths[i].front_row:
			vanguard = i
	assert_true(vanguard >= 0, "an oath asks for the front row")
	flow.state.hero("vell").oath = _run.events.oaths[vanguard].id
	flow.state.hero("vell").oath_fights = 2
	var hexes: Dictionary[String, Vector2i] = GoodBot.new().formation(flow)
	assert_eq(hexes["vell"].y, flow.front_row())
	var errors: Array[String] = []
	assert_not_null(flow.fight_setup(hexes, errors), ", ".join(errors))
