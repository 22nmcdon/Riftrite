extends GutTest
## Ilse's upgrade cards (phase 8 part 6, docs/plans/upgrade-pools.md Ilse;
## rebuild-phase8-last-heroes.md 8f-1) on her real kits: each changes the kit
## it's offered on, a card on Flare reaches it as her signature or her habit,
## the knobs her cards added (Heat's reach, Stoke's share, the ground's
## spread, Blessing's reach), and the bond relics built with her: Fire on the
## Wind, Bellows of the Wind, The Firepit, and The Vigil Lamp.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["ilse"].kit


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
		if card.hero == "ilse" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "ilse"):
			if card.layer == UpgradeDef.Layer.APEX:
				continue
			cards.append(id)
			var kit: UnitDef = _base()
			if not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15, "12 of her own, 2 tastes and 5 path cards a path")


func test_flare_cards_reach_the_signature_and_the_habit() -> void:
	assert_eq(_with("wide_flare", _base()).signature.effects[0].shape.size, 2)
	assert_eq(_passive(_with("wide_flare", _kit("furnace", PathDef.Stage.TRANSFORMED)), "flare").ability.effects[0].shape.size, 2, "the habit too")
	var hot: EffectDef = _with("hot_hands", _base()).basic_attack.effects[1]
	assert_eq(hot.scaling[UnitStats.Stat.MGK], 1500, "15% of her MGK, not 10%")


func test_her_own_cards() -> void:
	assert_eq(_passive(_with("fan_the_coals", _base()), "heat").ability.effects[0].near_trigger_range, 4 * HexGrid.HEX, "Heat reaches 4 hexes")
	var start: EffectDef = _passive(_with("kindled_start", _base()), "kindled_start").ability.effects[0]
	assert_true(start.once)
	assert_not_null(_passive(_with("flashover", _base()), "flashover"))


func test_furnace_cards() -> void:
	assert_eq(_passive(_with("deep_stoke", _kit("furnace", PathDef.Stage.VOWED)), "stoke").ability.effects[0].stacks_share_bp, 700, "7%, not 5%")
	assert_eq(_passive(_with("deep_stoke", _kit("furnace", PathDef.Stage.TRANSFORMED), true), "stoke").ability.effects[0].stacks_share_bp, 1000, "8% to 10% once transformed")
	var kit: UnitDef = _kit("furnace", PathDef.Stage.TRANSFORMED)
	assert_eq(_with("short_fuse", kit).mana.max, 45)
	var splash: EffectDef = _with("ashfall", kit).signature.effects[0]
	assert_eq(splash.near_range, 2 * HexGrid.HEX, "Immolate's splash reaches 2 hexes")


func test_wildfire_cards() -> void:
	var kit: UnitDef = _kit("wildfire", PathDef.Stage.TRANSFORMED)
	var fast: EffectDef = _with("fast_spread", kit).signature.effects[0]
	assert_eq(fast.grow_ticks, 30, "every 1.5s, not 2s")
	assert_eq(_passive(_with("fast_spread", kit), "kindling").ability.effects[0].grow_ticks, 30, "Kindling too")
	assert_eq(_with("far_spread", kit).signature.effects[0].grow_max, 4)
	assert_eq(_passive(_with("wide_kindling", _kit("wildfire", PathDef.Stage.VOWED)), "kindling").ability.effects[0].shape.size, 2)


func test_ember_choir_cards() -> void:
	var vowed: UnitDef = _kit("ember_choir", PathDef.Stage.VOWED)
	assert_eq(_passive(_with("shared_blessing", vowed), "blessing").ability.effects[0].nearest, 2, "the 2 nearest")
	assert_eq(_passive(_with("quick_blessing", vowed), "blessing").ability.effects[0].interval_ticks, 120, "every 6s")
	var kit: UnitDef = _kit("ember_choir", PathDef.Stage.TRANSFORMED)
	assert_eq(_with("long_hymn", kit).signature.effects[0].duration_ticks, 140, "7s")


func test_her_bond_relics() -> void:
	for pair: Array in [["burning_volley", "fire_on_the_wind", ["ember_choir", "volley"]], ["the_bellows", "bellows_of_the_wind", ["furnace", "windcaller"]],
			["the_firepit", "the_firepit", ["chainwarden", "wildfire"]], ["lantern_vigil", "the_vigil_lamp", ["last_watch", "lanternbearer"]]]:
		var bond: BondDef = _run.bonds[pair[0]]
		assert_eq([bond.relic, bond.paths, _run.relics[pair[1]].tier], [pair[1], pair[2] as Array[String], RelicDef.Tier.BOND], pair[0])
	var problems: Array[String] = []
	var storm: EffectDef = _run.relics["fire_on_the_wind"].mod.apply(_content.paths["volley"].transformed_kit, problems).signature.effects[0]
	assert_eq(storm.area_effects.back().status_id, "burn", "Arrow Storm rains fire")
	var lamp: RelicDef = _run.relics["the_vigil_lamp"]
	assert_true(lamp.mod_fits(_content.paths["lanternbearer"].transformed_kit), "Vell's")
	assert_false(lamp.mod_fits(_content.paths["last_watch"].transformed_kit), "not Brannoc's")
	var mend: EffectDef = _passive(lamp.mod.apply(_content.paths["lanternbearer"].transformed_kit, problems), "mend").ability.effects[0]
	assert_eq(mend.heal_cap_bp, 3000, "her heals on him stop at 30%")
	var pit: UnitDef = _run.relics["the_firepit"].mod.apply(_content.paths["chainwarden"].transformed_kit, problems)
	assert_not_null(_passive(pit, "crowd_strength").aura.per_twice, "Crowd Strength counts the Burning twice")
	assert_eq(problems, [] as Array[String])


func test_the_vigil_lamp_caps_heals_on_brannoc() -> void:
	var healer: UnitDef = K.kit("vell", {"stats": {"hp": 1000, "speed": 0, "range": 4},
		"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"passives": [{"id": "mend", "name": "Mend", "kind": "ability", "effects": [{"trigger": "on_basic_attack", "type": "heal", "amount": 300, "target": "lowest_hp_ally", "within_hexes": 8}]}]})
	var problems: Array[String] = []
	healer = _run.relics["the_vigil_lamp"].mod.apply(healer, problems)
	assert_eq(problems, [] as Array[String])
	var tank: UnitDef = K.kit("brannoc", {"stats": {"hp": 1000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var foe: UnitDef = K.kit("dummy", {"stats": {"hp": 5000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight([K.at(tank, 3, 2), K.at(healer, 0, 0)] as Array[UnitSetup], [K.foe(foe, 3, 5)] as Array[UnitSetup]))
	fight.unit_by_id("brannoc").hp = 100
	fight.unit_by_id("dummy").pos = fight.unit_by_id("vell").pos + Vector2i(0, 1500)
	var brannoc: UnitState = fight.unit_by_id("brannoc")
	while K.entries(fight, LogEntry.Kind.HEAL, "vell").is_empty() and fight.tick < 60:
		K.step(fight, 1)
	assert_eq(K.entries(fight, LogEntry.Kind.HEAL, "vell").size(), 1, "Mend")
	assert_eq([brannoc.hp, brannoc.shield], [300, 100], "healed to 30%, the other 100 a Shield")
