extends GutTest
## Growth in a run (docs/plans/rebuild-phase5-run.md, sections 4 and 5): deed
## thresholds and transformations, Switch vow, the upgrades as data, and the
## after-fight pick.

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


## A flow at today's fight (the first option), ready to record a result.
func _at_fight(run_seed: int = 7) -> RunFlow:
	var flow: RunFlow = _start(run_seed)
	flow.choose_fight(0)
	return flow


func _result(outcome: FightResult.Outcome, deeds: Array[FightResult.Deed] = []) -> FightResult:
	var result := FightResult.new()
	result.outcome = outcome
	result.end_tick = 600
	result.deeds = deeds
	return result


func _deed(hero_id: String, path_id: String, amount: int) -> Array[FightResult.Deed]:
	return [FightResult.Deed.make(hero_id, path_id, amount)] as Array[FightResult.Deed]


## A RunContent over the real data with `upgrades` as upgrades.json.
func _with_upgrades(upgrades: Array) -> RunContent:
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data/" + file_name)
	texts[RunContent.UPGRADES_FILE] = JSON.stringify(upgrades)
	return RunContent.load_texts(texts, _run.content)


func test_the_upgrades_load() -> void:
	assert_true(_run.is_valid(), "\n".join(_run.errors))
	for path_id: String in _run.content.path_ids:
		var cards: Array[String] = _run.upgrade_ids.filter(func(id: String) -> bool: return _run.upgrades[id].path == path_id)
		assert_eq(cards.filter(func(id: String) -> bool: return _run.upgrades[id].grows != null).size(), 1, "%s has one card that grows" % path_id)
		assert_eq(_run.upgrades[cards[0]].hero, _run.content.paths[path_id].hero, "a path's card is its hero's")
		assert_gt(_run.content.paths[path_id].deed.threshold, 0, "%s's deed has a threshold" % path_id)
	# A hero's cards come with its paths (phase 8 part 4).
	for hero_id: String in HeroTeam.draftable(_run.content):
		var own: Array[String] = _run.upgrade_ids.filter(func(id: String) -> bool: return _run.upgrades[id].hero == hero_id and _run.upgrades[id].layer == UpgradeDef.Layer.HERO)
		assert_eq(own.filter(func(id: String) -> bool: return _run.upgrades[id].grows != null).size(), 1, "%s has one hero card that grows (phase 5c step 4)" % hero_id)


func test_bad_upgrades_are_refused() -> void:
	var tough: Dictionary = {"stats_bp": {"hp": 11000}}
	var cases: Array = [
		[{"id": "both", "name": "Both", "text": "x", "hero": "maren", "path": "deadeye", "mod": tough}, "give one of hero, path, and apex"],
		[{"id": "odd", "name": "Odd", "text": "x", "hero": "maren", "taste": true, "mod": tough}, "only a path's card can be a taste card"],
		[{"id": "later", "name": "Later", "text": "x", "path": "deadeye", "mod": tough, "transformed_mod": tough}, "only a taste card has a transformed_mod"],
		[{"id": "who", "name": "Who", "text": "x", "path": "nowhere", "mod": tough}, "unknown path \"nowhere\""],
		[{"id": "idle", "name": "Idle", "text": "x", "path": "last_watch", "mod": {"mana": {"max_add": -5}}}, "does nothing on last_watch transformed"],
		[{"id": "never", "name": "Never", "text": "x", "hero": "brannoc", "mod": {"on": [{"slot": "abilities", "statuses": ["burn"], "duration_add_ms": 500}]}}, "does nothing on any of its hero's kits"],
		[{"id": "gone", "name": "Gone", "text": "x", "path": "deadeye", "taste": true, "mod": {"on": [{"slot": "passive:steady", "after_add_ms": -500}]}}, "on deadeye transformed, it has no passive \"steady\""],
		[{"id": "heap", "name": "Heap", "text": "x", "path": "deadeye", "stacks": {"stat": "atk", "pct": 10}}, "a stacking card is a hero's"],
		[{"id": "fast", "name": "Fast", "text": "x", "hero": "maren", "stacks": {"stat": "speed", "pct": 10}}, "stat"],
	]
	for case: Array in cases:
		var run: RunContent = _with_upgrades([case[0]])
		assert_false(run.is_valid(), str(case[0]))
		assert_true(run.errors.any(func(message: String) -> bool: return message.contains(case[1])), "%s: %s" % [case[1], run.errors])


