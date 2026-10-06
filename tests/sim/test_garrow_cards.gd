extends GutTest
## Garrow's upgrade cards (phase 8 part 4, docs/plans/upgrade-pools.md Garrow;
## rebuild-phase8-heroes.md 8d-2d) on his real kits: each changes the kit it's
## offered on, a card on Haul reaches it as his signature or as his habit
## (a cost change moves the habit's every by one), and the knobs they added.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["garrow"].kit


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
		if card.hero == "garrow" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "garrow"):
			cards.append(id)
			var kit: UnitDef = _base()
			if not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15, "12 of his own, 2 tastes and 5 path cards a path")


func test_swift_haul_reaches_the_signature_and_the_habit() -> void:
	assert_eq(_with("swift_haul", _base()).mana.max, 60, "Haul costs 10 less")
	var aegis: UnitDef = _kit("aegisfang", PathDef.Stage.TRANSFORMED)
	var hasted: UnitDef = _with("swift_haul", aegis)
	assert_eq(hasted.mana.max, aegis.mana.max, "Bulwark Burst's cost is its own")
	assert_eq(_passive(hasted, "haul").ability.effects[0].every, 7, "the habit comes one Chain Fist sooner")
	assert_eq(_with("quick_burst", aegis).mana.max, aegis.mana.max - 15, "Quick Burst names Bulwark Burst")


func test_long_barbs_and_back_line_hook_reach_the_habit() -> void:
	var warden: UnitDef = _kit("chainwarden", PathDef.Stage.TRANSFORMED)
	var barbed: UnitDef = _with("long_barbs", warden, true)
	assert_eq(_passive(barbed, "haul").ability.effects[0].scaling[UnitStats.Stat.ATK], 2250, "the habit's Bleed, x1.5")
	assert_eq(barbed.signature.effects[0].scaling[UnitStats.Stat.ATK], 2500, "not Maelstrom's")
	var hooked: UnitDef = _with("back_line_hook", warden)
	for effect: EffectDef in _passive(hooked, "haul").ability.effects:
		assert_not_null(effect.prefer, "each chain goes for casters and archers first")
	assert_not_null(_with("back_line_hook", _kit("chainwarden", PathDef.Stage.VOWED)).signature.prefer, "as does his signature")


func test_the_crowd_cards() -> void:
	var warden: UnitDef = _kit("chainwarden", PathDef.Stage.TRANSFORMED)
	var wide: UnitDef = _with("wide_crowd", warden)
	assert_eq([_passive(wide, "crowd_strength").aura.per_enemy_range, _passive(wide, "crowd_guard").aura.per_enemy_range], [2000, 2000])
	assert_eq(_passive(warden, "crowd_strength").aura.per_enemy_range, 1000, "the path's own kit is untouched")
	var bloodied: UnitDef = _with("bloodied_links", wide)
	assert_eq(_passive(bloodied, "crowd_strength").aura.per_enemy_range, 2000, "the cards stack")
	assert_not_null(_passive(bloodied, "crowd_guard").aura.per_twice)


func test_shared_ward_reads_the_shield_before_it_is_spent() -> void:
	var ward: UnitDef = _with("shared_ward", _kit("aegisfang", PathDef.Stage.TRANSFORMED))
	assert_eq(ward.signature.effects.map(func(effect: EffectDef) -> String: return EffectDef.TYPE_NAMES[effect.type]), ["area", "shield", "spend_shield"])


func test_the_spitemail_cards() -> void:
	var spite: UnitDef = _kit("spitemail", PathDef.Stage.TRANSFORMED)
	var bitter: UnitDef = _with("bitter_blood", spite, true)
	assert_true(_passive(bitter, "maidens_spite").ability.effects[0].ignores_def, "once transformed, Iron Maiden's too")
	assert_true(_passive(_with("bitter_blood", _kit("spitemail", PathDef.Stage.VOWED)), "spikes").ability.effects[0].ignores_def)
	var long: UnitDef = _with("long_maiden", spite)
	var durations: Array = long.signature.effects.map(func(effect: EffectDef) -> int:
		return effect.area_effects[0].duration_ticks if effect.type == EffectDef.Type.AREA else effect.duration_ticks)
	assert_eq(durations, [80, 80], "the taunt and the Maiden both last 4s")
