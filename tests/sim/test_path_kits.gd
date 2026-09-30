extends GutTest
## The nine paths as data (docs/plans/rebuild-phase4-paths.md, section 4):
## each hero's three, in the design's order; every ability's sentence names
## its reaches and has a numbers line; each path's kits carry what its texts
## say; and each taste fills its deed where the base kit barely does.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


func _kit(path_id: String, stage: PathDef.Stage) -> UnitDef:
	var path: PathDef = _content.paths[path_id]
	return path.kit(stage, _content.heroes[path.hero].kit)


func _has_part(kit: UnitDef, part_id: String) -> bool:
	return kit.passives.any(func(part: PartDef) -> bool: return part.id == part_id)


func test_each_hero_has_its_three_paths() -> void:
	var names: Dictionary = {}
	for hero_id: String in _content.hero_ids:
		names[hero_id] = _content.heroes[hero_id].paths.map(func(path: PathDef) -> String: return path.name)
	assert_eq(names, {"brannoc": ["Hearthwall", "Ironbrand", "Last Watch"], "maren": ["Deadeye", "Trapper", "Volley"],
		"vell": ["Lanternbearer", "Wardweaver", "Vigil Keeper"]})
	for path_id: String in _content.path_ids:
		var path: PathDef = _content.paths[path_id]
		for text: String in [path.title, path.fantasy, path.placement, path.taste, path.vowed_cost, path.transformed_text, path.transformed_cost, path.deed.text]:
			assert_false(text.is_empty(), "%s has all its texts" % path_id)
		assert_true(FileAccess.file_exists("res://art/figures/heroes/%s_%s.svg" % [path.hero, path_id]), "%s has its transformed figure" % path_id)


func test_every_ability_names_its_reaches_and_numbers() -> void:
	var checked: int = 0
	for path_id: String in _content.path_ids:
		for stage: PathDef.Stage in [PathDef.Stage.VOWED, PathDef.Stage.TRANSFORMED]:
			var kit: UnitDef = _kit(path_id, stage)
			var where: String = "%s (%s)" % [path_id, PathDef.STAGE_NAMES[stage]]
			var abilities: Array[AbilityDef] = [kit.basic_attack, kit.signature]
			for part: PartDef in kit.passives:
				assert_false(part.text.is_empty(), "%s: %s has its sentence" % [where, part.id])
				if part.ability != null:
					abilities.append(part.ability)
			for ability: AbilityDef in abilities:
				if ability == null:
					continue
				var text: String = ability.text
				if text.is_empty():
					for part: PartDef in kit.passives:
						if part.ability == ability:
							text = part.text
				assert_false(text.is_empty(), "%s: %s has its sentence" % [where, ability.id])
				for reach: int in UnitInfo.reaches(ability, kit):
					assert_not_null(RegEx.create_from_string("\\b%d hex" % reach).search(text), "%s: %s names %s: %s" % [where, ability.id, UnitInfo.hexes(reach), text])
					checked += 1
			for line: UnitInfo.Line in UnitInfo.lines(kit, "it", _content):
				assert_false(line.numbers.is_empty() and line.kind != "Trait", "%s: %s has a numbers line" % [where, line.name])
	assert_gt(checked, 40)


