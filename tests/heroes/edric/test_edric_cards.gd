extends GutTest
## Edric's upgrade cards (phase 8 part 5, docs/plans/design/upgrade-pools.md Edric;
## rebuild-phase8-severine-edric.md 8e-3c) on his real kits: each changes the
## kit it's offered on (or his Tithe), a card on Ward reaches it as his
## signature or as his habit, Hallow's cards (an interval through
## cooldown_bp, a preference for allies without a Shield), and his 12 apex
## cards on their apexes' kits.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["edric"].kit


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
		if card.hero == "edric" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "edric"):
			cards.append(id)
			var kit: UnitDef = _base()
			if card.layer == UpgradeDef.Layer.APEX:
				kit = _content.apexes[card.apex].apex_kit
			elif not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15 + 12, "12 of his own, 2 tastes and 5 path cards a path, 2 an apex")


func test_ward_cards_reach_the_signature_and_the_habit() -> void:
	assert_eq(_with("strong_ward", _base()).signature.effects[0].power_bp, 2500, "10%, not 8%: +25% power")
	var habit: PartDef = _passive(_with("strong_ward", _kit("aegis", PathDef.Stage.TRANSFORMED)), "ward")
	assert_eq(habit.ability.effects[0].power_bp, 2500, "the habit too")
	assert_eq(_with("swift_ward", _base()).mana.max, 60)
	assert_eq(_passive(_with("swift_ward", _kit("psalmist", PathDef.Stage.TRANSFORMED)), "ward").ability.effects[0].every, 7, "a habit comes a Seal sooner")


func test_hallow_cards() -> void:
	var vowed: UnitDef = _kit("aegis", PathDef.Stage.VOWED)
	assert_eq(_passive(_with("quick_hallow", vowed), "hallow").ability.effects[0].interval_ticks, 100, "every 5s, not 6s")
	var transformed: UnitDef = _kit("aegis", PathDef.Stage.TRANSFORMED)
	assert_eq(_passive(_with("quick_hallow", transformed, true), "hallow").ability.effects[0].interval_ticks, 72, "a tenth sooner once transformed (4s to 3.6s)")
	assert_eq(_passive(_with("faster_hallow", transformed), "hallow").ability.effects[0].interval_ticks, 67, "a sixth sooner (4s to 3.3s)")
	var steady: EffectDef = _passive(_with("steady_hallow", transformed), "hallow").ability.effects[0]
	assert_not_null(steady.prefer, "allies without a Shield first")
	assert_eq(steady.prefer.shielded, UnitCondition.Flying.NO)


func test_vigil_cards() -> void:
	assert_eq(_passive(_with("wide_vigil", _base()), "vigil").aura.target_range, 3 * HexGrid.HEX)
	assert_eq(_passive(_with("deep_vigil", _base()), "vigil").aura.value, 800)


func test_collection_cards() -> void:
	var kit: UnitDef = _kit("tithe_collector", PathDef.Stage.TRANSFORMED)
	var window: EffectDef = _with("long_collection", kit).signature.effects[1]
	assert_eq(window.duration_ticks, 160, "8s")
	var plated: Array[EffectDef] = _with("full_plate", kit).signature.effects
	assert_eq(plated.filter(func(effect: EffectDef) -> bool: return effect.status_id == "collection").map(func(effect: EffectDef) -> int: return effect.stacks), [3, 2], "up to 5 a cast")
	assert_eq(_with("quick_collection", kit).mana.max, 60)
	assert_eq(_with("thick_collection", kit).signature.effects[0].power_bp, 5000, "12%, not 8%")


func test_psalm_cards() -> void:
	var kit: UnitDef = _kit("psalmist", PathDef.Stage.TRANSFORMED)
	assert_eq(_passive(_with("steady_song", kit), "psalm").aura.value, 11500)
	assert_eq(_passive(_with("quick_breath", kit, true), "psalm").aura.value, 11500, "Quick Breath once transformed")
	assert_not_null(_passive(_with("quick_breath", _kit("psalmist", PathDef.Stage.VOWED)), "quick_breath"), "its own aura while vowed")
	var bright: Array[EffectDef] = _passive(_with("bright_offering", kit), "offering").ability.effects
	assert_eq(bright.back().status_id, "bright_offering")
	assert_eq(bright.back().target, EffectDef.Target.TRIGGER_ALLY)


