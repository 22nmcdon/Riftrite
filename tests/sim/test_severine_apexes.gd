extends GutTest
## Severine's six apexes (phase 8 part 5, docs/plans/rebuild-phase8-severine-
## edric.md 8e-2c; apexes.md) in real fights: each loads on its path's
## transformed kit with its taste and deed, and its snowball grows at apex:
## Leviathan's lifesteal per share of max HP gained, Sanguine Nova's burst of
## Engorged max HP and faster Engorge, Gravecaller's thralls, Pestilence's
## stronger Poison, Blood Tide's thirstier Blood Bolt, and Blood Rite's
## strength for the team.

const K = preload("res://tests/sim/sim_test_kit.gd")
const APEXES: Dictionary[String, String] = {
	"leviathan": "bloodglut", "sanguine_nova": "bloodglut",
	"gravecaller": "plaguebearer", "pestilence": "plaguebearer",
	"blood_tide": "hemomancer", "blood_rite": "hemomancer",
}
const TEAM: Array[String] = ["brannoc", "maren", "severine"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Severine with Brannoc and Maren, Severine transformed on the
## path of `apex_id`, vowed to it, and at apex if `apexed`.
func _fight(encounter_id: String, apex_id: String, apexed: bool) -> CombatSim:
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, TEAM, HeroTeam.GUARDED)
	var at_apex: Array[String] = []
	if apexed:
		at_apex.append("severine")
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, {"severine": APEXES[apex_id]} as Dictionary[String, String],
		["severine"] as Array[String], {}, {"severine": apex_id} as Dictionary[String, String], at_apex)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "severine" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _applied(sim: CombatSim, status_id: String) -> Array[LogEntry]:
	return sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "severine" and entry.status == status_id)


func _deed(sim: CombatSim, apex_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("severine", apex_id)


func test_her_six_apexes_load_on_their_paths() -> void:
	for apex_id: String in APEXES:
		var apex: ApexDef = _content.apexes[apex_id]
		assert_eq(apex.path, APEXES[apex_id], apex_id)
		assert_true(_content.paths[APEXES[apex_id]].apexes.has(apex), apex_id)
		var path_kit: UnitDef = _content.paths[apex.path].transformed_kit
		# Leviathan has no stat lift (she grows her own); the rest +15% HP.
		var lift: int = FixedMath.BP_ONE if apex_id == "leviathan" else 11500
		assert_eq(apex.apex_kit.stats.get_stat(UnitStats.Stat.HP), FixedMath.apply_bp(path_kit.stats.get_stat(UnitStats.Stat.HP), lift), apex_id)
		assert_gt(apex.deed.threshold, 0, apex_id)
	assert_eq(_content.apexes.values().filter(func(apex: ApexDef) -> bool: return _content.paths[apex.path].hero == "severine").size(), 6)


func test_leviathan_drinks_more_as_she_grows() -> void:
	var vowed: CombatSim = _fight("warren_mouth", "leviathan", false)
	assert_gt(_deed(vowed, "leviathan"), 0, "Rend's damage")
	var sim: CombatSim = _fight("warren_mouth", "leviathan", true)
	var grown: int = _of(sim, LogEntry.Kind.MAX_HP_UP, "engorge").reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)
	var start: int = _content.apexes["leviathan"].apex_kit.stats.get_stat(UnitStats.Stat.HP)
	assert_gt(grown * 10, start, "she grows past a tenth of her max HP")
	assert_true(sim.combat_log.of_kind(LogEntry.Kind.AURA).any(func(entry: LogEntry) -> bool: return entry.source_ability == "leviathan" and entry.note.begins_with("starts")),
		"Leviathan's lifesteal comes on")


func test_sanguine_nova_bursts_her_bonus_max_hp() -> void:
	var vowed: CombatSim = _fight("warren_mouth", "sanguine_nova", false)
	assert_gt(_deed(vowed, "sanguine_nova"), 0, "Gorge spills onto the enemies beside its target")
	var sim: CombatSim = _fight("warren_mouth", "sanguine_nova", true)
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "sanguine_nova").size(), 0, "Nova")
	assert_gt(_of(sim, LogEntry.Kind.MAX_HP_DOWN, "sanguine_nova").size(), 0, "she gives up what she grew")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "sanguine_nova").size(), 0, "as damage")
	assert_gt(_applied(sim, "nova_hunger").size(), 0, "each Nova makes Engorge faster")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "gorge").size(), 0, "Gorge is a habit")


func test_gravecaller_raises_the_poisoned_dead() -> void:
	var vowed: CombatSim = _fight("the_pack", "gravecaller", false)
	assert_gt(_of(vowed, LogEntry.Kind.ZONE, "corpse_cloud").size(), 0, "corpse clouds")
	assert_gt(_deed(vowed, "gravecaller"), 0, "their Poison")
	var sim: CombatSim = _fight("the_pack", "gravecaller", true)
	var raised: Array = _of(sim, LogEntry.Kind.SUMMON, "gravecaller").filter(func(entry: LogEntry) -> bool: return entry.note.is_empty())
	assert_gt(raised.size(), 0, "thralls rise")
	for entry: LogEntry in raised:
		var thrall: UnitState = sim.unit_by_id(entry.target)
		assert_true(thrall.raised and thrall.side == EffectSource.Team.HEROES and thrall.def.rank.is_empty(), entry.target)


func test_pestilence_thickens_with_the_dead() -> void:
	var vowed: CombatSim = _fight("the_pack", "pestilence", false)
	assert_gt(_deed(vowed, "pestilence"), 0, "Plague Burst's Poison")
	var sim: CombatSim = _fight("the_pack", "pestilence", true)
	assert_gt(_applied(sim, "plague_weak").size(), 0, "enemies in the cloud are weakened")
	assert_gt(_applied(sim, "pestilence").size(), 0, "each Poisoned death makes her Poison stronger")


func test_blood_tide_drinks_more_each_cast() -> void:
	var vowed: CombatSim = _fight("cairn_road", "blood_tide", false)
	assert_gt(_deed(vowed, "blood_tide"), 0, "Exsanguinate's damage")
	var sim: CombatSim = _fight("cairn_road", "blood_tide", true)
	var stacks: int = _applied(sim, "blood_tide").size()
	assert_gt(stacks, 0, "each cast gives a stack")
	assert_eq(stacks, _of(sim, LogEntry.Kind.FIRE, "exsanguinate").size(), "one a cast")
	assert_gt(_of(sim, LogEntry.Kind.LIFESTEAL, "blood_bolt").size(), 0, "Blood Bolt drinks")


func test_blood_rite_strengthens_the_team() -> void:
	var vowed: CombatSim = _fight("cairn_road", "blood_rite", false)
	assert_gt(_applied(vowed, "blood_offering").size(), 0, "the taste lifts her allies")
	assert_gt(_deed(vowed, "blood_rite"), 0, "their hits while lifted")
	var sim: CombatSim = _fight("cairn_road", "blood_rite", true)
	assert_gt(_applied(sim, "blood_rite").size(), 0, "every ally fights harder")
	assert_gt(_applied(sim, "sacred_blood").size(), 0, "and harder still for the HP she spends")
