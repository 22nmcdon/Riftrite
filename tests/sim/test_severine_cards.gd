extends GutTest
## Severine's upgrade cards (phase 8 part 5, docs/plans/upgrade-pools.md
## Severine; rebuild-phase8-severine-edric.md 8e-2d) on her real kits: each
## changes the kit it's offered on, a card on Drain reaches it as her
## signature or as her habit, and the new knobs (lifesteal_add_bp,
## plus_max_hp_add_bp, hp_cost_add_bp, a zone that follows its caster, the
## condition engorged_pct, the count lifesteal) do what they say; and her 12
## apex cards (8e-2c) on their apexes' kits.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["severine"].kit


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
		if card.hero == "severine" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "severine"):
			cards.append(id)
			var kit: UnitDef = _base()
			if card.layer == UpgradeDef.Layer.APEX:
				kit = _content.apexes[card.apex].apex_kit
			elif not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15 + 12, "12 of her own, 2 tastes and 5 path cards a path, 2 an apex")


func test_drain_cards_reach_the_signature_and_the_habit() -> void:
	assert_eq(_with("hungry_drain", _base()).signature.effects[0].lifesteal_bp, 7500, "75%, not 50%")
	var habit: PartDef = _passive(_with("hungry_drain", _kit("bloodglut", PathDef.Stage.TRANSFORMED)), "drain")
	assert_eq(habit.ability.effects[0].lifesteal_bp, 7500, "and as a habit")
	assert_eq(_with("heavy_drain", _base()).signature.effects[0].power_bp, 2500, "+25%: 250% of her ATK")


func test_lifesteal_and_hp_cost_knobs() -> void:
	assert_eq(_with("deep_bite", _base()).basic_attack.effects[0].lifesteal_bp, 2000, "Rend: 20%, not 15%")
	assert_eq(_with("leeching_bolt", _kit("hemomancer", PathDef.Stage.TRANSFORMED)).basic_attack.effects[0].lifesteal_bp, 3000, "Blood Bolt: 30%")
	assert_eq(_with("thin_blood", _kit("hemomancer", PathDef.Stage.VOWED)).signature.hp_cost_bp, 400, "Blood Price: 4%, not 5%")
	assert_eq(_with("thin_blood", _kit("hemomancer", PathDef.Stage.TRANSFORMED), true).signature.hp_cost_bp, 900, "carried on: Exsanguinate 9%")
	assert_eq(_with("bloodline", _kit("hemomancer", PathDef.Stage.TRANSFORMED)).signature.hp_cost_bp, 800, "8%, not 10%")
	assert_eq(_with("massive", _kit("bloodglut", PathDef.Stage.TRANSFORMED)).signature.effects[0].plus_bp_of_max_hp, 1500, "Gorge: 15% of max HP")
	assert_eq(_passive(_with("massive", _content.apexes["sanguine_nova"].apex_kit), "gorge").ability.effects[0].plus_bp_of_max_hp, 1500, "and as a habit under Sanguine Nova")
	assert_false(_run.changes_something(_run.upgrades["deep_bite"], false, _no_lifesteal()), "no lifesteal to raise: no change")


## A kit whose basic attack has no lifesteal.
func _no_lifesteal() -> UnitDef:
	return K.kit("plain", {})


func test_carrier_makes_plague_burst_follow_her() -> void:
	var zone: EffectDef = _with("carrier", _kit("plaguebearer", PathDef.Stage.TRANSFORMED)).signature.effects[0]
	assert_true(zone.follows and zone.follows_holder, "it moves with her")
	var sim: CombatSim = K.sim(K.fight([K.at(_with("carrier", _kit("plaguebearer", PathDef.Stage.TRANSFORMED)), 3, 2)] as Array[UnitSetup],
		[K.foe(K.kit("mark", {"stats": {"hp": 5000, "speed": 0}}), 3, 4)] as Array[UnitSetup]))
	var severine: UnitState = sim.heroes[0]
	severine.mana = severine.mana_cap
	K.step(sim, 2)
	severine.pos += Vector2i(1000, 0)
	K.step(sim, 22)
	var moved: Array = sim.combat_log.of_kind(LogEntry.Kind.AREA_LANDED).filter(func(entry: LogEntry) -> bool: return entry.note == "moved")
	assert_gt(moved.size(), 0, "the cloud moved after her")


