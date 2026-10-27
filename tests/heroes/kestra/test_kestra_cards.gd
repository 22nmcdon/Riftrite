extends GutTest
## Kestra's upgrade cards (phase 8 part 6, docs/plans/upgrade-pools.md
## Kestra; rebuild-phase8-last-heroes.md 8f-3) on her real kits: each changes
## the kit it's offered on, cards on Sic 'Em reach it as her signature and as
## her habit, cards on her companions reach their kits, and the bond relics
## built with her: The Gilded Hound and Mother of Serpents.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["kestra"].kit


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


func test_every_card_changes_the_kit_it_is_offered_on() -> void:
	var cards: Array[String] = []
	for id: String in _run.upgrade_ids:
		var card: UpgradeDef = _run.upgrades[id]
		if card.hero == "kestra" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "kestra"):
			if card.layer == UpgradeDef.Layer.APEX:
				continue
			cards.append(id)
			var kit: UnitDef = _base()
			if not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15, "12 of her own, 2 tastes and 5 path cards a path")


func test_sic_em_cards_reach_the_signature_and_the_habit() -> void:
	assert_eq(_with("hard_bite", _base()).signature.effects[1].power_bp, 2500, "250% of his ATK, not 200%")
	var habit: PartDef = _passive(_with("hard_bite", _kit("packleader", PathDef.Stage.TRANSFORMED)), "sic_em")
	assert_eq(habit.ability.effects.back().power_bp, 2500, "the habit too")
	assert_eq(_with("quick_sic", _base()).mana.max, 40)
	assert_false(_run.changes_something(_run.upgrades["big_grit"], false, _kit("serpent_keeper", PathDef.Stage.TRANSFORMED)), "no Grit once the viper takes his place")


func test_her_own_cards_reach_grit() -> void:
	var grit: CompanionDef = _with("big_grit", _base()).companion("grit")
	assert_eq(grit.hp_bp, 5500)
	assert_eq(_with("fierce_grit", _base()).companion("grit").atk_bp, 7500)
	assert_eq(_with("quick_return", _base()).companion("grit").return_ticks, 6 * 20)
	var bond: UnitDef = _with("strong_bond", _base())
	assert_eq(_passive(bond, "bond").aura.value, 15)
	assert_eq(_passive(bond.companion("grit").kit, "bond").aura.value, 15, "his Bond too")
	var guard: UnitDef = _with("guard_dog", _base()).companion("grit").kit
	assert_true(guard.prefer != null and guard.prefer.targets_owner, "Grit goes after enemies attacking her")
	assert_eq(_run.upgrades["old_leash"].grows.each.companion_changes[0].atk_add_bp, 100)


func test_cinderhound_cards() -> void:
	var vowed: UnitDef = _kit("cinderhound", PathDef.Stage.VOWED)
	assert_eq(_with("hot_fangs", vowed).companion("grit").kit.basic_attack.effects[1].scaling[UnitStats.Stat.ATK], 2500, "Smoldering Fangs' Burn: 25% of her ATK")
	assert_not_null(_passive(_with("ashen_coat", vowed).companion("grit").kit, "ashen_coat"))
	var kit: UnitDef = _kit("cinderhound", PathDef.Stage.TRANSFORMED)
	assert_eq(_with("long_pounce", kit).signature.effects[1].shape.size, 2)
	assert_eq(_with("quick_pounce", kit).mana.max, 40)
	assert_not_null(_passive(_with("searing_bite", kit).companion("grit").kit, "searing_bite"))
	assert_eq(_passive(_with("fire_retort", kit).companion("grit").kit, "ember_coat").ability.effects[0].scaling[UnitStats.Stat.ATK], 1500, "15% of her ATK")


func test_serpent_keeper_cards() -> void:
	var vowed: UnitDef = _kit("serpent_keeper", PathDef.Stage.VOWED)
	assert_eq(_with("sharp_jab", vowed).basic_attack.effects[1].every, 2, "every 2nd jab")
	assert_eq(_with("thick_venom", vowed).basic_attack.effects[1].scaling[UnitStats.Stat.ATK], 2000, "20% of her ATK")
	var kit: UnitDef = _kit("serpent_keeper", PathDef.Stage.TRANSFORMED)
	assert_eq(_with("long_nest", kit).signature.effects[0].lasts_ticks, 9 * 20, "nestlings last 9s")
	assert_eq(_with("long_spit", kit).companion("viper").kit.stats.get_stat(UnitStats.Stat.RANGE), 4)
	assert_not_null(_passive(_with("numbing_venom", kit), "numbing_venom"))


func test_packleader_cards() -> void:
	assert_eq(_passive(_with("strong_call", _kit("packleader", PathDef.Stage.VOWED)).companion("grit").kit, "pack_call").aura.value, 10400)
	var kit: UnitDef = _kit("packleader", PathDef.Stage.TRANSFORMED)
	assert_eq(_passive(_with("strong_call", kit, true), "pack_call").aura.value, 10400, "once transformed: hers, for every summon")
	assert_eq(_with("loyal_hound", kit, true).companion("brindle").return_ticks, 5 * 20, "both hounds")
	assert_eq(_with("lasting_howl", kit).signature.effects[0].duration_ticks, 7 * 20)
	assert_eq(_with("quick_howl", kit).mana.max, 35)
	assert_eq(_passive(_with("pack_tactics", kit), "pack_tactics").aura.vs.chased_by_summons, 2)
	assert_not_null(_passive(_with("thick_hides", kit), "thick_hides"))


