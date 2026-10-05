extends GutTest
## The rift learns (docs/plans/rebuild-phase8-act3.md, part 8c-5d; RiftLearns,
## data/rift_learns.json): each fight's summary kept on its Fought, the
## habits scored from the last fights, the boss's adds' learned picks on a
## boss day of an act with rift_learns, the fight with them, the save
## (version 10), and the fight card's line. On stand-in acts
## (tests/run/test_acts.gd) whose Act 2 learns, with a stand-in boss fight
## whose adds have specializations.

const Bot = preload("res://tools/run_bot.gd")
const ActsTest = preload("res://tests/run/test_acts.gd")
const BOSS: String = "learning_heart"

var _run: RunContent


func before_all() -> void:
	_run = ActsTest.stand_in_acts()
	_run.acts[1].rift_learns = true
	var errors: Array[String] = []
	var boss: EncounterDef = EncounterDef.read(DataReader.new({"id": BOSS, "name": "Learning Heart", "tests": "what it learned", "tier": "boss", "act": 1, "days": [7],
		"enemies": [{"enemy": "old_mother_ash", "hex": [3, 6]}, {"enemy": "cinder_moth", "hex": [1, 5]}, {"enemy": "rift_hound", "hex": [2, 5]},
			{"enemy": "hollow_archer", "hex": [5, 6]}, {"enemy": "rift_worn_sentinel", "hex": [5, 4]}]}, BOSS, errors))
	assert_eq(errors, [] as Array[String])
	_run.content.encounters[BOSS] = boss


