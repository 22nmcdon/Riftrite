extends GutTest
## Edric's run pieces (phase 8 part 5, docs/plans/rebuild-phase8-severine-
## edric.md section 6, 8e-3b): Tithe paid after a won day fight for each
## hero standing (TitheDef: its stage's, its cards'), its deed counted by the
## run (Decision 3), Collection's shards from a fight, the shards held passed
## to the fight, the apexes' run snowballs on flawless fights (Collector of
## Debts' Tithe, Golden Aegis's max HP for every hero, Gold Leaf's), Ward
## Tax's shards needed, Ledger of Debts' steps, and the pay line.

const Bot = preload("res://tools/run_bot.gd")
const TEAM_VOWS: Dictionary[String, String] = {"brannoc": "hearthwall", "maren": "deadeye", "edric": "tithe_collector"}

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _at_fight(run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, TEAM_VOWS, errors)
	assert_eq(errors, [] as Array[String])
	flow.choose_fight(0)
	return flow


## A won fight's result, `fallen` heroes down at its end, and `shards`
## SHARDS lines from Edric's Collection.
func _won(fallen: Array[String] = [], shards: int = 0) -> FightResult:
	var result := FightResult.new()
	result.outcome = FightResult.Outcome.VICTORY
	result.end_tick = 600
	for hero_id: String in fallen:
		var death := LogEntry.new()
		death.kind = LogEntry.Kind.DEATH
		death.target = hero_id
		result.combat_log.add(death)
	for i: int in shards:
		var paid := LogEntry.new()
		paid.kind = LogEntry.Kind.SHARDS
		paid.source_unit = "edric"
		paid.source_ability = "collection_dues"
		paid.target = "edric"
		paid.amount = 1
		result.combat_log.add(paid)
	return result


func _formation(flow: RunFlow) -> Dictionary[String, Vector2i]:
	var team: Array[String] = []
	for hero: RunState.Hero in flow.state.heroes:
		team.append(hero.id)
	return HeroTeam.place(_run.content, team, HeroTeam.GUARDED)


func _pay(flow: RunFlow) -> int:
	var tier: String = _run.content.encounters[flow.state.chosen].tier
	return flow.act.pay[tier]


func _apex(flow: RunFlow, apex_id: String) -> RunState.Hero:
	var edric: RunState.Hero = flow.state.hero("edric")
	edric.transformed = true
	edric.apex = apex_id
	edric.apex_earned = true
	return edric


