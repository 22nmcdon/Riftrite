extends GutTest
## Ottilie's six apexes (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## 8f-2; apexes.md) in real fights: each loads on its path's transformed kit
## with its taste and deed, and what it does at apex: Grand Reaction's
## growing bonus against both, Solvent's evening of Burn and Poison, Midas
## Touch's shards for either and a higher cap, Grand Transmutation's run
## transmuting (tests/run/rewards/test_transmute.gd), Panacea's vials for two, and
## Mana Flood's cheaper signatures.

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"grand_reaction": "catalyst", "solvent": "catalyst",
	"midas_touch": "transmuter", "grand_transmutation": "transmuter",
	"panacea": "apothecary", "mana_flood": "apothecary",
}
## Burn and Poison from her allies.
const ROT: Array[String] = ["severine", "ilse", "ottilie"]
const CHOIR: Array[String] = ["brannoc", "aldous", "ottilie"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Ottilie with `team`, transformed on the path of `apex_id`,
## vowed to it, and at apex if `apexed`; the enemies at x0.75.
func _fight(encounter_id: String, apex_id: String, apexed: bool, team: Array[String]) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("ottilie")
	var encounter: EncounterDef = _content.encounters[encounter_id]
	var keep: int = encounter.scale_bp
	encounter.scale_bp = FixedMath.apply_bp(keep, 7500)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, {"ottilie": APEXES[apex_id]} as Dictionary[String, String],
		["ottilie"] as Array[String], {}, {"ottilie": apex_id} as Dictionary[String, String], at_apex)
	encounter.scale_bp = keep
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "ottilie" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("ottilie", apex_id)


func test_her_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		assert_true(_content.paths[APEXES[apex_id]].apexes.has(apex), apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		# Grand Reaction gives +35% (8f-6b: a tankless team that hit a wall at x1.25); the rest +15%.
		var hp_bp: int = 13500 if apex_id == "grand_reaction" else 11500
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), hp_bp), apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "ottilie").size(), 6)
	assert_eq(_content.apexes["grand_transmutation"].vowed_transmute.into_per_act, 1, "a taste the run uses")
	assert_eq([_content.apexes["grand_transmutation"].apex_transmute.per_shop, _content.apexes["grand_transmutation"].apex_transmute.into_rank], [2, 2])


func test_grand_reaction_grows_with_each_fall() -> void:
	var vowed: CombatSim = _fight("cairn_road", "grand_reaction", false, ROT)
	assert_eq(_deed(vowed, "grand_reaction"), _of(vowed, LogEntry.Kind.DAMAGE, "reaction_flask").reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0))
	var sim: CombatSim = _fight("cairn_road", "grand_reaction", true, ROT)
	var fed: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "reaction_feed")
	assert_gt(fed.size(), 0, "enemies falling with both feed the reaction")
	var fed_heroes: Dictionary = {}
	for entry: LogEntry in fed:
		fed_heroes[entry.target] = true
	assert_gt(fed_heroes.size(), 1, "for every standing hero")


func test_solvent_evens_burn_and_poison() -> void:
	var vowed: CombatSim = _fight("cairn_road", "solvent", false, ROT)
	var added: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "solvent")
	assert_gt(added.size(), 0)
	assert_true(added.all(func(entry: LogEntry) -> bool: return entry.status == "burn" or entry.status == "poison"))
	assert_eq(_deed(vowed, "solvent"), added.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0), "in stacks")
	var sim: CombatSim = _fight("cairn_road", "solvent", true, ROT)
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "solvent").reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0),
		added.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0), "a share of the larger, not 1")


func test_midas_touch_gilds_either() -> void:
	assert_eq(_content.apexes["midas_touch"].apex_kit.shard_cap, 12)
	assert_eq(_content.apexes["midas_touch"].grows.run_counts, "shards", "a run snowball")
	var sim: CombatSim = _fight("cairn_road", "midas_touch", true, ROT)
	var paid: Array[LogEntry] = _of(sim, LogEntry.Kind.SHARDS, "gilded_death")
	assert_gt(paid.size(), 0)
	assert_eq(_deed(sim, "midas_touch"), paid.filter(func(entry: LogEntry) -> bool: return not entry.capped).reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0))


func test_panacea_doses_two() -> void:
	var sim: CombatSim = _fight("cairn_road", "panacea", true, CHOIR)
	var given: Array[LogEntry] = _of(sim, LogEntry.Kind.MANA_GIVEN, "tonic")
	assert_gt(given.size(), 1)
	var by_tick: Dictionary = {}
	for entry: LogEntry in given:
		by_tick[entry.tick] = by_tick.get(entry.tick, 0) + 1
	assert_true(by_tick.values().has(2), "two allies at once")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "tonic").filter(func(entry: LogEntry) -> bool: return entry.status == "potent_draught").size(), 0, "a stronger next signature")


func test_mana_flood_makes_signatures_cheap() -> void:
	var sim: CombatSim = _fight("cairn_road", "mana_flood", true, CHOIR)
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "elixir").filter(func(entry: LogEntry) -> bool: return entry.status == "mana_flood").size(), 0, "the flood")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_EXTENDED, "flood_tide").size(), 0, "each ally signature in it makes it last longer")
	assert_gt(_deed(sim, "mana_flood"), 0)
