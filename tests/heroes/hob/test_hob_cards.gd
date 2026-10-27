extends GutTest
## Hob's upgrade cards and bond relics (phase 8 part 6, docs/plans/
## upgrade-pools.md Hob, duo-bonds.md; rebuild-phase8-last-heroes.md 8f-5)
## on his real kits: each changes the kit it's offered on, cards on Grab
## reach it as his signature and as his habit, the knobs they added (Nest
## Egg's step and cap, Pickings' reach, a leap's hexes), and The Contract and
## The Counting House in fights.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["hob"].kit


func _kit(path_id: String, stage: PathDef.Stage) -> UnitDef:
	return _content.paths[path_id].kit(stage, _base())


func _with(card_id: String, kit: UnitDef, transformed: bool = false) -> UnitDef:
	var problems: Array[String] = []
	var built: UnitDef = _run.upgrades[card_id].mod_for(transformed).apply(kit, problems)
	assert_eq(problems, [] as Array[String], card_id)
	return built


func _passive(kit: UnitDef, part_id: String) -> PartDef:
	for part: PartDef in kit.passives:
		if part.id == part_id:
			return part
	return null


func _effect(kit: UnitDef, part_id: String, index: int = 0) -> EffectDef:
	return _passive(kit, part_id).ability.effects[index]


func test_every_card_changes_the_kit_it_is_offered_on() -> void:
	var cards: Array[String] = []
	for id: String in _run.upgrade_ids:
		var card: UpgradeDef = _run.upgrades[id]
		if card.hero == "hob" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "hob"):
			if card.layer == UpgradeDef.Layer.APEX:
				continue
			cards.append(id)
			var kit: UnitDef = _base()
			if not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15, "12 of his own, 2 tastes and 5 path cards a path")


func test_grab_cards_reach_the_signature_and_the_habit() -> void:
	var base: UnitDef = _base()
	var long: UnitDef = _with("long_grab", base)
	assert_eq([long.signature.max_range, long.signature.effects[0].hexes], [4, 4], "Grab reaches 4 hexes, and darts 4")
	var habit: EffectDef = _effect(_with("long_grab", _kit("fence", PathDef.Stage.TRANSFORMED)), "grab")
	assert_eq(habit.hexes, 4, "the habit's dart too")
	assert_eq(_with("hard_grab", base).signature.effects[1].power_bp, 3333, "150% to 200% of his ATK")
	assert_eq(_effect(_with("hard_grab", _kit("hoarder", PathDef.Stage.TRANSFORMED)), "grab", 1).power_bp, 3333)
	assert_eq(_with("slippery_exit", base).signature.effects.back().status_id, "slippery_exit")
	var nose: UnitDef = _with("scavengers_nose", base)
	assert_eq([nose.signature.max_range, nose.signature.effects[0].hexes], [5, 5], "within 5 hexes")
	assert_eq(nose.signature.prefer.below_hp_bp, 3000, "below 30% first")


func test_his_own_cards() -> void:
	var base: UnitDef = _base()
	assert_eq(_effect(_with("wider_pickings", base), "pickings").fell_range, 3 * HexGrid.HEX, "Pickings counts 3 hexes out")
	var sand: EffectDef = _effect(_with("pocket_sand", base), "pocket_sand")
	assert_eq([sand.trigger, sand.status_id, sand.duration_ticks], [EffectDef.Trigger.ON_HOLDER_CRIT, "hobbled", 20])
	assert_eq(_run.upgrades["lucky_find"].tithe.once_per_act, 5)
	var sling: GrowthDef = _run.upgrades["well_worn_sling"].grows
	assert_eq([sling.counts.counts, sling.per], [DeedDef.Counts.SHARDS, 20])
	assert_eq(sling.each.times(3).stats_bp[UnitStats.Stat.ATK], 10300)


func test_nest_egg_cards_move_its_step_and_cap() -> void:
	var vowed: UnitDef = _kit("hoarder", PathDef.Stage.VOWED)
	var deep: UnitDef = _with("deep_pockets", vowed)
	assert_eq([_passive(deep, "nest_egg").aura.per_shards_max, _passive(deep, "nest_egg_guard").aura.per_shards_max], [15, 15], "up to +15%")
	var wise: UnitDef = _with("penny_wise", vowed)
	assert_eq([_passive(wise, "nest_egg").aura.per_shards, _passive(wise, "nest_egg_guard").aura.per_shards], [8, 8], "every 8 shards")
	var transformed: UnitDef = _kit("hoarder", PathDef.Stage.TRANSFORMED)
	var later: UnitDef = _with("penny_wise", transformed, true)
	for part_id: String in ["nest_egg", "nest_egg_guard", "nest_egg_shared", "nest_egg_shared_guard"]:
		assert_eq(_passive(later, part_id).aura.per_shards, 4, part_id + ": every 4, once transformed")
	assert_false(KitMod.read(DataReader.new({"on": [{"slot": "passive:nest_egg", "per_shards_max_add": 5}]}, "m", [] as Array[String])).affects(transformed),
		"no cap once transformed: the knob changes nothing")
	assert_eq(_passive(_with("deep_pockets", transformed, true), "nest_egg").aura.value, 10120, "a bigger step instead")
	assert_eq(_passive(_with("shared_wealth", transformed), "nest_egg_shared").aura.value, 10075, "3/4, not half")
	assert_eq(_passive(_with("guarded_gold", transformed), "guarded_gold").aura.per_shards, 30)


