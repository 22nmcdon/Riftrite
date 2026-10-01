extends GutTest
## The relic pool's first part (docs/plans/rebuild-phase5c-combos.md, step
## 5a, section 10): the tiers, every 5a relic's effect (in a small fight, on
## a kit, or on the run), the run rules, the shops' relics and rerolls, the
## pre-boss shop, and the boss relic choice.

const Bot = preload("res://tools/run_bot.gd")
const K = preload("res://tests/sim/sim_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start(run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


func _hold(flow: RunFlow, ids: Array) -> void:
	for id: String in ids:
		flow.state.relic_choice.assign([id])
		assert_eq(flow.take_relic(0), "", id)


func _won(fallen: Array[String] = []) -> FightResult:
	var result := FightResult.new()
	result.outcome = FightResult.Outcome.VICTORY
	result.end_tick = 600
	for hero_id: String in fallen:
		var entry := LogEntry.new()
		entry.kind = LogEntry.Kind.DEATH
		entry.target = hero_id
		result.combat_log.add(entry)
	return result


func _to_fight(flow: RunFlow) -> void:
	if flow.state.phase == RunState.Phase.CAMP:
		assert_eq(flow.leave_camp(), "")
	assert_eq(flow.choose_fight(0), "")


## A standing hero (speed 0, range 2) hitting every tick for 10, with `relic`'s
## mod, against a sturdy dummy.
func _duel(relic: String, attack: Dictionary = {}, dummy_hp: int = 100000) -> CombatSim:
	var basic: Dictionary = {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	var hero: UnitDef = _run.relics[relic].mod.apply(K.kit("hero", {"stats": {"hp": 1000, "atk": 10, "speed": 0, "range": 2}, "basic_attack": basic}))
	var dummy: UnitDef = K.kit("dummy", {"stats": {"hp": dummy_hp, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(dummy, 3, 4)] as Array[UnitSetup]))


func _hits(fight: CombatSim) -> Array:
	return K.entries(fight, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> int: return entry.amount)


# --- the pool -----------------------------------------------------------------------

func test_the_tiers() -> void:
	assert_true(_run.is_valid(), "\n".join(_run.errors))
	var counts: Array[int] = [0, 0, 0, 0, 0]
	for id: String in _run.relic_ids:
		counts[_run.relics[id].tier] += 1
	assert_eq(counts, [17, 13, 5, 5, 4] as Array[int], "common, rare, epic, legendary, boss")
	for id: String in ["pilgrims_lantern", "hungry_blade"]:
		assert_false(_run.relics.has(id), "%s is cut" % id)
	assert_eq(_run.act.relic_prices, {"common": 5, "rare": 12, "epic": 20, "legendary": 30, "boss": 0} as Dictionary[String, int])


func test_every_relic_says_what_it_does_with_its_numbers() -> void:
	for id: String in _run.relic_ids:
		var relic: RelicDef = _run.relics[id]
		assert_false(relic.text.is_empty(), id)
		assert_false(ModInfo.relic_numbers(relic, _run.content).is_empty(), "%s has a numbers line" % id)


# --- relics on a kit ------------------------------------------------------------------

func test_relics_on_every_heros_stats() -> void:
	var flow: RunFlow = _start()
	var before: UnitStats = flow.kit_of("brannoc").stats
	_hold(flow, ["whetstone_of_the_fallen", "iron_filings", "quickened_pulse", "bone_dice"])
	var after: UnitStats = flow.kit_of("brannoc").stats
	assert_eq(after.get_stat(UnitStats.Stat.ATK), before.get_stat(UnitStats.Stat.ATK) + 6)
	assert_eq(after.get_stat(UnitStats.Stat.DEF), before.get_stat(UnitStats.Stat.DEF) + 6)
	assert_eq(after.get_stat(UnitStats.Stat.ATSP), before.get_stat(UnitStats.Stat.ATSP) + 8, "+8% attack speed is +8 ATSP")
	assert_eq(after.get_stat(UnitStats.Stat.CRIT), before.get_stat(UnitStats.Stat.CRIT) + 6)


func test_mana_relics() -> void:
	var flow: RunFlow = _start()
	var before: ManaDef = flow.kit_of("vell").mana
	_hold(flow, ["rift_candle", "hollow_drum"])
	var after: ManaDef = flow.kit_of("vell").mana
	assert_eq(after.regen_per_s, before.regen_per_s + 1)
	assert_eq(after.max, FixedMath.apply_bp(before.max, 9200), "8% less to fill")


func test_the_second_sun_echoes_signatures_at_full_strength() -> void:
	var flow: RunFlow = _start()
	_hold(flow, ["the_second_sun"])
	var signature: AbilityDef = flow.kit_of("vell").signature
	assert_eq(signature.echo_ticks, 10)
	assert_eq(signature.echo.effects[0].amount, signature.effects[0].amount, "at 100%")


# --- relics in a fight ---------------------------------------------------------------

func test_brand_of_guilt_marks_the_first_enemy_hit() -> void:
	var fight: CombatSim = _duel("brand_of_guilt")
	K.step(fight, 3)
	var marks: Array[LogEntry] = K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").filter(func(entry: LogEntry) -> bool: return entry.status == "marked")
	assert_eq(marks.size(), 1, "once a fight")


func test_bonuses_against_some_enemies() -> void:
	var low: CombatSim = _duel("headsmans_coin")
	K.step(low, 1)
	low.units[1].hp = low.units[1].max_hp / 4
	K.step(low, 1)
	assert_eq(_hits(low), [10, 11], "+10% once it's below 30% HP")
	var rooted: CombatSim = _duel("thornwoven_cloak")
	Statuses.apply(rooted, rooted.units[1], "root", 1, 100, EffectSource.make("x", "x", "X"))
	K.step(rooted, 1)
	assert_eq(_hits(rooted), [13], "+25% to a Rooted enemy (12.5, rounded)")


func test_ashen_censer_adds_burn_to_the_burning() -> void:
	var fight: CombatSim = _duel("ashen_censer")
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").size(), 0, "not Burning yet")
	Statuses.apply(fight, fight.units[1], "burn", 5, 0, EffectSource.make("x", "x", "X"))
	K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED, "hero").map(func(entry: LogEntry) -> String: return entry.status), ["burn"])


