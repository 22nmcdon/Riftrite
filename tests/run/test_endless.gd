extends GutTest
## Endless after Act 1 (docs/plans/rebuild-phase8-endless.md, part 8a-1):
## the choice after the act's boss shop, floors as days (their kind, fight,
## and growth), rift modifiers gathered every 3 floors, the collapse and
## crumbled ground, the shops' legendaries, boss relics then legendaries,
## the first loss ending the run, the save, and the records file.

const Bot = preload("res://tools/run_bot.gd")
const RECORDS_PATH: String = "user://test_records.json"

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func after_each() -> void:
	if FileAccess.file_exists(RECORDS_PATH):
		DirAccess.remove_absolute(RECORDS_PATH)


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


## Wins today's fight and settles what's waiting after it.
func _win_today(flow: RunFlow) -> void:
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	if not flow.state.pick.is_empty():
		flow.take_shards()
	if not flow.state.relic_choice.is_empty():
		flow.decline_relic()


## Plays the act through its boss shop to the choice.
func _to_choice(run_seed: int = 7) -> RunFlow:
	var flow: RunFlow = _start(run_seed)
	for day: int in range(1, _run.act.days.size()):
		_win_today(flow)
		assert_eq(flow.finish_day(), "")
		assert_eq(flow.leave_shop(), "")
		assert_eq(flow.choose_node(flow.state.nodes.find("camp")), "")
		assert_eq(flow.leave_node(), "")
	_win_today(flow)
	assert_eq(flow.finish_day(), "")
	assert_eq(flow.leave_shop(), "")
	assert_eq(flow.state.phase, RunState.Phase.CHOICE)
	return flow


## Goes deeper and on to `floor_number`, the floors between won as plain
## days (each floor's start, as leave_node gives it).
func _to_floor(floor_number: int, run_seed: int = 7) -> RunFlow:
	var flow: RunFlow = _to_choice(run_seed)
	assert_eq(flow.go_deeper(), "")
	while flow.floor_number() < floor_number:
		flow.state.day += 1
		flow._start_day()
	return flow


func test_the_choice_comes_after_the_boss_shop_and_going_deeper_keeps_the_run() -> void:
	var flow: RunFlow = _start()
	assert_eq(flow.go_deeper(), "can't go deeper now (the day is at route)")
	assert_eq(flow.end_run(), "can't end the run now (the day is at route)")
	flow = _to_choice()
	var state: RunState = flow.state
	var held: String = JSON.stringify([state.shards, state.relics, state.stash, state.item_ranks, state.heroes.map(func(hero: RunState.Hero) -> Dictionary: return hero.to_dict())])
	assert_eq(flow.go_deeper(), "")
	assert_eq([state.endless, state.day, flow.floor_number(), state.phase], [true, _run.act.days.size() + 1, 1, RunState.Phase.ROUTE])
	assert_eq(JSON.stringify([state.shards, state.relics, state.stash, state.item_ranks, state.heroes.map(func(hero: RunState.Hero) -> Dictionary: return hero.to_dict())]), held, "the heroes, relics, loadout, and shards go deeper")
	assert_eq(state.today().size(), 1, "one fight a floor (Decision 2)")
	assert_true(_run.floor_pool("normal").has(state.today()[0]))
	assert_eq(state.options.size(), state.day + 2, "drawn two floors ahead, for Scout and Map the Rift")


func test_a_floors_kind_and_its_fights() -> void:
	var endless: ActDef.Endless = _run.act.endless
	assert_eq([endless.kind(1), endless.kind(4), endless.kind(5), endless.kind(10), endless.kind(15), endless.kind(20)], ["normal", "normal", "elite", "boss", "elite", "boss"])
	for id: String in _run.floor_pool("normal"):
		var encounter: EncounterDef = _run.content.encounters[id]
		assert_true(["easier", "harder"].has(encounter.tier) and encounter.days.any(func(d: int) -> bool: return d >= 4), "%s: from day 4 on (Decision 1)" % id)
	assert_false(_run.floor_pool("normal").is_empty())
	assert_eq(_run.floor_pool("boss"), ["old_mother_ash"] as Array[String])
	var flow: RunFlow = _to_floor(12)
	var twin: RunFlow = _to_floor(12)
	assert_eq(flow.state.options, twin.state.options, "a floor's fight comes from the seed")
	for day: int in range(_run.act.days.size() + 1, flow.state.options.size() + 1):
		var kind: String = _run.day_kind(flow.state, day)
		assert_true(_run.floor_pool(kind).has(flow.state.options[day - 1][0]), "day %d's fight is a %s floor's" % [day, kind])
		if kind == "normal" and _run.day_kind(flow.state, day - 1) == "normal":
			assert_ne(flow.state.options[day - 1], flow.state.options[day - 2], "not the floor before's")


