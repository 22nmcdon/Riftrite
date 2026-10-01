extends GutTest
## Growing cards (docs/plans/rebuild-phase5c-combos.md, step 4, section 9):
## a step's mod times the steps, the cards as data, counting in the run from
## when a card is taken, a relic's team count, a quest's cap, the save, and
## the lines the cards show.

const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _mod(data: Dictionary, errors: Array[String] = []) -> KitMod:
	return KitMod.read(DataReader.new(data, "mod", errors))


func _growth(data: Dictionary, errors: Array[String] = []) -> GrowthDef:
	return GrowthDef.read(DataReader.new(data, "grows", errors))


func _at_fight(run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	flow.choose_fight(0)
	return flow


## A won fight's result that counted `amount` for `hero_id`'s card `key`.
func _counted(tallies: Array) -> FightResult:
	var result := FightResult.new()
	result.outcome = FightResult.Outcome.VICTORY
	result.end_tick = 600
	for tally: Array in tallies:
		result.tallies.append(FightResult.Deed.make(tally[0], tally[1], tally[2]))
	return result


func _give(flow: RunFlow, upgrade_id: String) -> void:
	var upgrade: UpgradeDef = _run.upgrades[upgrade_id]
	flow.state.pick.assign([upgrade_id])
	assert_eq(flow.take_pick(0), "")


# --- a step, times over ---------------------------------------------------------------

func test_a_step_times_over() -> void:
	var step: KitMod = _mod({"stats_bp": {"atk": 10100}, "stats_add": {"def": 1}, "on": [{"slot": "signature", "amount_bp": 10200}],
		"passives": [{"id": "glow", "name": "Glow", "kind": "aura", "aura": {"target": "holder", "stat": "heal_bp", "value": 10100}},
			{"id": "quick", "name": "Quick", "kind": "aura", "aura": {"target": "holder", "stat": "cooldown_bp", "value": -100}}]})
	assert_eq(step.step_problem(), "")
	assert_null(step.times(0), "no step, no mod")
	var ten: KitMod = step.times(10)
	assert_eq(ten.stats_bp[UnitStats.Stat.ATK], 11000, "ten +1% steps are +10%")
	assert_eq(ten.stats_add[UnitStats.Stat.DEF], 10)
	assert_eq(ten.changes[0].amount_bp, 12000)
	assert_eq([ten.passives[0].aura.value, ten.passives[1].aura.value], [11000, -1000], "a factor's change and an addition, ten times")
	assert_eq(step.passives[0].aura.value, 10100, "the step itself is untouched")


func test_a_step_may_only_change_what_scales() -> void:
	for data: Dictionary in [{"mana": {"start_add": 5}}, {"echo": {"after_ms": 1000, "share_pct": 50}},
			{"on": [{"slot": "signature", "radius_add": 1}]},
			{"passives": [{"id": "x", "name": "X", "kind": "ability", "effects": [{"trigger": "on_hop", "type": "shield", "amount": 1, "target": "self"}]}]}]:
		var errors: Array[String] = []
		_growth({"counts": {"counts": "damage"}, "per": 10, "each": data}, errors)
		assert_false(errors.is_empty(), "refused: %s" % data)


func test_steps_are_whole_and_a_quest_stops_at_one() -> void:
	var growth: GrowthDef = _growth({"counts": {"counts": "kills"}, "per": 10, "each": {"stats_add": {"atk": 1}}})
	assert_eq([growth.steps(0), growth.steps(9), growth.steps(10), growth.steps(35)], [0, 0, 1, 3])
	var quest: GrowthDef = _growth({"counts": {"counts": "applied", "keywords": ["marked"]}, "per": 40, "max_steps": 1, "each": {"stats_add": {"atk": 1}}})
	assert_eq([quest.steps(39), quest.steps(40), quest.steps(400)], [0, 1, 1])


# --- the cards ---------------------------------------------------------------------------

func test_the_twelve_growing_upgrades_load_and_say_how_they_grow() -> void:
	assert_true(_run.is_valid(), "\n".join(_run.errors))
	var growing: Array[String] = _run.upgrade_ids.filter(func(id: String) -> bool: return _run.upgrades[id].grows != null)
	assert_eq(growing.size(), 12)
	for id: String in growing:
		var line: String = ModInfo.upgrade_numbers(_run.upgrades[id], null, _run.content)
		assert_true(line.begins_with("Grows: ") and line.contains("1"), "%s: %s" % [id, line])
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["notched_bow"], null, _run.content), "Grows: +1% ATK per 3 enemies Marked")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["borrowed_time"], null, _run.content), "Grows: +1% damage below 30% HP per 8s below 30% HP")


