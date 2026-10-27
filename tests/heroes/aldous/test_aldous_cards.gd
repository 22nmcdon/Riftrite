extends GutTest
## Aldous's upgrade cards (phase 8 part 4, docs/plans/upgrade-pools.md Aldous;
## rebuild-phase8-heroes.md 8d-4d) and his bond relics on his real kits:
## each changes the kit it's offered on, a card on Peal reaches it as his
## signature or as his habit, and the new knobs (within_add, count_add) do
## what they say.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["aldous"].kit


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
		if card.hero == "aldous" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "aldous"):
			cards.append(id)
			var kit: UnitDef = _base()
			if card.layer == UpgradeDef.Layer.APEX:
				kit = _content.apexes[card.apex].apex_kit
			elif not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15 + 12, "12 of his own, 2 tastes and 5 path cards a path, and 2 an apex")


func test_peal_cards_reach_the_signature_and_the_habit() -> void:
	assert_eq(_with("long_peal", _base()).signature.effects[0].duration_ticks, 120, "6s, not 4s")
	var habit: PartDef = _passive(_with("long_peal", _kit("bellwarden", PathDef.Stage.TRANSFORMED)), "peal")
	assert_eq(habit.ability.effects[0].duration_ticks, 120, "and as a habit")
	assert_eq(_with("wide_peal", _base()).signature.effects[0].near_range, 4 * HexGrid.HEX, "within 4 hexes")
	assert_eq(_passive(_with("wide_peal", _kit("chorister", PathDef.Stage.TRANSFORMED)), "peal").ability.effects[0].near_range, 4 * HexGrid.HEX)
	var hymn: UnitDef = _with("steadying_hymn", _base())
	assert_eq(EffectDef.TYPE_NAMES[hymn.signature.effects[1].type], "cleanse")


func test_resonance_cards() -> void:
	var resonance: AuraDef = _passive(_with("far_resonance", _base()), "resonance").aura
	assert_eq(resonance.target_range, 3 * HexGrid.HEX, "within 3 hexes")
	assert_eq(_passive(_with("strong_resonance", _base()), "resonance").aura.value, 10)
	assert_eq(_passive(_base(), "resonance").aura.target_range, 2 * HexGrid.HEX, "the base kit is untouched")


func test_the_chorister_cards() -> void:
	var vowed: UnitDef = _kit("chorister", PathDef.Stage.VOWED)
	assert_eq(_passive(_with("two_breaths", vowed), "shared_breath").ability.effects[0].count, 2, "the 2 allies with the least mana")
	assert_eq(_passive(_with("deep_breath", vowed), "shared_breath").ability.effects[0].amount, 25)
	var chorister: UnitDef = _kit("chorister", PathDef.Stage.TRANSFORMED)
	assert_eq(_with("quick_crescendo", chorister).mana.max, chorister.mana.max - 10)
	assert_eq(_passive(_with("wide_chorus", chorister), "chorus").ability.effects[0].near_range, 4 * HexGrid.HEX)
	var kindled: UnitDef = _with("kindled_chorus", chorister)
	assert_eq(kindled.signature.effects[2].status_id, "kindled")
	assert_eq(_passive(kindled, "chorus").ability.effects[1].status_id, "kindled")


func test_the_windcaller_cards() -> void:
	var windcaller: UnitDef = _kit("windcaller", PathDef.Stage.TRANSFORMED)
	assert_eq(_passive(_with("steady_tailwind", _kit("windcaller", PathDef.Stage.VOWED)), "tailwind").aura.value, 8)
	assert_eq(_with("strong_gale", windcaller).signature.effects[0].hexes, 3, "3 hexes, not 2")
	assert_eq(_with("quick_gale", windcaller).mana.max, windcaller.mana.max - 10)
	assert_true(_passive(_with("keen_wind", windcaller), "keen_wind").aura.only.ranged == UnitCondition.Flying.YES)


func test_the_bellwarden_cards() -> void:
	var vowed: UnitDef = _kit("bellwarden", PathDef.Stage.VOWED)
	assert_eq(_passive(_with("sharp_toll", vowed), "toll_the_hour").ability.effects[0].every, 3)
	assert_eq(_passive(_with("long_toll", vowed), "toll_the_hour").ability.effects[0].duration_ticks, 60)
	var bellwarden: UnitDef = _kit("bellwarden", PathDef.Stage.TRANSFORMED)
	assert_eq(_passive(_with("sharp_toll", bellwarden, true), "toll_the_hour").ability.effects[0].duration_ticks, 70, "carried past the transformation")
	assert_eq(_with("wide_knell", bellwarden).signature.effects[1].near_range, 4 * HexGrid.HEX)
	assert_eq(_with("wide_knell", bellwarden).signature.effects[0].near_range, 0, "his target is the target")
	var rung: UnitDef = _with("ringing_mark", bellwarden)
	assert_eq(rung.signature.effects.map(func(effect: EffectDef) -> String: return effect.status_id), ["marked", "marked", "rung", "rung"])


func test_deaths_appointment_readies_sentence() -> void:
	var relic: RelicDef = _run.relics["deaths_appointment"]
	assert_eq(relic.tier, RelicDef.Tier.BOND)
	assert_eq(_run.bonds["the_hunters_bell"].relic, "deaths_appointment")
	var problems: Array[String] = []
	var knell: AbilityDef = relic.mod.apply(_kit("bellwarden", PathDef.Stage.TRANSFORMED), problems).signature
	assert_eq(knell.effects[knell.effects.size() - 1].type, EffectDef.Type.GAIN_MANA, "Tamsin's bar fills")
	var sentence: AbilityDef = relic.mod.apply(_content.paths["headhunter"].transformed_kit, problems).signature
	assert_eq(sentence.max_range, 10, "a Marked enemy anywhere on the field")
	assert_eq(EffectDef.TYPE_NAMES[sentence.effects[1].type], "leap", "she steps behind it")
	assert_eq(problems, [] as Array[String])
	for path_id: String in ["chorister", "windcaller", "nightblade", "garrote"]:
		assert_false(relic.mod.affects(_content.paths[path_id].transformed_kit), "%s: nothing" % path_id)


func test_the_toll_of_dawn_calls_down_sunfall() -> void:
	var relic: RelicDef = _run.relics["the_toll_of_dawn"]
	assert_eq(_run.bonds["toll_and_judgment"].relic, "the_toll_of_dawn")
	var problems: Array[String] = []
	var knell: AbilityDef = relic.mod.apply(_kit("bellwarden", PathDef.Stage.TRANSFORMED), problems).signature
	assert_eq(knell.effects[knell.effects.size() - 1].type, EffectDef.Type.AREA, "a Sunfall along the line")
	var vell: UnitDef = relic.mod.apply(_content.paths["vigil_keeper"].transformed_kit, problems)
	var mend: PartDef = _passive(vell, "mend")
	var smite: EffectDef = mend.ability.effects[mend.ability.effects.size() - 1]
	assert_eq(smite.target, EffectDef.Target.ALL_ENEMIES)
	assert_eq(smite.only.keywords, ["marked"] as Array[String], "every Marked enemy")
	assert_eq(problems, [] as Array[String])
	for path_id: String in ["chorister", "windcaller", "headhunter"]:
		assert_false(relic.mod.affects(_content.paths[path_id].transformed_kit), "%s: nothing" % path_id)