func test_a_floors_enemies_grow() -> void:
	assert_eq([ActDef.Endless.compound(11500, 0), ActDef.Endless.compound(11500, 1), ActDef.Endless.compound(11500, 2), ActDef.Endless.compound(11500, 3)], [10000, 11500, 13225, 15209])
	var flow: RunFlow = _to_floor(2)
	assert_eq(flow.state.endless_mods, [] as Array[String], "no modifier before floor 3")
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	var plain: FightSetup = Encounters.setup(_run.content, flow.state.chosen, Bot.formation(), 1, errors)
	for i: int in setup.enemies.size():
		for stat: UnitStats.Stat in [UnitStats.Stat.HP, UnitStats.Stat.ATK]:
			assert_eq(setup.enemies[i].def.stats.get_stat(stat), FixedMath.apply_bp(plain.enemies[i].def.stats.get_stat(stat), 13225), "x1.15 twice, on HP and ATK")
		assert_eq(setup.enemies[i].def.stats.get_stat(UnitStats.Stat.DEF), plain.enemies[i].def.stats.get_stat(UnitStats.Stat.DEF), "nothing else")


func test_a_rift_modifier_every_third_floor_for_good() -> void:
	var flow: RunFlow = _to_floor(1)
	var seen: Array[int] = []
	while flow.floor_number() < 33:
		flow.state.day += 1
		flow._start_day()
		@warning_ignore("integer_division")
		var expected: int = mini(flow.floor_number() / 3, _run.camps.modifier_ids.size())
		assert_eq(flow.state.endless_mods.size(), expected, "floor %d" % flow.floor_number())
		seen.append(flow.state.endless_mods.size())
	var unique: Dictionary = {}
	for id: String in flow.state.endless_mods:
		unique[id] = true
	assert_eq(unique.size(), _run.camps.modifier_ids.size(), "every modifier once, then no more")


func test_a_rift_tear_on_a_floor_never_doubles_a_modifier() -> void:
	var flow: RunFlow = _to_floor(5)
	var state: RunState = flow.state
	var all: Array[String] = _run.camps.modifier_ids
	state.endless_mods.assign(all.slice(0, all.size() - 3))
	var drawn: Array[String] = Offers.rift_modifiers(_run, state)
	assert_false(drawn.any(func(id: String) -> bool: return state.endless_mods.has(id)), "a tear draws none the run has gathered")
	# A tear set up for floor 6, a gathering floor: the floor gathers another.
	state.endless_mods.assign(all.slice(0, 1))
	state.rift_mods.assign(drawn.slice(0, 2))
	state.day += 1
	flow._start_day()
	assert_eq(state.endless_mods.size(), 2)
	assert_false(state.rift_mods.has(state.endless_mods[1]), "not one the tear brings")
	# And if one were on twice, the fight is still sound.
	state.rift_mods.append(state.endless_mods[0])
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	assert_not_null(flow.fight_setup(Bot.formation(), errors))
	assert_eq(errors, [] as Array[String])


func test_the_collapse_comes_sooner_and_the_ground_burns_hotter() -> void:
	var flow: RunFlow = _to_floor(1)
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq([setup.collapse_start_ticks, setup.crumble_bp], [FixedMath.ms_to_ticks(44000), 11500], "1s earlier, x1.15")
	flow = _to_floor(40)
	flow.state.endless_mods.clear()
	assert_eq(flow.choose_fight(0), "")
	setup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(setup.collapse_start_ticks, FixedMath.ms_to_ticks(10000), "never before 10s")
	assert_eq(setup.crumble_bp, ActDef.Endless.compound(11500, 40))
	assert_eq(errors, [] as Array[String])
	# Before endless, a fight's collapse is the act's.
	var campaign: RunFlow = _start()
	assert_eq(campaign.choose_fight(0), "")
	var plain: FightSetup = campaign.fight_setup(Bot.formation(), errors)
	assert_eq([plain.collapse_start_ticks, plain.crumble_bp], [0, 0])