func test_what_a_hero_can_be_offered() -> void:
	var maren := RunState.Hero.new()
	maren.id = "maren"
	maren.path = "deadeye"
	var offered: Array[String] = _run.upgrades_for(maren)
	assert_true(offered.has("steady_hands") and offered.has("deep_mark") and offered.has("notched_bow"), "her own cards and Deadeye's taste: %s" % [offered])
	assert_false(offered.has("hearts_refund"), "not Deadeye's path cards before she transforms")
	maren.transformed = true
	maren.upgrades.append("hearts_refund")
	offered = _run.upgrades_for(maren)
	assert_false(offered.has("steady_hands"), "no taste cards once transformed")
	assert_false(offered.has("hearts_refund"), "nothing taken twice")
	assert_true(offered.has("hunters_tally"), "the path's cards join")


func test_a_taste_card_changes_with_the_stage_and_waits_off_its_path() -> void:
	var maren := RunState.Hero.new()
	maren.id = "maren"
	maren.path = "deadeye"
	maren.upgrades.assign(["steady_hands", "deep_mark"])
	var hands: UpgradeDef = _run.upgrades["steady_hands"]
	assert_eq(_run.upgrade_mods(maren), [hands.mod, _run.upgrades["deep_mark"].mod] as Array[KitMod])
	maren.transformed = true
	assert_eq(_run.upgrade_mods(maren)[0], hands.transformed_mod, "once transformed, its transformed mod (Decision 35)")
	maren.transformed = false
	maren.path = "trapper"
	assert_eq(_run.upgrade_mods(maren), [_run.upgrades["deep_mark"].mod] as Array[KitMod], "off Deadeye, it waits")


func test_a_filled_deed_transforms_after_the_fight() -> void:
	var flow: RunFlow = _at_fight()
	var threshold: int = _run.content.paths["deadeye"].deed.threshold
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY, _deed("maren", "deadeye", threshold - 1)))
	assert_false(flow.state.hero("maren").transformed, "one short")
	assert_eq(flow.state.just_transformed, [] as Array[String])
	flow.take_shards()
	assert_eq(R.next_day(flow), "")
	flow.choose_fight(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT, _deed("maren", "deadeye", 1)))
	assert_true(flow.state.hero("maren").transformed, "a lost fight's deeds transform too")
	assert_eq(flow.state.just_transformed, ["maren"] as Array[String])
	flow.choose_fight(0)
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(setup.heroes[1].stage, PathDef.Stage.TRANSFORMED, "the next fight has her transformed")
	assert_eq(setup.heroes[0].stage, PathDef.Stage.VOWED)
	assert_eq(flow.switch_vow("maren", "trapper"), "maren has transformed, so the vow is set")


