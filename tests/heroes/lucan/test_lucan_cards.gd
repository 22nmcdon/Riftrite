extends GutTest
## Lucan's upgrade cards (phase 8 part 6, docs/plans/design/upgrade-pools.md Lucan;
## rebuild-phase8-last-heroes.md 8f-4) on his real kits: each changes the kit
## it's offered on, cards on Mirror reach it as his signature and as his
## habit, the copy cards reach a copy's share and time, and the growing ones
## scale.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


func _base() -> UnitDef:
	return _content.heroes["lucan"].kit


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


func _effect(kit: UnitDef, part_id: String) -> EffectDef:
	return _passive(kit, part_id).ability.effects[0]


func test_every_card_changes_the_kit_it_is_offered_on() -> void:
	var cards: Array[String] = []
	for id: String in _run.upgrade_ids:
		var card: UpgradeDef = _run.upgrades[id]
		if card.hero == "lucan" or (_content.paths.has(card.path) and _content.paths[card.path].hero == "lucan"):
			if card.layer == UpgradeDef.Layer.APEX:
				continue
			cards.append(id)
			var kit: UnitDef = _base()
			if not card.path.is_empty():
				kit = _kit(card.path, PathDef.Stage.VOWED if card.layer == UpgradeDef.Layer.TASTE else PathDef.Stage.TRANSFORMED)
			assert_true(_run.changes_something(card, card.layer == UpgradeDef.Layer.PATH, kit), id)
	assert_eq(cards.size(), 12 + 6 + 15, "12 of his own, 2 tastes and 5 path cards a path")


func test_mirror_cards_reach_the_signature_and_the_habit() -> void:
	var long: UnitDef = _with("long_mirror", _base())
	assert_eq(long.signature.effects[0].lasts_ticks, 9 * 20, "6s and 3s more")
	assert_eq(_with("strong_mirror", _base()).signature.effects[0].copy_share_bp, 4500, "45% of his stats, not 30%")
	assert_eq(_with("quick_mirror", _base()).mana.max, 50)
	var habit: EffectDef = _effect(_with("strong_mirror", _kit("veilweaver", PathDef.Stage.TRANSFORMED)), "mirror")
	assert_eq([habit.copy_share_bp, habit.lasts_ticks], [4500, 3 * 20], "the habit too")
	assert_eq(_effect(_with("long_mirror", _kit("puppeteer", PathDef.Stage.TRANSFORMED)), "mirror").lasts_ticks, 9 * 20)
	assert_eq(_effect(_with("quick_mirror", _kit("veilweaver", PathDef.Stage.TRANSFORMED)), "mirror").every, 7, "a habit comes sooner")


func test_his_own_cards() -> void:
	var base: UnitDef = _base()
	assert_eq(_passive(_with("deep_unreal", base), "unreal").aura.value, 2500, "25%, not 15%")
	assert_eq(_with("dazzling_glimmer", base).basic_attack.effects.back().status_id, "glimmer_dazzle")
	var bright: AuraDef = _passive(_with("bright_shard", base), "bright_shard").aura
	assert_true(bright.from_basic and bright.vs.target != null and bright.vs.target.summon, "Glimmer, at an enemy attacking a summon")
	var misdirect: EffectDef = _effect(_with("misdirect", base), "misdirect")
	assert_eq([misdirect.trigger, misdirect.vs.copy], [EffectDef.Trigger.ON_SUMMON_FELL, true])
	assert_eq(_run.upgrades["gallery"].grows.each.times(3).stats_bp[UnitStats.Stat.MGK], 10300)


