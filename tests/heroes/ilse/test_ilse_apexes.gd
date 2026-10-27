extends GutTest
## Ilse's six apexes (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## 8f-1; apexes.md) in real fights: each loads on its path's transformed kit
## with its taste and deed, and what it does at apex: Blast Furnace's stokes
## that speed her up, Crucible's Immolate that keeps the Burn, Living Flame's
## hunting fires, Ring of Fire's rings, Cinder Saint's growing MGK, and
## Kindred Flame's heals from Burn.

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"blast_furnace": "furnace", "crucible": "furnace",
	"living_flame": "wildfire", "ring_of_fire": "wildfire",
	"cinder_saint": "ember_choir", "kindred_flame": "ember_choir",
}
const TEAM: Array[String] = ["brannoc", "maren", "ilse"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Ilse with Brannoc and Maren, Ilse transformed on the path of
## `apex_id`, vowed to it, and at apex if `apexed`.
func _fight(encounter_id: String, apex_id: String, apexed: bool) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("ilse")
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, {"ilse": APEXES[apex_id]} as Dictionary[String, String],
		["ilse"] as Array[String], {}, {"ilse": apex_id} as Dictionary[String, String], at_apex)
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


func _applied(sim: CombatSim, status_id: String) -> Array[LogEntry]:
	return sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "ilse" and entry.status == status_id)


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("ilse", apex_id)


func test_her_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		assert_true(_content.paths[APEXES[apex_id]].apexes.has(apex), apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), 11500), apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "ilse").size(), 6)


func test_blast_furnace_speeds_up_with_every_stoke() -> void:
	var vowed: CombatSim = _fight("cairn_road", "blast_furnace", false)
	assert_eq(_deed(vowed, "blast_furnace"), _of(vowed, LogEntry.Kind.STATUS_APPLIED, "stoke").size(), "one for each Stoke")
	var sim: CombatSim = _fight("cairn_road", "blast_furnace", true)
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "stoke").filter(func(entry: LogEntry) -> bool: return entry.status == "burn").size(),
		_of(vowed, LogEntry.Kind.STATUS_APPLIED, "stoke").size(), "every 2nd Cinder Flick stokes")
	assert_gt(_applied(sim, "blast_furnace").size(), 0, "and each one speeds her up")


func test_crucible_keeps_the_burn() -> void:
	var vowed: CombatSim = _fight("cairn_road", "crucible", false)
	assert_eq(_deed(vowed, "crucible"), _of(vowed, LogEntry.Kind.DAMAGE, "immolate").reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0))
	var apex: ApexDef = _content.apexes["crucible"]
	assert_false(apex.apex_kit.signature.effects.any(func(effect: EffectDef) -> bool: return effect.type == EffectDef.Type.CLEANSE), "Immolate takes no Burn")
	var sim: CombatSim = _fight("cairn_road", "crucible", true)
	assert_gt(_applied(sim, "crucible").size(), 0, "each Immolate feeds Stoke")


func test_living_flame_hunts() -> void:
	var sim: CombatSim = _fight("witch_and_pups", "living_flame", true)
	assert_gt(_of(sim, LogEntry.Kind.AREA_LANDED, "firestorm").filter(func(entry: LogEntry) -> bool: return entry.note.contains("moved")).size(), 0, "its fires creep")
	assert_gt(_deed(sim, "living_flame"), 0, "and kill")
	assert_gt(_applied(sim, "living_flame").size(), 0, "growing with each kill")


func test_ring_of_fire_burns_those_who_cross() -> void:
	var vowed: CombatSim = _fight("witch_and_pups", "ring_of_fire", true)
	var rings: Array[LogEntry] = _of(vowed, LogEntry.Kind.ZONE, "ring_of_fire")
	assert_gt(rings.size(), 0, "rings")
	assert_true(rings.all(func(entry: LogEntry) -> bool: return entry.shape.begins_with("ring")))
	assert_gt(_applied(vowed, "ringed").size(), 0, "crossing one Slows")
	assert_eq(_deed(vowed, "ring_of_fire"), _of(vowed, LogEntry.Kind.STATUS_APPLIED, "ring_step").size() + _of(vowed, LogEntry.Kind.STATUS_APPLIED, "ring_of_fire").filter(func(entry: LogEntry) -> bool: return entry.status == "burn").size())


func test_cinder_saint_grows_with_her_allies() -> void:
	var sim: CombatSim = _fight("cairn_road", "cinder_saint", true)
	assert_gt(_applied(sim, "cinder_saint").size(), 0, "every ally basic attack raises her MGK")
	assert_gt(_deed(sim, "cinder_saint"), 0, "allies' damage to Burning enemies")


func test_kindred_flame_heals_from_burn() -> void:
	var vowed: CombatSim = _fight("cairn_road", "kindred_flame", false)
	var heals: Array[LogEntry] = _of(vowed, LogEntry.Kind.HEAL, "kindred_flame")
	assert_gt(heals.size(), 0, "Burn heals the team")
	assert_eq(_deed(vowed, "kindred_flame"), heals.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0))
	var sim: CombatSim = _fight("cairn_road", "kindred_flame", true)
	assert_gt(_of(sim, LogEntry.Kind.HEAL, "kindred_flame").size(), heals.size(), "five times as often at apex")