func test_the_tithe_reads() -> void:
	var errors: Array[String] = []
	var tithe: TitheDef = TitheDef.read(DataReader.new({"per_standing": 2, "elite_bp": 10000}, "tithe", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([tithe.pays(3, 0, "easier", 0, 0), tithe.pays(2, 1, "easier", 0, 0), tithe.pays(3, 0, "elite", 0, 0)], [6, 4, 12], "2 a standing hero, doubled after an elite")
	var debts: TitheDef = TitheDef.read(DataReader.new({"per_standing": 3, "flawless_add": 5, "flawless_grows": 1, "flawless_max": 15, "harder_add": 1, "fallen_pays": 1}, "tithe", errors))
	assert_eq(errors, [] as Array[String])
	assert_eq([debts.pays(3, 0, "easier", 0, 0), debts.pays(3, 0, "easier", 4, 0), debts.pays(3, 0, "easier", 40, 0), debts.pays(2, 1, "harder", 40, 2)],
		[14, 18, 29, 10], "the flawless bonus grows to its cap, and only without a fall")
	TitheDef.read(DataReader.new({}, "tithe", errors))
	assert_false(errors.is_empty(), "a Tithe pays something")
	assert_eq(tithe.merged(debts).per_standing, 5, "cards add on")


func test_tithe_pays_after_a_won_fight_and_fills_its_deed() -> void:
	var flow: RunFlow = _at_fight()
	var before: int = flow.state.shards
	var pay: int = _pay(flow)
	flow.record(_formation(flow), _won())
	assert_eq(flow.state.shards, before + pay + 3, "1 for each of 3 heroes standing, vowed")
	assert_eq(flow.state.fought.back().tithe, 3)
	assert_eq(flow.state.hero("edric").deeds["tithe_collector"], 3, "the deed is counted by the run")
	assert_string_contains(RunDayScreen.extra_pay(flow.state.fought.back()), "Tithe: +3")


func test_a_fallen_hero_pays_nothing_and_a_loss_pays_no_tithe() -> void:
	var flow: RunFlow = _at_fight()
	var before: int = flow.state.shards
	var pay: int = _pay(flow)
	flow.record(_formation(flow), _won(["maren"] as Array[String]))
	assert_eq(flow.state.shards, before + pay + 2, "2 standing")
	var lost: RunFlow = _at_fight()
	var held: int = lost.state.shards
	var result: FightResult = _won()
	result.outcome = FightResult.Outcome.DEFEAT
	lost.record(_formation(lost), result)
	assert_eq(lost.state.shards, held, "no Tithe for a loss")
	assert_eq(lost.state.hero("edric").deeds["tithe_collector"], 0)


func test_collection_pays_what_the_fight_gathered() -> void:
	var flow: RunFlow = _at_fight()
	var before: int = flow.state.shards
	var pay: int = _pay(flow)
	flow.record(_formation(flow), _won([] as Array[String], 2))
	assert_eq(flow.state.shards, before + pay + 3 + 2)
	assert_eq(flow.state.fought.back().collected, 2)
	assert_string_contains(RunDayScreen.extra_pay(flow.state.fought.back()), "Collection: +2")


func test_the_shards_held_go_into_the_fight() -> void:
	var flow: RunFlow = _at_fight()
	flow.state.shards = 42
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(_formation(flow), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(setup.shards, 42)
	var practice: PracticeSession = PracticeSession.make(_run.content)
	practice.shards = 30
	var fight: FightSetup = practice.setup("the_pack", practice.formation_for("the_pack"))
	assert_eq(fight.shards, 30, "Practice's setting (Decision 4)")


func test_collector_of_debts_grows_with_flawless_fights() -> void:
	var flow: RunFlow = _at_fight()
	var edric: RunState.Hero = _apex(flow, "collector_of_debts")
	var before: int = flow.state.shards
	var pay: int = _pay(flow)
	flow.record(_formation(flow), _won())
	assert_eq(flow.state.shards - before - pay, 3 * 3 + 5, "3 a hero, 5 more for none falling")
	assert_eq(edric.growth[RunContent.apex_growth_key(_run.content.apexes["collector_of_debts"])], 1, "a flawless fight counted")
	assert_eq(edric.deeds.get("collector_of_debts", 0), 0, "its deed counts from the apex vow, which earning it skipped here")
	assert_true(flow.state.grew.has("edric:apex:collector_of_debts"), "the day screen lists it")
	edric.growth["apex:collector_of_debts"] = 20
	flow.state.chosen = "the_pack"
	before = flow.state.shards
	flow.state.phase = RunState.Phase.LOADOUT
	flow.record(_formation(flow), _won())
	assert_eq(flow.state.shards - before - _pay(flow), 3 * 3 + 5 + 15, "the bonus stops at 15 more")
	flow.state.hero("edric").upgrades.append("insurance")
	flow.state.hero("edric").upgrades.append("compound_debt")
	assert_eq(_run.tithe(edric).fallen_pays, 1)
	assert_eq([_run.tithe(edric).flawless_grows, _run.tithe(edric).flawless_max], [2, 20], "Compound Debt")


func test_golden_aegis_grows_every_heros_max_hp() -> void:
	var flow: RunFlow = _at_fight()
	_apex(flow, "golden_aegis")
	var hp: int = flow.kit_of("maren").stats.get_stat(UnitStats.Stat.HP)
	flow.record(_formation(flow), _won())
	assert_eq(flow.kit_of("maren").stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(hp, 10100), "+1% for every hero, for the rest of the run")
	var fell: RunFlow = _at_fight()
	_apex(fell, "golden_aegis")
	fell.record(_formation(fell), _won(["brannoc"] as Array[String]))
	assert_eq(fell.state.hero("edric").growth.get("apex:golden_aegis", 0), 0, "only a fight with every hero standing")
	fell.state.hero("edric").upgrades.append("gold_leaf")
	fell.state.hero("edric").growth["gold_leaf"] = 2
	var mods: Array[KitMod] = _run.relic_mods(fell.state)
	assert_eq(mods.size(), 1, "Gold Leaf's steps go to every hero")
	assert_eq(mods[0].stats_bp[UnitStats.Stat.HP], 10100)


func test_ward_tax_needs_its_shards() -> void:
	var flow: RunFlow = _at_fight()
	var edric: RunState.Hero = _apex(flow, "golden_aegis")
	edric.upgrades.append("ward_tax")
	assert_eq(_run.upgrade_mods(edric, 29).size(), 0, "not below 30 shards")
	assert_eq(_run.upgrade_mods(edric, 30).size(), 1)
	assert_eq(_run.upgrade_mods(edric).size(), 1, "as if held, for what the card changes")
	assert_true(ModInfo.upgrade_numbers(_run.upgrades["ward_tax"], null, _run.content).contains("30+ shards"))


func test_ledger_of_debts_pays_more_as_the_run_wins() -> void:
	var flow: RunFlow = _at_fight()
	var edric: RunState.Hero = flow.state.hero("edric")
	edric.transformed = true
	edric.upgrades.append("ledger_of_debts")
	edric.growth["ledger_of_debts"] = 19
	var before: int = flow.state.shards
	var pay: int = _pay(flow)
	flow.record(_formation(flow), _won())
	assert_eq(flow.state.shards - before - pay, 2 * 3 + 1, "1 more for each 10 won before this one")
	assert_eq(edric.growth["ledger_of_debts"], 20, "and this one counts")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["ledger_of_debts"], null, _run.content), "Grows: +1 Tithe per 10 fights won (at most 5 times)")


func test_tithe_cards_are_offered_and_say_what_they_pay() -> void:
	var edric := RunState.Hero.new()
	edric.id = "edric"
	edric.path = "tithe_collector"
	edric.deeds.assign({"aegis": 0, "tithe_collector": 0, "psalmist": 0})
	var offered: Array[String] = _run.upgrades_for(edric)
	assert_true(offered.has("elite_tithe") and offered.has("bold_tithe"), "a card that only changes Tithe still changes something")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["elite_tithe"], null, _run.content), "Tithe: +100% after an elite")
	edric.upgrades.append("elite_tithe")
	assert_eq(_run.tithe(edric).elite_bp, 10000)
	assert_eq(_run.tithe(edric).per_standing, 1)
