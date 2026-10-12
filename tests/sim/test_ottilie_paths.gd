extends GutTest
## Ottilie's paths (phase 8 part 6, docs/plans/rebuild-phase8-last-heroes.md
## 8f-2; rebuild-heroes.md section 8i) in real fights: Brewing's vials,
## Catalyst's Reaction and Reaction Flask, Transmuter's Gilded Death and
## Philosopher's Flask, Apothecary's Tonic and Elixir, Volatile Flask as each
## one's habit, and each deed moving only with its taste.

const K = preload("res://tests/sim/sim_test_kit.gd")
const TEAM: Array[String] = ["brannoc", "maren", "ottilie"]
## Burn and Poison from her allies, for Catalyst and Transmuter.
const ROT: Array[String] = ["severine", "ilse", "ottilie"]
const PATHS: Array[String] = ["catalyst", "transmuter", "apothecary"]

var _content: ContentDb


func before_all() -> void:
	_content = K.content()


## A fight of Ottilie with `team`, on `path_id` ("" for her base kit;
## transformed if `transformed`), the encounter's enemies at `scale_bp`.
func _fight(encounter_id: String, path_id: String, transformed: bool, team: Array[String] = TEAM, scale_bp: int = 10000) -> CombatSim:
	var errors: Array[String] = []
	var vows: Dictionary[String, String] = {}
	if not path_id.is_empty():
		vows["ottilie"] = path_id
	var stages: Array[String] = []
	if transformed:
		stages.append("ottilie")
	var encounter: EncounterDef = _content.encounters[encounter_id]
	var keep: int = encounter.scale_bp
	encounter.scale_bp = FixedMath.apply_bp(keep, scale_bp)
	var formation: Dictionary[String, Vector2i] = HeroTeam.place(_content, team, HeroTeam.GUARDED)
	var setup: FightSetup = Encounters.setup(_content, encounter_id, formation, 1, errors, {}, vows, stages)
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


func _deed(sim: CombatSim, path_id: String) -> int:
	return CombatSim.result_of(sim).deed_amount("ottilie", path_id)


func test_ottilie_can_be_drafted() -> void:
	assert_true(HeroTeam.ready(_content, "ottilie"), "her three paths are built")
	for path_id: String in PATHS:
		var habit: PartDef = null
		for part: PartDef in _content.paths[path_id].transformed_kit.passives:
			if part.id == "volatile_flask":
				habit = part
		assert_not_null(habit, "%s keeps Volatile Flask as a habit" % path_id)
		assert_eq(habit.ability.effects[0].every, 6 if path_id == "transmuter" else 4, path_id)


func test_her_vials_ride_her_tosses() -> void:
	var sim: CombatSim = _fight("cairn_road", "", false)
	var vials: Array[LogEntry] = _of(sim, LogEntry.Kind.STATUS_APPLIED, "brewing")
	assert_gt(vials.filter(func(entry: LogEntry) -> bool: return entry.status == "burn").size(), 0, "fire vials")
	assert_gt(vials.filter(func(entry: LogEntry) -> bool: return entry.status == "poison").size(), 0, "and venom vials")
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "volatile_flask").size(), 0, "Volatile Flask")


func test_her_base_kit_fills_no_deed() -> void:
	var sim: CombatSim = _fight("cairn_road", "", false, ROT)
	for path_id: String in PATHS:
		assert_eq(_deed(sim, path_id), 0, "%s needs its taste" % path_id)


func test_catalyst_reacts() -> void:
	var vowed: CombatSim = _fight("cairn_road", "catalyst", false, ROT)
	var added: int = _of(vowed, LogEntry.Kind.DAMAGE, "toss").reduce(func(total: int, entry: LogEntry) -> int: return total + entry.part_bonus, 0) \
		+ _of(vowed, LogEntry.Kind.DAMAGE, "volatile_flask").reduce(func(total: int, entry: LogEntry) -> int: return total + entry.part_bonus, 0)
	assert_gt(_deed(vowed, "catalyst"), 0, "her allies' Burn and Poison feed Reaction")
	assert_eq(_deed(vowed, "catalyst"), added, "the deed counts what Reaction added")
	var sim: CombatSim = _fight("cairn_road", "catalyst", true, ROT)
	assert_eq(_of(sim, LogEntry.Kind.STATUS_APPLIED, "brewing").size(), 0, "Brewing stops")
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "reaction_flask").size(), 0, "Reaction Flask")
	var flask: Array[LogEntry] = _of(sim, LogEntry.Kind.DAMAGE, "reaction_flask")
	assert_gt(flask.size(), 0, "and it hits")
	assert_gt(_of(sim, LogEntry.Kind.AREA_LANDED, "volatile_flask").size(), 0, "Volatile Flask is a habit")


func test_transmuter_gilds_the_dead() -> void:
	var vowed: CombatSim = _fight("cairn_road", "transmuter", false, ROT, 7500)
	var paid: Array[LogEntry] = _of(vowed, LogEntry.Kind.SHARDS, "gilded_death")
	assert_gt(paid.size(), 0, "enemies falling Burning and Poisoned pay")
	var kept: int = paid.filter(func(entry: LogEntry) -> bool: return not entry.capped).reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)
	assert_lte(kept, 3, "up to 3 a fight")
	assert_eq(_deed(vowed, "transmuter"), kept)
	var sim: CombatSim = _fight("cairn_road", "transmuter", true, ROT, 7500)
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "philosophers_flask").size(), 0, "Philosopher's Flask")
	var all_paid: int = sim.combat_log.of_kind(LogEntry.Kind.SHARDS).filter(func(entry: LogEntry) -> bool: return entry.source_unit == "ottilie" and not entry.capped) \
		.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0)
	assert_lte(all_paid, 8, "up to 8 a fight")
	assert_eq(_content.paths["transmuter"].transformed_transmute.per_shop, 1, "and she transmutes once a shop")


func test_apothecary_tonics_her_allies() -> void:
	var vowed: CombatSim = _fight("cairn_road", "apothecary", false)
	var given: Array[LogEntry] = _of(vowed, LogEntry.Kind.MANA_GIVEN, "tonic")
	assert_gt(given.size(), 0, "her Toss throws mana vials")
	assert_false(given.any(func(entry: LogEntry) -> bool: return entry.target == "ottilie"), "to her allies")
	@warning_ignore("integer_division")
	assert_eq(_deed(vowed, "apothecary"), given.reduce(func(total: int, entry: LogEntry) -> int: return total + entry.amount, 0) / Mana.SCALE)
	var sim: CombatSim = _fight("cairn_road", "apothecary", true)
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "tonic").filter(func(entry: LogEntry) -> bool: return entry.status == "tonic_rush").size(), 0, "the vial quickens its ally")
	assert_gt(_of(sim, LogEntry.Kind.FIRE, "elixir").size(), 0, "Elixir")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "elixir").filter(func(entry: LogEntry) -> bool: return entry.status == "elixir").size(), 2, "on every ally")
	assert_gt(_of(sim, LogEntry.Kind.STATUS_APPLIED, "brewing").size(), 0, "Brewing stays")
