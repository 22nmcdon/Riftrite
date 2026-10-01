extends GutTest
## The upgrade pools (docs/plans/upgrade-pools.md; phase 5c step 7,
## docs/plans/rebuild-phase5c-combos.md, section 15): what each hero is
## offered by stage, cards that would change nothing, and stacking cards'
## lock-in.

const Bot = preload("res://tools/run_bot.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start() -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, 7, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


func _hero(hero_id: String, path_id: String, transformed: bool = false) -> RunState.Hero:
	var hero := RunState.Hero.new()
	hero.id = hero_id
	hero.path = path_id
	hero.transformed = transformed
	return hero


## Takes stacking card `id` through the pick, and returns what it locked in.
func _take(flow: RunFlow, id: String) -> int:
	flow.state.pick.assign([id])
	flow.state.picks_left = 1
	assert_eq(flow.take_pick(0), "")
	var locked: Array = flow.state.hero(_run.upgrades[id].hero).locked[id]
	return int(locked[locked.size() - 1])


func _stat(flow: RunFlow, hero_id: String, stat: UnitStats.Stat) -> int:
	var hero: RunState.Hero = flow.state.hero(hero_id)
	var kit: UnitDef = _run.hero_kit(hero)
	for mod: KitMod in _run.upgrade_mods(hero):
		kit = mod.apply(kit)
	return kit.stats.values[stat]


func test_the_pools_by_stage() -> void:
	var maren: RunState.Hero = _hero("maren", "trapper")
	var offered: Array[String] = _run.upgrades_for(maren)
	assert_true(offered.has("tight_weave"), "vowed: Trapper's taste")
	assert_false(offered.has("steady_hands"), "not another path's taste")
	assert_false(offered.has("tangle"), "not Trapper's path cards yet")
	maren.path = "deadeye"
	offered = _run.upgrades_for(maren)
	assert_true(offered.has("steady_hands") and not offered.has("tight_weave"), "Switch vow swaps the taste cards")
	maren.transformed = true
	offered = _run.upgrades_for(maren)
	assert_false(offered.has("steady_hands"), "transformed: no taste cards")
	assert_true(offered.has("hearts_refund") and offered.has("hunters_tally"), "but the path's cards, its growing one too")
	assert_true(offered.has("honed_tips"), "and her own, always")


func test_a_card_that_changes_nothing_is_never_offered() -> void:
	# Decision 37: Maren's Mark cards on a transformed path that never Marks,
	# Brannoc's taunt cards once Hearthwall's wall replaces his taunt.
	var maren: RunState.Hero = _hero("maren", "trapper")
	assert_true(_run.upgrades_for(maren).has("deep_mark"), "vowed, Marking Shot Marks")
	assert_true(_run.upgrades_for(maren).has("notched_bow"))
	maren.transformed = true
	assert_false(_run.upgrades_for(maren).has("deep_mark"), "Bramble Field never Marks")
	assert_false(_run.upgrades_for(maren).has("notched_bow"), "a growing card with nothing to count")
	assert_true(_run.upgrades_for(maren).has("parting_shot"), "she still hops")
	var brannoc: RunState.Hero = _hero("brannoc", "hearthwall", true)
	assert_false(_run.upgrades_for(brannoc).has("long_hold"), "no taunt")
	assert_false(_run.upgrades_for(brannoc).has("stubborn_taunt"), "an added passive that waits on a taunt")
	assert_true(_run.upgrades_for(_hero("brannoc", "last_watch", true)).has("stubborn_taunt"), "Last Rites taunts")
	maren.upgrades.append("deep_mark")
	assert_eq(_run.upgrade_mods(maren), [_run.upgrades["deep_mark"].mod] as Array[KitMod], "one held stays held")


func test_a_stacking_card_locks_in_a_share_of_the_stat_now() -> void:
	var flow: RunFlow = _start()
	assert_eq(_stat(flow, "maren", UnitStats.Stat.ATK), 22)
	assert_eq(_take(flow, "honed_tips"), 2, "10% of 22, rounded")
	assert_eq(_stat(flow, "maren", UnitStats.Stat.ATK), 24)
	assert_true(_run.upgrades_for(flow.state.hero("maren")).has("honed_tips"), "offered again")
	assert_eq(_take(flow, "honed_tips"), 2, "10% of 24")
	assert_eq(_take(flow, "keen_eye"), 2, "25% of 8 CRIT")
	assert_eq(_take(flow, "heavy_arm"), 1, "10% of 14 is 1.4: 1")
	assert_eq(_take(flow, "quick_draw"), 11, "attack speed: 10% of 100 + her 10 ATSP")
	assert_eq(_take(flow, "quick_glow"), 10, "Vell has no ATSP: 10% of 100")
	assert_eq(flow.state.hero("maren").upgrades.count("honed_tips"), 2, "listed once per take")
	assert_eq(_stat(flow, "maren", UnitStats.Stat.ATK), 26)


func test_the_lock_never_changes_after_a_transformation() -> void:
	var flow: RunFlow = _start()
	assert_eq(flow.state.hero("maren").path, "deadeye")
	assert_eq(_take(flow, "honed_tips"), 2)
	flow.state.hero("maren").transformed = true
	assert_eq(flow.state.hero("maren").locked["honed_tips"], [2], "still +2")
	# Deadeye transformed: ATK x1.05 (23), plus the locked 2.
	assert_eq(_stat(flow, "maren", UnitStats.Stat.ATK), 25)
	assert_eq(_take(flow, "honed_tips"), 3, "the next locks in 10% of 25, rounded up")


func test_at_least_one_point() -> void:
	var tiny: RunContent = RunContent.load_texts({
		RunContent.ACT_FILE: FileAccess.get_file_as_string("res://data/act1.json"),
		RunContent.UPGRADES_FILE: JSON.stringify([{"id": "dab", "name": "Dab", "text": "x", "hero": "maren", "stacks": {"stat": "crit", "pct": 1}}]),
	}, _run.content)
	assert_true(tiny.is_valid(), str(tiny.errors))
	assert_eq(tiny.stack_amount(_hero("maren", "deadeye"), tiny.upgrades["dab"]), 1, "1% of 8 CRIT rounds to 0: at least 1")


func test_the_locks_are_saved() -> void:
	var flow: RunFlow = _start()
	_take(flow, "honed_tips")
	_take(flow, "honed_tips")
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_not_null(loaded)
	assert_eq(loaded.hero("maren").locked["honed_tips"], [2, 2])
	assert_eq(loaded.hero("maren").upgrades.count("honed_tips"), 2)
	var old: Dictionary = flow.state.to_dict()
	old["version"] = 2
	assert_null(RunState.from_dict(old), "a save from before the upgrade pools doesn't load")


func test_the_cards_on_the_pick_say_their_layer() -> void:
	assert_eq(RunDayScreen.upgrade_source(_run.upgrades["steady_hands"], _run.content), "TASTE · DEADEYE")
	assert_eq(RunDayScreen.upgrade_source(_run.upgrades["hearts_refund"], _run.content), "PATH · DEADEYE")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["honed_tips"], null, _run.content), "+10% of ATK when taken (stacks)")
	assert_eq(ModInfo.stack_now(_run.upgrades["quick_draw"], 11), "+11% attack speed now · stacks")
	assert_eq(ModInfo.stack_locked(_run.upgrades["honed_tips"], [2, 3, 5]), "+2, +3, +5 ATK")


func test_crushing_blow_knocks_back_farther() -> void:
	# A mod's amount_bp scales a knockback's hexes when its types name it.
	var kit: UnitDef = _run.upgrades["crushing_blow"].mod.apply(_run.content.paths["ironbrand"].transformed_kit)
	var hexes: Array[int] = []
	for effect: EffectDef in kit.signature.effects:
		for inner: EffectDef in effect.area_effects:
			if inner.type == EffectDef.Type.KNOCKBACK:
				hexes.append(inner.hexes)
	assert_eq(hexes, [2] as Array[int])
	var errors: Array[String] = []
	var unnamed: UnitDef = KitMod.read(DataReader.new({"on": [{"slot": "signature", "amount_bp": 20000}]}, "x", errors)).apply(_run.content.paths["ironbrand"].transformed_kit)
	assert_eq(errors, [] as Array[String])
	for effect: EffectDef in unnamed.signature.effects:
		for inner: EffectDef in effect.area_effects:
			if inner.type == EffectDef.Type.KNOCKBACK:
				assert_eq(inner.hexes, 1, "a mod that doesn't name knockback never moves it")
