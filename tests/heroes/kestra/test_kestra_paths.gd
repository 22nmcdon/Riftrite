extends GutTest
## Kestra's paths (phase 8 part 6, docs/plans/phases/rebuild-phase8-last-heroes.md
## 8f-3; rebuild-heroes.md section 8k) in real fights: Cinderhound's
## Smoldering Fangs, ember coat, and Firebrand Pounce, Serpent-Keeper's
## Venomed Jab, viper, and Nest, Packleader's Pack Call, two hounds, Pack
## Fury, and Howl, Sic 'Em as each one's habit, and each deed moving only
## with its taste.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["brannoc", "maren", "kestra"]
const PATHS: Array[String] = ["cinderhound", "serpent_keeper", "packleader"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Kestra with `team`, on `path_id` ("" for her base kit;
## transformed if `transformed`), the encounter's enemies at `scale_bp`.
func _fight(encounter_id: String, path_id: String, transformed: bool, team: Array[String] = TEAM, scale_bp: int = 10000) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {}
	if not path_id.is_empty():
		vows["kestra"] = path_id
	var stages: Array[String] = []
	if transformed:
		stages.append("kestra")
	var encounter: EncounterDef = _content.encounters[encounter_id]
	var keep: int = encounter.scale_bp
	encounter.scale_bp = FixedMath.apply_bp(keep, scale_bp)
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, stages)
	encounter.scale_bp = keep
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


## `kind` entries sourced to `unit_id`'s `ability_id`.
func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String, unit_id: String = "kestra") -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == unit_id and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("kestra", path_id)


func _stacks(entries: Array[LogEntry], status_id: String) -> int:
	return entries.filter(func(entry: LogEntry) -> bool: return entry.status == status_id).reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)


func test_kestra_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "kestra"), "her three paths are built")
	for path_id: String in PATHS:
		var habit: PartDef = null
		for part: PartDef in _content.paths[path_id].transformed_kit.passives:
			if part.id == "sic_em":
				habit = part
		assert_not_null(habit, "%s keeps Sic 'Em as a habit" % path_id)
		assert_true(habit.ability.by_companion, "done by her companion")
		assert_eq(habit.ability.effects.back().every, 8, path_id)


func test_her_base_kit_fills_no_deed() -> void:
	var sim: CombatSim = _fight("cairn_road", "", false)
	for path_id: String in PATHS:
		assert_eq(_deed(sim, path_id), 0, "%s needs its taste" % path_id)


func test_cinderhound_burns_through_grit() -> void:
	var vowed: CombatSim = _fight("cairn_road", "cinderhound", false)
	var fangs: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "bite", "grit")
	var bites: int = _of(vowed, LogEntry.Kind.FIRE, "bite", "grit").size()
	assert_gt(fangs.size(), 0, "Smoldering Fangs")
	assert_almost_eq(fangs.size(), bites / 3, 1, "every 3rd bite")
	assert_eq(_deed(vowed, "cinderhound"), _stacks(fangs, "burn"), "the deed counts the Burn his bites set")
	# Enemies x1.5, so the fight lasts until some reach Grit past Brannoc
	# (since 8f-6c's tuning a fight at their own strength ends first).
	var sim: CombatSim = _fight("cairn_road", "cinderhound", true, TEAM, 15000)
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "firebrand_pounce", "grit").size(), 0, "Grit does Firebrand Pounce")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "firebrand_pounce", "grit").size(), 0, "and its burst sets Burn")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "ember_coat", "grit").size(), 0, "enemies that hit him catch Burn")
	assert_eq(sim.unit_by_id("grit").max_hp, FixedMath.apply_bp(sim.unit_by_id("kestra").base_max_hp, 3200), "20% less HP than Grit's 40%")
	assert_gt(_of(sim, LogEntry.Kind.LEAP, "sic_em", "grit").size(), 0, "Sic 'Em is a habit")


func test_serpent_keeper_poisons_with_her_jab_and_her_brood() -> void:
	var vowed: CombatSim = _fight("cairn_road", "serpent_keeper", false)
	var jabs: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "spear_jab")
	assert_gt(jabs.size(), 0, "Venomed Jab")
	assert_eq(_deed(vowed, "serpent_keeper"), _stacks(jabs, "poison"))
	var sim: CombatSim = _fight("cairn_road", "serpent_keeper", true)
	assert_null(sim.unit_by_id("grit"), "the viper takes Grit's place")
	var viper: UnitState = sim.unit_by_id("viper")
	assert_eq([viper.owner, viper.def.stats.get_stat(UnitStats.Stat.RANGE)], [sim.unit_by_id("kestra"), 3])
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "spit", "viper").size(), 0, "it spits Poison")
	var hatched: Array[LogEntry] = _of(sim, LogEntry.Kind.SUMMON, "nest")
	assert_gt(hatched.size(), 0, "Nest")
	assert_eq(hatched.size() % 3, 0, "3 nestlings at a time")
	var nestling: UnitState = sim.unit_by_id("nestling")
	assert_eq(nestling.owner, sim.unit_by_id("kestra"), "hers")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "sic_em", "viper").size(), 0, "the viper spits for Sic 'Em")
	assert_eq(_of(sim, LogEntry.Kind.LEAP, "sic_em", "viper").size(), 0, "without leaping")


func test_packleader_runs_the_pack() -> void:
	var vowed: CombatSim = _fight("cairn_road", "packleader", false)
	var bites: Array[LogEntry] = _of(vowed, LogEntry.Kind.DAMAGE, "bite", "grit")
	assert_gt(_deed(vowed, "packleader"), 0, "Pack Call adds to his bites")
	assert_eq(_deed(vowed, "packleader"), bites.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.part_bonus, 0))
	var sim: CombatSim = _fight("cairn_road", "packleader", true)
	assert_not_null(sim.unit_by_id("brindle"), "a second hound")
	assert_eq(sim.unit_by_id("kestra").def.stats.get_stat(UnitStats.Stat.RANGE), 1, "her spear reaches 1 hex")
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "howl").size(), 0, "Howl")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "howl").filter(func(entry: LogEntry) -> bool: return entry.target in ["grit", "brindle"]).size(), 0, "on the hounds")
	assert_false(_of(sim, LogEntry.Kind.STATUS_APPLIED, "howl").any(func(entry: LogEntry) -> bool: return entry.target in TEAM), "and only the summons")
	assert_gt(_of(sim, LogEntry.Kind.SHIELD, "howl").size(), 0, "with a Shield")
	assert_gt(_deed(sim, "packleader"), 0, "both hounds' Pack Call counts")


func test_pack_fury_hears_a_hound_fall() -> void:
	var sim: CombatSim = _fight("cairn_road", "packleader", true, TEAM, 13000)
	var fury: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "pack_fury")
	var fell: int = sim.combat_log.of_kind(LogEntry.Kind.DEATH).filter(func(entry: LogEntry) -> bool: return entry.target in ["grit", "brindle"]).size()
	assert_gt(fell, 0, "a hound falls in a harder fight")
	assert_gt(fury.size(), 0, "and the others are spurred on")
	assert_false(fury.any(func(entry: LogEntry) -> bool: return entry.target in TEAM), "only summons")