func test_the_now_line() -> void:
	var growth: GrowthDef = _run.upgrades["notched_bow"].grows
	assert_eq(ModInfo.growth_now(growth, 2, null, _run.content), "Now: nothing yet (2 / 3 enemies Marked to the next)")
	assert_eq(ModInfo.growth_now(growth, 10, null, _run.content), "Now: +3% ATK (1 / 3 enemies Marked to the next)")


# --- in the run ---------------------------------------------------------------------------

func test_a_card_counts_from_when_its_taken_and_reaches_the_next_fight() -> void:
	var flow: RunFlow = _at_fight()
	flow.record({}, _counted([["maren", "upgrade:notched_bow", 50]]))
	assert_false(flow.state.hero("maren").growth.has("notched_bow"), "not held: nothing counted")
	flow = _at_fight()
	_give(flow, "notched_bow")
	assert_eq(flow.state.hero("maren").growth["notched_bow"], 0, "it starts at nothing")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(_formation(flow), errors)
	assert_eq(errors, [] as Array[String])
	var maren: UnitSetup = setup.heroes.filter(func(unit: UnitSetup) -> bool: return unit.id == "maren")[0]
	assert_eq(maren.tally_keys, ["upgrade:notched_bow"] as Array[String], "the fight counts it")
	var atk_before: int = maren.def.stats.get_stat(UnitStats.Stat.ATK)
	flow.record(_formation(flow), _counted([["maren", "upgrade:notched_bow", 25]]))
	assert_eq(flow.state.hero("maren").growth["notched_bow"], 25)
	assert_eq(flow.state.grew, ["maren:notched_bow"] as Array[String], "it stepped up (8 times)")
	var kit: UnitDef = flow.kit_of("maren")
	assert_eq(kit.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(atk_before, 10800), "+8% ATK")


func test_a_relic_counts_the_whole_team() -> void:
	var flow: RunFlow = _at_fight()
	var relic := RelicDef.new()
	relic.id = "test_chain"
	relic.name = "Test Chain"
	relic.grows = _growth({"counts": {"counts": "kills"}, "per": 10, "each": {"stats_add": {"atk": 1}}})
	_run.relics["test_chain"] = relic
	flow.state.relics.append("test_chain")
	flow.state.growth["test_chain"] = 0
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(_formation(flow), errors)
	for hero: UnitSetup in setup.heroes:
		assert_true(hero.tally_keys.has("relic:test_chain"), "%s counts for it" % hero.id)
	flow.record(_formation(flow), _counted([["maren", "relic:test_chain", 6], ["vell", "relic:test_chain", 5], ["brannoc", "relic:test_chain", 1]]))
	assert_eq(flow.state.growth["test_chain"], 12, "every hero's count, added up")
	assert_eq(flow.state.grew, [":test_chain"] as Array[String])
	for hero_id: String in ["maren", "brannoc", "vell"]:
		var base: int = _run.hero_kit(flow.state.hero(hero_id)).stats.get_stat(UnitStats.Stat.ATK)
		assert_gt(flow.kit_of(hero_id).stats.get_stat(UnitStats.Stat.ATK), base, "%s has the step" % hero_id)
	_run.relics.erase("test_chain")


func test_growth_survives_a_save() -> void:
	var flow: RunFlow = _at_fight()
	_give(flow, "notched_bow")
	flow.record(_formation(flow), _counted([["maren", "upgrade:notched_bow", 13]]))
	flow.state.growth["some_relic"] = 7
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_eq(loaded.hero("maren").growth, {"notched_bow": 13} as Dictionary[String, int])
	assert_eq(loaded.growth, {"some_relic": 7} as Dictionary[String, int])
	assert_eq(loaded.grew, flow.state.grew)


func test_a_real_fight_counts_and_the_screen_lists_what_grew() -> void:
	var flow: RunFlow = _at_fight()
	_give(flow, "notched_bow")
	flow.state.hero("maren").growth["notched_bow"] = 9
	var errors: Array[String] = []
	var result: FightResult = flow.fight(_formation(flow), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(flow.state.hero("maren").growth["notched_bow"], 9 + result.tally_amount("maren", "upgrade:notched_bow"))


func _formation(flow: RunFlow) -> Dictionary[String, Vector2i]:
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(2, 0), "vell": Vector2i(5, 0)}
	return formation
