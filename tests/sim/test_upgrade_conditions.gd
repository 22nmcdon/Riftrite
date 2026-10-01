extends GutTest
## The upgrade pools' new conditions and filters (docs/plans/
## rebuild-phase5c-combos.md, step 7c, section 15.7), each on its real card
## in a small fight: heal and Shield bonuses on some allies (Urgent Mercy,
## Front Ward and front_most), a per-hit reach (Close Quarters), auras while
## moved and crowded (Restless, Crowd Sense) or on the allies near (Sanctuary),
## an event's holder condition (Scar Tissue, Bloody Kills), on_holder_crit's
## reach (Bleeding Shot), on_kill off its target (Glutton's Quiver), once per
## ally (Vigilant), on_heal's ability and HP (Cleansing Touch, Last-Minute
## Mercy), a cleanse's count, and a stronger Mark (Heavy Mark).

const K = preload("res://tests/sim/sim_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


## A kit for the hero `path_id` is on, with `cards`' mods.
func _kit(path_id: String, cards: Array[String], transformed: bool = false) -> UnitDef:
	var path: PathDef = _run.content.paths[path_id]
	var kit: UnitDef = path.transformed_kit if transformed else path.vowed_kit
	for card: String in cards:
		var problems: Array[String] = []
		kit = _run.upgrades[card].mod_for(transformed).apply(kit, problems)
		assert_eq(problems, [] as Array[String])
	return kit


func _dummy(dummy_id: String = "dummy", hp: int = 1000) -> UnitDef:
	return K.kit(dummy_id, {"stats": {"hp": hp, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


## A fight of `hero` (as `hero_id`) with allies and foes (ids -> hexes),
## stepped once so its auras are in.
func _fight(hero: UnitDef, hero_id: String, allies: Dictionary = {}, foes: Dictionary = {"foe": Vector2i(3, 5)}) -> CombatSim:
	var heroes: Array[UnitSetup] = [UnitSetup.make(hero, K.HEROES, 3, 1, hero_id)]
	for ally_id: String in allies:
		heroes.append(K.at(_dummy(ally_id), allies[ally_id].x, allies[ally_id].y, ally_id))
	var enemies: Array[UnitSetup] = []
	for foe_id: String in foes:
		enemies.append(K.foe(_dummy(foe_id, 100000), foes[foe_id].x, foes[foe_id].y, foe_id))
	var fight: CombatSim = K.sim(K.fight(heroes, enemies))
	fight.step()
	return fight


func _source(unit_id: String, ability_id: String) -> EffectSource:
	return EffectSource.make(unit_id, ability_id, ability_id.capitalize())


func _effect(data: Dictionary) -> EffectDef:
	var errors: Array[String] = []
	var effect: EffectDef = EffectDef.read(DataReader.new(data, "effect", errors))
	assert_eq(errors, [] as Array[String])
	return effect


func _amounts(fight: CombatSim, kind: LogEntry.Kind) -> Array:
	return K.entries(fight, kind).map(func(entry: LogEntry) -> int: return entry.amount)


func test_urgent_mercy_heals_the_low_more() -> void:
	var fight: CombatSim = _fight(_kit("lanternbearer", ["urgent_mercy"] as Array[String]), "vell", {"low": Vector2i(2, 1), "high": Vector2i(4, 1)})
	var vell: UnitState = fight.unit_by_id("vell")
	fight.unit_by_id("low").hp = 200
	fight.unit_by_id("high").hp = 500
	var heal: EffectDef = _effect({"type": "heal", "amount": 100, "target": "target"})
	for ally_id: String in ["low", "high"]:
		EffectRunner.land(fight, vell, vell.def.signature, _source("vell", "mend"), heal, fight.unit_by_id(ally_id), 100, false)
	assert_eq(_amounts(fight, LogEntry.Kind.HEAL), [125, 100], "+25% below 30% HP only")


func test_front_ward_shields_the_front_most_more() -> void:
	var fight: CombatSim = _fight(_kit("wardweaver", ["front_ward"] as Array[String], true), "vell", {"front": Vector2i(3, 2), "back": Vector2i(2, 0)})
	assert_true(fight.track_front)
	assert_true(fight.unit_by_id("front").front_most, "the hero nearest the enemies")
	assert_false(fight.unit_by_id("vell").front_most)
	var vell: UnitState = fight.unit_by_id("vell")
	var shield: EffectDef = _effect({"type": "shield", "amount": 100, "target": "target"})
	for ally_id: String in ["front", "back"]:
		EffectRunner.land(fight, vell, vell.def.basic_attack, _source("vell", "weave"), shield, fight.unit_by_id(ally_id), 100, false)
	assert_eq(_amounts(fight, LogEntry.Kind.SHIELD), [150, 100])
	assert_false(_fight(_run.content.paths["wardweaver"].transformed_kit, "vell").track_front, "a fight without it never marks")


func test_close_quarters_only_up_close() -> void:
	var fight: CombatSim = _fight(_kit("deadeye", ["close_quarters"] as Array[String]), "maren", {}, {"near": Vector2i(3, 4), "far": Vector2i(6, 6)})
	var maren: UnitState = fight.unit_by_id("maren")
	fight.unit_by_id("near").pos = maren.pos + Vector2i(0, 900)
	var near: int = EffectRunner.deal_hit(fight, _source("maren", "longshot"), fight.unit_by_id("near"), 100, false)
	var far: int = EffectRunner.deal_hit(fight, _source("maren", "longshot"), fight.unit_by_id("far"), 100, false)
	assert_eq(near * 100, far * 120, "+20%% within 1 hex: %d and %d" % [near, far])


func test_restless_and_crowd_sense() -> void:
	var fight: CombatSim = _fight(_kit("volley", ["restless"] as Array[String]), "maren")
	var maren: UnitState = fight.unit_by_id("maren")
	var base: int = maren.def.stats.get_stat(UnitStats.Stat.ATSP)
	maren.moved_at = fight.tick
	fight.check_conditional_auras()
	assert_eq(maren.stats.get_stat(UnitStats.Stat.ATSP), base + 10, "just moved")
	maren.moved_at = fight.tick - 41
	fight.check_conditional_auras()
	assert_eq(maren.stats.get_stat(UnitStats.Stat.ATSP), base, "off 2s after")
	maren.moved_at = UnitState.NEVER_MOVED
	fight.check_conditional_auras()
	assert_eq(maren.stats.get_stat(UnitStats.Stat.ATSP), base, "never moved: off")
	var crowd: CombatSim = _fight(_kit("ironbrand", ["crowd_sense"] as Array[String]), "brannoc", {}, {"a": Vector2i(2, 5), "b": Vector2i(4, 5)})
	var brannoc: UnitState = crowd.unit_by_id("brannoc")
	var alone: int = brannoc.stats.get_stat(UnitStats.Stat.ATK)
	crowd.unit_by_id("a").pos = brannoc.pos + Vector2i(800, 0)
	crowd.unit_by_id("b").pos = brannoc.pos + Vector2i(-800, 0)
	crowd.check_conditional_auras()
	assert_eq(brannoc.stats.get_stat(UnitStats.Stat.ATK), FixedMath.apply_bp(alone, 11000), "two enemies within 1 hex")


func test_sanctuary_on_the_allies_near() -> void:
	var fight: CombatSim = _fight(_kit("lanternbearer", ["sanctuary"] as Array[String]), "vell", {"near": Vector2i(2, 1), "far": Vector2i(6, 0)})
	var vell: UnitState = fight.unit_by_id("vell")
	fight.unit_by_id("near").pos = vell.pos + Vector2i(900, 0)
	fight.step()
	assert_eq(fight.unit_by_id("near").aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 500)
	assert_eq(fight.unit_by_id("far").aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 0)
	assert_eq(vell.aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 0, "not herself")
	fight.unit_by_id("near").pos = vell.pos + Vector2i(3000, 0)
	fight.step()
	assert_eq(fight.unit_by_id("near").aura_bp[AuraDef.Stat.DAMAGE_REDUCED_BP], 0, "gone once it walks off")


func test_a_holder_condition() -> void:
	var fight: CombatSim = _fight(_kit("last_watch", ["scar_tissue", "bloody_kills"] as Array[String], true), "brannoc", {}, {"foe": Vector2i(3, 5)})
	var brannoc: UnitState = fight.unit_by_id("brannoc")
	K.step(fight, 40)
	assert_null(Statuses.find(brannoc, "scarred"), "at full HP, nothing")
	brannoc.hp = brannoc.max_hp / 5
	K.step(fight, 41)
	assert_eq(Statuses.find(brannoc, "scarred").timed_stacks(), 2, "a stack a second below 30%")
	var weak: CombatSim = _fight(_kit("last_watch", ["bloody_kills"] as Array[String], true), "brannoc", {}, {"weak": Vector2i(3, 5)})
	var low: UnitState = weak.unit_by_id("brannoc")
	low.hp = low.max_hp / 5
	weak.unit_by_id("weak").hp = 1
	EffectRunner.deal_hit(weak, _source("brannoc", "shield_bash"), weak.unit_by_id("weak"), 100, false)
	weak.step()
	assert_eq(K.entries(weak, LogEntry.Kind.HEAL, "brannoc").size(), 1, "a kill below 30% heals him")


func test_bleeding_shot_and_gluttons_quiver() -> void:
	var fight: CombatSim = _fight(_kit("deadeye", ["bleeding_shot"] as Array[String], true), "maren", {}, {"near": Vector2i(3, 4), "far": Vector2i(3, 6)})
	var maren: UnitState = fight.unit_by_id("maren")
	fight.unit_by_id("far").pos = maren.pos + Vector2i(0, 5500)
	for foe_id: String in ["near", "far"]:
		EffectRunner.deal_hit(fight, _source("maren", "longshot"), fight.unit_by_id(foe_id), 10, true)
	fight.step()
	assert_null(Statuses.find(fight.unit_by_id("near"), "bleed"))
	assert_eq(Statuses.find(fight.unit_by_id("far"), "bleed").total_stacks(), 3, "a crit from beyond 5 hexes")
	var volley: CombatSim = _fight(_kit("volley", ["gluttons_quiver"] as Array[String], true), "maren", {}, {"aimed": Vector2i(3, 4), "split": Vector2i(4, 4), "other": Vector2i(1, 6)})
	var archer: UnitState = volley.unit_by_id("maren")
	archer.target = volley.unit_by_id("aimed")
	for foe_id: String in ["aimed", "split"]:
		volley.unit_by_id(foe_id).hp = 1
	var mana: int = archer.mana
	EffectRunner.deal_hit(volley, _source("maren", "longshot"), volley.unit_by_id("aimed"), 100, false)
	volley.step()
	assert_lt(archer.mana - mana, Mana.SCALE, "a kill on her target: nothing (regen aside)")
	archer.target = volley.unit_by_id("other")
	mana = archer.mana
	EffectRunner.deal_hit(volley, _source("maren", "longshot"), volley.unit_by_id("split"), 100, false)
	volley.step()
	assert_gte(archer.mana - mana, 10 * Mana.SCALE, "a split arrow's kill: +10 mana")


func test_vigilant_once_per_ally() -> void:
	var fight: CombatSim = _fight(_kit("lanternbearer", ["vigilant"] as Array[String]), "vell", {"a": Vector2i(2, 1), "b": Vector2i(4, 1)})
	var vell: UnitState = fight.unit_by_id("vell")
	var gains: Array[int] = []
	for ally_id: String in ["a", "a", "b"]:
		var mana: int = vell.mana
		fight.unit_by_id(ally_id).hp = 400
		fight.step()
		gains.append((vell.mana - mana) / Mana.SCALE)
		fight.unit_by_id(ally_id).hp = 1000
		fight.step()
	assert_true(gains[0] >= 20 and gains[1] < 20 and gains[2] >= 20, "each ally once: %s" % [gains])


func test_on_heal_by_ability_and_hp() -> void:
	var fight: CombatSim = _fight(_kit("lanternbearer", ["cleansing_touch", "last_minute_mercy"] as Array[String], true), "vell", {"ally": Vector2i(2, 1)})
	var vell: UnitState = fight.unit_by_id("vell")
	var ally: UnitState = fight.unit_by_id("ally")
	Statuses.apply(fight, ally, "root", 1, 100, _source("foe", "foe_attack"))
	fight.step()
	Statuses.apply(fight, ally, "slow", 1, 100, _source("foe", "foe_attack"))
	ally.hp = 200
	var mana: int = vell.mana
	EffectRunner.heal(fight, ally, 50, _source("vell", "hearthlight"))
	fight.step()
	assert_not_null(Statuses.find(ally, "slow"), "Hearthlight's heal cleanses nothing")
	EffectRunner.heal(fight, ally, 50, _source("vell", "mend"))
	fight.step()
	assert_null(Statuses.find(ally, "slow"), "Mend's takes the newest")
	assert_not_null(Statuses.find(ally, "root"), "only one")
	assert_eq((vell.mana - mana) / Mana.SCALE >= 20, true, "Mend on an ally below 30%: +20 mana")
	mana = vell.mana
	ally.hp = 600
	EffectRunner.heal(fight, ally, 50, _source("vell", "mend"))
	fight.step()
	assert_lt((vell.mana - mana) / Mana.SCALE, 20, "above 30%: no refund")


func test_heavy_mark_is_stronger() -> void:
	var maren: UnitDef = _kit("deadeye", ["heavy_mark"] as Array[String])
	assert_eq(maren.signature.effects[0].strength_add_bp, 500)
	var fight: CombatSim = _fight(maren, "maren")
	var foe: UnitState = fight.unit_by_id("foe")
	Statuses.apply(fight, foe, "marked", 1, 80, _source("maren", "marking_shot"), false, 0, 500)
	assert_eq(Statuses.damage_taken_bp(foe), 2000, "20%, not 15%")
	Statuses.apply(fight, foe, "marked", 1, 80, _source("ally", "x"))
	assert_eq(Statuses.damage_taken_bp(foe), 2000, "a plain Mark doesn't weaken it")
