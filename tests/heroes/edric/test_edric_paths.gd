extends GutTest
## Edric's paths (phase 8 part 5, docs/plans/phases/rebuild-phase8-severine-edric.md
## 8e-3c; rebuild-heroes.md section 8h) in real fights: Aegis's Hallow and
## Sanctuary, Tithe-Collector's Collection (its Tithe is the run's:
## tests/run/rewards/test_tithe.gd), Psalmist's Offering, Psalm, and Vesper Ward,
## Ward as each one's habit, and each deed moving only with its taste.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["brannoc", "maren", "edric"]
const PATHS: Array[String] = ["aegis", "tithe_collector", "psalmist"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Edric with Brannoc and Maren, Edric on `path_id` ("" for his
## base kit; transformed if `transformed`).
func _fight(encounter_id: String, path_id: String, transformed: bool) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {}
	if not path_id.is_empty():
		vows["edric"] = path_id
	var stages: Array[String] = []
	if transformed:
		stages.append("edric")
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, stages)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "edric" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _sum(entries: Array[LogEntry]) -> int:
	return entries.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("edric", path_id)


func test_edric_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "edric"), "his three paths are built")
	for path_id: String in PATHS:
		var kit: UnitDef = _content.paths[path_id].transformed_kit
		var habit: PartDef = null
		for part: PartDef in kit.passives:
			if part.id == "ward":
				habit = part
		assert_not_null(habit, "%s keeps Ward as a habit" % path_id)
		assert_eq(habit.ability.effects[0].every, 8, path_id)


func test_his_base_kit_fills_no_deed() -> void:
	var sim: CombatSim = _fight("the_pack", "", false)
	for path_id: String in PATHS:
		assert_eq(_deed(sim, path_id), 0, "%s needs its taste" % path_id)


func test_aegis_hallows_the_weakest() -> void:
	var vowed: CombatSim = _fight("the_pack", "aegis", false)
	var hallows: Array[LogEntry] = _of(vowed, LogEntry.Kind.SHIELD, "hallow")
	assert_gt(hallows.size(), 0, "Hallow wards someone every 6s")
	assert_eq(_deed(vowed, "aegis"), _sum(hallows), "the deed counts Hallow's Shield")
	var sim: CombatSim = _fight("the_pack", "aegis", true)
	assert_gt(_of(sim, LogEntry.Kind.SHIELD, "hallow").size(), hallows.size(), "every 4s once transformed")
	var sanctuary: Array[LogEntry] = _of(sim, LogEntry.Kind.SHIELD, "sanctuary")
	assert_gt(sanctuary.size(), 0, "Sanctuary")
	var to_maren: Array[LogEntry] = sanctuary.filter(func(entry: LogEntry) -> bool: return entry.target == "maren")
	assert_eq(to_maren[0].amount, FixedMath.apply_bp(sim.unit_by_id("maren").max_hp, 1500), "15% of her max HP (tuned from 20%)")
	assert_gt(_of(sim, LogEntry.Kind.SHIELD, "ward").size(), 0, "Ward is a habit")


func test_tithe_collector_collects_from_the_fallen() -> void:
	var vowed: CombatSim = _fight("the_pack", "tithe_collector", false)
	assert_eq(_deed(vowed, "tithe_collector"), 0, "Tithe is counted in a run, never in a fight (Decision 3)")
	var sim: CombatSim = _fight("the_pack", "tithe_collector", true)
	var fires: int = _of(sim, LogEntry.Kind.FIRE, "collection").size()
	assert_gt(fires, 0, "Collection")
	var paid: Array[LogEntry] = _of(sim, LogEntry.Kind.SHARDS, "collection_dues")
	assert_gt(paid.size(), 0, "enemies falling in its window pay shards")
	assert_lte(paid.size(), 3 * fires, "at most 3 a cast")
	var edric: UnitState = sim.unit_by_id("edric")
	assert_eq(edric.max_hp, FixedMath.apply_bp(_content.heroes["edric"].kit.stats.get_stat(UnitStats.Stat.HP), 8500), "15% less max HP")


func test_psalmist_turns_broken_wards_into_mana() -> void:
	var vowed: CombatSim = _fight("the_pack", "psalmist", false)
	var given: Array[LogEntry] = _of(vowed, LogEntry.Kind.MANA_GIVEN, "offering")
	assert_gt(given.size(), 0, "a breaking Shield gives its ally mana")
	assert_true(given.all(func(entry: LogEntry) -> bool: return entry.amount <= 500) and given.any(func(entry: LogEntry) -> bool: return entry.amount == 500),
		"5 each, vowed (in hundredths; what fits in the bar)")
	assert_eq(_deed(vowed, "psalmist"), _sum(given) / 100, "the deed counts it, in mana")
	var sim: CombatSim = _fight("the_pack", "psalmist", true)
	var more: Array[LogEntry] = _of(sim, LogEntry.Kind.MANA_GIVEN, "offering")
	assert_gt(more.size(), 0, "Offering stays")
	assert_true(more.all(func(entry: LogEntry) -> bool: return entry.amount <= 800), "up to 8 each, transformed (tuned from 10)")
	var offering: PartDef = _content.paths["psalmist"].transformed_kit.passives.filter(func(part: PartDef) -> bool: return part.id == "offering")[0]
	assert_eq(offering.ability.effects[0].amount, 8)
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "vesper_ward").size(), 0, "Vesper Ward")
	var vesper: Array[LogEntry] = _of(sim, LogEntry.Kind.SHIELD, "vesper_ward").filter(func(entry: LogEntry) -> bool: return entry.target == "maren")
	assert_eq(vesper[0].amount, FixedMath.apply_bp(sim.unit_by_id("maren").max_hp, 750), "a quarter smaller than 10%")
	assert_gt(_of(sim, LogEntry.Kind.MANA_GIVEN, "vesper_ward").size(), 0, "and its mana")
