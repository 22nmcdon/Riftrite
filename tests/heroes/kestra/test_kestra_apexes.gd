extends GutTest
## Kestra's six apexes (phase 8 part 6, docs/plans/phases/rebuild-phase8-last-heroes.md
## 8f-3; apexes.md) in real fights: each loads on its path's transformed kit
## with its taste and deed, and what it does at apex: Hellhound's fire round
## Grit, Firestarter's Burn on every summon's attacks, Brood Mother's nest
## that stays, Viper Queen's viper fed by Poisoned deaths, Alpha's three
## hounds spurred by each fall, and Wild Hunt's Marks under Howl; and the
## aura stat `speed` (Blood Scent).

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"hellhound": "cinderhound", "firestarter": "cinderhound",
	"brood_mother": "serpent_keeper", "viper_queen": "serpent_keeper",
	"alpha": "packleader", "wild_hunt": "packleader",
}
const TEAM: Array[String] = ["brannoc", "severine", "kestra"]

var _content: ContentDb
var _run: RunContent


func before_all() -> void:
	_content = K.content()
	_run = RunContent.load_dir("res://data", _content)


## A fight of Kestra with `team`, transformed on the path of `apex_id`,
## vowed to it, and at apex if `apexed`, holding `cards`; the enemies at
## `scale_bp` of their own.
func _fight(encounter_id: String, apex_id: String, apexed: bool, scale_bp: int = 7500, cards: Array[String] = []) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("kestra")
	var extras: Dictionary[String, HeroExtras] = {"kestra": HeroExtras.new()}
	for card_id: String in cards:
		extras["kestra"].mods.append(_run.upgrades[card_id].mod)
	var encounter: EncounterDef = _content.encounters[encounter_id]
	var keep: int = encounter.scale_bp
	encounter.scale_bp = FixedMath.apply_bp(keep, scale_bp)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, {"kestra": APEXES[apex_id]} as Dictionary[String, String],
		["kestra"] as Array[String], extras, {"kestra": apex_id} as Dictionary[String, String], at_apex)
	encounter.scale_bp = keep
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String, unit_id: String = "kestra") -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == unit_id and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("kestra", apex_id)


func _stacks(entries: Array[LogEntry], status_id: String) -> int:
	return entries.filter(func(entry: LogEntry) -> bool: return entry.status == status_id).reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)


func test_her_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		assert_true(_content.paths[APEXES[apex_id]].apexes.has(apex), apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		# Firestarter gives +35% (8f-6b: a tankless team that hit a wall at x1.25); the rest +15%.
		var hp_bp: int = 13500 if apex_id == "firestarter" else 11500
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), hp_bp), apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "kestra").size(), 6)
	assert_eq(_content.apexes["alpha"].apex_kit.companions.map(func(companion: CompanionDef) -> String: return companion.kit.id), ["grit", "brindle", "fang"], "three hounds")
	assert_eq(_content.apexes["brood_mother"].vowed_kit.signature.effects[0].count, 4, "the taste: four nestlings")


func test_hellhound_burns_round_grit() -> void:
	var vowed: CombatSim = _fight("cairn_road", "hellhound", false)
	var grit_burns: Array[LogEntry] = vowed.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool:
		return entry.source_unit == "grit" and entry.status == "burn" and entry.source_ability in ["bite", "ember_coat", "firebrand_pounce"])
	assert_eq(_deed(vowed, "hellhound"), _stacks(grit_burns, "burn"), "the Burn Grit sets")
	var sim: CombatSim = _fight("cairn_road", "hellhound", true)
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "hellfire", "grit").size(), 0, "enemies near him catch fire")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "hellhound", "grit").size(), 0, "a Burning enemy falls near him")
	assert_true(_of(sim, LogEntry.Kind.STATUS_APPLIED, "hellhound", "grit").all(func(entry: LogEntry) -> bool: return entry.target == "grit"), "and he hits harder")


func test_firestarter_burns_with_every_summon() -> void:
	var vowed: CombatSim = _fight("cairn_road", "firestarter", false)
	var pounce: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "firebrand_pounce", "grit")
	var near: Dictionary = {}
	for entry: LogEntry in pounce:
		near[entry.tick] = near.get(entry.tick, 0) + 1
	assert_true(near.values().any(func(count: int) -> bool: return count > 1), "the taste: one more enemy burns")
	var hounds: Array[LogEntry] = vowed.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "grit")
	assert_eq(_deed(vowed, "firestarter"), _stacks(hounds, "burn"), "the Burn her hound sets")
	var sim: CombatSim = _fight("cairn_road", "firestarter", true)
	var set: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "firestarter")
	assert_gt(set.size(), 0, "Grit's bites set Burn through her")
	var by_grit: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "grit")
	assert_eq(_deed(sim, "firestarter"), _stacks(set, "burn") + _stacks(by_grit, "burn"), "and what every summon's attacks set")


