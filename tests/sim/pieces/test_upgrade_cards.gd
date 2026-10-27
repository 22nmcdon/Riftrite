extends GutTest
## The upgrade cards phase 5c step 7a writes from built pieces, in small
## fights on the real kits (docs/plans/rebuild-phase5c-combos.md, section
## 15.7): the four statuses they add (Hobbled, Cowed, and the two next-hit
## boosts), and a taste card's transformed mod reaching its new piece.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


## `path_id`'s vowed (or transformed) kit with `cards`' mods.
func _kit(path_id: String, cards: Array[String], transformed: bool = false) -> UnitDef:
	var path: PathDef = _run.content.paths[path_id]
	var kit: UnitDef = path.transformed_kit if transformed else path.vowed_kit
	for id: String in cards:
		var problems: Array[String] = []
		kit = _run.upgrades[id].mod_for(transformed).apply(kit, problems)
		assert_eq(problems, [] as Array[String])
	return kit


func _dummy(hp: int = 100000, speed: int = 0) -> UnitDef:
	return K.kit("dummy", {"stats": {"hp": hp, "speed": speed, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})


func _applied(fight: CombatSim, status_id: String) -> Array[LogEntry]:
	return K.entries(fight, LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.status == status_id)


func test_first_blood_doubles_the_first_attack() -> void:
	var maren: UnitDef = _kit("deadeye", ["first_blood"] as Array[String])
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(maren, K.HEROES, 3, 1, "maren")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup], [], 3))
	fight.step()
	assert_eq(_applied(fight, "first_blood").size(), 1, "on at the fight's start")
	K.step(fight, 80)
	var hits: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "maren").filter(func(entry: LogEntry) -> bool: return not entry.crit)
	assert_gt(hits.size(), 1)
	assert_eq(hits[0].amount, 2 * hits[1].amount, "the first hit twice the next")
	assert_null(Statuses.find(fight.unit_by_id("maren"), "first_blood"), "and gone once she attacks")


func test_parting_shot_crits_after_a_hop() -> void:
	var maren: UnitDef = _kit("deadeye", ["parting_shot"] as Array[String])
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(maren, K.HEROES, 3, 1, "maren")] as Array[UnitSetup], [K.foe(_dummy(100000, 3), 3, 4)] as Array[UnitSetup], [], 3))
	K.step(fight, 200)
	var applied: Array[LogEntry] = _applied(fight, "parting_shot")
	assert_false(applied.is_empty(), "she hopped, and it went on")
	var after: Array[LogEntry] = K.entries(fight, LogEntry.Kind.DAMAGE, "maren").filter(func(entry: LogEntry) -> bool: return entry.tick > applied[0].tick)
	assert_false(after.is_empty())
	assert_true(after[0].crit, "her next hit crits")


func test_stubborn_taunt_cows_who_he_taunts() -> void:
	var brannoc: UnitDef = _kit("hearthwall", ["stubborn_taunt"] as Array[String])
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(brannoc, K.HEROES, 3, 2, "brannoc")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	var unit: UnitState = fight.unit_by_id("brannoc")
	K.step(fight, 40)
	unit.mana = unit.mana_cap
	K.step(fight, 5)
	assert_false(_applied(fight, "taunt").is_empty(), "Hold the Line taunts")
	assert_false(_applied(fight, "cowed").is_empty(), "and the taunted are Cowed")
	assert_not_null(Statuses.find(fight.unit_by_id("dummy"), "cowed"))


func test_staggering_bash_hobbles_every_fourth() -> void:
	var brannoc: UnitDef = _kit("hearthwall", ["staggering_bash"] as Array[String])
	var fight: CombatSim = K.sim(K.fight([UnitSetup.make(brannoc, K.HEROES, 3, 2, "brannoc")] as Array[UnitSetup], [K.foe(_dummy(), 3, 4)] as Array[UnitSetup]))
	K.step(fight, 400)
	var bashes: int = K.entries(fight, LogEntry.Kind.DAMAGE, "brannoc").size()
	assert_gt(bashes, 7)
	assert_eq(_applied(fight, "hobbled").size(), bashes / 4, "one in four of %d bashes" % bashes)


func test_a_taste_card_reaches_its_transformed_piece() -> void:
	# Burning Judgment: the vowed signature's smite, then transformed Mend's.
	var vowed: UnitDef = _kit("vigil_keeper", ["burning_judgment"] as Array[String])
	var smite: EffectDef = vowed.signature.effects[1]
	assert_eq(smite.power_bp, 5000, "+50% on the vowed smite")
	var transformed: UnitDef = _kit("vigil_keeper", ["burning_judgment"] as Array[String], true)
	var mend: PartDef = transformed.passives.filter(func(part: PartDef) -> bool: return part.id == "mend")[0]
	var damages: Array = mend.ability.effects.filter(func(effect: EffectDef) -> bool: return effect.type == EffectDef.Type.DAMAGE)
	assert_eq((damages[0] as EffectDef).power_bp, 5000, "and on Mend's smite once transformed")
	assert_eq(transformed.signature.effects[0].area_effects[0].power_bp, 0, "never on Sunfall")
