extends GutTest
## Ottilie's upgrade cards (phase 8 part 6, docs/plans/design/upgrade-pools.md
## Ottilie; rebuild-phase8-last-heroes.md 8f-2) on her real kits: each
## changes the kit it's offered on, cards on Volatile Flask reach it as her
## signature and as her habit, the knobs her cards added (Reaction's count
## and cap, Reaction Flask's per stack, the shard cap, effects before a
## vial's mana), the elites-and-bosses condition, and the bond relics built
## with her: Plague Alchemy and The Tonic Choir.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["ottilie"].kit


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
		if card.hero == "ottilie" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "ottilie"):
			if card.layer == UpgradeDef.Layer.APEX:
				continue
			cards.append(id)
			var kit: UnitDef = _base()
			if not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15, "12 of her own, 2 tastes and 5 path cards a path")


func test_flask_cards_reach_the_signature_and_the_habit() -> void:
	assert_eq(_with("wide_flask", _base()).signature.effects[0].shape.size, 2)
	assert_eq(_passive(_with("wide_flask", _kit("apothecary", PathDef.Stage.TRANSFORMED)), "volatile_flask").ability.effects[0].shape.size, 2, "the habit too")
	assert_eq(_with("quick_flask", _base()).mana.max, 50)
	var brew: Array[EffectDef] = _passive(_with("quick_brew", _base()), "brewing").ability.effects
	assert_eq([brew[0].interval_ticks, brew[0].first_ticks], [120, 60], "a vial every 3s, not 4s")
	assert_false(_run.changes_something(_run.upgrades["quick_brew"], true, _kit("catalyst", PathDef.Stage.TRANSFORMED)), "nothing to quicken once Brewing stops")


func test_her_own_cards() -> void:
	var sticky: Array[EffectDef] = _passive(_with("sticky_vials", _base()), "brewing").ability.effects
	assert_eq(sticky.filter(func(effect: EffectDef) -> bool: return effect.status_id == "sticky").map(func(effect: EffectDef) -> String: return effect.spends),
		["fire_vial", "venom_vial"], "each vial Slows as it lands")
	assert_eq(_with("long_toss", _base()).stats.get_stat(UnitStats.Stat.RANGE), 4)
	assert_not_null(_passive(_with("acrid_fumes", _base()), "acrid_fumes"))


func test_catalyst_cards() -> void:
	var sharp: AuraDef = _passive(_with("sharp_reaction", _kit("catalyst", PathDef.Stage.VOWED)), "reaction").aura
	assert_eq([sharp.per_stacks, sharp.cap_bp], [4, 1200], "every 4, up to +12%")
	var kit: UnitDef = _kit("catalyst", PathDef.Stage.TRANSFORMED)
	assert_eq(_passive(_with("sharp_reaction", kit, true), "reaction_both").aura.value, 13000, "once transformed: +30% against both")
	assert_eq(_passive(_with("strong_reaction", kit), "reaction_both").aura.value, 13500, "+35%")
	var flask: EffectDef = _with("heavy_flask", kit).signature.effects[0].area_effects[0]
	assert_eq(flask.amount_per_stack, 4, "4 a stack, not 3")
	assert_eq(_with("quick_reaction", kit).mana.max, 50)


func test_transmuter_cards() -> void:
	var kit: UnitDef = _kit("transmuter", PathDef.Stage.TRANSFORMED)
	assert_eq(_with("deep_purse", kit).shard_cap, 10, "up to 10 a fight")
	assert_eq(_run.upgrades["appraise"].transmute.pays(14, 2), 16)
	var assay: EffectDef = _passive(_with("assayer", _kit("transmuter", PathDef.Stage.VOWED)), "assayer").ability.effects[0]
	assert_eq(assay.vs.ranks, ["elite", "boss"] as Array[String])
	var ledger: UpgradeDef = _run.upgrades["transmuter_ledger"]
	assert_eq([ledger.tithe.per_step, ledger.grows.per, ledger.grows.max_steps], [1, 30, 5])