## A flow on Act 2's day `day`, its fights drawn; on day 7, the stand-in boss.
## `habits` are the measures of the fights before it, oldest first.
func _on_day(day: int, habits: Array = [], run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	flow.state.act = 2
	flow.state.day = day
	flow.state.options = ActDraw.draw(_run, run_seed, _run.acts[1])
	flow.state.options[6] = [BOSS]
	for measures: Variant in habits:
		var fought := RunState.Fought.new()
		for key: Variant in (measures as Dictionary):
			fought.habits[str(key)] = int((measures as Dictionary)[key])
		flow.state.fought.append(fought)
	flow._start_day()
	return flow


func _picks(flow: RunFlow) -> Array:
	return flow.state.today_learned[0]


func _entry(kind: LogEntry.Kind, source: String, amount: int = 0, status: String = "", ability: String = "") -> LogEntry:
	var entry := LogEntry.new()
	entry.kind = kind
	entry.source_unit = source
	entry.amount = amount
	entry.status = status
	entry.source_ability = ability
	return entry


func test_a_fights_summary() -> void:
	var flow: RunFlow = _on_day(1)
	var hero_ids: Array[String] = []
	for hero: RunState.Hero in flow.state.heroes:
		hero_ids.append(hero.id)
	var caster: RunState.Hero = flow.state.heroes.filter(func(hero: RunState.Hero) -> bool: return _run.hero_kit(hero).signature != null)[0]
	var kit: UnitDef = _run.hero_kit(caster)
	var result := FightResult.new()
	var log: CombatLog = result.combat_log
	log.add(_entry(LogEntry.Kind.STATUS_APPLIED, hero_ids[0], 1, "root"))
	log.add(_entry(LogEntry.Kind.STATUS_APPLIED, hero_ids[1], 1, "root"))
	log.add(_entry(LogEntry.Kind.STATUS_APPLIED, hero_ids[0], 3, "burn"))
	log.add(_entry(LogEntry.Kind.STATUS_APPLIED, hero_ids[2], 1, "marked"))
	log.add(_entry(LogEntry.Kind.STATUS_APPLIED, hero_ids[2], 1, "stealth"))
	log.add(_entry(LogEntry.Kind.STATUS_APPLIED, "rift_hound", 1, "root"))
	log.add(_entry(LogEntry.Kind.HEAL, hero_ids[1], 40))
	log.add(_entry(LogEntry.Kind.LIFESTEAL, hero_ids[0], 5))
	log.add(_entry(LogEntry.Kind.HEAL, "gloam_witch", 99))
	log.add(_entry(LogEntry.Kind.SHIELD, hero_ids[2], 30))
	var relic: LogEntry = _entry(LogEntry.Kind.SHIELD, "", 20)
	relic.source_relic_side = EffectSource.Team.HEROES
	log.add(relic)
	var enemy_relic: LogEntry = _entry(LogEntry.Kind.SHIELD, "", 70)
	enemy_relic.source_relic_side = EffectSource.Team.ENEMIES
	log.add(enemy_relic)
	log.add(_entry(LogEntry.Kind.FIRE, caster.id, 0, "", kit.signature.id))
	log.add(_entry(LogEntry.Kind.FIRE, caster.id, 0, "", kit.signature.id))
	log.add(_entry(LogEntry.Kind.FIRE, caster.id, 0, "", kit.basic_attack.id))
	var formation: Dictionary[String, Vector2i] = {hero_ids[0]: Vector2i(2, 0), hero_ids[1]: Vector2i(3, 0), hero_ids[2]: Vector2i(5, 2)}
	var summary: Dictionary[String, int] = RiftLearns.summary(_run, flow.state, formation, result)
	assert_eq(summary, {"rooted": 2, "burning": 1, "marked": 1, "stealthed": 1, "healing": 45, "shields": 50, "casts": 2, "back": 2, "front": 1, "bunched": 1} as Dictionary[String, int],
		"the heroes' doing only (a relic of theirs too); each application once; two side by side on the back row, one on the front")
	formation[hero_ids[2]] = Vector2i(5, 1)
	summary = RiftLearns.summary(_run, flow.state, formation, FightResult.new())
	assert_eq(summary, {"back": 2, "bunched": 1} as Dictionary[String, int], "the middle row is neither")


func test_each_fight_keeps_its_summary() -> void:
	var flow: RunFlow = _on_day(1)
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	var result: FightResult = CombatSim.run(setup, _run.content)
	var expected: Dictionary[String, int] = RiftLearns.summary(_run, flow.state, Bot.formation(), result)
	flow.record(Bot.formation(), result)
	assert_eq(flow.state.fought.back().habits, expected)
	assert_false(expected.is_empty(), "a real fight counts something")


func test_scores_read_only_the_last_fights() -> void:
	var flow: RunFlow = _on_day(1, [{"rooted": 100}, {"rooted": 4, "healing": 400}, {"rooted": 8}, {"healing": 1200}])
	var scored: Dictionary[String, int] = RiftLearns.scores(_run, flow.state)
	assert_eq(scored["roots"], 10000, "(4 + 8 + 0) over 3 fights of 4: the fight of 100 is too old")
	assert_eq(scored["healing"], 13333, "(400 + 1200) over 3 fights of 400")
	assert_eq(scored["burn"], 0)
	assert_eq(RiftLearns.scores(_run, _on_day(1).state).values().filter(func(score: int) -> bool: return score != 0), [], "no fights, no habits")


func test_the_top_habit_and_a_strong_second() -> void:
	var boss: EncounterDef = _run.content.encounters[BOSS]
	var ids: Callable = func(habits: Array[RiftLearnsDef.Habit]) -> Array: return habits.map(func(habit: RiftLearnsDef.Habit) -> String: return habit.id)
	var flow: RunFlow = _on_day(1, [{"rooted": 12, "burning": 6}])
	assert_eq(ids.call(RiftLearns.habits(_run, flow.state, boss)), ["roots"], "Burn at 50% isn't a second habit")
	flow = _on_day(1, [{"rooted": 12, "burning": 12}])
	assert_eq(ids.call(RiftLearns.habits(_run, flow.state, boss)), ["roots", "burn"], "Burn at 100% is")
	flow = _on_day(1, [{"burning": 12, "marked": 4}])
	assert_eq(ids.call(RiftLearns.habits(_run, flow.state, boss)), ["burn", "marks"], "a tie goes to the data's order")
	flow = _on_day(1, [{"casts": 30, "rooted": 2}])
	assert_eq(ids.call(RiftLearns.habits(_run, flow.state, _run.content.encounters["old_mother_ash"])), ["roots"],
		"nothing among Old Mother Ash's hounds answers signatures, so the next habit is answered")
	flow = _on_day(1, [{"healing": 4000}])
	assert_eq(ids.call(RiftLearns.habits(_run, flow.state, boss)), ["healing"], "Festering answers healing on any add")
	assert_eq(ids.call(RiftLearns.habits(_run, _on_day(1).state, boss)), [], "no habit, nothing to answer")
	flow = _on_day(1, [{"casts": 30}])
	assert_eq(ids.call(RiftLearns.habits(_run, flow.state, _run.content.encounters["old_mother_ash"])), [],
		"Old Mother Ash's hounds have no mana bar for Rift-Touched to change")
	assert_eq(RiftLearns.adds(boss), [1, 2, 3, 4] as Array[int], "every enemy but the boss")


func test_the_boss_adds_learn() -> void:
	var flow: RunFlow = _on_day(7, [{"rooted": 12}, {"rooted": 12}, {"bunched": 6}])
	var picks: Array = _picks(flow)
	assert_eq(picks.size(), 2, "half of the four adds")
	var adds: Array[int] = []
	for pick: Variant in picks:
		var entry: Dictionary = pick
		adds.append(int(entry["enemy"]))
		assert_true(int(entry["enemy"]) >= 1, "never the boss")
	assert_ne(adds[0], adds[1], "each add learns one thing")
	assert_eq((picks[0] as Dictionary)["habit"], "roots")
	assert_eq((picks[0] as Dictionary)["upgrade"], "anchored")
	assert_eq((picks[1] as Dictionary)["habit"], "bunching", "the habits take turns")
	assert_eq((picks[1] as Dictionary)["specialization"], "drifting_moth", "the only answer to bunching among these adds")
	assert_eq(int((picks[1] as Dictionary)["enemy"]), 1, "on the Cinder Moth")
	var specs: Array = flow.state.today_specs[0]
	assert_eq(specs[1], "drifting_moth", "the learned specialization replaces what it drew")
	assert_eq(specs[int((picks[0] as Dictionary)["enemy"])], "", "an add that learned an upgrade carries it alone")


func test_one_habit_takes_both_turns() -> void:
	for run_seed: int in range(1, 13):
		var picks: Array = _picks(_on_day(7, [{"marked": 20}], run_seed))
		assert_eq(picks.map(func(pick: Dictionary) -> String: return "%s %s" % [pick["habit"], pick["upgrade"]]), ["marks mark_shy", "marks mark_shy"])
		assert_ne(int((picks[0] as Dictionary)["enemy"]), int((picks[1] as Dictionary)["enemy"]), "on two adds")


func test_a_turn_leaves_the_add_a_later_habit_needs() -> void:
	for run_seed: int in range(1, 13):
		var picks: Array = _picks(_on_day(7, [{"rooted": 12}, {"rooted": 12}, {"bunched": 6}], run_seed))
		assert_eq(picks.map(func(pick: Dictionary) -> String: return "%s %d" % [pick["habit"], pick["enemy"]]).back(), "bunching 1",
			"Anchored never takes the Cinder Moth, the only add that answers bunching")


func test_the_fight_carries_them() -> void:
	var flow: RunFlow = _on_day(7, [{"rooted": 12}, {"bunched": 6}])
	var picks: Array = _picks(flow)
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	for pick: Variant in picks:
		var entry: Dictionary = pick
		var def: UnitDef = setup.enemies[int(entry["enemy"])].def
		if entry.has("upgrade"):
			assert_eq(def.upgrades, [str(entry["upgrade"])] as Array[String])
			assert_eq(def.specialization, "", "the upgrade alone")
		else:
			assert_eq(def.specialization, str(entry["specialization"]))
			assert_eq(def.upgrades, [] as Array[String])
	assert_eq(setup.enemies[0].def.upgrades, [] as Array[String], "the boss learns nothing")


func test_where_it_doesnt_learn() -> void:
	var habits: Array = [{"rooted": 12}]
	for day: int in range(1, 7):
		assert_true(_on_day(day, habits).state.today_learned.all(func(learned: Array) -> bool: return learned.is_empty()), "day %d isn't the boss's" % day)
	assert_eq(_picks(_on_day(7)), [], "a run with no habits yet")
	_run.acts[1].rift_learns = false
	assert_eq(_picks(_on_day(7, habits)), [], "an act without the rift learns")
	_run.acts[1].rift_learns = true
	var real: RunContent = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))
	assert_eq(real.acts.map(func(act_def: ActDef) -> bool: return act_def.rift_learns), [false, false, true], "only Act 3 learns")