func test_apex_cards() -> void:
	var bastion: UnitDef = _content.apexes["bastion_of_saints"].apex_kit
	assert_eq(_passive(_with("saintly", bastion), "hallow").ability.effects[0].grows_stack_bp, 2000, "+1% a Hallow, not 0.5%")
	var reforged: UnitDef = _content.apexes["reforged_ward"].apex_kit
	assert_eq(_passive(_with("quick_forge", reforged), "reforge").ability.effects[0].cooldown_per_unit_ticks, 60, "once every 3s for each ally")
	var evensong: UnitDef = _content.apexes["evensong"].apex_kit
	assert_eq(_passive(_with("swelling_song", evensong), "evensong").ability.effects[0].power_bp, 3000, "13%, not 10%")


func test_his_bond_relics() -> void:
	var ward: RelicDef = _run.relics["the_last_ward"]
	assert_eq([ward.tier, _run.bonds["watched_over"].relic, _run.bonds["watched_over"].paths], [RelicDef.Tier.BOND, "the_last_ward", ["aegis", "last_watch"] as Array[String]])
	var problems: Array[String] = []
	var hallow: EffectDef = _passive(ward.mod.apply(_kit("aegis", PathDef.Stage.TRANSFORMED), problems), "hallow").ability.effects[0]
	assert_eq(hallow.prefer.kits, ["brannoc"] as Array[String], "Hallow goes to Brannoc first")
	assert_eq(hallow.prefer.below_hp_bp, 3000, "below 30%")
	var psalter: RelicDef = _run.relics["the_psalter"]
	assert_eq([psalter.tier, _run.bonds["psalm_and_chorus"].relic, _run.bonds["psalm_and_chorus"].paths], [RelicDef.Tier.BOND, "the_psalter", ["psalmist", "chorister"] as Array[String]])
	var crescendo: AbilityDef = psalter.mod.apply(_content.paths["chorister"].transformed_kit, problems).signature
	assert_eq(crescendo.effects.back().type, EffectDef.Type.SHIELD, "Crescendo shields as it gives mana")
	assert_eq(problems, [] as Array[String])


func test_the_psalter_fills_aldous_on_every_broken_ward() -> void:
	# Every hero holds the relic's passive; only Edric's runs (its "holder").
	var passives: Array = [_run.relics["the_psalter"].mod.passives[0]]
	var idle: Dictionary = {"stats": {"hp": 1000, "speed": 0, "range": 1}, "mana": {"max": 100, "per_attack": 0},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]},
		"signature": {"id": "nothing", "name": "Nothing", "trigger": {"kind": "mana"}, "targeting": "self", "effects": [{"type": "shield", "amount": 1, "target": "self"}]}}
	var heroes: Array[UnitSetup] = []
	for hero_id: String in ["brannoc", "aldous", "edric"]:
		var kit: UnitDef = K.kit(hero_id, idle)
		kit.passives.assign(passives)
		heroes.append(K.at(kit, ["brannoc", "aldous", "edric"].find(hero_id) * 2, 2))
	var attacker: UnitDef = K.kit("attacker", {"stats": {"hp": 5000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 1000, "effects": [{"type": "damage", "amount": 100, "target": "target"}]}})
	var fight: CombatSim = K.sim(K.fight(heroes, [K.foe(attacker, 0, 4)] as Array[UnitSetup]))
	fight.unit_by_id("attacker").pos = fight.unit_by_id("brannoc").pos + Vector2i(0, 400)
	fight.unit_by_id("brannoc").shield = 10
	K.step(fight, 22)
	var given: Array[LogEntry] = K.entries(fight, LogEntry.Kind.MANA_GIVEN, "edric")
	assert_eq(given.map(func(entry: LogEntry) -> String: return "%s %s %d" % [entry.source_ability, entry.target, entry.amount]), ["the_psalter aldous 1000"],
		"once, from Edric, to Aldous: 10 mana")
