extends GutTest
## A Rift Tear's depths and the rift modifiers (docs/plans/rebuild-phase5c-
## combos.md, step 8b, section 16.5): choosing a depth, the day's modifiers,
## each modifier on tomorrow's fight, each depth's relics, and Early
## Collapse and Reinforcements in a fight.

const Bot = preload("res://tools/run_bot.gd")
const K = preload("res://tests/sim/sim_test_kit.gd")

var _run: RunContent


func before_all() -> void:
	_run = RunContent.load_dir("res://data", ContentDb.load_dir("res://data"))


func _start(run_seed: int = 7) -> RunFlow:
	var errors: Array[String] = []
	var flow: RunFlow = RunFlow.start(_run, run_seed, Bot.first_vows(_run.content), errors)
	assert_eq(errors, [] as Array[String])
	return flow


## A flow in a Rift Tear node on `day`.
func _at_tear(day: int = 1, run_seed: int = 7) -> RunFlow:
	var flow: RunFlow = _start(run_seed)
	flow.state.day = day
	flow.state.phase = RunState.Phase.NODES
	flow.state.nodes.assign(["camp", "rift_tear"])
	assert_eq(flow.choose_node(1), "")
	return flow


## A flow at tomorrow's fight (its first option; the tear taken on `day`)
## with `mods` as the tear's modifiers.
func _torn(mods: Array[String], day: int = 1) -> RunFlow:
	var flow: RunFlow = _at_tear(day)
	flow.choose_depth(0)
	flow.state.rift_mods.assign(mods)
	flow.leave_node()
	flow.choose_fight(0)
	return flow


func _setup_of(flow: RunFlow) -> FightSetup:
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	return setup


func _torn_setup(mods: Array[String], day: int = 1) -> FightSetup:
	return _setup_of(_torn(mods, day))


func _won() -> FightResult:
	var result := FightResult.new()
	result.outcome = FightResult.Outcome.VICTORY
	result.end_tick = 600
	return result


func _has_passive(kit: UnitDef, id: String) -> bool:
	return kit.passives.any(func(part: PartDef) -> bool: return part.id == id)


func test_the_depths_and_the_modifiers_load() -> void:
	assert_eq(_run.camps.depths.map(func(depth: CampsDef.Depth) -> String: return depth.id), ["shallow", "deep", "abyssal"])
	assert_eq(_run.camps.depths.map(func(depth: CampsDef.Depth) -> int: return depth.modifiers), [0, 1, 2])
	assert_eq(_run.camps.modifier_ids, ["hastened", "hardened", "rift_charged", "bloodthirst", "thornskin", "nightfall", "blood_frenzy", "blight",
		"early_collapse", "reinforcements"] as Array[String])


func test_choosing_a_depth() -> void:
	var flow: RunFlow = _at_tear()
	var state: RunState = flow.state
	assert_eq(state.rift_depth, "", "nothing until a depth is chosen")
	assert_eq(flow.leave_node(), "choose a depth first")
	assert_eq(flow.choose_depth(3), "there's no depth 3")
	var drawn: Array[String] = Offers.rift_modifiers(_run, state)
	assert_eq(drawn.size(), 2)
	assert_ne(drawn[0], drawn[1], "two different modifiers")
	assert_eq(flow.choose_depth(2), "")
	assert_eq([state.rift_depth, state.rift_mods], ["abyssal", drawn], "Abyssal: both of the day's")
	assert_eq(flow.choose_depth(1), "the depth is chosen (abyssal)")
	var deep: RunFlow = _at_tear()
	deep.choose_depth(1)
	assert_eq(deep.state.rift_mods, [drawn[0]] as Array[String], "Deep: the first, as its card showed")
	assert_eq(flow.choose_depth(0), "the depth is chosen (abyssal)")
	assert_eq(_start().choose_depth(0), "can't choose a depth now (the day is at route)")
	var seen: Dictionary[String, bool] = {}
	for day: int in range(1, 7):
		for run_seed: int in range(1, 11):
			for id: String in Offers.rift_modifiers(_run, _at_tear(day, run_seed).state):
				seen[id] = true
	assert_eq(seen.size(), _run.camps.modifier_ids.size(), "every modifier comes up")


