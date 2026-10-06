extends GutTest
## Garrow's six apexes (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md
## 8d-2c; apexes.md) in real fights: each loads on its path's transformed
## kit, its taste and deed, and its snowball growing at apex: Endless
## Bulwark's layers, Shatterburst's echoes and kept Shield, Grinder's feed,
## Undertow's tide, Thorned King's crown and splash, and Vengeance's stored
## damage released.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["maren", "vell", "garrow"]
const APEXES: Dictionary[String, String] = {
	"endless_bulwark": "aegisfang", "shatterburst": "aegisfang",
	"grinder": "chainwarden", "undertow": "chainwarden",
	"thorned_king": "spitemail", "vengeance": "spitemail",
}

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Garrow with Maren and Vell, Garrow transformed on the path of
## `apex_id`, vowed to it, and at apex if `apexed`.
func _fight(encounter_id: String, apex_id: String, apexed: bool) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {"garrow": APEXES[apex_id]}
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("garrow")
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, ["garrow"] as Array[String], {},
		{"garrow": apex_id} as Dictionary[String, String], at_apex)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "garrow" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _stacks_applied(sim: CombatSim, status_id: String) -> int:
	var stacks: int = 0
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED):
		if entry.source_unit == "garrow" and entry.status == status_id:
			stacks += 1
	return stacks


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("garrow", apex_id)


func _sum(entries: Array[LogEntry]) -> int:
	return entries.reduce(func(sum: int, entry: LogEntry) -> int: return sum + entry.amount, 0)


func test_his_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		assert_true(_content.paths[APEXES[apex_id]].apexes.has(apex), apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), 11500), "%s: +15%% HP" % apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "garrow").size(), 6)


func test_endless_bulwark_lays_plate_on_plate() -> void:
	var vowed: CombatSim = _fight("old_mother_ash", "endless_bulwark", false)
	var garrow: UnitState = vowed.unit_by_id("garrow")
	var plated: Array[LogEntry] = _of(vowed, LogEntry.Kind.SHIELD, "plated_blows")
	assert_gt(plated.size(), 3)
	assert_eq(plated[0].amount, FixedMath.apply_bp(garrow.max_hp, 250), "the taste: 2.5% of his max HP")
	assert_gt(_deed(vowed, "endless_bulwark"), 0, "Shield past a tenth of his max HP counts")
	assert_lt(_deed(vowed, "endless_bulwark"), _sum(plated), "only the part past the line")
	var sim: CombatSim = _fight("the_pack", "endless_bulwark", true)
	var blows: Array[LogEntry] = _of(sim, LogEntry.Kind.SHIELD, "plated_blows")
	assert_gt(blows.size(), 3)
	assert_gt(blows[blows.size() - 1].amount, blows[0].amount, "each layer makes the next Shield bigger")
	assert_eq(_stacks_applied(sim, "bulwark_layer"), blows.size(), "a layer a blow")


func test_shatterburst_bursts_wider_and_keeps_a_quarter() -> void:
	var sim: CombatSim = _fight("the_pack", "shatterburst", true)
	var spent: Array[LogEntry] = _of(sim, LogEntry.Kind.SHIELD_SPENT, "bulwark_burst")
	assert_gt(spent.size(), 0, "it bursts")
	assert_string_contains(spent[0].to_text(), "keeps", "a quarter stays with him")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "bulwark_burst").size(), 0)
	assert_gt(_stacks_applied(sim, "shatter_echo"), 0, "each enemy a Burst hits echoes")
	assert_eq(_deed(sim, "shatterburst"), _sum(_of(sim, LogEntry.Kind.DAMAGE, "bulwark_burst")), "the deed is the Burst's damage")


func test_grinder_grinds_and_feeds_on_the_fallen() -> void:
	var vowed: CombatSim = _fight("the_pack", "grinder", false)
	var ground: Array[LogEntry] = _of(vowed, LogEntry.Kind.DAMAGE, "grinder")
	assert_gt(ground.size(), 0, "the taste grinds the enemies next to him")
	assert_eq(_deed(vowed, "grinder"), _sum(ground))
	var sim: CombatSim = _fight("the_pack", "grinder", true)
	assert_gt(_sum(_of(sim, LogEntry.Kind.DAMAGE, "grinder")), _sum(ground), "the apex grinds harder")
	assert_gt(_stacks_applied(sim, "grinder_feed"), 0, "enemies that fall next to him feed it")


func test_undertow_drags_the_field_in() -> void:
	var vowed: CombatSim = _fight("hollow_line", "undertow", false)
	assert_gt(_deed(vowed, "undertow"), 0, "hexes dragged count")
	var sim: CombatSim = _fight("hollow_line", "undertow", true)
	assert_gt(_of(sim, LogEntry.Kind.PUSH, "undertow").size(), 0, "every 4s the field is pulled in")
	assert_gt(_stacks_applied(sim, "undertow_tide"), 0, "each pull feeds the tide")
	var roots: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "maelstrom").filter(func(entry: LogEntry) -> bool: return entry.status == "root")
	assert_gt(roots.size(), 0, "Maelstrom still Roots")


func test_thorned_king_splashes_and_grows_his_crown() -> void:
	var sim: CombatSim = _fight("old_mother_ash", "thorned_king", true)
	var spikes: Array[LogEntry] = _of(sim, LogEntry.Kind.DAMAGE, "spikes")
	assert_gt(spikes.size(), 0)
	var hit: Dictionary[String, bool] = {}
	for entry: LogEntry in spikes:
		hit[entry.target] = true
	assert_gt(hit.size(), 1, "thorns splash past the attacker")
	assert_gt(_stacks_applied(sim, "thorn_crown"), 0, "the crown grows with damage sent back")
	assert_eq(_deed(sim, "thorned_king"), _sum(_of(sim, LogEntry.Kind.DAMAGE, "maidens_spite")), "the deed is what Iron Maiden sends back")


func test_vengeance_stores_and_releases() -> void:
	var vowed: CombatSim = _fight("the_pack", "vengeance", false)
	var stored_any: bool = false
	for entry: LogEntry in vowed.combat_log.of_kind(LogEntry.Kind.DAMAGE):
		if entry.target == "garrow" and entry.note.contains("stored"):
			stored_any = true
	assert_true(stored_any, "the taste stores a share of each hit")
	var sim: CombatSim = _fight("the_pack", "vengeance", true)
	var released: Array[LogEntry] = _of(sim, LogEntry.Kind.RELEASED, "vengeance")
	var blasts: Array[LogEntry] = _of(sim, LogEntry.Kind.DAMAGE, "vengeance")
	assert_gt(released.size() + blasts.size(), 0, "it's released when Iron Maiden ends, or as he falls")
	assert_gt(blasts.size(), 0, "as a blast")
	assert_eq(_deed(sim, "vengeance"), _sum(blasts))
