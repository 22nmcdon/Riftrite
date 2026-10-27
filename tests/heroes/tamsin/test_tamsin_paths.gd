extends GutTest
## Tamsin's paths (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md 8d-3b;
## rebuild-heroes.md section 8c) in real fights: Nightblade's Fade and Shadow
## Dance, Headhunter's Scent and Sentence, Garrote's Choke and grip,
## Shadowstep as each one's habit, and each deed moving.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["maren", "vell", "tamsin"]
const HELD: Array[String] = ["root", "stun", "garroted"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Tamsin with Maren and Vell, Tamsin on `path_id` (transformed
## if `transformed`).
func _fight(encounter_id: String, path_id: String, transformed: bool) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {"tamsin": path_id}
	var stages: Array[String] = []
	if transformed:
		stages.append("tamsin")
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
		if entry.source_unit == "tamsin" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("tamsin", path_id)


func _sum(entries: Array[LogEntry]) -> int:
	return entries.reduce(func(sum: int, entry: LogEntry) -> int: return sum + entry.amount, 0)


func test_tamsin_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "tamsin"), "her three paths are built")
	for path_id: String in ["nightblade", "headhunter", "garrote"]:
		var kit: UnitDef = _content.paths[path_id].transformed_kit
		var habit: PartDef = null
		for part: PartDef in kit.passives:
			if part.id == "shadowstep":
				habit = part
		assert_not_null(habit, "%s keeps Shadowstep as a habit" % path_id)
		assert_eq(habit.ability.effects[0].every, 8, path_id)


func test_nightblade_hides_on_each_kill_and_dances() -> void:
	var vowed: CombatSim = _fight("pup_warren", "nightblade", false)
	var faded: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "fade")
	assert_gt(faded.size(), 0, "a kill hides her")
	assert_eq(_deed(vowed, "nightblade"), faded.size(), "the deed counts them")
	var sim: CombatSim = _fight("pup_warren", "nightblade", true)
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "shadow_dance").filter(func(entry: LogEntry) -> bool: return entry.status == "shadow_dance").size(), 0, "Shadow Dance")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "fade").size(), 0, "Fade still hides her")
	assert_eq(_of(sim, LogEntry.Kind.FIRE, "shadowstep").size(), 0, "Shadowstep is a habit now")
	assert_gt(_of(sim, LogEntry.Kind.LEAP, "shadowstep").size(), 0, "but she still slips behind, every 8th Knife")


func test_headhunter_keeps_marks_and_sentences() -> void:
	var vowed: CombatSim = _fight("the_pack", "headhunter", false)
	var kept: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_EXTENDED, "scent")
	assert_gt(kept.size(), 0, "her hits keep Maren's Marks")
	assert_gt(_deed(vowed, "headhunter"), 0)
	var sim: CombatSim = _fight("the_pack", "headhunter", true)
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "sentence").size(), 0, "Sentence")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_EXTENDED, "scent").size(), 0)


func test_garrote_grips_and_chokes() -> void:
	var sim: CombatSim = _fight("the_pack", "garrote", true)
	var grabbed: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "garrote").filter(func(entry: LogEntry) -> bool: return entry.status == "garroted")
	assert_gt(grabbed.size(), 0, "she Garrotes")
	assert_gt(_of(sim, LogEntry.Kind.DAMAGE, "garrote").size(), grabbed.size(), "and hits it again and again")
	var choked: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_EXTENDED, "choke")
	assert_gt(choked.size(), 0, "her Knife holds them longer")
	for entry: LogEntry in choked:
		assert_true(HELD.has(entry.status))
	assert_gt(_deed(sim, "garrote"), 0)
	for entry: LogEntry in _of(sim, LogEntry.Kind.DAMAGE, "knife"):
		if entry.crit:
			return
	fail_test("her Knife crits the held")


func test_vowed_choke_holds_on_a_knife_crit() -> void:
	var kit: UnitDef = _content.paths["garrote"].vowed_kit
	var fight: CombatSim = K.sim(K.fight([K.at(kit, 3, 2)] as Array[UnitSetup],
		[K.foe(K.kit("mark", {"stats": {"hp": 100000, "speed": 0}, "basic_attack": {"cooldown_ms": 60000}}), 3, 4)] as Array[UnitSetup]))
	var tamsin: UnitState = fight.units[0]
	fight.unit_by_id("mark").pos = tamsin.pos + Vector2i(0, 400)
	Statuses.apply(fight, fight.unit_by_id("mark"), "root", 1, 2000, EffectSource.make("mark", "test", "Test"))
	K.step(fight, 200)
	var crits: Array = K.entries(fight, LogEntry.Kind.DAMAGE, tamsin.id).filter(func(entry: LogEntry) -> bool: return entry.crit and entry.source_ability == "knife")
	assert_gt(crits.size(), 0, "her Knife crits now and then")
	assert_gt(K.entries(fight, LogEntry.Kind.STATUS_EXTENDED, tamsin.id).size(), 0, "and each crit on the Rooted enemy holds it longer")
