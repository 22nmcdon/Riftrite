extends GutTest
## The relic pool's first part (docs/plans/rebuild-phase5c-combos.md, step
## 5a, section 10): the tiers, every 5a relic's effect (in a small fight, on
## a kit, or on the run), the run rules, the shops' relics and rerolls, the
## boss shop, and the boss relic choice. And its second (step 5b,
## section 11): the 5b relics, their effects at a fight's start and Salt
## Circle in the run's fight setups, and Reliquary's doubling. And step 5c's
## engines (section 12.1).

const Bot = preload("res://tools/run_bot.gd")
const K = preload("res://tests/sim/sim_test_kit.gd")
const R = preload("res://tests/run/run_test_kit.gd")

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
	if flow.state.phase == RunState.Phase.SHOP:
		flow.close_shop()
		flow.state.phase = RunState.Phase.ROUTE
	assert_eq(flow.choose_fight(0), "")


## A standing hero (speed 0, range 2) hitting every tick for 10, with `relic`'s
## mod, against a sturdy dummy.
func _duel(relic: String, attack: Dictionary = {}, dummy_hp: int = 100000, stats: Dictionary = {}) -> CombatSim:
	var basic: Dictionary = {"cooldown_ms": 50, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}
	basic.merge(attack, true)
	var all_stats: Dictionary = {"hp": 1000, "atk": 10, "speed": 0, "range": 2}
	all_stats.merge(stats, true)
	var hero: UnitDef = _run.relics[relic].mod.apply(K.kit("hero", {"stats": all_stats, "basic_attack": basic}))
	var dummy: UnitDef = K.kit("dummy", {"stats": {"hp": dummy_hp, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	return K.sim(K.fight([K.at(hero, 3, 2)] as Array[UnitSetup], [K.foe(dummy, 3, 4)] as Array[UnitSetup]))


func _hits(fight: CombatSim) -> Array:
	return K.entries(fight, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> int: return entry.amount)


# --- the pool -----------------------------------------------------------------------

func test_the_tiers() -> void:
	assert_true(_run.is_valid(), "\n".join(_run.errors))
	var counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for id: String in _run.relic_ids:
		counts[_run.relics[id].tier] += 1
	assert_eq(counts, [25, 21, 14, 15, 11, 5] as Array[int], "common, rare, epic, legendary, boss, bond (Garrow's two since phase 8 part 4)")
	for id: String in ["pilgrims_lantern", "hungry_blade"]:
		assert_false(_run.relics.has(id), "%s is cut" % id)
	assert_eq(_run.acts[0].relic_prices, {"common": 5, "rare": 12, "epic": 20, "legendary": 30, "boss": 0, "bond": 0} as Dictionary[String, int])


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
	R.to_pedlar(flow)
	assert_eq([flow.reroll_price(), flow.wound_price()], [1, 4])
	flow.reroll()
	flow.reroll()
	assert_eq(flow.reroll_price(), 3, "1, then 2, then 3")
	flow.close_shop()
	_hold(flow, ["tinkers_purse", "merchants_covenant", "menders_purse"])
	R.to_pedlar(flow)
	assert_eq([flow.reroll_price(), flow.wound_price()], [0, 2], "the first reroll free; a wound 2 less")
	flow.reroll()
	flow.reroll()
	assert_eq(flow.reroll_price(), 1, "never more than the first price")


func test_shop_rules() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	_hold(flow, ["the_magpies_scale", "misers_vault"])
	state.shards = 30
	R.to_pedlar(flow)
	assert_eq(state.shards, 36, "Miser's Vault: 1 per 5 held, at most 6")
	assert_eq([state.shop_relics.size(), state.wares.size()], [2, _run.acts[0].pedlar_wares + 1], "one more relic and one more ware")


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
	assert_eq(state.shards, before + _run.acts[0].pay["elite"] + 6)
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
		assert_eq(R.next_day(flow), "")
	assert_eq(state.streak, 2, "the fall reset it")
	var before: int = state.shards
	_to_fight(flow)
	flow.record(Bot.formation(), _won())
	assert_eq(state.shards - before, _run.acts[0].pay[_run.content.encounters[state.chosen].tier] + 25, "3 in a row: +25")
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
	assert_eq(state.shards - before, _run.acts[0].pay[_run.content.encounters[state.chosen].tier] + 6 + 1, "6 kills, and 15 crits")
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

func test_the_boss_shop() -> void:
	var flow: RunFlow = _start()
	var state: RunState = flow.state
	state.day = 7
	state.phase = RunState.Phase.AFTER
	assert_eq(flow.finish_day(), "")
	assert_eq(state.shop, "pedlar", "the shop after the boss fight (Decision 48)")
	assert_true(flow.boss_shop())
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
		var choice: Array[String] = Offers.relics(_run, flow.state, RunFlow.RELIC_AFTER_FIGHT, 2, "rare", _run.acts[0].elite_epic_pct)
		assert_eq(choice.size(), 2)
		for id: String in choice:
			assert_true(_run.relics[id].tier == RelicDef.Tier.RARE or _run.relics[id].tier == RelicDef.Tier.EPIC)
			epics += 1 if _run.relics[id].tier == RelicDef.Tier.EPIC else 0
	assert_between(epics, 3, 20, "about 1 in 3 (%d of 30)" % epics)


func test_shop_relics_save() -> void:
	var flow: RunFlow = _start()
	R.to_pedlar(flow)
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


# --- step 5b ----------------------------------------------------------------------------

func _setup_holding(ids: Array) -> FightSetup:
	var flow: RunFlow = _start()
	_hold(flow, ids)
	_to_fight(flow)
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	return setup


func test_relics_at_a_fights_start_go_into_the_setup() -> void:
	var setup: FightSetup = _setup_holding(["bramble_seed", "tithe_of_iron", "salt_circle"])
	assert_eq(setup.relic_sources.map(func(source: EffectSource) -> String: return source.ability_name), ["Bramble Seed", "Tithe of Iron"])
	assert_eq(setup.relic_scales, [FixedMath.BP_ONE, FixedMath.BP_ONE] as Array[int])
	assert_eq(setup.salt_circles, 1)
	var fight: CombatSim = CombatSim.new(setup, _run.content)
	var shields: Array[LogEntry] = K.entries(fight, LogEntry.Kind.SHIELD)
	assert_eq(shields.size(), 3, "every hero, as the fight starts")
	for entry: LogEntry in shields:
		var hero: UnitState = fight.unit_by_id(entry.target)
		assert_eq([entry.tick, entry.source_ability, entry.amount], [0, "tithe_of_iron", FixedMath.apply_bp(hero.max_hp, 800)])
	assert_eq(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.status == "root").size(), 2, "the two enemies nearest")


func test_ember_bauble_and_smoke_pouch() -> void:
	var fight: CombatSim = CombatSim.new(_setup_holding(["ember_bauble", "smoke_pouch"]), _run.content)
	for enemy: UnitState in fight.enemies:
		assert_eq(Statuses.find(enemy, "burn").total_stacks(), 3, enemy.id)
	for hero: UnitState in fight.heroes:
		assert_eq(Statuses.find(hero, "stealth").ends_at, 20, "hidden for 1s: " + hero.id)


func test_reliquary_doubles_the_commons() -> void:
	var flow: RunFlow = _start()
	var atk: int = flow.kit_of("maren").stats.get_stat(UnitStats.Stat.ATK)
	var crit: int = flow.kit_of("maren").stats.get_stat(UnitStats.Stat.CRIT)
	_hold(flow, ["bloodstone", "bone_dice", "gravediggers_coin", "brand_of_guilt", "keen_edge", "reliquary"])
	var kit: UnitDef = flow.kit_of("maren")
	assert_eq(kit.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(atk, 11600), "+8% twice")
	assert_eq(kit.stats.get_stat(UnitStats.Stat.CRIT), crit + 12, "+6 twice")
	assert_eq(_run.relic_sum(flow.state, "pay_add"), 6, "a run rule's number, doubled")
	assert_eq(kit.passives.filter(func(part: PartDef) -> bool: return part.id == "brand_of_guilt").size(), 1, "an ability is unchanged")
	var keen: PartDef = kit.passives.filter(func(part: PartDef) -> bool: return part.id == "keen_edge")[0]
	assert_eq(keen.aura.value, 3000, "a rare is unchanged")
	_hold(flow, ["tithe_of_iron", "salt_circle"])
	_to_fight(flow)
	var setup: FightSetup = flow.fight_setup(Bot.formation(), [] as Array[String])
	assert_eq([setup.relic_scales, setup.salt_circles], [[2 * FixedMath.BP_ONE] as Array[int], 2], "a start effect twice as strong, two areas broken")


func test_lifesteal_relics() -> void:
	for id: String in ["leech_tooth", "gluttons_chalice"]:
		var fight: CombatSim = _duel(id, {"effects": [{"type": "damage", "amount": 100, "target": "target"}]})
		fight.units[0].hp = 500
		K.step(fight, 1)
		var stolen: Array = K.entries(fight, LogEntry.Kind.LIFESTEAL).map(func(entry: LogEntry) -> int: return entry.amount)
		assert_eq(stolen, [1 if id == "leech_tooth" else 5], id)
	var thirst: CombatSim = _duel("red_thirst", {"effects": [{"type": "damage", "amount": 100, "target": "target"}]}, 1000)
	thirst.units[0].hp = 500
	K.step(thirst, 6)
	var amounts: Array = K.entries(thirst, LogEntry.Kind.LIFESTEAL).map(func(entry: LogEntry) -> int: return entry.amount)
	assert_eq(amounts, [2], "only once the dummy is below half HP")


func test_crit_relics() -> void:
	var keen: CombatSim = _duel("keen_edge", {"crit_chance_bp": 10000})
	K.step(keen, 1)
	assert_eq(_hits(keen), [18], "x1.5 +30%")
	var mark: CombatSim = _duel("executioners_mark", {}, 100)
	Statuses.apply(mark, mark.units[1], "marked", 0, 200, EffectSource.make("hero", "x", "X"))
	K.step(mark, 8)
	var crits: Array = K.entries(mark, LogEntry.Kind.DAMAGE, "hero").map(func(entry: LogEntry) -> bool: return entry.crit)
	assert_eq(crits.slice(0, 2), [false, false], "not yet near death")
	assert_true(crits.slice(crits.size() - 1).all(func(crit: bool) -> bool: return crit), "below 30% HP and Marked: a sure crit")


func test_hunters_ledger_and_thicket_engine() -> void:
	var ledger: CombatSim = _duel("hunters_ledger", {"crit_chance_bp": 10000})
	Statuses.apply(ledger, ledger.units[1], "marked", 0, 60, EffectSource.make("hero", "x", "X"))
	K.step(ledger, 2)
	assert_eq(K.entries(ledger, LogEntry.Kind.STATUS_EXTENDED).size(), 2, "each crit on the Marked enemy")
	assert_eq(Statuses.find(ledger.units[1], "marked").ends_at, 60 + 2 * 20)
	var thicket: CombatSim = _duel("thicket_engine")
	Statuses.apply(thicket, thicket.units[1], "root", 0, 200, EffectSource.make("hero", "x", "X"))
	K.step(thicket, 8)
	assert_eq(_hits(thicket)[0], 13, "+30% on the Rooted")
	assert_eq(K.entries(thicket, LogEntry.Kind.STATUS_EXTENDED).size(), 2, "every 4th hit")
	assert_eq(Statuses.find(thicket.units[1], "root").ends_at, 200 + 2 * 2, "0.1s each")


func test_veil_of_the_lost_on_marens_stealth() -> void:
	var flow: RunFlow = _start()
	var before: UnitDef = flow.kit_of("maren")
	_hold(flow, ["veil_of_the_lost"])
	var after: UnitDef = flow.kit_of("maren")
	var stealth: Callable = func(kit: UnitDef) -> int:
		for part: PartDef in kit.passives:
			if part.ability != null:
				for effect: EffectDef in part.ability.effects:
					if effect.type == EffectDef.Type.APPLY_STATUS and effect.status_id == "stealth":
						return effect.duration_ticks if effect.duration_ticks > 0 else _run.content.statuses["stealth"].duration_ticks
		return -1
	assert_eq(stealth.call(after), stealth.call(before) + 20, "1s longer")
	var veil: PartDef = after.passives.filter(func(part: PartDef) -> bool: return part.id == "veil_of_the_lost")[0]
	assert_eq([veil.ability.effects[0].trigger, veil.ability.effects[0].status_id], [EffectDef.Trigger.ON_STATUS_ENDED, "veiled_haste"])


func test_overkill_tithe_pays_for_overkill() -> void:
	var flow: RunFlow = _start()
	_hold(flow, ["overkill_tithe"])
	_to_fight(flow)
	var setup: FightSetup = flow.fight_setup(Bot.formation(), [] as Array[String])
	assert_true(setup.heroes[0].tally_keys.has("relic:overkill_tithe"))
	var result: FightResult = _won()
	result.tallies.append(FightResult.Deed.make("maren", "relic:overkill_tithe", 200))
	result.tallies.append(FightResult.Deed.make("vell", "relic:overkill_tithe", 120))
	var before: int = flow.state.shards
	flow.record(Bot.formation(), result)
	assert_eq(flow.state.shards - before, _run.acts[0].pay[_run.content.encounters[flow.state.chosen].tier] + 2, "320 overkill: 2 shards")


# --- step 5c: the engines ------------------------------------------------------------

func _passive_ids(kit: UnitDef) -> Array:
	return kit.passives.map(func(part: PartDef) -> String: return part.id)


func test_the_engines_on_every_heros_kit() -> void:
	var flow: RunFlow = _start()
	var atk: int = flow.kit_of("maren").stats.get_stat(UnitStats.Stat.ATK)
	_hold(flow, ["ashen_engine", "overflow_chalice", "blood_communion", "sanguine_frenzy", "knifes_edge", "stonebound", "wardens_engine", "shadow_engine", "quickening"])
	var kit: UnitDef = flow.kit_of("maren")
	assert_eq(kit.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(atk, 12000), "Ashen Engine: +20% ATK")
	for id: String in ["ashen_engine", "overflow_chalice", "blood_communion", "blood_communion_given", "blood_communion_taken", "sanguine_frenzy", "knifes_edge",
			"stonebound", "stonebound_mgk", "stonebound_def", "wardens_engine", "wardens_engine_atk", "wardens_engine_mgk", "shadow_engine", "shadow_engine_leech",
			"shadow_engine_strike", "quickening"]:
		assert_true(_passive_ids(kit).has(id), id)


func test_knifes_edge_and_quickening_in_a_fight() -> void:
	var edge: CombatSim = _duel("knifes_edge", {}, 100000, {"crit": 130})
	K.step(edge, 1)
	assert_eq(_hits(edge), [21], "x1.5, +2 x 30% past 100%")
	var quick: CombatSim = _duel("quickening")
	var atsp: int = quick.units[0].stats.get_stat(UnitStats.Stat.ATSP)
	K.step(quick, 5)
	assert_eq(quick.units[0].stats.get_stat(UnitStats.Stat.ATSP), atsp + 5, "+1 a hit")


func test_blood_communion_and_sanguine_frenzy() -> void:
	var flow: RunFlow = _start()
	_hold(flow, ["gluttons_chalice", "blood_communion", "sanguine_frenzy"])
	var kit: UnitDef = flow.kit_of("maren")
	var setup: FightSetup = K.fight([K.at(kit, 3, 2)] as Array[UnitSetup], [K.foe(K.kit("dummy", {"stats": {"hp": 100000, "speed": 0, "range": 2},
		"basic_attack": {"cooldown_ms": 60000, "shot": false, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}), 3, 4)] as Array[UnitSetup])
	var fight: CombatSim = CombatSim.new(setup, _run.content)
	fight.units[0].hp = 100
	K.step(fight, 60)
	var heals: Array[LogEntry] = K.entries(fight, LogEntry.Kind.HEAL).filter(func(entry: LogEntry) -> bool: return entry.lifesteal)
	assert_false(heals.is_empty(), "lifesteal heals")
	assert_true(heals.all(func(entry: LogEntry) -> bool: return entry.amount > 0), "never a heal of nothing")
	assert_true(K.entries(fight, LogEntry.Kind.STATUS_APPLIED).any(func(entry: LogEntry) -> bool: return entry.status == "frenzy"), "and each heal frenzies")


func test_hunters_engine_makes_marks_stack() -> void:
	var setup: FightSetup = _setup_holding(["hunters_engine"])
	assert_true(setup.hero_rules.marks_stack)
	assert_false(_setup_holding(["keen_edge"]).hero_rules.marks_stack, "only with it")
	assert_true(ModInfo.relic_numbers(_run.relics["hunters_engine"], _run.content).contains("Marks heroes apply stack"))


func test_snaring_shot_is_for_ranged_heroes_only() -> void:
	var flow: RunFlow = _start()
	_hold(flow, ["snaring_shot"])
	assert_true(_passive_ids(flow.kit_of("maren")).has("snaring_shot"), "Maren shoots from range")
	assert_true(_passive_ids(flow.kit_of("vell")).has("snaring_shot"), "so does Vell")
	assert_false(_passive_ids(flow.kit_of("brannoc")).has("snaring_shot"), "Brannoc is melee")
	assert_true(ModInfo.relic_numbers(_run.relics["snaring_shot"], _run.content).begins_with("Ranged heroes: "))



# --- step 5c-2: the hero rules ---------------------------------------------------------

func test_rule_relics_go_into_the_setup() -> void:
	var rules: SideRules = _setup_holding(["crown_of_stars", "second_dawn", "everflame", "the_long_watch"]).hero_rules
	assert_eq([rules.crit_steps, rules.rise_ticks, rules.keywords_last, rules.watch_tie_ticks], [10, 100, true, 6000])
	assert_false(rules.keywords_twice, "only what's held")
	for id: String in ["crown_of_stars", "shared_pain", "the_hungering_rift", "overcharge", "second_dawn", "chain_of_echoes", "crown_of_the_hollow_king",
			"everflame", "the_unbending", "riftwalkers_soles", "the_long_watch"]:
		assert_false(ModInfo.rules_numbers(_run.relics[id].rules, _run.content).is_empty(), "%s says its rule" % id)
	assert_string_contains(ModInfo.relic_numbers(_run.relics["the_long_watch"], _run.content), "+10% max HP, +10% ATK")


func test_a_hero_who_rose_takes_no_wound() -> void:
	var flow: RunFlow = _start()
	_to_fight(flow)
	var result: FightResult = _won(["maren", "vell"])
	var rise := LogEntry.new()
	rise.kind = LogEntry.Kind.RISE
	rise.target = "maren"
	result.combat_log.add(rise)
	flow.record(Bot.formation(), result)
	assert_eq([flow.state.hero("maren").wounds, flow.state.hero("vell").wounds], [0, 1], "wounds only for heroes down at the end (Decision 23)")


# --- step 5d: bond relics --------------------------------------------------------------

## A run with Sentry and Sniper on: Brannoc transformed into Hearthwall, Maren
## into Deadeye.
func _bonded() -> RunFlow:
	var flow: RunFlow = _start()
	for pair: Array in [["brannoc", "hearthwall"], ["maren", "deadeye"]]:
		var hero: RunState.Hero = flow.state.hero(pair[0])
		hero.path = pair[1]
		hero.transformed = true
	return flow


func _bond_draws(flow: RunFlow, magpie: bool = false, boss: bool = false) -> int:
	var found: int = 0
	for rerolls: int in 400:
		var drawn: Array[String] = Offers.shop_relics(_run, flow.state, rerolls, 2 if boss else 1, magpie, boss)
		if drawn.has("the_watchtower_stone"):
			found += 1
			if boss:
				assert_eq(drawn.find("the_watchtower_stone"), 1, "beside the boss shop's legendary, never in its place")
	return found


func test_an_on_bonds_relic_shows_up_in_the_shops() -> void:
	var flow: RunFlow = _bonded()
	assert_eq(_run.bond_relics(flow.state), ["the_watchtower_stone"] as Array[String])
	var shown: int = _bond_draws(flow)
	assert_between(shown, 50, 110, "about 20%% of the Pedlar's draws (Decision 27): %d of 400" % shown)
	assert_eq(_bond_draws(flow, true), 0, "never at the Magpie")
	assert_gt(_bond_draws(flow, false, true), 0, "in the boss shop too")
	assert_eq(_bond_draws(_start()), 0, "no bond on, no bond relic")


func test_a_bond_relic_is_free_and_found_once() -> void:
	var flow: RunFlow = _bonded()
	var state: RunState = flow.state
	_hold(flow, ["hagglers_charm"])
	state.shards = 0
	R.to_pedlar(flow)
	state.shop_relics.assign(["the_watchtower_stone"])
	assert_eq(flow.relic_price(0), 0, "free, whatever the prices")
	assert_eq(flow.buy_relic(0), "")
	assert_true(state.relics.has("the_watchtower_stone"))
	assert_eq(_run.bond_relics(state), [] as Array[String], "held: drawn no more")
	assert_eq(_bond_draws(flow), 0)


func test_two_bonds_both_join() -> void:
	var flow: RunFlow = _bonded()
	var vell: RunState.Hero = flow.state.hero("vell")
	vell.path = "wardweaver"
	vell.transformed = true
	assert_eq(_run.bond_relics(flow.state), ["the_watchtower_stone", "the_hearth_woven_mail"] as Array[String], "Decision 28")
	var both: Dictionary = {}
	for rerolls: int in 400:
		for id: String in Offers.shop_relics(_run, flow.state, rerolls, 1, false, false):
			if _run.relics[id].tier == RelicDef.Tier.BOND:
				both[id] = true
	assert_eq(both.size(), 2, "either can show up")