func test_mirrorwright_cards() -> void:
	var vowed: UnitDef = _kit("mirrorwright", PathDef.Stage.VOWED)
	assert_eq(_effect(_with("quick_reflection", vowed), "reflection").interval_ticks, 10 * 20, "every 10s, not 12s")
	assert_eq(_effect(_with("lasting_reflection", vowed), "reflection").lasts_ticks, 5 * 20)
	var kit: UnitDef = _kit("mirrorwright", PathDef.Stage.TRANSFORMED)
	assert_eq(_effect(_with("fast_reflection", kit), "reflection").interval_ticks, 5 * 20)
	assert_eq(_effect(_with("many_mirrors", kit), "reflection").max_standing, 4)
	assert_eq(_with("long_hall", kit).signature.effects[0].lasts_ticks, 10 * 20)
	assert_eq(_with("quick_hall", kit).mana.max, 45)
	var problems: Array[String] = []
	var glass: UnitDef = _run.upgrades["silvered_glass"].grows.each.times(5).apply(kit, problems)
	assert_eq(problems, [] as Array[String])
	assert_eq([_effect(glass, "reflection").copy_share_bp, glass.signature.effects[0].copy_share_bp, _effect(glass, "mirror").copy_share_bp], [7500, 8500, 3500],
		"5 steps: +5% on every copy he makes")


func test_veilweaver_cards() -> void:
	var vowed: UnitDef = _kit("veilweaver", PathDef.Stage.VOWED)
	assert_eq(_effect(_with("quick_shroud", vowed), "shroud").interval_ticks, 8 * 20)
	assert_eq(_effect(_with("deep_shroud", vowed), "shroud").duration_ticks, 30, "1.5s")
	var kit: UnitDef = _kit("veilweaver", PathDef.Stage.TRANSFORMED)
	assert_eq(_effect(_with("faster_shroud", kit), "shroud").interval_ticks, 64, "3.2s, not 4s")
	assert_eq(_effect(_with("shroud_splits", kit), "shroud").count, 3, "the next most targeted ally too")
	assert_eq(_with("long_act", kit).signature.effects[0].duration_ticks, 3 * 20)
	var step: AuraDef = _passive(_with("veiled_step", kit), "veiled_step").aura
	assert_eq([step.stat, step.value, step.only.keywords], [AuraDef.Stat.SPEED, 1, ["stealthed"] as Array[String]])
	assert_eq(_run.upgrades["velvet_dark"].grows.each.times(4).passives[0].aura.value, 10400)


func test_puppeteer_cards() -> void:
	var vowed: UnitDef = _kit("puppeteer", PathDef.Stage.VOWED)
	assert_eq(_passive(_with("strong_strings", vowed), "strings").aura.value, 10300, "3% a unit, not 2%")
	assert_true(_passive(_with("lead_puppet", vowed), "strings").aura.per_twice.copy, "his copies count twice")
	var kit: UnitDef = _kit("puppeteer", PathDef.Stage.TRANSFORMED)
	assert_eq(_passive(_with("strong_strings", kit, true), "strings").aura.value, 11100)
	assert_eq(_with("long_string_dance", kit).signature.effects[0].duration_ticks, 7 * 20)
	assert_eq(_with("quick_dance", kit).mana.max, 45)
	assert_eq(_passive(_with("sharpened_puppets", kit), "sharpened_puppets").aura.value, 1500)
	assert_eq(_passive(_with("sturdy_puppets", kit), "sturdy_puppets").aura.value, 12000)


func test_his_cards_say_their_numbers() -> void:
	var base: UnitDef = _base()
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["strong_mirror"], base, _content), "Mirror: +15% of the stats it copies")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["long_mirror"], base, _content), "Mirror: +3s duration")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["shroud_splits"], _kit("veilweaver", PathDef.Stage.TRANSFORMED), _content), "Shroud: +1 ally")


func test_his_bond_relics() -> void:
	for pair: Array in [["unseen_blade", "the_shroud_of_knives", ["nightblade", "veilweaver"]], ["the_menagerie", "the_menagerie", ["puppeteer", "packleader"]],
			["hall_of_arrows", "mirror_step", ["mirrorwright", "volley"]]]:
		var bond: BondDef = _run.bonds[pair[0]]
		assert_eq([bond.relic, bond.paths, _run.relics[pair[1]].tier], [pair[1], pair[2] as Array[String], RelicDef.Tier.BOND], pair[0])
	var problems: Array[String] = []
	var menagerie: RelicDef = _run.relics["the_menagerie"]
	assert_true(menagerie.mod_fits(_kit("puppeteer", PathDef.Stage.TRANSFORMED)), "Lucan's")
	var strings: AuraDef = _passive(menagerie.mod.apply(_with("lead_puppet", _kit("puppeteer", PathDef.Stage.TRANSFORMED), true), problems), "strings").aura
	assert_eq(problems, [] as Array[String])
	assert_eq(strings.per_twice.describe(), "a copy or Grit or Brindle", "Lead Puppet's copies still count twice beside the hounds")


