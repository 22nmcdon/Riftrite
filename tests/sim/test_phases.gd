extends GutTest
## Enemy phases (docs/plans/act1-boss.md): HP-threshold phases built from
## specialization parts, and the Act 1 boss.

const K = preload("res://tests/sim/sim_test_kit.gd")
const FRONT := UnitSetup.Row.FRONT
const BACK := UnitSetup.Row.BACK


func _phase(data: Dictionary) -> Array:
	var errors: Array[String] = []
	var def: PhaseDef = PhaseDef.read(DataReader.new(data, "phase", errors), "boss")
	return [def, errors]


func _phases(list: Array) -> Array[PhaseDef]:
	var result: Array[PhaseDef] = []
	for data: Dictionary in list:
		var read: Array = _phase(data)
		assert_eq(read[1], [] as Array[String])
		result.append(read[0])
	return result


func _assert_error(errors: Array[String], expected: String) -> void:
	assert_true(errors.any(func(e: String) -> bool: return e.contains(expected)), "%s in %s" % [expected, errors])


## A boss with `phases`, and a hero who hits it for `hit` every second.
func _fight(phases: Array[PhaseDef], hit: int = 10, boss_hp: int = 100) -> CombatSim:
	var boss: UnitSetup = K.unit_with("boss", UnitStats.make(boss_hp, 10, 0, 10), FRONT, [], K.basic("idle", {"cooldown_ms": 60000, "effects": K.damage(1)}))
	boss.phases = phases
	var hero: UnitSetup = K.unit("hero", 100000, FRONT, [], K.basic("jab", {"effects": K.damage(hit)}))
	return CombatSim.new(FightSetup.make([hero] as Array[UnitSetup], [boss] as Array[UnitSetup]), K.content())


func _step_to(sim: CombatSim, tick: int) -> void:
	while sim.tick < tick and not sim.finished:
		sim.step()


func _phase_lines(sim: CombatSim) -> Array[String]:
	var lines: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.PHASE):
		lines.append(entry.to_text())
	return lines


# --- data ---------------------------------------------------------------------

func test_phases_read_and_reject() -> void:
	var good: Array = _phase({"name": "Molt", "below_hp_bp": 6000, "parts": [{"key": "fury", "kind": "aura", "target": "holder", "stat": "atsp_bp", "value": 13000}]})
	assert_eq(good[1], [] as Array[String])
	assert_eq([(good[0] as PhaseDef).below_hp_bp, (good[0] as PhaseDef).parts[0].label], [6000, "Molt"])
	_assert_error(_phase({"name": "Empty", "below_hp_bp": 5000})[1], "a phase needs parts")
	_assert_error(_phase({"name": "X", "below_hp_bp": 5000, "parts": [{"key": "b", "kind": "backup", "backup": {"cooldown_ms": 1000, "effects": K.damage(1)}}]})[1],
		"a phase can't have a backup part")
	_assert_error(_phase({"name": "X", "below_hp_bp": 5000, "parts": [
		{"key": "a", "kind": "aura", "when": "always", "target": "holder", "stat": "def_bp", "value": 11000}]})[1], "phase parts always apply on the field")
	_assert_error(_phase({"name": "X", "below_hp_bp": 0, "parts": []})[1], "below_hp_bp: 0 is out of range")


func test_enemy_phases_go_from_high_to_low() -> void:
	var enemies: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	for enemy: Dictionary in enemies:
		if enemy["id"] == "mother_ash":
			enemy["phases"].reverse()
			enemy["phases"][0]["parts"][0]["effects"][0]["status"] = "moonfire"
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	texts[ContentDb.ENEMIES_FILE] = JSON.stringify(enemies)
	var errors: Array[String] = ContentDb.load_texts(texts).errors
	_assert_error(errors, "phases go from the highest HP threshold to the lowest")
	_assert_error(errors, "unknown status \"moonfire\"")


# --- in a fight ---------------------------------------------------------------

func test_a_phase_begins_once_below_its_threshold() -> void:
	var sim: CombatSim = _fight(_phases([{"name": "Molt", "below_hp_bp": 6000, "parts": [
		{"key": "fury", "kind": "aura", "target": "holder", "stat": "atk_bp", "value": 15000}]}]))
	_step_to(sim, 80)
	assert_eq(_phase_lines(sim), [] as Array[String], "60 HP is not below 60%")
	assert_eq(sim.unit_by_id("boss").stats.get_stat(UnitStats.Stat.ATK), 10)
	_step_to(sim, 100)
	assert_eq(_phase_lines(sim), ["[5.00s] boss enters Molt"] as Array[String])
	assert_eq(sim.unit_by_id("boss").stats.get_stat(UnitStats.Stat.ATK), 15)
	_step_to(sim, 180)
	assert_eq(_phase_lines(sim).size(), 1, "only once")


