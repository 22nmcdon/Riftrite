extends GutTest
## Severine's paths (phase 8 part 5, docs/plans/rebuild-phase8-severine-edric.md
## 8e-2b; rebuild-heroes.md section 8g) in real fights: Bloodglut's Engorge
## (capped vowed, uncapped transformed) and Gorge, Plaguebearer's Blight,
## Plague Burst, and Plague Feast, Hemomancer's Blood Price and, transformed,
## the start at half HP, Blood Bolt, and Exsanguinate, Drain as each one's
## habit, and each deed moving only with its taste.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["brannoc", "maren", "severine"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Severine with Brannoc and Maren, Severine on `path_id` ("" for
## her base kit; transformed if `transformed`).
func _fight(encounter_id: String, path_id: String, transformed: bool) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {}
	if not path_id.is_empty():
		vows["severine"] = path_id
	var stages: Array[String] = []
	if transformed:
		stages.append("severine")
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
		if entry.source_unit == "severine" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _sum(entries: Array[LogEntry]) -> int:
	return entries.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("severine", path_id)


func test_severine_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "severine"), "her three paths are built")
	for path_id: String in ["bloodglut", "plaguebearer", "hemomancer"]:
		var kit: UnitDef = _content.paths[path_id].transformed_kit
		var habit: PartDef = null
		for part: PartDef in kit.passives:
			if part.id == "drain":
				habit = part
		assert_not_null(habit, "%s keeps Drain as a habit" % path_id)
		assert_eq(habit.ability.effects[0].every, 8, path_id)
		assert_eq(habit.ability.effects[0].lifesteal_bp, 5000, "%s: half of it drunk" % path_id)


func test_her_base_kit_fills_no_deed() -> void:
	var sim: CombatSim = _fight("the_pack", "", false)
	for path_id: String in ["bloodglut", "plaguebearer", "hemomancer"]:
		assert_eq(_deed(sim, path_id), 0, "%s needs its taste" % path_id)


func test_bloodglut_swells_past_full() -> void:
	var vowed: CombatSim = _fight("warren_mouth", "bloodglut", false)
	var grown: Array[LogEntry] = _of(vowed, LogEntry.Kind.MAX_HP_UP, "engorge")
	assert_gt(grown.size(), 0, "her lifesteal past full grows her")
	var start: int = _content.paths["bloodglut"].vowed_kit.stats.get_stat(UnitStats.Stat.HP)
	assert_eq(_sum(grown), FixedMath.apply_bp(start, 500), "up to 5% of her max HP, vowed")
	assert_eq(_deed(vowed, "bloodglut"), _sum(grown), "the deed counts it")
	var sim: CombatSim = _fight("warren_mouth", "bloodglut", true)
	assert_gt(_sum(_of(sim, LogEntry.Kind.MAX_HP_UP, "engorge")), FixedMath.apply_bp(start, 500), "no cap once transformed")
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "gorge").size(), 0, "Gorge")
	assert_eq(_of(sim, LogEntry.Kind.FIRE, "drain").size(), 0, "Drain is a habit now")


func test_plaguebearer_poisons_and_feeds() -> void:
	var vowed: CombatSim = _fight("the_pack", "plaguebearer", false)
	var blighted: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "blight").filter(func(entry: LogEntry) -> bool: return entry.status == "poison")
	assert_gt(blighted.size(), 0, "Rend poisons")
	assert_eq(_deed(vowed, "plaguebearer"), blighted.size(), "the deed counts each Poison Blight applies")
	var sim: CombatSim = _fight("sentinel_gate", "plaguebearer", true)
	assert_gt(_of(sim, LogEntry.Kind.ZONE, "plague_burst").size(), 0, "Plague Burst")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_DAMAGE, "plague_burst").size(), 0, "its Poison works")
	var kit: UnitDef = _content.paths["plaguebearer"].transformed_kit
	assert_true(kit.passives.any(func(part: PartDef) -> bool: return part.id == "plague_feast" and part.aura.stat == AuraDef.Stat.LIFESTEAL_MORE_BP),
		"her lifesteal doubles against the Poisoned")


func test_hemomancer_bleeds_for_power() -> void:
	var vowed: CombatSim = _fight("the_pack", "hemomancer", false)
	var spent: Array[LogEntry] = _of(vowed, LogEntry.Kind.HP_SPENT, "drain")
	assert_gt(spent.size(), 0, "Blood Price: Drain costs HP")
	assert_eq(spent[0].amount, FixedMath.apply_bp(_content.paths["hemomancer"].vowed_kit.stats.get_stat(UnitStats.Stat.HP), 500), "5% of her max HP")
	assert_eq(_deed(vowed, "hemomancer"), _sum(spent), "the deed counts HP spent")
	var sim: CombatSim = _fight("cairn_road", "hemomancer", true)
	var casts: Array[LogEntry] = _of(sim, LogEntry.Kind.HP_SPENT, "exsanguinate")
	assert_gt(casts.size(), 0, "Exsanguinate")
	assert_eq(_of(sim, LogEntry.Kind.FIRE, "exsanguinate").size(), casts.size(), "each cast paid in HP")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "blood_bolt").size(), 0, "Blood Bolt")
	assert_eq(_of(sim, LogEntry.Kind.LIFESTEAL, "exsanguinate").size(), 0, "no lifesteal on Exsanguinate")
	var setup_hp: int = _content.paths["hemomancer"].transformed_kit.start_hp_bp
	assert_eq(setup_hp, 5000, "she starts at half her HP")