func test_heavy_frame_needs_her_grown_a_fifth() -> void:
	var frame: AuraDef = _passive(_with("heavy_frame", _kit("bloodglut", PathDef.Stage.TRANSFORMED)), "heavy_frame").aura
	var errors: Array[String] = []
	var grown := UnitState.new()
	grown.base_max_hp = 1100
	grown.max_hp = 1100
	grown.engorged = 100
	assert_false(frame.state.holds(grown, grown), "10% grown: not yet")
	grown.base_max_hp = 1200
	grown.max_hp = 1200
	grown.engorged = 200
	assert_true(frame.state.holds(grown, grown), "20% grown")
	assert_eq(errors, [] as Array[String])


func test_old_thirst_counts_what_lifesteal_heals() -> void:
	var striker: UnitDef = K.kit("striker", {"stats": {"hp": 1000, "speed": 0, "range": 1}, "basic_attack": {"cooldown_ms": 1000,
		"effects": [{"type": "damage", "amount": 100, "target": "target", "lifesteal_pct": 20}]}})
	var setup: UnitSetup = K.at(striker, 3, 2)
	var errors: Array[String] = []
	setup.tally_keys.append("thirst")
	setup.tally_counts.append(DeedDef.read(DataReader.new({"text": "x", "counts": "lifesteal"}, "count", errors)))
	var sim: CombatSim = K.sim(K.fight([setup] as Array[UnitSetup], [K.foe(K.kit("mark", {"stats": {"hp": 5000, "speed": 0}}), 3, 4)] as Array[UnitSetup]))
	sim.unit_by_id("mark").pos = sim.unit_by_id("striker").pos + Vector2i(0, 400)
	sim.unit_by_id("striker").hp = 500
	K.step(sim, 42)
	assert_eq(CombatSim.result_of(sim).tally_amount("striker", "thirst"), 40, "20 a hit, two hits")
	assert_eq(errors, [] as Array[String])


func test_apex_cards_reach_their_snowballs() -> void:
	var leviathan: UnitDef = _content.apexes["leviathan"].apex_kit
	assert_eq(_passive(_with("bottomless", leviathan), "leviathan").aura.value, 600, "+6% per 10%, not 3%")
	assert_eq(_passive(_with("thick_hide", leviathan), "thick_hide").aura.per_engorged_bp, 500, "+1 DEF per 5%")
	var grave: UnitDef = _content.apexes["gravecaller"].apex_kit
	assert_eq(_passive(_with("deep_grave", grave), "gravecaller").ability.effects[0].raise_grow_hp_bp, 3000, "+30% per thrall, not 10%")
	assert_eq(_with("crimson_spray", _content.apexes["blood_tide"].apex_kit).signature.effects[1].near_range, 2 * HexGrid.HEX, "the splash reaches 2 hexes")
	assert_eq(_passive(_with("crimson_flood", _content.apexes["blood_tide"].apex_kit), "tidal_thirst").aura.value, 400, "+4% per cast, not 2%")
	var nova: EffectDef = _with("blood_rain", _content.apexes["sanguine_nova"].apex_kit).signature.effects[0]
	assert_eq(nova.area_effects.back().status_id, "slow", "Nova slows")


func test_her_bond_relics() -> void:
	var maw: RelicDef = _run.relics["the_iron_maw"]
	assert_eq([maw.tier, _run.bonds["iron_hunger"].relic, _run.bonds["iron_hunger"].paths], [RelicDef.Tier.BOND, "the_iron_maw", ["bloodglut", "spitemail"] as Array[String]])
	var lamp: RelicDef = _run.relics["the_lamp_of_ichor"]
	assert_eq([lamp.tier, _run.bonds["blood_and_lamplight"].relic], [RelicDef.Tier.BOND, "the_lamp_of_ichor"])
	var problems: Array[String] = []
	var exsanguinate: AbilityDef = lamp.mod.apply(_kit("hemomancer", PathDef.Stage.TRANSFORMED), problems).signature
	assert_eq(exsanguinate.effects.back().type, EffectDef.Type.GAIN_MANA, "Vell's bar fills")
	var vowed_mend: AbilityDef = lamp.mod.apply(_content.paths["lanternbearer"].vowed_kit, problems).signature
	assert_not_null(vowed_mend.prefer, "Mend goes to her first")
	assert_eq(vowed_mend.prefer.kits, ["severine"] as Array[String])
	var habit: PartDef = _passive(lamp.mod.apply(_content.paths["lanternbearer"].transformed_kit, problems), "mend")
	assert_not_null(habit.ability.effects[0].prefer, "and as a habit")
	assert_eq(problems, [] as Array[String])
