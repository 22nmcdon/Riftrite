extends GutTest
## Enemy specializations (docs/plans/rebuild-phase8-act2.md, part 8c-3a):
## the data, the draw (half of a day fight's enemies from the act's day, fresh
## on each attempt), the fight's kits and names, the save, and the fight
## card's line. On stand-in acts (tests/run/test_acts.gd) whose Act 2
## specializes from day 3.

const Bot = preload("res://tools/run_bot.gd")
const ActsTest = preload("res://tests/run/test_acts.gd")
const K = preload("res://tests/sim/sim_test_kit.gd")

var _run: RunContent


static func specialized_acts() -> RunContent:
	var run: RunContent = ActsTest.stand_in_acts()
	run.acts[1].specialized_from_day = 3
	return run


func before_all() -> void:
	_run = specialized_acts()


## A flow on Act 2's day `day`, its fights drawn and the day started.
func _on_day(day: int, run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	flow.state.act = 2
	flow.state.day = day
	flow.state.options = ActDraw.draw(_run, run_seed, _run.acts[1])
	flow._start_day()
	return flow


func test_the_data() -> void:
	var content: ContentDb = _run.content
	assert_eq(content.errors, [] as Array[String])
	for id: String in ["gnawing_pup", "smoldering_ashling", "bulwark_guardian", "deep_lurker", "rot_lurker", "hex_witch"]:
		assert_true(content.specializations.has(id), id)
	for enemy_id: String in content.enemy_ids:
		assert_lte(content.enemies[enemy_id].specializations.size(), SpecializationDef.PER_ENEMY)
	var pup: UnitDef = content.enemies["rift_pup"].kit
	var gnawing: UnitDef = content.specializations["gnawing_pup"].apply(pup)
	assert_eq(gnawing.name, "Gnawing Rift Pup")
	assert_eq(gnawing.specialization, "gnawing_pup")
	assert_eq(gnawing.basic_attack.effects.size(), pup.basic_attack.effects.size() + 1, "its bite adds Bleed")
	assert_eq([pup.name, pup.specialization], ["Rift Pup", ""], "the enemy's own kit is untouched")


func test_a_specialization_must_change_something() -> void:
	var texts: Dictionary[String, String] = {}
	for file_name: String in ContentDb.FILES:
		texts[file_name] = FileAccess.get_file_as_string("res://data".path_join(file_name))
	var enemies: Array = JSON.parse_string(texts[ContentDb.ENEMIES_FILE])
	for entry: Variant in enemies:
		if entry is Dictionary and (entry as Dictionary).get("id", "") == "rift_pup":
			(entry["specializations"] as Array).append({"id": "idle_pup", "name": "Idle", "text": "It does nothing new.", "mod": {}})
	texts[ContentDb.ENEMIES_FILE] = JSON.stringify(enemies)
	var content: ContentDb = ContentDb.load_texts(texts)
	assert_true(content.errors.any(func(error: String) -> bool: return error.contains("idle_pup") and error.contains("changes something")), str(content.errors))


func test_none_before_the_acts_day_or_in_act_1() -> void:
	var flow: RunFlow = RunFlow.start(_run, 7, Bot.first_vows(_run.content), [] as Array[String])
	assert_true(flow.state.today_specs.all(func(specs: Array) -> bool: return specs.all(func(id: Variant) -> bool: return str(id).is_empty())), "Act 1 specializes none")
	var early: RunFlow = _on_day(2)
	assert_true(early.state.today_specs.all(func(specs: Array) -> bool: return specs.all(func(id: Variant) -> bool: return str(id).is_empty())), "Act 2 from day 3")


func test_half_of_a_fights_enemies_from_day_3() -> void:
	for day: int in [3, 4, 6]:
		var flow: RunFlow = _on_day(day)
		var today: Array[String] = flow.state.today()
		assert_eq(flow.state.today_specs.size(), today.size())
		for i: int in today.size():
			var encounter: EncounterDef = _run.content.encounters[today[i]]
			var eligible: int = encounter.enemies.filter(func(placed: EncounterDef.Placed) -> bool: return not _run.content.enemies[placed.enemy].specializations.is_empty()).size()
			var drawn: Array = flow.state.today_specs[i]
			assert_eq(drawn.size(), encounter.enemies.size())
			assert_eq(drawn.filter(func(id: Variant) -> bool: return not str(id).is_empty()).size(), mini(encounter.enemies.size() / 2, eligible), "day %d, %s" % [day, encounter.id])
			for j: int in drawn.size():
				if not str(drawn[j]).is_empty():
					assert_eq(_run.content.specializations[str(drawn[j])].enemy, encounter.enemies[j].enemy, "its own enemy's")


func test_the_draw_repeats_and_is_fresh_on_a_replay() -> void:
	var first: RunFlow = _on_day(4)
	assert_eq(_on_day(4).state.today_specs, first.state.today_specs, "the same seed and day, the same draw")
	var changed: bool = false
	for run_seed: int in range(1, 10):
		for day: int in [4, 6]:
			var flow: RunFlow = _on_day(day, run_seed)
			var before: Array = flow.state.today_specs.duplicate(true)
			flow.state.attempt = 1
			flow._start_day()
			changed = changed or flow.state.today_specs != before
	assert_true(changed, "a replay after a loss draws afresh")


func test_the_fight_has_the_specialized_kits() -> void:
	var flow: RunFlow = null
	for run_seed: int in range(1, 30):
		flow = _on_day(4, run_seed)
		if flow.state.today_specs[0].any(func(id: Variant) -> bool: return not str(id).is_empty()):
			break
	var drawn: Array = flow.state.today_specs[0]
	assert_true(drawn.any(func(id: Variant) -> bool: return not str(id).is_empty()), "a seed with one")
	assert_eq(flow.choose_fight(0), "")
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	for i: int in drawn.size():
		var spec_id: String = str(drawn[i])
		assert_eq(setup.enemies[i].def.specialization, spec_id)
		if not spec_id.is_empty():
			var spec: SpecializationDef = _run.content.specializations[spec_id]
			assert_eq(setup.enemies[i].def.name, "%s %s" % [spec.name, _run.content.enemies[spec.enemy].name])
	var refused: Array[String] = []
	var encounter: String = flow.state.chosen
	Encounters.setup(_run.content, encounter, Bot.formation(), 1, refused, {}, {}, [], {}, {}, [], {0: "no_such"} as Dictionary[int, String])
	assert_false(refused.is_empty(), "an unknown specialization is refused")


func test_the_save_keeps_them() -> void:
	var flow: RunFlow = _on_day(4)
	var data: Dictionary = JSON.parse_string(JSON.stringify(flow.state.to_dict()))
	assert_eq(int(data["version"]), RunState.VERSION)
	var loaded: RunState = RunState.from_dict(data)
	assert_eq(loaded.today_specs, flow.state.today_specs)
	data["version"] = 7
	data.erase("today_specs")
	assert_eq(RunState.from_dict(data).today_specs, [] as Array[Array], "a version 7 save has none")


func test_the_fight_cards_line() -> void:
	var encounter: EncounterDef = _run.content.encounters["pup_warren"]
	var drawn: Array = ["gnawing_pup", "", "gnawing_pup", "", "", ""]
	assert_eq(RunDayScreen.specs_line(_run.content, encounter, drawn), "Specialized: 2 Gnawing Rift Pups: Its bites make you Bleed, and the Bleed stacks.")
	assert_eq(RunDayScreen.specs_line(_run.content, encounter, ["", "", "", "", "", ""]), "")


## Brannoc, Maren, and Vell on `encounter_id`, with `specs` (enemy index ->
## specialization id).
func _fight(encounter_id: String, specs: Dictionary[int, String]) -> CombatSim:
	var content: ContentDb = _run.content
	var errors: Array[String] = []
	var formation: Dictionary[String, Vector2i] = {"brannoc": Vector2i(3, 2), "maren": Vector2i(3, 0), "vell": Vector2i(4, 0)}
	var setup: FightSetup = Encounters.setup(content, encounter_id, formation, 1, errors, {}, {}, [], {}, {}, [], specs)
	assert_eq(errors, [] as Array[String])
	assert_eq(setup.validate(content), [] as Array[String])
	return CombatSim.new(setup, content)


func test_a_burrowing_pup_comes_up_beside_the_hindmost_hero() -> void:
	var fight: CombatSim = _fight("stray_pups", {0: "burrowing_pup"} as Dictionary[int, String])
	var pup: UnitState = fight.enemies[0]
	assert_false(pup.alive, "burrowed at the start")
	assert_true(pup.arriving)
	for i: int in 59:
		fight.step()
	assert_false(pup.alive, "still under at 2.95s")
	# The hindmost hero as it comes up (the arrival is early in the tick).
	var hindmost: UnitState = fight.heroes[0]
	for hero: UnitState in fight.heroes:
		if hero.pos.y < hindmost.pos.y:
			hindmost = hero
	var there: Vector2i = hindmost.pos
	fight.step()
	assert_true(pup.alive, "up at 3s")
	var arrived: Array[LogEntry] = fight.combat_log.of_kind(LogEntry.Kind.ARRIVE)
	assert_eq(arrived.size(), 1)
	assert_eq([arrived[0].target, arrived[0].source_ability_name], [pup.id, "Burrow"])
	assert_lt(ArenaPlane.distance(arrived[0].to_pos, there), 500, "beside the hindmost hero")
	assert_true(fight.enemies[1].alive, "the others never burrowed")


func test_an_avalanche_guardian_carries_every_hero_in_its_line() -> void:
	var content: ContentDb = _run.content
	var kit: UnitDef = content.specializations["avalanche_guardian"].apply(content.enemies["cairn_guardian"].kit)
	assert_true(kit.signature.effects[0].carries)
	assert_string_contains(" · ".join(UnitInfo.effect_numbers(kit.signature.effects, kit, content)), "carrying every enemy in its line 2 hexes")
	var charge: Dictionary = {"id": "rush", "name": "Rush", "trigger": {"kind": "fight_start"}, "targeting": "farthest", "max_range": 6,
		"effects": [{"type": "charge", "hexes": 6, "knockback": 1, "carries": true, "target": "target"}]}
	var still: Dictionary = {"stats": {"hp": 900, "speed": 0}, "basic_attack": {"cooldown_ms": 60000}}
	var guardian: UnitDef = K.kit("guardian", {"stats": {"hp": 900, "speed": 0}, "basic_attack": {"cooldown_ms": 60000}, "signature": charge})
	var setup: FightSetup = K.fight([K.at(K.kit("near", still), 3, 2), K.at(K.kit("far", still), 3, 0)] as Array[UnitSetup], [K.foe(guardian, 3, 4)] as Array[UnitSetup])
	var fight: CombatSim = K.sim(setup)
	K.step(fight, 2)
	var pushed: Array = fight.combat_log.of_kind(LogEntry.Kind.PUSH).map(func(entry: LogEntry) -> String: return entry.target)
	assert_eq(pushed, ["far", "near"], "both, the farthest first")
	assert_eq(fight.combat_log.of_kind(LogEntry.Kind.CHARGE).size(), 1)


func test_a_veil_witch_hides_an_ally_instead_of_shielding() -> void:
	var content: ContentDb = _run.content
	var kit: UnitDef = content.specializations["veil_witch"].apply(content.enemies["gloam_witch"].kit)
	var ids: Array = kit.passives.map(func(part: PartDef) -> String: return part.id)
	assert_eq(ids, ["veil"], "Ward is gone, Veil is in")
	assert_string_contains(ModInfo.mod_numbers(content.specializations["veil_witch"].mod, content.enemies["gloam_witch"].kit, content), "no Ward")
	var fight: CombatSim = _fight("witch_and_pups", {0: "veil_witch"} as Dictionary[int, String])
	for i: int in 200:
		fight.step()
	var hidden: Array[LogEntry] = fight.combat_log.of_kind(LogEntry.Kind.STATUS_APPLIED).filter(func(entry: LogEntry) -> bool: return entry.status == "stealth")
	assert_false(hidden.is_empty(), "it hides an ally")
	assert_eq(hidden[0].source_ability, "veil")
	assert_eq(fight.combat_log.of_kind(LogEntry.Kind.SHIELD).filter(func(entry: LogEntry) -> bool: return entry.source_ability == "ward"), [] as Array[LogEntry], "and never shields")