func test_brood_mother_keeps_her_brood() -> void:
	var sim: CombatSim = _fight("cairn_road", "brood_mother", true)
	var hatched: Array[LogEntry] = _of(sim, LogEntry.Kind.SUMMON, "nest")
	assert_gt(hatched.size(), 3, "more than one cast")
	assert_gt(_deed(sim, "brood_mother"), 0, "their nips Poison")
	var nestling: UnitState = null
	for unit: UnitState in sim.units:
		if unit.def.id == "nestling":
			nestling = unit
			assert_gt(unit.expires_at, 60 * 20, "they stay all fight")
	assert_not_null(nestling)


func test_viper_queen_feeds_on_the_poisoned() -> void:
	var vowed: CombatSim = _fight("cairn_road", "viper_queen", false)
	assert_gt(_of(vowed, LogEntry.Kind.STATUS_APPLIED, "spit", "viper").filter(func(entry: LogEntry) -> bool: return entry.status == "numbed").size(), 0, "the taste Slows")
	var sim: CombatSim = _fight("cairn_road", "viper_queen", true)
	var spit: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "spit", "viper")
	assert_gt(spit.filter(func(entry: LogEntry) -> bool: return entry.status == "viper_slow").size(), 0)
	assert_eq(_deed(sim, "viper_queen"), _stacks(spit, "poison"))
	var fed: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "queen_feed", "viper")
	assert_gt(fed.size(), 0, "a Poisoned enemy falls")
	assert_gt(sim.unit_by_id("viper").max_hp, FixedMath.apply_bp(sim.unit_by_id("kestra").base_max_hp, 3200), "the viper stands longer")


func test_alpha_runs_three_hounds() -> void:
	var sim: CombatSim = _fight("cairn_road", "alpha", true, 13000)
	for hound: String in ["grit", "brindle", "fang"]:
		assert_eq(sim.unit_by_id(hound).owner, sim.unit_by_id("kestra"), hound)
	var fury: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "pack_fury")
	assert_gt(fury.size(), 0, "a hound falls")
	assert_true(fury.all(func(entry: LogEntry) -> bool: return entry.status == "alpha_fury"))
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "alpha_blood").size(), 0, "every summon faster for good")
	assert_gt(_deed(sim, "alpha"), 0, "attacks under Pack Fury")


func test_wild_hunt_marks_its_prey() -> void:
	var vowed: CombatSim = _fight("cairn_road", "wild_hunt", false)
	assert_gt(_deed(vowed, "wild_hunt"), 0, "summons' damage under Howl")
	var sim: CombatSim = _fight("cairn_road", "wild_hunt", true)
	var marks: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "wild_hunt")
	assert_gt(marks.size(), 0)
	assert_true(marks.all(func(entry: LogEntry) -> bool: return entry.status == "marked"))
	var hounds_hit: int = 0
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.DAMAGE):
		if entry.source_unit in ["grit", "brindle"]:
			hounds_hit += entry.amount
	assert_lt(_deed(sim, "wild_hunt"), hounds_hit + 1, "only part of what they deal: what lands under Howl")


func test_damage_by_allies_takes_statuses() -> void:
	var deed: DeedDef = _content.apexes["wild_hunt"].deed
	assert_eq([deed.counts, deed.by_allies, deed.statuses], [DeedDef.Counts.DAMAGE, true, ["howl"] as Array[String]])


func test_blood_scent_speeds_summons_under_howl() -> void:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var extras: Dictionary[String, HeroExtras] = {"kestra": HeroExtras.new()}
	extras["kestra"].mods.append(_run.upgrades["hunt_scent"].mod)
	var setup: FightSetup = Encounters.setup(_content, "cairn_road", formation, 1, errors, {}, {"kestra": "packleader"} as Dictionary[String, String],
		["kestra"] as Array[String], extras, {"kestra": "wild_hunt"} as Dictionary[String, String], ["kestra"] as Array[String])
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	var grit: UnitState = sim.unit_by_id("grit")
	var speed: int = grit.def.stats.get_stat(UnitStats.Stat.SPEED)
	assert_eq(grit.stats.get_stat(UnitStats.Stat.SPEED), speed, "not before Howl")
	var seen: bool = false
	while not sim.finished and not seen:
		sim.step()
		if Statuses.stacks_on(grit, "howl") > 0 and grit.alive:
			seen = true
			assert_eq(grit.stats.get_stat(UnitStats.Stat.SPEED), speed + 1, "+1 hex a second under Howl")
	assert_true(seen, "Howl reaches Grit")
	assert_eq(sim.unit_by_id("kestra").stats.get_stat(UnitStats.Stat.SPEED), sim.unit_by_id("kestra").def.stats.get_stat(UnitStats.Stat.SPEED), "only summons")