func test_later_phases_add_and_replace_by_key() -> void:
	var sim: CombatSim = _fight(_phases([
		{"name": "One", "below_hp_bp": 9500, "parts": [
			{"key": "fury", "kind": "aura", "target": "holder", "stat": "atk_bp", "value": 15000},
			{"key": "hide", "kind": "aura", "target": "holder", "stat": "def_bp", "value": 20000}]},
		{"name": "Two", "below_hp_bp": 8500, "parts": [
			{"key": "fury", "kind": "aura", "target": "holder", "stat": "atk_bp", "value": 30000}]},
	]))
	_step_to(sim, 40)
	var boss: UnitState = sim.unit_by_id("boss")
	assert_eq(_phase_lines(sim), ["[1.00s] boss enters One", "[2.00s] boss enters Two"] as Array[String])
	assert_eq([boss.stats.get_stat(UnitStats.Stat.ATK), boss.stats.get_stat(UnitStats.Stat.DEF)], [30, 20], "Two's fury replaces One's; One's hide stays")
	var auras: Array[String] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.AURA):
		auras.append(entry.to_text())
	assert_true(auras.has("[2.00s] boss · One aura ends: x1.5 ATK for its holder"), str(auras))
	assert_true(auras.has("[2.00s] boss · Two aura starts: x3 ATK for its holder"), str(auras))


func test_crossing_several_thresholds_at_once() -> void:
	var sim: CombatSim = _fight(_phases([
		{"name": "One", "below_hp_bp": 6000, "parts": [{"key": "a", "kind": "aura", "target": "holder", "stat": "atk_bp", "value": 12000}]},
		{"name": "Two", "below_hp_bp": 3000, "parts": [{"key": "b", "kind": "aura", "target": "holder", "stat": "def_bp", "value": 12000}]},
	]), 80)  # 80 through 10 DEF lands 73: 100 HP drops to 27%, below both.
	_step_to(sim, 20)
	assert_eq(_phase_lines(sim), ["[1.00s] boss enters One", "[1.00s] boss enters Two"] as Array[String])


func test_no_phase_for_a_killing_blow() -> void:
	var sim: CombatSim = _fight(_phases([{"name": "Molt", "below_hp_bp": 6000, "parts": [
		{"key": "fury", "kind": "aura", "target": "holder", "stat": "atk_bp", "value": 15000}]}]), 150)
	_step_to(sim, 20)
	assert_eq(_phase_lines(sim), [] as Array[String])


func test_phase_abilities_start_with_the_phase() -> void:
	var sim: CombatSim = _fight(_phases([{"name": "Last Ember", "below_hp_bp": 6000, "parts": [
		{"key": "hide", "kind": "ability", "name": "Hide", "effects": [{"trigger": "on_fight_start", "type": "shield", "amount": 30, "target": "self"}]},
		{"key": "breath", "kind": "ability", "name": "Breath", "cooldown_ms": 1000, "effects": [
			{"trigger": "on_fire", "type": "apply_status", "status": "burn", "stacks": 2, "target": "all_enemies"}]}]}]))
	_step_to(sim, 120)
	var shields: Array[LogEntry] = sim.combat_log.of_kind(LogEntry.Kind.SHIELD)
	assert_eq([shields[0].tick, shields[0].amount, shields[0].source_text()], [100, 30, "boss · Hide (Last Ember)"])
	var burns: Array[int] = []
	for entry: LogEntry in sim.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED):
		burns.append(entry.tick)
	assert_eq(burns, [120] as Array[int], "the breath starts its cooldown when the phase begins")


func test_a_phase_can_change_the_basic_attack() -> void:
	var sim: CombatSim = _fight(_phases([{"name": "Maul", "below_hp_bp": 9500, "parts": [
		{"key": "maul", "kind": "basic_attack", "basic_attack": {"id": "maul", "name": "Maul", "cooldown_ms": 500, "effects": K.damage(3)}}]}]))
	_step_to(sim, 30)
	assert_eq(sim.unit_by_id("boss").items[0].def.id, "maul")
	assert_true(sim.combat_log.of_kind(LogEntry.Kind.FIRE).any(func(e: LogEntry) -> bool: return e.source_item == "maul" and e.tick == 30))


# --- the Act 1 boss -------------------------------------------------------------

func test_old_mother_ash() -> void:
	var content: ContentDb = K.content()
	var units: Array[UnitSetup] = SetupBuilder.encounter_units(content, "the_ash_mother")
	assert_eq([units[0].id, units[2].id, units[2].row], ["ash_hound_1", "mother_ash_3", BACK])
	assert_eq(units[2].phases.size(), 2)
	assert_true(content.items["pack_bond"].enemy_only and content.items["ember_maw"].enemy_only)
	var army: Array[UnitSetup] = []
	for hero_id: String in ["brannoc", "wren", "vell", "odo"]:
		var entries: Array[LoadoutEntry] = []
		for item_id: String in ["first_light_dagger", "hearth_knife", "dusk_tome"]:
			var entry := LoadoutEntry.new()
			entry.item_id = item_id
			entry.tier = 3
			entries.append(entry)
		army.append(SetupBuilder.hero(content, hero_id, 3, FRONT if hero_id != "odo" else BACK, entries))
	var result: FightResult = CombatSim.run(FightSetup.make(army, units, 2), content)
	assert_eq(result.errors, [] as Array[String])
	var text: String = result.combat_log.to_text()
	for expected: String in ["ash_hound_1 · Pack Bond aura starts: x1.25 DEF for all allies", "mother_ash_3 enters Molt", "mother_ash_3 enters Last Ember", "Ember Breath (Last Ember) applies 8 Burn"]:
		assert_string_contains(text, expected)