func test_her_bond_relics() -> void:
	for pair: Array in [["gilded_ash", "the_gilded_hound", ["transmuter", "cinderhound"]], ["nest_of_rot", "mother_of_serpents", ["plaguebearer", "serpent_keeper"]]]:
		var bond: BondDef = _run.bonds[pair[0]]
		assert_eq([bond.relic, bond.paths, _run.relics[pair[1]].tier], [pair[1], pair[2] as Array[String], RelicDef.Tier.BOND], pair[0])
	var problems: Array[String] = []
	var hound: RelicDef = _run.relics["the_gilded_hound"]
	assert_true(hound.mod_fits(_content.paths["cinderhound"].transformed_kit), "Kestra's")
	var grit: UnitDef = hound.mod.apply(_content.paths["cinderhound"].transformed_kit, problems).companion("grit").kit
	assert_eq(grit.basic_attack.effects.back().status_id, "poison", "his bites Poison a little")
	assert_not_null(_passive(grit, "gilded_fetch"))
	var mother: UnitDef = _run.relics["mother_of_serpents"].mod.apply(_content.paths["serpent_keeper"].transformed_kit, problems)
	assert_eq(mother.companion("viper").kit.basic_attack.effects.back().status_id, "viper_bitten")
	assert_eq(mother.companion("nestling").kit.basic_attack.effects.back().status_id, "viper_bitten")
	assert_not_null(_passive(mother, "mother_of_serpents"))
	assert_eq(problems, [] as Array[String])


func _bond_fight(team: Array[String], vows: Dictionary[String, String], relic_id: String, scale_bp: int = 10000) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var extras: Dictionary[String, HeroExtras] = {"kestra": HeroExtras.new()}
	extras["kestra"].mods.append(_run.relics[relic_id].mod)
	var encounter: EncounterDef = _content.encounters["cairn_road"]
	var keep: int = encounter.scale_bp
	encounter.scale_bp = FixedMath.apply_bp(keep, scale_bp)
	var setup: FightSetup = Encounters.setup(_content, "cairn_road", formation, 1, errors, {}, vows, team, extras)
	encounter.scale_bp = keep
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func test_the_gilded_hound_fetches_shards() -> void:
	var sim: CombatSim = _bond_fight(["brannoc", "ottilie", "kestra"] as Array[String],
		{"kestra": "cinderhound", "ottilie": "transmuter", "brannoc": "hearthwall"} as Dictionary[String, String], "the_gilded_hound")
	assert_gt(sim.combat_log.of_kind(LogEntry.Kind.SHARDS).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "grit").size(), 0, "Grit fetches shards")
	assert_gt(sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "grit" and entry.status == "poison").size(), 0,
		"and Poisons as he bites")


func test_mother_of_serpents_hatches_from_her_plague() -> void:
	var sim: CombatSim = _bond_fight(["brannoc", "severine", "kestra"] as Array[String],
		{"kestra": "serpent_keeper", "severine": "plaguebearer", "brannoc": "hearthwall"} as Dictionary[String, String], "mother_of_serpents", 7500)
	var bitten: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.status == "viper_bitten")
	assert_gt(bitten.size(), 0, "her vipers mark what they bite")
	var hatched: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.SUMMON).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "mother_of_serpents")
	assert_gt(hatched.size(), 0, "a Poisoned enemy Severine fells hatches a nestling")


func test_her_cards_say_their_numbers() -> void:
	var base: UnitDef = _base()
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["big_grit"], base, _content), "Grit: +15% of her max HP")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["quick_return"], base, _content), "Grit: returns 4s sooner")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["hard_bite"], base, _content), "Sic 'Em: +25% damage", "by its name")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["strong_bond"], base, _content), "Bond: +5 ATSP · Grit: Bond: +5 ATSP", "attack speed in points; only the companions she has")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["long_spit"], _kit("serpent_keeper", PathDef.Stage.TRANSFORMED), _content), "Viper: +1 Range")
	assert_string_contains(ModInfo.upgrade_numbers(_run.upgrades["pack_lore"], _kit("packleader", PathDef.Stage.TRANSFORMED), _content),
		"Grows: Her companions: +1% of her ATK per 20 summons brought onto the field")


func test_her_apex_cards() -> void:
	var cards: Array[String] = []
	for id: String in _run.upgrade_ids:
		var card: UpgradeDef = _run.upgrades[id]
		if card.layer == UpgradeDef.Layer.APEX and _content.paths[_content.apexes[card.apex].path].hero == "kestra":
			cards.append(id)
			assert_true(_run.changes_something(card, true, _content.apexes[card.apex].apex_kit), id)
	assert_eq(cards.size(), 12, "2 an apex")
	assert_eq(_passive(_with("ember_mantle", _content.apexes["hellhound"].apex_kit).companion("grit").kit, "hellfire").ability.effects[0].near_range, 2000, "his fire reaches 2 hexes")
	assert_eq(_with("big_brood", _content.apexes["brood_mother"].apex_kit).signature.effects[0].max_standing, 9)
	assert_eq(_with("long_howl", _content.apexes["wild_hunt"].apex_kit).signature.effects[0].duration_ticks, 10 * 20)
	assert_eq(_passive(_with("hunt_scent", _content.apexes["wild_hunt"].apex_kit), "blood_scent").aura.stat, AuraDef.Stat.SPEED)
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["hunt_scent"], _content.apexes["wild_hunt"].apex_kit, _content), "Blood Scent: +1 speed for all allies Howl, a summon", "speed in points")
