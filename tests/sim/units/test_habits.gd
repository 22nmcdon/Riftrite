extends GutTest
## Habits (phase 8 part 4, docs/plans/rebuild-phase8-heroes.md section 3b;
## rebuild-heroes.md section 3): a transformation that replaces a hero's
## signature keeps the old one as a passive on every Nth basic attack, with
## the old signature's id. It isn't a signature: no mana, no FIRE of it.

const K = preload("res://tests/sim/sim_test_kit.gd")

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of the three with `hero_id` transformed on `path_id`.
func _transformed(encounter_id: String, hero_id: String, path_id: String) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {hero_id: path_id}
	var transformed: Array[String] = [hero_id]
	var setup: FightSetup = Encounters.setup(_content, encounter_id, PracticeSession.DEFAULT_FORMATION, 1, errors, {}, vows, transformed)
	assert_eq(errors, [] as Array[String])
	var sim: CombatSim = CombatSim.new(setup, _content)
	while not sim.finished:
		sim.step()
	return sim


## How many times `unit_id`'s basic attack fired, and its habit `habit_id`
## landed (an apply_status's or an area's lines, one per fire).
func _counts(sim: CombatSim, unit_id: String, habit_id: String, kind: LogEntry.Kind) -> Array[int]:
	var attacks: int = 0
	var habits: int = 0
	var basic: String = sim.unit_by_id(unit_id).def.basic_attack.id
	for entry: LogEntry in sim.combat_log.entries:
		if entry.source_unit != unit_id:
			continue
		if entry.kind == LogEntry.Kind.FIRE and entry.source_ability == basic:
			attacks += 1
		if entry.kind == kind and entry.source_ability == habit_id:
			habits += 1
	return [attacks, habits]


func test_every_replaced_signature_is_a_habit() -> void:
	for path_id: String in _content.path_ids:
		var path: PathDef = _content.paths[path_id]
		var base: UnitDef = _content.heroes[path.hero].kit
		if path.transformed_kit.signature != null and path.transformed_kit.signature.id == base.signature.id:
			continue
		var wanted: String = path.habit if not path.habit.is_empty() else base.signature.id
		var habit: Array[PartDef] = path.transformed_kit.passives.filter(func(part: PartDef) -> bool: return part.id == wanted)
		assert_eq(habit.size(), 1, "%s keeps %s as a habit" % [path_id, wanted])
		if habit.is_empty():
			continue
		for effect: EffectDef in habit[0].ability.effects:
			assert_eq(effect.trigger, EffectDef.Trigger.ON_BASIC_ATTACK, "%s's habit fires on its basic attacks" % path_id)
			assert_true(effect.every in [4, 6, 8], "%s's habit: every 4th, 6th, or 8th" % path_id)
	var kit: UnitDef = _content.paths["hearthwall"].transformed_kit
	var without: UnitDef = DefCopy.shallow(kit) as UnitDef
	without.passives = kit.passives.filter(func(part: PartDef) -> bool: return part.id != "hold_the_line")
	var errors_before: int = _content.errors.size()
	_content._check_habit(_content.heroes["brannoc"].kit, without, "", "hearthwall")
	assert_eq(_content.errors.slice(errors_before), ["hearthwall: it replaces Hold the Line, so it needs its habit (a passive \"hold_the_line\")"],
		"the content refuses a path that forgets it")
	_content.errors.resize(errors_before)


func test_brannocs_habit_taunts_every_8th_bash() -> void:
	var sim: CombatSim = _transformed("the_pack", "brannoc", "hearthwall")
	var counts: Array[int] = _counts(sim, "brannoc", "hold_the_line", LogEntry.Kind.AREA_LANDED)
	assert_gt(counts[0], 8, "he bashes")
	@warning_ignore("integer_division")
	assert_eq(counts[1], counts[0] / 8, "a habit every 8th Shield Bash")
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.FIRE):
		assert_false(entry.source_unit == "brannoc" and entry.source_ability == "hold_the_line", "a habit is no signature: it never FIREs")


func test_marens_habit_marks_her_target_every_8th_shot() -> void:
	var sim: CombatSim = _transformed("the_pack", "maren", "volley")
	var counts: Array[int] = _counts(sim, "maren", "marking_shot", LogEntry.Kind.STATUS_APPLIED)
	assert_gt(counts[0], 8, "she shoots")
	@warning_ignore("integer_division")
	assert_eq(counts[1], counts[0] / 8, "a Mark every 8th Longshot")