func test_the_ninth_arrow() -> void:
	var fight: CombatSim = _duel("the_ninth_arrow")
	K.step(fight, 9)
	assert_eq(_hits(fight).slice(-2), [10, 20], "the 9th hit strikes again for twice its damage: triple in all")


func test_mirror_of_ash_and_sunder() -> void:
	var biter: UnitDef = K.kit("biter", {"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 10, "target": "target"}]}})
	var hero: UnitDef = _run.relics["mirror_of_ash"].mod.apply(K.kit("hero", {"stats": {"hp": 1000, "atk": 0, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}))
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(biter, 3, 4)] as Array[UnitSetup]))
	K.step(fight, 1)
	assert_eq(_hits(fight), [6], "60% of the 10 it took")
	var sunder: CombatSim = _duel("sunder")
	sunder.units[1].base_stats.values[UnitStats.Stat.DEF] = 10
	sunder.units[1].stats.values[UnitStats.Stat.DEF] = 10
	K.step(sunder, 4)
	assert_eq(sunder.units[1].defense(), 10 - 4, "each hit takes 1 DEF off")


func test_echoing_bell_gives_the_others_mana() -> void:
	var flow: RunFlow = _start()
	_hold(flow, ["echoing_bell"])
	assert_true(flow.kit_of("maren").passives.any(func(part: PartDef) -> bool: return part.id == "echoing_bell"), "every hero holds it")


# --- run rules ----------------------------------------------------------------------

func test_prices_and_rerolls() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.shards = 100
	flow.open_shop("pedlar")
	assert_eq([flow.reroll_price(), flow.wound_price()], [1, 4])
	flow.reroll()
	flow.reroll()
	assert_eq(flow.reroll_price(), 3, "1, then 2, then 3")
	flow.close_shop()
	_hold(flow, ["tinkers_purse", "merchants_covenant", "menders_purse"])
	flow.open_shop("pedlar")
	assert_eq([flow.reroll_price(), flow.wound_price()], [0, 2], "the first reroll free; a wound 2 less")
	flow.reroll()
	flow.reroll()
	assert_eq(flow.reroll_price(), 1, "never more than the first price")