func test_each_depth_pays_its_relics() -> void:
	var expected: Array = [["rare", "rare"], ["epic", "epic"], ["legendary", "epic"]]
	for i: int in 3:
		var flow: RunFlow = _at_tear()
		flow.choose_depth(i)
		flow.leave_node()
		flow.choose_fight(0)
		flow.record(Bot.formation(), _won())
		assert_eq(flow.state.relic_choice.map(func(id: String) -> String: return RelicDef.TIER_NAMES[_run.relics[id].tier]), expected[i], _run.camps.depths[i].id)
		assert_eq(flow.state.rift_depth, "", "spent once won")


func test_the_shield_on_every_depth() -> void:
	var setup: FightSetup = _torn_setup([] as Array[String])
	assert_true(setup.enemies.all(func(enemy: UnitSetup) -> bool: return _has_passive(enemy.def, "rift_warded")))
	var sim := CombatSim.new(setup, _run.content)
	sim.step()
	sim.step()
	var enemy: UnitState = sim.enemies[0]
	assert_eq(enemy.shield, FixedMath.apply_bp(enemy.max_hp, 1000), "a tenth of its max HP")


func test_each_modifier_reaches_the_fight() -> void:
	var plain: FightSetup = _torn_setup([] as Array[String])
	var kit: UnitDef = plain.enemies[0].def
	var checks: Dictionary = {
		"hastened": func(setup: FightSetup) -> bool: return _has_passive(setup.enemies[0].def, "rift_hastened"),
		"hardened": func(setup: FightSetup) -> bool: return setup.enemies[0].def.stats.get_stat(UnitStats.Stat.DEF) == FixedMath.apply_bp(kit.stats.get_stat(UnitStats.Stat.DEF), 12000),
		"bloodthirst": func(setup: FightSetup) -> bool: return _has_passive(setup.enemies[0].def, "rift_bloodthirst"),
		"thornskin": func(setup: FightSetup) -> bool: return _has_passive(setup.enemies[0].def, "rift_thornskin"),
		"nightfall": func(setup: FightSetup) -> bool: return _has_passive(setup.enemies[0].def, "rift_nightfall"),
		"blood_frenzy": func(setup: FightSetup) -> bool: return _has_passive(setup.enemies[0].def, "rift_blood_frenzy"),
		"blight": func(setup: FightSetup) -> bool: return setup.heroes.all(func(hero: UnitSetup) -> bool: return _has_passive(hero.def, "rift_blight")) \
			and not _has_passive(setup.enemies[0].def, "rift_blight"),
		"early_collapse": func(setup: FightSetup) -> bool: return setup.collapse_start_ticks == 30 * FixedMath.TICKS_PER_SECOND,
		"reinforcements": func(setup: FightSetup) -> bool: return setup.rift_effects.size() == 1 and setup.rift_ticks[0] == 15 * FixedMath.TICKS_PER_SECOND,
	}
	for id: String in checks:
		assert_true((checks[id] as Callable).call(_torn_setup([id] as Array[String])), id)
		if id != "hardened":
			assert_false((checks[id] as Callable).call(plain), "%s: not without it" % id)
	# Rift-Charged: an enemy with a signature bar starts half full.
	var charged: FightSetup = _torn_setup(["rift_charged"] as Array[String], 2)
	for enemy: UnitSetup in charged.enemies:
		if enemy.def.mana != null:
			assert_gte(enemy.def.mana.start, enemy.def.mana.max / 2, enemy.id)