func test_the_kits_carry_what_the_texts_say() -> void:
	var vowed: PathDef.Stage = PathDef.Stage.VOWED
	var done: PathDef.Stage = PathDef.Stage.TRANSFORMED
	# Deadeye: Steady and slower shots; planted range, Heartseeker, the plant delay, far mana.
	assert_true(_has_part(_kit("deadeye", vowed), "steady") and _has_part(_kit("deadeye", vowed), "unsteady"))
	var deadeye: UnitDef = _kit("deadeye", done)
	assert_eq([deadeye.signature.id, deadeye.plant_ticks, deadeye.mana.far_hexes, deadeye.signature.cast_ticks], ["heartseeker", 30, 5, 16])
	assert_true(_has_part(deadeye, "planted") and not _has_part(deadeye, "steady"), "the transformation replaces the taste")
	# Trapper: a once-a-fight snare; Bramble Field, 2 placed snares, range 3.
	assert_true(_has_part(_kit("trapper", vowed), "snare"))
	var trapper: UnitDef = _kit("trapper", done)
	assert_eq([trapper.signature.id, trapper.placed_snares, trapper.stats.get_stat(UnitStats.Stat.RANGE)], ["bramble_field", 2, 3])
	assert_eq(Snares.placed_effect(trapper).max_standing, 3)
	# Volley: every 6th shot splits, range 3; every shot, fires moving, Arrow Storm.
	assert_eq(_kit("volley", vowed).basic_attack.effects[1].every, 6)
	assert_eq(_kit("volley", vowed).stats.get_stat(UnitStats.Stat.RANGE), 3)
	var volley: UnitDef = _kit("volley", done)
	assert_eq([volley.basic_attack.effects[1].every, volley.has_trait("fires_moving"), volley.signature.id], [1, true, "arrow_storm"])
	assert_gt(volley.signature.effects[0].zone_ticks, 0)
	# Hearthwall: Guard behind; Guard all round, the wall, slower, no taunting DEF.
	var guard: PartDef = _kit("hearthwall", vowed).passives.filter(func(part: PartDef) -> bool: return part.kind == PartDef.Kind.GUARD)[0]
	assert_eq([guard.share_bp, guard.guard_range, guard.behind_only], [1000, 3000, true])
	var hearthwall: UnitDef = _kit("hearthwall", done)
	assert_eq([hearthwall.signature.id, hearthwall.stats.get_stat(UnitStats.Stat.SPEED), _has_part(hearthwall, "hold_the_line_guard")], ["hearthwall", 1, false])
	# Ironbrand: Brand; the Mace and Brand Slam.
	assert_eq(_kit("ironbrand", vowed).basic_attack.effects[1].target, EffectDef.Target.ENEMY_NEAR_TARGET)
	var ironbrand: UnitDef = _kit("ironbrand", done)
	assert_eq([ironbrand.basic_attack.id, ironbrand.signature.id, ironbrand.signature.targeting], ["hearthbrand_mace", "brand_slam", "largest_group"])
	# Last Watch: Unyielding; Last Rites on HP, no mana, the low-HP auras.
	assert_eq(_kit("last_watch", vowed).passives.back().ability.effects[0].trigger, EffectDef.Trigger.ON_WOULD_FALL)
	var last_watch: UnitDef = _kit("last_watch", done)
	assert_eq([last_watch.signature.id, last_watch.signature.trigger.kind, last_watch.mana], ["last_rites", TriggerDef.Kind.HP_BELOW, null])
	for part_id: String in ["last_stand", "last_wall", "grief", "scarred"]:
		assert_true(_has_part(last_watch, part_id), part_id)
	# Vell: Kindle, Ward Thread, Judgment (every 2nd Mend); Night Lantern, Warding Circle, Sunfall, with Mend (or Weave) every 4th Lantern Glow.
	assert_eq(_kit("lanternbearer", vowed).signature.effects[1].target, EffectDef.Target.ALLY_NEAR_TARGET)
	assert_eq(_kit("wardweaver", vowed).signature.effects[0].overheal_shield_bp, 2000)
	assert_eq(_kit("vigil_keeper", vowed).signature.effects[1].every, 2)
	assert_eq(_kit("vigil_keeper", vowed).signature.max_range, 2)
	for pair: Array in [["lanternbearer", "night_lantern", "mend"], ["wardweaver", "warding_circle", "weave"], ["vigil_keeper", "sunfall", "mend"]]:
		var kit: UnitDef = _kit(pair[0], done)
		assert_eq(kit.signature.id, pair[1])
		assert_true(_has_part(kit, pair[2]), "%s: %s every 4th Lantern Glow" % [pair[0], pair[2]])


func test_wait_to_heal_fits_every_healing_signature() -> void:
	var wait: TacticDef = _content.tactics["wait_to_heal"]
	for path_id: String in ["lanternbearer", "wardweaver", "vigil_keeper"]:
		assert_true(Tactics.can_wait(_kit(path_id, PathDef.Stage.VOWED).signature), "%s vowed" % path_id)
	assert_true(Tactics.can_wait(_kit("lanternbearer", PathDef.Stage.TRANSFORMED).signature), "Night Lantern heals")
	assert_true(Tactics.can_wait(_kit("vigil_keeper", PathDef.Stage.TRANSFORMED).signature), "Sunfall heals")
	assert_false(Tactics.can_wait(_kit("wardweaver", PathDef.Stage.TRANSFORMED).signature), "Warding Circle doesn't (Decision 7)")
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(2, 1)}
	var fight: FightSetup = Encounters.setup(_content, "witch_circle", formation, 1, errors, {"vell": "wait_to_heal"} as Dictionary[String, String],
		{"vell": "wardweaver"} as Dictionary[String, String], ["vell"] as Array[String])
	assert_eq(fight.validate(_content), ["vell at (2, 1) can't take the tactic %s" % wait.name] as Array[String])


## Where each taste fills its deed and the base kit doesn't (the deed report
## measures it everywhere).
const TASTE_FIGHTS: Dictionary[String, Array] = {
	"deadeye": ["hollow_line", Vector2i(0, 0)],
	"trapper": ["the_pack", Vector2i(3, 0)],
	"volley": ["the_pack", Vector2i(3, 0)],
	"hearthwall": ["the_pack", Vector2i(3, 0)],
	"ironbrand": ["the_pack", Vector2i(3, 0)],
	"lanternbearer": ["the_pack", Vector2i(3, 0)],
	"wardweaver": ["hollow_line", Vector2i(3, 0)],
	"vigil_keeper": ["hollow_line", Vector2i(3, 0)],
}


func test_each_taste_fills_its_deed_where_the_base_kit_doesnt() -> void:
	for path_id: String in TASTE_FIGHTS:
		var path: PathDef = _content.paths[path_id]
		var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": TASTE_FIGHTS[path_id][1], "vell": Vector2i(2, 1)}
		var amounts: Array[int] = []
		for vowed: bool in [false, true]:
			var vows: Dictionary[String, String] = {}
			if vowed:
				vows[path.hero] = path_id
			var errors: Array[String] = []
			var setup: FightSetup = Encounters.setup(_content, TASTE_FIGHTS[path_id][0], formation, 3, errors, {}, vows)
			amounts.append(CombatSim.run(setup, _content).deed_amount(path.hero, path_id))
		assert_eq(amounts[0], 0, "%s: the base kit can't fill it" % path_id)
		assert_gt(amounts[1], 0, "%s: the taste does" % path_id)