func test_it_repeats_and_is_fresh_on_a_replay() -> void:
	var habits: Array = [{"rooted": 12}, {"bunched": 6}]
	assert_eq(_picks(_on_day(7, habits)), _picks(_on_day(7, habits)), "the same seed and fights, the same picks")
	var changed: bool = false
	for run_seed: int in range(1, 12):
		var flow: RunFlow = _on_day(7, habits, run_seed)
		var before: Array = _picks(flow).duplicate(true)
		flow.state.attempt = 1
		flow._start_day()
		changed = changed or _picks(flow) != before
	assert_true(changed, "a replay after a loss draws afresh")


func test_an_endless_boss_floor_learns() -> void:
	var flow: RunFlow = _on_day(7, [{"rooted": 12}])
	flow.state.endless = true
	assert_eq(RiftLearns.picks(_run, flow.state, 0, BOSS).size(), 2)


func test_the_save_keeps_them() -> void:
	var flow: RunFlow = _on_day(7, [{"rooted": 12}, {"bunched": 6}])
	assert_false(_picks(flow).is_empty())
	var data: Dictionary = JSON.parse_string(JSON.stringify(flow.state.to_dict()))
	assert_eq(int(data["version"]), 10)
	var loaded: RunState = RunState.from_dict(data)
	assert_eq(loaded.today_learned, flow.state.today_learned)
	assert_eq(loaded.fought.map(func(fought: RunState.Fought) -> Dictionary: return fought.habits), flow.state.fought.map(func(fought: RunState.Fought) -> Dictionary: return fought.habits))
	data["version"] = 9
	data.erase("today_learned")
	for fought: Variant in data["fought"]:
		(fought as Dictionary).erase("habits")
	var old: RunState = RunState.from_dict(data)
	assert_eq(old.today_learned, [] as Array[Array], "a version 9 save has none")
	assert_true(old.fought.all(func(fought: RunState.Fought) -> bool: return fought.habits.is_empty()))