func test_early_collapse_and_reinforcements_in_a_fight() -> void:
	var flow: RunFlow = _torn(["early_collapse", "reinforcements"] as Array[String])
	var setup: FightSetup = _setup_of(flow)
	assert_eq(setup.validate(_run.content), [] as Array[String])
	var sim := CombatSim.new(setup, _run.content)
	assert_eq(sim.collapse_start, 30 * FixedMath.TICKS_PER_SECOND, "the rift closes from 30s")
	var kind: String = setup.rift_effects[0].summon_kit
	assert_eq(kind, _run.content.encounters[flow.state.chosen].enemies[0].enemy, "the encounter's first enemy")
	for tick: int in 15 * FixedMath.TICKS_PER_SECOND:
		sim.step()
		if sim.finished:
			break
	var joined: Array = sim.combat_log.entries.filter(func(entry: LogEntry) -> bool: return entry.kind == LogEntry.Kind.SUMMON and entry.source_rift)
	assert_true(sim.enemies.any(func(unit: UnitState) -> bool: return unit.alive and unit.joined_at == 0), "the fight is still on at 15s")
	assert_eq(joined.size(), 2, "two join from the edge at 15s")
	for entry: LogEntry in joined:
		assert_eq([entry.tick, entry.source_relic_side, entry.source_text()], [15 * FixedMath.TICKS_PER_SECOND, EffectSource.Team.ENEMIES, "rift · Reinforcements"])
	# An elite fight's are the second enemy listed, not the elite.
	var elite_flow: RunFlow = _torn(["reinforcements"] as Array[String], 2)
	var elite: FightSetup = _setup_of(elite_flow)
	var encounter: EncounterDef = _run.content.encounters[elite_flow.state.chosen]
	assert_eq(encounter.tier, "elite")
	assert_eq(elite.rift_effects[0].summon_kit, encounter.enemies[1].enemy)


func test_a_hunt_takes_no_rift() -> void:
	var flow: RunFlow = _at_tear()
	flow.choose_depth(2)
	flow.state.node = "camp"
	flow.state.hunt = _run.encounters_for("hunt", 1)[0]
	var errors: Array[String] = []
	var setup: FightSetup = flow.fight_setup(Bot.formation(), errors)
	assert_eq(errors, [] as Array[String])
	assert_false(setup.enemies.any(func(enemy: UnitSetup) -> bool: return _has_passive(enemy.def, "rift_warded")))
	assert_eq([setup.collapse_start_ticks, setup.rift_effects.size()], [0, 0])


func test_the_rift_saves() -> void:
	var flow: RunFlow = _at_tear()
	flow.choose_depth(2)
	var loaded: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(flow.state.to_dict())))
	assert_eq([loaded.rift_depth, loaded.rift_mods], [flow.state.rift_depth, flow.state.rift_mods])


func test_blood_frenzy_and_nightfall_in_a_fight() -> void:
	var frenzy: KitMod = _run.camps.modifiers["blood_frenzy"].mod
	var night: KitMod = _run.camps.modifiers["nightfall"].mod
	var hero: UnitDef = K.kit("hero", {"stats": {"hp": 100000, "atk": 50, "speed": 0, "range": 4},
		"basic_attack": {"cooldown_ms": 50, "effects": [{"type": "damage", "amount": 0, "target": "target", "scaling": {"atk": 10000}}]}})
	var weak: UnitDef = frenzy.apply(K.kit("weak", {"stats": {"hp": 10, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}}))
	var sturdy: UnitDef = night.apply(frenzy.apply(K.kit("sturdy", {"stats": {"hp": 100000, "speed": 0, "range": 1},
		"basic_attack": {"cooldown_ms": 60000, "effects": [{"type": "damage", "amount": 0, "target": "target"}]}})))
	var fight: CombatSim = K.sim(K.fight([K.at(hero, 3, 1, "hero")] as Array[UnitSetup], [K.foe(weak, 3, 4, "weak"), K.foe(sturdy, 5, 5, "sturdy")] as Array[UnitSetup]))
	K.step(fight, 120)
	var applied: Array = K.entries(fight, LogEntry.Kind.STATUS_APPLIED)
	assert_true(applied.any(func(entry: LogEntry) -> bool: return entry.status == "stealth" and entry.target == "sturdy" and entry.tick <= 1), "Nightfall: hidden from the start")
	assert_false(fight.unit_by_id("weak").alive, "it fell")
	assert_true(applied.any(func(entry: LogEntry) -> bool: return entry.status == "blood_frenzy" and entry.target == "sturdy"), "Blood Frenzy: its ally hits harder")