func test_only_the_vowed_deed_transforms() -> void:
	var flow: RunFlow = _at_fight()
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY, _deed("maren", "trapper", 999999)))
	assert_false(flow.state.hero("maren").transformed)
	assert_eq(flow.switch_vow("maren", "trapper"), "", "switching between fights")
	assert_eq(flow.state.hero("maren").deeds["trapper"], 999999, "the new path's deed keeps what it had")
	flow.take_shards()
	assert_eq(R.next_day(flow), "")
	flow.choose_fight(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_true(flow.state.hero("maren").transformed, "it fills after the next fight")


func test_switching_a_vow_is_checked() -> void:
	var flow: RunFlow = _start()
	assert_eq(flow.switch_vow("maren", "hearthwall"), "maren can't vow to \"hearthwall\"")
	assert_eq(flow.switch_vow("maren", "deadeye"), "maren is already vowed to deadeye")
	assert_eq(flow.switch_vow("nobody", "deadeye"), "unknown hero \"nobody\"")
	assert_eq(flow.switch_vow("maren", "volley"), "")
	assert_eq(flow.state.hero("maren").path, "volley")


func test_a_win_offers_a_pick_one_card_per_hero() -> void:
	var flow: RunFlow = _at_fight()
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	var cards: Array[String] = flow.state.pick
	assert_eq(cards.size(), 3)
	assert_eq(cards, Offers.pick(_run, flow.state, 0), "the same state, the same pick")
	assert_eq(flow.finish_day(), "choose an upgrade or take the shards first")
	assert_eq(flow.take_pick(3), "there's no card 3")
	var chosen: UpgradeDef = _run.upgrades[cards[1]]
	assert_eq(flow.take_pick(1), "")
	assert_eq(flow.state.hero(chosen.hero).upgrades, [chosen.id] as Array[String])
	assert_eq(flow.state.pick, [] as Array[String])
	assert_eq(flow.take_pick(0), "there's no pick waiting")
	assert_eq(flow.take_shards(), "there's no pick waiting")
	assert_eq(flow.finish_day(), "")


func test_the_shards_instead() -> void:
	var flow: RunFlow = _at_fight()
	flow.record(Bot.formation(), _result(FightResult.Outcome.TIE))
	var before: int = flow.state.shards
	assert_eq(flow.take_shards(), "")
	assert_eq(flow.state.shards, before + _run.acts[0].pick_shards)
	assert_true(flow.state.heroes.all(func(hero: RunState.Hero) -> bool: return hero.upgrades.is_empty()))


func test_a_loss_offers_no_pick() -> void:
	var flow: RunFlow = _at_fight()
	flow.record(Bot.formation(), _result(FightResult.Outcome.DEFEAT))
	assert_eq(flow.state.pick, [] as Array[String])


func test_cards_are_one_per_hero_unless_wild() -> void:
	var wild: int = 0
	for run_seed: int in range(1, 41):
		var flow: RunFlow = _at_fight(run_seed)
		flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
		var owners: Array = flow.state.pick.map(func(id: String) -> String: return _run.upgrades[id].hero)
		if owners != ["brannoc", "maren", "vell"]:
			wild += 1
			assert_eq(owners.size(), 3)
	assert_between(wild, 1, 20, "a wild card now and then (%d of 40)" % wild)


func test_a_taken_upgrade_reaches_the_fight() -> void:
	var flow: RunFlow = _at_fight()
	flow.state.hero("brannoc").upgrades.append("opening_stand")
	flow.state.hero("brannoc").upgrades.append("hearthblood")
	flow.state.hero("brannoc").locked["hearthblood"] = [63]
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	var kit: UnitDef = _run.content.paths["hearthwall"].vowed_kit
	assert_eq(setup.heroes[0].def.stats.get_stat(UnitStats.Stat.HP), kit.stats.get_stat(UnitStats.Stat.HP) + 63, "a stacking card's locked amount")
	assert_true(setup.heroes[0].def.passives.any(func(part: PartDef) -> bool: return part.id == "opening_stand"), "and a card's passive")


func test_picks_run_out_gracefully() -> void:
	# The real pools never run dry (stacking cards come back, phase 5c step
	# 7), so a pool of one card: whoever's it is, then nothing.
	var run: RunContent = _with_upgrades([{"id": "glow", "name": "Glow", "text": "x", "hero": "vell", "mod": {"stats_bp": {"mgk": 11000}}}])
	assert_true(run.is_valid(), str(run.errors))
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(run, 7, Bot.first_vows(run.content), errors)
	flow.choose_fight(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq(flow.state.pick, ["glow"] as Array[String], "one card left, whoever's it is")
	flow.take_pick(0)
	assert_eq(R.next_day(flow), "")
	flow.choose_fight(0)
	flow.record(Bot.formation(), _result(FightResult.Outcome.VICTORY))
	assert_eq(flow.state.pick, [] as Array[String], "nothing left: no pick")
	assert_eq(flow.finish_day(), "")


func test_the_bot_grows_its_heroes() -> void:
	var taken: int = 0
	for run_seed: int in range(1, 11):
		var errors: Array[String] = []
		var flow: RunFlow = Bot.play(_run, run_seed, errors)
		assert_eq(errors, [] as Array[String])
		for hero: RunState.Hero in flow.state.heroes:
			taken += hero.upgrades.size()
	assert_gt(taken, 0, "the bot took picks over ten runs")