func test_shop_rules() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	_hold(flow, ["the_magpies_scale", "misers_vault"])
	state.shards = 30
	flow.open_shop("pedlar")
	assert_eq(state.shards, 36, "Miser's Vault: 1 per 5 held, at most 6")
	assert_eq([state.shop_relics.size(), state.wares.size()], [2, _run.act.pedlar_wares + 1], "one more relic and one more ware")


func test_elites_pay_more_and_tally_of_the_dead_grows() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	_hold(flow, ["bounty_hunters_tag", "tally_of_the_dead"])
	state.day = 3
	state.phase = RunState.Phase.ROUTE
	assert_eq(flow.choose_fight(0), "")
	assert_eq(_run.content.encounters[state.chosen].tier, "elite")
	var before: int = state.shards
	var hp: int = flow.kit_of("maren").stats.get_stat(UnitStats.Stat.HP)
	flow.record(Bot.formation(), _won())
	assert_eq(state.shards, before + _run.act.pay["elite"] + 6)
	assert_eq(state.growth["tally_of_the_dead"], 1)
	assert_eq(flow.kit_of("maren").stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(hp, 10200), "+2% max HP an elite")
	assert_eq(state.relic_choice.size(), 2, "an elite's relic choice")


func test_bounty_board_pays_once_for_a_streak() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	_hold(flow, ["bounty_board"])
	for fallen: Array[String] in [[] as Array[String], ["maren"] as Array[String], [] as Array[String], [] as Array[String]]:
		_to_fight(flow)
		flow.record(Bot.formation(), _won(fallen))
		flow.take_shards()
		flow.state.relic_choice.clear()
		flow.finish_day()
	assert_eq(state.streak, 2, "the fall reset it")
	var before: int = state.shards
	_to_fight(flow)
	flow.record(Bot.formation(), _won())
	assert_eq(state.shards - before, _run.act.pay[_run.content.encounters[state.chosen].tier] + 25, "3 in a row: +25")
	assert_eq(state.streaks_paid, ["bounty_board"] as Array[String])


func test_relics_that_pay_with_what_the_team_does() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	_hold(flow, ["bloodied_coin", "lucky_strike", "collectors_chain"])
	_to_fight(flow)
	var setup: FightSetup = flow.fight_setup(Bot.formation(), [] as Array[String])
	assert_true(setup.heroes[0].tally_keys.has("relic:bloodied_coin"))
	var result: FightResult = _won()
	for hero_id: String in ["brannoc", "maren", "vell"]:
		result.tallies.append(FightResult.Deed.make(hero_id, "relic:bloodied_coin", 2))
		result.tallies.append(FightResult.Deed.make(hero_id, "relic:collectors_chain", 4))
		result.tallies.append(FightResult.Deed.make(hero_id, "relic:lucky_strike", 5))
	var before: int = state.shards
	var atk: int = flow.kit_of("maren").stats.get_stat(UnitStats.Stat.ATK)
	flow.record(Bot.formation(), result)
	assert_eq(state.shards - before, _run.act.pay[_run.content.encounters[state.chosen].tier] + 6 + 1, "6 kills, and 15 crits")
	assert_eq(flow.kit_of("maren").stats.get_stat(UnitStats.Stat.ATK), atk + 1, "12 kills: one step of Collector's Chain")


func test_chalk_ledger_is_a_quest() -> void:
	var growth: GrowthDef = _run.relics["chalk_ledger"].grows
	assert_eq([growth.steps(39), growth.steps(40), growth.steps(400)], [0, 1, 1])


func test_rift_bound_heart_doubles_growth() -> void:
	var flow: RunFlow = _start()
	_hold(flow, ["collectors_chain", "rift_bound_heart"])
	_to_fight(flow)
	var result: FightResult = _won()
	result.tallies.append(FightResult.Deed.make("maren", "relic:collectors_chain", 5))
	flow.record(Bot.formation(), result)
	assert_eq(flow.state.growth["collectors_chain"], 10)


