extends GutTest
## Lucan's paths (phase 8 part 6, docs/plans/phases/rebuild-phase8-last-heroes.md
## 8f-4; rebuild-heroes.md section 8j) in real fights: Mirrorwright's
## Reflection and Hall of Mirrors, Veilweaver's Shroud, Veiled Strike, and
## Vanishing Act, Puppeteer's Strings and Dance of Strings, Mirror as each
## one's habit, and each deed moving only with its taste.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["brannoc", "maren", "lucan"]
const PATHS: Array[String] = ["mirrorwright", "veilweaver", "puppeteer"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Lucan with `team`, on `path_id` ("" for his base kit;
## transformed if `transformed`).
func _fight(encounter_id: String, path_id: String, transformed: bool, team: Array[String] = TEAM) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {}
	if not path_id.is_empty():
		vows["lucan"] = path_id
	var stages: Array[String] = []
	if transformed:
		stages.append("lucan")
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, stages)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


## `kind` entries sourced to Lucan's `ability_id`.
func _of(sim: CombatSim, kind: LogEntry.Kind, ability_id: String) -> Array[LogEntry]:
	var found: Array[LogEntry] = []
	for entry: LogEntry in sim.combat_log.of_kind(kind):
		if entry.source_unit == "lucan" and entry.source_ability == ability_id:
			found.append(entry)
	return found


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("lucan", path_id)


func test_lucan_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "lucan"), "his three paths are built")
	for path_id: String in PATHS:
		var habit: PartDef = null
		for part: PartDef in _content.paths[path_id].transformed_kit.passives:
			if part.id == "mirror":
				habit = part
		assert_not_null(habit, "%s keeps Mirror as a habit" % path_id)
		assert_eq(habit.ability.effects[0].every, 4 if path_id == "puppeteer" else 8, path_id + " (Puppeteer's every 4th: more strings to pull)")


func test_his_base_kit_fills_no_deed() -> void:
	var sim: CombatSim = _fight("cairn_road", "", false)
	for path_id: String in PATHS:
		assert_eq(_deed(sim, path_id), 0, "%s needs its taste" % path_id)


func test_mirrorwright_fills_the_field_with_himself() -> void:
	var vowed: CombatSim = _fight("cairn_road", "mirrorwright", false)
	var reflected: Array[LogEntry] = _of(vowed, LogEntry.Kind.SUMMON, "reflection")
	assert_gt(reflected.size(), 0, "Reflection")
	assert_eq(reflected[0].tick, 12 * 20, "every 12s")
	assert_eq(reflected[0].end_tick - reflected[0].tick, 4 * 20, "for 4s")
	assert_eq(_deed(vowed, "mirrorwright"), reflected.filter(func(entry: LogEntry) -> bool: return entry.note.is_empty()).size(), "the deed counts Reflection's copies")
	var sim: CombatSim = _fight("cairn_road", "mirrorwright", true)
	var hall: Array[LogEntry] = _of(sim, LogEntry.Kind.SUMMON, "hall_of_mirrors")
	assert_gt(hall.size(), 0, "Hall of Mirrors")
	assert_true(hall.any(func(entry: LogEntry) -> bool: return entry.target.begins_with("brannoc_copy")), "a copy of each ally")
	assert_gt(_of(sim, LogEntry.Kind.SUMMON, "mirror").size(), 0, "Mirror is a habit")
	var most: int = 0
	var fight: CombatSim = CombatSim.new(sim.setup, _content)
	while not fight.finished:
		fight.step()
		var standing: int = fight.units.filter(func(unit: UnitState) -> bool: return unit.alive and unit.def.id == "lucan_copy").size()
		most = maxi(most, standing)
	assert_between(most, 2, 5, "his copies, Reflection's capped at 3 (with Mirror's and the Hall's of him)")


func test_veilweaver_hides_the_threatened() -> void:
	var vowed: CombatSim = _fight("cairn_road", "veilweaver", false)
	var shrouds: Array[LogEntry] = _of(vowed, LogEntry.Kind.STATUS_APPLIED, "shroud")
	assert_gt(shrouds.size(), 0, "Shroud")
	assert_eq(shrouds[0].tick, 10 * 20, "every 10s")
	assert_eq(_deed(vowed, "veilweaver"), shrouds.size(), "the deed counts Shroud's Stealth")
	var sim: CombatSim = _fight("cairn_road", "veilweaver", true)
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "shroud").size(), shrouds.size(), "every 5s")
	var struck: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.DAMAGE).filter(func(entry: LogEntry) -> bool: return entry.from_stealth)
	assert_gt(struck.size(), 0, "strikes from Stealth")
	assert_gt(struck.filter(func(entry: LogEntry) -> bool: return entry.rule_power >= 6000).size(), struck.size() / 2, "most of them 60% harder (a Stealth set in the strike's own tick counts from the next)")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "hush").filter(func(entry: LogEntry) -> bool: return entry.status == "silence").size(), 0, "and Silencing")
	var vanished: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "vanishing_act")
	assert_true(vanished.any(func(entry: LogEntry) -> bool: return entry.status == "vanished" and entry.target == "maren"), "Vanishing Act hides every ally")
	assert_true(struck.any(func(entry: LogEntry) -> bool: return entry.rule_crit > 0), "and their next attack crits")
	var habit: Array[LogEntry] = _of(sim, LogEntry.Kind.SUMMON, "mirror")
	assert_gt(habit.size(), 0)
	assert_eq(habit[0].end_tick - habit[0].tick, 3 * 20, "Mirror's copy lasts only 3s")


func test_puppeteer_pulls_every_string() -> void:
	var vowed: CombatSim = _fight("cairn_road", "puppeteer", false)
	var glimmers: Array[LogEntry] = _of(vowed, LogEntry.Kind.DAMAGE, "glimmer")
	assert_eq(glimmers[0].rule_power, 3 * 200, "2% for each of the three heroes")
	assert_gt(_deed(vowed, "puppeteer"), 0, "Strings adds to his Glimmer")
	assert_eq(_deed(vowed, "puppeteer"), glimmers.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.part_bonus, 0))
	var sim: CombatSim = _fight("cairn_road", "puppeteer", true)
	assert_eq(sim.unit_by_id("lucan").def.stats.get_stat(UnitStats.Stat.RANGE), 2, "Glimmer reaches 2 hexes")
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "dance_of_strings").size(), 0, "Dance of Strings")
	var danced: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "dance_of_strings")
	assert_gt(danced.size(), 0)
	assert_false(danced.any(func(entry: LogEntry) -> bool: return entry.target in TEAM), "only the summons")
	var fight: CombatSim = CombatSim.new(sim.setup, _content)
	var copy: UnitState = null
	while copy == null and not fight.finished:
		fight.step()
		var copies: Array[UnitState] = fight.units.filter(func(unit: UnitState) -> bool: return unit.alive and unit.def.id == "lucan_copy")
		copy = copies[0] if not copies.is_empty() else null
	fight.step()
	assert_eq(copy.stats.get_stat(UnitStats.Stat.MGK), FixedMath.apply_bp(copy.def.stats.get_stat(UnitStats.Stat.MGK), 11000), "allied summons get 10% more MGK")
