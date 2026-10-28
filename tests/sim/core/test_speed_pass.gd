extends GutTest
## The speed pass's shortcuts (after the clean-up): the tables and caches that
## stand in for work the sim used to repeat each tick give what that work
## gives. The bench's fingerprints (tools/bench/bench_sim.gd) check the
## fights didn't change; these check the shortcuts themselves.

const K = preload("res://tests/sim/sim_test_kit.gd")
const Chaos = preload("res://tests/sim/chaos_fight.gd")
const Practice = preload("res://tools/bots/practice.gd")
const Bot = preload("res://tools/bots/bot.gd")


func test_the_aura_tables_match_aura_def() -> void:
	var keys: Array[int] = []
	keys.assign(AuraDef.UNIT_STAT_FOR.keys())
	keys.sort()
	assert_eq(Passives._UNIT_STAT_AURAS, keys, "rederive's stats are UNIT_STAT_FOR's, in order")
	var wrong: Array[int] = []
	for stat: int in AuraDef.Stat.size():
		if Passives._is_additive(stat) != AuraDef.ADDITIVE.has(stat):
			wrong.append(stat)
	assert_eq(wrong, [] as Array[int], "the additive table is AuraDef.ADDITIVE")
	var first: Array[int] = Passives.no_auras()
	first[0] += 5
	assert_ne(Passives.no_auras()[0], first[0], "each unit gets its own copy")


func test_statuses_kinds_names_each_kind_and_a_focus() -> void:
	var fight: CombatSim = K.sim(Chaos.setup())
	var unit: UnitState = fight.heroes[0]
	unit.statuses.clear()
	assert_eq(Statuses.kinds(unit), 0)
	var stun := StatusState.new()
	stun.def = StatusDef.new()
	stun.def.kind = StatusDef.Kind.STUN
	var focus := StatusState.new()
	focus.def = StatusDef.new()
	focus.def.kind = StatusDef.Kind.BOOST
	focus.def.focus = true
	unit.statuses.append(stun)
	unit.statuses.append(focus)
	assert_eq(Statuses.kinds(unit), (1 << StatusDef.Kind.STUN) | (1 << StatusDef.Kind.BOOST) | Statuses.FOCUS_BIT)


func test_fixed_auras_change_as_aura_change_says() -> void:
	# The chaos fight, and the bench's late Act 3 run state: a full team's
	# relics, upgrades, items, and an apex.
	var fights: Array[CombatSim] = [K.sim(Chaos.setup())]
	var run: RunContent = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))
	var flow: RunFlow = RunFlow.resume(run, RunState.from_dict(JSON.parse_string(FileAccess.get_file_as_string("res://tools/bench/states/act3_day6.json"))))
	var hexes: Dictionary[String, Vector2i] = Practice.place(flow)
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(hexes, errors, Bot.default_markers(flow, hexes))
	assert_eq(errors, [] as Array[String])
	fights.append(CombatSim.new(setup, run.content))
	var fixed: int = 0
	var wrong: Array[String] = []
	for fight: CombatSim in fights:
		for tick: int in 40:
			fight.step()
		for unit: UnitState in fight.units:
			for a: int in unit.aura_parts.size():
				var aura: AuraDef = unit.aura_parts[a].aura
				var flags: int = unit.aura_flags[a]
				if flags & Passives.AURA_FIXED != 0:
					fixed += 1
					if unit.aura_fixed[a] != Passives.aura_change(fight, unit, aura):
						wrong.append(unit.aura_keys[a])
				if flags & Passives.AURA_ALWAYS != 0 and not aura.active_at(fight.tick):
					wrong.append(unit.aura_keys[a] + " (window)")
				if (flags & Passives.AURA_CONDITIONAL != 0) != aura.is_conditional() or (flags & Passives.AURA_PER_HIT != 0) != aura.is_per_hit():
					wrong.append(unit.aura_keys[a] + " (flags)")
	assert_gt(fixed, 20, "the loaded team has plenty")
	assert_eq(wrong, [] as Array[String])
