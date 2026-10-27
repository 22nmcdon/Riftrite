extends GutTest
## Ilse's paths (phase 8 part 6, docs/plans/phases/rebuild-phase8-last-heroes.md
## 8f-1; rebuild-heroes.md section 8b) in real fights: Heat as her only mana,
## Furnace's Stoke and Immolate, Wildfire's Kindling and Firestorm, Ember
## Choir's Blessing and Hymn of Cinders, Flare as each one's habit, and each
## deed moving only with its taste.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["brannoc", "maren", "ilse"]
const PATHS: Array[String] = ["furnace", "wildfire", "ember_choir"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Ilse with Brannoc and Maren, Ilse on `path_id` ("" for her
## base kit; transformed if `transformed`).
func _fight(encounter_id: String, path_id: String, transformed: bool) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {}
	if not path_id.is_empty():
		vows["ilse"] = path_id
	var stages: Array[String] = []
	if transformed:
		stages.append("ilse")
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
		if entry.source_unit == "ilse" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _burn(entries: Array[LogEntry]) -> int:
	return entries.filter(func(entry: LogEntry) -> bool: return entry.status == "burn").reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("ilse", path_id)


func test_ilse_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "ilse"), "her three paths are built")
	for path_id: String in PATHS:
		var habit: PartDef = null
		for part: PartDef in _content.paths[path_id].transformed_kit.passives:
			if part.id == "flare":
				habit = part
		assert_not_null(habit, "%s keeps Flare as a habit" % path_id)
		assert_eq(habit.ability.effects[0].every, 6 if path_id == "wildfire" else 8, path_id)


func test_heat_is_her_only_mana() -> void:
	var kit: UnitDef = _content.heroes["ilse"].kit
	assert_eq([kit.mana.per_attack, kit.mana.regen_per_s, kit.mana.per_10_damage_taken], [0, 0, 0], "no mana from attacks, time, or hits")
	var sim: CombatSim = _fight("cairn_road", "", false)
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "flare").size(), 0, "Burn ticks near her fill her bar: Flare fires")


func test_her_base_kit_fills_no_deed() -> void:
	var sim: CombatSim = _fight("cairn_road", "", false)
	for path_id: String in PATHS:
		assert_eq(_deed(sim, path_id), 0, "%s needs its taste" % path_id)


func test_furnace_stokes_and_immolates() -> void:
	var vowed: CombatSim = _fight("cairn_road", "furnace", false)
	var stoked: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "stoke")
	assert_gt(stoked.size(), 0, "every 4th Cinder Flick stokes")
	assert_eq(_deed(vowed, "furnace"), _burn(stoked), "the deed counts the Burn Stoke adds, in stacks")
	var sim: CombatSim = _fight("cairn_road", "furnace", true)
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "immolate").size(), 0, "Immolate")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "immolate").size(), 0, "and it hits")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "cinder_flick").filter(func(entry: LogEntry) -> bool: return entry.status == "smoldering").size(), 0,
		"Burn on her targets fades slower")
	assert_gt(_of(sim, LogEntry.Kind.AREA_LANDED, "flare").size(), 0, "Flare is a habit")


func test_wildfire_sets_the_ground_alight() -> void:
	var vowed: CombatSim = _fight("cairn_road", "wildfire", false)
	assert_gt(_of(vowed, LogEntry.Kind.ZONE, "kindling").size(), 0, "Flare leaves burning ground")
	assert_eq(_deed(vowed, "wildfire"), _burn(_of(vowed, LogEntry.Kind.STATUS_APPLIED, "kindling")), "the deed counts its Burn, in stacks")
	var sim: CombatSim = _fight("witch_and_pups", "wildfire", true)
	var storms: Array[LogEntry] = _of(sim, LogEntry.Kind.ZONE, "firestorm")
	assert_gt(storms.size(), 1, "Firestorm starts a fire under each group")
	assert_true(_of(sim, LogEntry.Kind.AREA_LANDED, "firestorm").any(func(entry: LogEntry) -> bool: return entry.note.contains("spread to")), "and it spreads")
	assert_eq(_of(sim, LogEntry.Kind.STATUS_APPLIED, "cinder_flick").size(), 0, "Cinder Flick sets no Burn once transformed")


func test_ember_choir_sets_allies_weapons_alight() -> void:
	var vowed: CombatSim = _fight("cairn_road", "ember_choir", false)
	var blessed: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "blessing").filter(func(entry: LogEntry) -> bool: return entry.status == "burn")
	assert_gt(blessed.size(), 0, "blessed allies' attacks set Burn")
	assert_true(blessed.all(func(entry: LogEntry) -> bool: return entry.amount == 1), "1 Burn each")
	assert_eq(_deed(vowed, "ember_choir"), blessed.size())
	var sim: CombatSim = _fight("cairn_road", "ember_choir", true)
	var burns: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "ember_choir")
	assert_gt(burns.size(), 0, "every ally's attack sets Burn")
	assert_false(burns.any(func(entry: LogEntry) -> bool: return entry.target == "ilse"), "never on her own")
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "hymn_of_cinders").size(), 0, "Hymn of Cinders")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "hymn").filter(func(entry: LogEntry) -> bool: return entry.status == "burn").size(), 0, "and allies carry more Burn under it")