func test_the_bounty_cards() -> void:
	var vowed: UnitDef = _kit("bounty_hunter", PathDef.Stage.VOWED)
	assert_eq(_effect(_with("wanted_poster", vowed), "bounty").duration_ticks, 12 * 20, "12s, not 8s")
	var transformed: UnitDef = _kit("bounty_hunter", PathDef.Stage.TRANSFORMED)
	assert_eq(_effect(_with("wanted_poster", transformed, true), "bounty").strength_add_bp, 3000, "a stronger Mark once transformed")
	assert_eq(_with("long_arm", transformed).signature.max_range, 6)
	assert_eq(_with("fast_collect", transformed).mana.max, 40)
	var tracker: AuraDef = _passive(_with("tracker", transformed), "tracker").aura
	assert_eq([tracker.target, tracker.value], [AuraDef.Target.ALL_ALLIES, 11000])
	var seasoned: GrowthDef = _run.upgrades["seasoned_hunter"].grows
	assert_eq([seasoned.counts.counts, seasoned.counts.by_allies, seasoned.per], [DeedDef.Counts.KILLS, true, 3])


## A fight of `team` on `vows`, all transformed, holding `relics`.
func _fight(team: Array[String], vows: Dictionary[String, String], relics: Array[String], shards: int = 0, tithe_shards: int = 0) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var extras: Dictionary[String, HeroExtras] = {}
	for hero_id: String in team:
		var extra := HeroExtras.new()
		for id: String in relics:
			if _run.relics[id].mod != null and _run.relics[id].mod_fits(_content.paths[vows[hero_id]].transformed_kit):
				extra.mods.append(_run.relics[id].mod)
		extras[hero_id] = extra
	var stages: Array[String] = team.duplicate()
	var setup: FightSetup = Encounters.setup(_content, "cairn_road", formation, 1, errors, {}, vows, stages, extras)
	assert_eq(errors, [] as Array[String])
	setup.shards = shards
	setup.tithe_shards = tithe_shards
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func test_the_contract_sends_tamsin_to_the_next_bounty() -> void:
	var team: Array[String] = ["brannoc", "tamsin", "hob"]
	var vows: Dictionary[String, String] = {"brannoc": "hearthwall", "tamsin": "headhunter", "hob": "bounty_hunter"}
	var sim: CombatSim = _fight(team, vows, ["the_contract"] as Array[String])
	var steps: Array[LogEntry] = sim.combat_log.entries.filter(func(entry: LogEntry) -> bool: return entry.source_unit == "tamsin" and entry.source_ability == "contract_step")
	assert_gt(steps.size(), 0, "she steps when a Bounty dies")
	assert_true(steps.any(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.STATUS_APPLIED and entry.status == "parting_shot"), "her next attack crits")
	var paid: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.SHARDS).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "tamsin")
	for entry: LogEntry in paid:
		assert_eq([entry.source_ability, entry.amount], ["the_contract", 3], "a Bounty she kills pays again")
	var plain: CombatSim = _fight(team, vows, [] as Array[String])
	assert_eq(plain.combat_log.of_kind(LogEntry.Kind.SHARDS).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "tamsin").size(), 0)


func test_the_counting_house_counts_the_tithe_twice() -> void:
	var team: Array[String] = ["brannoc", "edric", "hob"]
	var vows: Dictionary[String, String] = {"brannoc": "hearthwall", "edric": "tithe_collector", "hob": "hoarder"}
	var sim: CombatSim = _fight(team, vows, ["the_counting_house"] as Array[String], 50, 20)
	var stones: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "hob" and entry.source_ability == "sling_stone")
	assert_eq(stones[0].rule_power, 1000 + 400, "+1% for every 5 held, and again for every 5 of the Tithe's")
	var none: CombatSim = _fight(team, vows, ["the_counting_house"] as Array[String], 50, 0)
	assert_eq(none.combat_log.of_kind(LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "hob" and entry.source_ability == "sling_stone")[0].rule_power, 1000)
	var wards: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.SHIELD).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "edric")
	assert_gt(wards.size(), 0)
	assert_eq(wards[0].rule_power, 1000, "Edric's Shields +1% for every 5 shards held")