func test_apothecary_cards() -> void:
	var kit: UnitDef = _kit("apothecary", PathDef.Stage.TRANSFORMED)
	var effects: Array[EffectDef] = _passive(_with("bracing_vial", kit), "tonic").ability.effects
	var bracing: int = effects.find_custom(func(effect: EffectDef) -> bool: return effect.status_id == "bracing")
	var mana: int = effects.find_custom(func(effect: EffectDef) -> bool: return effect.type == EffectDef.Type.GAIN_MANA)
	assert_true(bracing >= 0 and bracing < mana, "added before the mana, so it reaches the same ally")
	assert_eq(_with("long_elixir", kit).signature.effects[1].duration_ticks, 160, "8s")


func test_ranks_hold_only_for_elites_and_bosses() -> void:
	var errors: Array[String] = []
	var ranked: UnitCondition = UnitCondition.read(DataReader.new({"ranks": ["elite", "boss"]}, "condition", errors))
	assert_eq(errors, [] as Array[String])
	var fight: CombatSim = K.sim(K.fight([K.at(K.kit("hero"), 0, 0)] as Array[UnitSetup], [K.foe(_content.enemies["rift_hound"].kit, 3, 4)] as Array[UnitSetup]))
	assert_false(ranked.holds(fight.enemies[0]), "a Rift Hound is neither")
	var elite: String = ""
	for id: String in _content.enemy_ids:
		if _content.enemies[id].rank == "elite":
			elite = id
			break
	var boss: UnitState = fight.enemies[0]
	boss.def = _content.enemies[elite].kit
	assert_true(ranked.holds(boss), elite)


func test_her_bond_relics() -> void:
	for pair: Array in [["putrefaction", "plague_alchemy", ["catalyst", "plaguebearer"]], ["tonic_and_hymn", "the_tonic_choir", ["apothecary", "chorister"]]]:
		var bond: BondDef = _run.bonds[pair[0]]
		assert_eq([bond.relic, bond.paths, _run.relics[pair[1]].tier], [pair[1], pair[2] as Array[String], RelicDef.Tier.BOND], pair[0])
	var problems: Array[String] = []
	var alchemy: RelicDef = _run.relics["plague_alchemy"]
	assert_true(alchemy.mod_fits(_content.paths["plaguebearer"].transformed_kit), "Severine's")
	var burst: UnitDef = alchemy.mod.apply(_content.paths["plaguebearer"].transformed_kit, problems)
	assert_eq(burst.signature.effects[0].area_effects.back().status_id, "burn", "Plague Burst sets Burn too")
	var choir: RelicDef = _run.relics["the_tonic_choir"]
	assert_true(choir.mod_fits(_content.paths["apothecary"].transformed_kit), "Ottilie's")
	var tonic: UnitDef = choir.mod.apply(_content.paths["apothecary"].transformed_kit, problems)
	assert_true(_passive(tonic, "tonic").ability.effects.any(func(effect: EffectDef) -> bool: return effect.only != null and effect.only.kits == (["aldous"] as Array[String])),
		"her vials give Aldous mana too")
	assert_not_null(_passive(tonic, "the_tonic_choir"))
	assert_eq(problems, [] as Array[String])


func test_the_tonic_choir_fills_her_next_tosses() -> void:
	var errors: Array[String] = []
	var team: Array[String] = ["aldous", "brannoc", "ottilie"]
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var extras: Dictionary[String, HeroExtras] = {"ottilie": HeroExtras.new()}
	extras["ottilie"].mods.append(_run.relics["the_tonic_choir"].mod)
	var setup: FightSetup = Encounters.setup(_content, "cairn_road", formation, 1, errors, {},
		{"ottilie": "apothecary", "aldous": "chorister", "brannoc": "hearthwall"} as Dictionary[String, String], ["ottilie", "aldous"] as Array[String], extras)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	var choir: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.MANA_GIVEN).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "the_tonic_choir")
	assert_gt(choir.size(), 0, "Crescendo filled her next Tosses with vials")
	assert_true(sim.combat_log.of_kind(LogEntry.Kind.MANA_GIVEN).any(func(entry: LogEntry) -> bool: return entry.source_ability == "tonic" and entry.target == "aldous"),
		"and her vials give Aldous mana")