func test_relics_worked_out_from_the_run() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	var atk: int = flow.kit_of("maren").stats.get_stat(UnitStats.Stat.ATK)
	var hp: int = flow.kit_of("maren").stats.get_stat(UnitStats.Stat.HP)
	_hold(flow, ["gilded_rift"])
	state.shards = 24
	assert_eq(flow.kit_of("maren").stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(atk, 10400), "+1% per 5 shards held: 4 steps")
	state.shards = 0
	_hold(flow, ["reliquary_lamp", "bone_dice"])
	assert_eq(flow.kit_of("maren").stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(hp, 10600), "+2% for each of the 3 relics")


func test_the_hollow_throne_takes_two_cards() -> void:
	var flow: RunFlow = _start()
	_hold(flow, ["the_hollow_throne"])
	_to_fight(flow)
	flow.record(Bot.formation(), _won())
	assert_eq([flow.state.pick.size(), flow.state.picks_left], [3, 2])
	assert_eq(flow.take_pick(0), "")
	assert_eq(flow.state.pick.size(), 2, "one more to take")
	assert_eq(flow.take_pick(0), "")
	assert_eq(flow.state.pick, [] as Array[String])


func test_the_hollow_covenant_shares_the_best_stats() -> void:
	var flow: RunFlow = _start()
	var best_hp: int = 0
	for hero_id: String in ["brannoc", "maren", "vell"]:
		best_hp = maxi(best_hp, flow.kit_of(hero_id).stats.get_stat(UnitStats.Stat.HP))
	_hold(flow, ["the_hollow_covenant"])
	for hero_id: String in ["brannoc", "maren", "vell"]:
		assert_eq(flow.kit_of(hero_id).stats.get_stat(UnitStats.Stat.HP), best_hp, hero_id)


# --- where relics come from -------------------------------------------------------------

func test_the_pre_boss_shop() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.day = 7
	flow.state.camp = Offers.camp(_run, state)[1]
	assert_true(state.camp.has("pedlar"), "the boss day's camp always has the Pedlar")
	assert_eq(flow.open_shop("pedlar"), "")
	assert_true(flow.pre_boss_shop())
	assert_eq(state.shop_relics.size(), 2)
	assert_eq(_run.relics[state.shop_relics[0]].tier, RelicDef.Tier.LEGENDARY, "a legendary first")
	assert_ne(_run.relics[state.shop_relics[1]].tier, RelicDef.Tier.LEGENDARY, "and one of another tier")
	assert_eq(flow.reroll_price(), 5, "rerolls start at 5")
	state.shards = 5
	assert_eq(flow.reroll(), "")
	assert_eq(flow.reroll_price(), 6)


func test_an_elite_sometimes_offers_an_epic() -> void:
	var epics: int = 0
	for run_seed: int in range(1, 31):
		var flow: RunFlow = _start(run_seed)
		var choice: Array[String] = Offers.relics(_run, flow.state, RunFlow.RELIC_AFTER_FIGHT, 2, "rare", _run.act.elite_epic_pct)
		assert_eq(choice.size(), 2)
		for id: String in choice:
			assert_true(_run.relics[id].tier == RelicDef.Tier.RARE or _run.relics[id].tier == RelicDef.Tier.EPIC)
			epics += 1 if _run.relics[id].tier == RelicDef.Tier.EPIC else 0
	assert_between(epics, 3, 20, "about 1 in 3 (%d of 30)" % epics)


func test_shop_relics_save() -> void:
	var flow: RunFlow = _start()
	flow.open_shop("pedlar")
	flow.state.shards = 5
	flow.reroll()
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_eq([loaded.shop_relics, loaded.rerolls], [flow.state.shop_relics, 1])


func test_a_relic_that_looks_for_engaged_enemies_can_be_fought() -> void:
	var flow: RunFlow = _start()
	_hold(flow, ["rusted_fetter"])
	_to_fight(flow)
	var errors: Array[String] = []
	assert_not_null(flow.fight_setup(Bot.formation(), errors))
	assert_eq(errors, [] as Array[String], "it names Engaged only in a condition")
