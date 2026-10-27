extends GutTest
## Kit modifiers and wounds (docs/plans/rebuild-phase5-run.md, section 7):
## each change on each slot, what a mod affects, that the content it reads
## is never changed, and that a fight takes them through Encounters.setup.

const K = preload("res://tests/sim/sim_test_kit.gd")
const GUARDED: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


static func mod(data: Dictionary) -> KitMod:
	var errors: Array[String] = []
	var made: KitMod = KitMod.read(DataReader.new(data, "mod", errors))
	assert(errors.is_empty(), str(errors))
	return made


static func mod_errors(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	KitMod.read(DataReader.new(data, "mod", errors))
	return errors


func _kit(hero_id: String) -> UnitDef:
	return _content.heroes[hero_id].kit


func test_stats_multiply_then_add() -> void:
	var brannoc: UnitDef = _kit("brannoc")
	var built: UnitDef = mod({"stats_bp": {"hp": 11000}, "stats_add": {"range": 1}}).apply(brannoc)
	assert_eq(built.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(brannoc.stats.get_stat(UnitStats.Stat.HP), 11000))
	assert_eq(built.stats.get_stat(UnitStats.Stat.RANGE), brannoc.stats.get_stat(UnitStats.Stat.RANGE) + 1)
	assert_eq(brannoc.stats.get_stat(UnitStats.Stat.RANGE), 1, "the content's kit is untouched")
	var problems: Array[String] = []
	mod({"stats_add": {"range": -3}}).apply(brannoc, problems)
	assert_eq(problems, ["its range would drop below 1"] as Array[String])


func test_a_signatures_heals_scale_nested_ones_too() -> void:
	var lantern: UnitDef = _content.paths["lanternbearer"].transformed_kit
	var deeper: KitMod = mod({"on": [{"slot": "signature", "types": ["heal"], "amount_bp": 12000}]})
	var built: UnitDef = deeper.apply(lantern)
	var before: EffectDef = lantern.signature.effects[0].area_effects[0]
	var after: EffectDef = built.signature.effects[0].area_effects[0]
	assert_eq([after.amount, after.scaling[UnitStats.Stat.MGK], after.power_bp], [before.amount, before.scaling[UnitStats.Stat.MGK], before.power_bp + 2000], "the lantern's heal, inside its area, gets +20% power (the damage rule, phase 5c Decision 6)")
	assert_eq(built.signature.effects[0].area_effects[1].type, EffectDef.Type.CLEANSE, "the cleanse beside it isn't a heal")
	assert_eq(lantern.signature.effects[0].area_effects[0].amount, before.amount, "the path's kit is untouched")
	assert_eq(built.basic_attack, lantern.basic_attack, "other slots are the same objects")
	assert_true(deeper.affects(lantern))
	assert_false(deeper.affects(_kit("brannoc")), "Brannoc's signature has no heal")


func test_durations_radius_and_cooldown() -> void:
	var wall: UnitDef = _content.paths["hearthwall"].transformed_kit
	var longer: UnitDef = mod({"on": [{"slot": "signature", "types": ["wall"], "duration_add_ms": 2000}]}).apply(wall)
	assert_eq(longer.signature.effects[0].zone_ticks, wall.signature.effects[0].zone_ticks + 40, "the wall stands 2s longer")
	var circle: UnitDef = _content.paths["wardweaver"].transformed_kit
	var wider: UnitDef = mod({"on": [{"slot": "signature", "radius_add": 1}]}).apply(circle)
	assert_eq(wider.signature.effects[0].shape.size, circle.signature.effects[0].shape.size + 1)
	var maren: UnitDef = _kit("maren")
	var quicker: UnitDef = mod({"on": [{"slot": "basic_attack", "cooldown_bp": 9000}]}).apply(maren)
	assert_eq(quicker.basic_attack.cooldown_ticks, FixedMath.apply_bp(maren.basic_attack.cooldown_ticks, 9000))


func test_added_effects_and_passives() -> void:
	var maren: UnitDef = _kit("maren")
	var slowing: KitMod = mod({"on": [{"slot": "basic_attack", "add_effects": [{"trigger": "on_crit", "type": "apply_status", "status": "slow", "duration_ms": 1000, "target": "target"}]}]})
	var built: UnitDef = slowing.apply(maren)
	assert_eq(built.basic_attack.effects.size(), maren.basic_attack.effects.size() + 1)
	assert_true(built.basic_attack.has_hit_effects, "an on_crit effect is a hit effect")
	var watch: KitMod = mod({"passives": [{"id": "watchful", "name": "Watchful", "kind": "aura", "aura": {"target": "holder", "stat": "def_bp", "value": 11000}}]})
	assert_eq(watch.apply(maren).passives.back().id, "watchful")
	var problems: Array[String] = []
	var twice: UnitDef = watch.apply(watch.apply(maren), problems)
	assert_has(problems, "it already has a passive \"watchful\"", "the same passive twice is a problem")
	assert_not_null(twice)


func test_a_passive_by_id_and_its_aura() -> void:
	var deadeye: UnitDef = _content.paths["deadeye"].vowed_kit
	var steadier: KitMod = mod({"on": [{"slot": "passive:steady", "after_add_ms": -500}]})
	var built: UnitDef = steadier.apply(deadeye)
	var steady: PartDef = built.passives.filter(func(part: PartDef) -> bool: return part.id == "steady")[0]
	var original: PartDef = deadeye.passives.filter(func(part: PartDef) -> bool: return part.id == "steady")[0]
	assert_eq(steady.aura.after_ticks, original.aura.after_ticks - 10)
	assert_true(steadier.affects(deadeye))
	assert_false(steadier.affects(_kit("maren")), "base Maren has no Steady")
	var problems: Array[String] = []
	steadier.apply(_kit("maren"), problems)
	assert_eq(problems, ["it has no passive \"steady\""] as Array[String])


func test_mana_changes_only_a_kit_with_a_bar() -> void:
	var cheaper: KitMod = mod({"mana": {"max_add": -15}})
	var maren: UnitDef = _kit("maren")
	assert_eq(cheaper.apply(maren).mana.max, maren.mana.max - 15)
	var last_watch: UnitDef = _content.paths["last_watch"].transformed_kit
	assert_null(last_watch.mana)
	assert_false(cheaper.affects(last_watch), "no effect on a hero without mana")
	assert_null(cheaper.apply(last_watch).mana)


func test_bad_mods_are_refused() -> void:
	assert_string_contains(mod_errors({})[0], "a mod needs")
	assert_string_contains(mod_errors({"on": [{"slot": "mend", "amount_bp": 12000}]})[0], "slot: expected")
	assert_string_contains(mod_errors({"on": [{"slot": "signature"}]})[0], "an \"on\" entry needs")
	assert_string_contains(mod_errors({"on": [{"slot": "signature", "duration_add_ms": 30}]})[0], "multiple of 50")


func test_a_fight_takes_mods_and_wounds() -> void:
	var errors: Array[String] = []
	var tougher: KitMod = mod({"stats_bp": {"hp": 12000}})
	var extras: Dictionary[String, HeroExtras] = {"brannoc": HeroExtras.make([tougher] as Array[KitMod], 2)}
	var fight: FightSetup = Encounters.setup(_content, "the_pack", GUARDED, 1, errors, {}, {}, [], extras)
	assert_eq(errors, [] as Array[String])
	assert_eq(fight.validate(_content), [] as Array[String])
	var brannoc: UnitSetup = fight.heroes[0]
	assert_eq(brannoc.def.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(_kit("brannoc").stats.get_stat(UnitStats.Stat.HP), 12000))
	assert_eq(brannoc.max_hp_bp, 7000, "two wounds: 30% off")
	var sim := CombatSim.new(fight, _content)
	assert_eq(sim.unit_by_id("brannoc").max_hp, FixedMath.apply_bp(brannoc.def.stats.get_stat(UnitStats.Stat.HP), 7000))
	assert_eq(sim.unit_by_id("brannoc").hp, sim.unit_by_id("brannoc").max_hp, "a fight starts at full current max HP")
	var plain: FightSetup = Encounters.setup(_content, "the_pack", GUARDED, 1, errors)
	assert_eq(plain.heroes[0].max_hp_bp, FixedMath.BP_ONE)
	assert_eq(CombatSim.run(plain, _content).combat_log.to_text(), CombatSim.run(Encounters.setup(_content, "the_pack", GUARDED, 1, errors, {}, {}, [], {}), _content).combat_log.to_text(),
		"no extras is the same fight")
	var too_many: Dictionary[String, HeroExtras] = {"vell": HeroExtras.make([], 4)}
	var refused: Array[String] = []
	assert_null(Encounters.setup(_content, "the_pack", GUARDED, 1, refused, {}, {}, [], too_many))
	assert_eq(refused, ["vell can't have 4 wounds"] as Array[String])
	var broken: Array[String] = []
	var unsound: Dictionary[String, HeroExtras] = {"maren": HeroExtras.make([mod({"stats_add": {"range": -5}})] as Array[KitMod])}
	assert_null(Encounters.setup(_content, "the_pack", GUARDED, 1, broken, {}, {}, [], unsound))
	assert_eq(broken, ["maren: a modifier leaves it unsound: its range would drop below 1"] as Array[String])
	fight.heroes[0].max_hp_bp = 500
	assert_eq(fight.validate(_content), ["brannoc at (3, 2) has max HP at 5% of its kit's (10% to 100%)"] as Array[String])