func _bond_fight(team: Array[String], vows: Dictionary[String, String], hero_id: String, relic_id: String, encounter_id: String = "cairn_road") -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var extras: Dictionary[String, HeroExtras] = {hero_id: HeroExtras.new()}
	if not relic_id.is_empty():
		extras[hero_id].mods.append(_run.relics[relic_id].mod)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, team, extras)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func test_the_shroud_of_knives_covers_tamsin() -> void:
	var sim: CombatSim = _bond_fight(["brannoc", "tamsin", "lucan"] as Array[String],
		{"tamsin": "nightblade", "lucan": "veilweaver", "brannoc": "hearthwall"} as Dictionary[String, String], "lucan", "the_shroud_of_knives")
	var hid: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "shroud_of_knives")
	assert_gt(hid.size(), 0, "Shroud hides Tamsin")
	assert_true(hid.all(func(entry: LogEntry) -> bool: return entry.target == "tamsin"), "only her")
	assert_gt(sim.combat_log.of_kind(LogEntry.Kind.STATUS_EXTENDED).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "covering_kills").size(), 0,
		"her kills keep the hidden hidden")


func test_the_menagerie_counts_the_hounds_twice() -> void:
	var team: Array[String] = ["brannoc", "kestra", "lucan"]
	var vows: Dictionary[String, String] = {"kestra": "packleader", "lucan": "puppeteer", "brannoc": "hearthwall"}
	var powers: Array[int] = []
	for relic_id: String in ["", "the_menagerie"]:
		var sim: CombatSim = _bond_fight(team, vows, "lucan", relic_id)
		powers.append(sim.combat_log.of_kind(LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "lucan" and entry.source_ability == "glimmer")[0].rule_power)
	assert_eq(powers[1] - powers[0], 2 * 1000, "Grit and Brindle each count once more: +10% each")


func test_mirror_step_leaves_a_copy_of_maren() -> void:
	var sim: CombatSim = _bond_fight(["brannoc", "maren", "lucan"] as Array[String],
		{"maren": "volley", "lucan": "mirrorwright", "brannoc": "hearthwall"} as Dictionary[String, String], "maren", "mirror_step", "alphas_trail")
	var hops: int = sim.combat_log.of_kind(LogEntry.Kind.HOP).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "maren").size()
	var copies: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.SUMMON).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "mirror_step")
	assert_gt(hops, 0, "she hops")
	assert_gt(copies.size(), 0, "and leaves a copy of herself")
	assert_eq(copies[0].end_tick - copies[0].tick, 3 * 20)
	assert_true(copies[0].target.begins_with("maren_copy"))


func test_his_apex_cards() -> void:
	var cards: Array[String] = []
	for id: String in _run.upgrade_ids:
		var card: UpgradeDef = _run.upgrades[id]
		if card.layer == UpgradeDef.Layer.APEX and _content.paths[_content.apexes[card.apex].path].hero == "lucan":
			cards.append(id)
			assert_true(_run.changes_something(card, true, _content.apexes[card.apex].apex_kit), id)
	assert_eq(cards.size(), 12, "2 an apex")
	var faces: UnitDef = _content.apexes["thousand_faces"].apex_kit
	assert_eq(_effect(_with("perfect_likeness", faces, true), "reflection").copy_grows_bp, _effect(faces, "reflection").copy_grows_bp + 100, "+1% a copy")
	assert_eq(_with("long_strings", _content.apexes["marionette"].apex_kit, true).signature.effects[0].duration_ticks,
		_content.apexes["marionette"].apex_kit.signature.effects[0].duration_ticks + 2 * 20)
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["perfect_likeness"], faces, _content), "Reflection: +1% of the stats each later copy takes, for each copy made")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["mirror_guard"], _content.apexes["true_reflection"].apex_kit, _content), "Signature: Shield of 15% of max HP to all allies")
	assert_eq(ModInfo.upgrade_numbers(_run.upgrades["longer_night"], _content.apexes["night_veil"].apex_kit, _content), "Night Veil: +1s duration")