func test_the_shops_show_legendaries_from_floor_ten() -> void:
	var flow: RunFlow = _to_floor(9)
	var odds: Array = Offers.shop_odds(_run, flow.state)
	assert_eq(odds[0], _run.act.relic_odds, "the act's odds on floor 9")
	flow = _to_floor(10)
	odds = Offers.shop_odds(_run, flow.state)
	assert_eq(odds[1][(odds[0] as Array).find("legendary")], _run.act.endless.legendary_weight)


func test_a_boss_floor_offers_boss_relics_then_legendaries() -> void:
	var flow: RunFlow = _to_floor(10)
	assert_eq(_run.day_kind(flow.state, flow.state.day), "boss")
	assert_eq(flow.state.today(), ["old_mother_ash"] as Array[String])
	_win_choice(flow)
	assert_true(flow.state.relic_choice.all(func(id: String) -> bool: return _run.relics[id].tier == RelicDef.Tier.BOSS))
	flow = _to_floor(10)
	for id: String in _run.relic_ids:
		if _run.relics[id].tier == RelicDef.Tier.BOSS and not flow.state.relics.has(id):
			flow.state.relics.append(id)
	_win_choice(flow)
	assert_eq(flow.state.relic_choice.size(), _run.act.boss_relics)
	assert_true(flow.state.relic_choice.all(func(id: String) -> bool: return _run.relics[id].tier == RelicDef.Tier.LEGENDARY), "every boss relic held: legendaries")
	# Its boss shop leads on to the nodes, not to the choice.
	flow.decline_relic()
	assert_eq(flow.finish_day(), "")
	assert_true(flow.boss_shop())
	assert_eq(flow.leave_shop(), "")
	assert_eq(flow.state.phase, RunState.Phase.NODES)


func _win_choice(flow: RunFlow) -> void:
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))


func test_the_first_loss_ends_an_endless_run() -> void:
	var flow: RunFlow = _to_floor(3)
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq([flow.state.phase, flow.state.outcome, flow.floor_number()], [RunState.Phase.ENDED, RunState.Outcome.WON, 3], "the act was won; the run fell on floor 3")
	# A tie still wins.
	flow = _to_floor(3)
	assert_eq(flow.choose_fight(0), "")
	flow.record(Bot.formation(), _result(FightResult.Outcome.TIE))
	assert_eq(flow.state.phase, RunState.Phase.AFTER)


func test_ending_at_the_choice_wins_the_act() -> void:
	var flow: RunFlow = _to_choice()
	assert_eq(flow.end_run(), "")
	assert_eq([flow.state.phase, flow.state.outcome, flow.state.endless], [RunState.Phase.ENDED, RunState.Outcome.WON, false])


func test_the_save_keeps_endless_and_an_older_save_still_loads() -> void:
	var flow: RunFlow = _to_floor(4)
	var data: Dictionary = flow.state.to_dict()
	assert_eq(JSON.stringify(RunState.from_dict(data).to_dict()), JSON.stringify(data))
	var older: Dictionary = _start().state.to_dict()
	older["version"] = 4
	older.erase("endless")
	older.erase("endless_mods")
	var loaded: RunState = RunState.from_dict(older)
	assert_not_null(loaded, "a version-4 save loads")
	assert_eq([loaded.endless, loaded.endless_mods], [false, [] as Array[String]])
	older["version"] = 3
	assert_null(RunState.from_dict(older))


func test_the_records_keep_the_deepest_floor() -> void:
	var state: RunState = _start().state
	assert_eq(RunRecords.best(RECORDS_PATH), {})
	assert_true(RunRecords.note(state, 6, RECORDS_PATH))
	assert_false(RunRecords.note(state, 4, RECORDS_PATH), "not deeper")
	assert_true(RunRecords.note(state, 9, RECORDS_PATH))
	var best: Dictionary = RunRecords.best(RECORDS_PATH)
	assert_eq([int(best["floor"]), int(best["seed"])], [9, state.seed_value])
	assert_eq((best["vows"] as Dictionary).size(), state.heroes.size())