func test_the_data() -> void:
	assert_eq(_run.learns.fights, 3)
	assert_eq(_run.learns.habits.size(), 10, "enemy-growth.md's ten habits")
	for bad: Dictionary in [{"measure": "dancing"}, {"upgrades": [], "specializations": []}, {"per_fight": 0}]:
		var habit: Dictionary = {"id": "roots", "name": "Roots", "against": "your Roots", "measure": "rooted", "per_fight": 4, "upgrades": ["anchored"]}
		habit.merge(bad, true)
		var errors: Array[String] = []
		RiftLearnsDef.read(DataReader.new({"fights": 3, "second_at_pct": 100, "habits": [habit]}, "learns", errors))
		assert_false(errors.is_empty(), str(bad))
	var errors: Array[String] = []
	var twice: Dictionary = {"id": "roots", "name": "Roots", "against": "your Roots", "measure": "rooted", "per_fight": 4, "upgrades": ["anchored"]}
	RiftLearnsDef.read(DataReader.new({"fights": 3, "second_at_pct": 100, "habits": [twice, twice]}, "learns", errors))
	assert_true(errors.any(func(error: String) -> bool: return error.contains("twice")), str(errors))
	var texts: Dictionary[String, String] = {}
	for file_name: String in RunContent.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[RunContent.RIFT_LEARNS_FILE] = JSON.stringify({"fights": 3, "second_at_pct": 100, "habits": [{"id": "x", "name": "X", "against": "your X", "measure": "front", "per_fight": 1,
		"upgrades": ["no_upgrade"], "specializations": ["no_spec"]}]})
	var run: RunContent = RunContent.load_texts(texts, ContentDb.load_dir("res://data"))
	assert_true(run.errors.any(func(error: String) -> bool: return error.contains("unknown enemy upgrade \"no_upgrade\"")), str(run.errors))
	assert_true(run.errors.any(func(error: String) -> bool: return error.contains("unknown specialization \"no_spec\"")), str(run.errors))
	var act: Dictionary = JSON.parse_string(texts[RunContent.ACT_FILE])
	act["rift_learns"] = true
	texts[RunContent.ACT_FILE] = JSON.stringify(act)
	texts.erase(RunContent.RIFT_LEARNS_FILE)
	run = RunContent.load_texts(texts, ContentDb.load_dir("res://data"))
	assert_true(run.acts[0].rift_learns)
	assert_true(run.errors.any(func(error: String) -> bool: return error.contains("the rift learns needs")), str(run.errors))


func test_the_fight_cards_line() -> void:
	var boss: EncounterDef = _run.content.encounters[BOSS]
	assert_eq(RunDayScreen.learned_line(_run, boss, []), "")
	var line: String = RunDayScreen.learned_line(_run, boss, [{"enemy": 2, "habit": "roots", "upgrade": "anchored"}, {"enemy": 1, "habit": "bunching", "specialization": "drifting_moth"}])
	assert_eq(line, "Learned: Anchored Rift Hound, against your Roots: %s\nDrifting Cinder Moth, against your bunching up: %s" % [_run.content.enemy_upgrades["anchored"].text, _run.content.specializations["drifting_moth"].text])
